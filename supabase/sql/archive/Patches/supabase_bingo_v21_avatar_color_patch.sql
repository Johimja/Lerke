-- Lerke Bingo V21 — Avatar paid color changes
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC
-- Cost: 25 XP per color change per slot
-- Valid slots: 'skinColor' (base face silhouette tint)

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_student_id  uuid;
  v_xp_before   int;
  v_new_xp      int;
  v_new_data    jsonb;
  v_cost        int := 25;
  v_valid_slots text[] := array['skinColor'];
begin
  -- Validate slot name
  if p_color_slot is null or not (p_color_slot = any(v_valid_slots)) then
    return jsonb_build_object('ok', false, 'error', 'invalid_slot');
  end if;

  -- Validate hex color (#RGB or #RRGGBB)
  if p_color is null or p_color !~ '^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_color');
  end if;

  -- Resolve student from authenticated session
  select student_id into v_student_id
  from student_auth_links
  where auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  -- Check current XP balance
  select coalesce(total_xp, 0) into v_xp_before
  from student_profiles
  where id = v_student_id;

  if v_xp_before < v_cost then
    return jsonb_build_object(
      'ok', false,
      'error', 'insufficient_xp',
      'total_xp', v_xp_before,
      'cost', v_cost
    );
  end if;

  -- Atomically deduct XP and merge new color into avatar_data
  update student_profiles
  set total_xp   = total_xp - v_cost,
      avatar_data = coalesce(avatar_data, '{}'::jsonb)
                    || jsonb_build_object(p_color_slot, p_color)
  where id = v_student_id
  returning total_xp, avatar_data into v_new_xp, v_new_data;

  return jsonb_build_object(
    'ok',        true,
    'total_xp',  v_new_xp,
    'xp_spent',  v_cost,
    'avatar_data', v_new_data
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
