-- supabase_bingo_v21_avatar_color_patch.sql
-- Purpose: Avatar-9 — paid color changes.
--   New RPC purchase_avatar_color(p_color_slot, p_color):
--     - Validates slot ('silhouetteColor' or 'accColor')
--     - Validates hex color (^#[0-9a-fA-F]{6}$)
--     - Deducts 25 XP from the student's total_xp
--     - Merges the new color key into avatar_data JSONB
--     - Returns {ok, total_xp, avatar_data, xp_spent} or {ok:false, error}
--
-- avatar_data shape after: { head, acc, silhouetteColor?, accColor? }
-- No schema changes needed — avatar_data is already JSONB (from v13).
-- Run on a DB that already has v13–v20 applied.

-- <<< BEGIN FILE: supabase_bingo_v21_avatar_color_patch.sql

create or replace function public.purchase_avatar_color(
  p_color_slot text,
  p_color      text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_student_id  uuid;
  v_xp          integer;
  v_avatar_data jsonb;
  v_cost        integer := 25;
begin
  -- validate slot
  if p_color_slot not in ('silhouetteColor', 'accColor') then
    return jsonb_build_object('ok', false, 'error', 'Invalid color slot');
  end if;
  -- validate hex color (#rrggbb only)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Invalid color format');
  end if;
  -- get student profile
  select sp.id,
         sp.total_xp,
         coalesce(sp.avatar_data, '{}'::jsonb)
  into   v_student_id, v_xp, v_avatar_data
  from   student_profiles sp
  where  sp.user_id = auth.uid()
  limit  1;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'Student not found');
  end if;
  -- check XP balance
  if v_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP');
  end if;
  -- merge color into avatar_data and deduct XP
  v_avatar_data := v_avatar_data || jsonb_build_object(p_color_slot, p_color);
  update student_profiles
  set    total_xp    = total_xp - v_cost,
         avatar_data  = v_avatar_data
  where  id = v_student_id;
  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_xp - v_cost,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated;

-- <<< END FILE: supabase_bingo_v21_avatar_color_patch.sql
