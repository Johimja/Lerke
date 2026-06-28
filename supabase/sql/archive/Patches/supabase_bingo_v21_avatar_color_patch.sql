-- =========================================================
-- V21: Paid avatar color changes (Avatar-9)
-- =========================================================
-- Adds a server-verified XP cost for recoloring the base face-shape
-- silhouette layer. avatar_data gains an optional "headColor" hex string,
-- e.g. { "head": "head_basic", "acc": "acc_none", "headColor": "#caa07a" }.
-- No new columns — headColor lives inside the existing avatar_data jsonb
-- column, same as head/acc.
--
-- New RPC: purchase_avatar_color(p_color_slot text, p_color text)
--   - p_color_slot: currently only 'head' is accepted (more slots —
--     hair/prop colors — can be added once those layers exist).
--   - p_color: a "#rrggbb" hex string.
--   - Cost: fixed 25 XP per save. Re-saving the same color that is
--     already stored for that slot is free (no-op, no charge).
--   - Returns {ok, total_xp, avatar_data, xp_spent} or {ok:false, error}.
-- =========================================================

create or replace function public.purchase_avatar_color(p_color_slot text, p_color text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id   uuid;
  v_cost         int := 25;
  v_current_xp   int;
  v_avatar_data  jsonb;
  v_current_color text;
begin
  if p_color_slot is distinct from 'head' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargefelt');
  end if;

  if p_color is null or p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig fargeformat');
  end if;

  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select total_xp, coalesce(avatar_data, '{}'::jsonb)
  into v_current_xp, v_avatar_data
  from public.student_profiles
  where id = v_student_id;

  v_current_color := v_avatar_data->>'headColor';

  -- Re-saving the already-active color is free.
  if v_current_color is not null and lower(v_current_color) = lower(p_color) then
    return jsonb_build_object('ok', true, 'unchanged', true, 'total_xp', v_current_xp, 'avatar_data', v_avatar_data);
  end if;

  if v_current_xp < v_cost then
    return jsonb_build_object('ok', false, 'error', 'Ikke nok XP', 'total_xp', v_current_xp, 'needed', v_cost);
  end if;

  update public.student_profiles
  set total_xp    = total_xp - v_cost,
      avatar_data = coalesce(avatar_data, '{}'::jsonb) || jsonb_build_object('headColor', lower(p_color))
  where id = v_student_id
  returning total_xp, avatar_data into v_current_xp, v_avatar_data;

  return jsonb_build_object(
    'ok',          true,
    'total_xp',    v_current_xp,
    'avatar_data', v_avatar_data,
    'xp_spent',    v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text, text) to authenticated, anon;
