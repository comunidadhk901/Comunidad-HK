-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/admin_schema.sql ya se haya ejecutado antes (usa is_admin()).

create table if not exists resource_content (
  slug text primary key,
  title text not null,
  desc_text text not null,
  body_one text,
  body_two text,
  updated_at timestamptz not null default now()
);

alter table resource_content enable row level security;

drop policy if exists "cualquiera puede leer el contenido de recursos" on resource_content;
create policy "cualquiera puede leer el contenido de recursos"
  on resource_content for select
  to anon, authenticated
  using (true);

drop policy if exists "admins pueden crear contenido de recursos" on resource_content;
create policy "admins pueden crear contenido de recursos"
  on resource_content for insert
  to authenticated
  with check (is_admin());

drop policy if exists "admins pueden editar contenido de recursos" on resource_content;
create policy "admins pueden editar contenido de recursos"
  on resource_content for update
  to authenticated
  using (is_admin())
  with check (is_admin());

-- Semilla inicial para la guia de CV (el admin puede editarla despues desde el sitio).
insert into resource_content (slug, title, desc_text, body_one, body_two)
values (
  'cv-guide',
  'Cómo actualizar tu CV',
  'Una guía práctica para ordenar tu experiencia y destacar logros relevantes para roles de liderazgo.',
  'Un CV ejecutivo debe priorizar resultados por sobre funciones. Cuantifica el impacto de tu gestión: crecimiento, eficiencia, equipos liderados.',
  'Mantén un formato limpio y de una a dos páginas. Actualízalo cada seis meses, incluso si no estás buscando un cambio activamente.'
)
on conflict (slug) do nothing;
