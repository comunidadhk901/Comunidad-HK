-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/schema.sql ya se haya ejecutado antes (tabla inscripciones).

-- Funcion segura para verificar si un correo esta registrado en la
-- comunidad, sin exponer el resto de la tabla inscripciones (que sigue
-- siendo de solo lectura para administradores).
create or replace function is_community_member(check_email text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from inscripciones where lower(email) = lower(check_email)
  );
$$;

grant execute on function is_community_member(text) to anon, authenticated;
