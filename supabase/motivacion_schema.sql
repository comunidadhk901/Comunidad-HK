-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.

alter table inscripciones add column if not exists motivacion text;
