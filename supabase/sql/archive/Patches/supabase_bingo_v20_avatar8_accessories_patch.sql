-- =========================================================
-- Lerke Bingo — V20 Avatar-8: Head Accessories Shop
-- =========================================================
-- Extends get_avatar_item_cost() to include all 20 acc_* keys
-- with XP costs so that purchase_avatar_item() can validate and
-- charge for accessory purchases.  The purchase RPC itself is
-- unchanged — it already delegates cost-lookup to this helper.
--
-- XP pricing:
--   acc_none          0   (free; also bypassed on the client)
--   acc_headband     50   basic
--   acc_bow          50   basic
--   acc_bandana      75   casual
--   acc_cap          75   casual
--   acc_beanie       75   casual
--   acc_party_hat    75   fun
--   acc_earmuffs    100   cute
--   acc_graduation  100   achievement
--   acc_cowboy      100   style
--   acc_chef_hat    100   fun
--   acc_bunny_ears  125   cute/fun
--   acc_sombrero    125   style
--   acc_antlers     125   seasonal
--   acc_tophat      150   prestige
--   acc_tiara       150   prestige
--   acc_laurel      175   achievement
--   acc_viking      175   warrior
--   acc_witch_hat   200   rare
--   acc_crown       250   ultimate prestige
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- ── face shapes (v18) ──────────────────────────────────
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
    -- ── head accessories (v20) ────────────────────────────
    when 'acc_none'            then 0
    when 'acc_headband'        then 50
    when 'acc_bow'             then 50
    when 'acc_bandana'         then 75
    when 'acc_cap'             then 75
    when 'acc_beanie'          then 75
    when 'acc_party_hat'       then 75
    when 'acc_earmuffs'        then 100
    when 'acc_graduation'      then 100
    when 'acc_cowboy'          then 100
    when 'acc_chef_hat'        then 100
    when 'acc_bunny_ears'      then 125
    when 'acc_sombrero'        then 125
    when 'acc_antlers'         then 125
    when 'acc_tophat'          then 150
    when 'acc_tiara'           then 150
    when 'acc_laurel'          then 175
    when 'acc_viking'          then 175
    when 'acc_witch_hat'       then 200
    when 'acc_crown'           then 250
    else null
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
