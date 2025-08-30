from kafka import KafkaProducer
import json, time, random

producer = KafkaProducer(
    bootstrap_servers="my-kafka-cluster-kafka-bootstrap:9092",
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

while True:
    # 30 random floats simulieren Input-Features
    data = {f"f{i}": random.random() for i in range(30)}
    producer.send("tracking-data", value=data)
    print("Sent message")
    time.sleep(0.001)