-- =========================================================
-- V21: Avatar background color purchases (Avatar-9)
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Each color change costs COLOR_COST XP (25).
-- The color is stored in avatar_data under the given slot key.
-- Supported slot: 'bgColor' (avatar card background color).
-- No schema changes needed — avatar_data jsonb column already exists (v13).
-- =========================================================

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  COLOR_COST constant int := 25;
  v_profile_id uuid;
  v_xp int;
  v_avatar jsonb;
  v_new_xp int;
begin
  -- validate color slot
  if p_color_slot not in ('bgColor') then
    return jsonb_build_object('ok', false, 'error', 'Invalid color slot');
  end if;

  -- validate hex color format (#RRGGBB)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Invalid color format');
  end if;

  -- get student profile
  select id, total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_profile_id, v_xp, v_avatar
  from public.student_profiles
  where auth_user_id = auth.uid()
  limit 1;

  if v_profile_id is null then
    return jsonb_build_object('ok', false, 'error', 'Student profile not found');
  end if;

  -- check XP balance
  if v_xp < COLOR_COST then
    return jsonb_build_object('ok', false, 'error', 'Not enough XP');
  end if;

  -- deduct XP and merge new color into avatar_data
  v_new_xp := v_xp - COLOR_COST;
  v_avatar := v_avatar || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
  set total_xp = v_new_xp,
      avatar_data = v_avatar
  where id = v_profile_id;

  return jsonb_build_object(
    'ok',        true,
    'total_xp',  v_new_xp,
    'level',     (floor(v_new_xp::numeric / 100) + 1)::int,
    'avatar_data', v_avatar,
    'xp_spent',  COLOR_COST
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
