drop view if exists "public"."auth_users_view";

-- Function is_superuser is used by RLS policies, don't drop it
-- drop function if exists "public"."is_superuser"(user_id uuid);
