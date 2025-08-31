/**
 * Simple Express server that keeps a persistent access counter on disk.
 * This demonstrates a "stateful" application: state (the counter) survives restarts
 * because it is stored in a file under ./data/count.txt.
 *
 * Notes:
 * - This is intended for demos and local use. For production, consider a proper data store.
 * - Synchronous fs calls are used for simplicity; they block the event loop.
 * - If multiple app instances write to the same file, you can get race conditions.
 */

const express = require("express");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = 3000;

// Absolute path to the counter file (stored under ./data/count.txt next to this file)
const DATA_FILE = path.join(__dirname, "data", "count.txt");

let accessCount = 0; // in-memory copy of the counter for the current process

// Ensure the 'data' directory exists so we can write the count file there
const dataDir = path.dirname(DATA_FILE);
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir);
}

/**
 * Load the current counter value from disk.
 * Returns 0 if the file does not exist or does not contain a valid number.
 * Uses synchronous I/O for simplicity (blocks the event loop while reading).
 */
function loadCount() {
  if (fs.existsSync(DATA_FILE)) {
    const data = fs.readFileSync(DATA_FILE, "utf8");
    const count = parseInt(data);
    return isNaN(count) ? 0 : count;
  }
  return 0;
}

/**
 * Persist the current in-memory counter value to disk.
 * Uses synchronous write to keep it simple and deterministic for this demo.
 */
function saveCount() {
  fs.writeFileSync(DATA_FILE, accessCount.toString(), "utf8");
  console.log(`Zähler in ${DATA_FILE} gespeichert: ${accessCount}`);
}

// Load from disk once at startup.
// Note: The return value is not assigned here; the route handler reloads on each request.
// If you prefer to initialize the in-memory value at startup, you could do:
// accessCount = loadCount();
loadCount();

/**
 * HTTP route for the root path:
 * - Reloads the counter from disk on each request (ensures persistence across restarts).
 * - Increments the counter and saves it back to disk.
 * - Responds with a simple HTML page showing the current count.
 *
 * Caveat:
 * - With concurrent requests, two requests might load the same old value and both write,
 *   resulting in a lost update. For proper concurrency, use a database or locking.
 */
app.get("/", (req, res) => {
  accessCount = loadCount(); // bring in sync with the on-disk value
  accessCount++; // increment for this visit
  saveCount(); // persist the new value

  res.send(`
    <div style="font-family: sans-serif; line-height: 1.4;">
      <div><strong>Version 1.3</strong></div>
      <p>Hello from the stateful app! You have visited this page <strong>${accessCount}</strong> times.</p>
      <p>The <strong>counter</strong> is the stateful component of this app; it is stored on disk so it persists across restarts.</p>
    </div>
  `);
});

// Start the HTTP server
app.listen(PORT, () => {
  console.log(`Server läuft auf http://localhost:${PORT}`);
});

/**
 * Graceful shutdown handlers:
 * - On SIGINT (Ctrl+C) or SIGTERM (container orchestration), save the counter and exit.
 * - This helps avoid losing the latest in-memory value if the process stops unexpectedly.
 */
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
