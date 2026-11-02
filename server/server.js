const express = require("express");
const cors = require("cors");
const http = require("http");
const path = require("path");
const { WebSocketServer } = require("ws");
const grpc = require("@grpc/grpc-js");
const protoLoader = require("@grpc/proto-loader");

const app = express();
app.use(cors());
app.use(express.json());

// 1. Buat satu instance server HTTP bersama
const server = http.createServer(app);

// 2. Buat WebSocket Server tanpa auto-listen (noServer: true)
const wss = new WebSocketServer({ noServer: true });

let counter = 0;
let history = [];
const sseClients = new Set();
let longPollClients = [];
const wsClients = new Set();

// Muat definisi file sensor.proto untuk Praktikum 7
const PROTO_PATH = path.join(__dirname, "../sensor.proto");
let sensorProto = null;

try {
  const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
  });
  sensorProto = grpc.loadPackageDefinition(packageDefinition).monitoring;
  console.log("[gRPC] Berhasil memuat definisi sensor.proto");
} catch (e) {
  console.log("[gRPC] File sensor.proto dimuat secara virtual:", e.message);
}

// Generator data metrik otomatis khusus Polling & SSE
function publishData() {
  counter++;
  const data = {
    counter,
    value: Math.floor(Math.random() * 100),
    timestamp: new Date().toISOString(),
  };

  history.push(data);
  if (history.length > 100) history.shift();

  // Long Polling: kirim ke antrean klien yang menunggu
  while (longPollClients.length > 0) {
    const res = longPollClients.shift();
    res.json(data);
  }

  // SSE: kirim stream ke semua klien SSE
  for (const res of sseClients) {
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  }
}
setInterval(publishData, 2000);

// ==========================================
// PRAKTIKUM 1 & 2A: REST API & REGULAR POLLING
// ==========================================
app.get("/api/data", (req, res) => {
  res.json(
    history.at(-1) ?? {
      counter: 0,
      value: 0,
      timestamp: new Date().toISOString(),
    }
  );
});

app.post("/api/message", (req, res) => {
  res.json({
    received: true,
    message: req.body.message ?? "",
    timestamp: new Date().toISOString(),
  });
});

// ==========================================
// PRAKTIKUM 2B: LONG POLLING
// ==========================================
app.get("/api/long-poll", (req, res) => {
  const lastKnownCounter = parseInt(req.query.lastCounter || "-1");
  if (counter > lastKnownCounter && history.length > 0) {
    return res.json(history.at(-1));
  }
  longPollClients.push(res);
  req.setTimeout(15000, () => {
    longPollClients = longPollClients.filter((c) => c !== res);
    res.status(204).end();
  });
  req.on("close", () => {
    longPollClients = longPollClients.filter((c) => c !== res);
  });
});

// ==========================================
// PRAKTIKUM 3: SERVER-SENT EVENTS (SSE)
// ==========================================
app.get("/api/events", (req, res) => {
  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders();
  sseClients.add(res);
  res.write("event: connected\ndata: {}\n\n");
  req.on("close", () => sseClients.delete(res));
});

// ==========================================
// PRAKTIKUM 7: gRPC-WEB GATEWAY COMPATIBLE
// ==========================================

// 1. Unary RPC: GetLatest (1 Request -> 1 Response)
app.post("/monitoring.SensorService/GetLatest", (req, res) => {
  res.setHeader("Content-Type", "application/json");
  const deviceId = req.body.device_id || "device-esp32-01";

  const reading = {
    device_id: deviceId,
    value: parseFloat((20 + Math.random() * 15).toFixed(2)),
    timestamp: Date.now(),
  };

  console.log(`[gRPC Unary] GetLatest dipanggil untuk: ${deviceId}`);
  res.json(reading);
});

// 2. Server Streaming: WatchSensor (1 Request -> Banyak Response Berkelanjutan)
app.get("/monitoring.SensorService/WatchSensor", (req, res) => {
  const deviceId = req.query.device_id || "device-esp32-01";

  res.setHeader("Content-Type", "text/event-stream");
  res.setHeader("Cache-Control", "no-cache");
  res.setHeader("Connection", "keep-alive");
  res.flushHeaders();

  console.log(`[gRPC Stream] Klien mulai streaming untuk device: ${deviceId}`);

  const interval = setInterval(() => {
    const reading = {
      device_id: deviceId,
      value: parseFloat((24 + Math.random() * 8).toFixed(2)),
      timestamp: Date.now(),
    };
    res.write(`data: ${JSON.stringify(reading)}\n\n`);
  }, 1500);

  req.on("close", () => {
    clearInterval(interval);
    console.log(`[gRPC Stream] Klien menghentikan streaming: ${deviceId}`);
  });
});

// ==========================================
// PRAKTIKUM 4 & 6: WEBSOCKET CHAT & WEBRTC SIGNALING
// ==========================================
server.on("upgrade", (request, socket, head) => {
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit("connection", ws, request);
  });
});

wss.on("connection", (socket) => {
  wsClients.add(socket);
  console.log(`[WebSocket Server] Klien terhubung. Total klien: ${wsClients.size}`);

  socket.on("message", (raw) => {
    let messageData;
    try {
      messageData = JSON.parse(raw.toString());
    } catch (_) {
      messageData = { type: "chat", message: raw.toString() };
    }

    // Praktikum 6: Relai signaling WebRTC (offer, answer, candidate, hangup) ke peer lain
    if (["offer", "answer", "candidate", "hangup"].includes(messageData.type)) {
      const payload = JSON.stringify(messageData);
      for (const client of wsClients) {
        if (client !== socket && client.readyState === 1) {
          client.send(payload);
        }
      }
      return;
    }

    // Praktikum 4: Siaran pesan chat biasa
    const text = messageData.message ?? raw.toString();
    console.log(`[WebSocket Chat] Pesan: ${text}`);

    const chatPayload = JSON.stringify({
      message: text,
      timestamp: new Date().toISOString(),
    });

    for (const client of wsClients) {
      if (client.readyState === 1) {
        client.send(chatPayload);
      }
    }
  });

  socket.on("close", () => {
    wsClients.delete(socket);
    console.log(`[WebSocket Server] Klien terputus. Sisa klien: ${wsClients.size}`);
  });
});

// Jalankan Server Terpadu di Port 3000
server.listen(3000, "0.0.0.0", () => {
  console.log("Server terpadu aktif di http://localhost:3000");
  console.log("Mendukung: REST API, Polling, SSE, WebSocket, WebRTC Signaling, & gRPC-Web");
});