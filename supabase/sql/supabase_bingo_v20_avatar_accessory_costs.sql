-- =========================================================
-- V20: Avatar-8 — head accessories XP costs
-- =========================================================
-- Extends get_avatar_item_cost() (introduced in V17, replaced in V18) to
-- recognize acc_* keys from media/avatar_head_accessories.png so that the
-- existing purchase_avatar_item() RPC can sell accessories, not just heads.
-- No schema changes — unlocked_avatar_items already stores both head_* and
-- acc_* keys via the same text[] column.
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
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
    when 'acc_none'            then 0
    when 'acc_party_hat'       then 50
    when 'acc_headband'        then 50
    when 'acc_cap'             then 60
    when 'acc_bandana'         then 60
    when 'acc_beanie'          then 75
    when 'acc_bow'             then 75
    when 'acc_earmuffs'        then 80
    when 'acc_graduation'      then 100
    when 'acc_chef_hat'        then 100
    when 'acc_cowboy'          then 125
    when 'acc_bunny_ears'      then 125
    when 'acc_witch_hat'       then 150
    when 'acc_laurel'          then 150
    when 'acc_sombrero'        then 175
    when 'acc_antlers'         then 175
    when 'acc_viking'          then 200
    when 'acc_tophat'          then 225
    when 'acc_tiara'           then 250
    when 'acc_crown'           then 300
    else null  -- invalid / unknown item
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
