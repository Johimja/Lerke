-- =========================================================
-- V20: Head accessories shop — XP costs for acc_* items
-- =========================================================
-- Extends get_avatar_item_cost() to recognise all 20 acc_*
-- keys from avatar_head_accessories.png (4×5 spritesheet).
-- purchase_avatar_item() already handles acc_* keys correctly
-- via this helper — no changes needed to that RPC.
--
-- XP tiers:
--   Free  (0 XP) : acc_none, acc_cap, acc_headband
--   Tier 1(50-75): acc_beanie, acc_bandana, acc_bow,
--                  acc_party_hat, acc_earmuffs
--   Tier 2(100)  : acc_graduation, acc_chef_hat,
--                  acc_antlers, acc_bunny_ears
--   Tier 3(125)  : acc_tophat, acc_laurel, acc_sombrero
--   Tier 4(150)  : acc_cowboy, acc_tiara, acc_witch_hat
--   Rare  (200+) : acc_crown (200), acc_viking (225)
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- Head / face-shape silhouettes (avatar_faceshapes.png)
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
    -- Head accessories (avatar_head_accessories.png)
    when 'acc_none'            then 0
    when 'acc_cap'             then 0
    when 'acc_headband'        then 0
    when 'acc_beanie'          then 50
    when 'acc_bandana'         then 50
    when 'acc_bow'             then 50
    when 'acc_party_hat'       then 75
    when 'acc_earmuffs'        then 75
    when 'acc_graduation'      then 100
    when 'acc_chef_hat'        then 100
    when 'acc_antlers'         then 100
    when 'acc_bunny_ears'      then 100
    when 'acc_tophat'          then 125
    when 'acc_laurel'          then 125
    when 'acc_sombrero'        then 125
    when 'acc_cowboy'          then 150
    when 'acc_tiara'           then 150
    when 'acc_witch_hat'       then 150
    when 'acc_crown'           then 200
    when 'acc_viking'          then 225
    else null
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
