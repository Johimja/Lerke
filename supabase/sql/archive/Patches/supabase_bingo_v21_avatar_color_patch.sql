-- supabase_bingo_v21_avatar_color_patch.sql
-- Avatar-9: paid color changes
--
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC:
--   - Valid slots: 'skinColor', 'accColor'
--   - Validates hex color (#rrggbb format)
--   - Costs 25 XP per save (overwrites previous color, every save costs)
--   - Updates avatar_data JSONB in-place
--   - Returns {ok, total_xp, avatar_data, xp_spent} on success
--   - Returns {ok:false, error} on failure
--
-- No schema changes needed — avatar_data (jsonb) already exists from v13.
-- purchase_avatar_item and save_student_avatar already work generically.

create or replace function public.purchase_avatar_color(p_color_slot text, p_color text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id  uuid;
  v_profile_id  uuid;
  v_xp          integer;
  v_avatar      jsonb;
  v_cost        integer := 25;
begin
  -- validate slot
  if p_color_slot not in ('skinColor','accColor') then
    return jsonb_build_object('ok',false,'error','Ugyldig fargeslot');
  end if;

  -- validate hex color (#rrggbb, exactly 7 chars)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok',false,'error','Ugyldig farge — bruk #rrggbb format');
  end if;

  -- require authentication
  v_student_id := auth.uid();
  if v_student_id is null then
    return jsonb_build_object('ok',false,'error','Ikke innlogget');
  end if;

  -- fetch student profile
  select id, total_xp, coalesce(avatar_data, '{}'::jsonb)
  into   v_profile_id, v_xp, v_avatar
  from   student_profiles
  where  user_id = v_student_id
  limit  1;

  if v_profile_id is null then
    return jsonb_build_object('ok',false,'error','Ingen studentprofil funnet');
  end if;

  -- check XP
  if v_xp < v_cost then
    return jsonb_build_object('ok',false,'error','Ikke nok XP — trenger ' || v_cost || ' XP');
  end if;

  -- merge color into avatar_data and deduct XP
  v_avatar := v_avatar || jsonb_build_object(p_color_slot, p_color);

  update student_profiles
  set    total_xp   = total_xp - v_cost,
         avatar_data = v_avatar
  where  id = v_profile_id;

  return jsonb_build_object(
    'ok',        true,
    'total_xp',  v_xp - v_cost,
    'avatar_data', v_avatar,
    'xp_spent',  v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text,text) to authenticated;
