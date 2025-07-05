-- Create a function to search users by first name or last name
CREATE OR REPLACE FUNCTION search_users(first_name_pattern text, last_name_pattern text)
RETURNS TABLE (
    id uuid,
    firstname text,
    lastname text,
    email text
) LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT u.id, u.firstname, u.lastname, u.email
    FROM users u
    WHERE 
        (u.firstname ILIKE first_name_pattern OR u.lastname ILIKE last_name_pattern)
    ORDER BY u.firstname ASC
    LIMIT 10;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION search_users(text, text) TO authenticated;
 