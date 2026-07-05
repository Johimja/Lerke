-- =========================================================
-- V21: Paid avatar color changes (Avatar-9)
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Each call costs 25 XP, deducts from student total_xp,
-- and updates the named color slot in avatar_data.
-- Allowed slot for this release: 'skinColor'.
-- Returns {ok, total_xp, avatar_data, xp_spent} on success
-- or {ok:false, error, ...} on failure.
-- No schema changes — avatar_data (jsonb) already exists on
-- student_profiles and accepts arbitrary JSON keys.
-- =========================================================

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
) returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  v_student_id   uuid;
  v_current_xp   int;
  v_current_avatar jsonb;
  v_new_avatar   jsonb;
  v_cost         int := 25;
  v_allowed_slots text[] := array['skinColor'];
begin
  -- Validate slot name
  if not (p_color_slot = any(v_allowed_slots)) then
    return jsonb_build_object('ok', false, 'error', 'invalid_slot');
  end if;

  -- Validate hex color: must be exactly #RRGGBB
  if not (p_color ~ '^#[0-9a-fA-F]{6}$') then
    return jsonb_build_object('ok', false, 'error', 'invalid_color');
  end if;

  -- Resolve student via auth link
  select sp.id, sp.total_xp, sp.avatar_data
  into   v_student_id, v_current_xp, v_current_avatar
  from   student_profiles sp
  join   student_auth_links sal on sal.student_profile_id = sp.id
  where  sal.auth_user_id = auth.uid()
  limit  1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'student_not_found');
  end if;

  -- No charge if the color is already set to the exact same value
  if (v_current_avatar ->> p_color_slot) = p_color then
    return jsonb_build_object(
      'ok',        true,
      'no_change', true,
      'total_xp',  v_current_xp,
      'avatar_data', v_current_avatar,
      'xp_spent',  0
    );
  end if;

  -- Check XP balance
  if coalesce(v_current_xp, 0) < v_cost then
    return jsonb_build_object(
      'ok',        false,
      'error',     'insufficient_xp',
      'required',  v_cost,
      'available', coalesce(v_current_xp, 0)
    );
  end if;

  -- Merge color slot into avatar_data and deduct XP atomically
  v_new_avatar := coalesce(v_current_avatar, '{}'::jsonb)
                  || jsonb_build_object(p_color_slot, p_color);

  update student_profiles
  set    total_xp   = total_xp - v_cost,
         avatar_data = v_new_avatar
  where  id = v_student_id;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_current_xp - v_cost,
    'avatar_data', v_new_avatar,
    'xp_spent',   v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
