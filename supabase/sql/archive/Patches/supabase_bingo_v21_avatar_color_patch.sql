-- V21 — Avatar colour changes (paid)
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
--
-- Rules:
--   - Supported slots: 'headColor' (others rejected)
--   - Color must be a 7-char hex string: #rrggbb
--   - No-op (free) if the new color equals the currently saved color
--   - Default current color (when no color saved yet) is treated as #ffffff
--   - Every actual change costs COLOR_CHANGE_COST (25) XP
--   - Not enough XP → returns {ok:false, error:'For lite XP'}
--
-- Returns: {ok, total_xp, level, avatar_data, xp_spent}
--          or {ok:false, error}

-- Migration label: v21_avatar_color

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
  COLOR_CHANGE_COST constant integer := 25;
  VALID_SLOTS       constant text[]  := array['headColor'];

  v_user_id     uuid   := auth.uid();
  v_student_id  bigint;
  v_xp          integer;
  v_avatar_data jsonb;
  v_current_col text;
  v_new_avatar  jsonb;
  v_xp_spent    integer := 0;
begin
  -- Validate slot
  if p_color_slot != all(VALID_SLOTS) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargefelt');
  end if;

  -- Validate hex color (#rrggbb)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat');
  end if;

  -- Fetch student profile
  select id, total_xp, avatar_data
    into v_student_id, v_xp, v_avatar_data
    from public.student_profiles
   where auth_user_id = v_user_id
   limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Elevprofil ikke funnet');
  end if;

  -- Current color (default white when not yet set)
  v_current_col := coalesce(v_avatar_data ->> p_color_slot, '#ffffff');

  -- No-op if same color (case-insensitive)
  if lower(v_current_col) = lower(p_color) then
    return jsonb_build_object(
      'ok',         true,
      'total_xp',   v_xp,
      'level',      floor(v_xp::numeric / 100)::int + 1,
      'avatar_data', coalesce(v_avatar_data, '{}'::jsonb),
      'xp_spent',   0
    );
  end if;

  -- Check XP for an actual color change
  if v_xp < COLOR_CHANGE_COST then
    return jsonb_build_object('ok', false, 'error', 'For lite XP');
  end if;

  -- Deduct XP and save new color
  v_xp_spent   := COLOR_CHANGE_COST;
  v_xp         := v_xp - COLOR_CHANGE_COST;
  v_new_avatar := coalesce(v_avatar_data, '{}'::jsonb)
               || jsonb_build_object(p_color_slot, lower(p_color));

  update public.student_profiles
     set total_xp    = v_xp,
         avatar_data = v_new_avatar
   where id = v_student_id;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_xp,
    'level',      floor(v_xp::numeric / 100)::int + 1,
    'avatar_data', v_new_avatar,
    'xp_spent',   v_xp_spent
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text)
  to authenticated, anon;
