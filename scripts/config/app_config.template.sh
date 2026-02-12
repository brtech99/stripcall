#!/bin/bash

# Template configuration file
# Copy this to app_config.sh and fill in your Supabase credentials

export SUPABASE_URL="your-supabase-url-here"
export SUPABASE_ANON_KEY="your-supabase-anon-key-here"

echo "✅ Supabase configuration loaded"
echo "🔐 Other secrets will be fetched by the app from Vault" 