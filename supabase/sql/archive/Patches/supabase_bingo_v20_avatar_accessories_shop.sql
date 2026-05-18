-- =========================================================
-- Lerke Bingo — V20: Head Accessories Shop
-- =========================================================
--
-- Extends get_avatar_item_cost to include all 20 acc_* keys
-- from avatar_head_accessories.png (4 cols × 5 rows, 256×256/tile).
--
-- The purchase_avatar_item RPC already handles any key — this patch
-- simply makes acc_* keys valid so the server can validate and charge XP.
--
-- XP cost tiers (mirrors head face-shape pricing):
--   Free (0):           acc_none
--   Common (50–75):     acc_headband, acc_bow, acc_beanie, acc_earmuffs, acc_bandana, acc_cap
--   Medium (75–125):    acc_party_hat, acc_graduation, acc_chef_hat, acc_bunny_ears, acc_cowboy, acc_sombrero, acc_antlers
--   Premium (125–225):  acc_laurel, acc_tophat, acc_witch_hat, acc_viking, acc_tiara
--   Legendary (300):    acc_crown
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- Face shapes (head_*)
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
    -- Head accessories (acc_*)
    when 'acc_none'            then 0
    when 'acc_headband'        then 50
    when 'acc_bow'             then 50
    when 'acc_beanie'          then 75
    when 'acc_earmuffs'        then 75
    when 'acc_bandana'         then 75
    when 'acc_cap'             then 75
    when 'acc_party_hat'       then 100
    when 'acc_graduation'      then 100
    when 'acc_chef_hat'        then 100
    when 'acc_bunny_ears'      then 100
    when 'acc_cowboy'          then 125
    when 'acc_sombrero'        then 125
    when 'acc_antlers'         then 125
    when 'acc_laurel'          then 150
    when 'acc_tophat'          then 150
    when 'acc_witch_hat'       then 175
    when 'acc_viking'          then 200
    when 'acc_tiara'           then 225
    when 'acc_crown'           then 300
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
