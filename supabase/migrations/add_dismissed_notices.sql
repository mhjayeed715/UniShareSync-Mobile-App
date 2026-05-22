-- Add dismissed notifications tracking
-- This tracks which notifications users have removed from their notification center

create table if not exists public.dismissed_notices (
  id uuid primary key default gen_random_uuid(),
  notice_id uuid not null references public.notices(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  dismissed_at timestamp with time zone default now(),
  created_at timestamp with time zone default now(),
  unique(notice_id, user_id)
);

-- Enable RLS
alter table public.dismissed_notices enable row level security;

-- Users can only see their own dismissed records
drop policy if exists dismissed_notices_select_own on public.dismissed_notices;
create policy dismissed_notices_select_own
on public.dismissed_notices
for select
to authenticated
using (user_id = auth.uid());

-- Users can only insert their own dismissed records
drop policy if exists dismissed_notices_insert_own on public.dismissed_notices;
create policy dismissed_notices_insert_own
on public.dismissed_notices
for insert
to authenticated
with check (user_id = auth.uid());

-- Users can only delete their own dismissed records
drop policy if exists dismissed_notices_delete_own on public.dismissed_notices;
create policy dismissed_notices_delete_own
on public.dismissed_notices
for delete
to authenticated
using (user_id = auth.uid());

-- Create indexes for performance
create index if not exists idx_dismissed_notices_user_id on public.dismissed_notices(user_id);
create index if not exists idx_dismissed_notices_notice_id on public.dismissed_notices(notice_id);
create index if not exists idx_dismissed_notices_user_notice on public.dismissed_notices(user_id, notice_id);

-- Enable realtime
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'dismissed_notices'
  ) then
    alter publication supabase_realtime add table public.dismissed_notices;
  end if;
end
$$;
