from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from backend.app.dependencies import get_current_user
from backend.app.database.connection import get_connection

from kafka import KafkaProducer
import json

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
           r.route_id, r.route_code, r.route_name, r.start_point, r.end_point
    FROM trips t
    JOIN buses b ON b.bus_id = t.bus_id
    JOIN routes r ON r.route_id = t.route_id
"""


def _trip_dict(t):
    return {
        "trip_id": t[0], "trip_date": str(t[1]),
        "start_time": _iso(t[2]), "end_time": _iso(t[3]), "status": t[4],
        "bus": {"bus_id": t[5], "bus_number": t[6], "bus_type": t[7],
                "capacity": t[8], "registration_number": t[9]},
        "route": {"route_id": t[10], "route_code": t[11], "route_name": t[12],
                  "start_point": t[13], "end_point": t[14]},
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
                SELECT bus_id, bus_number, bus_type, capacity, registration_number
                FROM buses WHERE driver_id = %s ORDER BY bus_id LIMIT 1
            """, (d[5],))
            b = cur.fetchone()
            return {
                "user_id": d[0], "name": d[1], "email": d[2], "role": d[3],
                "is_active": d[4], "driver_id": d[5],
                "license_number": d[6], "phone": d[7],
                "bus": None if not b else {
                    "bus_id": b[0], "bus_number": b[1], "bus_type": b[2],
                    "capacity": b[3], "registration_number": b[4]},
            }
    finally:
        conn.close()


# Current trip (+ route, ordered stops, latest stored GPS point)
@router.get("/me/trip")
def get_my_current_trip(current_user: dict = Depends(require_driver)):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            driver_id = _driver_id(cur, current_user["user_id"])
            cur.execute(TRIP_SELECT + """
                WHERE t.driver_id = %s
                ORDER BY (t.trip_date = CURRENT_DATE) DESC,
                         CASE t.status WHEN 'ACTIVE' THEN 1 WHEN 'SCHEDULED' THEN 2
                                       WHEN 'COMPLETED' THEN 3 ELSE 4 END,
                         t.trip_date DESC, t.trip_id DESC
                LIMIT 1
            """, (driver_id,))
            t = cur.fetchone()
            if not t:
                raise HTTPException(status_code=404, detail="No trip assigned to you yet")
            trip = _trip_dict(t)
            cur.execute("""
                SELECT stop_id, stop_name, latitude, longitude, stop_order
                FROM stops WHERE route_id = %s ORDER BY stop_order
            """, (t[10],))
            trip["stops"] = [
                {"stop_id": s[0], "stop_name": s[1], "latitude": float(s[2]),
                 "longitude": float(s[3]), "stop_order": s[4]}
                for s in cur.fetchall()]
            cur.execute("""
                SELECT latitude, longitude, speed, recorded_at FROM bus_locations
                WHERE trip_id = %s ORDER BY recorded_at DESC, location_id DESC LIMIT 1
            """, (t[0],))
            loc = cur.fetchone()
            trip["last_location"] = None if not loc else {
                "latitude": float(loc[0]), "longitude": float(loc[1]),
                "speed": float(loc[2]) if loc[2] is not None else None,
                "recorded_at": _iso(loc[3])}
            return trip
    finally:
        conn.close()


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
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            driver_id = _driver_id(cur, current_user["user_id"])
            cur.execute("SELECT status FROM trips WHERE trip_id = %s AND driver_id = %s FOR UPDATE",
                        (trip_id, driver_id))
            row = cur.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Trip not found")
            if row[0] != "ACTIVE":
                raise HTTPException(status_code=409, detail=f"Only an active trip can be ended (current status: {row[0]})")
            cur.execute("""
                UPDATE trips SET status = 'COMPLETED', end_time = CURRENT_TIMESTAMP
                WHERE trip_id = %s RETURNING trip_id, status, end_time
            """, (trip_id,))
            r = cur.fetchone()
            conn.commit()
            return {"trip_id": r[0], "status": r[1], "end_time": _iso(r[2])}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


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
                "speed": loc.speed
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
                WHERE t.driver_id = %s ORDER BY t.trip_date DESC, t.trip_id DESC LIMIT 50
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