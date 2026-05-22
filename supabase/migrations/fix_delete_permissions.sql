-- Update delete policy to allow users to remove notices from their notification center
-- Users can remove notices by deleting their read record (soft delete)
-- Admins can permanently delete notices

-- Drop the old admin-only delete policy
drop policy if exists notices_delete_admin_only on public.notices;

-- Create new delete policy: admins can delete, users cannot delete notices directly
-- Instead, users remove notices by deleting their read record
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

-- Allow users to delete their own read records (removes from notification center)
drop policy if exists notice_reads_delete_own on public.notice_reads;
create policy notice_reads_delete_own
on public.notice_reads
for delete
to authenticated
using (user_id = auth.uid());
