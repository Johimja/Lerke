-- =========================================================
-- V20: Head accessories shop — XP costs for acc_* items
-- =========================================================
-- Extends get_avatar_item_cost() to recognise all 20 acc_*
-- keys from media/avatar_head_accessories.png.
-- The existing purchase_avatar_item() RPC already delegates
-- to get_avatar_item_cost() so no changes are needed there.
--
-- XP tiers:
--   0   : acc_none, acc_headband (always free)
--   50  : acc_bow, acc_bandana, acc_cap, acc_earmuffs, acc_beanie
--   75  : acc_party_hat, acc_chef_hat, acc_bunny_ears
--  100  : acc_graduation, acc_laurel, acc_tophat, acc_cowboy, acc_sombrero
--  125  : acc_antlers, acc_crown, acc_witch_hat
--  150  : acc_viking
--  200  : acc_tiara
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- ── head face-shape items (unchanged from v17/v18) ──
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
    -- ── head accessories (new in v20) ──
    when 'acc_none'            then 0
    when 'acc_headband'        then 0
    when 'acc_bow'             then 50
    when 'acc_bandana'         then 50
    when 'acc_cap'             then 50
    when 'acc_earmuffs'        then 50
    when 'acc_beanie'          then 50
    when 'acc_party_hat'       then 75
    when 'acc_chef_hat'        then 75
    when 'acc_bunny_ears'      then 75
    when 'acc_graduation'      then 100
    when 'acc_laurel'          then 100
    when 'acc_tophat'          then 100
    when 'acc_cowboy'          then 100
    when 'acc_sombrero'        then 100
    when 'acc_antlers'         then 125
    when 'acc_crown'           then 125
    when 'acc_witch_hat'       then 150
    when 'acc_viking'          then 150
    when 'acc_tiara'           then 200
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
