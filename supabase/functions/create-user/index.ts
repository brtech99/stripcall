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

  // Only allow POST requests
  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 405
      }
    )
  }

  try {
    // Create a Supabase client with the Auth context of the function
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    // Get the request body
    const {
      email,
      password,
      firstname,
      lastname,
      phonenbr,
      superuser = false,
      organizer = false,
      is_sms_mode = false,
      skip_email_confirmation = false
    } = await req.json()

    // Validate required fields
    if (!email) {
      throw new Error('email is required')
    }
    if (!password) {
      throw new Error('password is required')
    }
    if (!firstname) {
      throw new Error('firstname is required')
    }
    if (!lastname) {
      throw new Error('lastname is required')
    }

    // Check if the current user is authenticated and is a superuser
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      throw new Error('Unauthorized - No valid session')
    }

    const { data: currentUserData, error: userError } = await supabaseClient
      .from('users')
      .select('superuser, firstname, lastname')
      .eq('supabase_id', user.id)
      .single()

    if (userError || !currentUserData) {
      throw new Error('User not found in database')
    }

    if (!currentUserData.superuser) {
      throw new Error('Only superusers can create users')
    }

    console.log('=== CREATE USER: Superuser authorized, proceeding with creation ===')

    // Create admin client for auth operations
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Create the auth user
    const { data: authData, error: authError } = await adminClient.auth.admin.createUser({
      email: email,
      password: password,
      email_confirm: skip_email_confirmation, // If true, user doesn't need to confirm email
      user_metadata: {
        firstname: firstname,
        lastname: lastname,
      }
    })

    if (authError) {
      console.log('=== CREATE USER: Auth creation error:', authError.message)
      throw new Error(`Failed to create auth user: ${authError.message}`)
    }

    if (!authData.user) {
      throw new Error('Failed to create auth user: No user returned')
    }

    console.log('=== CREATE USER: Auth user created with ID:', authData.user.id)

    // Create the public.users record
    const { error: publicError } = await adminClient
      .from('users')
      .insert({
        supabase_id: authData.user.id,
        firstname: firstname,
        lastname: lastname,
        phonenbr: phonenbr || null,
        superuser: superuser,
        organizer: organizer,
        is_sms_mode: is_sms_mode,
      })

    if (publicError) {
      console.log('=== CREATE USER: Public user creation error:', publicError.message)
      // Try to clean up the auth user if public user creation fails
      try {
        await adminClient.auth.admin.deleteUser(authData.user.id)
        console.log('=== CREATE USER: Cleaned up auth user after public user creation failure')
      } catch (cleanupError) {
        console.log('=== CREATE USER: Failed to cleanup auth user:', cleanupError)
      }
      throw new Error(`Failed to create public user: ${publicError.message}`)
    }

    console.log('=== CREATE USER: Public user created successfully')

    // Log the creation for audit purposes
    console.log(`User creation: ${currentUserData.firstname} ${currentUserData.lastname} (${user.id}) created user ${email} (${authData.user.id})`)

    return new Response(
      JSON.stringify({
        message: 'User created successfully',
        user: {
          id: authData.user.id,
          email: authData.user.email,
          firstname: firstname,
          lastname: lastname,
          email_confirmed: skip_email_confirmation,
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200
      }
    )

  } catch (error: unknown) {
    console.error('=== CREATE USER ERROR:', error instanceof Error ? error.message : error)
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400
      }
    )
  }
})
