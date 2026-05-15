-- =========================================================
-- V20: Avatar head accessories — XP costs + purchase support
-- =========================================================
-- Extends get_avatar_item_cost() to cover all 20 acc_* keys.
-- Backfills unlocked_avatar_items for students who already have
-- a non-free accessory equipped via avatar_data.acc so they do
-- not lose access when XP costs go live.
-- No new columns or tables needed.
-- =========================================================

-- =========================================================
-- 1. Replace get_avatar_item_cost to add acc_* entries
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- Head face-shapes (from v17)
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
    -- Head accessories (v20)
    when 'acc_none'        then 0
    when 'acc_headband'    then 25
    when 'acc_beanie'      then 25
    when 'acc_earmuffs'    then 25
    when 'acc_bow'         then 50
    when 'acc_bandana'     then 50
    when 'acc_party_hat'   then 50
    when 'acc_cap'         then 50
    when 'acc_tophat'      then 75
    when 'acc_cowboy'      then 75
    when 'acc_chef_hat'    then 75
    when 'acc_bunny_ears'  then 75
    when 'acc_crown'       then 100
    when 'acc_graduation'  then 100
    when 'acc_sombrero'    then 100
    when 'acc_witch_hat'   then 125
    when 'acc_antlers'     then 125
    when 'acc_tiara'       then 150
    when 'acc_laurel'      then 150
    when 'acc_viking'      then 200
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;

-- =========================================================
-- 2. One-time backfill: grant currently-equipped accessories
--    to students who already have them saved in avatar_data.acc
--    so they keep their accessory when XP costs go live.
-- =========================================================

update public.student_profiles
set unlocked_avatar_items = array_append(
      coalesce(unlocked_avatar_items, '{}'),
      avatar_data->>'acc'
    )
where avatar_data->>'acc' is not null
  and avatar_data->>'acc' <> 'acc_none'
  and public.get_avatar_item_cost(avatar_data->>'acc') > 0
  and not (avatar_data->>'acc' = any(coalesce(unlocked_avatar_items, '{}')));
