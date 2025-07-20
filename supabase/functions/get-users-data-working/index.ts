import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get the authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header provided')
    }

    console.log('=== WORKING FUNCTION: Starting users data request ===')

    // Create a Supabase client with the service role key
    const supabaseUrl = Deno.env.get('SUPABASE_URL')
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing Supabase configuration')
    }

    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey, {
      global: {
        headers: { Authorization: authHeader },
      },
    })

    // Verify the user has superuser privileges
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    
    if (userError || !user) {
      console.log('=== WORKING FUNCTION: Auth failed -', userError?.message || 'No user')
      throw new Error('Authentication failed')
    }

    console.log('=== WORKING FUNCTION: User authenticated -', user.email)

    // Check if the user is a superuser in the public.users table
    const { data: userData, error: userDataError } = await supabaseClient
      .from('users')
      .select('*')
      .eq('supabase_id', user.id)
      .single()

    console.log('=== WORKING FUNCTION: User data query result -', { userData, userDataError })

    if (userDataError) {
      console.log('=== WORKING FUNCTION: User data error -', userDataError.message)
      throw new Error('User not allowed - could not verify user data')
    }

    if (!userData) {
      console.log('=== WORKING FUNCTION: No user data found')
      throw new Error('User not allowed - user not found in users table')
    }

    console.log('=== WORKING FUNCTION: User superuser status -', userData.superuser, 'Type:', typeof userData.superuser)

    if (userData.superuser !== true) {
      console.log('=== WORKING FUNCTION: User is not superuser -', userData.superuser)
      throw new Error('User not allowed - superuser privileges required')
    }

    console.log('=== WORKING FUNCTION: User is superuser, proceeding to get data')

    // Get public users (we can access this)
    const { data: publicUsers, error: publicError } = await supabaseClient
      .from('users')
      .select('*')

    if (publicError) {
      console.log('=== WORKING FUNCTION: Public users error -', publicError.message)
      throw publicError
    }

    // Get pending users (we can access this)
    const { data: pendingUsers, error: pendingError } = await supabaseClient
      .from('pending_users')
      .select('*')

    if (pendingError) {
      console.log('=== WORKING FUNCTION: Pending users error -', pendingError.message)
      throw pendingError
    }

    console.log('=== WORKING FUNCTION: Successfully retrieved accessible user data')

    // Return accessible user data (note: no auth.users due to Supabase restrictions)
    return new Response(
      JSON.stringify({ 
        authUsers: [], // Cannot access auth.users from Edge Functions
        publicUsers: publicUsers || [],
        pendingUsers: pendingUsers || [],
        note: 'Auth users cannot be accessed from Edge Functions due to Supabase security restrictions'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error('=== WORKING FUNCTION ERROR:', errorMessage)
    
    return new Response(
      JSON.stringify({ error: errorMessage }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
}) 