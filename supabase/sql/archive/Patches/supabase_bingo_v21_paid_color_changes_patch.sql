-- supabase_bingo_v21_paid_color_changes_patch.sql
-- Avatar-9: Paid color changes
--
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Valid slots: skinColor, accColor. Cost: 25 XP per change.
-- Updates avatar_data directly (no new column needed — avatar_data is jsonb from v13).
-- Returns {ok, xp_spent, total_xp, avatar_data} on success.
--
-- No schema changes needed — avatar_data jsonb already exists on student_profiles (v13).
-- Apply to databases that already have v13+ applied.

-- >>> BEGIN FILE: supabase_bingo_v21_paid_color_changes_patch.sql

drop function if exists public.purchase_avatar_color(text, text);

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
) returns json language plpgsql security definer as $$
declare
  v_cost         integer := 25;
  v_student_id   uuid;
  v_xp           integer;
  v_avatar_data  jsonb;
  v_valid_slots  text[] := array['skinColor','accColor'];
begin
  -- Validate slot
  if not (p_color_slot = any(v_valid_slots)) then
    return json_build_object('ok', false, 'error', 'invalid_slot');
  end if;

  -- Validate hex color: #rgb or #rrggbb
  if p_color !~ '^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$' then
    return json_build_object('ok', false, 'error', 'invalid_color');
  end if;

  -- Get student profile
  select id, total_xp, avatar_data
  into   v_student_id, v_xp, v_avatar_data
  from   public.student_profiles
  where  user_id = auth.uid()
  limit  1;

  if not found then
    return json_build_object('ok', false, 'error', 'student_not_found');
  end if;

  -- Check XP
  if v_xp < v_cost then
    return json_build_object('ok', false, 'error', 'insufficient_xp');
  end if;

  -- Merge color into avatar_data and deduct XP
  v_avatar_data := coalesce(v_avatar_data, '{}'::jsonb) || jsonb_build_object(p_color_slot, p_color);

  update public.student_profiles
  set    total_xp    = total_xp - v_cost,
         avatar_data = v_avatar_data
  where  id = v_student_id;

  return json_build_object(
    'ok',          true,
    'xp_spent',    v_cost,
    'total_xp',    v_xp - v_cost,
    'avatar_data', v_avatar_data
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;

-- <<< END FILE: supabase_bingo_v21_paid_color_changes_patch.sql
