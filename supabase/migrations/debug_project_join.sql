-- Debug script to check project join request setup

-- Check if project_join_requests table exists
SELECT EXISTS (
  SELECT FROM information_schema.tables 
  WHERE table_schema = 'public' 
  AND table_name = 'project_join_requests'
) AS table_exists;

-- Check table structure
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'project_join_requests'
ORDER BY ordinal_position;

-- Check if functions exist
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('request_project_join', 'review_project_join_request');

-- Check existing join requests
SELECT * FROM project_join_requests LIMIT 10;
