-- Add function to decrement club member count
-- This is called when a member leaves a club

create or replace function public.decrement_club_member_count(p_club_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.clubs
  set member_count = greatest(member_count - 1, 0),
      updated_at = now()
  where id = p_club_id;
end;
$$;

grant execute on function public.decrement_club_member_count(uuid) to authenticated;
