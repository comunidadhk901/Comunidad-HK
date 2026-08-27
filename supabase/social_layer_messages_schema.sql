-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que social_layer_full_schema.sql ya se haya ejecutado antes.
--
-- Mensajeria privada 1 a 1. Las policies de conversations/conversation_participants/
-- messages ya se crearon en social_layer_full_schema.sql (is_conversation_participant),
-- asi que nadie puede leer una conversacion de la que no forma parte.

-- Falta permitir marcar un mensaje como leido (solo se agrego SELECT/INSERT
-- en el esquema original).
drop policy if exists "marcar leido" on messages;
create policy "marcar leido" on messages for update to authenticated
  using (is_conversation_participant(conversation_id))
  with check (is_conversation_participant(conversation_id));

-- Busca (o crea) la conversacion 1 a 1 entre yo y otro miembro, evitando
-- duplicados.
create or replace function get_or_create_conversation(other_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  my_id uuid := my_member_id();
  conv_id uuid;
begin
  if my_id is null or other_id is null or my_id = other_id then
    return null;
  end if;

  select conv.id into conv_id
  from conversations conv
  join conversation_participants p1 on p1.conversation_id = conv.id and p1.member_id = my_id
  join conversation_participants p2 on p2.conversation_id = conv.id and p2.member_id = other_id
  limit 1;

  if conv_id is not null then
    return conv_id;
  end if;

  insert into conversations (created_by_id) values (my_id) returning id into conv_id;
  insert into conversation_participants (conversation_id, member_id) values (conv_id, my_id), (conv_id, other_id);
  return conv_id;
end;
$$;

grant execute on function get_or_create_conversation(uuid) to authenticated;

-- Lista mis conversaciones con el otro participante, ultimo mensaje y
-- cantidad de mensajes sin leer.
create or replace function get_my_conversations()
returns json
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  my_id uuid := my_member_id();
  result json;
begin
  select json_agg(row_to_json(c) order by c.last_at desc nulls last) into result
  from (
    select conv.id as conversation_id,
      other.id as other_member_id, other.nombre as other_nombre, other.apellido as other_apellido,
      other.cargo as other_cargo, other.empresa as other_empresa,
      case when other.foto_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
          || regexp_replace(lower(other.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from other.foto_updated_at)::text
      else null end as other_photo_url,
      (select m.text from messages m where m.conversation_id = conv.id order by m.created_at desc limit 1) as last_text,
      (select m.created_at from messages m where m.conversation_id = conv.id order by m.created_at desc limit 1) as last_at,
      (select count(*) from messages m2 where m2.conversation_id = conv.id and m2.sender_id <> my_id and m2.read_at is null) as unread_count
    from conversations conv
    join conversation_participants me_p on me_p.conversation_id = conv.id and me_p.member_id = my_id
    join conversation_participants other_p on other_p.conversation_id = conv.id and other_p.member_id <> my_id
    join inscripciones other on other.id = other_p.member_id
  ) c;
  return coalesce(result, '[]'::json);
end;
$$;

grant execute on function get_my_conversations() to authenticated;
