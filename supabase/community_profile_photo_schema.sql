-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/community_profile_schema.sql ya se haya ejecutado antes.

alter table inscripciones add column if not exists foto_updated_at timestamptz;

-- Bucket publico para las fotos de perfil de los miembros (igual patron
-- que site-assets: cualquiera puede verlas, pero solo se sube/reemplaza
-- la propia foto identificandose con el correo, igual que el resto del
-- perfil).
insert into storage.buckets (id, name, public)
values ('member-photos', 'member-photos', true)
on conflict (id) do nothing;

drop policy if exists "cualquiera puede ver member-photos" on storage.objects;
create policy "cualquiera puede ver member-photos"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'member-photos');

drop policy if exists "miembros pueden subir su foto" on storage.objects;
create policy "miembros pueden subir su foto"
  on storage.objects for insert
  to anon, authenticated
  with check (bucket_id = 'member-photos');

drop policy if exists "miembros pueden reemplazar su foto" on storage.objects;
create policy "miembros pueden reemplazar su foto"
  on storage.objects for update
  to anon, authenticated
  using (bucket_id = 'member-photos')
  with check (bucket_id = 'member-photos');

create or replace function get_my_profile(check_email text)
returns json
language sql
security definer
set search_path = public
stable
as $$
  select to_jsonb(t) from (
    select nombre, apellido, email, telefono, cargo, empresa, carrera, linkedin, ciudad,
           area_profesional, anios_experiencia, cv_file_name, foto_updated_at
    from inscripciones
    where lower(email) = lower(check_email)
    limit 1
  ) t;
$$;

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

grant execute on function get_my_profile(text) to anon, authenticated;
grant execute on function update_my_profile(text,text,text,text,text,text,text,text,text,text,text,text,text,text) to anon, authenticated;
