-- Create a view that exposes auth users data
-- This allows the client to access auth users without needing admin privileges
CREATE OR REPLACE VIEW auth_users_view AS
SELECT
  au.id,
  au.email,
  au.email_confirmed_at,
  au.created_at,
  au.updated_at,
  au.last_sign_in_at,
  au.invited_at,
  au.confirmation_sent_at,
  au.recovery_sent_at,
  au.email_change_sent_at,
  au.aud,
  au.role,
  au.phone,
  au.phone_confirmed_at,
  au.phone_change_sent_at,
  au.phone_change,
  au.email_change_confirm_status,
  au.banned_until,
  au.reauthentication_sent_at,
  au.created_at as auth_created_at,
  au.updated_at as auth_updated_at
FROM auth.users au;

-- Grant access to the view for authenticated users
GRANT SELECT ON auth_users_view TO authenticated;

-- Create a function to check if user is superuser
CREATE OR REPLACE FUNCTION is_superuser(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users
    WHERE public.users.supabase_id = user_id::text AND public.users.superuser = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION is_superuser(UUID) TO authenticated; 