#!/usr/bin/env bash
# start-remote.sh
# Starts the Node WebSocket server and optionally ngrok (if installed).
# Usage: ./start-remote.sh

PORT=${PORT:-8080}

echo "Starting server on port $PORT..."
# start server in background
node server.js &
SERVER_PID=$!
sleep 0.5

PUBLIC_PATH=${PUBLIC_WS_PATH:-/tmp/public_ws.json}

function write_public_ws() {
  local url="$1"
  if [ -n "$url" ]; then
    # convert http/https to ws/wss
    ws_url=$(echo "$url" | sed -E 's/^https:/wss:/; s/^http:/ws:/')
    printf '{"ws":"%s"}' "$ws_url" > "$PUBLIC_PATH"
    echo "Wrote public WS URL to $PUBLIC_PATH"
  fi
}

# First, try ngrok only if it's installed AND an auth token is provided
if command -v ngrok >/dev/null 2>&1 && [ -n "$NGROK_AUTHTOKEN" ]; then
  echo "ngrok found and token present — starting HTTP tunnel for port $PORT..."
  ngrok authtoken "$NGROK_AUTHTOKEN" >/dev/null 2>&1 || true
  ngrok http $PORT --log=stdout >/tmp/ngrok.log 2>&1 &
  NGROK_PID=$!
  echo "ngrok started (pid $NGROK_PID). Waiting for tunnel..."
  for i in {1..15}; do
    out=$(curl -s http://127.0.0.1:4040/api/tunnels 2>/dev/null || true)
    if [ -n "$out" ]; then
      # try to parse first https or http tunnel
      pub=$(echo "$out" | grep -o '"public_url":"[^"]\+' | head -n1 | sed -E 's/"public_url":"//')
      if [ -n "$pub" ]; then
        write_public_ws "$pub"
        break
      fi
    fi
    sleep 1
  done
  echo "You can query the public WS URL with: cat $PUBLIC_PATH or curl http://localhost:$PORT/public-ws"
else
  echo "ngrok not used (not installed or token missing). Trying localtunnel via npx..."
  if command -v npx >/dev/null 2>&1; then
    # start localtunnel in background and capture output
    npx localtunnel --port $PORT > /tmp/lt.log 2>&1 &
    LT_PID=$!
    echo "localtunnel started (pid $LT_PID). Waiting for public url..."
    for i in {1..20}; do
      if grep -q "http" /tmp/lt.log 2>/dev/null; then
        # extract first https/http url
        pub=$(grep -oE 'https?://[^ ]+' /tmp/lt.log | head -n1)
        if [ -n "$pub" ]; then
          write_public_ws "$pub"
          break
        fi
      fi
      sleep 1
    done
    if [ -z "$pub" ]; then
      echo "localtunnel didn't produce a public URL; check /tmp/lt.log"
    fi
  else
    echo "npx not available; cannot start localtunnel. Server still running locally."
  fi
fi

echo "Server PID: $SERVER_PID"

# wait for server process
wait $SERVER_PID
