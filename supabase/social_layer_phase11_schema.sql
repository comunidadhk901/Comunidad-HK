-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que social_layer_full_schema.sql y social_layer_phase10_schema.sql
-- ya se hayan ejecutado antes.
--
-- Cambios:
-- 1) El creador de un evento puede eliminarlo (ya podia editarlo desde phase10).
-- 2) Pedir participar en un evento ahora queda "pendiente" hasta que el
--    creador lo acepte. El lugar/link del evento solo se muestra al
--    creador y a quienes ya fueron aceptados.
-- 3) Recordatorios automaticos (2 dias antes, 1 dia antes, el mismo dia)
--    via pg_cron -- si tu proyecto no tiene la extension pg_cron
--    disponible, la seccion 3 al final de este archivo fallara; el resto
--    (borrar evento, aprobar participacion, ocultar lugar) funciona igual.

-- ---------------------------------------------------------------------
-- 1) Eliminar evento (solo el creador).
-- ---------------------------------------------------------------------

drop policy if exists "creador elimina evento" on events;
create policy "creador elimina evento" on events for delete to authenticated
  using (created_by_id = my_member_id());

-- ---------------------------------------------------------------------
-- 2) Participacion con aprobacion del creador.
-- ---------------------------------------------------------------------

alter table event_rsvps add column if not exists status text not null default 'pending';
alter table event_rsvps drop constraint if exists event_rsvps_status_check;
alter table event_rsvps add constraint event_rsvps_status_check check (status in ('pending','approved'));

drop policy if exists "pedir participar" on event_rsvps;
create policy "pedir participar" on event_rsvps for insert to authenticated
  with check (member_id = my_member_id());

drop policy if exists "creador aprueba participacion" on event_rsvps;
create policy "creador aprueba participacion" on event_rsvps for update to authenticated
  using (exists (select 1 from events e where e.id = event_rsvps.event_id and e.created_by_id = my_member_id()))
  with check (exists (select 1 from events e where e.id = event_rsvps.event_id and e.created_by_id = my_member_id()));

drop policy if exists "cancelar o rechazar participacion" on event_rsvps;
create policy "cancelar o rechazar participacion" on event_rsvps for delete to authenticated
  using (
    member_id = my_member_id()
    or exists (select 1 from events e where e.id = event_rsvps.event_id and e.created_by_id = my_member_id())
  );

-- Solicitudes pendientes de un evento que yo cree.
create or replace function get_event_rsvp_requests(eid uuid)
returns json
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  result json;
begin
  if not exists (select 1 from events e where e.id = eid and e.created_by_id = my_member_id()) then
    return '[]'::json;
  end if;
  select coalesce(json_agg(row_to_json(r)), '[]'::json) into result
  from (
    select rs.member_id, i.nombre, i.apellido, i.cargo, i.empresa
    from event_rsvps rs
    join inscripciones i on i.id = rs.member_id
    where rs.event_id = eid and rs.status = 'pending'
  ) r;
  return result;
end;
$$;

grant execute on function get_event_rsvp_requests(uuid) to authenticated;

create or replace function get_events()
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
  select coalesce(json_agg(row_to_json(e) order by e.created_at desc), '[]'::json) into result
  from (
    select ev.id, ev.title, ev.description, ev.event_date,
      case when ev.created_by_id = my_id or exists(
        select 1 from event_rsvps r where r.event_id = ev.id and r.member_id = my_id and r.status = 'approved'
      ) then ev.location else null end as location,
      ev.created_at, ev.created_by_id,
      (ev.created_by_id = my_id) as is_creator,
      i.nombre as creator_nombre, i.apellido as creator_apellido,
      case when ev.photo_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/event-photos/event-' || ev.id::text || '?v=' || extract(epoch from ev.photo_updated_at)::text
      else null end as photo_url,
      (select count(*) from event_rsvps r2 where r2.event_id = ev.id and r2.status = 'approved') as rsvp_count,
      (select count(*) from event_rsvps r3 where r3.event_id = ev.id and r3.status = 'pending') as pending_count,
      (select r4.status from event_rsvps r4 where r4.event_id = ev.id and r4.member_id = my_id) as my_rsvp_status
    from events ev
    join inscripciones i on i.id = ev.created_by_id
  ) e;
  return result;
end;
$$;

grant execute on function get_events() to authenticated;

create or replace function get_feed(limit_count int default 30)
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
  select json_agg(row_to_json(f) order by f.created_at desc) into result
  from (
    select
      p.id, p.text, p.media_type, p.media_storage_path, p.created_at,
      p.author_id,
      i.nombre as author_nombre, i.apellido as author_apellido,
      i.cargo as author_cargo, i.empresa as author_empresa,
      i.intereses_profesionales as author_intereses,
      case when i.foto_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
          || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
      else null end as author_photo_url,
      (select count(*) from post_likes pl where pl.post_id = p.id) as like_count,
      exists(select 1 from post_likes pl2 where pl2.post_id = p.id and pl2.member_id = my_id) as liked_by_me,
      (select count(*) from post_comments pc where pc.post_id = p.id) as comment_count,
      (
        select json_agg(row_to_json(c) order by c.created_at asc) from (
          select pc.id, pc.author_id, pc.text, pc.created_at, ci.nombre as author_nombre, ci.apellido as author_apellido
          from post_comments pc join inscripciones ci on ci.id = pc.author_id
          where pc.post_id = p.id order by pc.created_at asc limit 5
        ) c
      ) as recent_comments,
      (
        select row_to_json(pd) from (
          select pl3.id, pl3.question,
            (select json_agg(row_to_json(o)) from (
              select po.id, po.option_text,
                (select count(*) from poll_votes pv where pv.option_id = po.id) as vote_count
              from poll_options po where po.poll_id = pl3.id
            ) o) as options,
            (select option_id from poll_votes pv2 where pv2.poll_id = pl3.id and pv2.member_id = my_id) as my_vote_option_id
          from polls pl3 where pl3.post_id = p.id
        ) pd
      ) as poll,
      (
        select row_to_json(ed) from (
          select e.id, e.title, e.description, e.event_date,
            case when e.created_by_id = my_id or exists(
              select 1 from event_rsvps r where r.event_id = e.id and r.member_id = my_id and r.status = 'approved'
            ) then e.location else null end as location,
            e.created_by_id,
            (e.created_by_id = my_id) as is_creator,
            case when e.photo_updated_at is not null then
              'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/event-photos/event-' || e.id::text || '?v=' || extract(epoch from e.photo_updated_at)::text
            else null end as photo_url,
            (select count(*) from event_rsvps r2 where r2.event_id = e.id and r2.status = 'approved') as rsvp_count,
            (select count(*) from event_rsvps r3 where r3.event_id = e.id and r3.status = 'pending') as pending_count,
            (select r4.status from event_rsvps r4 where r4.event_id = e.id and r4.member_id = my_id) as my_rsvp_status
          from events e where e.id = p.event_id
        ) ed
      ) as event,
      (
        select row_to_json(sp) from (
          select p2.id, p2.text, p2.media_type, p2.media_storage_path, p2.created_at,
            i2.nombre as author_nombre, i2.apellido as author_apellido
          from posts p2 join inscripciones i2 on i2.id = p2.author_id
          where p2.id = p.shared_post_id
        ) sp
      ) as shared_post
    from posts p
    join inscripciones i on i.id = p.author_id
    where p.group_id is null
    order by p.created_at desc
    limit limit_count
  ) f;
  return coalesce(result, '[]'::json);
end;
$$;

grant execute on function get_feed(int) to authenticated;

-- ---------------------------------------------------------------------
-- 3) Recordatorios automaticos: 2 dias antes, 1 dia antes, el mismo dia.
--    Requiere la extension pg_cron (Database -> Extensions en Supabase).
-- ---------------------------------------------------------------------

create extension if not exists pg_cron;

create table if not exists event_reminders_sent (
  event_id uuid not null references events(id) on delete cascade,
  member_id uuid not null references inscripciones(id) on delete cascade,
  reminder_type text not null check (reminder_type in ('2d','1d','0d')),
  sent_at timestamptz not null default now(),
  primary key (event_id, member_id, reminder_type)
);
alter table event_reminders_sent enable row level security;

create or replace function send_event_reminders()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  reminder_label text;
  reminder_key text;
  days_left int;
begin
  for r in
    select ev.id as event_id, ev.title, ev.event_date, rs.member_id
    from events ev
    join event_rsvps rs on rs.event_id = ev.id and rs.status = 'approved'
    where ev.event_date is not null
      and (date(ev.event_date) - current_date) in (2, 1, 0)
    union
    select ev.id, ev.title, ev.event_date, ev.created_by_id as member_id
    from events ev
    where ev.event_date is not null
      and (date(ev.event_date) - current_date) in (2, 1, 0)
  loop
    days_left := (date(r.event_date) - current_date);
    reminder_key := case days_left when 2 then '2d' when 1 then '1d' else '0d' end;
    reminder_label := case days_left
      when 2 then 'es en 2 días'
      when 1 then 'es mañana'
      else 'es hoy'
    end;
    insert into event_reminders_sent (event_id, member_id, reminder_type)
    values (r.event_id, r.member_id, reminder_key)
    on conflict (event_id, member_id, reminder_type) do nothing;
    if found then
      insert into notifications (recipient_id, actor_id, type, payload)
      values (r.member_id, null, 'event_reminder', 'Tu evento "' || r.title || '" ' || reminder_label);
    end if;
  end loop;
end;
$$;

do $$
begin
  if exists (select 1 from cron.job where jobname = 'send_event_reminders_daily') then
    perform cron.unschedule('send_event_reminders_daily');
  end if;
end $$;

-- Corre todos los dias a las 13:00 UTC (~09:00 en Chile continental).
select cron.schedule('send_event_reminders_daily', '0 13 * * *', 'select send_event_reminders();');
