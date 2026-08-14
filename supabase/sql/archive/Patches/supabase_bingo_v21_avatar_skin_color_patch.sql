-- V21: Avatar skin color — purchase_avatar_color RPC
-- Allows students to spend 25 XP to set a custom skin color (or other color slots)
-- on their avatar. The color is stored in avatar_data as a hex string.
-- Applied: 2026-08-14

CREATE OR REPLACE FUNCTION purchase_avatar_color(
  p_color_slot text,
  p_color      text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_student_id  uuid;
  v_profile     student_profiles%rowtype;
  v_cost        int := 25;
  v_allowed     text[] := ARRAY['skinColor'];
BEGIN
  -- Validate slot
  IF NOT (p_color_slot = ANY(v_allowed)) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslot');
  END IF;

  -- Validate hex colour (#RRGGBB)
  IF p_color !~ '^#[0-9a-fA-F]{6}$' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Ugyldig farge – bruk #RRGGBB');
  END IF;

  -- Resolve student via auth link
  SELECT sp.id INTO v_student_id
  FROM student_auth_links sal
  JOIN student_profiles sp ON sp.id = sal.student_profile_id
  WHERE sal.auth_user_id = auth.uid();

  IF v_student_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'Ikke logget inn');
  END IF;

  SELECT * INTO v_profile FROM student_profiles WHERE id = v_student_id;

  -- Check XP
  IF v_profile.total_xp < v_cost THEN
    RETURN jsonb_build_object(
      'ok',    false,
      'error', 'Ikke nok XP (trenger ' || v_cost || ' XP, har ' || v_profile.total_xp || ')'
    );
  END IF;

  -- Deduct XP and merge color into avatar_data
  UPDATE student_profiles
  SET
    total_xp   = total_xp - v_cost,
    avatar_data = COALESCE(avatar_data, '{}'::jsonb)
                  || jsonb_build_object(p_color_slot, lower(p_color))
  WHERE id = v_student_id
  RETURNING total_xp, avatar_data
  INTO v_profile.total_xp, v_profile.avatar_data;

  RETURN jsonb_build_object(
    'ok',        true,
    'total_xp',  v_profile.total_xp,
    'level',     xp_to_level(v_profile.total_xp),
    'avatar_data', v_profile.avatar_data,
    'xp_spent',  v_cost,
    'slot',      p_color_slot,
    'color',     lower(p_color)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION purchase_avatar_color(text, text) TO authenticated;
