-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que social_layer_full_schema.sql ya se haya ejecutado antes.
--
-- Trae el feed completo (posts + autor + likes + comentarios + encuesta
-- + evento) en una sola llamada, sin exponer la tabla inscripciones
-- directamente al cliente.

create or replace function get_feed(limit_count int default 30)
returns json
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  result json;
begin
  select json_agg(row_to_json(f) order by f.created_at desc) into result
  from (
    select
      p.id, p.text, p.media_type, p.media_storage_path, p.created_at,
      p.author_id,
      i.nombre as author_nombre, i.apellido as author_apellido,
      i.cargo as author_cargo, i.empresa as author_empresa,
      case when i.foto_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
          || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
      else null end as author_photo_url,
      (select count(*) from post_likes pl where pl.post_id = p.id) as like_count,
      exists(select 1 from post_likes pl2 where pl2.post_id = p.id and pl2.member_id = my_member_id()) as liked_by_me,
      (select count(*) from post_comments pc where pc.post_id = p.id) as comment_count,
      (
        select json_agg(row_to_json(c) order by c.created_at asc) from (
          select pc.id, pc.text, pc.created_at, ci.nombre as author_nombre, ci.apellido as author_apellido
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
            (select option_id from poll_votes pv2 where pv2.poll_id = pl3.id and pv2.member_id = my_member_id()) as my_vote_option_id
          from polls pl3 where pl3.post_id = p.id
        ) pd
      ) as poll,
      (
        select row_to_json(ed) from (
          select e.id, e.title, e.description, e.event_date, e.location,
            (select count(*) from event_rsvps r where r.event_id = e.id) as rsvp_count,
            exists(select 1 from event_rsvps r2 where r2.event_id = e.id and r2.member_id = my_member_id()) as rsvped_by_me
          from events e where e.id = p.event_id
        ) ed
      ) as event
    from posts p
    join inscripciones i on i.id = p.author_id
    order by p.created_at desc
    limit limit_count
  ) f;
  return coalesce(result, '[]'::json);
end;
$$;

grant execute on function get_feed(int) to authenticated;
