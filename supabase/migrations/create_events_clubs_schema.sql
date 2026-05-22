-- Events and Clubs Schema Migration
-- Run this in Supabase SQL Editor

-- ============================================
-- EVENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  date TIMESTAMPTZ NOT NULL,
  time TEXT NOT NULL,
  venue TEXT NOT NULL,
  organizer_club TEXT NOT NULL,
  seat_capacity INT NOT NULL CHECK (seat_capacity > 0),
  registered_count INT NOT NULL DEFAULT 0 CHECK (registered_count >= 0),
  status TEXT NOT NULL DEFAULT 'upcoming' CHECK (status IN ('upcoming', 'ongoing', 'completed')),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_by_name TEXT NOT NULL,
  created_by_avatar TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- EVENT REGISTRATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.event_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id UUID NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_name TEXT NOT NULL,
  user_avatar TEXT,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(event_id, user_id)
);

-- ============================================
-- CLUBS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.clubs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT NOT NULL,
  category TEXT NOT NULL,
  member_count INT NOT NULL DEFAULT 1 CHECK (member_count >= 1),
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_name TEXT NOT NULL,
  owner_avatar TEXT,
  logo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================
-- CLUB MEMBERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.club_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(club_id, user_id)
);

-- ============================================
-- CLUB JOIN REQUESTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS public.club_join_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  club_id UUID NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requester_name TEXT NOT NULL,
  requester_avatar TEXT,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  UNIQUE(club_id, requester_id)
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_events_date ON public.events(date);
CREATE INDEX IF NOT EXISTS idx_events_status ON public.events(status);
CREATE INDEX IF NOT EXISTS idx_events_created_by ON public.events(created_by);
CREATE INDEX IF NOT EXISTS idx_event_registrations_event ON public.event_registrations(event_id);
CREATE INDEX IF NOT EXISTS idx_event_registrations_user ON public.event_registrations(user_id);
CREATE INDEX IF NOT EXISTS idx_clubs_owner ON public.clubs(owner_id);
CREATE INDEX IF NOT EXISTS idx_club_members_club ON public.club_members(club_id);
CREATE INDEX IF NOT EXISTS idx_club_members_user ON public.club_members(user_id);
CREATE INDEX IF NOT EXISTS idx_club_join_requests_club ON public.club_join_requests(club_id);
CREATE INDEX IF NOT EXISTS idx_club_join_requests_requester ON public.club_join_requests(requester_id);

-- ============================================
-- ROW LEVEL SECURITY
-- ============================================
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_join_requests ENABLE ROW LEVEL SECURITY;

-- Events Policies
DROP POLICY IF EXISTS events_select_all ON public.events;
CREATE POLICY events_select_all ON public.events FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS events_insert_faculty_admin ON public.events;
CREATE POLICY events_insert_faculty_admin ON public.events FOR INSERT TO authenticated
WITH CHECK (
  created_by = auth.uid() AND 
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin'))
);

DROP POLICY IF EXISTS events_update_creator_admin ON public.events;
CREATE POLICY events_update_creator_admin ON public.events FOR UPDATE TO authenticated
USING (
  created_by = auth.uid() OR 
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS events_delete_creator_admin ON public.events;
CREATE POLICY events_delete_creator_admin ON public.events FOR DELETE TO authenticated
USING (
  created_by = auth.uid() OR 
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Event Registrations Policies
DROP POLICY IF EXISTS event_registrations_select_all ON public.event_registrations;
CREATE POLICY event_registrations_select_all ON public.event_registrations FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS event_registrations_insert_student ON public.event_registrations;
CREATE POLICY event_registrations_insert_student ON public.event_registrations FOR INSERT TO authenticated
WITH CHECK (
  user_id = auth.uid() AND 
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'student')
);

DROP POLICY IF EXISTS event_registrations_delete_own ON public.event_registrations;
CREATE POLICY event_registrations_delete_own ON public.event_registrations FOR DELETE TO authenticated
USING (user_id = auth.uid());

-- Clubs Policies
DROP POLICY IF EXISTS clubs_select_all ON public.clubs;
CREATE POLICY clubs_select_all ON public.clubs FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS clubs_insert_faculty_admin ON public.clubs;
CREATE POLICY clubs_insert_faculty_admin ON public.clubs FOR INSERT TO authenticated
WITH CHECK (
  owner_id = auth.uid() AND 
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('faculty', 'admin'))
);

DROP POLICY IF EXISTS clubs_update_owner_admin ON public.clubs;
CREATE POLICY clubs_update_owner_admin ON public.clubs FOR UPDATE TO authenticated
USING (
  owner_id = auth.uid() OR 
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS clubs_delete_owner_admin ON public.clubs;
CREATE POLICY clubs_delete_owner_admin ON public.clubs FOR DELETE TO authenticated
USING (
  owner_id = auth.uid() OR 
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- Club Members Policies
DROP POLICY IF EXISTS club_members_select_all ON public.club_members;
CREATE POLICY club_members_select_all ON public.club_members FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS club_members_insert_owner_admin ON public.club_members;
CREATE POLICY club_members_insert_owner_admin ON public.club_members FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.clubs 
    WHERE id = club_id AND (owner_id = auth.uid() OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
  )
);

DROP POLICY IF EXISTS club_members_delete_owner_admin ON public.club_members;
CREATE POLICY club_members_delete_owner_admin ON public.club_members FOR DELETE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.clubs 
    WHERE id = club_id AND (owner_id = auth.uid() OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))
  )
);

-- Club Join Requests Policies
DROP POLICY IF EXISTS club_join_requests_select_related ON public.club_join_requests;
CREATE POLICY club_join_requests_select_related ON public.club_join_requests FOR SELECT TO authenticated
USING (
  requester_id = auth.uid() OR 
  EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND owner_id = auth.uid()) OR
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

DROP POLICY IF EXISTS club_join_requests_insert_student ON public.club_join_requests;
CREATE POLICY club_join_requests_insert_student ON public.club_join_requests FOR INSERT TO authenticated
WITH CHECK (
  requester_id = auth.uid() AND 
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'student')
);

DROP POLICY IF EXISTS club_join_requests_update_owner_admin ON public.club_join_requests;
CREATE POLICY club_join_requests_update_owner_admin ON public.club_join_requests FOR UPDATE TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.clubs WHERE id = club_id AND owner_id = auth.uid()) OR
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function: Register for Event
CREATE OR REPLACE FUNCTION public.register_for_event(p_event_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event RECORD;
  v_user RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get event details
  SELECT * INTO v_event FROM public.events WHERE id = p_event_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Event not found';
  END IF;

  IF v_event.status != 'upcoming' THEN
    RAISE EXCEPTION 'Event is not open for registration';
  END IF;

  IF v_event.registered_count >= v_event.seat_capacity THEN
    RAISE EXCEPTION 'Event is full';
  END IF;

  -- Get user details
  SELECT full_name, avatar_url, role INTO v_user FROM public.profiles WHERE id = auth.uid();

  IF v_user.role != 'student' THEN
    RAISE EXCEPTION 'Only students can register for events';
  END IF;

  -- Insert registration
  INSERT INTO public.event_registrations (event_id, user_id, user_name, user_avatar)
  VALUES (p_event_id, auth.uid(), COALESCE(v_user.full_name, 'Student'), v_user.avatar_url);

  -- Update registered count
  UPDATE public.events 
  SET registered_count = registered_count + 1, updated_at = NOW()
  WHERE id = p_event_id;
END;
$$;

-- Function: Unregister from Event
CREATE OR REPLACE FUNCTION public.unregister_from_event(p_event_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Delete registration
  DELETE FROM public.event_registrations 
  WHERE event_id = p_event_id AND user_id = auth.uid();

  -- Update registered count
  UPDATE public.events 
  SET registered_count = registered_count - 1, updated_at = NOW()
  WHERE id = p_event_id;
END;
$$;

-- Function: Request to Join Club
CREATE OR REPLACE FUNCTION public.request_join_club(p_club_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get user details
  SELECT full_name, avatar_url, role INTO v_user FROM public.profiles WHERE id = auth.uid();

  IF v_user.role != 'student' THEN
    RAISE EXCEPTION 'Only students can request to join clubs';
  END IF;

  -- Insert join request
  INSERT INTO public.club_join_requests (club_id, requester_id, requester_name, requester_avatar)
  VALUES (p_club_id, auth.uid(), COALESCE(v_user.full_name, 'Student'), v_user.avatar_url);
END;
$$;

-- Function: Review Club Join Request
CREATE OR REPLACE FUNCTION public.review_club_join_request(p_request_id UUID, p_action TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_request RECORD;
  v_club RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Get request details
  SELECT * INTO v_request FROM public.club_join_requests WHERE id = p_request_id;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Join request not found';
  END IF;

  IF v_request.status != 'pending' THEN
    RAISE EXCEPTION 'Request already reviewed';
  END IF;

  -- Get club details
  SELECT * INTO v_club FROM public.clubs WHERE id = v_request.club_id;

  -- Check authorization
  IF v_club.owner_id != auth.uid() AND NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin') THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  IF LOWER(p_action) = 'approve' THEN
    -- Update request status
    UPDATE public.club_join_requests
    SET status = 'approved', reviewed_at = NOW()
    WHERE id = p_request_id;

    -- Add member to club
    INSERT INTO public.club_members (club_id, user_id, role)
    VALUES (v_request.club_id, v_request.requester_id, 'member')
    ON CONFLICT DO NOTHING;

    -- Update member count
    UPDATE public.clubs
    SET member_count = member_count + 1, updated_at = NOW()
    WHERE id = v_request.club_id;
  ELSIF LOWER(p_action) = 'reject' THEN
    -- Update request status
    UPDATE public.club_join_requests
    SET status = 'rejected', reviewed_at = NOW()
    WHERE id = p_request_id;
  ELSE
    RAISE EXCEPTION 'Invalid action';
  END IF;
END;
$$;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION public.register_for_event(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unregister_from_event(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_join_club(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.review_club_join_request(UUID, TEXT) TO authenticated;

-- ============================================
-- REALTIME
-- ============================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.events;
ALTER PUBLICATION supabase_realtime ADD TABLE public.event_registrations;
ALTER PUBLICATION supabase_realtime ADD TABLE public.clubs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.club_members;
