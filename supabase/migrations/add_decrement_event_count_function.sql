-- Function to decrement event registered count
CREATE OR REPLACE FUNCTION decrement_event_registered_count(p_event_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE events
  SET registered_count = GREATEST(0, registered_count - 1)
  WHERE id = p_event_id;
END;
$$;
