from fastapi import APIRouter, Depends, HTTPException

from backend.app.dependencies import get_current_user
from backend.app.database.connection import get_connection


router = APIRouter(
    prefix="/students",
    tags=["Students"]
)


# Logged-in student: View own profile
@router.get("/me")
def get_my_profile(current_user: dict = Depends(get_current_user)):

    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT
                    u.user_id,
                    u.name,
                    u.email,
                    u.role,
                    u.is_active,
                    s.student_id,
                    s.enrollment_no,
                    s.department,
                    s.semester
                FROM users u
                JOIN students s
                    ON u.user_id = s.user_id
                WHERE u.user_id = %s
            """, (current_user["user_id"],))

            student = cursor.fetchone()

            if not student:
                raise HTTPException(
                    status_code=404,
                    detail="Student profile not found"
                )

            return {
                "user_id": student[0],
                "name": student[1],
                "email": student[2],
                "role": student[3],
                "is_active": student[4],
                "student_id": student[5],
                "enrollment_no": student[6],
                "department": student[7],
                "semester": student[8]
            }

    finally:
        conn.close()

# Logged-in student: View all active university routes
@router.get("/routes")
def get_all_student_routes(current_user: dict = Depends(get_current_user)):

    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    route_id,
                    route_name,
                    route_code,
                    description,
                    start_point,
                    end_point,
                    is_active
                FROM routes
                WHERE is_active = TRUE
                ORDER BY route_id
            """)

            routes = cursor.fetchall()

            return [
                {
                    "route_id": route[0],
                    "route_name": route[1],
                    "route_code": route[2],
                    "description": route[3],
                    "start_point": route[4],
                    "end_point": route[5],
                    "is_active": route[6]
                }
                for route in routes
            ]

    finally:
        conn.close()


# Logged-in student: View all university buses and their photos
@router.get("/buses")
def get_all_student_buses(current_user: dict = Depends(get_current_user)):

    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    bus_id,
                    bus_number,
                    bus_type,
                    capacity,
                    registration_number,
                    front_photo,
                    side_photo
                FROM buses
                ORDER BY bus_id
            """)

            buses = cursor.fetchall()

            return [
                {
                    "bus_id": bus[0],
                    "bus_number": bus[1],
                    "bus_type": bus[2],
                    "capacity": bus[3],
                    "registration_number": bus[4],
                    "front_photo": bus[5],
                    "side_photo": bus[6]
                }
                for bus in buses
            ]

    finally:
        conn.close()


# Logged-in student: View subscribed routes
@router.get("/me/routes")
def get_my_routes(current_user: dict = Depends(get_current_user)):

    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT
                    r.route_id,
                    r.route_name,
                    r.route_code,
                    r.description,
                    r.start_point,
                    r.end_point,
                    r.is_active,
                    s.subscription_id,
                    s.subscribed_at,
                    s.is_active
                FROM students st
                JOIN subscriptions s
                    ON st.student_id = s.student_id
                JOIN routes r
                    ON s.route_id = r.route_id
                WHERE st.user_id = %s
                  AND s.is_active = TRUE
                  AND r.is_active = TRUE
                ORDER BY r.route_id
            """, (current_user["user_id"],))

            routes = cursor.fetchall()

            return [
                {
                    "route_id": route[0],
                    "route_name": route[1],
                    "route_code": route[2],
                    "description": route[3],
                    "start_point": route[4],
                    "end_point": route[5],
                    "is_active": route[6],
                    "subscription_id": route[7],
                    "subscribed_at": route[8],
                    "subscription_active": route[9]
                }
                for route in routes
            ]

    finally:
        conn.close()        
# Logged-in student: Subscribe to a route
@router.post("/me/routes/{route_id}/subscribe")
def subscribe_to_route(
    route_id: int,
    current_user: dict = Depends(get_current_user)
):

    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            # Get student ID
            cursor.execute("""
                SELECT student_id
                FROM students
                WHERE user_id = %s
            """, (current_user["user_id"],))

            student = cursor.fetchone()

            if not student:
                raise HTTPException(
                    status_code=404,
                    detail="Student profile not found"
                )

            student_id = student[0]

            # Check route
            cursor.execute("""
                SELECT
                    route_id,
                    route_name,
                    route_code
                FROM routes
                WHERE route_id = %s
                  AND is_active = TRUE
            """, (route_id,))

            route = cursor.fetchone()

            if not route:
                raise HTTPException(
                    status_code=404,
                    detail="Route not found or inactive"
                )

            # Check existing subscription
            cursor.execute("""
                SELECT
                    subscription_id,
                    is_active
                FROM subscriptions
                WHERE student_id = %s
                  AND route_id = %s
            """, (student_id, route_id))

            existing = cursor.fetchone()

            if existing:

                if existing[1] is True:
                    raise HTTPException(
                        status_code=409,
                        detail="Already subscribed to this route"
                    )

                # Reactivate old subscription
                cursor.execute("""
                    UPDATE subscriptions
                    SET is_active = TRUE,
                        subscribed_at = CURRENT_TIMESTAMP
                    WHERE subscription_id = %s
                    RETURNING subscription_id
                """, (existing[0],))

                subscription_id = cursor.fetchone()[0]

            else:

                # Create new subscription
                cursor.execute("""
                    INSERT INTO subscriptions
                        (student_id, route_id)
                    VALUES
                        (%s, %s)
                    RETURNING subscription_id
                """, (student_id, route_id))

                subscription_id = cursor.fetchone()[0]

            conn.commit()

            return {
                "message": "Route subscribed successfully",
                "subscription_id": subscription_id,
                "student_id": student_id,
                "route_id": route[0],
                "route_name": route[1],
                "route_code": route[2]
            }

    except HTTPException:
        conn.rollback()
        raise

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close() 

# Logged-in student: View stops of any active university route
@router.get("/routes/{route_id}/stops")
def get_all_route_stops(
    route_id: int,
    current_user: dict = Depends(get_current_user)
):
    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT route_id
                FROM routes
                WHERE route_id = %s
                  AND is_active = TRUE
            """, (route_id,))

            if not cursor.fetchone():
                raise HTTPException(
                    status_code=404,
                    detail="Active route not found"
                )

            cursor.execute("""
                SELECT
                    stop_id,
                    route_id,
                    stop_name,
                    latitude,
                    longitude,
                    stop_order
                FROM stops
                WHERE route_id = %s
                ORDER BY stop_order
            """, (route_id,))

            stops = cursor.fetchall()

            return [
                {
                    "stop_id": stop[0],
                    "route_id": stop[1],
                    "stop_name": stop[2],
                    "latitude": float(stop[3]),
                    "longitude": float(stop[4]),
                    "stop_order": stop[5]
                }
                for stop in stops
            ]

    finally:
        conn.close()


# Logged-in student: View stops of a subscribed route
@router.get("/me/routes/{route_id}/stops")
def get_my_route_stops(
    route_id: int,
    current_user: dict = Depends(get_current_user)
):

    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            # Get student ID
            cursor.execute("""
                SELECT student_id
                FROM students
                WHERE user_id = %s
            """, (current_user["user_id"],))

            student = cursor.fetchone()

            if not student:
                raise HTTPException(
                    status_code=404,
                    detail="Student profile not found"
                )

            student_id = student[0]

            # Check active route subscription
            cursor.execute("""
                SELECT subscription_id
                FROM subscriptions
                WHERE student_id = %s
                  AND route_id = %s
                  AND is_active = TRUE
            """, (student_id, route_id))

            subscription = cursor.fetchone()

            if not subscription:
                raise HTTPException(
                    status_code=403,
                    detail="You are not subscribed to this route"
                )

            # Get stops
            cursor.execute("""
                SELECT
                    stop_id,
                    route_id,
                    stop_name,
                    latitude,
                    longitude,
                    stop_order
                FROM stops
                WHERE route_id = %s
                ORDER BY stop_order
            """, (route_id,))

            stops = cursor.fetchall()

            return [
                {
                    "stop_id": stop[0],
                    "route_id": stop[1],
                    "stop_name": stop[2],
                    "latitude": float(stop[3]),
                    "longitude": float(stop[4]),
                    "stop_order": stop[5]
                }
                for stop in stops
            ]

    finally:
        conn.close()

# Logged-in student: Get bus details for any active route
@router.get("/routes/{route_id}/bus")
def get_any_route_bus(
    route_id: int,
    current_user: dict = Depends(get_current_user)
):
    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT route_id
                FROM routes
                WHERE route_id = %s
                  AND is_active = TRUE
            """, (route_id,))

            if not cursor.fetchone():
                raise HTTPException(
                    status_code=404,
                    detail="Active route not found"
                )

            cursor.execute("""
                SELECT
                    t.trip_id,
                    t.route_id,
                    t.bus_id,
                    t.driver_id,
                    t.trip_date,
                    t.start_time,
                    t.end_time,
                    t.status,
                    b.bus_number,
                    b.bus_type,
                    b.capacity,
                    b.registration_number,
                    b.front_photo,
                    b.side_photo
                FROM trips t
                JOIN buses b ON t.bus_id = b.bus_id
                WHERE t.route_id = %s
                ORDER BY
                    CASE
                        WHEN t.trip_date = CURRENT_DATE AND t.status = 'ACTIVE' THEN 1
                        WHEN t.trip_date = CURRENT_DATE AND t.status = 'SCHEDULED' THEN 2
                        ELSE 3
                    END,
                    t.trip_date DESC,
                    t.start_time NULLS LAST,
                    t.trip_id DESC
                LIMIT 1
            """, (route_id,))

            trip = cursor.fetchone()

            if not trip:
                return {
                    "route_id": route_id,
                    "bus_assigned": False,
                    "bus_available": False,
                    "message": "No bus is assigned to this route"
                }

            is_available_today = (
                trip[4] == __import__("datetime").date.today()
                and trip[7] in ("ACTIVE", "SCHEDULED")
            )

            return {
                "trip_id": trip[0],
                "route_id": trip[1],
                "bus_id": trip[2],
                "driver_id": trip[3],
                "trip_date": str(trip[4]),
                "start_time": trip[5].isoformat() if trip[5] else None,
                "end_time": trip[6].isoformat() if trip[6] else None,
                "trip_status": trip[7],
                "bus_number": trip[8],
                "bus_type": trip[9],
                "capacity": trip[10],
                "registration_number": trip[11],
                "front_photo": trip[12],
                "side_photo": trip[13],
                "bus_assigned": True,
                "bus_available": is_available_today
            }

    finally:
        conn.close()


# Logged-in student: Get bus assigned to a subscribed route
@router.get("/me/routes/{route_id}/bus")
def get_route_bus(
    route_id: int,
    current_user: dict = Depends(get_current_user)
):

    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            # Check student
            cursor.execute("""
                SELECT student_id
                FROM students
                WHERE user_id = %s
            """, (current_user["user_id"],))

            student = cursor.fetchone()

            if not student:
                raise HTTPException(
                    status_code=404,
                    detail="Student profile not found"
                )

            student_id = student[0]

            # Check active subscription
            cursor.execute("""
                SELECT subscription_id
                FROM subscriptions
                WHERE student_id = %s
                  AND route_id = %s
                  AND is_active = TRUE
            """, (student_id, route_id))

            subscription = cursor.fetchone()

            if not subscription:
                raise HTTPException(
                    status_code=403,
                    detail="You are not subscribed to this route"
                )

            # Find bus through trips
            cursor.execute("""
                SELECT
                    t.trip_id,
                    t.route_id,
                    t.bus_id,
                    t.driver_id,
                    t.trip_date,
                    t.start_time,
                    t.end_time,
                    t.status,
                    b.bus_number,
                    b.bus_type,
                    b.capacity,
                    b.registration_number
                FROM trips t
                JOIN buses b
                    ON t.bus_id = b.bus_id
                WHERE t.route_id = %s
                  AND t.trip_date = CURRENT_DATE
                  AND t.status IN ('ACTIVE', 'SCHEDULED')
                ORDER BY
                    CASE
                        WHEN t.status = 'ACTIVE' THEN 1
                        WHEN t.status = 'SCHEDULED' THEN 2
                    END,
                    t.start_time NULLS LAST
                LIMIT 1
             """, (route_id,))
            trip = cursor.fetchone()


            if not trip:
                raise HTTPException(
                    status_code=404,
                    detail="No active or scheduled bus trip found for this route today"
                )

            return {
                "trip_id": trip[0],
                "route_id": trip[1],
                "bus_id": trip[2],
                "driver_id": trip[3],
                "trip_date": str(trip[4]),
                "start_time": trip[5].isoformat() if trip[5] else None,
                "end_time": trip[6].isoformat() if trip[6] else None,
                "trip_status": trip[7],
                "bus_number": trip[8],
                "bus_type": trip[9],
                "capacity": trip[10],
                "registration_number": trip[11]
            }

    finally:
        conn.close()        



# Student: Get GPS location for any active university route
@router.get("/routes/{route_id}/bus/location")
def get_any_route_bus_location(
    route_id: int,
    current_user: dict = Depends(get_current_user)
):
    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT route_id
                FROM routes
                WHERE route_id = %s
                  AND is_active = TRUE
            """, (route_id,))

            if not cursor.fetchone():
                raise HTTPException(
                    status_code=404,
                    detail="Active route not found"
                )

            cursor.execute("""
                SELECT trip_id, bus_id
                FROM trips
                WHERE route_id = %s
                  AND trip_date = CURRENT_DATE
                  AND status = 'ACTIVE'
                ORDER BY trip_id DESC
                LIMIT 1
            """, (route_id,))

            trip = cursor.fetchone()

            if not trip:
                return {
                    "route_id": route_id,
                    "bus_available": False,
                    "last_location": None,
                    "message": "No active bus trip found for this route today"
                }

            trip_id, bus_id = trip

            cursor.execute("""
                SELECT bus_number
                FROM buses
                WHERE bus_id = %s
            """, (bus_id,))

            bus = cursor.fetchone()

            cursor.execute("""
                SELECT latitude, longitude, speed, recorded_at
                FROM bus_locations
                WHERE trip_id = %s
                  AND bus_id = %s
                ORDER BY recorded_at DESC, location_id DESC
                LIMIT 1
            """, (trip_id, bus_id))

            loc = cursor.fetchone()

            return {
                "route_id": route_id,
                "trip_id": trip_id,
                "bus_id": bus_id,
                "bus_number": bus[0] if bus else None,
                "trip_status": "ACTIVE",
                "bus_available": True,
                "last_location": None if not loc else {
                    "latitude": float(loc[0]),
                    "longitude": float(loc[1]),
                    "speed": float(loc[2]) if loc[2] is not None else None,
                    "recorded_at": loc[3].isoformat()
                }
            }

    finally:
        conn.close()


# Student: Get latest GPS location of the active bus
@router.get("/me/routes/{route_id}/bus/location")
def get_route_bus_location(
    route_id: int,
    current_user: dict = Depends(get_current_user)
):
    if current_user["role"] != "STUDENT":
        raise HTTPException(
            status_code=403,
            detail="Student access required"
        )

    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            # Verify student and active route subscription
            cursor.execute("""
                SELECT st.student_id
                FROM students st
                JOIN subscriptions s
                    ON st.student_id = s.student_id
                WHERE st.user_id = %s
                  AND s.route_id = %s
                  AND s.is_active = TRUE
            """, (current_user["user_id"], route_id))

            student = cursor.fetchone()

            if not student:
                raise HTTPException(
                    status_code=403,
                    detail="You are not subscribed to this route"
                )

            # Find today's active trip on this route
            cursor.execute("""
                SELECT trip_id, bus_id
                FROM trips
                WHERE route_id = %s
                AND status = 'ACTIVE'
                ORDER BY trip_id DESC
                LIMIT 1
            """, (route_id,))

            trip = cursor.fetchone()

            if not trip:
                raise HTTPException(
                    status_code=404,
                    detail="No active bus trip found for this route"
                )

            trip_id = trip[0]
            bus_id = trip[1]

            # Get bus number
            cursor.execute("""
                SELECT bus_number
                FROM buses
                WHERE bus_id = %s
            """, (bus_id,))

            bus = cursor.fetchone()

            # Get latest GPS location for this exact trip
            cursor.execute("""
                SELECT latitude, longitude, speed, recorded_at
                FROM bus_locations
                WHERE trip_id = %s
                  AND bus_id = %s
                ORDER BY recorded_at DESC, location_id DESC
                LIMIT 1
            """, (trip_id, bus_id))

            loc = cursor.fetchone()

            return {
                "route_id": route_id,
                "trip_id": trip_id,
                "bus_id": bus_id,
                "bus_number": bus[0] if bus else None,
                "trip_status": "ACTIVE",
                "last_location": None if not loc else {
                    "latitude": float(loc[0]),
                    "longitude": float(loc[1]),
                    "speed": float(loc[2]) if loc[2] is not None else None,
                    "recorded_at": loc[3].isoformat()
                }
            }

    finally:
        conn.close()

        