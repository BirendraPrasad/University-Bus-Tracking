from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from datetime import datetime, timezone

from backend.app.dependencies import get_current_user, require_admin
from backend.app.database.connection import get_connection
from backend.app.services.notifications import create_notification_if_enabled

from kafka import KafkaProducer
import json
import os

router = APIRouter(prefix="/drivers", tags=["Drivers"])

producer = KafkaProducer(
    bootstrap_servers="localhost:9092",
    value_serializer=lambda data: json.dumps(data).encode("utf-8")
)


def require_driver(current_user: dict = Depends(get_current_user)):
    """Only DRIVER tokens may use these endpoints (enforced server-side)."""
    if current_user["role"] != "DRIVER":
        raise HTTPException(status_code=403, detail="Driver access required")
    return current_user


class LocationIn(BaseModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    speed: float | None = Field(default=None, ge=0, le=999)
    recorded_at: datetime | None = None


def _driver_id(cur, user_id):
    cur.execute("SELECT driver_id FROM drivers WHERE user_id = %s", (user_id,))
    row = cur.fetchone()
    if not row:
        raise HTTPException(status_code=404, detail="Driver profile not found")
    return row[0]


def _iso(value):
    return value.isoformat() if value else None


TRIP_SELECT = """
    SELECT t.trip_id, t.trip_date, t.start_time, t.end_time, t.status,
           b.bus_id, b.bus_number, b.bus_type, b.capacity, b.registration_number,
           r.route_id, r.route_code, r.route_name, r.start_point, r.end_point,
           b.front_photo, b.side_photo
    FROM trips t
    JOIN buses b ON b.bus_id = t.bus_id
    JOIN routes r ON r.route_id = t.route_id
"""


def _trip_dict(t):
    return {
        "trip_id": t[0],
        "trip_date": str(t[1]),
        "start_time": _iso(t[2]),
        "end_time": _iso(t[3]),
        "status": t[4],
        "bus": {
            "bus_id": t[5],
            "bus_number": t[6],
            "bus_type": t[7],
            "capacity": t[8],
            "registration_number": t[9],
            "front_photo": t[15],
            "side_photo": t[16]
        },
        "route": {
            "route_id": t[10],
            "route_code": t[11],
            "route_name": t[12],
            "start_point": t[13],
            "end_point": t[14]
        }
    }

# Driver profile + assigned bus
@router.get("/me")
def get_my_profile(current_user: dict = Depends(require_driver)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT u.user_id, u.name, u.email, u.role, u.is_active,
                       d.driver_id, d.license_number, d.phone
                FROM users u JOIN drivers d ON d.user_id = u.user_id
                WHERE u.user_id = %s
            """, (current_user["user_id"],))
            d = cur.fetchone()
            if not d:
                raise HTTPException(status_code=404, detail="Driver profile not found")
            cur.execute("""
                SELECT bus_id, bus_number, bus_type, capacity, registration_number,
                front_photo, side_photo, route_id
                FROM buses
                WHERE driver_id = %s
                ORDER BY bus_id
                LIMIT 1
            """, (d[5],))
            b = cur.fetchone()
            return {
                "user_id": d[0], "name": d[1], "email": d[2], "role": d[3],
                "is_active": d[4], "driver_id": d[5],
                "license_number": d[6], "phone": d[7],
                "bus": None if not b else {
                    "bus_id": b[0],
                    "bus_number": b[1],
                    "bus_type": b[2],
                    "capacity": b[3],
                    "registration_number": b[4],
                    "front_photo": b[5],
                    "side_photo": b[6],
                    "route_id": b[7]
                },
            }
    finally:
        conn.close()




# Driver: View assigned route and its ordered stops
@router.get("/me/route")
def get_my_assigned_route(current_user: dict = Depends(require_driver)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            driver_id = _driver_id(cur, current_user["user_id"])

            cur.execute("""
                SELECT r.route_id, r.route_name, r.route_code,
                       r.description, r.start_point, r.end_point,
                       r.is_active
                FROM buses b
                JOIN routes r ON r.route_id = b.route_id
                WHERE b.driver_id = %s
                ORDER BY b.bus_id
                LIMIT 1
            """, (driver_id,))

            route = cur.fetchone()

            if not route:
                raise HTTPException(
                    status_code=404,
                    detail="No route assigned to your bus"
                )

            cur.execute("""
                SELECT stop_id, stop_name, latitude, longitude,
                       stop_order, pickup_time, drop_time
                FROM stops
                WHERE route_id = %s
                ORDER BY stop_order
            """, (route[0],))

            stops = [
                {
                    "stop_id": row[0],
                    "stop_name": row[1],
                    "latitude": float(row[2]),
                    "longitude": float(row[3]),
                    "stop_order": row[4],
                    "pickup_time": str(row[5]) if row[5] is not None else None,
                    "drop_time": str(row[6]) if row[6] is not None else None
                }
                for row in cur.fetchall()
            ]

            return {
                "route_id": route[0],
                "route_name": route[1],
                "route_code": route[2],
                "description": route[3],
                "start_point": route[4],
                "end_point": route[5],
                "is_active": route[6],
                "stops": stops
            }
    finally:
        conn.close()

# Current trip (+ route, ordered stops, latest stored GPS point)
@router.get("/me/trip")
def get_my_current_trip(
    trip_id: int | None = None,
    current_user: dict = Depends(require_driver)
):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            driver_id = _driver_id(cur, current_user["user_id"])

            if trip_id is not None:
                cur.execute(
                    TRIP_SELECT + """
                    WHERE t.driver_id = %s
                      AND t.trip_id = %s
                      AND t.status IN ('SCHEDULED', 'ACTIVE')
                    LIMIT 1
                    """,
                    (driver_id, trip_id)
                )
            else:
                cur.execute(
                    TRIP_SELECT + """
                    WHERE t.driver_id = %s
                      AND t.status = 'ACTIVE'
                    ORDER BY t.trip_date DESC, t.trip_id DESC
                    LIMIT 1
                    """,
                    (driver_id,)
                )

            t = cur.fetchone()
            if not t:
                raise HTTPException(
                    status_code=404,
                    detail="No matching trip assigned to you"
                )

            trip = _trip_dict(t)

            cur.execute("""
                SELECT
                    s.stop_id,
                    s.stop_name,
                    s.latitude,
                    s.longitude,
                    s.stop_order,
                    s.pickup_time,
                    s.drop_time,
                    e.arrival_time,
                    e.departure_time
                FROM stops s
                LEFT JOIN trip_stop_events e
                    ON e.stop_id = s.stop_id
                   AND e.trip_id = %s
                WHERE s.route_id = %s
                ORDER BY s.stop_order
            """, (t[0], t[10]))

            trip["stops"] = []
            for row in cur.fetchall():
                latitude = float(row[2])
                longitude = float(row[3])

                tracking_available = (
                    -90 <= latitude <= 90
                    and -180 <= longitude <= 180
                    and (latitude != 0 or longitude != 0)
                )

                arrival_time = _iso(row[7])
                departure_time = _iso(row[8])

                if not tracking_available:
                    stop_status = "Untracked"
                elif departure_time:
                    stop_status = "Completed"
                elif arrival_time:
                    stop_status = "Arrived"
                else:
                    stop_status = "Upcoming"

                trip["stops"].append({
                    "stop_id": row[0],
                    "stop_name": row[1],
                    "latitude": latitude,
                    "longitude": longitude,
                    "stop_order": row[4],
                    "pickup_time": str(row[5]) if row[5] is not None else None,
                    "drop_time": str(row[6]) if row[6] is not None else None,
                    "arrival_time": arrival_time,
                    "departure_time": departure_time,
                    "status": stop_status,
                    "tracking_available": tracking_available
                })

            cur.execute("""
                SELECT latitude, longitude, speed, recorded_at
                FROM bus_locations
                WHERE trip_id = %s
                ORDER BY recorded_at DESC, location_id DESC
                LIMIT 1
            """, (t[0],))

            loc = cur.fetchone()
            trip["last_location"] = None if not loc else {
                "latitude": float(loc[0]),
                "longitude": float(loc[1]),
                "speed": float(loc[2]) if loc[2] is not None else None,
                "recorded_at": _iso(loc[3])
            }

            return trip
    finally:
        conn.close()



# List scheduled and active trips assigned to the logged-in driver
@router.get("/me/trips/available")
def get_my_available_trips(
    current_user: dict = Depends(require_driver)
):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            driver_id = _driver_id(cur, current_user["user_id"])

            cur.execute(
                TRIP_SELECT + """
                    WHERE t.driver_id = %s
                      AND t.status IN ('SCHEDULED', 'ACTIVE')
                    ORDER BY
                        CASE t.status
                            WHEN 'ACTIVE' THEN 1
                            WHEN 'SCHEDULED' THEN 2
                            ELSE 3
                        END,
                        t.trip_date ASC,
                        t.trip_id ASC
                """,
                (driver_id,)
            )

            return [_trip_dict(row) for row in cur.fetchall()]
    finally:
        conn.close()

# ==========================================================================

@router.post("/me/trips/{trip_id}/start")
def start_trip(trip_id: int, current_user: dict = Depends(require_driver)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            driver_id = _driver_id(cur, current_user["user_id"])
            cur.execute("SELECT status FROM trips WHERE trip_id = %s AND driver_id = %s FOR UPDATE",
                        (trip_id, driver_id))
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Trip not found")
            if row[0] != "SCHEDULED":
                raise HTTPException(status_code=409, detail=f"Only a scheduled trip can be started (current status: {row[0]})")
            cur.execute("SELECT 1 FROM trips WHERE driver_id = %s AND status = 'ACTIVE'", (driver_id,))
            if cur.fetchone():
                raise HTTPException(status_code=409, detail="You already have an active trip")
            cur.execute("""
                UPDATE trips SET status = 'ACTIVE', start_time = CURRENT_TIMESTAMP
                WHERE trip_id = %s RETURNING trip_id, status, start_time
            """, (trip_id,))
            r = cur.fetchone()
            conn.commit()
            return {"trip_id": r[0], "status": r[1], "start_time": _iso(r[2])}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@router.post("/me/trips/{trip_id}/end")
def end_trip(trip_id: int, current_user: dict = Depends(require_driver)):
    raise HTTPException(
        status_code=409,
        detail="Trips are completed automatically when the bus enters the campus geofence."
    )


# Driver GPS point -> bus_locations (only while the driver's trip is ACTIVE)
# @router.post("/me/trips/{trip_id}/location")
# def post_location(trip_id: int, loc: LocationIn, current_user: dict = Depends(require_driver)):
#     conn = get_connection()
#     try:
#         with conn.cursor() as cur:
#             driver_id = _driver_id(cur, current_user["user_id"])
#             cur.execute("SELECT bus_id, status FROM trips WHERE trip_id = %s AND driver_id = %s",
#                         (trip_id, driver_id))
#             row = cur.fetchone()
#             if not row:
#                 raise HTTPException(status_code=404, detail="Trip not found")
#             if row[1] != "ACTIVE":
#                 raise HTTPException(status_code=409, detail="GPS can only be shared during an active trip")
#             cur.execute("""
#                 INSERT INTO bus_locations (trip_id, bus_id, latitude, longitude, speed)
#                 VALUES (%s, %s, %s, %s, %s) RETURNING recorded_at
#             """, (trip_id, row[0], loc.latitude, loc.longitude, loc.speed))
#             recorded = cur.fetchone()[0]
#             conn.commit()
#             return {"recorded_at": _iso(recorded)}
#     except Exception:
#         conn.rollback()
#         raise
#     finally:
#         conn.close()

@router.post("/me/trips/{trip_id}/location")
def post_location(
    trip_id: int,
    loc: LocationIn,
    current_user: dict = Depends(require_driver)
):
    conn = get_connection()

    try:
        with conn.cursor() as cur:

            driver_id = _driver_id(
                cur,
                current_user["user_id"]
            )

            cur.execute(
                """
                SELECT bus_id, status
                FROM trips
                WHERE trip_id = %s
                  AND driver_id = %s
                """,
                (trip_id, driver_id)
            )

            row = cur.fetchone()

            if not row:
                raise HTTPException(
                    status_code=404,
                    detail="Trip not found"
                )

            if row[1] != "ACTIVE":
                raise HTTPException(
                    status_code=409,
                    detail="GPS can only be shared during an active trip"
                )

            bus_id = row[0]

            # Get bus number
            cur.execute(
                """
                SELECT bus_number
                FROM buses
                WHERE bus_id = %s
                """,
                (bus_id,)
            )

            bus = cur.fetchone()

            if not bus:
                raise HTTPException(
                    status_code=404,
                    detail="Bus not found"
                )

            bus_number = bus[0]

            # GPS data for Kafka
            gps_data = {
                "bus_id": bus_number,
                "trip_id": trip_id,
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "speed": loc.speed,
                "recorded_at": (
                    loc.recorded_at.isoformat()
                    if loc.recorded_at
                    else datetime.now(timezone.utc).isoformat()
                )
            }

            # Send GPS data to Kafka
            producer.send(
                "bus-location",
                value=gps_data
            )

            producer.flush()

            return {
                "message": "GPS location sent to Kafka",
                "trip_id": trip_id,
                "bus_id": bus_number,
                "latitude": loc.latitude,
                "longitude": loc.longitude,
                "speed": loc.speed
            }

    finally:
        conn.close()


@router.get("/me/trips/history")
def trip_history(current_user: dict = Depends(require_driver)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            driver_id = _driver_id(cur, current_user["user_id"])
            cur.execute(TRIP_SELECT + """
                WHERE t.driver_id = %s ORDER BY t.trip_date DESC, t.trip_id DESC
            """, (driver_id,))
            return [_trip_dict(t) for t in cur.fetchall()]
    finally:
        conn.close()


@router.get("/me/notifications")
def my_notifications(current_user: dict = Depends(require_driver)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT notification_id, title, message, notification_type, is_read, created_at
                FROM notifications WHERE user_id = %s ORDER BY created_at DESC LIMIT 50
            """, (current_user["user_id"],))
            return [{"notification_id": n[0], "title": n[1], "message": n[2],
                     "type": n[3], "is_read": n[4], "created_at": _iso(n[5])}
                    for n in cur.fetchall()]
    finally:
        conn.close()

# Automatic campus geofence trip management
CAMPUS_LAT = 13.219992
CAMPUS_LNG = 77.753943
GEOFENCE_RADIUS_METERS = 150



def _distance_meters(lat1, lon1, lat2, lon2):
    from math import radians, sin, cos, asin, sqrt
    lat1, lon1, lat2, lon2 = map(radians, (lat1, lon1, lat2, lon2))
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    return 6371000 * 2 * asin(sqrt(a))


def _process_geofence_location(bus_id: int, loc: LocationIn, source: str, expected_driver_id=None):
    """Process GPS with persistent timestamp and geofence transition validation."""
    if source not in ("REAL", "SIMULATED"):
        raise HTTPException(status_code=400, detail="Invalid GPS source")

    GPS_STALE_SECONDS = 60
    GPS_FUTURE_TOLERANCE_SECONDS = 10
    GPS_MAX_SAMPLE_GAP_SECONDS = 10
    REQUIRED_GPS_READINGS = 5
    REQUIRED_DWELL_SECONDS = 20

    received_at = datetime.now(timezone.utc)
    recorded_at = loc.recorded_at or received_at

    if recorded_at.tzinfo is None:
        recorded_at = recorded_at.replace(tzinfo=timezone.utc)
    else:
        recorded_at = recorded_at.astimezone(timezone.utc)

    age_seconds = (received_at - recorded_at).total_seconds()

    if age_seconds > GPS_STALE_SECONDS:
        raise HTTPException(
            status_code=422,
            detail="GPS reading is stale. Please send a fresh location."
        )

    if age_seconds < -GPS_FUTURE_TOLERANCE_SECONDS:
        raise HTTPException(
            status_code=422,
            detail="GPS timestamp is too far in the future."
        )

    state_table = (
        "bus_geofence_state"
        if source == "REAL"
        else "bus_geofence_simulator_state"
    )

    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT bus_id, bus_number, route_id, driver_id
                FROM buses
                WHERE bus_id = %s
                FOR UPDATE
            """, (bus_id,))
            bus = cur.fetchone()

            if not bus:
                raise HTTPException(status_code=404, detail="Bus not found")

            bus_id, bus_number, route_id, driver_id = bus

            if expected_driver_id is not None and driver_id != expected_driver_id:
                raise HTTPException(status_code=403, detail="This bus is not assigned to your driver account")

            if driver_id is None:
                raise HTTPException(status_code=409, detail="No driver is assigned to this bus")

            if route_id is None:
                raise HTTPException(status_code=409, detail="No route is assigned to this bus")

            cur.execute("""
                SELECT is_active FROM routes WHERE route_id = %s
            """, (route_id,))
            route = cur.fetchone()

            if not route or not route[0]:
                raise HTTPException(status_code=409, detail="The assigned bus route is not active")

            inside = _distance_meters(
                loc.latitude, loc.longitude, CAMPUS_LAT, CAMPUS_LNG
            ) <= GEOFENCE_RADIUS_METERS

            # Lock the stable geofence state.
            cur.execute(f"""
                SELECT is_inside
                FROM {state_table}
                WHERE bus_id = %s
                FOR UPDATE
            """, (bus_id,))
            previous = cur.fetchone()

            initialized = previous is None

            if initialized:
                # First reading is only a baseline, never a trip transition.
                was_inside = inside
                cur.execute(f"""
                    INSERT INTO {state_table}
                    (bus_id, is_inside, last_latitude, last_longitude, updated_at)
                    VALUES (%s, %s, %s, %s, CURRENT_TIMESTAMP)
                """, (bus_id, inside, loc.latitude, loc.longitude))
            else:
                was_inside = previous[0]

            # Create and lock persistent validation state separately per source.
            cur.execute("""
                INSERT INTO bus_geofence_validation_state
                    (bus_id, source, candidate_count, last_recorded_at)
                VALUES (%s, %s, 0, NULL)
                ON CONFLICT (bus_id, source) DO NOTHING
            """, (bus_id, source))

            cur.execute("""
                SELECT candidate_inside, candidate_started_at,
                       candidate_last_at, candidate_count, last_recorded_at
                FROM bus_geofence_validation_state
                WHERE bus_id = %s AND source = %s
                FOR UPDATE
            """, (bus_id, source))
            validation = cur.fetchone()

            candidate_inside, candidate_started_at, candidate_last_at, candidate_count, last_recorded_at = validation

            if last_recorded_at is not None:
                if recorded_at <= last_recorded_at:
                    raise HTTPException(
                        status_code=409,
                        detail="Duplicate or out-of-order GPS timestamp rejected."
                    )

            action = "NONE"
            trip_id = None
            transition_confirmed = False

            if initialized:
                # Baseline only. Do not infer a departure from the first reading.
                cur.execute("""
                    UPDATE bus_geofence_validation_state
                    SET candidate_inside = NULL,
                        candidate_started_at = NULL,
                        candidate_last_at = NULL,
                        candidate_count = 0,
                        last_recorded_at = %s,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE bus_id = %s AND source = %s
                """, (recorded_at, bus_id, source))

            elif inside == was_inside:
                # The bus returned to its stable side; discard the candidate.
                cur.execute("""
                    UPDATE bus_geofence_validation_state
                    SET candidate_inside = NULL,
                        candidate_started_at = NULL,
                        candidate_last_at = NULL,
                        candidate_count = 0,
                        last_recorded_at = %s,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE bus_id = %s AND source = %s
                """, (recorded_at, bus_id, source))

            else:
                gap_seconds = (
                    (recorded_at - candidate_last_at).total_seconds()
                    if candidate_last_at is not None else None
                )

                if (
                    candidate_inside != inside
                    or candidate_started_at is None
                    or gap_seconds is None
                    or gap_seconds > GPS_MAX_SAMPLE_GAP_SECONDS
                ):
                    candidate_count = 1
                    candidate_started_at = recorded_at
                    candidate_last_at = recorded_at
                else:
                    candidate_count += 1
                    candidate_last_at = recorded_at

                dwell_seconds = (
                    (recorded_at - candidate_started_at).total_seconds()
                )

                transition_confirmed = (
                    candidate_count >= REQUIRED_GPS_READINGS
                    and dwell_seconds >= REQUIRED_DWELL_SECONDS
                )

                if transition_confirmed:
                    cur.execute(f"""
                        UPDATE {state_table}
                        SET is_inside = %s
                        WHERE bus_id = %s
                    """, (inside, bus_id))
                    cur.execute("""
                        UPDATE bus_geofence_validation_state
                        SET candidate_inside = NULL,
                            candidate_started_at = NULL,
                            candidate_last_at = NULL,
                            candidate_count = 0,
                            last_recorded_at = %s,
                            updated_at = CURRENT_TIMESTAMP
                        WHERE bus_id = %s AND source = %s
                    """, (recorded_at, bus_id, source))
                else:
                    cur.execute("""
                        UPDATE bus_geofence_validation_state
                        SET candidate_inside = %s,
                            candidate_started_at = %s,
                            candidate_last_at = %s,
                            candidate_count = %s,
                            last_recorded_at = %s,
                            updated_at = CURRENT_TIMESTAMP
                        WHERE bus_id = %s AND source = %s
                    """, (
                        inside, candidate_started_at, candidate_last_at,
                        candidate_count, recorded_at, bus_id, source
                    ))

            # Update GPS heartbeat for every accepted reading.
            # Keep stable is_inside unchanged until transition confirmation.
            cur.execute(f"""
                UPDATE {state_table}
                SET last_latitude = %s,
                    last_longitude = %s,
                    updated_at = CURRENT_TIMESTAMP
                WHERE bus_id = %s
            """, (loc.latitude, loc.longitude, bus_id))

            cur.execute("""
                SELECT trip_id, route_id, source
                FROM trips
                WHERE bus_id = %s AND status = 'ACTIVE'
                ORDER BY trip_id DESC
                FOR UPDATE
            """, (bus_id,))
            active_trips = cur.fetchall()

            other_source_trip = next(
                (row for row in active_trips if row[2] != source), None
            )
            if other_source_trip:
                raise HTTPException(
                    status_code=409,
                    detail=f"Bus has an active {other_source_trip[2]} trip. Stop or complete it before using {source} GPS."
                )

            active_trip = next(
                (row for row in active_trips if row[2] == source), None
            )

            # Start or reconcile a trip whenever valid GPS confirms bus is outside.
            if not inside and not active_trip:
                cur.execute("""
                    SELECT trip_id
                    FROM trips
                    WHERE bus_id = %s
                      AND driver_id = %s
                      AND route_id = %s
                      AND source = %s
                      AND status = 'SCHEDULED'
                      AND trip_date <= CURRENT_DATE
                    ORDER BY trip_date ASC, trip_id ASC
                    LIMIT 1
                    FOR UPDATE
                """, (bus_id, driver_id, route_id, source))
                scheduled_trip = cur.fetchone()

                if scheduled_trip:
                    trip_id = scheduled_trip[0]
                    cur.execute("""
                        UPDATE trips
                        SET status = 'ACTIVE',
                            start_time = CURRENT_TIMESTAMP,
                            end_time = NULL
                        WHERE trip_id = %s AND status = 'SCHEDULED'
                        RETURNING trip_id
                    """, (trip_id,))
                    started = cur.fetchone()
                    if started:
                        trip_id = started[0]
                        action = "TRIP_STARTED"
                else:
                    cur.execute("""
                        INSERT INTO trips
                        (bus_id, route_id, driver_id, trip_date, start_time, status, source)
                        VALUES (%s, %s, %s, CURRENT_DATE, CURRENT_TIMESTAMP, 'ACTIVE', %s)
                        RETURNING trip_id
                    """, (bus_id, route_id, driver_id, source))
                    trip_id = cur.fetchone()[0]
                    action = "TRIP_STARTED"

            # A confirmed campus ENTRY completes the active trip.
            elif transition_confirmed and not was_inside and inside and active_trip:
                active_trip_id, active_trip_route_id, _ = active_trip

                if active_trip_route_id != route_id:
                    raise HTTPException(
                        status_code=409,
                        detail="Active trip route does not match the assigned bus route."
                    )

                cur.execute("""
                    UPDATE trips
                    SET status = 'COMPLETED',
                        end_time = CURRENT_TIMESTAMP
                    WHERE trip_id = %s AND status = 'ACTIVE'
                    RETURNING trip_id
                """, (active_trip_id,))

                completed = cur.fetchone()
                if completed:
                    trip_id = completed[0]
                    action = "TRIP_COMPLETED"

            if source == "REAL" and action in ("TRIP_STARTED", "TRIP_COMPLETED"):
                event_title = (
                    "Bus Trip Started"
                    if action == "TRIP_STARTED"
                    else "Bus Trip Completed"
                )
                event_message = (
                    f"Bus {bus_number}: trip #{trip_id} has started."
                    if action == "TRIP_STARTED"
                    else f"Bus {bus_number}: trip #{trip_id} has been completed."
                )

                cur.execute(
                    "SELECT user_id FROM drivers WHERE driver_id = %s",
                    (driver_id,)
                )
                driver_user = cur.fetchone()
                recipient_ids = set()

                if driver_user:
                    recipient_ids.add(driver_user[0])

                cur.execute("""
                    SELECT DISTINCT s.user_id
                    FROM subscriptions sub
                    JOIN students s ON s.student_id = sub.student_id
                    WHERE sub.route_id = %s
                      AND sub.is_active = TRUE
                """, (route_id,))

                recipient_ids.update(row[0] for row in cur.fetchall())

                for recipient_id in recipient_ids:
                    create_notification_if_enabled(
                        cur,
                        recipient_id,
                        event_title,
                        event_message,
                        preference_key="tripAlerts",
                        notification_type=action
                    )

            if not inside:
                cur.execute("""
                    SELECT trip_id FROM trips
                    WHERE bus_id = %s
                      AND driver_id = %s
                      AND status = 'ACTIVE'
                      AND source = %s
                    ORDER BY trip_id DESC
                    LIMIT 1
                """, (bus_id, driver_id, source))
                active = cur.fetchone()
                if active:
                    trip_id = active[0]

            conn.commit()

            if trip_id and action != "TRIP_COMPLETED":
                producer.send("bus-location", value={
                    "bus_id": bus_number,
                    "trip_id": trip_id,
                    "latitude": loc.latitude,
                    "longitude": loc.longitude,
                    "speed": loc.speed,
                    "recorded_at": recorded_at.isoformat()
                })
                producer.flush()

            return {
                "message": "Geofence location processed",
                "bus_number": bus_number,
                "inside_campus": inside,
                "trip_action": action,
                "trip_id": trip_id,
                "source": source,
                "geofence_confirmed": transition_confirmed,
                "gps_readings_required": REQUIRED_GPS_READINGS,
                "gps_candidate_count": (
                    0 if transition_confirmed or initialized or inside == was_inside
                    else candidate_count
                )
            }

    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@router.post("/me/location")
def automatic_geofence_location(
    loc: LocationIn,
    current_user: dict = Depends(require_driver)
):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            driver_id = _driver_id(cur, current_user["user_id"])

            cur.execute("""
                SELECT bus_id
                FROM buses
                WHERE driver_id = %s
                ORDER BY bus_id
                LIMIT 1
            """, (driver_id,))
            bus = cur.fetchone()

            if not bus:
                raise HTTPException(status_code=404, detail="No bus assigned to this driver")

            bus_id = bus[0]
    finally:
        conn.close()

    return _process_geofence_location(
        bus_id, loc, "REAL", expected_driver_id=driver_id
    )


@router.post("/admin/gps-simulator/{bus_id}/location")
def simulate_bus_location(
    bus_id: int,
    loc: LocationIn,
    current_user: dict = Depends(require_admin)
):
    if os.getenv("GPS_SIMULATOR_ENABLED", "false").strip().lower() != "true":
        raise HTTPException(
            status_code=403,
            detail="GPS Simulator is disabled. Enable GPS_SIMULATOR_ENABLED=true for local testing."
        )

    return _process_geofence_location(
        bus_id, loc, "SIMULATED"
    )
