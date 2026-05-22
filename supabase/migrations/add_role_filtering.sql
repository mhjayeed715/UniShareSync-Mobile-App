-- Add role-based filtering and fix delete permissions for notices
-- Apply in Supabase SQL Editor

-- Step 1: Update RLS policies for notices table

-- Drop existing policies
drop policy if exists notices_select_authenticated on public.notices;
drop policy if exists notices_delete_admin_only on public.notices;

-- Step 2: Create new select policy that filters by target_roles
create policy notices_select_by_role
on public.notices
for select
to authenticated
using (
  target_roles @> array[(
    select role from public.profiles where id = auth.uid()
  )::text]
  or target_roles @> array['student', 'faculty', 'admin']::text[]
);

-- Step 3: Create delete policy that allows admins and post creators
create policy notices_delete_admin_or_creator
on public.notices
for delete
to authenticated
using (
  posted_by = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

-- Step 4: Ensure posted_by is set for existing notices without it
update public.notices
set posted_by = created_by
where posted_by is null and created_by is not null;
