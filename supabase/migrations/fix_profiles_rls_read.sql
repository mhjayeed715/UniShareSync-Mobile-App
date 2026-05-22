-- Fix profiles RLS to allow all authenticated users to read basic profile info
-- This is needed for displaying member names in projects, events, clubs, etc.

-- Drop existing restrictive select policies if they exist
drop policy if exists profiles_select_own on public.profiles;
drop policy if exists profiles_select_restricted on public.profiles;
drop policy if exists profiles_select_all on public.profiles;

-- Create a policy that allows all authenticated users to read basic profile info
create policy profiles_select_all
on public.profiles
for select
to authenticated
using (true);

-- Update policy already exists, no need to recreate it
