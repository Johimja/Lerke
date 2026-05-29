-- =========================================================
-- supabase_bingo_v20_avatar_accessories_patch.sql
-- Avatar-8: Head accessories shop — add XP costs for acc_* items
--
-- Extends get_avatar_item_cost() to recognise all 20 acc_* keys
-- from media/avatar_head_accessories.png (1024×1280, 4 cols × 5 rows).
--
-- purchase_avatar_item() already handles any valid key — this patch
-- is the only SQL change needed to unlock paid accessories.
-- =========================================================

create or replace function public.get_avatar_item_cost(p_item_key text)
returns int
language sql
immutable
security definer
set search_path = public
as $$
  select case p_item_key
    -- ── face-shape heads (avatar_faceshapes.png) ─────────────────
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
    -- ── head accessories (avatar_head_accessories.png) ───────────
    when 'acc_none'            then 0
    when 'acc_headband'        then 0
    when 'acc_beanie'          then 25
    when 'acc_bow'             then 25
    when 'acc_bandana'         then 50
    when 'acc_party_hat'       then 50
    when 'acc_cap'             then 75
    when 'acc_earmuffs'        then 75
    when 'acc_bunny_ears'      then 100
    when 'acc_graduation'      then 100
    when 'acc_chef_hat'        then 125
    when 'acc_sombrero'        then 125
    when 'acc_antlers'         then 150
    when 'acc_laurel'          then 150
    when 'acc_tophat'          then 175
    when 'acc_cowboy'          then 175
    when 'acc_tiara'           then 200
    when 'acc_witch_hat'       then 250
    when 'acc_crown'           then 300
    when 'acc_viking'          then 350
    else null
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
