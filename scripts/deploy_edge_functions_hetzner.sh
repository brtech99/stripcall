#!/bin/bash
#
# Deploy Supabase Edge Functions to the Hetzner self-hosted instance.
#
# Usage: ./scripts/deploy_edge_functions_hetzner.sh
#
# Copies all function directories from supabase/functions/ to the Hetzner
# server and restarts the edge functions container.
#
# Prerequisites:
#   - SSH access to root@supabase.stripcall.us
#   - Edge function runtime container already running on Hetzner

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."
FUNCTIONS_DIR="$PROJECT_DIR/supabase/functions"

HETZNER_HOST="supabase.stripcall.us"
REMOTE_FUNCTIONS_DIR="/opt/supabase/supabase/functions"
CONTAINER_NAME="supabase-edge-functions"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Deploy Edge Functions to Hetzner ==="
echo ""

# Verify local functions exist
if [ ! -d "$FUNCTIONS_DIR" ]; then
    echo -e "${RED}ERROR: Functions directory not found at $FUNCTIONS_DIR${NC}"
    exit 1
fi

# List functions to deploy
FUNCTIONS=$(ls -d "$FUNCTIONS_DIR"/*/ 2>/dev/null | xargs -I{} basename {} | sort)
FUNC_COUNT=$(echo "$FUNCTIONS" | wc -l | tr -d ' ')

echo "Functions to deploy ($FUNC_COUNT):"
echo "$FUNCTIONS" | sed 's/^/  - /'
echo ""

# Verify Hetzner is reachable
echo "Checking Hetzner connectivity..."
if ! ssh -o ConnectTimeout=5 "root@$HETZNER_HOST" "echo ok" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Cannot SSH to root@$HETZNER_HOST${NC}"
    exit 1
fi
echo -e "${GREEN}Connected${NC}"
echo ""

# Copy shared deno config files
echo "--- Copying shared config files ---"
for f in deno.json deno.lock; do
    if [ -f "$FUNCTIONS_DIR/$f" ]; then
        scp "$FUNCTIONS_DIR/$f" "root@$HETZNER_HOST:$REMOTE_FUNCTIONS_DIR/$f"
        echo "  Copied $f"
    fi
done

# Copy each function directory
echo ""
echo "--- Copying function directories ---"
for func in $FUNCTIONS; do
    LOCAL_DIR="$FUNCTIONS_DIR/$func"
    if [ -d "$LOCAL_DIR" ]; then
        # Use rsync for efficient transfer (delete removed files)
        rsync -az --delete "$LOCAL_DIR/" "root@$HETZNER_HOST:$REMOTE_FUNCTIONS_DIR/$func/"
        echo "  Deployed: $func"
    fi
done

# Restart the edge functions container
echo ""
echo "--- Restarting edge functions container ---"
ssh "root@$HETZNER_HOST" "docker restart $CONTAINER_NAME"
echo -e "${GREEN}Container restarted${NC}"

# Wait for container to be healthy
echo ""
echo "--- Waiting for container to be ready ---"
sleep 3

# Verify with keep-alive
echo "--- Verifying deployment ---"
HEALTH_RESPONSE=$(ssh "root@$HETZNER_HOST" "curl -s -o /dev/null -w '%{http_code}' http://localhost:54321/functions/v1/keep-alive" 2>/dev/null || echo "000")

if [ "$HEALTH_RESPONSE" = "200" ]; then
    echo -e "${GREEN}keep-alive returned 200 — edge functions are running${NC}"
else
    echo -e "${YELLOW}WARNING: keep-alive returned $HEALTH_RESPONSE — functions may still be starting${NC}"
    echo "  Check manually: ssh root@$HETZNER_HOST 'docker logs $CONTAINER_NAME --tail 20'"
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Edge functions deployed to https://$HETZNER_HOST/functions/v1/"
echo ""
echo "Test a function:"
echo "  curl -s https://$HETZNER_HOST/functions/v1/keep-alive"
