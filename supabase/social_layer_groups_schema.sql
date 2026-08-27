-- Ejecutar en Supabase: Panel del proyecto -> SQL Editor -> New query -> pegar y correr.
-- Requiere que social_layer_full_schema.sql ya se haya ejecutado antes.
--
-- Lista todos los grupos con su cantidad real de miembros (sin exponer
-- quienes son, salvo que seas admin del grupo) y mi estado en cada uno.

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
      (select count(*) from group_members gm where gm.group_id = gr.id and gm.status = 'approved') as member_count,
      (select gm2.status from group_members gm2 where gm2.group_id = gr.id and gm2.member_id = my_id) as my_status,
      (select gm3.role from group_members gm3 where gm3.group_id = gr.id and gm3.member_id = my_id) as my_role
    from groups gr
  ) g;
  return coalesce(result, '[]'::json);
end;
$$;

grant execute on function list_groups() to authenticated;

-- Solicitudes pendientes de un grupo que administro (para aprobar/rechazar).
create or replace function get_group_join_requests(gid uuid)
returns json
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  result json;
begin
  if not is_group_admin(gid) then
    return '[]'::json;
  end if;
  select json_agg(row_to_json(r)) into result
  from (
    select gm.id as member_row_id, gm.member_id, i.nombre, i.apellido, i.cargo, i.empresa
    from group_members gm
    join inscripciones i on i.id = gm.member_id
    where gm.group_id = gid and gm.status = 'pending'
  ) r;
  return coalesce(result, '[]'::json);
end;
$$;

grant execute on function get_group_join_requests(uuid) to authenticated;

-- Rechazar una solicitud (o que un miembro salga de un grupo) borra la
-- fila de group_members. Solo el propio miembro o un admin del grupo.
drop policy if exists "salir o admin gestiona" on group_members;
create policy "salir o admin gestiona" on group_members for delete to authenticated
  using (member_id = my_member_id() or is_group_admin(group_id));
