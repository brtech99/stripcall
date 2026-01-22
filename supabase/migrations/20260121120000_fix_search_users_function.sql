-- Fix search_users function to properly use AND when both names are provided
-- Previously it used OR which caused incorrect results

CREATE OR REPLACE FUNCTION public.search_users(first_name_pattern text, last_name_pattern text)
 RETURNS TABLE(id text, firstname text, lastname text)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    SELECT u.supabase_id AS id, u.firstname, u.lastname
    FROM users u
    WHERE
        -- If both patterns provided, require both to match
        -- If only one provided, match that one
        (first_name_pattern = '' OR u.firstname ILIKE first_name_pattern)
        AND
        (last_name_pattern = '' OR u.lastname ILIKE last_name_pattern)
        -- At least one pattern must be non-empty (handled by caller, but safety check)
        AND (first_name_pattern != '' OR last_name_pattern != '')
    ORDER BY u.firstname ASC
    LIMIT 10;
END;
$function$;
