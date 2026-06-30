-- v21 Avatar Color Patch
-- purchase_avatar_color(p_color_slot, p_color):
--   Validates slot ('skinColor' or 'accColor'), validates hex color (#rrggbb),
--   checks and deducts 25 XP from the student, updates avatar_data in-place
--   via jsonb_set, and returns {ok, total_xp, avatar_data}.
-- No schema changes — avatar_data (jsonb) already exists from v13.

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cost        constant int := 25;
  v_student_id  uuid;
  v_current_xp  int;
  v_avatar_data jsonb;
  v_new_xp      int;
begin
  if p_color_slot not in ('skinColor', 'accColor') then
    return jsonb_build_object('ok', false, 'error', 'Invalid color slot');
  end if;

  if p_color is null or p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Invalid color format');
  end if;

  select id, total_xp, coalesce(avatar_data, '{}'::jsonb)
    into v_student_id, v_current_xp, v_avatar_data
    from public.student_profiles
    where auth_user_id = auth.uid()
    limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Student not found');
  end if;

  if coalesce(v_current_xp, 0) < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Not enough XP');
  end if;

  v_new_xp      := v_current_xp - v_cost;
  v_avatar_data := jsonb_set(v_avatar_data, array[p_color_slot], to_jsonb(p_color));

  update public.student_profiles
    set total_xp    = v_new_xp,
        avatar_data = v_avatar_data
    where id = v_student_id;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_new_xp,
    'avatar_data', v_avatar_data
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
