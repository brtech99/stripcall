#!/bin/bash

# StripCall Web Server Stop Script
# This script stops the local web server

echo "🛑 Stopping StripCall Web Server..."

# Kill any Python servers on port 3000
pkill -f "python3.*3000" || true
pkill -f "python.*3000" || true

echo "✅ Web server stopped" 