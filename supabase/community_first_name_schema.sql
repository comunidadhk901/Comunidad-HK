-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que supabase/community_access_schema.sql ya se haya ejecutado antes.

-- Funcion segura para obtener solo el nombre de pila de alguien que ya
-- forma parte de la comunidad, dado su correo. Igual que is_community_member,
-- no expone el resto de la tabla inscripciones: solo devuelve el nombre para
-- el correo exacto que ya se conoce (usado para personalizar el saludo de
-- bienvenida cuando alguien vuelve a la seccion "Comunidad").
create or replace function get_community_first_name(check_email text)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select nombre from inscripciones where lower(email) = lower(check_email) limit 1;
$$;

grant execute on function get_community_first_name(text) to anon, authenticated;
