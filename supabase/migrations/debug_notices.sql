-- Debug query to check what's in the notices table
-- Run this in Supabase SQL Editor to see the actual data

SELECT 
  id,
  title,
  target_roles,
  target_semesters,
  posted_by,
  created_at
FROM public.notices
ORDER BY created_at DESC
LIMIT 20;
