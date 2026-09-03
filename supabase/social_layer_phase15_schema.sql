-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que las fases anteriores ya se hayan ejecutado.

-- ---------------------------------------------------------------------
-- 1) Contraseña obligatoria para miembros. El correo (codigo de un solo
--    uso) sigue siendo la puerta de entrada -- pero una vez verificado,
--    si el miembro todavia no tiene contraseña, se le exige crearla
--    antes de darle acceso. Si no quiere crearla, no entra.
-- ---------------------------------------------------------------------

alter table inscripciones add column if not exists password_set boolean not null default false;

create or replace function get_my_password_status()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(password_set, false) from inscripciones where lower(email) = lower(auth.jwt()->>'email') limit 1;
$$;

grant execute on function get_my_password_status() to authenticated;

create or replace function mark_password_set()
returns void
language sql
security definer
set search_path = public
as $$
  update inscripciones set password_set = true where lower(email) = lower(auth.jwt()->>'email');
$$;

grant execute on function mark_password_set() to authenticated;

-- ---------------------------------------------------------------------
-- 2) Eliminar una conversacion completa (para ambas personas).
-- ---------------------------------------------------------------------

drop policy if exists "participante elimina conversacion" on conversations;
create policy "participante elimina conversacion" on conversations for delete to authenticated
  using (is_conversation_participant(id));

-- ---------------------------------------------------------------------
-- 3) Editar un mensaje: solo quien lo escribio puede cambiar el texto
--    (la policy de "marcar leido" ya dejaba actualizar la fila a
--    cualquier participante para poner read_at -- este trigger evita
--    que alguien use eso para editar el texto de un mensaje ajeno).
-- ---------------------------------------------------------------------

create or replace function enforce_message_edit_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.text is distinct from old.text and old.sender_id <> my_member_id() then
    raise exception 'Solo el remitente puede editar el texto del mensaje';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_enforce_message_edit_rules on messages;
create trigger trg_enforce_message_edit_rules
before update on messages
for each row execute function enforce_message_edit_rules();
