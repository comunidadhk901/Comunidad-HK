-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/resource_content_schema.sql y supabase/hero_image_schema.sql
-- ya se hayan ejecutado antes (reutiliza el bucket "site-assets" y sus policies).

alter table resource_content add column if not exists cover_updated_at timestamptz;
