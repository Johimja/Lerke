-- Lerke
-- Student accounts / classes V1 incremental fix
--
-- Fixes recursive RLS evaluation on public.classes that caused:
-- "stack depth limit exceeded"
-- when fetching teacher-owned classes after the initial student account patch.
--
-- Keep this only for databases that already applied an earlier core patch.
-- New rollouts should use `supabase_student_accounts_v1_core_patch.sql`.

begin;

create or replace function public.is_class_teacher(target_class_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.classes c
    join public.teacher_profiles tp on tp.user_id = c.teacher_user_id
    where c.id = target_class_id
      and c.teacher_user_id = auth.uid()
      and tp.is_teacher = true
      and tp.is_approved = true
  );
$$;

drop policy if exists classes_teacher_select on public.classes;
create policy classes_teacher_select
on public.classes
for select
to authenticated
using (
  teacher_user_id = auth.uid()
  and public.is_teacher()
);

commit;
