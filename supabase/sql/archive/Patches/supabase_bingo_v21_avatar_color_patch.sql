-- =========================================================
-- V21: Avatar-9 — Paid color changes
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Cost: 25 XP per unique color change.
-- White (#ffffff) and null (reset) are always free.
-- color_slot: 'skinColor' only for now; extend later for hair/prop.
-- No schema changes — avatar_data jsonb already exists (v13).
-- =========================================================

begin;

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text   -- normalized hex e.g. '#ff6347', or null to reset
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cost     integer := 25;
  v_profile  student_profiles%rowtype;
  v_new_data jsonb;
  v_is_free  boolean;
begin
  -- Validate slot
  if p_color_slot not in ('skinColor') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeslot');
  end if;

  -- Validate color format (null = reset to default white)
  if p_color is not null and p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat');
  end if;

  -- Get student profile for current auth user
  select sp.* into v_profile
    from student_profiles sp
   where sp.user_id = auth.uid();

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Profil ikke funnet');
  end if;

  -- Free if resetting to white/null, or same color already stored
  v_is_free := (
    p_color is null
    or lower(p_color) = '#ffffff'
    or (
      v_profile.avatar_data is not null
      and v_profile.avatar_data->>'skinColor' = p_color
    )
  );

  if not v_is_free and v_profile.total_xp < v_cost then
    return jsonb_build_object(
      'ok', false,
      'error', 'Ikke nok XP (' || v_cost::text || ' XP kreves)'
    );
  end if;

  -- Build updated avatar_data
  v_new_data := coalesce(v_profile.avatar_data, '{}'::jsonb);
  if p_color is null or lower(p_color) = '#ffffff' then
    v_new_data := v_new_data - p_color_slot;
  else
    v_new_data := jsonb_set(v_new_data, array[p_color_slot], to_jsonb(p_color));
  end if;

  -- Apply update (with or without XP deduction)
  if v_is_free then
    update student_profiles
       set avatar_data = v_new_data
     where id = v_profile.id;
  else
    update student_profiles
       set avatar_data = v_new_data,
           total_xp   = total_xp - v_cost
     where id = v_profile.id;
    v_profile.total_xp := v_profile.total_xp - v_cost;
  end if;

  return jsonb_build_object(
    'ok',         true,
    'total_xp',   v_profile.total_xp,
    'level',      floor(v_profile.total_xp::numeric / 100) + 1,
    'avatar_data', v_new_data,
    'xp_spent',   case when v_is_free then 0 else v_cost end
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;

commit;
