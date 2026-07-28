-- =============================================================
-- Lerke Bingo v21 — Avatar color customization patch
-- =============================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Slots: 'skinColor' (face/head layer), 'propColor' (accessory layer).
-- Cost: 25 XP per color save. Overwrites the previous color for that slot.
-- No schema changes — avatar_data jsonb column from v13 already stores colors.
-- =============================================================

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_student record;
  v_cost    int := 25;
  v_avatar_data jsonb;
  v_level   int;
begin
  -- validate slot
  if p_color_slot not in ('skinColor','propColor') then
    return jsonb_build_object('ok',false,'error','invalid_slot');
  end if;

  -- validate hex color (#rgb or #rrggbb)
  if p_color !~ '^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$' then
    return jsonb_build_object('ok',false,'error','invalid_color');
  end if;

  select id, total_xp, avatar_data
  into v_student
  from student_profiles
  where auth_user_id = auth.uid()
  limit 1;

  if not found then
    return jsonb_build_object('ok',false,'error','profile_not_found');
  end if;

  if v_student.total_xp < v_cost then
    return jsonb_build_object(
      'ok',false,
      'error','insufficient_xp',
      'xp_needed',v_cost,
      'xp_have',v_student.total_xp
    );
  end if;

  v_avatar_data := coalesce(v_student.avatar_data,'{}') || jsonb_build_object(p_color_slot, p_color);

  update student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_student.id;

  v_level := floor((v_student.total_xp - v_cost) / 100) + 1;

  return jsonb_build_object(
    'ok',      true,
    'total_xp', v_student.total_xp - v_cost,
    'level',   v_level,
    'avatar_data', v_avatar_data
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text,text) to authenticated;
