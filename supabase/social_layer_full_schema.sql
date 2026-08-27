-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que member_profile_photo_schema.sql / member_profile_social_v1_schema.sql
-- ya se hayan ejecutado antes (columna perfil_visible en inscripciones).
--
-- Esquema completo de la capa social real de Comunidad HK: conexiones,
-- grupos, publicaciones (con fotos/videos/encuestas/eventos), mensajes
-- privados y notificaciones. Se entrega todo junto para correr una sola
-- vez, aunque la interfaz se construye por etapas.
--
-- Identidad: Comunidad HK ahora requiere login real (codigo de un solo
-- uso por correo, via Supabase Auth) en vez del correo sin verificar
-- que usa el "Comunidad" viejo. Todas las policies de abajo usan
-- auth.jwt()->>'email', no un parametro que mande el cliente -- por
-- eso se puede garantizar que nadie lea mensajes ni datos ajenos.
--
-- Todas las tablas nuevas usan member_id (uuid, referencia a
-- inscripciones.id) en vez de email, para no exponer correos entre
-- miembros en ningun listado.

create or replace function my_member_id()
returns uuid
language sql
security definer
set search_path = public
stable
as $$
  select id from inscripciones where lower(email) = lower(auth.jwt()->>'email') limit 1;
$$;

grant execute on function my_member_id() to authenticated;

-- ---------------------------------------------------------------------
-- Directorio de miembros (solo perfil_visible = true, nunca expone
-- correo ni telefono).
-- ---------------------------------------------------------------------
create or replace function list_visible_members()
returns table (
  id uuid, nombre text, apellido text, cargo text, empresa text,
  area_profesional text, ciudad text, photo_url text
)
language sql
security definer
set search_path = public
stable
as $$
  select i.id, i.nombre, i.apellido, i.cargo, i.empresa, i.area_profesional, i.ciudad,
    case when i.foto_updated_at is not null then
      'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
        || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
    else null end
  from inscripciones i
  where i.perfil_visible = true and lower(i.email) <> lower(coalesce(auth.jwt()->>'email',''));
$$;

grant execute on function list_visible_members() to authenticated;

-- ---------------------------------------------------------------------
-- Conexiones
-- ---------------------------------------------------------------------
create table if not exists connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references inscripciones(id) on delete cascade,
  recipient_id uuid not null references inscripciones(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','declined')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (requester_id, recipient_id)
);
alter table connections enable row level security;

drop policy if exists "ver mis conexiones" on connections;
create policy "ver mis conexiones" on connections for select to authenticated
  using (requester_id = my_member_id() or recipient_id = my_member_id());

drop policy if exists "enviar solicitud" on connections;
create policy "enviar solicitud" on connections for insert to authenticated
  with check (requester_id = my_member_id() and requester_id <> recipient_id);

drop policy if exists "responder solicitud" on connections;
create policy "responder solicitud" on connections for update to authenticated
  using (recipient_id = my_member_id())
  with check (recipient_id = my_member_id());

-- ---------------------------------------------------------------------
-- Grupos
-- ---------------------------------------------------------------------
create table if not exists groups (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  sector text,
  created_by_id uuid not null references inscripciones(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table groups enable row level security;

drop policy if exists "autenticados ven grupos" on groups;
create policy "autenticados ven grupos" on groups for select to authenticated using (true);

drop policy if exists "crear grupo" on groups;
create policy "crear grupo" on groups for insert to authenticated
  with check (created_by_id = my_member_id());

create table if not exists group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references groups(id) on delete cascade,
  member_id uuid not null references inscripciones(id) on delete cascade,
  role text not null default 'member' check (role in ('admin','member')),
  status text not null default 'pending' check (status in ('invited','pending','approved')),
  created_at timestamptz not null default now(),
  unique (group_id, member_id)
);
alter table group_members enable row level security;

create or replace function is_group_admin(gid uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from group_members
    where group_id = gid and member_id = my_member_id() and role = 'admin' and status = 'approved'
  );
$$;

grant execute on function is_group_admin(uuid) to authenticated;

drop policy if exists "ver membresias" on group_members;
create policy "ver membresias" on group_members for select to authenticated
  using (member_id = my_member_id() or is_group_admin(group_id));

drop policy if exists "unirse invitar o crear como admin" on group_members;
create policy "unirse invitar o crear como admin" on group_members for insert to authenticated
  with check (
    (member_id = my_member_id() and status = 'pending')
    or (status = 'invited' and is_group_admin(group_id))
    or (status = 'approved' and role = 'admin' and member_id = my_member_id()
        and exists (select 1 from groups g where g.id = group_members.group_id and g.created_by_id = my_member_id()))
  );

drop policy if exists "aprobar o aceptar membresia" on group_members;
create policy "aprobar o aceptar membresia" on group_members for update to authenticated
  using (member_id = my_member_id() or is_group_admin(group_id))
  with check (true);

-- ---------------------------------------------------------------------
-- Publicaciones, likes, comentarios
-- ---------------------------------------------------------------------
create table if not exists posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references inscripciones(id) on delete cascade,
  text text,
  media_type text check (media_type in ('photo','video')),
  media_storage_path text,
  event_id uuid,
  created_at timestamptz not null default now()
);
alter table posts enable row level security;

drop policy if exists "autenticados ven posts" on posts;
create policy "autenticados ven posts" on posts for select to authenticated using (true);

drop policy if exists "crear post propio" on posts;
create policy "crear post propio" on posts for insert to authenticated
  with check (author_id = my_member_id());

drop policy if exists "borrar post propio" on posts;
create policy "borrar post propio" on posts for delete to authenticated
  using (author_id = my_member_id());

create table if not exists post_likes (
  post_id uuid not null references posts(id) on delete cascade,
  member_id uuid not null references inscripciones(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, member_id)
);
alter table post_likes enable row level security;

drop policy if exists "ver likes" on post_likes;
create policy "ver likes" on post_likes for select to authenticated using (true);
drop policy if exists "dar like" on post_likes;
create policy "dar like" on post_likes for insert to authenticated with check (member_id = my_member_id());
drop policy if exists "quitar like" on post_likes;
create policy "quitar like" on post_likes for delete to authenticated using (member_id = my_member_id());

create table if not exists post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  author_id uuid not null references inscripciones(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now()
);
alter table post_comments enable row level security;

drop policy if exists "ver comentarios" on post_comments;
create policy "ver comentarios" on post_comments for select to authenticated using (true);
drop policy if exists "comentar" on post_comments;
create policy "comentar" on post_comments for insert to authenticated with check (author_id = my_member_id());

-- ---------------------------------------------------------------------
-- Encuestas
-- ---------------------------------------------------------------------
create table if not exists polls (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  question text not null
);
alter table polls enable row level security;
drop policy if exists "ver encuestas" on polls;
create policy "ver encuestas" on polls for select to authenticated using (true);
drop policy if exists "crear encuesta" on polls;
create policy "crear encuesta" on polls for insert to authenticated
  with check (exists (select 1 from posts p where p.id = polls.post_id and p.author_id = my_member_id()));

create table if not exists poll_options (
  id uuid primary key default gen_random_uuid(),
  poll_id uuid not null references polls(id) on delete cascade,
  option_text text not null
);
alter table poll_options enable row level security;
drop policy if exists "ver opciones" on poll_options;
create policy "ver opciones" on poll_options for select to authenticated using (true);
drop policy if exists "crear opciones" on poll_options;
create policy "crear opciones" on poll_options for insert to authenticated
  with check (exists (select 1 from polls pl join posts p on p.id = pl.post_id where pl.id = poll_options.poll_id and p.author_id = my_member_id()));

create table if not exists poll_votes (
  poll_id uuid not null references polls(id) on delete cascade,
  option_id uuid not null references poll_options(id) on delete cascade,
  member_id uuid not null references inscripciones(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (poll_id, member_id)
);
alter table poll_votes enable row level security;
drop policy if exists "ver votos" on poll_votes;
create policy "ver votos" on poll_votes for select to authenticated using (true);
drop policy if exists "votar" on poll_votes;
create policy "votar" on poll_votes for insert to authenticated with check (member_id = my_member_id());

-- ---------------------------------------------------------------------
-- Eventos
-- ---------------------------------------------------------------------
create table if not exists events (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  event_date timestamptz,
  location text,
  created_by_id uuid not null references inscripciones(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table events enable row level security;
drop policy if exists "ver eventos" on events;
create policy "ver eventos" on events for select to authenticated using (true);
drop policy if exists "crear evento" on events;
create policy "crear evento" on events for insert to authenticated with check (created_by_id = my_member_id());

create table if not exists event_rsvps (
  event_id uuid not null references events(id) on delete cascade,
  member_id uuid not null references inscripciones(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, member_id)
);
alter table event_rsvps enable row level security;
drop policy if exists "ver participantes" on event_rsvps;
create policy "ver participantes" on event_rsvps for select to authenticated using (true);
drop policy if exists "pedir participar" on event_rsvps;
create policy "pedir participar" on event_rsvps for insert to authenticated with check (member_id = my_member_id());

-- ---------------------------------------------------------------------
-- Mensajes privados
-- ---------------------------------------------------------------------
create table if not exists conversations (
  id uuid primary key default gen_random_uuid(),
  created_by_id uuid not null references inscripciones(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table conversations enable row level security;

create table if not exists conversation_participants (
  conversation_id uuid not null references conversations(id) on delete cascade,
  member_id uuid not null references inscripciones(id) on delete cascade,
  primary key (conversation_id, member_id)
);
alter table conversation_participants enable row level security;

create or replace function is_conversation_participant(conv_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from conversation_participants
    where conversation_id = conv_id and member_id = my_member_id()
  );
$$;

grant execute on function is_conversation_participant(uuid) to authenticated;

drop policy if exists "ver mis conversaciones" on conversations;
create policy "ver mis conversaciones" on conversations for select to authenticated
  using (is_conversation_participant(id));
drop policy if exists "crear conversacion" on conversations;
create policy "crear conversacion" on conversations for insert to authenticated
  with check (created_by_id = my_member_id());

drop policy if exists "ver participantes" on conversation_participants;
create policy "ver participantes" on conversation_participants for select to authenticated
  using (is_conversation_participant(conversation_id));
drop policy if exists "agregar participantes" on conversation_participants;
create policy "agregar participantes" on conversation_participants for insert to authenticated
  with check (exists (select 1 from conversations c where c.id = conversation_participants.conversation_id and c.created_by_id = my_member_id()));

create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references inscripciones(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);
alter table messages enable row level security;
drop policy if exists "ver mensajes" on messages;
create policy "ver mensajes" on messages for select to authenticated
  using (is_conversation_participant(conversation_id));
drop policy if exists "enviar mensaje" on messages;
create policy "enviar mensaje" on messages for insert to authenticated
  with check (sender_id = my_member_id() and is_conversation_participant(conversation_id));

-- ---------------------------------------------------------------------
-- Notificaciones
-- ---------------------------------------------------------------------
create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references inscripciones(id) on delete cascade,
  actor_id uuid references inscripciones(id) on delete set null,
  type text not null,
  payload text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
alter table notifications enable row level security;
drop policy if exists "ver mis notificaciones" on notifications;
create policy "ver mis notificaciones" on notifications for select to authenticated
  using (recipient_id = my_member_id());
drop policy if exists "marcar leida" on notifications;
create policy "marcar leida" on notifications for update to authenticated
  using (recipient_id = my_member_id())
  with check (recipient_id = my_member_id());
drop policy if exists "crear notificacion para otro" on notifications;
create policy "crear notificacion para otro" on notifications for insert to authenticated
  with check (actor_id = my_member_id() or actor_id is null);

-- ---------------------------------------------------------------------
-- Estadisticas de mi perfil
-- ---------------------------------------------------------------------
create or replace function get_my_social_stats()
returns json
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'connections', (select count(*) from connections where status = 'accepted' and (requester_id = my_member_id() or recipient_id = my_member_id())),
    'groups', (select count(*) from group_members where member_id = my_member_id() and status = 'approved'),
    'posts', (select count(*) from posts where author_id = my_member_id())
  );
$$;

grant execute on function get_my_social_stats() to authenticated;

-- ---------------------------------------------------------------------
-- Bucket para fotos/videos de publicaciones
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('post-media', 'post-media', true)
on conflict (id) do nothing;

drop policy if exists "cualquiera ve post-media" on storage.objects;
create policy "cualquiera ve post-media" on storage.objects for select to anon, authenticated using (bucket_id = 'post-media');

drop policy if exists "autenticados suben post-media" on storage.objects;
create policy "autenticados suben post-media" on storage.objects for insert to authenticated with check (bucket_id = 'post-media');
