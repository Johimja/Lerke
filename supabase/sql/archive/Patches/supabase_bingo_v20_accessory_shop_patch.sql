-- =========================================================
-- V20: Avatar accessory shop — XP costs for acc_* items
-- =========================================================
-- Extends get_avatar_item_cost() to return XP costs for all
-- 20 head-accessory keys (acc_none through acc_bunny_ears).
-- acc_none is always free (cost 0).
-- The existing purchase_avatar_item() RPC handles acc_* purchases
-- without modification because it delegates cost lookup to this helper.
-- =========================================================

-- =========================================================
-- 1. Replace get_avatar_item_cost to include acc_* keys
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- ── Head / face-shape silhouettes (from v17) ──────────────────────────
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
    -- ── Head accessories (new in v20) ─────────────────────────────────────
    when 'acc_none'            then 0
    when 'acc_headband'        then 25
    when 'acc_bow'             then 25
    when 'acc_cap'             then 50
    when 'acc_beanie'          then 50
    when 'acc_bandana'         then 50
    when 'acc_earmuffs'        then 50
    when 'acc_party_hat'       then 75
    when 'acc_chef_hat'        then 75
    when 'acc_bunny_ears'      then 75
    when 'acc_graduation'      then 100
    when 'acc_cowboy'          then 100
    when 'acc_antlers'         then 100
    when 'acc_sombrero'        then 125
    when 'acc_laurel'          then 125
    when 'acc_tophat'          then 150
    when 'acc_witch_hat'       then 150
    when 'acc_tiara'           then 175
    when 'acc_viking'          then 200
    when 'acc_crown'           then 250
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
