-- =========================================================
-- V20 patch: Avatar-8 — head accessories XP costs
--
-- Extends get_avatar_item_cost to recognise acc_* keys with
-- tiered XP costs. Free accessories: acc_none, acc_cap,
-- acc_beanie, acc_headband. All others cost 50–250 XP.
--
-- Also backfills unlocked_avatar_items for any student who
-- already has a paid accessory saved in avatar_data (those
-- students equipped it when all accessories were still free
-- in Avatar-7; they keep access without re-purchasing).
--
-- Apply to any DB that has v17+ (unlocked_avatar_items exists)
-- and v18+ (avatar_faceshapes catalogue in place).
-- =========================================================

-- 1. Replace cost helper — adds acc_* entries, keeps head_* unchanged
create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- Head shapes (unchanged from v18_avatar_faceshapes)
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
    -- Head accessories (new in v20)
    when 'acc_none'            then 0
    when 'acc_cap'             then 0
    when 'acc_beanie'          then 0
    when 'acc_headband'        then 0
    when 'acc_party_hat'       then 50
    when 'acc_bow'             then 50
    when 'acc_earmuffs'        then 50
    when 'acc_bandana'         then 75
    when 'acc_graduation'      then 75
    when 'acc_chef_hat'        then 75
    when 'acc_bunny_ears'      then 75
    when 'acc_cowboy'          then 100
    when 'acc_tophat'          then 100
    when 'acc_antlers'         then 100
    when 'acc_sombrero'        then 125
    when 'acc_laurel'          then 150
    when 'acc_tiara'           then 150
    when 'acc_witch_hat'       then 175
    when 'acc_viking'          then 200
    when 'acc_crown'           then 250
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;

-- 2. Backfill: students who already have a paid accessory equipped
-- keep it in unlocked_avatar_items so they don't lose access.
-- Free accessories (acc_none, acc_cap, acc_beanie, acc_headband)
-- don't need backfilling because isFree=true in the frontend.
update public.student_profiles
set unlocked_avatar_items = array_append(
  coalesce(unlocked_avatar_items, '{}'),
  avatar_data->>'acc'
)
where
  avatar_data is not null
  and avatar_data->>'acc' is not null
  and avatar_data->>'acc' not in ('acc_none', 'acc_cap', 'acc_beanie', 'acc_headband')
  and not (avatar_data->>'acc' = any(coalesce(unlocked_avatar_items, '{}')));
