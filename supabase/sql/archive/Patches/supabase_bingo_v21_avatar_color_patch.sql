-- Avatar-9: Paid color changes
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC
-- Deducts 25 XP per color change, saves color into avatar_data
-- Valid slots: 'skinColor' (more slots added in future Avatar versions)

CREATE OR REPLACE FUNCTION purchase_avatar_color(
  p_color_slot text,
  p_color      text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_profile_id  uuid;
  v_total_xp    integer;
  v_avatar_data jsonb;
  v_cost        integer := 25;
  v_valid_slots text[]  := ARRAY['skinColor'];
BEGIN
  SELECT id, total_xp, avatar_data
  INTO v_profile_id, v_total_xp, v_avatar_data
  FROM student_profiles
  WHERE auth_user_id = auth.uid();

  IF v_profile_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Ikke logget inn');
  END IF;

  IF NOT (p_color_slot = ANY(v_valid_slots)) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslott');
  END IF;

  -- Accept #rrggbb only
  IF NOT (lower(p_color) ~ '^#[0-9a-f]{6}$') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Ugyldig fargeverdi');
  END IF;

  -- Same color already saved — no charge
  IF v_avatar_data IS NOT NULL AND (v_avatar_data->>(p_color_slot)) = lower(p_color) THEN
    RETURN jsonb_build_object(
      'ok',         true,
      'total_xp',   v_total_xp,
      'avatar_data', v_avatar_data,
      'xp_spent',   0
    );
  END IF;

  IF v_total_xp < v_cost THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger 25 XP)');
  END IF;

  v_avatar_data := COALESCE(v_avatar_data, '{}'::jsonb)
                || jsonb_build_object(p_color_slot, lower(p_color));

  UPDATE student_profiles
  SET total_xp    = total_xp - v_cost,
      avatar_data = v_avatar_data
  WHERE id = v_profile_id;

  RETURN jsonb_build_object(
    'ok',         true,
    'total_xp',   v_total_xp - v_cost,
    'avatar_data', v_avatar_data,
    'xp_spent',   v_cost
  );
END;
$$;
