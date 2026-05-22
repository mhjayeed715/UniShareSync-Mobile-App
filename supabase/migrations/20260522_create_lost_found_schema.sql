-- Create Lost & Found reporting schema
-- Apply in Supabase SQL editor

create table if not exists public.lost_found_reports (
  id uuid primary key default gen_random_uuid(),
  report_type text not null check (report_type in ('lost', 'found')),
  title text not null,
  category text not null,
  description text not null,
  location text not null,
  contact_info text not null,
  report_date date not null default current_date,
  status text not null default 'open' check (status in ('open', 'matched', 'resolved')),
  photo_urls text[] not null default '{}',
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reporter_name text not null,
  reporter_avatar_url text,
  reporter_role text not null default 'student' check (reporter_role in ('student', 'faculty', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_lost_found_reports_type on public.lost_found_reports(report_type);
create index if not exists idx_lost_found_reports_status on public.lost_found_reports(status);
create index if not exists idx_lost_found_reports_category on public.lost_found_reports(category);
create index if not exists idx_lost_found_reports_reporter on public.lost_found_reports(reporter_id);
create index if not exists idx_lost_found_reports_created_at on public.lost_found_reports(created_at desc);

alter table public.lost_found_reports enable row level security;

drop policy if exists lost_found_reports_select_authenticated on public.lost_found_reports;
create policy lost_found_reports_select_authenticated
on public.lost_found_reports
for select
to authenticated
using (true);

drop policy if exists lost_found_reports_insert_authenticated on public.lost_found_reports;
create policy lost_found_reports_insert_authenticated
on public.lost_found_reports
for insert
to authenticated
with check (reporter_id = auth.uid());

drop policy if exists lost_found_reports_update_owner_or_admin on public.lost_found_reports;
create policy lost_found_reports_update_owner_or_admin
on public.lost_found_reports
for update
to authenticated
using (
  reporter_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  )
)
with check (
  reporter_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  )
);

drop policy if exists lost_found_reports_delete_owner_or_admin on public.lost_found_reports;
create policy lost_found_reports_delete_owner_or_admin
on public.lost_found_reports
for delete
to authenticated
using (
  reporter_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
  )
);

create or replace function public.set_lost_found_reports_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_set_lost_found_reports_updated_at on public.lost_found_reports;
create trigger trg_set_lost_found_reports_updated_at
before update on public.lost_found_reports
for each row
execute function public.set_lost_found_reports_updated_at();

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'lost_found_reports'
  ) then
    alter publication supabase_realtime add table public.lost_found_reports;
  end if;
end
$$;

insert into storage.buckets (id, name, public)
values ('lost-found-photos', 'lost-found-photos', true)
on conflict (id) do nothing;

drop policy if exists lost_found_photos_select_authenticated on storage.objects;
create policy lost_found_photos_select_authenticated
on storage.objects
for select
to authenticated
using (bucket_id = 'lost-found-photos');

drop policy if exists lost_found_photos_insert_authenticated on storage.objects;
create policy lost_found_photos_insert_authenticated
on storage.objects
for insert
to authenticated
with check (bucket_id = 'lost-found-photos');

drop policy if exists lost_found_photos_update_authenticated on storage.objects;
create policy lost_found_photos_update_authenticated
on storage.objects
for update
to authenticated
using (bucket_id = 'lost-found-photos')
with check (bucket_id = 'lost-found-photos');
