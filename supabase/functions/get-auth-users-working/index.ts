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

    console.log('=== GET AUTH USERS: Starting request ===')

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
      console.log('=== GET AUTH USERS: Auth failed -', userError?.message || 'No user')
      throw new Error('Authentication failed')
    }

    console.log('=== GET AUTH USERS: User authenticated -', user.email)

    // Check if the user is a superuser in the public.users table
    const { data: userData, error: userDataError } = await supabaseClient
      .from('users')
      .select('*')
      .eq('supabase_id', user.id)
      .single()

    console.log('=== GET AUTH USERS: User data query result -', { userData, userDataError })

    if (userDataError) {
      console.log('=== GET AUTH USERS: User data error -', userDataError.message)
      throw new Error('User not allowed - could not verify user data')
    }

    if (!userData) {
      console.log('=== GET AUTH USERS: No user data found')
      throw new Error('User not allowed - user not found in users table')
    }

    console.log('=== GET AUTH USERS: User superuser status -', userData.superuser, 'Type:', typeof userData.superuser)

    if (userData.superuser !== true) {
      console.log('=== GET AUTH USERS: User is not superuser -', userData.superuser)
      throw new Error('User not allowed - superuser privileges required')
    }

    console.log('=== GET AUTH USERS: User is superuser, proceeding to get auth users')

    // Create admin client for auth operations
    const adminClient = createClient(supabaseUrl, supabaseServiceKey)

    // Get auth users using admin privileges
    const { data: authUsers, error: authError } = await adminClient.auth.admin.listUsers()

    if (authError) {
      console.log('=== GET AUTH USERS: Auth users error -', authError.message)
      throw authError
    }

    console.log('=== GET AUTH USERS: Successfully retrieved auth users, count:', authUsers.users?.length || 0)

    // Get public users data to combine with auth users
    const { data: publicUsers, error: publicError } = await supabaseClient
      .from('users')
      .select('*')

    if (publicError) {
      console.log('=== GET AUTH USERS: Public users error -', publicError.message)
      throw publicError
    }

    // Create a map of public users by supabase_id for quick lookup
    const publicUsersMap = new Map()
    if (publicUsers) {
      publicUsers.forEach((pu: any) => {
        publicUsersMap.set(pu.supabase_id, pu)
      })
    }

    // Combine auth users with their public user data
    const combinedAuthUsers = authUsers.users?.map((authUser: any) => {
      const publicUser = publicUsersMap.get(authUser.id)
      return {
        ...authUser,
        public_user: publicUser || null
      }
    }) || []

    console.log('=== GET AUTH USERS: Combined auth users with public data, count:', combinedAuthUsers.length)

    // Return combined auth users data
    return new Response(
      JSON.stringify({ 
        authUsers: combinedAuthUsers,
        count: combinedAuthUsers.length
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : 'Unknown error'
    console.error('=== GET AUTH USERS ERROR:', errorMessage)
    
    return new Response(
      JSON.stringify({ error: errorMessage }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
}) 