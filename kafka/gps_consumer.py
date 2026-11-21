

# import json
# import os
# from kafka import KafkaConsumer
# import psycopg

# consumer = KafkaConsumer(
#     "bus-events",
#     bootstrap_servers="localhost:9092",
#     value_deserializer=lambda v: json.loads(v.decode("utf-8")),
#     auto_offset_reset="latest",
#     group_id="gps-db-consumer"
# )

# conn = psycopg2.connect(
#     host="localhost",
#     database="bus_tracking",
#     user="meghana",
#     password=os.getenv("DB_PASSWORD")
# )

# cursor = conn.cursor()

# print("GPS Consumer started...")

# for message in consumer:
#     data = message.value

#     if "latitude" in data and "longitude" in data:

#         bus_id = data.get("bus_id", "BUS001")
#         latitude = data["latitude"]
#         longitude = data["longitude"]

#         cursor.execute(
#             """
#             INSERT INTO gps_data
#             (bus_id, latitude, longitude)
#             VALUES (%s, %s, %s)
#             """,
#             (bus_id, latitude, longitude)
#         )

#         conn.commit()

#         print("GPS saved:", bus_id, latitude, longitude)





import json
import os
from datetime import datetime, timezone
from zoneinfo import ZoneInfo

from kafka import KafkaConsumer
import psycopg
from dotenv import load_dotenv

load_dotenv()

consumer = KafkaConsumer(
    "bus-location",
    bootstrap_servers="localhost:9092",
    value_deserializer=lambda v: json.loads(v.decode("utf-8")),
    auto_offset_reset="earliest",
    group_id="gps-db-consumer-test"
)

DATABASE_URL = os.getenv("DATABASE_URL")

conn = psycopg.connect(DATABASE_URL)
cursor = conn.cursor()

print("GPS Consumer started...")

for message in consumer:
    data = message.value

    print("Kafka GPS received:", data)

    if "latitude" not in data or "longitude" not in data:
        print("Invalid GPS data")
        continue

    bus_number = data.get("bus_id")
    latitude = data["latitude"]
    longitude = data["longitude"]
    speed = data.get("speed")

    # Convert the original GPS timestamp to Asia/Kolkata local time.
    raw_timestamp = data.get("recorded_at")
    if raw_timestamp:
        gps_time = datetime.fromisoformat(
            raw_timestamp.replace("Z", "+00:00")
        )
        if gps_time.tzinfo is None:
            gps_time = gps_time.replace(tzinfo=timezone.utc)
    else:
        gps_time = datetime.now(timezone.utc)

    recorded_at = (
        gps_time.astimezone(ZoneInfo("Asia/Kolkata"))
        .replace(tzinfo=None)
    )

    try:
        # Find bus
        cursor.execute(
            """
            SELECT bus_id
            FROM buses
            WHERE bus_number = %s
            """,
            (bus_number,)
        )

        bus = cursor.fetchone()

        if not bus:
            print("Bus not found:", bus_number)
            continue

        bus_id = bus[0]

        # Validate the exact trip_id supplied by the GPS producer
        trip_id = data.get("trip_id")
        if trip_id is None:
            print("GPS skipped: message has no trip_id")
            continue

        cursor.execute(
            """
            SELECT trip_id
            FROM trips
            WHERE trip_id = %s
              AND bus_id = %s
              AND status = 'ACTIVE'
            """,
            (trip_id, bus_id)
        )

        trip = cursor.fetchone()

        if not trip:
            print("GPS skipped: trip is not active or does not belong to this bus")
            continue

        # Save GPS against the exact validated trip
        cursor.execute(
            """
            INSERT INTO bus_locations
            (trip_id, bus_id, latitude, longitude, speed, recorded_at)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (trip_id, bus_id, latitude, longitude, speed, recorded_at)
        )

        conn.commit()

        print(
            f"GPS saved | Bus: {bus_number} | "
            f"Lat: {latitude} | "
            f"Lng: {longitude} | "
            f"Speed: {speed}"
        )

    except Exception as e:
        conn.rollback()
        print("Database error:", e)