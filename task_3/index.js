const express = require("express");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = 3000;
const DATA_FILE = path.join(__dirname, "data", "count.txt"); // Pfad zur Zählerdatei
let accessCount = 0;

// Sicherstellen, dass das 'data'-Verzeichnis existiert
const dataDir = path.dirname(DATA_FILE);
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir);
}

// Zähler beim Start der App laden
function loadCount() {
  if (fs.existsSync(DATA_FILE)) {
    const data = fs.readFileSync(DATA_FILE, "utf8");
    const count = parseInt(data);
    return isNaN(count) ? 0 : count;
  }
  return 0;
}

// Zähler speichern
function saveCount() {
  fs.writeFileSync(DATA_FILE, accessCount.toString(), "utf8");
  console.log(`Zähler in ${DATA_FILE} gespeichert: ${accessCount}`);
}

// Zähler beim Start laden
loadCount();

// Route für den HTTP-Zugriff
// ...existing code...
app.get("/", (req, res) => {
  accessCount = loadCount();
  accessCount++;
  saveCount(); // Zähler bei jedem Zugriff speichern

  res.send(`
    <div style="font-family: sans-serif; line-height: 1.4;">
      <div><strong>Version 1.3</strong></div>
      <p>Hello from the stateful app! You have visited this page <strong>${accessCount}</strong> times.</p>
      <p>The <strong>counter</strong> is the stateful component of this app; it is stored on disk so it persists across restarts.</p>
    </div>
  `);
});

app.listen(PORT, () => {
  console.log(`Server läuft auf http://localhost:${PORT}`);
});

// SIGINT (Ctrl+C) und SIGTERM (Kubernetes Beenden) behandeln
process.on("SIGINT", () => {
  console.log("SIGINT empfangen. Zähler speichern und beenden.");
  saveCount();
  process.exit(0);
});

process.on("SIGTERM", () => {
  console.log("SIGTERM empfangen. Zähler speichern und beenden.");
  saveCount();
  process.exit(0);
});
