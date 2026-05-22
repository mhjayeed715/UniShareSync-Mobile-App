-- Fix project join request functions to include project_owner_id

-- First, add project_owner_id column if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'project_join_requests'
      AND column_name = 'project_owner_id'
  ) THEN
    ALTER TABLE public.project_join_requests
    ADD COLUMN project_owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
    
    -- Populate existing rows with owner_id from projects table
    UPDATE public.project_join_requests pjr
    SET project_owner_id = p.owner_id
    FROM public.projects p
    WHERE pjr.project_id = p.id
      AND pjr.project_owner_id IS NULL;
  END IF;
  
  -- Rename requested_at to created_at if it exists
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'project_join_requests'
      AND column_name = 'requested_at'
  ) THEN
    ALTER TABLE public.project_join_requests
    RENAME COLUMN requested_at TO created_at;
  END IF;
END
$$;

-- Update request_project_join function
CREATE OR REPLACE FUNCTION public.request_project_join(p_project_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_project RECORD;
  v_requester RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT * INTO v_project
  FROM public.projects
  WHERE id = p_project_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Project not found';
  END IF;

  IF v_project.status <> 'recruiting' THEN
    RAISE EXCEPTION 'Project is not recruiting';
  END IF;

  IF v_project.current_members >= v_project.max_members THEN
    RAISE EXCEPTION 'Project is full';
  END IF;

  IF v_project.deadline < NOW() THEN
    RAISE EXCEPTION 'Project deadline passed';
  END IF;

  SELECT full_name, avatar_url, role INTO v_requester
  FROM public.profiles
  WHERE id = auth.uid();

  IF v_requester.role <> 'student' THEN
    RAISE EXCEPTION 'Only students can request to join';
  END IF;

  -- Insert with project_owner_id field
  INSERT INTO public.project_join_requests (
    project_id,
    requester_id,
    project_owner_id,
    requester_name,
    requester_avatar_url
  ) VALUES (
    p_project_id,
    auth.uid(),
    v_project.owner_id,
    COALESCE(v_requester.full_name, 'Student'),
    v_requester.avatar_url
  );

  -- Create notification for project owner
  INSERT INTO public.notifications (user_id, title, body, notification_type)
  VALUES (
    v_project.owner_id,
    'New join request',
    FORMAT('%s requested to join %s', COALESCE(v_requester.full_name, 'A student'), v_project.title),
    'info'
  );
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.request_project_join(UUID) TO authenticated;
