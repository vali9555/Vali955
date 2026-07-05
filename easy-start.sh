#!/usr/bin/env bash
# easy-start.sh — simple wrapper to start server+tunnel and show public URL

set -e

ROOT=$(cd "$(dirname "$0")" && pwd)
cd "$ROOT"

echo "Starting remote server and tunnel (this may install localtunnel via npx)..."
./start-remote.sh &
START_PID=$!
echo "Launched start script (pid $START_PID). Waiting for public URL..."

PUBLIC_PATH=${PUBLIC_WS_PATH:-/tmp/public_ws.json}
for i in {1..30}; do
  if [ -f "$PUBLIC_PATH" ]; then
    ws=$(cat "$PUBLIC_PATH" | sed -n "s/.*\"ws\":\"\([^\"]*\)\".*/\1/p")
    if [ -n "$ws" ]; then
      echo "Public WS URL: $ws"
      echo "Control page: Live-Control.html (Code: 2409)"
      echo "Game page: Bet-2000-Schwalbkraiburg.html"
      echo "You can also query the discovery endpoint: curl http://localhost:8080/public-ws"
      # Try to open the pages in the default browser (best effort)
      OPEN_CMD=""
      if command -v xdg-open >/dev/null 2>&1; then
        OPEN_CMD="xdg-open"
      elif command -v sensible-browser >/dev/null 2>&1; then
        OPEN_CMD="sensible-browser"
      elif command -v gio >/dev/null 2>&1; then
        OPEN_CMD="gio open"
      fi
      if [ -n "$OPEN_CMD" ]; then
        # open local files (these trigger the clients to auto-discover the public WS URL)
        $OPEN_CMD "$(pwd)/Live-Control.html" >/dev/null 2>&1 || true
        $OPEN_CMD "$(pwd)/Bet-2000-Schwalbkraiburg.html" >/dev/null 2>&1 || true
        echo "Versuche, die Clientseiten im Browser zu öffnen..."
      else
        echo "Kein Browser‑Opener gefunden; öffne die Dateien manuell:" 
        echo "  $(pwd)/Live-Control.html"
        echo "  $(pwd)/Bet-2000-Schwalbkraiburg.html"
      fi
      exit 0
    fi
  fi
  sleep 1
done

echo "Timed out waiting for public URL. Check /tmp/lt.log or /tmp/ngrok.log for details." 
exit 1
