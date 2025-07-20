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
    const { user_id, updates } = await req.json()

    if (!user_id) {
      throw new Error('user_id is required')
    }

    if (!updates || typeof updates !== 'object') {
      throw new Error('updates object is required')
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
      throw new Error('Only superusers can update users')
    }

    console.log('=== UPDATE USER: Superuser authorized, proceeding with update ===')

    // Create admin client for auth operations
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Prepare the update data for auth.users
    const authUpdates: any = {}
    
    // Map allowed fields from updates to auth.users fields
    if (updates.email !== undefined) authUpdates.email = updates.email
    if (updates.email_confirmed_at !== undefined) authUpdates.email_confirmed_at = updates.email_confirmed_at
    if (updates.phone !== undefined) authUpdates.phone = updates.phone
    if (updates.phone_confirmed_at !== undefined) authUpdates.phone_confirmed_at = updates.phone_confirmed_at
    if (updates.user_metadata !== undefined) authUpdates.user_metadata = updates.user_metadata
    if (updates.app_metadata !== undefined) authUpdates.app_metadata = updates.app_metadata
    if (updates.banned_until !== undefined) authUpdates.banned_until = updates.banned_until
    if (updates.confirmation_sent_at !== undefined) authUpdates.confirmation_sent_at = updates.confirmation_sent_at
    if (updates.recovery_sent_at !== undefined) authUpdates.recovery_sent_at = updates.recovery_sent_at
    if (updates.email_change_sent_at !== undefined) authUpdates.email_change_sent_at = updates.email_change_sent_at
    if (updates.new_email !== undefined) authUpdates.new_email = updates.new_email
    if (updates.invited_at !== undefined) authUpdates.invited_at = updates.invited_at
    if (updates.action_link !== undefined) authUpdates.action_link = updates.action_link
    if (updates.email_change_confirm_status !== undefined) authUpdates.email_change_confirm_status = updates.email_change_confirm_status
    if (updates.aud !== undefined) authUpdates.aud = updates.aud
    if (updates.role !== undefined) authUpdates.role = updates.role

    console.log('=== UPDATE USER: Auth updates to apply:', authUpdates)

    // Update the user in auth.users
    const { data: updatedAuthUser, error: authError } = await adminClient.auth.admin.updateUserById(
      user_id,
      authUpdates
    )
    
    if (authError) {
      console.log('=== UPDATE USER: Auth update error:', authError.message)
      throw authError
    }

    console.log('=== UPDATE USER: Auth user updated successfully')
    console.log('=== UPDATE USER: Updated user data:', updatedAuthUser.user)
    console.log('=== UPDATE USER: Updated user email:', updatedAuthUser.user.email)

    // Also update public.users if those fields are provided
    let publicUserUpdated = false
    const publicUpdates: any = {}
    
    if (updates.firstname !== undefined) publicUpdates.firstname = updates.firstname
    if (updates.lastname !== undefined) publicUpdates.lastname = updates.lastname
    if (updates.phonenbr !== undefined) publicUpdates.phonenbr = updates.phonenbr
    if (updates.superuser !== undefined) publicUpdates.superuser = updates.superuser
    if (updates.organizer !== undefined) publicUpdates.organizer = updates.organizer

    if (Object.keys(publicUpdates).length > 0) {
      console.log('=== UPDATE USER: Public updates to apply:', publicUpdates)
      
      const { error: publicError } = await supabaseClient
        .from('users')
        .update(publicUpdates)
        .eq('supabase_id', user_id)
      
      if (publicError) {
        console.log('=== UPDATE USER: Public update error:', publicError.message)
        throw publicError
      }
      
      publicUserUpdated = true
      console.log('=== UPDATE USER: Public user updated successfully')
    }

    // Log the update for audit purposes
    console.log(`User update: ${currentUserData.firstname} ${currentUserData.lastname} (${user.id}) updated user ${user_id}`)

    return new Response(
      JSON.stringify({ 
        message: 'User updated successfully',
        updated_user: {
          id: updatedAuthUser.user.id,
          email: updatedAuthUser.user.email,
          auth_updated: true,
          public_updated: publicUserUpdated
        }
      }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200 
      }
    )

  } catch (error: unknown) {
    console.error('=== UPDATE USER ERROR:', error instanceof Error ? error.message : error)
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400 
      }
    )
  }
}) 