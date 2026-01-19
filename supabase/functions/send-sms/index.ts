import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Crew type -> Twilio phone mapping
const CREW_TYPE_TO_PHONE: Record<string, string> = {
  'Armorer': '+17542276679',
  'Medical': '+13127577223',
  'Natloff': '+16504803067',
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify authentication
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    )

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { problemId, message, type } = await req.json()

    if (!problemId) {
      return new Response(JSON.stringify({ error: 'problemId is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Use service role for database operations
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Get problem with reporter phone and crew type
    const { data: problem, error: problemError } = await supabase
      .from('problem')
      .select(`
        id,
        strip,
        reporter_phone,
        crew:crews!inner(
          id,
          crew_type:crewtypes!inner(crewtype)
        )
      `)
      .eq('id', problemId)
      .single()

    if (problemError || !problem) {
      console.error('Problem not found:', problemError)
      return new Response(JSON.stringify({
        success: false,
        message: 'Problem not found'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    if (!problem.reporter_phone) {
      // Not an error - just means this problem wasn't created via SMS
      return new Response(JSON.stringify({
        success: true,
        message: 'No SMS reporter for this problem'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Get sender name
    const { data: sender } = await supabase
      .from('users')
      .select('firstname, lastname')
      .eq('supabase_id', user.id)
      .single()

    const senderName = sender
      ? `${sender.firstname} ${sender.lastname}`.trim()
      : 'Crew Member'

    // Get the Twilio phone number for this crew type
    const crewTypeName = problem.crew?.crew_type?.crewtype
    const fromPhone = CREW_TYPE_TO_PHONE[crewTypeName]

    if (!fromPhone) {
      console.error(`No phone mapping for crew type: ${crewTypeName}`)
      return new Response(JSON.stringify({
        success: false,
        message: `No SMS number configured for ${crewTypeName} crew`
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Build SMS body based on type
    let smsBody: string
    if (type === 'on_my_way') {
      smsBody = `${senderName} is on the way to Strip ${problem.strip}.`
    } else {
      // Regular message
      smsBody = `[Strip ${problem.strip}] ${senderName}: ${message}`
    }

    // Send via Twilio
    const twilioResult = await sendTwilioSms(fromPhone, problem.reporter_phone, smsBody)

    return new Response(JSON.stringify({
      success: twilioResult.success,
      message: twilioResult.message,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Error sending SMS:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

async function sendTwilioSms(
  from: string,
  to: string,
  body: string
): Promise<{ success: boolean; message: string }> {
  const accountSid = Deno.env.get('TWILIO_ACCOUNT_SID')
  const authToken = Deno.env.get('TWILIO_AUTH_TOKEN')

  if (!accountSid || !authToken) {
    console.error('Twilio credentials not configured')
    return { success: false, message: 'Twilio credentials not configured' }
  }

  try {
    const response = await fetch(
      `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Basic ${btoa(`${accountSid}:${authToken}`)}`,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          From: from,
          To: to,
          Body: body,
        }),
      }
    )

    if (response.ok) {
      const data = await response.json()
      console.log(`SMS sent successfully: ${data.sid}`)
      return { success: true, message: `SMS sent: ${data.sid}` }
    } else {
      const errorData = await response.json()
      console.error('Twilio API error:', errorData)
      return {
        success: false,
        message: `Twilio error: ${errorData.message || response.status}`
      }
    }
  } catch (err) {
    console.error('Error calling Twilio API:', err)
    return { success: false, message: `Network error: ${err.message}` }
  }
}
