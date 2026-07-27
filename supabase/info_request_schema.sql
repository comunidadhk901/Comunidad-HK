-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.

alter table inscripciones add column if not exists quiere_info_coaching boolean not null default false;
alter table inscripciones add column if not exists quiere_info_outplacement boolean not null default false;
alter table inscripciones add column if not exists quiere_info_otro text;
