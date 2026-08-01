-- =========================================================
-- V21: Avatar paid color changes (Avatar-9)
-- =========================================================
-- Adds purchase_avatar_color(p_color_slot, p_color) RPC.
-- Valid slots: 'skinColor' (face/body silhouette), 'accColor' (head accessory).
-- Cost: 25 XP per save. Each save overwrites the previous color for that slot.
-- Color is validated as a 6-digit hex (#rrggbb, case-insensitive).
-- Updates avatar_data jsonb in-place and returns updated XP + avatar_data.
-- No schema changes required — avatar_data column already exists from v13.
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
  v_student_id   uuid;
  v_profile_id   uuid;
  v_total_xp     integer;
  v_avatar_data  jsonb;
  v_cost         integer := 25;
  v_valid_slots  text[] := array['skinColor','accColor'];
begin
  -- Validate slot
  if p_color_slot != all(v_valid_slots) then
    return jsonb_build_object('ok', false, 'error', 'Invalid color slot');
  end if;

  -- Validate hex color format  (#rrggbb)
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Invalid color format');
  end if;

  -- Require auth
  v_student_id := auth.uid();
  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Not authenticated');
  end if;

  -- Load student profile
  select id, total_xp, avatar_data
    into v_profile_id, v_total_xp, v_avatar_data
    from student_profiles
   where auth_user_id = v_student_id
   limit 1;

  if v_profile_id is null then
    return jsonb_build_object('ok', false, 'error', 'Student profile not found');
  end if;

  -- Check XP
  if v_total_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Not enough XP');
  end if;

  -- Merge color into avatar_data and deduct XP atomically
  v_avatar_data := coalesce(v_avatar_data, '{}'::jsonb) || jsonb_build_object(p_color_slot, p_color);

  update student_profiles
     set total_xp    = total_xp - v_cost,
         avatar_data = v_avatar_data
   where id = v_profile_id
  returning total_xp into v_total_xp;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_total_xp,
    'level',       floor(v_total_xp::numeric / 100) + 1,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
