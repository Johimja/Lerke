-- =========================================================
-- V21: Paid avatar color changes (Avatar-9)
-- =========================================================
-- Students can pay 25 XP to set a custom color on their avatar
-- silhouette. The color is stored in avatar_data.color (#rrggbb).
-- XP deduction is server-side via purchase_avatar_color(); the
-- client then calls save_student_avatar() to persist the new color
-- alongside the existing head/acc fields.
-- No schema changes — avatar_data is already a jsonb column from v13.
-- =========================================================

create or replace function public.purchase_avatar_color(p_color text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_student_id uuid;
  v_cost       int := 25;
  v_current_xp int;
begin
  -- Validate #rrggbb hex format
  if p_color !~ '^#[0-9a-fA-F]{6}$' then
    return jsonb_build_object('ok', false, 'error', 'Ugyldig farge');
  end if;

  -- Resolve student via auth link
  select sal.student_id into v_student_id
  from public.student_auth_links sal
  where sal.auth_user_id = auth.uid()
  limit 1;

  if v_student_id is null then
    return jsonb_build_object('ok', false, 'error', 'Ikke innlogget');
  end if;

  select total_xp into v_current_xp
  from public.student_profiles
  where id = v_student_id;

  if v_current_xp < v_cost then
    return jsonb_build_object(
      'ok',     false,
      'error',  'Ikke nok XP',
      'total_xp', v_current_xp,
      'needed', v_cost
    );
  end if;

  update public.student_profiles
  set total_xp = total_xp - v_cost
  where id = v_student_id
  returning total_xp into v_current_xp;

  return jsonb_build_object(
    'ok',       true,
    'total_xp', v_current_xp,
    'xp_spent', v_cost
  );
end;
$$;

grant execute on function public.purchase_avatar_color(text) to authenticated, anon;
