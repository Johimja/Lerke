-- =========================================================
-- V20: Head accessories XP costs
-- =========================================================
-- Extends get_avatar_item_cost to recognise all acc_* keys
-- from the 20-item ACCESSORY_CATALOGUE in index.html.
-- purchase_avatar_item already routes through get_avatar_item_cost,
-- so no other RPC changes are needed.
--
-- Cost tiers (mirrors ACCESSORY_CATALOGUE xp values):
--   Free  (0 XP): acc_none, acc_headband
--   Tier1 (50):   acc_beanie, acc_bow
--   Tier2 (75):   acc_bandana, acc_cap
--   Tier3 (100):  acc_party_hat, acc_graduation
--   Tier4 (125):  acc_cowboy, acc_chef_hat
--   Tier5 (150):  acc_tophat, acc_earmuffs
--   Tier6 (175):  acc_sombrero, acc_laurel
--   Tier7 (200):  acc_bunny_ears, acc_antlers
--   Tier8 (250):  acc_crown, acc_tiara
--   Tier9 (275):  acc_witch_hat
--   Tier10(300):  acc_viking
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- ---- face-shape heads (v17/v18) ----
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
    -- ---- head accessories (v20) ----
    when 'acc_none'            then 0
    when 'acc_headband'        then 0
    when 'acc_beanie'          then 50
    when 'acc_bow'             then 50
    when 'acc_bandana'         then 75
    when 'acc_cap'             then 75
    when 'acc_party_hat'       then 100
    when 'acc_graduation'      then 100
    when 'acc_cowboy'          then 125
    when 'acc_chef_hat'        then 125
    when 'acc_tophat'          then 150
    when 'acc_earmuffs'        then 150
    when 'acc_sombrero'        then 175
    when 'acc_laurel'          then 175
    when 'acc_bunny_ears'      then 200
    when 'acc_antlers'         then 200
    when 'acc_crown'           then 250
    when 'acc_tiara'           then 250
    when 'acc_witch_hat'       then 275
    when 'acc_viking'          then 300
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
