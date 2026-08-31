-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
--
-- Diagnostico: los administradores que NO son comunidadhk901@gmail.com
-- (por ejemplo fmackenna@hkchile.cl) no tenian una fila en inscripciones.
-- Comunidad HK identifica al usuario actual buscando su email en
-- inscripciones (my_member_id()) -- si no existe esa fila, ninguna
-- accion que requiera "saber quien eres" funciona: conectar, pedir
-- participar en un evento, pedir unirse a un grupo, enviar mensajes,
-- etc. Por eso a fmackenna@hkchile.cl (que entra como admin) le fallaba
-- todo, aunque para comunidadhk901@gmail.com si funcionaba: a esa
-- cuenta ya le habiamos creado su fila manualmente (admin_hk_profile_seed.sql).
--
-- Esto NO afecta a un usuario normal real: alguien que se inscribe por
-- el formulario publico y despues entra a Comunidad HK con codigo por
-- correo (no como admin) ya tiene su fila de inscripciones desde que se
-- inscribio, asi que para ellos ya deberia funcionar todo.
--
-- Este script le crea automaticamente una fila de inscripciones a TODOS
-- los administradores que todavia no tengan una (para que puedan probar
-- Comunidad HK como si fueran miembros), y deja un trigger para que
-- cualquier admin que agregues despues tambien la reciba automaticamente.

insert into inscripciones (nombre, apellido, email, telefono, cargo, empresa, perfil_visible)
select initcap(split_part(ae.email, '@', 1)), '', ae.email, '', '', '', true
from admin_emails ae
where not exists (
  select 1 from inscripciones i where lower(i.email) = lower(ae.email)
);

create or replace function ensure_admin_inscripcion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into inscripciones (nombre, apellido, email, telefono, cargo, empresa, perfil_visible)
  select initcap(split_part(new.email, '@', 1)), '', new.email, '', '', '', true
  where not exists (select 1 from inscripciones i where lower(i.email) = lower(new.email));
  return new;
end;
$$;

drop trigger if exists trg_ensure_admin_inscripcion on admin_emails;
create trigger trg_ensure_admin_inscripcion
after insert on admin_emails
for each row execute function ensure_admin_inscripcion();
