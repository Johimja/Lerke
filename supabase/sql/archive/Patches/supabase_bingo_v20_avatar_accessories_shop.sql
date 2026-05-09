-- =========================================================
-- Lerke Bingo — Avatar-8: Head accessories XP costs
-- Migration: v20_avatar_accessories_shop
-- Applied: 2026-05-09
-- =========================================================
--
-- Extends get_avatar_item_cost() to include all 20 acc_* keys
-- introduced in Avatar-7 (previously free / unrecognised by server).
-- The existing purchase_avatar_item RPC needs no changes — it already
-- delegates cost lookup to get_avatar_item_cost and handles free items.
--
-- XP cost tiers:
--   0   — acc_none (always free / equippable)
--   50  — acc_headband, acc_bandana
--   75  — acc_cap, acc_beanie
--   100 — acc_bow, acc_party_hat, acc_earmuffs
--   125 — acc_cowboy, acc_sombrero
--   150 — acc_graduation, acc_tophat, acc_chef_hat, acc_antlers
--   175 — acc_bunny_ears, acc_tiara
--   200 — acc_laurel, acc_viking
--   250 — acc_witch_hat
--   300 — acc_crown
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- Head / face-shape items (unchanged from v18)
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
    -- Head accessory items (added in Avatar-8)
    when 'acc_none'            then 0
    when 'acc_headband'        then 50
    when 'acc_bandana'         then 50
    when 'acc_cap'             then 75
    when 'acc_beanie'          then 75
    when 'acc_bow'             then 100
    when 'acc_party_hat'       then 100
    when 'acc_earmuffs'        then 100
    when 'acc_cowboy'          then 125
    when 'acc_sombrero'        then 125
    when 'acc_graduation'      then 150
    when 'acc_tophat'          then 150
    when 'acc_chef_hat'        then 150
    when 'acc_antlers'         then 150
    when 'acc_bunny_ears'      then 175
    when 'acc_tiara'           then 175
    when 'acc_laurel'          then 200
    when 'acc_viking'          then 200
    when 'acc_witch_hat'       then 250
    when 'acc_crown'           then 300
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
