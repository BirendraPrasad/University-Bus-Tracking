from kafka import KafkaProducer
import json
import time

producer = KafkaProducer(
    bootstrap_servers="localhost:9092",
    value_serializer=lambda data: json.dumps(data).encode("utf-8")
)

latitude = 16.8302
longitude = 75.7150

while True:
    gps_data = {
        "bus_id": "BUS001",
        "latitude": latitude,
        "longitude": longitude
    }

    producer.send("bus-events", value=gps_data)
    producer.flush()

    print("GPS data sent:", gps_data)

    time.sleep(5)
