-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/schema.sql y supabase/admin_schema.sql ya se hayan ejecutado antes.

alter table inscripciones add column if not exists carrera text;
alter table inscripciones add column if not exists cv_storage_path text;

-- Bucket privado para los CV: nadie puede verlos por URL directa,
-- solo mediante un link firmado que genera el panel de administracion.
insert into storage.buckets (id, name, public)
values ('cvs', 'cvs', false)
on conflict (id) do nothing;

drop policy if exists "cualquiera puede subir su cv" on storage.objects;
create policy "cualquiera puede subir su cv"
  on storage.objects for insert
  to anon
  with check (bucket_id = 'cvs');

drop policy if exists "admins pueden ver los cv" on storage.objects;
create policy "admins pueden ver los cv"
  on storage.objects for select
  to authenticated
  using (bucket_id = 'cvs' and is_admin());
