-- Add read tracking for notices
-- This creates a junction table to track which users have read which notices

create table if not exists public.notice_reads (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.notices(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamp with time zone default now(),
  created_at timestamp with time zone default now(),
  unique(notice_id, user_id)
);

-- Enable RLS
alter table public.notice_reads enable row level security;

-- Users can only see their own read records
drop policy if exists notice_reads_select_own on public.notice_reads;
create policy notice_reads_select_own
on public.notice_reads
for select
to authenticated
using (user_id = auth.uid());

-- Users can only insert their own read records
drop policy if exists notice_reads_insert_own on public.notice_reads;
create policy notice_reads_insert_own
on public.notice_reads
for insert
to authenticated
with check (user_id = auth.uid());

-- Users can only delete their own read records
drop policy if exists notice_reads_delete_own on public.notice_reads;
create policy notice_reads_delete_own
on public.notice_reads
for delete
to authenticated
using (user_id = auth.uid());

-- Create indexes for performance
create index if not exists idx_notice_reads_user_id on public.notice_reads(user_id);
create index if not exists idx_notice_reads_notice_id on public.notice_reads(notice_id);
create index if not exists idx_notice_reads_user_notice on public.notice_reads(user_id, notice_id);

-- Enable realtime
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notice_reads'
  ) then
    alter publication supabase_realtime add table public.notice_reads;
  end if;
end
$$;
