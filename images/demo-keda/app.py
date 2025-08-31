# Simple Kafka load generator for demos (e.g., KEDA autoscaling):
# - Produces JSON messages to topic "tracking-data" at a high rate (~1000 msg/s).
# - Each message contains 30 random floating-point features: f0, f1, ..., f29.
# - Intended for testing/benchmarking a downstream stream-processing pipeline.
#
# Notes:
# - .send() is asynchronous; messages are batched by the Kafka client and sent in the background.
# - Use Ctrl+C to stop. In production code, add a try/finally with producer.flush()/close().
# - Tuning options like linger_ms, batch_size, and compression_type can shape throughput/latency.

from kafka import KafkaProducer
import json, time, random

# Kafka producer:
# - bootstrap_servers: address of your Kafka bootstrap service.
# - value_serializer: converts Python dict -> JSON bytes for transport.
# Optional tuning (uncomment and adjust):
#   linger_ms=5, batch_size=32768, compression_type="lz4"
producer = KafkaProducer(
    bootstrap_servers="my-kafka-cluster-kafka-bootstrap:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

# Infinite loop sending messages at a fixed cadence
while True:
    # Generate 30 random float features (simulating model input)
    data = {f"f{i}": random.random() for i in range(30)}

    # Send one message to the "tracking-data" topic.
    # .send() returns a Future; we don't block here to maximize throughput.
    producer.send("tracking-data", value=data)

    # Basic progress log. Consider reducing frequency for very high rates.
    print("Sent message")

    # Sleep 1 ms -> roughly ~1000 messages per second (subject to scheduling).
    # Increase/decrease to change the load.