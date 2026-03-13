#!/bin/bash
# tournament_toggle.sh — Enable/disable daily auth sync for tournament weeks
#
# Usage:
#   tournament_toggle.sh on    # Enable daily sync
#   tournament_toggle.sh off   # Revert to weekly sync
#   tournament_toggle.sh       # Show current status

FLAG="/opt/stripcall/tournament_active"

case "${1:-status}" in
  on)
    touch "$FLAG"
    echo "Tournament mode ENABLED — auth sync will run daily at 4:05 AM Eastern"
    ;;
  off)
    rm -f "$FLAG"
    echo "Tournament mode DISABLED — auth sync will run weekly (Wednesday only)"
    ;;
  *)
    if [ -f "$FLAG" ]; then
      echo "Tournament mode is ON (daily auth sync)"
    else
      echo "Tournament mode is OFF (weekly auth sync, Wednesday)"
    fi
    ;;
esac
