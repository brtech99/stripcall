import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface SecretMappings {
  [key: string]: string[]
}

interface SecretsResponse {
  [key: string]: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify the request is authenticated
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    // Verify user is authenticated
    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      throw new Error('User not authenticated')
    }

    // Get requested secret type from request
    const { secretType } = await req.json()

    // Define which secrets each type can access
    const secretMappings: SecretMappings = {
      'firebase': [
        'FIREBASE_API_KEY',
        'FIREBASE_APP_ID', 
        'FIREBASE_MESSAGING_SENDER_ID',
        'FIREBASE_PROJECT_ID',
        'FIREBASE_AUTH_DOMAIN',
        'FIREBASE_STORAGE_BUCKET',
        'FIREBASE_VAPID_KEY',
        'FIREBASE_IOS_APP_ID'
      ],
      'deployment': [
        'HOSTINGER_FTP_HOST',
        'HOSTINGER_FTP_USER', 
        'HOSTINGER_FTP_PASS',
        'HOSTINGER_FTP_PATH'
      ]
    }

    const allowedSecrets = secretMappings[secretType]
    if (!allowedSecrets) {
      throw new Error('Invalid secret type')
    }

    // Check if user has permission (superuser for deployment secrets)
    if (secretType === 'deployment') {
      const { data: userData } = await supabaseClient
        .from('users')
        .select('superuser')
        .eq('supabase_id', user.id)
        .single()
      
      if (!userData?.superuser) {
        throw new Error('Insufficient permissions for deployment secrets')
      }
    }

    // Fetch secrets from environment (these are stored in Supabase secrets)
    const secrets: SecretsResponse = {}
    for (const secretName of allowedSecrets) {
      const secretValue = Deno.env.get(secretName)
      if (secretValue) {
        secrets[secretName] = secretValue
      }
    }

    return new Response(
      JSON.stringify({ secrets }),
      { 
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 400,
        headers: { 
          ...corsHeaders, 
          'Content-Type': 'application/json' 
        } 
      }
    )
  }
}) 