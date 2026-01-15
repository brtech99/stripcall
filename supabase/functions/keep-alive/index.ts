import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 1. Keep database active with a simple query
    console.log('🔄 Performing database keep-alive query...')
    const { data: dbCheck, error: dbError } = await supabase
      .from('users')
      .select('count')
      .limit(1)
    
    if (dbError) {
      console.error('❌ Database query failed:', dbError)
      throw dbError
    }

    console.log('✅ Database is active')

    // 2. Trigger GitHub workflow via repository dispatch
    const githubToken = Deno.env.get('GITHUB_TOKEN')
    const repoOwner = Deno.env.get('GITHUB_REPO_OWNER') || 'your-username'
    const repoName = Deno.env.get('GITHUB_REPO_NAME') || 'stripcall'

    if (githubToken) {
      console.log('🚀 Triggering GitHub workflow...')
      
      const githubResponse = await fetch(
        `https://api.github.com/repos/${repoOwner}/${repoName}/dispatches`,
        {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${githubToken}`,
            'Accept': 'application/vnd.github.v3+json',
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            event_type: 'keep-alive',
            client_payload: {
              timestamp: new Date().toISOString(),
              source: 'supabase-cron'
            }
          })
        }
      )

      if (!githubResponse.ok) {
        console.error('❌ GitHub workflow trigger failed:', await githubResponse.text())
      } else {
        console.log('✅ GitHub workflow triggered successfully')
      }
    } else {
      console.log('ℹ️ No GitHub token provided, skipping workflow trigger')
    }

    // 3. Log the keep-alive activity (optional)
    const timestamp = new Date().toISOString()
    console.log(`✅ Keep-alive completed at ${timestamp}`)

    return new Response(
      JSON.stringify({
        success: true,
        timestamp,
        database_active: true,
        github_triggered: !!githubToken
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('❌ Keep-alive failed:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
        timestamp: new Date().toISOString()
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      },
    )
  }
})
