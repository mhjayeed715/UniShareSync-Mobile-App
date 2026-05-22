-- Create notifications table for notification center
-- Apply in Supabase SQL Editor

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  body text not null,
  notification_type text not null default 'info' check (notification_type in ('info', 'success', 'warning', 'error')),
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Create indexes
create index if not exists idx_notifications_user_id_created_at
  on public.notifications (user_id, created_at desc);
create index if not exists idx_notifications_user_id_is_read
  on public.notifications (user_id, is_read);

-- Enable RLS
alter table public.notifications enable row level security;

-- RLS policies
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
on public.notifications
for select
to authenticated
using (user_id = auth.uid());

drop policy if exists notifications_insert_admin_only on public.notifications;
create policy notifications_insert_admin_only
on public.notifications
for insert
to authenticated
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role in ('admin', 'faculty')
  )
);

drop policy if exists notifications_update_own on public.notifications;
create policy notifications_update_own
on public.notifications
for update
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists notifications_delete_own on public.notifications;
create policy notifications_delete_own
on public.notifications
for delete
to authenticated
using (user_id = auth.uid());

-- Enable realtime
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end
$$;
