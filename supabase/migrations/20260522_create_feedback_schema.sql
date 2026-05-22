-- Create feedback and suggestions schema
-- Apply in Supabase SQL editor

create table if not exists public.feedback_entries (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('academic', 'technical', 'general')),
  title text not null,
  content text not null,
  rating smallint not null check (rating between 1 and 5),
  is_anonymous boolean not null default false,
  status text not null default 'pending' check (status in ('pending', 'responded', 'resolved')),
  admin_response text,
  responded_by uuid references auth.users(id) on delete set null,
  responded_at timestamptz,
  submitter_id uuid not null references auth.users(id) on delete cascade,
  submitter_name text not null,
  submitter_avatar_url text,
  submitter_role text not null default 'student' check (submitter_role in ('student', 'faculty', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_feedback_entries_category on public.feedback_entries(category);
create index if not exists idx_feedback_entries_status on public.feedback_entries(status);
create index if not exists idx_feedback_entries_submitter on public.feedback_entries(submitter_id);
create index if not exists idx_feedback_entries_created_at on public.feedback_entries(created_at desc);

alter table public.feedback_entries enable row level security;

drop policy if exists feedback_entries_select_authenticated on public.feedback_entries;
create policy feedback_entries_select_authenticated
on public.feedback_entries
for select
to authenticated
using (true);

drop policy if exists feedback_entries_insert_authenticated on public.feedback_entries;
create policy feedback_entries_insert_authenticated
on public.feedback_entries
for insert
to authenticated
with check (submitter_id = auth.uid());

drop policy if exists feedback_entries_update_admin_only on public.feedback_entries;
create policy feedback_entries_update_admin_only
on public.feedback_entries
for update
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  )
);

drop policy if exists feedback_entries_delete_admin_only on public.feedback_entries;
create policy feedback_entries_delete_admin_only
on public.feedback_entries
for delete
to authenticated
using (
  exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  )
);

create or replace function public.set_feedback_entries_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_set_feedback_entries_updated_at on public.feedback_entries;
create trigger trg_set_feedback_entries_updated_at
before update on public.feedback_entries
for each row
execute function public.set_feedback_entries_updated_at();

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'feedback_entries'
  ) then
    alter publication supabase_realtime add table public.feedback_entries;
  end if;
end
$$;
