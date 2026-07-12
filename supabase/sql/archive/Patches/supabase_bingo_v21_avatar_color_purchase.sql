-- =========================================================
-- Lerke Bingo v21 — Avatar color purchase
-- Adds server-verified XP-gated color changes for avatar skin color.
-- Cost: 25 XP per color change, saved directly into avatar_data.
-- =========================================================

-- Migration label: v21_avatar_color_purchase

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
  v_student_id  uuid;
  v_current_xp  int;
  v_avatar_data jsonb;
  v_cost        int := 25;
begin
  -- validate slot (only skinColor is supported in v21)
  if p_color_slot is null or p_color_slot not in ('skinColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslot: ' || coalesce(p_color_slot, ''));
  end if;

  -- validate hex color (#RRGGBB, 7 chars)
  if p_color is null or p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat. Bruk #RRGGBB.');
  end if;

  -- resolve current student via auth link
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_current_xp, v_avatar_data
  from public.student_profiles
  where id = v_student_id;

  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok',       false,
      'error',    'Ikke nok XP. Trenger ' || v_cost || ' XP.',
      'total_xp', v_current_xp,
      'needed',   v_cost
    );
  end if;

  -- merge new color into avatar_data and deduct XP
  v_avatar_data := v_avatar_data || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
  set total_xp   = total_xp - v_cost,
      avatar_data = v_avatar_data,
      updated_at  = now()
  where id = v_student_id
  returning total_xp into v_current_xp;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_current_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',   v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
