-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.

alter table inscripciones add column if not exists coaching_contactado boolean not null default false;
alter table inscripciones add column if not exists outplacement_contactado boolean not null default false;

-- Los administradores necesitan poder marcar como contactado.
drop policy if exists "admins pueden actualizar inscripciones" on inscripciones;
create policy "admins pueden actualizar inscripciones"
  on inscripciones for update
  to authenticated
  using (is_admin())
  with check (is_admin());
