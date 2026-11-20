import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "..");
const publicDir = path.join(root, "public");
const host = process.env.APP_HOST || "127.0.0.1";
const port = Number.parseInt(process.env.APP_PORT || "6789", 10);
const appName = process.env.APP_NAME || "MC Panel";
const databasePath = process.env.DATABASE_PATH || path.join(root, "storage", "mc-panel.sqlite");
const secret = process.env.APP_SECRET || "";
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error("APP_PORT must be 1-65535.");
if (secret.length < 32 && process.env.NODE_ENV === "production") throw new Error("APP_SECRET must be at least 32 characters in production.");

fs.mkdirSync(path.dirname(databasePath), { recursive: true });

const mime = {
  ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8", ".svg": "image/svg+xml",
  ".json": "application/json; charset=utf-8", ".ico": "image/x-icon"
};
const started = Date.now();

function json(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Content-Security-Policy": "default-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"
  });
  res.end(body);
}
function safeEqual(a, b) {
  const aa = Buffer.from(String(a)); const bb = Buffer.from(String(b));
  return aa.length === bb.length && crypto.timingSafeEqual(aa, bb);
}
function getAuth(req) {
  const configured = process.env.ADMIN_API_TOKEN || "";
  const header = req.headers.authorization || "";
  return configured && header.startsWith("Bearer ") && safeEqual(header.slice(7), configured);
}
function readBody(req, limit = 64 * 1024) {
  return new Promise((resolve, reject) => {
    let data = ""; let size = 0;
    req.on("data", chunk => {
      size += chunk.length;
      if (size > limit) { reject(new Error("Request body too large")); req.destroy(); return; }
      data += chunk.toString("utf8");
    });
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}
function stats() {
  const totalMem = os.totalmem();
  const freeMem = os.freemem();
  const cpus = os.cpus() || [];
  let disk = null;
  try {
    const stat = fs.statfsSync(root);
    disk = { totalBytes: stat.blocks * stat.bsize, freeBytes: stat.bavail * stat.bsize };
  } catch {}
  return {
    hostname: os.hostname(),
    platform: os.platform(),
    release: os.release(),
    arch: os.arch(),
    uptimeSeconds: Math.floor(os.uptime()),
    processUptimeSeconds: Math.floor(process.uptime()),
    cpuLogicalCount: cpus.length,
    cpuModel: cpus[0]?.model || "unknown",
    memory: { totalBytes: totalMem, freeBytes: freeMem, usedBytes: totalMem - freeMem },
    disk,
    loadAverage: os.loadavg(),
    nodeVersion: process.version,
    phpVersion: (() => { try { return fs.readFileSync("/dev/null") && null; } catch { return null; } })(),
    panelUptimeSeconds: Math.floor((Date.now() - started) / 1000)
  };
}

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url || "/", `http://${req.headers.host || `${host}:${port}`}`);
    if (req.method === "GET" && url.pathname === "/api/v1/health") {
      return json(res, 200, { ok: true, name: appName, status: "healthy", time: new Date().toISOString(), uptimeSeconds: Math.floor(process.uptime()) });
    }
    if (req.method === "GET" && url.pathname === "/api/v1/system") {
      return json(res, 200, { ok: true, system: stats() });
    }
    if (url.pathname.startsWith("/api/v1/admin/")) {
      if (!getAuth(req)) return json(res, 401, { ok: false, error: "unauthorized", message: "Set ADMIN_API_TOKEN in the service environment and provide a Bearer token." });
      if (req.method === "GET" && url.pathname === "/api/v1/admin/config") {
        return json(res, 200, { ok: true, appName, host, port, databaseConfigured: Boolean(databasePath), nodeVersion: process.version });
      }
      if (req.method === "POST" && url.pathname === "/api/v1/admin/echo") {
        const raw = await readBody(req);
        let parsed;
        try { parsed = raw ? JSON.parse(raw) : {}; } catch { return json(res, 400, { ok: false, error: "invalid_json" }); }
        return json(res, 200, { ok: true, receivedKeys: Object.keys(parsed).slice(0, 50) });
      }
      return json(res, 404, { ok: false, error: "not_found" });
    }
    if (url.pathname.startsWith("/api/")) return json(res, 404, { ok: false, error: "not_found" });
    let requested = url.pathname === "/" ? "/index.html" : decodeURIComponent(url.pathname);
    if (requested.includes("\0") || requested.split("/").includes("..")) return json(res, 400, { ok: false, error: "bad_path" });
    const file = path.resolve(publicDir, "." + requested);
    if (!file.startsWith(publicDir + path.sep) && file !== path.join(publicDir, "index.html")) return json(res, 403, { ok: false, error: "forbidden" });
    let target = file;
    if (!fs.existsSync(target) || !fs.statSync(target).isFile()) {
      if (!path.extname(requested)) target = path.join(publicDir, "index.html");
      else return json(res, 404, { ok: false, error: "not_found" });
    }
    const ext = path.extname(target);
    const content = fs.readFileSync(target);
    res.writeHead(200, {
      "Content-Type": mime[ext] || "application/octet-stream",
      "Content-Length": content.length,
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
      "Content-Security-Policy": "default-src 'self'; style-src 'self'; script-src 'self'; connect-src 'self'; img-src 'self' data:; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"
    });
    res.end(content);
  } catch (error) {
    if (!res.headersSent) json(res, 500, { ok: false, error: "internal_error", message: process.env.NODE_ENV === "production" ? "Unexpected server error" : String(error.message || error) });
    else res.destroy();
  }
});

server.listen(port, host, () => {
  console.log(`${appName} listening on http://${host}:${port}`);
});
server.on("error", err => {
  console.error("Server failed:", err.message);
  process.exitCode = 1;
});
process.on("SIGTERM", () => server.close(() => process.exit(0)));
process.on("SIGINT", () => server.close(() => process.exit(0)));
