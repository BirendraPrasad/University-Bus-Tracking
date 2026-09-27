import json
import os
from kafka import KafkaConsumer
import psycopg2

consumer = KafkaConsumer(
    "bus-events",
    bootstrap_servers="localhost:9092",
    value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    auto_offset_reset="latest",
    group_id="gps-db-consumer"
)

conn = psycopg2.connect(
    host="localhost",
    database="bus_tracking",
    user="meghana",
    password=os.getenv("DB_PASSWORD")
)

cursor = conn.cursor()

print("GPS Consumer started...")

for message in consumer:
    data = message.value

    if "latitude" in data and "longitude" in data:

        bus_id = data.get("bus_id", "BUS001")
        latitude = data["latitude"]
        longitude = data["longitude"]

        cursor.execute(
            """
            INSERT INTO gps_data
            (bus_id, latitude, longitude)
            VALUES (%s, %s, %s)
            """,
            (bus_id, latitude, longitude)
        )

        conn.commit()

        print("GPS saved:", bus_id, latitude, longitude)
