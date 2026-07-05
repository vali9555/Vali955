const http = require('http');
const WebSocket = require('ws');
const port = process.env.PORT || 8080;
const CONTROL_CODE = process.env.CONTROL_CODE || '2409';

// Simple HTTP server to provide a discovery endpoint and allow ngrok status queries
const server = http.createServer((req, res) => {
  if (req.url && req.url.startsWith('/public-ws')) {
    // Try to detect ngrok tunnel via its local API
    const ngrokApi = 'http://127.0.0.1:4040/api/tunnels';
    const httpGet = require('http').get;
    httpGet(ngrokApi, (ngRes) => {
      let body = '';
      ngRes.on('data', chunk => body += chunk);
      ngRes.on('end', () => {
        try {
          const data = JSON.parse(body);
          const tunnels = data.tunnels || [];
          // prefer https tunnel
          const t = tunnels.find(t=>t.proto==='https') || tunnels[0];
          if (t && t.public_url) {
            // convert https://... to wss://... (or http -> ws)
            const pub = t.public_url.replace(/^https:/,'wss:').replace(/^http:/,'ws:');
            res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
            res.end(JSON.stringify({ ws: pub }));
            return;
          }
        } catch (e) {
          // fallthrough
        }
        // no ngrok or no tunnel
        const fallback = { ws: null };
        res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
        res.end(JSON.stringify(fallback));
      });
    }).on('error', () => {
      res.writeHead(200, { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' });
      res.end(JSON.stringify({ ws: null }));
    });
    return;
  }
  res.writeHead(404);
  res.end();
});

const wss = new WebSocket.Server({ server });
server.listen(port, ()=> console.log(`HTTP+WS server listening on http://0.0.0.0:${port}`));

// Simple auth: controller clients must authenticate with { type: 'auth', code }
// Only authenticated controllers may send control actions; game clients may connect and receive messages.
wss.on('connection', function connection(ws, req) {
  ws.isController = false;
  console.log('Client connected');

  ws.on('message', function message(data) {
    try {
      const msg = JSON.parse(data.toString());
      console.log('Received message:', msg);
      if (msg && msg.type === 'auth') {
        if (msg.code === CONTROL_CODE) {
          ws.isController = true;
          ws.send(JSON.stringify({ type: 'auth', status: 'ok' }));
          console.log('Client authenticated as controller');
        } else {
          ws.send(JSON.stringify({ type: 'auth', status: 'failed' }));
          console.log('Client failed authentication');
        }
        return;
      }

      // Only accept control messages from authenticated controllers
      if (msg && ws.isController) {
        // Broadcast to all clients (including controller if desired)
        const out = JSON.stringify(msg);
        wss.clients.forEach(function each(client) {
          if (client.readyState === WebSocket.OPEN) {
            client.send(out);
          }
        });
      } else {
        // Ignore unauthenticated control messages
        console.log('Ignored message from unauthenticated client');
      }
    } catch (e) {
      console.error('Invalid message', e);
    }
  });

  ws.on('close', ()=>{ console.log('Client disconnected'); });
});

// Keep process alive
process.on('uncaughtException', (err) => { console.error('Uncaught', err); });
