-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que social_layer_full_schema.sql, social_layer_phase6/7/8_schema.sql
-- ya se hayan ejecutado antes.

-- ---------------------------------------------------------------------
-- 1) El creador de un grupo puede eliminarlo.
-- ---------------------------------------------------------------------

drop policy if exists "creador elimina grupo" on groups;
create policy "creador elimina grupo" on groups for delete to authenticated
  using (created_by_id = my_member_id());

-- ---------------------------------------------------------------------
-- 2) "Personas activas": si hay menos de las pedidas con actividad real
--    en 60 dias, se completa con otros miembros visibles (para que el
--    panel no se vea vacio mientras la comunidad recien empieza a usar
--    la seccion nueva).
-- ---------------------------------------------------------------------

create or replace function get_active_members(limit_count int default 4)
returns json
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  my_id uuid := coalesce(my_member_id(), '00000000-0000-0000-0000-000000000000'::uuid);
  result json;
begin
  with active as (
    select i.id, i.nombre, i.apellido, i.cargo, i.empresa,
      case when i.foto_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
          || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
      else null end as photo_url
    from inscripciones i
    where i.perfil_visible = true and coalesce(i.quiere_networking, true) = true
      and i.last_active_at is not null and i.last_active_at >= now() - interval '60 days'
      and i.id <> my_id
    order by random()
    limit limit_count
  ),
  filler as (
    select i.id, i.nombre, i.apellido, i.cargo, i.empresa,
      case when i.foto_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
          || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
      else null end as photo_url
    from inscripciones i
    where i.perfil_visible = true and coalesce(i.quiere_networking, true) = true
      and i.id <> my_id
      and i.id not in (select id from active)
    order by random()
    limit greatest(limit_count - (select count(*) from active), 0)
  )
  select coalesce(json_agg(row_to_json(x)), '[]'::json) into result
  from (select * from active union all select * from filler) x;
  return result;
end;
$$;

grant execute on function get_active_members(int) to authenticated;

-- ---------------------------------------------------------------------
-- 3) La pregunta de networking pasa a ser obligatoria en el formulario
--    (se valida en el cliente) y ahora SI controla si el perfil aparece
--    en Comunidad HK: responder que no equivale a perfil_visible=false
--    para todo lo que muestra miembros. Los que ya se inscribieron antes
--    de esta pregunta (quiere_networking = null) se siguen mostrando.
-- ---------------------------------------------------------------------

create or replace function list_visible_members()
returns table (
  id uuid, nombre text, apellido text, cargo text, empresa text,
  area_profesional text, ciudad text, photo_url text, intereses_profesionales text[]
)
language sql
security definer
set search_path = public
stable
as $$
  select i.id, i.nombre, i.apellido, i.cargo, i.empresa, i.area_profesional, i.ciudad,
    case when i.foto_updated_at is not null then
      'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
        || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
    else null end,
    i.intereses_profesionales
  from inscripciones i
  where i.perfil_visible = true and coalesce(i.quiere_networking, true) = true
    and lower(i.email) <> lower(coalesce(auth.jwt()->>'email',''));
$$;

grant execute on function list_visible_members() to authenticated;

create or replace function get_member_profile(target_id uuid)
returns json
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  my_id uuid := my_member_id();
  target_visible boolean;
  result json;
begin
  select (perfil_visible and coalesce(quiere_networking, true)) into target_visible from inscripciones where id = target_id;
  if target_visible is null then
    return null;
  end if;
  if not target_visible and target_id <> my_id then
    return json_build_object('perfil_visible', false);
  end if;

  select json_build_object(
    'id', i.id, 'nombre', i.nombre, 'apellido', i.apellido, 'cargo', i.cargo, 'empresa', i.empresa,
    'area_profesional', i.area_profesional, 'ciudad', i.ciudad, 'bio', i.bio, 'linkedin', i.linkedin,
    'perfil_visible', i.perfil_visible,
    'photo_url', case when i.foto_updated_at is not null then
      'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
        || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
      else null end,
    'connections_count', (select count(*) from connections c where c.status = 'accepted' and (c.requester_id = i.id or c.recipient_id = i.id)),
    'groups_count', (select count(*) from group_members gm where gm.member_id = i.id and gm.status = 'approved'),
    'posts_count', (select count(*) from posts where author_id = i.id),
    'posts', (
      select coalesce(json_agg(row_to_json(pp) order by pp.created_at desc), '[]'::json) from (
        select id, text, media_type, media_storage_path, created_at
        from posts where author_id = i.id order by created_at desc limit 10
      ) pp
    )
  ) into result
  from inscripciones i where i.id = target_id;

  return result;
end;
$$;

grant execute on function get_member_profile(uuid) to authenticated;

-- ---------------------------------------------------------------------
-- 4) get_feed(): agrega los intereses del autor de cada post, para
--    poder priorizar publicaciones por interes en el feed.
-- ---------------------------------------------------------------------

create or replace function get_feed(limit_count int default 30)
returns json
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  result json;
begin
  select json_agg(row_to_json(f) order by f.created_at desc) into result
  from (
    select
      p.id, p.text, p.media_type, p.media_storage_path, p.created_at,
      p.author_id,
      i.nombre as author_nombre, i.apellido as author_apellido,
      i.cargo as author_cargo, i.empresa as author_empresa,
      i.intereses_profesionales as author_intereses,
      case when i.foto_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
          || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
      else null end as author_photo_url,
      (select count(*) from post_likes pl where pl.post_id = p.id) as like_count,
      exists(select 1 from post_likes pl2 where pl2.post_id = p.id and pl2.member_id = my_member_id()) as liked_by_me,
      (select count(*) from post_comments pc where pc.post_id = p.id) as comment_count,
      (
        select json_agg(row_to_json(c) order by c.created_at asc) from (
          select pc.id, pc.author_id, pc.text, pc.created_at, ci.nombre as author_nombre, ci.apellido as author_apellido
          from post_comments pc join inscripciones ci on ci.id = pc.author_id
          where pc.post_id = p.id order by pc.created_at asc limit 5
        ) c
      ) as recent_comments,
      (
        select row_to_json(pd) from (
          select pl3.id, pl3.question,
            (select json_agg(row_to_json(o)) from (
              select po.id, po.option_text,
                (select count(*) from poll_votes pv where pv.option_id = po.id) as vote_count
              from poll_options po where po.poll_id = pl3.id
            ) o) as options,
            (select option_id from poll_votes pv2 where pv2.poll_id = pl3.id and pv2.member_id = my_member_id()) as my_vote_option_id
          from polls pl3 where pl3.post_id = p.id
        ) pd
      ) as poll,
      (
        select row_to_json(ed) from (
          select e.id, e.title, e.description, e.event_date, e.location,
            (select count(*) from event_rsvps r where r.event_id = e.id) as rsvp_count,
            exists(select 1 from event_rsvps r2 where r2.event_id = e.id and r2.member_id = my_member_id()) as rsvped_by_me
          from events e where e.id = p.event_id
        ) ed
      ) as event,
      (
        select row_to_json(sp) from (
          select p2.id, p2.text, p2.media_type, p2.media_storage_path, p2.created_at,
            i2.nombre as author_nombre, i2.apellido as author_apellido
          from posts p2 join inscripciones i2 on i2.id = p2.author_id
          where p2.id = p.shared_post_id
        ) sp
      ) as shared_post
    from posts p
    join inscripciones i on i.id = p.author_id
    where p.group_id is null
    order by p.created_at desc
    limit limit_count
  ) f;
  return coalesce(result, '[]'::json);
end;
$$;

grant execute on function get_feed(int) to authenticated;
