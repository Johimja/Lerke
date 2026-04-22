-- =========================================================
-- V18: Avatar face-shape sheet correction
-- =========================================================
-- Canonical spritesheet: /media/avatar_faceshapes.png
-- 1024×1280, 4 cols × 5 rows, 256×256/cell.
--
-- V17 introduced the XP avatar shop against an incorrect mixed sheet.
-- This patch keeps the same purchase RPC and unlocked_avatar_items column,
-- but replaces the server-side item catalogue with the 20 real face-shape
-- tile keys used by the frontend.
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
    else null
  end;
$$;

grant execute on function public.get_avatar_item_cost(text) to authenticated, anon;
