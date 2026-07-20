-- supabase_bingo_v21_avatar_color_patch.sql
-- Avatar-9: paid color changes
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Costs 25 XP per call. Slot 'skin' → avatar_data.skinColor.
-- Validates hex color format. Updates avatar_data in-place and deducts XP.
-- Returns {ok, total_xp, avatar_data, xp_spent} or {ok:false, error}.

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_profile_id  uuid;
  v_current_xp  integer;
  v_avatar_data jsonb;
  v_cost        integer := 25;
begin
  if p_color_slot not in ('skin') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespor');
  end if;

  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge');
  end if;

  select id, total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_profile_id, v_current_xp, v_avatar_data
  from public.student_profiles
  where auth_user_id = auth.uid()
  limit 1;

  if v_profile_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ingen elevkonto funnet');
  end if;

  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger ' || v_cost || ')');
  end if;

  v_avatar_data := v_avatar_data || jsonb_build_object(p_color_slot || 'Color', p_color);

  update public.student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = v_avatar_data
  where id = v_profile_id;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp - v_cost,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
