-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Reemplaza a community_profile_fix_overload.sql (esa version dependia de
-- adivinar la firma exacta de la funcion vieja para borrarla, y por lo visto
-- no la elimino: el error "Could not choose the best candidate function"
-- sigue apareciendo porque siguen coexistiendo dos versiones de
-- update_my_profile en la base de datos.
--
-- Este script es a prueba de fallos: busca TODAS las versiones de
-- update_my_profile que existan en la base (sin importar cuantas ni con que
-- parametros) y las elimina, para despues crear una sola version limpia con
-- soporte de foto de perfil incluido.

do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'update_my_profile'
  loop
    execute format('drop function %s', r.sig);
  end loop;
end $$;

create function update_my_profile(
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
  p_cv_file_name text default null,
  p_foto_updated_at text default null
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
    cv_file_name = coalesce(p_cv_file_name, cv_file_name),
    foto_updated_at = coalesce(p_foto_updated_at::timestamptz, foto_updated_at)
  where lower(email) = lower(check_email);
end;
$$;

grant execute on function update_my_profile(text,text,text,text,text,text,text,text,text,text,text,text,text,text) to anon, authenticated;
