-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/schema.sql ya se haya ejecutado antes.

create table if not exists admin_emails (
  email text primary key,
  created_at timestamptz not null default now()
);

alter table admin_emails enable row level security;

-- security definer: evita recursion infinita al chequear el mismo admin_emails
-- desde sus propias policies (patron estandar de Supabase para este caso).
create or replace function is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from admin_emails where email = auth.jwt() ->> 'email'
  );
$$;

create policy "admins pueden ver la lista de administradores"
  on admin_emails for select
  to authenticated
  using (is_admin());

create policy "admins pueden agregar administradores"
  on admin_emails for insert
  to authenticated
  with check (is_admin());

-- Los administradores autenticados pueden ver todas las inscripciones
-- (el resto del sitio, con la anon key, solo puede insertar).
create policy "admins pueden ver inscripciones"
  on inscripciones for select
  to authenticated
  using (is_admin());

-- Primer administrador (bootstrap). Agrega mas emails desde el boton
-- "Agregar administrador" del panel una vez que hayas iniciado sesion,
-- o agrega mas lineas "insert into admin_emails..." aqui antes de correr.
insert into admin_emails (email) values ('pablomackenna9@gmail.com')
  on conflict (email) do nothing;
