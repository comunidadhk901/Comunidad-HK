-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que las fases anteriores ya se hayan ejecutado (en especial
-- social_layer_phase15_schema.sql, que agrego la columna password_set).
--
-- Permite que el login de Comunidad HK sepa, ANTES de autenticar, si un
-- correo ya tiene contraseña (para pedirle password directo) o todavia
-- no (para seguir el flujo de codigo + crear contraseña de siempre).
-- No expone nada mas que ese boolean, igual que is_community_member.

create or replace function has_password_set(check_email text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select password_set from inscripciones where lower(email) = lower(check_email) limit 1;
$$;

grant execute on function has_password_set(text) to anon, authenticated;
