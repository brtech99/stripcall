// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.

// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

console.log("Hello from Functions!")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationRequest {
  title: string
  body: string
  data?: Record<string, any>
  userIds: string[]
  problemId?: string
}

serve(async (req) => {
  const startTime = Date.now();
  
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('DEBUG: Edge Function called')
    const { title, body, userIds, data, problemId }: NotificationRequest = await req.json()
    console.log('DEBUG: Request data:', { title, body, userIds, data, problemId })

    if (!title || !body || !userIds || userIds.length === 0) {
      console.log('DEBUG: Missing required fields')
      return new Response(
        JSON.stringify({ error: 'Missing required fields: title, body, userIds' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Get FCM service account key from secrets
    const fcmServiceAccountKey = Deno.env.get('FCM_SERVICE_ACCOUNT_KEY')
    if (!fcmServiceAccountKey) {
      return new Response(
        JSON.stringify({ error: 'FCM service account key not configured' }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    const serviceAccount = JSON.parse(fcmServiceAccountKey)
    const projectId = serviceAccount.project_id

    // Create Supabase client to get device tokens
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    console.log('DEBUG: Fetching device tokens for users:', userIds)
    // Get device tokens for the specified users
    const { data: deviceTokens, error: tokenError } = await supabase
      .from('device_tokens')
      .select('device_token')
      .in('user_id', userIds)

    console.log('DEBUG: Device tokens query result:', { deviceTokens, tokenError })

    if (tokenError) {
      console.error('Error fetching device tokens:', tokenError)
      return new Response(
        JSON.stringify({ error: 'Failed to fetch device tokens', details: tokenError.message }),
        { 
          status: 500, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    if (!deviceTokens || deviceTokens.length === 0) {
      console.log('DEBUG: No device tokens found')
      return new Response(
        JSON.stringify({ 
          success: true, 
          message: 'No device tokens found for the specified users',
          results: []
        }),
        { 
          status: 200, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
        }
      )
    }

    // Send FCM notifications to all device tokens
    const results = await Promise.all(
      deviceTokens.map(async (deviceToken) => {
        return await sendFCMNotification(serviceAccount, projectId, deviceToken.device_token, title, body, data)
      })
    )

    const endTime = Date.now();
    console.log(`DEBUG: Function completed in ${endTime - startTime}ms`);
    
    return new Response(
      JSON.stringify({
        success: true,
        message: `Sent notifications to ${results.length} devices`,
        results: results,
        executionTime: endTime - startTime
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )

  } catch (error) {
    console.error('Error in send-fcm-notification:', error)
    return new Response(
      JSON.stringify({ error: 'Internal server error', details: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

async function sendFCMNotification(
  serviceAccount: any,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, any>
) {
  try {
    // Create JWT token for FCM authentication
    const jwt = await createJWT(serviceAccount)
    
    // Prepare FCM message payload
    const fcmPayload = {
      message: {
        token: token,
        notification: {
          title: title,
          body: body,
        },
        data: data || {},
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      },
    }

    // Send to FCM HTTP v1 API
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${jwt}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(fcmPayload),
    })

    const responseData = await response.json()

    if (response.ok) {
      console.log(`FCM notification sent successfully to token: ${token.substring(0, 20)}...`)
      return {
        token: token.substring(0, 20) + '...',
        success: true,
        message: 'Notification sent successfully',
        fcmResponse: responseData
      }
    } else {
      console.error(`FCM API error for token ${token.substring(0, 20)}...:`, responseData)
      return {
        token: token.substring(0, 20) + '...',
        success: false,
        message: `FCM API error: ${responseData.error?.message || 'Unknown error'}`,
        fcmResponse: responseData
      }
    }

  } catch (error) {
    console.error(`Error sending FCM notification to token ${token.substring(0, 20)}...:`, error)
    return {
      token: token.substring(0, 20) + '...',
      success: false,
      message: `Error: ${error.message}`,
      error: error
    }
  }
}

// Cache JWT token to avoid recreating it on every request
let cachedJWT: { token: string; expiresAt: number } | null = null;

async function createJWT(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  
  // Check if we have a valid cached JWT
  if (cachedJWT && cachedJWT.expiresAt > now + 300) { // 5 minute buffer
    console.log('Using cached JWT token');
    return cachedJWT.token;
  }

  console.log('Creating new JWT token...');
  
  // First, get an access token from Google OAuth
  const accessToken = await getGoogleAccessToken(serviceAccount);
  
  // Cache the token
  cachedJWT = {
    token: accessToken,
    expiresAt: now + 3600
  };
  
  return accessToken;
}

async function getGoogleAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  
  const header = {
    alg: 'RS256',
    typ: 'JWT',
    kid: serviceAccount.private_key_id,
  }

  const payload = {
    iss: serviceAccount.client_email,
    sub: serviceAccount.client_email,
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600, // 1 hour
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
  }

  const encodedHeader = btoa(JSON.stringify(header))
  const encodedPayload = btoa(JSON.stringify(payload))
  
  const signatureInput = `${encodedHeader}.${encodedPayload}`
  const signature = await signRS256(signatureInput, serviceAccount.private_key)
  
  const jwt = `${signatureInput}.${signature}`;
  
  // Exchange JWT for access token
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error('Failed to get access token:', errorText);
    throw new Error(`Failed to get access token: ${response.status} ${errorText}`);
  }

  const data = await response.json();
  console.log('Successfully obtained access token');
  return data.access_token;
}

async function signRS256(input: string, privateKey: string): Promise<string> {
  // Import the private key
  const keyData = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s/g, '')
  
  const keyBuffer = Uint8Array.from(atob(keyData), c => c.charCodeAt(0))
  
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  )
  
  // Sign the input
  const encoder = new TextEncoder()
  const data = encoder.encode(input)
  const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cryptoKey, data)
  
  // Convert to base64
  return btoa(String.fromCharCode(...new Uint8Array(signature)))
}

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/send-fcm-notification' \
    --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0' \
    --header 'Content-Type: application/json' \
    --data '{"token":"YOUR_FCM_TOKEN","title":"Test","body":"Test message"}'

*/
