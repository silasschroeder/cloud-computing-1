# Stream processing app using Faust:
# - Consumes JSON messages from Kafka topic "tracking-data".
# - Loads Naive Bayes model parameters from S3/MinIO at startup.
# - Predicts breast cancer (malignant vs. benign) using a Gaussian Naive Bayes formula.
# - Produces a boolean result to Kafka topic "model-results".
# - For correlation, selected inbound headers (correlationId, instanceId) are forwarded to the outbound message.
#
# Notes:
# - This example assumes the input JSON has 30 numerical features and that their order matches the model training.
# - Storing credentials in code is not recommended for production; prefer env vars/secret managers.
# - The code prints debug logs for visibility; reduce or remove in production.

import faust
import s3fs
import numpy as np
import json

app = faust.App(
    "s3-stream",
    # Kafka bootstrap (K8s DNS in this example)
    broker="kafka://my-kafka-cluster-kafka-bootstrap.default.svc.cluster.local:9092",
    # Incoming payloads are JSON and will be deserialized to Python dicts
    value_serializer="json",
    # Do not attempt to create topics automatically (topics must already exist)
    topic_allow_declare=False,  # prevents declaring/creating topics
    topic_disable_leader=True,  # prevents creation of the app's default internal topic
)

# Duplicate import of numpy below is unnecessary; kept unchanged for parity with the original file.
import numpy as np


def gaussian_nb_predict(x, params):
  """
  x: list or np.array with 30 features (floats)
  params: stored Naive Bayes parameters in the following keys:
      - "class_prior_": prior probability per class (shape [n_classes])
      - "theta_": mean per class/feature (shape [n_classes, n_features])
      - "sigma_": variance per class/feature (shape [n_classes, n_features])
      - "classes_": list/array of class labels (e.g., [0, 1])
  return: bool -> True = breast cancer (Malignant), False = no cancer (Benign)

  Implementation details:
  - Uses Gaussian likelihood per feature and sums log-likelihoods to avoid underflow.
  - Assumes variances are strictly positive; if not, you may need variance smoothing (e.g., var + 1e-9).
  """
  x = np.array(x)
  priors = np.array(params["class_prior_"])
  means = np.array(params["theta_"])
  vars_ = np.array(params["sigma_"])

  log_probs = []
  for i, cls in enumerate(params["classes_"]):
    mean = means[i]
    var = vars_[i]
    # Gaussian log-likelihood summed across features
    log_likelihood = -0.5 * np.sum(np.log(2 * np.pi * var) + ((x - mean) ** 2) / var)
    log_probs.append(np.log(priors[i]) + log_likelihood)

  # Transform log-probs to normalized probabilities for numerical stability
  log_probs = np.array(log_probs)
  probs = np.exp(log_probs - log_probs.max())
  probs = probs / probs.sum()

  # Classes convention: 1 = Cancer (Malignant), 0 = No Cancer (Benign)
  pred_class = params["classes_"][np.argmax(probs)]
  return bool(pred_class == 1)


# Kafka topics:
# - input_topic: consumes JSON values; evt.value will be a dict
# - results_topic: produces boolean values serialized as JSON (true/false)
input_topic = app.topic("tracking-data", value_type=bytes)
results_topic = app.topic("model-results", value_type=bool, value_serializer="json")

# S3/MinIO filesystem client.
# For production, do not hardcode credentials; use environment variables or secrets.
fs = s3fs.S3FileSystem(
  key="minioadmin",
  secret="minioadminpassword",
  client_kwargs={"endpoint_url": "http://minio:9000"},  # MinIO gateway URL inside the cluster/network
)

# Load model parameters once at startup from s3://models/naive_bayes_params.json
# The file must contain the keys used above (class_prior_, theta_, sigma_, classes_).
with fs.open("s3://models/naive_bayes_params.json", "r") as f:
  model_params = json.load(f)


@app.agent(input_topic)
async def process(stream):
  """
  Faust agent that:
  - Logs inbound event payload and headers.
  - Extracts correlation headers (correlationId, instanceId) and forwards them.
  - Converts the inbound JSON dict to a list of floats (feature vector).
  - Runs the Gaussian NB prediction.
  - Sends a boolean result to the results topic with copied headers.

  Important:
  - The order of evt.value.values() must match the model training feature order.
    Prefer sending the feature array explicitly or sort by a predefined list of feature names.
  """
  async for evt in stream.events():
    print(f"[faust] Received event: {evt.value!r}")

    # Raw Kafka headers are list[(key_bytes, value_bytes)]
    raw_headers = evt.message.headers or []

    # Human-readable headers for debugging
    dbg = []
    for k, v in raw_headers:
      ks = k.decode() if isinstance(k, (bytes, bytearray)) else str(k)
      vs = v.decode() if isinstance(v, (bytes, bytearray)) else (str(v) if v is not None else None)
      dbg.append((ks, vs))
    print(f"[faust] In headers: {dbg}")

    # Extract correlation metadata from inbound headers (if present)
    corr_bytes = None
    inst_bytes = None
    for k, v in raw_headers:
      key = k.decode() if isinstance(k, (bytes, bytearray)) else k
      if key == "correlationId":
        corr_bytes = v if isinstance(v, (bytes, bytearray)) else (str(v).encode() if v is not None else None)
      elif key == "instanceId":
        inst_bytes = v if isinstance(v, (bytes, bytearray)) else (str(v).encode() if v is not None else None)

    # Prepare outbound headers to preserve traceability across topics
    out_headers = []
    if corr_bytes is not None:
      out_headers.append(("correlationId", corr_bytes))
    if inst_bytes is not None:
      out_headers.append(("instanceId", inst_bytes))

    # Convert JSON dict values to float features.
    # Caution: dict value order must be consistent with model expectations.
    x = [float(e) for e in evt.value.values()]
    result = gaussian_nb_predict(x, model_params)

    print(f"[faust] Sending {result} to {results_topic} with headers={out_headers}")
    await results_topic.send(value=result, headers=out_headers)