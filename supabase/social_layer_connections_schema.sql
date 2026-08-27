-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que social_layer_full_schema.sql ya se haya ejecutado antes.
--
-- Trae mis conexiones aceptadas y mis solicitudes entrantes pendientes,
-- con la info del otro miembro (foto, nombre, cargo, empresa, area
-- profesional), sin exponer inscripciones directamente al cliente.

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
    ), '[]'::json)
  ) into result;
  return result;
end;
$$;

grant execute on function get_my_connections() to authenticated;
