-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/resource_content_schema.sql ya se haya ejecutado antes
-- (reutiliza el bucket "site-assets" y sus policies, igual que la foto de portada).

alter table resource_content add column if not exists file_updated_at timestamptz;
alter table resource_content add column if not exists file_name text;
alter table resource_content add column if not exists external_url text;
