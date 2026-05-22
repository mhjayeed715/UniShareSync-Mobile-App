-- Fix notices table schema - CORRECTED VERSION
-- Apply in Supabase SQL Editor

-- Step 1: Drop existing constraints
alter table if exists public.notices drop constraint if exists notices_priority_check;
alter table if exists public.notices drop constraint if exists notices_attachment_type_check;
alter table if exists public.notices drop constraint if exists notices_notice_type_check;

-- Step 2: Ensure body column is NOT NULL
alter table public.notices 
  alter column body set not null;

-- Step 3: Add missing columns if they don't exist
alter table public.notices 
  add column if not exists priority text,
  add column if not exists target_roles text[] default array['student', 'faculty', 'admin']::text[],
  add column if not exists target_semesters int[] default array[]::int[],
  add column if not exists posted_by uuid references auth.users(id) on delete set null;

-- Step 4: Update existing rows with valid priority values
update public.notices 
set priority = 'normal' 
where priority is null or priority not in ('normal', 'important', 'urgent');

-- Step 5: Set NOT NULL constraint on priority
alter table public.notices 
  alter column priority set not null,
  alter column priority set default 'normal';

-- Step 6: Set NOT NULL constraints on targeting columns
alter table public.notices 
  alter column target_roles set not null,
  alter column target_semesters set not null;

-- Step 7: Add constraints
alter table public.notices 
  add constraint notices_priority_check check (priority in ('normal', 'important', 'urgent')),
  add constraint notices_attachment_type_check check (attachment_type in ('image', 'pdf')),
  add constraint notices_notice_type_check check (notice_type in ('info', 'success', 'warning', 'error'));

-- Step 8: Create indexes for performance
create index if not exists idx_notices_priority_created_at
  on public.notices (priority, created_at desc);
create index if not exists idx_notices_created_at
  on public.notices (created_at desc);
create index if not exists idx_notices_target_roles
  on public.notices using gin (target_roles);
create index if not exists idx_notices_target_semesters
  on public.notices using gin (target_semesters);

-- Step 9: Ensure storage bucket exists
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'notice_attachments',
  'notice_attachments',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Step 10: Storage policies for notice attachments
drop policy if exists notice_attachments_public_read on storage.objects;
create policy notice_attachments_public_read
on storage.objects
for select
to public
using (bucket_id = 'notice_attachments');

drop policy if exists notice_attachments_insert_faculty_admin on storage.objects;
create policy notice_attachments_insert_faculty_admin
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'notice_attachments'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role in ('admin', 'faculty')
  )
);

drop policy if exists notice_attachments_update_faculty_admin on storage.objects;
create policy notice_attachments_update_faculty_admin
on storage.objects
for update
to authenticated
using (
  bucket_id = 'notice_attachments'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role in ('admin', 'faculty')
  )
)
with check (
  bucket_id = 'notice_attachments'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role in ('admin', 'faculty')
  )
);

drop policy if exists notice_attachments_delete_faculty_admin on storage.objects;
create policy notice_attachments_delete_faculty_admin
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'notice_attachments'
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role in ('admin', 'faculty')
  )
);

-- Step 11: RLS policies for notices table
alter table public.notices enable row level security;

drop policy if exists notices_select_authenticated on public.notices;
create policy notices_select_authenticated
on public.notices
for select
to authenticated
using (true);

drop policy if exists notices_insert_admin_faculty on public.notices;
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
);

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

-- Step 12: Enable realtime for notices
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notices'
  ) then
    alter publication supabase_realtime add table public.notices;
  end if;
end
$$;
