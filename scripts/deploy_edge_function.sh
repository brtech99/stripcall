#!/bin/bash

echo "🚀 Deploying get-app-secrets Edge Function..."

# Deploy the edge function
supabase functions deploy get-app-secrets

echo "✅ Edge function deployed!"
echo ""
echo "📝 Next steps:"
echo "1. Set up secrets in Supabase Vault:"
echo "   supabase secrets set FIREBASE_API_KEY=\"your_key_here\""
echo "   supabase secrets set FIREBASE_APP_ID=\"your_app_id_here\""
echo "   # ... and so on for all Firebase secrets"
echo ""
echo "2. Test the function by running your app and logging in" 