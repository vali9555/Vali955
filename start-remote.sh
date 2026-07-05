#!/usr/bin/env bash
# start-remote.sh
# Starts the Node WebSocket server and optionally ngrok (if installed).
# Usage: ./start-remote.sh

PORT=${PORT:-8080}
NODE= node

echo "Starting server on port $PORT..."
# start server in background
node server.js &
SERVER_PID=$!
sleep 0.5

# Try to start ngrok if available
if command -v ngrok >/dev/null 2>&1; then
  echo "ngrok found — starting HTTP tunnel for port $PORT..."
  # start ngrok even if token not provided; user may have local auth
  ngrok http $PORT --log=stdout >/dev/null &
  NGROK_PID=$!
  echo "ngrok started (pid $NGROK_PID). Waiting for tunnel..."
  # wait for ngrok API to appear
  for i in {1..15}; do
    if curl -s http://127.0.0.1:4040/api/tunnels >/dev/null 2>&1; then
      echo "ngrok API available"
      break
    fi
    sleep 1
  done
  echo "You can query the public WS URL with: curl http://127.0.0.1:4040/api/tunnels"
  echo "Also the game exposes /public-ws on the server: http://localhost:$PORT/public-ws"
else
  echo "ngrok not installed; server is running but not publicly exposed."
fi

echo "Server PID: $SERVER_PID"

# wait for server process
wait $SERVER_PID
