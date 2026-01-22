import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

    const adminClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { autoRefreshToken: false, persistSession: false }
    })

    const { from, to, body } = await req.json()

    if (!from || !to || !body) {
      return new Response(
        JSON.stringify({ error: 'Missing from, to, or body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Normalize phone (remove formatting)
    const normalizedFrom = from.replace(/\D/g, '')

    // Verify this is a simulated phone
    if (!normalizedFrom.match(/^202555100[1-5]$/)) {
      return new Response(
        JSON.stringify({ error: 'Invalid simulator phone number' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Record the outbound message from the simulated phone
    await adminClient.from('sms_simulator').insert({
      phone: normalizedFrom,
      direction: 'outbound',
      twilio_number: to,
      message: body,
    })

    // Now invoke the receive-sms function as if Twilio sent it
    // We need to simulate the Twilio webhook format (form data)
    const formData = new FormData()
    formData.append('From', '+1' + normalizedFrom)
    formData.append('To', to)
    formData.append('Body', body)

    const receiveResponse = await fetch(`${supabaseUrl}/functions/v1/receive-sms`, {
      method: 'POST',
      body: formData,
    })

    // Parse the TwiML response to get the reply message
    const twimlResponse = await receiveResponse.text()
    const messageMatch = twimlResponse.match(/<Message>([^<]+)<\/Message>/)
    const replyMessage = messageMatch ? messageMatch[1] : null

    // If there's a reply, record it as inbound to the simulator
    if (replyMessage) {
      await adminClient.from('sms_simulator').insert({
        phone: normalizedFrom,
        direction: 'inbound',
        twilio_number: to,
        message: replyMessage,
      })
    }

    return new Response(
      JSON.stringify({ success: true, reply: replyMessage }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('simulator-send-sms error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
