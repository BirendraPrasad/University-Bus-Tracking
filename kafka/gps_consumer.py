

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

from kafka import KafkaConsumer
import psycopg
from dotenv import load_dotenv
from backend.app.services.notifications import create_notification_if_enabled

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

    # Store GPS timestamps consistently as UTC-naive values.
    raw_timestamp = data.get("recorded_at")
    if raw_timestamp:
        gps_time = datetime.fromisoformat(
            raw_timestamp.replace("Z", "+00:00")
        )
        if gps_time.tzinfo is None:
            gps_time = gps_time.replace(tzinfo=timezone.utc)
        else:
            gps_time = gps_time.astimezone(timezone.utc)
    else:
        gps_time = datetime.now(timezone.utc)

    recorded_at = gps_time.replace(tzinfo=None)

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
            SELECT trip_id, route_id
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

        # Detect the nearest unvisited stop within 100 metres.
        trip_route_id = trip[1]

        cursor.execute("""
            SELECT s.stop_id, s.stop_name, s.latitude, s.longitude
            FROM stops s
            LEFT JOIN trip_stop_events e
              ON e.trip_id = %s AND e.stop_id = s.stop_id
            WHERE s.route_id = %s AND e.arrival_time IS NULL
            ORDER BY s.stop_order
        """, (trip_id, trip_route_id))

        from math import radians, sin, cos, asin, sqrt

        nearby_stops = []
        for stop_id, stop_name, stop_lat, stop_lng in cursor.fetchall():
            lat1, lon1, lat2, lon2 = map(
                radians, (float(latitude), float(longitude),
                          float(stop_lat), float(stop_lng))
            )
            dlat, dlon = lat2 - lat1, lon2 - lon1
            a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
            distance = 6371000 * 2 * asin(sqrt(a))

            if distance <= 100:
                nearby_stops.append((distance, stop_id, stop_name))

        if nearby_stops:
            _, stop_id, stop_name = min(nearby_stops, key=lambda item: item[0])

            cursor.execute("""
                INSERT INTO trip_stop_events (trip_id, stop_id, arrival_time)
                VALUES (%s, %s, %s)
                ON CONFLICT (trip_id, stop_id)
                DO UPDATE SET
                    arrival_time = COALESCE(
                        trip_stop_events.arrival_time,
                        EXCLUDED.arrival_time
                    ),
                    updated_at = CURRENT_TIMESTAMP
                WHERE trip_stop_events.arrival_time IS NULL
                RETURNING event_id
            """, (trip_id, stop_id, recorded_at))

            if cursor.fetchone():
                cursor.execute("""
                    SELECT DISTINCT s.user_id
                    FROM subscriptions sub
                    JOIN students s ON s.student_id = sub.student_id
                    WHERE sub.route_id = %s AND sub.is_active = TRUE
                """, (trip_route_id,))

                for recipient in cursor.fetchall():
                    create_notification_if_enabled(
                        cursor, recipient[0],
                        "Bus Arrived at Stop",
                        f"Bus {bus_number} has arrived at {stop_name}.",
                        preference_key="busArrival",
                        notification_type="BUS_ARRIVAL"
                    )

                print("Stop arrival detected:", stop_name)

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