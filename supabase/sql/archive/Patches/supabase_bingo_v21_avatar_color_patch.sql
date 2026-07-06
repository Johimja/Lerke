-- Avatar-9: Paid color changes (v21)
-- RPC: purchase_avatar_color(p_color_slot, p_color)
--   Validates the color slot (skinColor or accColor), validates hex color,
--   deducts COLOR_CHANGE_COST XP, stores the color in avatar_data, and
--   returns { ok, total_xp, avatar_data, xp_spent } on success
--   or { ok: false, error } on failure.
-- Cost: 25 XP per color save.

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
  v_student_id   uuid;
  v_total_xp     integer;
  v_avatar_data  jsonb;
  v_color_cost   constant integer := 25;
begin
  -- Validate slot
  if p_color_slot not in ('skinColor', 'accColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargesport: ' || coalesce(p_color_slot, ''));
  end if;

  -- Validate hex color (#rrggbb)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge: ' || coalesce(p_color, ''));
  end if;

  -- Resolve student profile
  select id, total_xp, coalesce(avatar_data, '{}'::jsonb)
  into   v_student_id, v_total_xp, v_avatar_data
  from   student_profiles
  where  auth_user_id = auth.uid()
  limit  1;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Elevprofil ikke funnet');
  end if;

  -- Check XP
  if v_total_xp < v_color_cost then
    return jsonb_build_object(
      'ok', false,
      'error', 'Ikke nok XP – du trenger ' || v_color_cost || ' XP'
    );
  end if;

  -- Deduct XP and merge color slot into avatar_data
  update student_profiles
  set
    total_xp   = total_xp - v_color_cost,
    avatar_data = coalesce(avatar_data, '{}'::jsonb) || jsonb_build_object(p_color_slot, p_color)
  where id = v_student_id
  returning total_xp, avatar_data into v_total_xp, v_avatar_data;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_total_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',   v_color_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
