from fastapi import APIRouter, Depends, HTTPException
from backend.app.dependencies import get_current_user
from backend.app.database.connection import get_connection

router = APIRouter(prefix="/faculty", tags=["Faculty"])


def require_faculty(current_user: dict = Depends(get_current_user)):
    if current_user.get("role") != "FACULTY":
        raise HTTPException(status_code=403, detail="Faculty access required")
    return current_user


def _iso(value):
    return value.isoformat() if value else None


@router.get("/me")
def get_my_profile(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT u.user_id, u.name, u.email, u.role, u.is_active,
                       f.faculty_id, f.employee_id, f.department
                FROM users u
                JOIN faculty f ON f.user_id = u.user_id
                WHERE u.user_id = %s
            """, (current_user["user_id"],))
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Faculty profile not found")
            return {
                "user_id": row[0], "name": row[1], "email": row[2],
                "role": row[3], "is_active": row[4], "faculty_id": row[5],
                "employee_id": row[6], "department": row[7]
            }
    finally:
        conn.close()


@router.get("/summary")
def get_faculty_summary(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM routes WHERE is_active = TRUE")
            routes = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM stops s JOIN routes r ON r.route_id=s.route_id WHERE r.is_active=TRUE")
            stops = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM buses")
            buses = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM notifications WHERE user_id=%s AND is_read=FALSE", (current_user["user_id"],))
            unread = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM trips WHERE status='ACTIVE'")
            active_trips = cursor.fetchone()[0]
            return {"route_count": routes, "stop_count": stops, "bus_count": buses,
                    "unread_notifications": unread, "active_trip_count": active_trips}
    finally:
        conn.close()


@router.get("/routes")
def get_faculty_routes(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT r.route_id, r.route_name, r.route_code, r.description,
                       r.start_point, r.end_point, r.is_active,
                       COUNT(DISTINCT b.bus_id) AS bus_count,
                       COUNT(DISTINCT s.stop_id) AS stop_count
                FROM routes r
                LEFT JOIN trips t ON t.route_id=r.route_id
                LEFT JOIN buses b ON b.bus_id=t.bus_id
                LEFT JOIN stops s ON s.route_id=r.route_id
                WHERE r.is_active=TRUE
                GROUP BY r.route_id
                ORDER BY r.route_name
            """)
            return [{"route_id": r[0], "route_name": r[1], "route_code": r[2],
                     "description": r[3], "start_point": r[4], "end_point": r[5],
                     "is_active": r[6], "bus_count": r[7], "stop_count": r[8]}
                    for r in cursor.fetchall()]
    finally:
        conn.close()


@router.get("/stops")
def get_faculty_stops(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT s.stop_id, s.stop_name, s.route_id, r.route_name,
                       s.stop_order, s.latitude, s.longitude,
                       s.pickup_time, s.drop_time
                FROM stops s JOIN routes r ON r.route_id=s.route_id
                WHERE r.is_active=TRUE
                ORDER BY r.route_name, s.stop_order
            """)
            return [{
                "stop_id": r[0], "stop_name": r[1], "route_id": r[2],
                "route_name": r[3], "stop_order": r[4],
                "latitude": float(r[5]) if r[5] is not None else None,
                "longitude": float(r[6]) if r[6] is not None else None,
                "pickup_time": str(r[7]) if r[7] is not None else None,
                "drop_time": str(r[8]) if r[8] is not None else None
            } for r in cursor.fetchall()]
    finally:
        conn.close()


@router.get("/trips")
def get_faculty_trips(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT t.trip_id, t.trip_date, t.start_time, t.end_time, t.status,
                       b.bus_number, r.route_name, u.name
                FROM trips t
                JOIN buses b ON b.bus_id=t.bus_id
                JOIN routes r ON r.route_id=t.route_id
                LEFT JOIN drivers d ON d.driver_id=t.driver_id
                LEFT JOIN users u ON u.user_id=d.user_id
                ORDER BY t.trip_date DESC, t.trip_id DESC
                LIMIT 100
            """)
            return [{"trip_id": r[0], "trip_date": str(r[1]) if r[1] else None,
                     "start_time": _iso(r[2]), "end_time": _iso(r[3]),
                     "status": r[4], "bus_number": r[5],
                     "route_name": r[6], "driver_name": r[7]}
                    for r in cursor.fetchall()]
    finally:
        conn.close()


@router.get("/live-buses")
def get_faculty_live_buses(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT DISTINCT ON (t.bus_id)
                       t.trip_id, t.status, b.bus_id, b.bus_number,
                       r.route_name, u.name AS driver_name,
                       bl.latitude, bl.longitude, bl.speed, bl.recorded_at,
                       (bl.recorded_at >= NOW() - INTERVAL '2 minutes') AS gps_online,
                       b.front_photo, b.side_photo
                FROM trips t
                JOIN buses b ON b.bus_id=t.bus_id
                JOIN routes r ON r.route_id=t.route_id
                LEFT JOIN drivers d ON d.driver_id=t.driver_id
                LEFT JOIN users u ON u.user_id=d.user_id
                LEFT JOIN bus_locations bl ON bl.trip_id=t.trip_id AND bl.bus_id=t.bus_id
                WHERE t.status='ACTIVE'
                ORDER BY t.bus_id, bl.recorded_at DESC NULLS LAST
            """)
            rows = cursor.fetchall()
            return [{"trip_id": r[0], "trip_status": r[1], "bus_id": r[2],
                     "bus_number": r[3], "route_name": r[4], "driver_name": r[5],
                     "latitude": float(r[6]) if r[6] is not None else None,
                     "longitude": float(r[7]) if r[7] is not None else None,
                     "speed": float(r[8]) if r[8] is not None else None,
                     "recorded_at": _iso(r[9]),
                     "gps_online": bool(r[10]) if r[10] is not None else False,
                     "front_photo": r[11], "side_photo": r[12]}
                    for r in rows]
    finally:
        conn.close()



@router.get("/buses")
def get_faculty_buses(current_user: dict = Depends(require_faculty)):
    """Read-only university fleet directory for authenticated faculty."""
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT b.bus_id, b.bus_number, b.bus_type, b.capacity,
                       b.registration_number, u.name AS driver_name,
                       active_route.route_name, active_route.route_code,
                       b.front_photo, b.side_photo
                FROM buses b
                LEFT JOIN drivers d ON d.driver_id = b.driver_id
                LEFT JOIN users u ON u.user_id = d.user_id
                LEFT JOIN LATERAL (
                    SELECT r.route_name, r.route_code
                    FROM trips t
                    JOIN routes r ON r.route_id = t.route_id
                    WHERE t.bus_id = b.bus_id AND t.status = 'ACTIVE'
                    ORDER BY t.start_time DESC NULLS LAST, t.trip_id DESC
                    LIMIT 1
                ) active_route ON TRUE
                ORDER BY b.bus_number
            """)
            return [{
                "bus_id": row[0], "bus_number": row[1], "bus_type": row[2],
                "capacity": row[3], "registration_number": row[4],
                "driver_name": row[5], "route_name": row[6], "route_code": row[7],
                "front_photo": row[8], "side_photo": row[9]
            } for row in cursor.fetchall()]
    finally:
        conn.close()


@router.get("/timetable")
def get_faculty_timetable(current_user: dict = Depends(require_faculty)):
    """Read-only university timetable for authenticated faculty."""
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT s.schedule_id, s.day_of_week, s.departure_time,
                       s.arrival_time, r.route_name, r.route_code,
                       b.bus_number, s.bus_id, s.route_id, s.direction
                FROM schedules s
                JOIN routes r ON r.route_id = s.route_id
                LEFT JOIN buses b ON b.bus_id = s.bus_id
                WHERE r.is_active = TRUE
                ORDER BY
                    CASE LOWER(s.day_of_week)
                        WHEN 'monday' THEN 1 WHEN 'tuesday' THEN 2
                        WHEN 'wednesday' THEN 3 WHEN 'thursday' THEN 4
                        WHEN 'friday' THEN 5 WHEN 'saturday' THEN 6
                        WHEN 'sunday' THEN 7 ELSE 8
                    END,
                    s.departure_time, r.route_name
            """)
            return [{
                "schedule_id": row[0], "day_of_week": row[1],
                "departure_time": row[2].isoformat() if row[2] else None,
                "arrival_time": row[3].isoformat() if row[3] else None,
                "route_name": row[4], "route_code": row[5],
                "bus_number": row[6], "bus_id": row[7],
                "route_id": row[8], "direction": row[9],
                "time": row[2].strftime("%H:%M") if row[2] else None,
                "status": "scheduled"
            } for row in cursor.fetchall()]
    finally:
        conn.close()
