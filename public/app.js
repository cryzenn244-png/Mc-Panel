const $ = (id) => document.getElementById(id);
const labels = {
  overview: ["Overview", "OVERVIEW"],
  minecraft: ["Minecraft", "MINECRAFT"],
  bots: ["Discord Bots", "DISCORD BOTS"],
  vps: ["VPS Instances", "VPS INSTANCES"],
  nodes: ["Nodes", "NODES"],
  eggs: ["Eggs & Nests", "EGGS & NESTS"],
  backups: ["Backups", "BACKUPS"]
};
function bytes(n) {
  if (!Number.isFinite(n)) return "Unavailable";
  const units = ["B", "KB", "MB", "GB", "TB"]; let i = 0; let x = n;
  while (x >= 1024 && i < units.length - 1) { x /= 1024; i++; }
  return `${x.toFixed(i >= 2 ? 1 : 0)} ${units[i]}`;
}
function duration(seconds) {
  if (!Number.isFinite(seconds)) return "—";
  const d = Math.floor(seconds / 86400); const h = Math.floor(seconds % 86400 / 3600);
  const m = Math.floor(seconds % 3600 / 60);
  return d ? `${d}d ${h}h` : h ? `${h}h ${m}m` : `${m}m`;
}
function navigate(view) {
  if (!labels[view]) return;
  document.querySelectorAll(".view").forEach(el => el.classList.add("hidden"));
  document.querySelectorAll(".nav[data-view]").forEach(el => el.classList.toggle("active", el.dataset.view === view));
  const overview = view === "overview";
  $("overview").classList.toggle("hidden", !overview);
  $("placeholder").classList.toggle("hidden", overview);
  $("page-title").textContent = labels[view][0];
  $("crumb").textContent = labels[view][1];
  if (!overview) {
    $("placeholder-title").textContent = `${labels[view][0]} module`;
    $("placeholder-text").textContent = view === "nodes"
      ? "This bootstrap can read host telemetry, but node registration, agent authentication, resource reservations, and remote-node control are not implemented yet."
      : "This module is not implemented in this bootstrap. No fake servers, bots, VPS instances, eggs, backups, or success states are shown.";
  }
}
document.querySelectorAll("[data-view]").forEach(el => el.addEventListener("click", () => navigate(el.dataset.view)));
async function refresh() {
  $("api-status").textContent = "Checking…";
  $("notice").classList.add("hidden");
  try {
    const [healthResponse, systemResponse] = await Promise.all([
      fetch("/api/v1/health", { cache: "no-store" }),
      fetch("/api/v1/system", { cache: "no-store" })
    ]);
    if (!healthResponse.ok || !systemResponse.ok) throw new Error("API request failed");
    const health = await healthResponse.json(); const { system: s } = await systemResponse.json();
    $("api-status").textContent = health.status.toUpperCase();
    $("cpu-count").textContent = s.cpuLogicalCount;
    $("cpu-model").textContent = s.cpuModel || "Processor model unavailable";
    $("mem-total").textContent = bytes(s.memory.totalBytes);
    const usedPct = s.memory.totalBytes ? s.memory.usedBytes / s.memory.totalBytes * 100 : 0;
    $("mem-meter").style.width = `${Math.min(100, Math.max(0, usedPct))}%`;
    $("mem-foot").textContent = `${usedPct.toFixed(1)}% used · ${bytes(s.memory.freeBytes)} free`;
    $("host-uptime").textContent = duration(s.uptimeSeconds);
    $("host-name").textContent = s.hostname;
    $("platform").textContent = s.platform;
    $("platform-version").textContent = `${s.release} · ${s.arch}`;
    $("mem-used").textContent = bytes(s.memory.usedBytes);
    $("mem-free").textContent = bytes(s.memory.freeBytes);
    $("load-average").textContent = Array.isArray(s.loadAverage) ? s.loadAverage.map(v => v.toFixed(2)).join(" / ") : "Unavailable";
    $("node-version").textContent = s.nodeVersion;
    $("panel-uptime").textContent = duration(s.panelUptimeSeconds);
    $("last-updated").textContent = `UPDATED ${new Date().toLocaleTimeString()}`;
    $("footer-time").textContent = new Date().toLocaleString();
  } catch (err) {
    $("api-status").textContent = "OFFLINE";
    $("notice").textContent = `Could not load live system data: ${err.message}. Check that the MC Panel service is running.`;
    $("notice").classList.remove("hidden");
  }
}
$("refresh").addEventListener("click", refresh);
refresh();
