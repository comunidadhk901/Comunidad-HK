-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/community_profile_photo_schema.sql ya se haya ejecutado antes.
--
-- Etapa 1 de la capa social de Comunidad HK: "Mi Perfil" enriquecido
-- (bio, intereses profesionales para futuro matching de conexiones,
-- visibilidad de perfil). Esta migracion solo toca datos -- la nueva
-- UI queda detras de un feature flag (site_settings.social_layer_enabled)
-- hasta que se active para todos los miembros; ver index.html.

alter table inscripciones add column if not exists bio text;
alter table inscripciones add column if not exists intereses_profesionales text[] not null default '{}';
alter table inscripciones add column if not exists perfil_visible boolean not null default true;

-- Elimina TODAS las versiones existentes de get_my_profile/update_my_profile
-- antes de recrearlas. La vez pasada, "create or replace function" con un
-- parametro nuevo dejo dos versiones coexistiendo en vez de reemplazar
-- (error "Could not choose the best candidate function" al guardar el
-- perfil) -- este bloque evita repetir ese bug.
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('get_my_profile', 'update_my_profile')
  loop
    execute format('drop function %s', r.sig);
  end loop;
end $$;

create function get_my_profile(check_email text)
returns json
language sql
security definer
set search_path = public
stable
as $$
  select to_jsonb(t) from (
    select nombre, apellido, email, telefono, cargo, empresa, carrera, linkedin, ciudad,
           area_profesional, anios_experiencia, cv_file_name, foto_updated_at,
           motivacion, bio, intereses_profesionales, perfil_visible
    from inscripciones
    where lower(email) = lower(check_email)
    limit 1
  ) t;
$$;

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
  p_foto_updated_at text default null,
  p_bio text default null,
  p_intereses_profesionales text[] default null,
  p_perfil_visible boolean default null
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
    foto_updated_at = coalesce(p_foto_updated_at::timestamptz, foto_updated_at),
    bio = coalesce(p_bio, bio),
    intereses_profesionales = coalesce(p_intereses_profesionales, intereses_profesionales),
    perfil_visible = coalesce(p_perfil_visible, perfil_visible)
  where lower(email) = lower(check_email);
end;
$$;

grant execute on function get_my_profile(text) to anon, authenticated;
grant execute on function update_my_profile(text,text,text,text,text,text,text,text,text,text,text,text,text,text,text,text[],boolean) to anon, authenticated;

-- Eliminar foto: funcion separada porque "coalesce" no puede distinguir
-- "no tocar el campo" de "ponerlo en null" para limpiar la foto actual.
create or replace function remove_my_photo(check_email text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update inscripciones set foto_updated_at = null
  where lower(email) = lower(check_email);
end;
$$;

grant execute on function remove_my_photo(text) to anon, authenticated;
