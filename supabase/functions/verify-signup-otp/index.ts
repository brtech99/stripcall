import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
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
    const { phone, code, email } = await req.json()

    if (!phone || !code) {
      return new Response(JSON.stringify({ error: 'phone and code are required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Normalize phone
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

    // Find the OTP code
    const { data: otpRecord, error: otpError } = await supabase
      .from('signup_otp_codes')
      .select('*')
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

    // Check expiry
    if (new Date(otpRecord.expires_at) < new Date()) {
      await supabase.from('signup_otp_codes').delete().eq('id', otpRecord.id)
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
      await supabase.from('signup_otp_codes').delete().eq('id', otpRecord.id)
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
      await supabase
        .from('signup_otp_codes')
        .update({ attempts: otpRecord.attempts + 1 })
        .eq('id', otpRecord.id)

      const remaining = 5 - (otpRecord.attempts + 1)
      return new Response(JSON.stringify({
        success: false,
        error: `Incorrect code. ${remaining} attempt${remaining !== 1 ? 's' : ''} remaining.`
      }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Code correct — mark verified
    await supabase
      .from('signup_otp_codes')
      .update({ verified_at: new Date().toISOString(), email: email || '' })
      .eq('id', otpRecord.id)

    // If email provided, update pending_users with the verified phone number
    if (email) {
      const { error: updateError } = await supabase
        .from('pending_users')
        .update({ phone_number: normalizedPhone })
        .eq('email', email)

      if (updateError) {
        console.error('Error updating pending_users phone:', updateError)
        // Don't fail — the phone was verified, pending_users update is best-effort
      }
    }

    // Clean up old codes for this phone
    await supabase
      .from('signup_otp_codes')
      .delete()
      .eq('phone', normalizedPhone)
      .neq('id', otpRecord.id)

    return new Response(JSON.stringify({
      success: true,
      message: 'Phone number verified',
      phone: normalizedPhone,
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    console.error('Error verifying signup OTP:', error)
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
