-- Add notifications for project join requests

-- Update request_project_join function to create notification
CREATE OR REPLACE FUNCTION request_project_join(p_project_id UUID)
RETURNS VOID AS $$
DECLARE
  v_requester_id UUID;
  v_requester_name TEXT;
  v_requester_avatar TEXT;
  v_project_owner_id UUID;
  v_project_title TEXT;
BEGIN
  v_requester_id := auth.uid();
  
  -- Get requester name and avatar
  SELECT full_name, avatar_url INTO v_requester_name, v_requester_avatar
  FROM profiles
  WHERE id = v_requester_id;
  
  -- Get project owner and title
  SELECT owner_id, title INTO v_project_owner_id, v_project_title
  FROM projects
  WHERE id = p_project_id;
  
  -- Insert join request with all required fields
  INSERT INTO project_join_requests (
    project_id, 
    requester_id, 
    project_owner_id, 
    requester_name,
    requester_avatar_url,
    status
  )
  VALUES (
    p_project_id, 
    v_requester_id, 
    v_project_owner_id, 
    v_requester_name,
    v_requester_avatar,
    'pending'
  );
  
  -- Create notification for project owner
  INSERT INTO notifications (user_id, title, body, notification_type)
  VALUES (
    v_project_owner_id,
    'New Join Request',
    v_requester_name || ' wants to join your project "' || v_project_title || '"',
    'info'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update review_project_join_request function to create notification
CREATE OR REPLACE FUNCTION review_project_join_request(p_request_id UUID, p_action TEXT)
RETURNS VOID AS $$
DECLARE
  v_requester_id UUID;
  v_project_id UUID;
  v_project_title TEXT;
  v_owner_name TEXT;
BEGIN
  -- Get request details
  SELECT requester_id, project_id INTO v_requester_id, v_project_id
  FROM project_join_requests
  WHERE id = p_request_id;
  
  -- Get project title and owner name
  SELECT p.title, pr.full_name INTO v_project_title, v_owner_name
  FROM projects p
  JOIN profiles pr ON p.owner_id = pr.id
  WHERE p.id = v_project_id;
  
  IF p_action = 'approve' THEN
    -- Update request status
    UPDATE project_join_requests
    SET status = 'approved', reviewed_at = NOW()
    WHERE id = p_request_id;
    
    -- Add member to project
    INSERT INTO project_members (project_id, user_id, role)
    VALUES (v_project_id, v_requester_id, 'member');
    
    -- Update project member count
    UPDATE projects
    SET current_members = current_members + 1
    WHERE id = v_project_id;
    
    -- Create notification for requester
    INSERT INTO notifications (user_id, title, body, notification_type)
    VALUES (
      v_requester_id,
      'Join Request Approved',
      v_owner_name || ' approved your request to join "' || v_project_title || '"',
      'success'
    );
  ELSE
    -- Update request status
    UPDATE project_join_requests
    SET status = 'rejected', reviewed_at = NOW()
    WHERE id = p_request_id;
    
    -- Create notification for requester
    INSERT INTO notifications (user_id, title, body, notification_type)
    VALUES (
      v_requester_id,
      'Join Request Declined',
      'Your request to join "' || v_project_title || '" was declined',
      'warning'
    );
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
