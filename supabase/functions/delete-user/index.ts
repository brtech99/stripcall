import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': 'http://localhost:3000', // Restrict to your app domain
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
    const { user_id } = await req.json()

    if (!user_id) {
      throw new Error('user_id is required')
    }

    // Validate user_id format (should be a UUID)
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
    if (!uuidRegex.test(user_id)) {
      throw new Error('Invalid user_id format')
    }

    // Check if the current user is authenticated
    const { data: { user } } = await supabaseClient.auth.getUser()
    if (!user) {
      throw new Error('Unauthorized - No valid session')
    }

    // Check rate limiting
    if (!checkRateLimit(user.id)) {
      return new Response(
        JSON.stringify({ error: 'Rate limit exceeded. Please wait before trying again.' }),
        { 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 429 
        }
      )
    }

    // Check if the current user is a superuser
    const { data: currentUserData, error: userError } = await supabaseClient
      .from('users')
      .select('superuser, firstname, lastname')
      .eq('supabase_id', user.id)
      .single()

    if (userError || !currentUserData) {
      throw new Error('User not found in database')
    }

    if (!currentUserData.superuser) {
      throw new Error('Only superusers can delete users')
    }

    // Prevent self-deletion
    if (user.id === user_id) {
      throw new Error('Cannot delete your own account')
    }

    // Get info about the user being deleted for audit log
    const { data: targetUserData } = await supabaseClient
      .from('users')
      .select('firstname, lastname, email')
      .eq('supabase_id', user_id)
      .maybeSingle()

    // Delete the user from auth.users using the admin client
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { error } = await adminClient.auth.admin.deleteUser(user_id)
    
    if (error) {
      throw error
    }

    // Log the deletion for audit purposes
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
    console.error('Delete user error:', error instanceof Error ? error.message : error)
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400 
      }
    )
  }
}) 