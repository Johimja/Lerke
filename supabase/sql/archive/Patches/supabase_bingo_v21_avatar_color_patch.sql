-- =========================================================
-- V21: Paid avatar skin color changes (Avatar-9)
-- =========================================================
-- Adds `purchase_avatar_color(p_color_slot, p_color)` RPC.
-- Cost: 25 XP per color save; resetting to default (null) is free.
-- No-op (0 XP) when the stored color already matches the requested one.
-- Valid slots: 'skinColor' (extendable to 'accColor' etc. in later patches).
-- =========================================================

-- >>> BEGIN FILE: supabase_bingo_v21_avatar_color_patch.sql

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text  -- '#RRGGBB' to apply a custom color, or null to reset to default
)
returns jsonb
language plpgsql security definer
as $$
declare
  v_valid_slots text[]  := array['skinColor'];
  v_color_cost  int     := 25;
  v_uid         uuid    := auth.uid();
  v_student_id  uuid;
  v_current_xp  int;
  v_avatar_data jsonb;
  v_current_color text;
  v_cost        int;
begin
  -- Validate slot
  if not (p_color_slot = any(v_valid_slots)) then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespor');
  end if;

  -- Validate hex color (allow null = reset to default)
  if p_color is not null and p_color !~ '^#[0-9A-Fa-f]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge');
  end if;

  -- Resolve student
  select student_id into v_student_id
  from public.student_auth_links
  where auth_user_id = v_uid;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget som elev');
  end if;

  -- Fetch current state
  select total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_current_xp, v_avatar_data
  from public.student_profiles
  where id = v_student_id;

  v_current_color := v_avatar_data ->> p_color_slot;

  -- No-op check (requested color is already saved)
  if v_current_color is not distinct from p_color then
    return jsonb_build_object(
      'ok',         true,
      'xp_spent',   0,
      'total_xp',   v_current_xp,
      'avatar_data', v_avatar_data
    );
  end if;

  -- Resetting to null is always free; setting a custom color costs XP
  v_cost := case when p_color is null then 0 else v_color_cost end;

  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok',       false,
      'error',    'Ikke nok XP',
      'total_xp', v_current_xp,
      'needed',   v_cost
    );
  end if;

  -- Apply: null removes the key (resets to default), string sets it
  if p_color is null then
    v_avatar_data := v_avatar_data - p_color_slot;
  else
    v_avatar_data := jsonb_set(v_avatar_data, array[p_color_slot], to_jsonb(p_color));
  end if;

  update public.student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_student_id;

  return jsonb_build_object(
    'ok',          true,
    'xp_spent',    v_cost,
    'total_xp',    v_current_xp - v_cost,
    'avatar_data', v_avatar_data
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;

-- <<< END FILE: supabase_bingo_v21_avatar_color_patch.sql
