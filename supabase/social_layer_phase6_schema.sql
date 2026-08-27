-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que social_layer_full_schema.sql, social_layer_groups_schema.sql
-- y admin_hk_profile_seed.sql ya se hayan ejecutado antes (esta migracion
-- asume que ya existe la fila de comunidadhk901@gmail.com).

-- ---------------------------------------------------------------------
-- 1) HK Human Capital queda conectado automaticamente con cada miembro
--    (existente y nuevo).
-- ---------------------------------------------------------------------

-- Backfill: conectar a HK con todos los miembros que ya existen.
insert into connections (requester_id, recipient_id, status, responded_at)
select hk.id, i.id, 'accepted', now()
from inscripciones i
cross join (select id from inscripciones where lower(email) = 'comunidadhk901@gmail.com') hk
where i.id <> hk.id
  and not exists (
    select 1 from connections c
    where (c.requester_id = hk.id and c.recipient_id = i.id)
       or (c.requester_id = i.id and c.recipient_id = hk.id)
  );

-- A futuro: cada vez que alguien se inscribe, queda conectado con HK.
create or replace function auto_connect_hk_admin()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  hk_id uuid;
begin
  select id into hk_id from inscripciones where lower(email) = 'comunidadhk901@gmail.com';
  if hk_id is not null and hk_id <> new.id then
    insert into connections (requester_id, recipient_id, status, responded_at)
    values (hk_id, new.id, 'accepted', now())
    on conflict (requester_id, recipient_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_auto_connect_hk_admin on inscripciones;
create trigger trg_auto_connect_hk_admin
after insert on inscripciones
for each row execute function auto_connect_hk_admin();

-- ---------------------------------------------------------------------
-- 2) Grupos: foto + nombre del creador en list_groups().
-- ---------------------------------------------------------------------

alter table groups add column if not exists photo_updated_at timestamptz;

insert into storage.buckets (id, name, public)
values ('group-photos', 'group-photos', true)
on conflict (id) do nothing;

drop policy if exists "cualquiera ve group-photos" on storage.objects;
create policy "cualquiera ve group-photos" on storage.objects for select to anon, authenticated using (bucket_id = 'group-photos');

drop policy if exists "autenticados suben group-photos" on storage.objects;
create policy "autenticados suben group-photos" on storage.objects for insert to authenticated with check (bucket_id = 'group-photos');

create or replace function list_groups()
returns json
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  my_id uuid := my_member_id();
  result json;
begin
  select json_agg(row_to_json(g) order by g.name) into result
  from (
    select gr.id, gr.name, gr.description, gr.sector, gr.created_at, gr.created_by_id,
      creator.nombre as creator_nombre, creator.apellido as creator_apellido,
      case when gr.photo_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/group-photos/group-' || gr.id::text || '?v=' || extract(epoch from gr.photo_updated_at)::text
      else null end as photo_url,
      (select count(*) from group_members gm where gm.group_id = gr.id and gm.status = 'approved') as member_count,
      (select gm2.status from group_members gm2 where gm2.group_id = gr.id and gm2.member_id = my_id) as my_status,
      (select gm3.role from group_members gm3 where gm3.group_id = gr.id and gm3.member_id = my_id) as my_role
    from groups gr
    join inscripciones creator on creator.id = gr.created_by_id
  ) g;
  return coalesce(result, '[]'::json);
end;
$$;

grant execute on function list_groups() to authenticated;

-- ---------------------------------------------------------------------
-- 3) Compartir publicaciones.
-- ---------------------------------------------------------------------

alter table posts add column if not exists shared_post_id uuid references posts(id) on delete set null;

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
      case when i.foto_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
          || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
      else null end as author_photo_url,
      (select count(*) from post_likes pl where pl.post_id = p.id) as like_count,
      exists(select 1 from post_likes pl2 where pl2.post_id = p.id and pl2.member_id = my_member_id()) as liked_by_me,
      (select count(*) from post_comments pc where pc.post_id = p.id) as comment_count,
      (
        select json_agg(row_to_json(c) order by c.created_at asc) from (
          select pc.id, pc.text, pc.created_at, ci.nombre as author_nombre, ci.apellido as author_apellido
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
    order by p.created_at desc
    limit limit_count
  ) f;
  return coalesce(result, '[]'::json);
end;
$$;

grant execute on function get_feed(int) to authenticated;

-- ---------------------------------------------------------------------
-- 4) Perfil publico de otro miembro (al hacer clic en su nombre).
--    Si el perfil no es visible, solo devuelve perfil_visible:false.
-- ---------------------------------------------------------------------

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
  select perfil_visible into target_visible from inscripciones where id = target_id;
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
