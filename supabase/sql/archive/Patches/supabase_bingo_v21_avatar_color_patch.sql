-- =========================================================
-- V21: Avatar color system (Avatar-9)
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Cost: 25 XP per color change. Valid slots: 'skinColor'.
-- The RPC merges the new color key into the student's existing
-- avatar_data JSONB — no schema changes needed (avatar_data
-- already exists from V13). The client stores skinColor in
-- avatar_data alongside head/acc, and save_student_avatar
-- preserves it on subsequent item equips.
-- =========================================================

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
  v_student_id  uuid;
  v_cost        int := 25;
  v_current_xp  int;
  v_avatar_data jsonb;
begin
  -- Validate slot
  if p_color_slot not in ('skinColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargesegment');
  end if;

  -- Validate hex color format: exactly #rrggbb
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargekode');
  end if;

  -- Resolve student
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_current_xp, v_avatar_data
  from public.student_profiles
  where id = v_student_id;

  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok',     false,
      'error',  'Ikke nok XP',
      'total_xp', v_current_xp,
      'needed', v_cost
    );
  end if;

  -- Merge new color into avatar_data and deduct XP atomically
  v_avatar_data := v_avatar_data || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_student_id
  returning total_xp, avatar_data into v_current_xp, v_avatar_data;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
