-- ============================================================
-- Lerke Bingo v21: Avatar paid color changes (Avatar-9)
-- ============================================================
-- New RPC: purchase_avatar_color(p_color_slot text, p_color text)
--   - Validates p_color_slot (only 'silhouetteColor' supported)
--   - Validates p_color is a valid 6-digit hex color (#rrggbb)
--   - Free if p_color matches current color or is '#ffffff' (default)
--   - 25 XP cost for any other color change
--   - Deducts XP, updates avatar_data.silhouetteColor, returns updated state
-- ============================================================

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
  v_student_id     uuid;
  v_current_xp     integer;
  v_current_avatar jsonb;
  v_current_color  text;
  v_cost           integer := 25;
  v_xp_spent       integer := 0;
  v_valid_slots    text[]  := array['silhouetteColor'];
begin
  -- validate slot
  if not (p_color_slot = any(v_valid_slots)) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespor');
  end if;

  -- validate hex color (#rrggbb only)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig hex-farge');
  end if;

  -- get student profile
  select id, total_xp, coalesce(avatar_data, '{}'::jsonb)
    into v_student_id, v_current_xp, v_current_avatar
  from public.student_profiles
  where auth_user_id = auth.uid();

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ingen elevprofil funnet');
  end if;

  -- current color (null or missing → treat as white)
  v_current_color := coalesce(v_current_avatar ->> p_color_slot, '#ffffff');

  -- free cases: same color as current, or resetting to white (default)
  if lower(p_color) = lower(v_current_color) or lower(p_color) = '#ffffff' then
    v_current_avatar := v_current_avatar || jsonb_build_object(p_color_slot, lower(p_color));
    update public.student_profiles
      set avatar_data = v_current_avatar
    where id = v_student_id;
    return jsonb_build_object(
      'ok',        true,
      'total_xp',  v_current_xp,
      'xp_spent',  0,
      'avatar_data', v_current_avatar
    );
  end if;

  -- paid case: check XP
  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok',    false,
      'error', 'Ikke nok XP (trenger ' || v_cost || ' XP)'
    );
  end if;

  -- deduct XP and update avatar_data
  v_current_avatar := v_current_avatar || jsonb_build_object(p_color_slot, lower(p_color));

  update public.student_profiles
    set total_xp    = total_xp - v_cost,
        avatar_data = v_current_avatar
  where id = v_student_id;

  return jsonb_build_object(
    'ok',        true,
    'total_xp',  v_current_xp - v_cost,
    'xp_spent',  v_cost,
    'avatar_data', v_current_avatar
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
