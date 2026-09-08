-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que las fases anteriores ya se hayan ejecutado.

-- ---------------------------------------------------------------------
-- 1) Notifica a tus conexiones cuando publicas algo en el feed
--    principal (no publicaciones dentro de un grupo, esas ya son
--    privadas de por si).
-- ---------------------------------------------------------------------

create or replace function notify_connections_of_new_post()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.group_id is null then
    insert into notifications (recipient_id, actor_id, type, payload)
    select
      case when c.requester_id = new.author_id then c.recipient_id else c.requester_id end,
      new.author_id,
      'connection_post',
      coalesce((select nombre from inscripciones where id = new.author_id), 'Una conexión') || ' publicó algo nuevo'
    from connections c
    where c.status = 'accepted' and (c.requester_id = new.author_id or c.recipient_id = new.author_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_connections_of_new_post on posts;
create trigger trg_notify_connections_of_new_post
after insert on posts
for each row execute function notify_connections_of_new_post();

-- ---------------------------------------------------------------------
-- 2) Notifica cuando alguien ve tu perfil (get_member_profile ya no
--    puede ser "stable" porque ahora escribe una notificacion).
--    Para no saturar, no vuelve a notificar la misma visita si el
--    mismo miembro ya te vio en la ultima hora.
-- ---------------------------------------------------------------------

create or replace function get_member_profile(target_id uuid)
returns json
language plpgsql
security definer
set search_path = public
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

  if my_id is not null and target_id <> my_id then
    if not exists (
      select 1 from notifications n
      where n.recipient_id = target_id and n.actor_id = my_id and n.type = 'profile_view'
        and n.created_at >= now() - interval '1 hour'
    ) then
      insert into notifications (recipient_id, actor_id, type, payload)
      select target_id, my_id, 'profile_view', coalesce((select nombre from inscripciones where id = my_id), 'Alguien') || ' vio tu perfil';
    end if;
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
