const http = require("http");

const PORT = process.env.PORT || 3000;
const TOKEN = process.env.DELTA_TOKEN;
const CLIENT = process.env.CLIENT_TOKEN;

let queue = [];

const allowed = ["scan_npcs", "attack_next", "stop"];

const server = http.createServer((req, res) => {
  res.setHeader("Content-Type", "application/json");

  const send = (code, data) => {
    res.writeHead(code);
    res.end(JSON.stringify(data));
  };

  if (req.url === "/health" && req.method === "GET") {
    return send(200, { status: "online" });
  }

  if (req.url === "/command" && req.method === "POST") {
    if (!TOKEN || req.headers["x-api-key"] !== TOKEN)
      return send(401, { error: "Unauthorized" });

    let body = "";
    req.on("data", chunk => body += chunk);
    req.on("end", () => {
      try {
        const data = JSON.parse(body);
        if (!allowed.includes(data.action))
          return send(400, { error: "Unknown action" });

        queue.push({ action: data.action });
        send(200, { accepted: true });
      } catch {
        send(400, { error: "Invalid JSON" });
      }
    });
    return;
  }

  if (req.url === "/next" && req.method === "GET") {
    if (!CLIENT || req.headers["x-api-key"] !== CLIENT)
      return send(401, { error: "Unauthorized" });

    return send(200, { command: queue.shift() || null });
  }

  send(404, { error: "Not found" });
});

server.listen(PORT, () => {
  console.log("Delta bridge is running on port " + PORT);
});





