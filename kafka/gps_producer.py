# from kafka import KafkaProducer
# import json
# import time

# producer = KafkaProducer(
#     bootstrap_servers="localhost:9092",
#     value_serializer=lambda data: json.dumps(data).encode("utf-8")
# )

# latitude = 16.8302
# longitude = 75.7150

# while True:
#     gps_data = {
#         "bus_id": "BUS-001",
#         "latitude": latitude,
#         "longitude": longitude
#     }

#     producer.send("bus-events", value=gps_data)
#     producer.flush()

#     print("GPS data sent:", gps_data)

#     time.sleep(5)




from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers=["localhost:9092"],
    value_serializer=lambda v: json.dumps(v).encode("utf-8")
)

data = {
    "bus_id": "BUS-001",
    "latitude": 16.8302,
    "longitude": 75.715,
    "speed": 30
}

print("Sending:", data)

future = producer.send("bus-location", value=data)

try:
    result = future.get(timeout=10)
    print("SUCCESS")
    print("Topic:", result.topic)
    print("Partition:", result.partition)
    print("Offset:", result.offset)
except Exception as e:
    print("KAFKA ERROR:", repr(e))

producer.flush()
producer.close()
