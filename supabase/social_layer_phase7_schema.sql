-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que social_layer_full_schema.sql, social_layer_connections_schema.sql
-- y social_layer_phase6_schema.sql ya se hayan ejecutado antes.

-- ---------------------------------------------------------------------
-- 1) Nueva pregunta del formulario de inscripcion: quiere formar parte
--    de la red de networking. Solo la ve el administrador (misma tabla
--    inscripciones, mismo acceso que el resto del formulario).
-- ---------------------------------------------------------------------

alter table inscripciones add column if not exists quiere_networking boolean;

-- ---------------------------------------------------------------------
-- 2) Solo el creador de un grupo puede actualizarlo (nombre, foto, etc).
--    Sin esto, subir una foto de grupo fallaba en silencio: el UPDATE
--    quedaba bloqueado por RLS y no habia policy que lo permitiera.
-- ---------------------------------------------------------------------

drop policy if exists "creador actualiza grupo" on groups;
create policy "creador actualiza grupo" on groups for update to authenticated
  using (created_by_id = my_member_id())
  with check (created_by_id = my_member_id());

-- ---------------------------------------------------------------------
-- 3) get_my_connections(): agrega "outgoing" (solicitudes que yo envie
--    y todavia no responden) para poder mostrar "Solicitado" solo ahi,
--    y no confundirlo con conexiones ya aceptadas.
-- ---------------------------------------------------------------------

create or replace function get_my_connections()
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
  select json_build_object(
    'accepted', coalesce((
      select json_agg(row_to_json(a)) from (
        select c.id as connection_id,
          (case when c.requester_id = my_id then c.recipient_id else c.requester_id end) as member_id,
          i.nombre, i.apellido, i.cargo, i.empresa, i.area_profesional,
          case when i.foto_updated_at is not null then
            'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
              || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
          else null end as photo_url
        from connections c
        join inscripciones i on i.id = (case when c.requester_id = my_id then c.recipient_id else c.requester_id end)
        where c.status = 'accepted' and (c.requester_id = my_id or c.recipient_id = my_id)
      ) a
    ), '[]'::json),
    'incoming', coalesce((
      select json_agg(row_to_json(inc)) from (
        select c.id as connection_id, c.requester_id as member_id,
          i.nombre, i.apellido, i.cargo, i.empresa,
          case when i.foto_updated_at is not null then
            'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
              || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
          else null end as photo_url
        from connections c
        join inscripciones i on i.id = c.requester_id
        where c.status = 'pending' and c.recipient_id = my_id
      ) inc
    ), '[]'::json),
    'outgoing', coalesce((
      select json_agg(row_to_json(o)) from (
        select c.id as connection_id, c.recipient_id as member_id
        from connections c
        where c.status = 'pending' and c.requester_id = my_id
      ) o
    ), '[]'::json)
  ) into result;
  return result;
end;
$$;

grant execute on function get_my_connections() to authenticated;
