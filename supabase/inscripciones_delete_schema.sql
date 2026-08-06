-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/admin_schema.sql ya se haya ejecutado antes.

-- Los administradores pueden eliminar inscripciones (botón "Eliminar
-- de la comunidad" en el panel de administrador).
drop policy if exists "admins pueden eliminar inscripciones" on inscripciones;
create policy "admins pueden eliminar inscripciones"
  on inscripciones for delete
  to authenticated
  using (is_admin());
