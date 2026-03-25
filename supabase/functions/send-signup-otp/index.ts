import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const OTP_FROM_PHONE = '+17542276679'

// Test phone numbers (SMS simulator) — use fixed code, don't send via Twilio
const TEST_PHONE_PREFIX = '+1202555'
const TEST_OTP_CODE = '123456'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { phone } = await req.json()

    if (!phone) {
      return new Response(JSON.stringify({ error: 'phone is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Normalize phone number
    let normalizedPhone = phone.replace(/[^\d+]/g, '')
    if (!normalizedPhone.startsWith('+')) {
      if (normalizedPhone.length === 10) {
        normalizedPhone = '+1' + normalizedPhone
      } else if (normalizedPhone.length === 11 && normalizedPhone.startsWith('1')) {
        normalizedPhone = '+' + normalizedPhone
      }
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Check if phone number is already in use by another user
    const { data: existingUser } = await supabase
      .from('users')
      .select('supabase_id')
      .eq('phonenbr', normalizedPhone)
      .limit(1)
      .maybeSingle()

    if (existingUser) {
      return new Response(JSON.stringify({
        success: false,
        error: 'This phone number is already associated with another account.'
      }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Cleanup expired codes older than 1 hour
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    await supabase
      .from('signup_otp_codes')
      .delete()
      .lt('created_at', oneHourAgo)

    // Rate limit: max 3 OTP requests per phone per hour
    const { count: recentAttempts } = await supabase
      .from('signup_otp_codes')
      .select('*', { count: 'exact', head: true })
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

    // Use test code for simulator phone numbers
    const isTestPhone = normalizedPhone.startsWith(TEST_PHONE_PREFIX)
    const code = isTestPhone ? TEST_OTP_CODE : Math.floor(100000 + Math.random() * 900000).toString()

    // Delete any existing unverified codes for this phone
    await supabase
      .from('signup_otp_codes')
      .delete()
      .eq('phone', normalizedPhone)
      .is('verified_at', null)

    // Insert new OTP code
    const { error: insertError } = await supabase
      .from('signup_otp_codes')
      .insert({
        phone: normalizedPhone,
        email: '', // Will be empty until verify links it
        code: code,
      })

    if (insertError) {
      console.error('Error inserting signup OTP code:', insertError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to generate verification code'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Skip Twilio for test phone numbers
    if (isTestPhone) {
      console.log(`Test phone detected (${normalizedPhone}), using code: ${TEST_OTP_CODE}`)
      return new Response(JSON.stringify({
        success: true,
        message: 'Verification code sent',
        phone: normalizedPhone,
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Send SMS via Twilio
    const smsBody = `Your StripCall verification code is: ${code}. This code expires in 10 minutes.`
    const twilioResult = await sendTwilioSms(OTP_FROM_PHONE, normalizedPhone, smsBody)

    if (!twilioResult.success) {
      await supabase
        .from('signup_otp_codes')
        .delete()
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
    console.error('Error sending signup OTP:', error)
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
        body: new URLSearchParams({ From: from, To: to, Body: body }),
      }
    )

    if (response.ok) {
      const data = await response.json()
      return { success: true, message: `SMS sent: ${data.sid}` }
    } else {
      const errorData = await response.json()
      return { success: false, message: `Twilio error: ${errorData.message || response.status}` }
    }
  } catch (err) {
    return { success: false, message: `Network error: ${err.message}` }
  }
}
