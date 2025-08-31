/**
 * Simple Express + Kafka front-end:
 * - Serves an HTML form for 30 numeric features.
 * - Sends the form payload as JSON to Kafka topic "tracking-data".
 * - Correlates responses from topic "model-results" using a correlationId header.
 * - Uses instanceId to ensure this instance only consumes its own replies.
 *
 * Architecture notes:
 * - A single shared Kafka consumer is started to read all results.
 * - In-flight HTTP requests are tracked in a Map keyed by correlationId (pending).
 * - When a matching Kafka result arrives, the pending Promise is resolved.
 * - Timeouts clean up pending entries to avoid memory leaks.
 *
 * Caveats:
 * - This is a demo. Add input validation, rate limiting, and stronger error handling for production.
 * - Make sure both Kafka topics exist and the broker address is reachable from this service.
 */

const { Kafka } = require("kafkajs");
const express = require("express");

const app = express();
app.use(express.urlencoded({ extended: true }));
app.use(express.json());

const os = require("node:os");

// Instance identity used to filter responses meant for this process
const INSTANCE_ID =
  process.env.INSTANCE_ID || process.env.HOSTNAME || os.hostname();

// Kafka configuration
const KAFKA_BROKERS = ["my-kafka-cluster-kafka-bootstrap:9092"];
const CLIENT_ID = "consumer-id";
const TRACKING_TOPIC = "tracking-data";
const RESULTS_TOPIC = "model-results";

// Kafka client + producer and a long-lived consumer for results
const kafka = new Kafka({ clientId: CLIENT_ID, brokers: KAFKA_BROKERS });
const producer = kafka.producer();
const consumer = kafka.consumer({
  // Use a group per instance to ensure each instance gets its own result messages
  groupId: `${CLIENT_ID}-results-${INSTANCE_ID}`,
});

// In-flight requests: correlationId -> { resolve, reject, timer }
const pending = new Map();

/**
 * Start a shared results consumer:
 * - Subscribes to "model-results".
 * - For each message, checks correlationId and instanceId headers.
 * - If it matches a pending HTTP request, resolves it and clears its timeout.
 */
async function startResultsConsumer() {
  await consumer.connect();
  await consumer.subscribe({ topic: RESULTS_TOPIC, fromBeginning: false });
  await consumer.run({
    eachMessage: async ({ message }) => {
      // kafkajs headers are Buffers (or undefined) -> convert to string
      const cid = message.headers?.correlationId?.toString();
      const inst = message.headers?.instanceId?.toString();

      // Only handle replies addressed to this instance and having a correlationId
      if (!cid || inst !== INSTANCE_ID) return;

      // Result payload is JSON-encoded boolean in our pipeline; fall back to raw string if not JSON
      const raw = message.value ? message.value.toString() : "";
      let parsed;
      try {
        parsed = JSON.parse(raw);
      } catch {
        parsed = raw;
      }

      // Resolve the matching waiter, if any
      const waiter = pending.get(cid);
      if (waiter) {
        clearTimeout(waiter.timer);
        pending.delete(cid);
        waiter.resolve(parsed);
      }
    },
  });
}

/**
 * Helper to send a single message to the tracking topic.
 * The headers should include correlationId and instanceId for round-trip correlation.
 */
async function sendTrackingMessage(data, headers = {}) {
  return producer.send({
    topic: TRACKING_TOPIC,
    messages: [{ value: JSON.stringify(data), headers }],
  });
}

/**
 * Alternative one-off consumer approach (not used by the current flow).
 * Spawns a temporary consumer that stops after receiving exactly one matching result.
 * Kept for reference; the shared-consumer + pending-map approach is more efficient.
 */
async function consumeOneResult({ correlationId, timeoutMs = 10000 }) {
  const consumer = kafka.consumer({
    groupId: `${CLIENT_ID}-results-${Date.now()}-${Math.random()
      .toString(16)
      .slice(2)}`,
  });

  await consumer.connect();
  await consumer.subscribe({ topic: RESULTS_TOPIC, fromBeginning: false });

  return new Promise((resolve, reject) => {
    const timer = setTimeout(async () => {
      try {
        await consumer.stop();
        await consumer.disconnect();
      } catch {}
      reject(new Error("Timeout waiting for result"));
    }, timeoutMs);

    consumer
      .run({
        eachMessage: async ({ message }) => {
          const cid = message.headers?.correlationId
            ? message.headers.correlationId.toString()
            : undefined;
          if (cid !== correlationId) return;

          clearTimeout(timer);
          const raw = message.value ? message.value.toString() : "";
          let parsed;
          try {
            parsed = JSON.parse(raw);
          } catch {
            parsed = raw;
          }
          try {
            await consumer.stop();
            await consumer.disconnect();
          } catch {}
          resolve(parsed);
        },
      })
      .catch(async (err) => {
        clearTimeout(timer);
        try {
          await consumer.disconnect();
        } catch {}
        reject(err);
      });
  });
}

// Serve a minimal HTML form to collect 30 features and submit via fetch()
app.get("/", (req, res) => {
  const placeholders = [
    "radius1",
    "texture1",
    "perimeter1",
    "area1",
    "smoothness1",
    "compactness1",
    "concavity1",
    "concave_points1",
    "symmetry1",
    "fractal_dimension1",
    "radius2",
    "texture2",
    "perimeter2",
    "area2",
    "smoothness2",
    "compactness2",
    "concavity2",
    "concave_points2",
    "symmetry2",
    "fractal_dimension2",
    "radius3",
    "texture3",
    "perimeter3",
    "area3",
    "smoothness3",
    "compactness3",
    "concavity3",
    "concave_points3",
    "symmetry3",
    "fractal_dimension3",
  ];

  // Dynamically render 30 input fields
  const inputFields = placeholders
    .map(
      (p) =>
        `<input type="text" name="${p}" placeholder="${p}" id="${p}" required /><br/>`
    )
    .join("\n");

  // Basic client-side helpers:
  // - fillRandomValues: fill inputs with random numbers for testing
  // - handleSubmit: POST JSON to /send and display the boolean result
  res.send(`<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kafka Input Form</title>
  <script>
    function fillRandomValues(){const ps=${JSON.stringify(
      placeholders
    )};ps.forEach(p=>{document.getElementById(p).value=(Math.random()).toFixed(2);});}
    async function handleSubmit(e){
      e.preventDefault();
      const data=Object.fromEntries(new FormData(e.target).entries());
      try{
        const resp=await fetch('/send',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});
        if(!resp.ok){document.getElementById('resultValue').textContent='ERROR';return;}
        const json=await resp.json();
        document.getElementById('resultValue').textContent=String(json.result);
      }catch{document.getElementById('resultValue').textContent='ERROR';}
    }
  </script></head>
  <body>
    <h1>Input Data for Kafka</h1>
    <p>Aktueller Pod: <strong>${INSTANCE_ID}</strong></p>
    <form id="inputForm" onsubmit="handleSubmit(event)">${inputFields}
      <button type="button" onclick="fillRandomValues()">Fill Random Values</button>
      <button type="submit">Send to Kafka</button>
    </form>
    <p id="resultLabel">Breastcancer: <strong><span id="resultValue"></span></strong></p>
  </body></html>`);
});

/**
 * Send the payload to Kafka and wait for exactly one correlated reply.
 * - Generates a unique correlationId.
 * - Registers a resolver in the pending map with a timeout.
 * - Sends correlationId and instanceId as headers so the processor can echo them back.
 * - Awaits the shared consumer to resolve this HTTP request when the result arrives.
 */
app.post("/send", async (req, res) => {
  try {
    const correlationId = `${CLIENT_ID}-${Date.now()}-${Math.random()
      .toString(16)
      .slice(2)}`;

    // Create a promise that will be resolved by startResultsConsumer() on matching result
    const resultPromise = new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(correlationId);
        reject(new Error("Timeout waiting for result"));
      }, 15000);
      pending.set(correlationId, { resolve, reject, timer });
    });

    // Include instanceId so downstream can route the reply back to this instance
    await sendTrackingMessage(req.body, {
      correlationId,
      instanceId: INSTANCE_ID,
    });

    const result = await resultPromise;
    res.json({ ok: true, result });
  } catch (err) {
    console.error("Failed to send or receive from Kafka", err);
    res
      .status(500)
      .json({ ok: false, error: "Failed to send or receive from Kafka" });
  }
});

/**
 * App bootstrap:
 * - Connect producer, start the results consumer, then start the HTTP server.
 * - If startup fails, exit non-zero so orchestration can restart the container.
 */
async function start() {
  await producer.connect();
  await startResultsConsumer();
  app.listen(3000, () =>
    console.log("Node app is running at http://localhost:3000")
  );
}

start().catch((e) => {
  console.error("Startup failed:", e);
  process.exit(1);
});
