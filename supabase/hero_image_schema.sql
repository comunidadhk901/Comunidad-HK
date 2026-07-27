-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/admin_schema.sql ya se haya ejecutado antes (usa is_admin()).

create table if not exists site_settings (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);

alter table site_settings enable row level security;

-- Cualquiera puede leer (para saber que foto mostrar en el hero).
create policy "cualquiera puede leer la configuracion del sitio"
  on site_settings for select
  to anon, authenticated
  using (true);

-- Solo administradores pueden cambiarla.
drop policy if exists "admins pueden actualizar la configuracion del sitio" on site_settings;
create policy "admins pueden actualizar la configuracion del sitio"
  on site_settings for insert
  to authenticated
  with check (is_admin());

drop policy if exists "admins pueden modificar la configuracion del sitio" on site_settings;
create policy "admins pueden modificar la configuracion del sitio"
  on site_settings for update
  to authenticated
  using (is_admin())
  with check (is_admin());

-- Bucket publico para imagenes de marketing del sitio (hero, etc).
-- Publico porque son fotos decorativas, no datos de candidatos.
insert into storage.buckets (id, name, public)
values ('site-assets', 'site-assets', true)
on conflict (id) do nothing;

drop policy if exists "cualquiera puede ver site-assets" on storage.objects;
create policy "cualquiera puede ver site-assets"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'site-assets');

drop policy if exists "admins pueden subir site-assets" on storage.objects;
create policy "admins pueden subir site-assets"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'site-assets' and is_admin());

drop policy if exists "admins pueden reemplazar site-assets" on storage.objects;
create policy "admins pueden reemplazar site-assets"
  on storage.objects for update
  to authenticated
  using (bucket_id = 'site-assets' and is_admin())
  with check (bucket_id = 'site-assets' and is_admin());
