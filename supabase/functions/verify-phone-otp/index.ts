import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    const { phone, code } = await req.json()

    if (!phone || !code) {
      return new Response(JSON.stringify({ error: 'phone and code are required' }), {
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

    // Use service role for database operations
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Find the OTP code
    const { data: otpRecord, error: otpError } = await supabase
      .from('phone_otp_codes')
      .select('*')
      .eq('user_id', user.id)
      .eq('phone', normalizedPhone)
      .is('verified_at', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .single()

    if (otpError || !otpRecord) {
      return new Response(JSON.stringify({
        success: false,
        error: 'No pending verification found. Please request a new code.'
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Check if expired
    if (new Date(otpRecord.expires_at) < new Date()) {
      // Delete expired code
      await supabase
        .from('phone_otp_codes')
        .delete()
        .eq('id', otpRecord.id)

      return new Response(JSON.stringify({
        success: false,
        error: 'Verification code has expired. Please request a new code.'
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Check attempts (max 5)
    if (otpRecord.attempts >= 5) {
      // Delete the code after too many attempts
      await supabase
        .from('phone_otp_codes')
        .delete()
        .eq('id', otpRecord.id)

      return new Response(JSON.stringify({
        success: false,
        error: 'Too many incorrect attempts. Please request a new code.'
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Check code
    if (otpRecord.code !== code.trim()) {
      // Increment attempts
      await supabase
        .from('phone_otp_codes')
        .update({ attempts: otpRecord.attempts + 1 })
        .eq('id', otpRecord.id)

      const remainingAttempts = 5 - (otpRecord.attempts + 1)
      return new Response(JSON.stringify({
        success: false,
        error: `Incorrect code. ${remainingAttempts} attempt${remainingAttempts !== 1 ? 's' : ''} remaining.`
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Code is correct! Update the user's phone number
    const { error: updateError } = await supabase
      .from('users')
      .update({ phonenbr: normalizedPhone })
      .eq('supabase_id', user.id)

    if (updateError) {
      console.error('Error updating phone number:', updateError)
      return new Response(JSON.stringify({
        success: false,
        error: 'Failed to update phone number'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Mark OTP as verified and clean up
    await supabase
      .from('phone_otp_codes')
      .update({ verified_at: new Date().toISOString() })
      .eq('id', otpRecord.id)

    // Clean up old codes for this user/phone
    await supabase
      .from('phone_otp_codes')
      .delete()
      .eq('user_id', user.id)
      .eq('phone', normalizedPhone)
      .neq('id', otpRecord.id)

    return new Response(JSON.stringify({
      success: true,
      message: 'Phone number verified and updated successfully',
      phone: normalizedPhone,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Error verifying phone OTP:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
