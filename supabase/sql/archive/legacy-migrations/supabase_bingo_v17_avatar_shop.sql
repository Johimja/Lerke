-- =========================================================
-- V17: Spritesheet avatar shop — XP-unlockable items
-- =========================================================
-- Spritesheet: /media/avatar_faceshapes.png (1024×1280, 4 cols × 5 rows, 256×256/cell)
-- Category: head / face-shape silhouettes
-- avatar_data shape changes to: { "head": "head_basic" }
-- New columns / RPCs:
--   unlocked_avatar_items text[]  — paid items purchased by this student
--   get_avatar_item_cost(p_item_key) — immutable helper, returns XP cost or null for invalid key
--   purchase_avatar_item(p_item_key) — deducts XP, adds to unlocked list
--   get_current_student_profile updated to include unlocked_avatar_items
-- =========================================================

-- =========================================================
-- 1. Add unlocked_avatar_items column
-- =========================================================

alter table public.student_profiles
  add column if not exists unlocked_avatar_items text[] default '{}';

-- =========================================================
-- 2. Immutable cost helper (used server-side for validation)
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    when 'head_basic'          then 0
    when 'head_flat_top'       then 0
    when 'head_widows_peak'    then 50
    when 'head_crew'           then 50
    when 'head_bun'            then 75
    when 'head_bob'            then 75
    when 'head_long'           then 100
    when 'head_side_part'      then 100
    when 'head_wavy'           then 125
    when 'head_spiky'          then 125
    when 'head_afro'           then 300
    when 'head_pigtails'       then 150
    when 'head_full_beard'     then 175
    when 'head_goatee'         then 150
    when 'head_mohawk'         then 225
    when 'head_hat'            then 200
    when 'head_hood'           then 250
    when 'head_helmet'         then 275
    when 'head_cap'            then 175
    when 'head_flat_top_beard' then 300
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;

-- =========================================================
-- 3. RPC: purchase (and unlock) an avatar item with XP
-- =========================================================

create or replace function public.purchase_avatar_item(p_item_key text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_cost       int;
  v_current_xp int;
  v_unlocked   text[];
begin
  v_cost := public.get_avatar_item_cost(p_item_key);

  if v_cost is null then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig gjenstand');
  end if;

  -- Free items are always available, nothing to purchase
  if v_cost = 0 then
    return jsonb_build_object('ok', true, 'free', true);
  end if;

  -- Resolve student
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select total_xp, coalesce(unlocked_avatar_items, '{}')
  into v_current_xp, v_unlocked
  from public.student_profiles
  where id = v_student_id;

  -- Already owned — no charge
  if p_item_key = any(v_unlocked) then
    return jsonb_build_object('ok', true, 'already_owned', true, 'total_xp', v_current_xp, 'unlocked_avatar_items', to_jsonb(v_unlocked));
  end if;

  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP', 'total_xp', v_current_xp, 'needed', v_cost);
  end if;

  update public.student_profiles
  set total_xp             = total_xp - v_cost,
      unlocked_avatar_items = array_append(coalesce(unlocked_avatar_items, '{}'), p_item_key)
  where id = v_student_id
  returning total_xp, unlocked_avatar_items into v_current_xp, v_unlocked;

  return jsonb_build_object(
    'ok',                   true,
    'total_xp',             v_current_xp,
    'unlocked_avatar_items', to_jsonb(v_unlocked),
    'xp_spent',             v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_item(text) to authenticated, anon;

-- =========================================================
-- 4. Update get_current_student_profile to include unlocked_avatar_items
-- =========================================================

create or replace function public.get_current_student_profile()
returns jsonb
language sql
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'student_id',            sp.id,
    'display_name',          sp.display_name,
    'login_code',            sp.login_code,
    'student_code',          sp.student_code,
    'class_id',              c.id,
    'class_name',            c.name,
    'class_code',            c.class_code,
    'total_xp',              coalesce(sp.total_xp, 0),
    'level',                 public.xp_to_level(coalesce(sp.total_xp, 0)),
    'avatar_data',           sp.avatar_data,
    'unlocked_avatar_items', coalesce(sp.unlocked_avatar_items, '{}')
  )
  from public.student_auth_links sal
  join public.student_profiles sp on sp.id = sal.student_id
  join public.classes          c  on c.id  = sp.class_id
  where sal.auth_user_id = auth.uid()
    and sp.status = 'active'
    and c.status  = 'active'
  limit 1;
$$;

grant execute on function public.get_current_student_profile() to authenticated, anon;
