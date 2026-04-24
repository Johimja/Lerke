-- =========================================================
-- Lerke Bingo v19 — Head Accessory XP Costs (Avatar-8)
-- =========================================================
-- Extends get_avatar_item_cost to cover acc_* keys.
-- The existing purchase_avatar_item RPC handles all keys
-- that get_avatar_item_cost returns non-null for, so no
-- changes to that RPC are needed.
-- Also grandfathers currently-equipped accessories into
-- unlocked_avatar_items so existing students keep them.
-- =========================================================

-- 1. Extend get_avatar_item_cost with accessory costs
-- Note: this is not IMMUTABLE now that it is STABLE, but
-- it remains deterministic (pure case lookup). We keep it
-- IMMUTABLE because it is a pure function with no side effects.

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- Head face-shapes (20 items)
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
    -- Head accessories (20 items)
    when 'acc_none'        then 0    -- always free
    when 'acc_headband'    then 50
    when 'acc_beanie'      then 50
    when 'acc_cap'         then 50
    when 'acc_party_hat'   then 75
    when 'acc_earmuffs'    then 75
    when 'acc_bow'         then 75
    when 'acc_tophat'      then 100
    when 'acc_bandana'     then 100
    when 'acc_chef_hat'    then 100
    when 'acc_cowboy'      then 125
    when 'acc_sombrero'    then 125
    when 'acc_antlers'     then 125
    when 'acc_graduation'  then 150
    when 'acc_witch_hat'   then 150
    when 'acc_bunny_ears'  then 150
    when 'acc_laurel'      then 175
    when 'acc_viking'      then 200
    when 'acc_tiara'       then 225
    when 'acc_crown'       then 250
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;

-- =========================================================
-- 2. Grandfather currently-equipped accessories
-- Any student who already has a non-free accessory equipped
-- in avatar_data gets it added to unlocked_avatar_items so
-- they don't lose it when costs take effect.
-- =========================================================

update public.student_profiles
set unlocked_avatar_items = array_append(
  coalesce(unlocked_avatar_items, '{}'),
  avatar_data->>'acc'
)
where avatar_data->>'acc' is not null
  and avatar_data->>'acc' <> ''
  and avatar_data->>'acc' <> 'acc_none'
  and not (avatar_data->>'acc' = any(coalesce(unlocked_avatar_items, '{}')));
