-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que las fases anteriores ya se hayan ejecutado.
--
-- fmackenna@hkchile.cl seguia sin funcionarle nada (conectar, unirse a
-- grupos, publicar, comentar, pedir participar, Mi Perfil pegado en
-- "Cargando...") a pesar de social_layer_phase12_schema.sql -- lo mas
-- probable es que su sesion real (auth.jwt()->>'email') no calzo
-- exactamente con lo que quedo en admin_emails/inscripciones (mayuscula,
-- espacio, o un correo ligeramente distinto).
--
-- En vez de seguir parchando caso por caso, esto deja el sistema
-- auto-reparable: cualquier admin que entre a Comunidad HK y no tenga
-- fila en inscripciones se la crea usando exactamente el correo de su
-- sesion real, sin depender de que admin_emails calce.

create or replace function ensure_my_inscripcion()
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  my_email text := auth.jwt()->>'email';
  existing_id uuid;
begin
  if my_email is null then
    return null;
  end if;
  select id into existing_id from inscripciones where lower(email) = lower(my_email);
  if existing_id is not null then
    return existing_id;
  end if;
  insert into inscripciones (nombre, apellido, email, telefono, cargo, empresa, perfil_visible)
  values (initcap(split_part(my_email, '@', 1)), '', my_email, '', '', '', true)
  returning id into existing_id;
  return existing_id;
end;
$$;

grant execute on function ensure_my_inscripcion() to authenticated;

-- Diagnostico opcional: para ver si algun admin quedo sin fila (o con
-- una fila cuyo email no calza exactamente), correr por separado:
--   select ae.email as admin_email, i.id as inscripcion_id, i.email as inscripcion_email
--   from admin_emails ae
--   left join inscripciones i on lower(i.email) = lower(ae.email)
--   order by ae.email;

-- ---------------------------------------------------------------------
-- Mi Perfil: ahora tambien devuelve tus propias publicaciones (para
-- mostrarlas abajo, igual que al ver el perfil de otro miembro).
-- ---------------------------------------------------------------------

create or replace function get_my_social_stats()
returns json
language sql
security definer
set search_path = public
stable
as $$
  select json_build_object(
    'connections', (select count(*) from connections where status = 'accepted' and (requester_id = my_member_id() or recipient_id = my_member_id())),
    'groups', (select count(*) from group_members where member_id = my_member_id() and status = 'approved'),
    'posts', (select count(*) from posts where author_id = my_member_id()),
    'recent_posts', (
      select coalesce(json_agg(row_to_json(pp) order by pp.created_at desc), '[]'::json) from (
        select id, text, media_type, media_storage_path, created_at
        from posts where author_id = my_member_id() order by created_at desc limit 10
      ) pp
    )
  );
$$;

grant execute on function get_my_social_stats() to authenticated;

-- ---------------------------------------------------------------------
-- Eventos: no se puede pedir participar en un evento cuya fecha ya paso.
-- ---------------------------------------------------------------------

drop policy if exists "pedir participar" on event_rsvps;
create policy "pedir participar" on event_rsvps for insert to authenticated
  with check (
    member_id = my_member_id()
    and exists (
      select 1 from events e where e.id = event_rsvps.event_id
      and (e.event_date is null or e.event_date >= now())
    )
  );
