-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que las fases anteriores ya se hayan ejecutado.

-- ---------------------------------------------------------------------
-- 1) list_groups(): agrega cuantas solicitudes pendientes tiene cada
--    grupo, para mostrar el globito en el menu de Grupos.
-- ---------------------------------------------------------------------

create or replace function list_groups()
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
  select json_agg(row_to_json(g) order by g.name) into result
  from (
    select gr.id, gr.name, gr.description, gr.sector, gr.created_at, gr.created_by_id,
      creator.nombre as creator_nombre, creator.apellido as creator_apellido,
      case when gr.photo_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/group-photos/group-' || gr.id::text || '?v=' || extract(epoch from gr.photo_updated_at)::text
      else null end as photo_url,
      (select count(*) from group_members gm where gm.group_id = gr.id and gm.status = 'approved') as member_count,
      (select count(*) from group_members gm2 where gm2.group_id = gr.id and gm2.status = 'pending') as pending_count,
      (select gm3.status from group_members gm3 where gm3.group_id = gr.id and gm3.member_id = my_id) as my_status,
      (select gm4.role from group_members gm4 where gm4.group_id = gr.id and gm4.member_id = my_id) as my_role
    from groups gr
    join inscripciones creator on creator.id = gr.created_by_id
  ) g;
  return coalesce(result, '[]'::json);
end;
$$;

grant execute on function list_groups() to authenticated;

-- ---------------------------------------------------------------------
-- 2) Ver quien le dio like a una publicacion.
-- ---------------------------------------------------------------------

create or replace function get_post_likers(pid uuid)
returns json
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(json_agg(row_to_json(l)), '[]'::json) from (
    select i.id as member_id, i.nombre, i.apellido,
      case when i.foto_updated_at is not null then
        'https://dqxmcqenqedehlorvwms.supabase.co/storage/v1/object/public/member-photos/avatar-'
          || regexp_replace(lower(i.email), '[^a-z0-9]+', '-', 'g') || '?v=' || extract(epoch from i.foto_updated_at)::text
      else null end as photo_url
    from post_likes pl
    join inscripciones i on i.id = pl.member_id
    where pl.post_id = pid
    order by pl.created_at desc
  ) l;
$$;

grant execute on function get_post_likers(uuid) to authenticated;
