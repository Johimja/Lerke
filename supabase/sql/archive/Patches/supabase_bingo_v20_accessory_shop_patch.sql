-- =========================================================
-- V20: Head accessories shop — XP costs for acc_* items
-- =========================================================
-- Adds XP costs for all 20 head accessories to the item-cost catalogue.
-- Spritesheet: /media/avatar_head_accessories.png (1024×1280, 4 cols × 5 rows, 256×256/cell)
-- The existing purchase_avatar_item RPC already handles acc_* keys correctly
-- (appends to unlocked_avatar_items; frontend reads avatar_data.acc for equip state).
-- Free starters: acc_none, acc_party_hat, acc_headband.
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- Head face-shapes (avatar_faceshapes.png)
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
    when 'head_pigtails'       then 150
    when 'head_goatee'         then 150
    when 'head_full_beard'     then 175
    when 'head_cap'            then 175
    when 'head_hat'            then 200
    when 'head_mohawk'         then 225
    when 'head_hood'           then 250
    when 'head_helmet'         then 275
    when 'head_afro'           then 300
    when 'head_flat_top_beard' then 300
    -- Head accessories (avatar_head_accessories.png)
    when 'acc_none'            then 0
    when 'acc_party_hat'       then 0
    when 'acc_headband'        then 0
    when 'acc_beanie'          then 50
    when 'acc_bow'             then 50
    when 'acc_bandana'         then 50
    when 'acc_cap'             then 75
    when 'acc_graduation'      then 100
    when 'acc_laurel'          then 100
    when 'acc_chef_hat'        then 100
    when 'acc_tophat'          then 150
    when 'acc_cowboy'          then 150
    when 'acc_earmuffs'        then 150
    when 'acc_bunny_ears'      then 150
    when 'acc_antlers'         then 175
    when 'acc_witch_hat'       then 200
    when 'acc_sombrero'        then 225
    when 'acc_crown'           then 250
    when 'acc_tiara'           then 250
    when 'acc_viking'          then 300
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
