const WebSocket = require('ws');
const port = process.env.PORT || 8080;
const wss = new WebSocket.Server({ port });
console.log(`WebSocket server listening on ws://0.0.0.0:${port}`);

wss.on('connection', function connection(ws, req) {
  console.log('Client connected');
  ws.on('message', function message(data) {
    try {
      // echo message to all clients
      const msg = data.toString();
      wss.clients.forEach(function each(client) {
        if (client !== ws && client.readyState === WebSocket.OPEN) {
          client.send(msg);
        }
      });
    } catch (e) {
      console.error('Invalid message', e);
    }
  });
  ws.on('close', ()=>{ console.log('Client disconnected'); });
});
