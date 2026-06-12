-- =========================================================
-- Lerke Bingo v20 patch — Avatar accessories shop XP costs
-- =========================================================
-- Extends get_avatar_item_cost() to include acc_* item keys.
-- The purchase_avatar_item RPC and unlocked_avatar_items column
-- are unchanged — they already handle any item key returned by
-- get_avatar_item_cost.
--
-- XP cost tiers:
--   0   — acc_none (always free)
--   50  — simple/common accessories (headband, beanie, bow)
--   75  — casual accessories (cap, bandana, party hat)
--   100 — distinctive accessories (graduation, tophat, chef_hat, earmuffs)
--   125 — fun accessories (cowboy, laurel, bunny_ears)
--   150 — thematic accessories (sombrero, antlers)
--   175 — prestige accessories (tiara, witch_hat)
--   200 — rare accessories (crown)
--   275 — legendary accessories (viking)
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
    -- Head accessory items (new in v20)
    when 'acc_none'            then 0
    when 'acc_headband'        then 50
    when 'acc_beanie'          then 50
    when 'acc_bow'             then 50
    when 'acc_cap'             then 75
    when 'acc_bandana'         then 75
    when 'acc_party_hat'       then 75
    when 'acc_graduation'      then 100
    when 'acc_tophat'          then 100
    when 'acc_chef_hat'        then 100
    when 'acc_earmuffs'        then 100
    when 'acc_cowboy'          then 125
    when 'acc_laurel'          then 125
    when 'acc_bunny_ears'      then 125
    when 'acc_sombrero'        then 150
    when 'acc_antlers'         then 150
    when 'acc_tiara'           then 175
    when 'acc_witch_hat'       then 175
    when 'acc_crown'           then 200
    when 'acc_viking'          then 275
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
