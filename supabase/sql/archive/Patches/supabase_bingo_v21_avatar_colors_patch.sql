-- =========================================================
-- Lerke Bingo — v21 Avatar Colors Patch
-- =========================================================
-- Adds server-verified XP-cost color changes for avatar skin color.
-- No schema changes — skinColor is stored as a key in the existing
-- avatar_data jsonb column (student_profiles.avatar_data).
--
-- New RPC:
--   purchase_avatar_color(p_color_slot text, p_color text)
--     - Validates slot (only 'skinColor' for now)
--     - Validates hex format (#rrggbb, case-insensitive)
--     - Checks and deducts 25 XP
--     - Merges the color key into avatar_data (preserves head/acc/other keys)
--     - Returns { ok, total_xp, avatar_data, xp_spent }
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
  v_color_change_cost constant integer := 25;
  v_student_id   uuid;
  v_current_xp   integer;
  v_current_avatar jsonb;
  v_new_xp       integer;
  v_new_avatar   jsonb;
begin
  -- Validate slot
  if p_color_slot not in ('skinColor') then
    return jsonb_build_object('ok', false, 'error', 'invalid_slot');
  end if;

  -- Validate hex color: must be exactly #rrggbb (6 hex digits)
  if p_color is null or p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'invalid_color');
  end if;

  -- Resolve student
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'not_found');
  end if;

  -- Read current XP and avatar_data
  select sp.total_xp, sp.avatar_data
  into v_current_xp, v_current_avatar
  from public.student_profiles sp
  where sp.id = v_student_id;

  -- Check XP
  if coalesce(v_current_xp, 0) < v_color_change_cost then
    return jsonb_build_object(
      'ok',       false,
      'error',    'insufficient_xp',
      'required', v_color_change_cost,
      'total_xp', coalesce(v_current_xp, 0)
    );
  end if;

  -- Deduct XP and merge color into avatar_data
  v_new_xp     := v_current_xp - v_color_change_cost;
  v_new_avatar := coalesce(v_current_avatar, '{}'::jsonb) || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
  set total_xp   = v_new_xp,
      avatar_data = v_new_avatar
  where id = v_student_id;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_new_xp,
    'avatar_data', v_new_avatar,
    'xp_spent',   v_color_change_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
