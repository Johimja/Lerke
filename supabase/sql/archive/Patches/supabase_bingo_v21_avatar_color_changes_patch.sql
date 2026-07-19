-- =========================================================
-- V21: Paid avatar color changes (Avatar-9)
-- =========================================================
-- Adds `purchase_avatar_color(p_color_slot, p_color)` RPC.
-- Students spend 25 XP to save a color for a named slot; the
-- color is stored inside avatar_data (e.g. avatar_data.skinColor).
-- Changing the same slot again costs another 25 XP.
-- Only the 'skin' slot is accepted for now; extra slots can be
-- added to the valid-slots check as new prop layers ship.
-- No schema changes — avatar_data jsonb already exists from V13.
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
  v_cost         int  := 25;
  v_valid_slots  text[] := array['skin'];
  v_student_id   uuid;
  v_profile      student_profiles%rowtype;
  v_avatar_data  jsonb;
  v_slot_key     text;
begin
  -- Validate slot
  if not (p_color_slot = any(v_valid_slots)) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslot');
  end if;

  -- Validate hex color (#rrggbb only — normalise to lower-case)
  if not (lower(p_color) ~ '^#[0-9a-f]{6}$') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge (bruk #rrggbb-format)');
  end if;

  -- Resolve the jsonb key name for the slot  (skin → skinColor)
  v_slot_key := p_color_slot || 'Color';

  -- Find student profile for the current auth user via student_auth_links
  select sal.student_id into v_student_id
  from student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Elevprofil ikke funnet');
  end if;

  select * into v_profile from student_profiles where id = v_student_id;

  -- Check XP
  if v_profile.total_xp < v_cost then
    return jsonb_build_object(
      'ok',    false,
      'error', format('Ikke nok XP — trenger %s XP', v_cost)
    );
  end if;

  -- Merge color into avatar_data
  v_avatar_data := coalesce(v_profile.avatar_data, '{}'::jsonb)
                   || jsonb_build_object(v_slot_key, lower(p_color));

  update student_profiles
  set total_xp   = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_student_id;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_profile.total_xp - v_cost,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
