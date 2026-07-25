-- =========================================================
-- V21: Paid avatar color changes (Avatar-9)
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Valid slots: 'skinColor' (face/head layer) and 'accColor' (accessory layer).
-- Each color change costs COLOR_CHANGE_COST (25 XP) and is server-verified.
-- Color is saved directly into avatar_data JSON alongside head/acc keys.
-- No schema changes — avatar_data (jsonb, from V13) already holds arbitrary keys.
-- =========================================================

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile_id uuid;
  v_total_xp   integer;
  v_avatar_data jsonb;
  v_cost        integer := 25;
begin
  -- Validate slot
  if p_color_slot not in ('skinColor', 'accColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslodd');
  end if;

  -- Validate hex color (#rrggbb)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge — bruk #rrggbb');
  end if;

  -- Resolve logged-in student profile
  if auth.uid() is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select id, total_xp, coalesce(avatar_data, '{}'::jsonb)
    into v_profile_id, v_total_xp, v_avatar_data
    from student_profiles
   where user_id = auth.uid();

  if v_profile_id is null then
    return jsonb_build_object('ok', false, 'error', 'Elevprofil ikke funnet');
  end if;

  -- XP check
  if v_total_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger ' || v_cost || ')');
  end if;

  -- Deduct XP and write new color into avatar_data
  v_avatar_data := jsonb_set(v_avatar_data, array[p_color_slot], to_jsonb(p_color));

  update student_profiles
     set total_xp    = total_xp - v_cost,
         avatar_data = v_avatar_data
   where id = v_profile_id;

  -- Re-read updated XP to return accurate value
  select total_xp into v_total_xp
    from student_profiles
   where id = v_profile_id;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_total_xp,
    'avatar_data', v_avatar_data
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;
