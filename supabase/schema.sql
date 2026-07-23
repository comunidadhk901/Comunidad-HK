-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.

create table if not exists inscripciones (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  nombre text not null,
  apellido text not null,
  email text not null,
  telefono text not null,
  cargo text not null,
  empresa text not null,
  linkedin text,
  ciudad text,
  area_profesional text,
  anios_experiencia text,
  cv_file_name text,
  areas_interes text[] not null default '{}',
  acepta_privacidad boolean not null default false,
  acepta_comunicaciones boolean not null default false
);

alter table inscripciones enable row level security;

-- El sitio publico usa la anon key: solo puede INSERTAR inscripciones,
-- nunca leer, editar ni borrar las de otras personas.
create policy "cualquiera puede inscribirse"
  on inscripciones for insert
  to anon
  with check (true);
