-- ===========================================================================
-- LERKE BINGO — V21 PATCH: Avatar body color purchases
-- ===========================================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Students pay 25 XP per color change. Color is stored in avatar_data JSONB.
-- Currently supported slot: 'body' → stored as avatar_data.bodyColor.
-- Runs on top of v20 (accessory costs). Safe to re-run (create or replace).
-- ===========================================================================

-- Mark migration
insert into public.schema_migrations(version) values ('v21_avatar_color')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- purchase_avatar_color
-- ---------------------------------------------------------------------------
create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
) returns jsonb language plpgsql security definer as $$
declare
  v_student_id  uuid;
  v_current_xp  integer;
  v_avatar_data jsonb;
  v_cost        integer := 25;
begin
  -- validate slot
  if p_color_slot not in ('body') then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargespalte');
  end if;

  -- validate hex color format: exactly #rrggbb
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge (bruk #rrggbb)');
  end if;

  -- fetch student profile
  select id, total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_student_id, v_current_xp, v_avatar_data
  from public.student_profiles
  where auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Elev ikke funnet');
  end if;

  -- check XP balance
  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP (trenger ' || v_cost || ')');
  end if;

  -- deduct XP and merge color into avatar_data
  v_current_xp  := v_current_xp - v_cost;
  v_avatar_data := v_avatar_data || jsonb_build_object('bodyColor', lower(p_color));

  update public.student_profiles
  set total_xp    = v_current_xp,
      avatar_data = v_avatar_data
  where id = v_student_id;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'level',       floor(v_current_xp::float / 100)::int + 1,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
-- <<< END FILE: supabase_bingo_v21_avatar_color_patch.sql
