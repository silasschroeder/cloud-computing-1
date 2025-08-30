import faust
import s3fs
import numpy as np
import json

# def ensure_kafka_url(url: str) -> str:
#     return url if "://" in url else f"kafka://{url}"

# broker_env = os.getenv("KAFKA_BROKER", "my-kafka-cluster-kafka-bootstrap.default.svc.cluster.local:9092")
# broker = ensure_kafka_url(broker_env)
# print(f"[faust] Using broker: {broker}")

app = faust.App(
    "s3-stream",
    #broker="kafka://my-kafka-cluster-kafka-bootstrap.default.svc.cluster.local:9092",
    broker="kafka://my-kafka-cluster-kafka-bootstrap:9092",
    value_serializer="json",
    topic_allow_declare=False, # so it does not try to create topics
    topic_disable_leader=True, # so no default topic is created
)

import numpy as np

def gaussian_nb_predict(x, params):
    """
    x: list oder np.array mit 30 Features
    params: gespeicherte NB-Parameter
    return: bool -> True = breast cancer (Malignant), False = kein cancer (Benign)
    """
    x = np.array(x)
    priors = np.array(params["class_prior_"])
    means = np.array(params["theta_"])
    vars_ = np.array(params["sigma_"])
    
    log_probs = []
    for i, cls in enumerate(params["classes_"]):
        mean = means[i]
        var = vars_[i]
        log_likelihood = -0.5 * np.sum(np.log(2 * np.pi * var) + ((x - mean) ** 2) / var)
        log_probs.append(np.log(priors[i]) + log_likelihood)
    
    log_probs = np.array(log_probs)
    probs = np.exp(log_probs - log_probs.max())
    probs = probs / probs.sum()
    
    # Klassen: 1 = Krebs, 0 = Kein Krebs
    pred_class = params["classes_"][np.argmax(probs)]
    return bool(pred_class == 1)


input_topic = app.topic("tracking-data", value_type=bytes)
results_topic = app.topic("model-results", value_type=bool, value_serializer="json")

fs = s3fs.S3FileSystem(
    key="minioadmin",
    secret="minioadminpassword",
    client_kwargs={"endpoint_url": "http://minio:9000"},
)

# read model parameters from S3
with fs.open("s3://models/naive_bayes_params.json", "r") as f:
    model_params = json.load(f)

@app.agent(input_topic)
async def process(stream):
    async for evt in stream.events():
        print(f"[faust] Received event: {evt.value!r}")
        raw_headers = evt.message.headers or []  # list[(key, val)]
        # Debug-print headers as strings
        dbg = []
        for k, v in raw_headers:
            ks = k.decode() if isinstance(k, (bytes, bytearray)) else str(k)
            vs = v.decode() if isinstance(v, (bytes, bytearray)) else (str(v) if v is not None else None)
            dbg.append((ks, vs))
        print(f"[faust] In headers: {dbg}")

        corr_bytes = None
        inst_bytes = None
        for k, v in raw_headers:
            key = k.decode() if isinstance(k, (bytes, bytearray)) else k
            if key == "correlationId":
                corr_bytes = v if isinstance(v, (bytes, bytearray)) else (str(v).encode() if v is not None else None)
            elif key == "instanceId":
                inst_bytes = v if isinstance(v, (bytes, bytearray)) else (str(v).encode() if v is not None else None)

        out_headers = []
        if corr_bytes is not None: out_headers.append(("correlationId", corr_bytes))
        if inst_bytes is not None: out_headers.append(("instanceId", inst_bytes))

        x = [float(e) for e in evt.value.values()]
        result = gaussian_nb_predict(x, model_params)

        print(f"[faust] Sending {result} to {results_topic} with headers={out_headers}")
        await results_topic.send(value=result, headers=out_headers)