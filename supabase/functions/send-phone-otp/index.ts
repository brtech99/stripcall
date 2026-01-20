import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Use one of the existing Twilio numbers for OTP
const OTP_FROM_PHONE = '+17542276679'  // Armorer number

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

    const { phone } = await req.json()

    if (!phone) {
      return new Response(JSON.stringify({ error: 'phone is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Normalize phone number (ensure it starts with +1 for US)
    let normalizedPhone = phone.replace(/[^\d+]/g, '')
    if (!normalizedPhone.startsWith('+')) {
      if (normalizedPhone.length === 10) {
        normalizedPhone = '+1' + normalizedPhone
      } else if (normalizedPhone.length === 11 && normalizedPhone.startsWith('1')) {
        normalizedPhone = '+' + normalizedPhone
      }
    }

    // Use service role for database operations
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Check for rate limiting - max 3 OTP requests per phone per hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    const { count: recentAttempts } = await supabase
      .from('phone_otp_codes')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .eq('phone', normalizedPhone)
      .gte('created_at', oneHourAgo)

    if (recentAttempts && recentAttempts >= 3) {
      return new Response(JSON.stringify({
        success: false,
        error: 'Too many verification attempts. Please try again later.'
      }), {
        status: 429,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Generate 6-digit OTP code
    const code = Math.floor(100000 + Math.random() * 900000).toString()

    // Delete any existing unverified codes for this user/phone
    await supabase
      .from('phone_otp_codes')
      .delete()
      .eq('user_id', user.id)
      .eq('phone', normalizedPhone)
      .is('verified_at', null)

    // Insert new OTP code
    const { error: insertError } = await supabase
      .from('phone_otp_codes')
      .insert({
        user_id: user.id,
        phone: normalizedPhone,
        code: code,
      })

    if (insertError) {
      console.error('Error inserting OTP code:', insertError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to generate verification code'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Send SMS via Twilio
    const smsBody = `Your StripCall verification code is: ${code}. This code expires in 10 minutes.`
    const twilioResult = await sendTwilioSms(OTP_FROM_PHONE, normalizedPhone, smsBody)

    if (!twilioResult.success) {
      // Delete the OTP code since SMS failed
      await supabase
        .from('phone_otp_codes')
        .delete()
        .eq('user_id', user.id)
        .eq('phone', normalizedPhone)
        .eq('code', code)

      return new Response(JSON.stringify({
        success: false,
        error: twilioResult.message
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({
      success: true,
      message: 'Verification code sent',
      phone: normalizedPhone,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Error sending phone OTP:', error)
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
      console.log(`OTP SMS sent successfully: ${data.sid}`)
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
