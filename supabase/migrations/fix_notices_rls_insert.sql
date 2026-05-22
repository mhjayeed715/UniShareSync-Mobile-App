-- Fix RLS policy for notices insert
-- The insert policy should allow faculty and admin to create notices

-- Drop the existing insert policy
drop policy if exists notices_insert_admin_faculty on public.notices;

-- Create a new insert policy that allows faculty and admin
create policy notices_insert_admin_faculty
on public.notices
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role in ('admin', 'faculty')
  )
  and posted_by = auth.uid()
);

-- Ensure the select policy allows all authenticated users to see notices
drop policy if exists notices_select_authenticated on public.notices;
create policy notices_select_authenticated
on public.notices
for select
to authenticated
using (true);

-- Update policy allows faculty/admin to update their own or admins to update any
drop policy if exists notices_update_admin_faculty on public.notices;
create policy notices_update_admin_faculty
on public.notices
for update
to authenticated
using (
  posted_by = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
)
with check (
  posted_by = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

-- Delete policy - only admins can delete
drop policy if exists notices_delete_admin_only on public.notices;
create policy notices_delete_admin_only
on public.notices
for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);
