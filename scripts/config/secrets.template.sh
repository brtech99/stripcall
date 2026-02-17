#!/bin/bash
# Single source of truth for all production credentials.
# Copy this to secrets.sh and fill in your actual values.

# --- Supabase (production) ---
export SUPABASE_URL="your-supabase-url-here"
export SUPABASE_ANON_KEY="your-supabase-anon-key-here"

# --- Supabase Postgres (direct connection for backups) ---
export SUPABASE_DB_HOST="db.your-project-ref.supabase.co"
export SUPABASE_DB_PORT="5432"
export SUPABASE_DB_NAME="postgres"
export SUPABASE_DB_USER="postgres"
export SUPABASE_DB_PASS="your-database-password-here"

# --- Twilio ---
export TWILIO_ACCOUNT_SID="your-twilio-account-sid-here"
export TWILIO_AUTH_TOKEN="your-twilio-auth-token-here"

# --- Hostinger FTP ---
export HOSTINGER_FTP_HOST="your-ftp-host-here"
export HOSTINGER_FTP_USER="your-ftp-username-here"
export HOSTINGER_FTP_PASS="your-ftp-password-here"
export HOSTINGER_FTP_PATH="/public_html"
export HOSTINGER_FTP_PORT="21"

# --- Hostinger domain ---
export HOSTINGER_DOMAIN="stripcall.us"
export HOSTINGER_SUBDOMAIN="app"
export HOSTINGER_APP_PATH="/app"

# --- Hostinger options ---
export HOSTINGER_SSL_ENABLED="true"
export HOSTINGER_FORCE_HTTPS="true"
export HOSTINGER_BACKUP_ENABLED="true"
export HOSTINGER_BACKUP_DIR="./backups"
export HOSTINGER_DELETE_OLD_FILES="true"
export HOSTINGER_VERBOSE_UPLOAD="true"
