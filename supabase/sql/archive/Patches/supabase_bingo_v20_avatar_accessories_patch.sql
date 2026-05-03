-- =========================================================
-- V20: Avatar head-accessories XP costs (Avatar-8)
-- =========================================================
-- Extends get_avatar_item_cost() to recognise all 20 acc_*
-- keys from media/avatar_head_accessories.png.
-- purchase_avatar_item() already handles acc_* keys correctly
-- via get_avatar_item_cost(); no changes to that RPC are needed.
--
-- Accessory XP tier rationale (relative to head items):
--   0   — acc_none         (no accessory, always free)
--  25   — starter (headband, bow)
--  50   — common  (beanie, bandana)
--  75   — medium  (cap, party_hat, earmuffs)
-- 100   — decent  (bunny_ears, graduation, laurel)
-- 125   — better  (cowboy, sombrero)
-- 150   — advanced (chef_hat, witch_hat, antlers)
-- 175   — premium (tophat, tiara)
-- 200   — high-end (crown)
-- 225   — top-tier (viking)
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- Head face-shapes (v18 catalogue)
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
    -- Head accessories (v20 catalogue)
    when 'acc_none'            then 0
    when 'acc_headband'        then 25
    when 'acc_bow'             then 25
    when 'acc_beanie'          then 50
    when 'acc_bandana'         then 50
    when 'acc_cap'             then 75
    when 'acc_party_hat'       then 75
    when 'acc_earmuffs'        then 75
    when 'acc_bunny_ears'      then 100
    when 'acc_graduation'      then 100
    when 'acc_laurel'          then 100
    when 'acc_cowboy'          then 125
    when 'acc_sombrero'        then 125
    when 'acc_chef_hat'        then 150
    when 'acc_witch_hat'       then 150
    when 'acc_antlers'         then 150
    when 'acc_tophat'          then 175
    when 'acc_tiara'           then 175
    when 'acc_crown'           then 200
    when 'acc_viking'          then 225
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
