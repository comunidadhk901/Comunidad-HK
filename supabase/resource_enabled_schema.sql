-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/resource_content_schema.sql ya se haya ejecutado antes.

alter table resource_content add column if not exists enabled boolean not null default false;

-- La guia de CV ya estaba habilitada antes de este cambio: se mantiene asi.
update resource_content set enabled = true where slug = 'cv-guide';
