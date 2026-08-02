-- V21: Avatar paid color changes (25 XP per head color save)
--
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC:
--   - Validates color slot name (currently only 'headColor')
--   - Validates hex color format (#rrggbb)
--   - Checks student has >= 25 XP
--   - Deducts 25 XP and updates avatar_data with the new color
--   - Returns {ok, total_xp, level, avatar_data, xp_spent} or {ok:false, error}
--
-- No schema changes needed — avatar_data is already a jsonb column from v13.
-- Migration label: v21_avatar_color

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
) returns jsonb
language plpgsql security definer
set search_path = public
as $$
declare
  v_allowed_slots text[] := array['headColor'];
  v_cost          integer := 25;
  v_color_clean   text;
  v_student       record;
  v_new_avatar    jsonb;
begin
  -- Validate slot
  if p_color_slot is null or not (p_color_slot = any(v_allowed_slots)) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslot');
  end if;

  -- Validate hex color (#rrggbb exactly)
  v_color_clean := lower(trim(p_color));
  if v_color_clean !~ '^#[0-9a-f]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge — bruk #rrggbb');
  end if;

  -- Load student profile for the current user
  select sp.*
  into   v_student
  from   student_profiles sp
  where  sp.user_id = auth.uid()
  limit  1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Fant ikke elevprofil');
  end if;

  -- Check XP balance
  if v_student.total_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger ' || v_cost || ')');
  end if;

  -- Merge new color into avatar_data
  v_new_avatar := coalesce(v_student.avatar_data, '{}'::jsonb)
                  || jsonb_build_object(p_color_slot, v_color_clean);

  update student_profiles
  set    total_xp   = total_xp - v_cost,
         avatar_data = v_new_avatar
  where  user_id = auth.uid();

  return jsonb_build_object(
    'ok',        true,
    'total_xp',  v_student.total_xp - v_cost,
    'level',     floor((v_student.total_xp - v_cost)::numeric / 100) + 1,
    'avatar_data', v_new_avatar,
    'xp_spent',  v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
