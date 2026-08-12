-- =========================================================
-- V21: Avatar skin color purchases (Avatar-9)
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Students pay 25 XP to save a custom color for their avatar
-- face shape. The color is stored in avatar_data.skinColor as
-- a normalized #rrggbb hex string. Each save costs XP again,
-- so changing color repeatedly costs XP each time.
--
-- No schema changes needed — avatar_data is already jsonb
-- and save_student_avatar already writes the full object.
-- This RPC validates the slot + hex color, deducts XP, and
-- updates avatar_data in one atomic transaction.
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
  v_profile  student_profiles%rowtype;
  v_cost     int := 25;
  v_valid_slots text[] := array['skinColor'];
  v_avatar_data jsonb;
begin
  -- Resolve the calling student's profile
  select sp.* into v_profile
  from student_profiles sp
  where sp.auth_user_id = auth.uid()
  limit 1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Ingen elevprofil funnet');
  end if;

  -- Validate color slot
  if not (p_color_slot = any(v_valid_slots)) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeplass');
  end if;

  -- Validate hex color format: must be exactly #rrggbb
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat (forventet #rrggbb)');
  end if;

  -- Check XP balance
  if v_profile.total_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger ' || v_cost || ' XP)');
  end if;

  -- Update avatar_data with the new color and deduct XP atomically
  v_avatar_data := coalesce(v_profile.avatar_data, '{}'::jsonb);
  v_avatar_data := jsonb_set(v_avatar_data, array[p_color_slot], to_jsonb(p_color));

  update student_profiles
  set total_xp   = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_profile.id;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_profile.total_xp - v_cost,
    'color_slot', p_color_slot,
    'color',      p_color
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
