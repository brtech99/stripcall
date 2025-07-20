-- Drop the problematic user confirmation trigger
DROP TRIGGER IF EXISTS on_auth_user_confirmed ON auth.users;
DROP FUNCTION IF EXISTS handle_user_confirmation(); 