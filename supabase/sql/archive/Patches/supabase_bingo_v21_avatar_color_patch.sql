-- =========================================================
-- Avatar-9: paid color changes (v21)
-- Apply on top of v20 (avatar accessory costs).
-- =========================================================
-- New RPC: purchase_avatar_color(p_color_slot, p_color)
--   Valid slots: 'skinColor'
--   Validates hex color format (#rrggbb)
--   Cost: 25 XP per save (always charged, even for same color)
--   Merges the new color key into avatar_data jsonb
--   Returns: {ok, total_xp, avatar_data, xp_spent} or {ok:false, error}
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
  v_student_id uuid;
  v_current_xp int;
  v_avatar     jsonb;
  v_new_avatar jsonb;
  v_cost       int := 25;
  v_valid_slots text[] := array['skinColor'];
begin
  -- Validate slot
  if p_color_slot != all(v_valid_slots) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslot');
  end if;

  -- Validate hex color: must be exactly #rrggbb
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat');
  end if;

  -- Resolve student via student_auth_links
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  -- Fetch current XP and avatar_data
  select total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_current_xp, v_avatar
  from public.student_profiles
  where id = v_student_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Ingen elevprofil funnet');
  end if;

  -- Check XP balance
  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok',      false,
      'error',   'Ikke nok XP',
      'total_xp', v_current_xp,
      'needed',  v_cost
    );
  end if;

  -- Merge new color slot into avatar_data and deduct XP
  v_new_avatar := v_avatar || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
  set total_xp   = total_xp - v_cost,
      avatar_data = v_new_avatar,
      updated_at  = now()
  where id = v_student_id
  returning total_xp into v_current_xp;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_current_xp,
    'avatar_data', v_new_avatar,
    'xp_spent',   v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
