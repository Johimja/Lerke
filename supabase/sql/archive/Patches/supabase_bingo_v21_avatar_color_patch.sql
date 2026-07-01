-- Lerke Bingo v21: Avatar paid color changes
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Valid slots: 'skinColor', 'accColor'
-- Cost: 25 XP per change. White (#ffffff) is always free. Same color as current = 0 cost.
-- Returns {ok, total_xp, avatar_data, xp_spent}

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color text
) returns jsonb language plpgsql security definer as $$
declare
  v_student_id uuid;
  v_xp integer;
  v_avatar_data jsonb;
  v_cost integer := 25;
  v_valid_slots text[] := array['skinColor','accColor'];
  v_current_color text;
  v_norm_color text;
begin
  -- Resolve student profile for current auth user
  select id, total_xp, avatar_data
  into v_student_id, v_xp, v_avatar_data
  from public.student_profiles
  where auth_user_id = auth.uid();

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  -- Validate slot
  if not (p_color_slot = any(v_valid_slots)) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespor');
  end if;

  -- Validate hex color (#rrggbb)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargekode');
  end if;

  v_norm_color := lower(p_color);
  v_avatar_data := coalesce(v_avatar_data, '{}'::jsonb);
  v_current_color := lower(coalesce(v_avatar_data->>p_color_slot, '#ffffff'));

  -- Same color as current: no cost, no-op
  if v_norm_color = v_current_color then
    return jsonb_build_object('ok', true, 'total_xp', v_xp, 'avatar_data', v_avatar_data, 'xp_spent', 0);
  end if;

  -- White is always free
  if v_norm_color = '#ffffff' then
    v_cost := 0;
  end if;

  -- Check XP
  if v_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (' || v_cost || ' XP kreves)');
  end if;

  -- Update avatar_data and deduct XP
  v_avatar_data := v_avatar_data || jsonb_build_object(p_color_slot, v_norm_color);

  update public.student_profiles
  set total_xp = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_student_id;

  return jsonb_build_object(
    'ok', true,
    'total_xp', v_xp - v_cost,
    'avatar_data', v_avatar_data,
    'xp_spent', v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
