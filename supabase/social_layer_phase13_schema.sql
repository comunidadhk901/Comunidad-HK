-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que social_layer_full_schema.sql ya se haya ejecutado antes.
--
-- Cantidad de mensajes sin leer (para el globito del icono de Mensajes).

create or replace function get_unread_message_count()
returns int
language sql
security definer
set search_path = public
stable
as $$
  select count(*)::int
  from messages m
  join conversation_participants cp on cp.conversation_id = m.conversation_id
  where cp.member_id = my_member_id()
    and m.sender_id <> my_member_id()
    and m.read_at is null;
$$;

grant execute on function get_unread_message_count() to authenticated;
