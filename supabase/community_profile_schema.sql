-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/schema.sql y supabase/cv_and_carrera_schema.sql ya se hayan ejecutado antes.

-- Estas dos funciones permiten que un miembro de la comunidad vea y edite
-- SU PROPIO perfil (nombre, cargo, CV, etc.), identificandose solo con el
-- correo con el que se inscribio -- mismo nivel de verificacion que ya se
-- usa para el acceso a Recursos (is_community_member). No hay contraseña
-- de por medio: quien conozca el correo de otra persona podria editar su
-- perfil. Se documenta ese riesgo, aceptado a cambio de no construir un
-- sistema de autenticacion nuevo para miembros.

create or replace function get_my_profile(check_email text)
returns json
language sql
security definer
set search_path = public
stable
as $$
  select to_jsonb(t) from (
    select nombre, apellido, email, telefono, cargo, empresa, carrera, linkedin, ciudad,
           area_profesional, anios_experiencia, cv_file_name
    from inscripciones
    where lower(email) = lower(check_email)
    limit 1
  ) t;
$$;

grant execute on function get_my_profile(text) to anon, authenticated;

create or replace function update_my_profile(
  check_email text,
  p_nombre text default null,
  p_apellido text default null,
  p_telefono text default null,
  p_cargo text default null,
  p_empresa text default null,
  p_carrera text default null,
  p_linkedin text default null,
  p_ciudad text default null,
  p_area_profesional text default null,
  p_anios_experiencia text default null,
  p_cv_storage_path text default null,
  p_cv_file_name text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update inscripciones set
    nombre = coalesce(p_nombre, nombre),
    apellido = coalesce(p_apellido, apellido),
    telefono = coalesce(p_telefono, telefono),
    cargo = coalesce(p_cargo, cargo),
    empresa = coalesce(p_empresa, empresa),
    carrera = coalesce(p_carrera, carrera),
    linkedin = coalesce(p_linkedin, linkedin),
    ciudad = coalesce(p_ciudad, ciudad),
    area_profesional = coalesce(p_area_profesional, area_profesional),
    anios_experiencia = coalesce(p_anios_experiencia, anios_experiencia),
    cv_storage_path = coalesce(p_cv_storage_path, cv_storage_path),
    cv_file_name = coalesce(p_cv_file_name, cv_file_name)
  where lower(email) = lower(check_email);
end;
$$;

grant execute on function update_my_profile(text,text,text,text,text,text,text,text,text,text,text,text,text) to anon, authenticated;
