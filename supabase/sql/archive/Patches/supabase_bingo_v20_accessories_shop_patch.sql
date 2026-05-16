-- =========================================================
-- Lerke Bingo — V20: Head accessories shop
-- =========================================================
-- Extends get_avatar_item_cost to handle the 20 acc_* keys
-- from media/avatar_head_accessories.png.
-- The existing purchase_avatar_item RPC already works generically
-- (it rejects any key returning null from get_avatar_item_cost),
-- so no other RPC changes are needed.
--
-- XP cost tiers:
--   Free (0):        acc_none, acc_headband, acc_beanie
--   Common (50):     acc_cap, acc_bow, acc_bandana, acc_earmuffs
--   Uncommon (75):   acc_party_hat
--   Standard (100):  acc_graduation, acc_cowboy, acc_chef_hat
--   Rare (125):      acc_sombrero, acc_bunny_ears
--   Epic (150):      acc_laurel, acc_witch_hat
--   Legendary (175): acc_tiara, acc_antlers
--   Exclusive (200): acc_crown, acc_tophat
--   Ultra (250):     acc_viking
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- Head shapes (face-shape sheet, unchanged)
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
    -- Head accessories (accessory sheet — Avatar-8)
    when 'acc_none'            then 0
    when 'acc_headband'        then 0
    when 'acc_beanie'          then 0
    when 'acc_cap'             then 50
    when 'acc_bow'             then 50
    when 'acc_bandana'         then 50
    when 'acc_earmuffs'        then 50
    when 'acc_party_hat'       then 75
    when 'acc_graduation'      then 100
    when 'acc_cowboy'          then 100
    when 'acc_chef_hat'        then 100
    when 'acc_sombrero'        then 125
    when 'acc_bunny_ears'      then 125
    when 'acc_laurel'          then 150
    when 'acc_witch_hat'       then 150
    when 'acc_tiara'           then 175
    when 'acc_antlers'         then 175
    when 'acc_crown'           then 200
    when 'acc_tophat'          then 200
    when 'acc_viking'          then 250
    else null
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
