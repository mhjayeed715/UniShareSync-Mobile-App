-- Create project collaboration schema
-- Apply in Supabase SQL editor

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  category text not null,
  semester_no int not null check (semester_no between 1 and 10),
  max_members int not null default 5 check (max_members between 2 and 20),
  current_members int not null default 1,
  required_skills text[] not null default '{}',
  deadline timestamptz not null,
  status text not null default 'recruiting' check (status in ('recruiting', 'active', 'completed')),
  owner_id uuid not null references auth.users(id) on delete cascade,
  owner_name text not null,
  owner_avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Ensure semester_no exists on legacy projects table before indexes
do $$
begin
  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'projects'
      and column_name = 'semester_no'
  ) then
    alter table public.projects add column semester_no int;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'projects'
      and column_name = 'semester'
  ) then
    execute 'update public.projects '
      'set semester_no = nullif(regexp_replace(semester::text, ''[^0-9]'', '''', ''g''), '''')::int '
      'where semester_no is null and semester is not null';
  end if;

  execute 'update public.projects set semester_no = 1 where semester_no is null';
  execute 'alter table public.projects alter column semester_no set default 1';
  execute 'alter table public.projects alter column semester_no set not null';

  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'projects'
      and c.conname = 'projects_semester_no_check'
  ) then
    execute 'alter table public.projects add constraint projects_semester_no_check check (semester_no between 1 and 10)';
  end if;
end
$$;

create table if not exists public.project_members (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  unique(project_id, user_id)
);

create table if not exists public.project_join_requests (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  requester_id uuid not null references auth.users(id) on delete cascade,
  requester_name text not null,
  requester_avatar_url text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  requested_at timestamptz not null default now(),
  reviewed_at timestamptz,
  reviewer_id uuid references auth.users(id),
  unique(project_id, requester_id)
);

create index if not exists idx_projects_semester on public.projects(semester_no);
create index if not exists idx_projects_status on public.projects(status);
create index if not exists idx_projects_owner on public.projects(owner_id);
create index if not exists idx_project_members_project on public.project_members(project_id);
create index if not exists idx_project_join_requests_project on public.project_join_requests(project_id);
create index if not exists idx_project_join_requests_requester on public.project_join_requests(requester_id);

alter table public.projects enable row level security;
alter table public.project_members enable row level security;
alter table public.project_join_requests enable row level security;

-- Projects policies
create policy projects_select_all
on public.projects
for select
to authenticated
using (true);

create policy projects_insert_student_or_admin
on public.projects
for insert
to authenticated
with check (
  owner_id = auth.uid()
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role in ('student', 'admin')
  )
);

create policy projects_update_owner_or_admin
on public.projects
for update
to authenticated
using (
  owner_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
)
with check (
  owner_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

create policy projects_delete_owner_or_admin
on public.projects
for delete
to authenticated
using (
  owner_id = auth.uid()
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  )
);

-- Project members policies
create policy project_members_select_all
on public.project_members
for select
to authenticated
using (true);

create policy project_members_insert_owner_or_admin
on public.project_members
for insert
to authenticated
with check (
  exists (
    select 1
    from public.projects p
    where p.id = project_id
      and (p.owner_id = auth.uid()
        or exists (
          select 1
          from public.profiles pr
          where pr.id = auth.uid() and pr.role = 'admin'
        ))
  )
);

-- Project join request policies
create policy project_join_requests_select_related
on public.project_join_requests
for select
to authenticated
using (
  requester_id = auth.uid()
  or exists (
    select 1
    from public.projects p
    where p.id = project_id and p.owner_id = auth.uid()
  )
  or exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'admin'
  )
);

create policy project_join_requests_insert_student
on public.project_join_requests
for insert
to authenticated
with check (
  requester_id = auth.uid()
  and exists (
    select 1
    from public.profiles p
    where p.id = auth.uid() and p.role = 'student'
  )
);

create policy project_join_requests_update_owner_or_admin
on public.project_join_requests
for update
to authenticated
using (
  exists (
    select 1
    from public.projects p
    where p.id = project_id and p.owner_id = auth.uid()
  )
  or exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'admin'
  )
)
with check (
  exists (
    select 1
    from public.projects p
    where p.id = project_id and p.owner_id = auth.uid()
  )
  or exists (
    select 1
    from public.profiles pr
    where pr.id = auth.uid() and pr.role = 'admin'
  )
);

-- Function: request join
create or replace function public.request_project_join(p_project_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_project record;
  v_requester record;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_project
  from public.projects
  where id = p_project_id;

  if not found then
    raise exception 'Project not found';
  end if;

  if v_project.status <> 'recruiting' then
    raise exception 'Project is not recruiting';
  end if;

  if v_project.current_members >= v_project.max_members then
    raise exception 'Project is full';
  end if;

  if v_project.deadline < now() then
    raise exception 'Project deadline passed';
  end if;

  select full_name, avatar_url, role into v_requester
  from public.profiles
  where id = auth.uid();

  if v_requester.role <> 'student' then
    raise exception 'Only students can request to join';
  end if;

  insert into public.project_join_requests (
    project_id,
    requester_id,
    requester_name,
    requester_avatar_url
  ) values (
    p_project_id,
    auth.uid(),
    coalesce(v_requester.full_name, 'Student'),
    v_requester.avatar_url
  );

  insert into public.notifications (user_id, title, body, notification_type)
  values (
    v_project.owner_id,
    'New join request',
    format('%s requested to join %s', coalesce(v_requester.full_name, 'A student'), v_project.title),
    'info'
  );
end;
$$;

-- Function: review join request
create or replace function public.review_project_join_request(
  p_request_id uuid,
  p_action text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request record;
  v_project record;
  v_is_admin boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_request
  from public.project_join_requests
  where id = p_request_id;

  if not found then
    raise exception 'Join request not found';
  end if;

  if v_request.status <> 'pending' then
    raise exception 'Join request already reviewed';
  end if;

  select * into v_project
  from public.projects
  where id = v_request.project_id;

  if not found then
    raise exception 'Project not found';
  end if;

  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role = 'admin'
  ) into v_is_admin;

  if not (v_project.owner_id = auth.uid() or v_is_admin) then
    raise exception 'Not authorized';
  end if;

  if lower(p_action) = 'approve' then
    if v_project.current_members >= v_project.max_members then
      raise exception 'Project is full';
    end if;

    update public.project_join_requests
    set status = 'approved',
        reviewer_id = auth.uid(),
        reviewed_at = now()
    where id = p_request_id;

    insert into public.project_members (project_id, user_id, role)
    values (v_project.id, v_request.requester_id, 'member')
    on conflict do nothing;

    update public.projects
    set current_members = current_members + 1,
        updated_at = now()
    where id = v_project.id;

    insert into public.notifications (user_id, title, body, notification_type)
    values (
      v_request.requester_id,
      'Join request approved',
      format('You have been added to %s', v_project.title),
      'success'
    );
  elsif lower(p_action) = 'reject' then
    update public.project_join_requests
    set status = 'rejected',
        reviewer_id = auth.uid(),
        reviewed_at = now()
    where id = p_request_id;

    insert into public.notifications (user_id, title, body, notification_type)
    values (
      v_request.requester_id,
      'Join request rejected',
      format('Your request to join %s was declined', v_project.title),
      'warning'
    );
  else
    raise exception 'Invalid action';
  end if;
end;
$$;

grant execute on function public.request_project_join(uuid) to authenticated;
grant execute on function public.review_project_join_request(uuid, text) to authenticated;

-- Enable realtime
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'projects'
  ) then
    alter publication supabase_realtime add table public.projects;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'project_join_requests'
  ) then
    alter publication supabase_realtime add table public.project_join_requests;
  end if;
end
$$;
