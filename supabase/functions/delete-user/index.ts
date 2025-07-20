import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Allow all origins for debugging
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Simple in-memory rate limiting (for production, use Redis)
const rateLimitStore = new Map<string, { count: number; resetTime: number }>()
const RATE_LIMIT_WINDOW = 60000 // 1 minute
const RATE_LIMIT_MAX = 5 // Max 5 deletions per minute per user

function checkRateLimit(userId: string): boolean {
  const now = Date.now()
  const userLimit = rateLimitStore.get(userId)
  
  if (!userLimit || now > userLimit.resetTime) {
    rateLimitStore.set(userId, { count: 1, resetTime: now + RATE_LIMIT_WINDOW })
    return true
  }
  
  if (userLimit.count >= RATE_LIMIT_MAX) {
    return false
  }
  
  userLimit.count++
  return true
}

serve(async (req: Request) => {
  console.log('=== DELETE USER FUNCTION: Request received ===')
  console.log('Method:', req.method)
  console.log('URL:', req.url)
  
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    console.log('=== DELETE USER FUNCTION: Handling CORS preflight ===')
    return new Response('ok', { headers: corsHeaders })
  }

  // Only allow POST requests
  if (req.method !== 'POST') {
    console.log('=== DELETE USER FUNCTION: Method not allowed ===')
    return new Response(
      JSON.stringify({ error: 'Method not allowed' }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 405 
      }
    )
  }

  try {
    console.log('=== DELETE USER FUNCTION: Creating Supabase client ===')
    
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
    const body = await req.json()
    console.log('=== DELETE USER FUNCTION: Request body ===', body)
    
    const { user_id } = body

    if (!user_id) {
      console.log('=== DELETE USER FUNCTION: No user_id provided ===')
      throw new Error('user_id is required')
    }

    console.log('=== DELETE USER FUNCTION: User ID to delete ===', user_id)

    // Validate user_id format (should be a UUID)
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    if (!uuidRegex.test(user_id)) {
      console.log('=== DELETE USER FUNCTION: Invalid UUID format ===')
      throw new Error('Invalid user_id format')
    }

    // Check if the current user is authenticated
    console.log('=== DELETE USER FUNCTION: Checking current user ===')
    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    
    if (authError) {
      console.log('=== DELETE USER FUNCTION: Auth error ===', authError)
      throw authError
    }
    
    if (!user) {
      console.log('=== DELETE USER FUNCTION: No authenticated user ===')
      throw new Error('Unauthorized - No valid session')
    }

    console.log('=== DELETE USER FUNCTION: Current user ID ===', user.id)

    // Check rate limiting
    if (!checkRateLimit(user.id)) {
      console.log('=== DELETE USER FUNCTION: Rate limit exceeded ===')
      return new Response(
        JSON.stringify({ error: 'Rate limit exceeded. Please wait before trying again.' }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 429 
        }
      )
    }

    // Check if the current user is a superuser
    console.log('=== DELETE USER FUNCTION: Checking superuser status ===')
    const { data: currentUserData, error: userError } = await supabaseClient
      .from('users')
      .select('superuser, firstname, lastname')
      .eq('supabase_id', user.id)
      .single()

    if (userError) {
      console.log('=== DELETE USER FUNCTION: Error fetching current user ===', userError)
      throw new Error(`User not found in database: ${userError.message}`)
    }
    
    if (!currentUserData) {
      console.log('=== DELETE USER FUNCTION: Current user not found in database ===')
      throw new Error('User not found in database')
    }

    console.log('=== DELETE USER FUNCTION: Current user data ===', currentUserData)

    if (!currentUserData.superuser) {
      console.log('=== DELETE USER FUNCTION: User is not a superuser ===')
      throw new Error('Only superusers can delete users')
    }

    // Prevent self-deletion
    if (user.id === user_id) {
      console.log('=== DELETE USER FUNCTION: Attempted self-deletion ===')
      throw new Error('Cannot delete your own account')
    }

    // Get info about the user being deleted for audit log
    console.log('=== DELETE USER FUNCTION: Getting target user info ===')
    const { data: targetUserData, error: targetError } = await supabaseClient
      .from('users')
      .select('firstname, lastname, email')
      .eq('supabase_id', user_id)
      .maybeSingle()

    if (targetError) {
      console.log('=== DELETE USER FUNCTION: Error fetching target user ===', targetError)
    }

    console.log('=== DELETE USER FUNCTION: Target user data ===', targetUserData)

    // Delete the user from auth.users using the admin client
    console.log('=== DELETE USER FUNCTION: Creating admin client ===')
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    console.log('=== DELETE USER FUNCTION: Attempting to delete user from auth ===')
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user_id)
    
    if (deleteError) {
      console.log('=== DELETE USER FUNCTION: Auth delete error ===', deleteError)
      throw deleteError
    }

    console.log('=== DELETE USER FUNCTION: User deleted from auth successfully ===')

    // Also delete from public.users if it exists
    console.log('=== DELETE USER FUNCTION: Attempting to delete from public.users ===')
    const { error: publicDeleteError } = await adminClient
      .from('users')
      .delete()
      .eq('supabase_id', user_id)

    if (publicDeleteError) {
      console.log('=== DELETE USER FUNCTION: Public users delete error ===', publicDeleteError)
      // Don't throw here, as the auth user was already deleted
    }

    // Also delete from pending_users if it exists
    console.log('=== DELETE USER FUNCTION: Attempting to delete from pending_users ===')
    const { error: pendingDeleteError } = await adminClient
      .from('pending_users')
      .delete()
      .eq('email', targetUserData?.email)

    if (pendingDeleteError) {
      console.log('=== DELETE USER FUNCTION: Pending users delete error ===', pendingDeleteError)
      // Don't throw here, as the auth user was already deleted
    }

    // Log the deletion for audit purposes
    console.log(`=== DELETE USER FUNCTION: User deletion successful ===`)
    console.log(`User deletion: ${currentUserData.firstname} ${currentUserData.lastname} (${user.id}) deleted user ${targetUserData?.firstname} ${targetUserData?.lastname} (${user_id})`)

    return new Response(
      JSON.stringify({ 
        message: 'User deleted successfully',
        deleted_user: targetUserData ? `${targetUserData.firstname} ${targetUserData.lastname}` : user_id
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error: unknown) {
    console.error('=== DELETE USER FUNCTION: Error ===', error instanceof Error ? error.message : error)
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400 
      }
    )
  }
}) 