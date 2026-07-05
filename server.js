const WebSocket = require('ws');
const port = process.env.PORT || 8080;
const CONTROL_CODE = process.env.CONTROL_CODE || '2409';

const wss = new WebSocket.Server({ port });
console.log(`WebSocket server listening on ws://0.0.0.0:${port}`);

// Simple auth: controller clients must authenticate with { type: 'auth', code }
// Only authenticated controllers may send control actions; game clients may connect and receive messages.
wss.on('connection', function connection(ws, req) {
  ws.isController = false;
  console.log('Client connected');

  ws.on('message', function message(data) {
    try {
      const msg = JSON.parse(data.toString());
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
        // Optionally, you can log or forward non-control messages here
        console.log('Ignored message from unauthenticated client');
      }
    } catch (e) {
      console.error('Invalid message', e);
    }
  });

  ws.on('close', ()=>{ console.log('Client disconnected'); });
});
