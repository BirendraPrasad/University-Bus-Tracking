from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, Body

from pathlib import Path
import shutil
import uuid


from backend.app.dependencies import get_current_user, require_admin
from backend.app.database.connection import get_connection


from backend.app.schemas.user import (
    UserCreate,
    StudentCreate,
    DriverCreate,
    FacultyCreate,
    BusCreate,
    BusUpdate,
    RouteCreate,
    RouteUpdate,
    StopCreate,
    StopUpdate,
    BusAssignDriver
)

from backend.app.services.security import hash_password

from datetime import date, datetime
from fastapi import HTTPException

router = APIRouter(
    prefix="/users",
    tags=["Users"]
)


# Admin: View all users
@router.get("/")
def get_users(current_user: dict = Depends(require_admin)):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT user_id, name, email, role, is_active
                FROM users
                ORDER BY user_id
            """)

            users = cursor.fetchall()

            return [
                {
                    "user_id": user[0],
                    "name": user[1],
                    "email": user[2],
                    "role": user[3],
                    "is_active": user[4]
                }
                for user in users
            ]

    finally:
        conn.close()


# ============================================
# ADMIN: EDIT USER DETAILS
# ============================================

@router.put("/{user_id}")
def update_user(
    user_id: int,
    payload: dict = Body(...),
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT role
                FROM users
                WHERE user_id = %s
                FOR UPDATE
            """, (user_id,))

            result = cursor.fetchone()

            if not result:
                raise HTTPException(status_code=404, detail="User not found")

            role = result[0]

            # Common fields
            common_fields = {"name", "email"}

            # Role-specific profile fields
            profile_config = {
                "STUDENT": {
                    "table": "students",
                    "fields": {"enrollment_no", "department", "semester"},
                    "id_column": "user_id"
                },
                "FACULTY": {
                    "table": "faculty",
                    "fields": {"employee_id", "department"},
                    "id_column": "user_id"
                },
                "DRIVER": {
                    "table": "drivers",
                    "fields": {"license_number", "phone"},
                    "id_column": "user_id"
                }
            }

            allowed_fields = set(common_fields)

            if role in profile_config:
                allowed_fields.update(profile_config[role]["fields"])

            invalid_fields = set(payload) - allowed_fields

            if invalid_fields:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid fields: {', '.join(invalid_fields)}"
                )

            if not payload:
                raise HTTPException(
                    status_code=400,
                    detail="No fields provided"
                )

            # Validate values
            if "name" in payload and not str(payload["name"]).strip():
                raise HTTPException(status_code=400, detail="Name cannot be empty")

            if "email" in payload:
                email = str(payload["email"]).strip().lower()

                if not email or "@" not in email:
                    raise HTTPException(status_code=400, detail="Invalid email")

                cursor.execute("""
                    SELECT user_id FROM users
                    WHERE LOWER(email) = %s AND user_id != %s
                """, (email, user_id))

                if cursor.fetchone():
                    raise HTTPException(status_code=409, detail="Email already exists")

                payload["email"] = email

            if "semester" in payload:
                if not isinstance(payload["semester"], int) or payload["semester"] < 1:
                    raise HTTPException(status_code=400, detail="Invalid semester")

            # Update common user fields
            user_updates = {
                key: value for key, value in payload.items()
                if key in common_fields
            }

            if user_updates:
                set_clause = ", ".join(
                    f"{key} = %s" for key in user_updates
                )

                cursor.execute(
                    f"UPDATE users SET {set_clause} WHERE user_id = %s",
                    list(user_updates.values()) + [user_id]
                )

            # Update role-specific profile
            profile_updates = {
                key: value for key, value in payload.items()
                if key not in common_fields
            }

            if profile_updates:
                if role not in profile_config:
                    raise HTTPException(
                        status_code=400,
                        detail="This role has no editable profile fields"
                    )

                config = profile_config[role]

                # Check unique profile fields
                unique_field = {
                    "STUDENT": "enrollment_no",
                    "FACULTY": "employee_id",
                    "DRIVER": "license_number"
                }[role]

                if unique_field in profile_updates:
                    cursor.execute(
                        f"""
                        SELECT user_id FROM {config['table']}
                        WHERE {unique_field} = %s AND user_id != %s
                        """,
                        (profile_updates[unique_field], user_id)
                    )

                    if cursor.fetchone():
                        raise HTTPException(
                            status_code=409,
                            detail=f"{unique_field} already exists"
                        )

                set_clause = ", ".join(
                    f"{key} = %s" for key in profile_updates
                )

                cursor.execute(
                    f"""
                    UPDATE {config['table']}
                    SET {set_clause}
                    WHERE user_id = %s
                    """,
                    list(profile_updates.values()) + [user_id]
                )

                if cursor.rowcount == 0:
                    raise HTTPException(
                        status_code=404,
                        detail="User profile not found"
                    )

            conn.commit()

            return {
                "message": "User updated successfully",
                "user_id": user_id,
                "role": role
            }

        

    except HTTPException:
        conn.rollback()
        raise

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


# ============================================
# ADMIN: ACTIVATE / DEACTIVATE USER
# ============================================

@router.patch("/{user_id}/status")
def update_user_status(
    user_id: int,
    payload: dict = Body(...),
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        is_active = payload.get("is_active")

        if not isinstance(is_active, bool):
            raise HTTPException(
                status_code=400,
                detail="is_active must be true or false"
            )

        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT role, is_active
                FROM users
                WHERE user_id = %s
                FOR UPDATE
            """, (user_id,))

            user = cursor.fetchone()

            if not user:
                raise HTTPException(status_code=404, detail="User not found")

            role, current_status = user

            if current_status == is_active:
                return {
                    "message": "User status is already set",
                    "user_id": user_id,
                    "is_active": is_active
                }

            # Prevent deactivation of the last active admin
            if role == "ADMIN" and not is_active:
                cursor.execute("""
                    SELECT COUNT(*)
                    FROM users
                    WHERE role = 'ADMIN' AND is_active = TRUE
                """)

                active_admins = cursor.fetchone()[0]

                if active_admins <= 1:
                    raise HTTPException(
                        status_code=409,
                        detail="Cannot deactivate the last active admin"
                    )

            cursor.execute("""
                UPDATE users
                SET is_active = %s
                WHERE user_id = %s
            """, (is_active, user_id))

            conn.commit()

            return {
                "message": "User status updated successfully",
                "user_id": user_id,
                "is_active": is_active
            }

    except HTTPException:
        conn.rollback()
        raise

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()



# Admin: Create a new user
@router.post("/")
def create_user(
    user: UserCreate,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        password_hash = hash_password(user.password)

        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO users
                    (name, email, password_hash, role)
                VALUES
                    (%s, %s, %s, %s)
                RETURNING user_id, name, email, role, is_active
            """, (
                user.name,
                user.email,
                password_hash,
                user.role
            ))

            new_user = cursor.fetchone()
            conn.commit()

            return {
                "user_id": new_user[0],
                "name": new_user[1],
                "email": new_user[2],
                "role": new_user[3],
                "is_active": new_user[4]
            }

    finally:
        conn.close()


# Logged-in user: View own profile
@router.get("/profile")
def get_profile(current_user: dict = Depends(get_current_user)):
    return {
        "message": "Protected profile accessed successfully",
        "user_id": current_user["user_id"],
        "role": current_user["role"]
    }


# Admin: Test admin authorization
@router.get("/admin-test")
def admin_test(current_user: dict = Depends(require_admin)):
    return {
        "message": "Admin access granted",
        "user_id": current_user["user_id"],
        "role": current_user["role"]
    }
# Admin: Create a student
@router.post("/students")
def create_student(
    student: StudentCreate,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        password_hash = hash_password(student.password)

        with conn.cursor() as cursor:

            # Create user
            cursor.execute("""
                INSERT INTO users
                    (name, email, password_hash, role)
                VALUES
                    (%s, %s, %s, 'STUDENT')
                RETURNING user_id
            """, (
                student.name,
                student.email,
                password_hash
            ))

            user_id = cursor.fetchone()[0]

            # Create student profile
            cursor.execute("""
                INSERT INTO students
                    (user_id, enrollment_no, department, semester)
                VALUES
                    (%s, %s, %s, %s)
                RETURNING student_id
            """, (
                user_id,
                student.enrollment_no,
                student.department,
                student.semester
            ))

            student_id = cursor.fetchone()[0]

            conn.commit()

            return {
                "message": "Student created successfully",
                "user_id": user_id,
                "student_id": student_id,
                "name": student.name,
                "email": student.email,
                "enrollment_no": student.enrollment_no,
                "department": student.department,
                "semester": student.semester,
                "role": "STUDENT"
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()

# Admin: Create a driver
@router.post("/drivers")
def create_driver(
    driver: DriverCreate,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        password_hash = hash_password(driver.password)

        with conn.cursor() as cursor:

            # Create user
            cursor.execute("""
                INSERT INTO users
                    (name, email, password_hash, role)
                VALUES
                    (%s, %s, %s, 'DRIVER')
                RETURNING user_id
            """, (
                driver.name,
                driver.email,
                password_hash
            ))

            user_id = cursor.fetchone()[0]

            # Create driver profile
            cursor.execute("""
                INSERT INTO drivers
                    (user_id, license_number, phone)
                VALUES
                    (%s, %s, %s)
                RETURNING driver_id
            """, (
                user_id,
                driver.license_number,
                driver.phone
            ))

            driver_id = cursor.fetchone()[0]

            # Notify all Admin accounts about new driver
            cursor.execute("""
                INSERT INTO notifications
                    (user_id, title, message, notification_type)
                SELECT
                    user_id,
                    %s,
                    %s,
                    %s
                FROM users
                WHERE role = 'ADMIN'
            """, (
                "New Driver Added",
                f"{driver.name} has been added by Admin.",
                "DRIVER_ADDED"
            ))
            conn.commit()

            return {
                "message": "Driver created successfully",
                "user_id": user_id,
                "driver_id": driver_id,
                "name": driver.name,
                "email": driver.email,
                "license_number": driver.license_number,
                "phone": driver.phone,
                "role": "DRIVER"
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()        

# Admin: Create a faculty member
@router.post("/faculty")
def create_faculty(
    faculty: FacultyCreate,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        password_hash = hash_password(faculty.password)

        with conn.cursor() as cursor:

            # Create user
            cursor.execute("""
                INSERT INTO users
                    (name, email, password_hash, role)
                VALUES
                    (%s, %s, %s, 'FACULTY')
                RETURNING user_id
            """, (
                faculty.name,
                faculty.email,
                password_hash
            ))

            user_id = cursor.fetchone()[0]

            # Create faculty profile
            cursor.execute("""
                INSERT INTO faculty
                    (user_id, employee_id, department)
                VALUES
                    (%s, %s, %s)
                RETURNING faculty_id
            """, (
                user_id,
                faculty.employee_id,
                faculty.department
            ))

            faculty_id = cursor.fetchone()[0]

            conn.commit()

            return {
                "message": "Faculty created successfully",
                "user_id": user_id,
                "faculty_id": faculty_id,
                "name": faculty.name,
                "email": faculty.email,
                "employee_id": faculty.employee_id,
                "department": faculty.department,
                "role": "FACULTY"
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()        
# Admin: Create a bus
def validate_bus_route(cursor, bus_type, route_id):
    if route_id is None:
        return

    cursor.execute(
        "SELECT route_code, is_active FROM routes WHERE route_id = %s",
        (route_id,)
    )
    route = cursor.fetchone()

    if not route:
        raise HTTPException(status_code=404, detail="Route not found")

    route_code, is_active = route

    if not is_active:
        raise HTTPException(status_code=400, detail="Route is inactive")

    allowed = (
        {"R001", "R002", "R003", "R004", "R005", "R006"}
        if bus_type == "ROUTE_BUS"
        else {"R007", "R008"}
    )

    if route_code not in allowed:
        raise HTTPException(status_code=400, detail="Route does not match bus type")


@router.post("/buses")
def create_bus(
    bus: BusCreate,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            validate_bus_route(cursor, bus.bus_type, bus.route_id)

            cursor.execute("""
                INSERT INTO buses
                    (bus_number, bus_type, capacity, registration_number, route_id)
                VALUES
                    (%s, %s, %s, %s, %s)
                RETURNING
                    bus_id,
                    bus_number,
                    bus_type,
                    capacity,
                    registration_number,
                    route_id
            """, (
                bus.bus_number,
                bus.bus_type,
                bus.capacity,
                bus.registration_number,
                bus.route_id
            ))

            new_bus = cursor.fetchone()
            conn.commit()

            return {
                "message": "Bus created successfully",
                "bus_id": new_bus[0],
                "bus_number": new_bus[1],
                "bus_type": new_bus[2],
                "capacity": new_bus[3],
                "registration_number": new_bus[4],
                "route_id": new_bus[5]
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()  

# Admin: Create a route
@router.post("/routes")
def create_route(
    route: RouteCreate,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO routes
                    (route_name, route_code, description, start_point, end_point)
                VALUES
                    (%s, %s, %s, %s, %s)
                RETURNING
                    route_id,
                    route_name,
                    route_code,
                    description,
                    start_point,
                    end_point,
                    is_active
            """, (
                route.route_name,
                route.route_code,
                route.description,
                route.start_point,
                route.end_point
            ))

            new_route = cursor.fetchone()
            conn.commit()

            return {
                "message": "Route created successfully",
                "route_id": new_route[0],
                "route_name": new_route[1],
                "route_code": new_route[2],
                "description": new_route[3],
                "start_point": new_route[4],
                "end_point": new_route[5],
                "is_active": new_route[6]
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()

# Admin: Create a stop
@router.post("/stops")
def create_stop(
    stop: StopCreate,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            # Check whether route exists
            cursor.execute("""
                SELECT route_id
                FROM routes
                WHERE route_id = %s
            """, (stop.route_id,))

            route = cursor.fetchone()

            if not route:
                from fastapi import HTTPException
                raise HTTPException(
                    status_code=404,
                    detail="Route not found"
                )

            cursor.execute("""
                INSERT INTO stops
                    (route_id, stop_name, latitude, longitude, stop_order,
                     pickup_time, drop_time)
                VALUES
                    (%s, %s, %s, %s, %s, %s, %s)
                RETURNING
                    stop_id,
                    route_id,
                    stop_name,
                    latitude,
                    longitude,
                    stop_order,
                    pickup_time,
                    drop_time
            """, (
                stop.route_id,
                stop.stop_name,
                stop.latitude,
                stop.longitude,
                stop.stop_order,
                stop.pickup_time or None,
                stop.drop_time or None
            ))

            new_stop = cursor.fetchone()
            conn.commit()

            return {
                "message": "Stop created successfully",
                "stop_id": new_stop[0],
                "route_id": new_stop[1],
                "stop_name": new_stop[2],
                "latitude": float(new_stop[3]),
                "longitude": float(new_stop[4]),
                "stop_order": new_stop[5],
                "pickup_time": str(new_stop[6]) if new_stop[6] is not None else None,
                "drop_time": str(new_stop[7]) if new_stop[7] is not None else None
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()

# Admin: View all stops of a route
@router.get("/routes/{route_id}/stops")
def get_route_stops(
    route_id: int,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT
                    stop_id,
                    route_id,
                    stop_name,
                    latitude,
                    longitude,
                    stop_order,
                    pickup_time,
                    drop_time
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
                    "stop_order": stop[5],
                    "pickup_time": str(stop[6]) if stop[6] is not None else None,
                    "drop_time": str(stop[7]) if stop[7] is not None else None
                }
                for stop in stops
            ]

    finally:
        conn.close()        

# Admin: View all routes
@router.get("/routes")
def get_routes(
    current_user: dict = Depends(require_admin)
):
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


# Admin: Edit a route
@router.put("/routes/{route_id}")
def update_route(
    route_id: int,
    payload: RouteUpdate,
    current_user: dict = Depends(require_admin)
):
    fields = payload.dict(exclude_unset=True)
    allowed = {
        "route_name", "route_code", "description",
        "start_point", "end_point", "is_active"
    }
    fields = {k: v for k, v in fields.items() if k in allowed}

    if not fields:
        raise HTTPException(status_code=400, detail="No route fields supplied")

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT route_id FROM routes WHERE route_id = %s FOR UPDATE",
                (route_id,)
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="Route not found")

            if "route_code" in fields:
                cursor.execute(
                    "SELECT route_id FROM routes WHERE route_code = %s AND route_id <> %s",
                    (fields["route_code"], route_id)
                )
                if cursor.fetchone():
                    raise HTTPException(status_code=409, detail="Route code already exists")

            assignments = ", ".join(f"{key} = %s" for key in fields)
            values = list(fields.values()) + [route_id]
            cursor.execute(
                f"""
                UPDATE routes SET {assignments}
                WHERE route_id = %s
                RETURNING route_id, route_name, route_code, description,
                          start_point, end_point, is_active
                """,
                values
            )
            row = cursor.fetchone()
            conn.commit()
            return {
                "message": "Route updated successfully",
                "route_id": row[0],
                "route_name": row[1],
                "route_code": row[2],
                "description": row[3],
                "start_point": row[4],
                "end_point": row[5],
                "is_active": row[6]
            }
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# Admin: Delete a route only when it has no dependent records
@router.delete("/routes/{route_id}")
def delete_route(
    route_id: int,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT route_id FROM routes WHERE route_id = %s FOR UPDATE",
                (route_id,)
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="Route not found")

            dependencies = {}
            for table in ("buses", "trips", "stops", "schedules", "subscriptions"):
                cursor.execute(
                    f"SELECT COUNT(*) FROM {table} WHERE route_id = %s",
                    (route_id,)
                )
                dependencies[table] = cursor.fetchone()[0]

            used_by = {k: v for k, v in dependencies.items() if v > 0}
            if used_by:
                raise HTTPException(
                    status_code=409,
                    detail={"message": "Route cannot be deleted because records depend on it",
                            "dependencies": used_by}
                )

            cursor.execute("DELETE FROM routes WHERE route_id = %s", (route_id,))
            conn.commit()
            return {"message": "Route deleted successfully", "route_id": route_id}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# Admin: Edit a stop, including its timetable
@router.put("/stops/{stop_id}")
def update_stop(
    stop_id: int,
    payload: StopUpdate,
    current_user: dict = Depends(require_admin)
):
    fields = payload.dict(exclude_unset=True)
    allowed = {
        "stop_name", "latitude", "longitude", "stop_order",
        "pickup_time", "drop_time"
    }
    fields = {k: v for k, v in fields.items() if k in allowed}

    if not fields:
        raise HTTPException(status_code=400, detail="No stop fields supplied")

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT route_id FROM stops WHERE stop_id = %s FOR UPDATE",
                (stop_id,)
            )
            existing = cursor.fetchone()
            if not existing:
                raise HTTPException(status_code=404, detail="Stop not found")

            route_id = existing[0]
            if "stop_order" in fields:
                cursor.execute(
                    """
                    SELECT stop_id FROM stops
                    WHERE route_id = %s AND stop_order = %s AND stop_id <> %s
                    """,
                    (route_id, fields["stop_order"], stop_id)
                )
                if cursor.fetchone():
                    raise HTTPException(
                        status_code=409,
                        detail="This stop order is already used on the route"
                    )

            assignments = ", ".join(f"{key} = %s" for key in fields)
            values = list(fields.values()) + [stop_id]
            cursor.execute(
                f"""
                UPDATE stops SET {assignments}
                WHERE stop_id = %s
                RETURNING stop_id, route_id, stop_name, latitude, longitude,
                          stop_order, pickup_time, drop_time
                """,
                values
            )
            row = cursor.fetchone()
            conn.commit()
            return {
                "message": "Stop updated successfully",
                "stop_id": row[0],
                "route_id": row[1],
                "stop_name": row[2],
                "latitude": float(row[3]),
                "longitude": float(row[4]),
                "stop_order": row[5],
                "pickup_time": str(row[6]) if row[6] is not None else None,
                "drop_time": str(row[7]) if row[7] is not None else None
            }
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# Admin: Delete a stop
@router.delete("/stops/{stop_id}")
def delete_stop(
    stop_id: int,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT stop_id FROM stops WHERE stop_id = %s FOR UPDATE",
                (stop_id,)
            )
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="Stop not found")

            cursor.execute("DELETE FROM stops WHERE stop_id = %s", (stop_id,))
            conn.commit()
            return {"message": "Stop deleted successfully", "stop_id": stop_id}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


# Admin: View all buses
@router.get("/buses")
def get_buses(
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    b.bus_id,
                    b.bus_number,
                    b.bus_type,
                    b.capacity,
                    b.registration_number,
                    b.driver_id,
                    b.front_photo,
                    b.side_photo,
                    b.route_id,
                    r.route_code,
                    r.route_name
                FROM buses b
                LEFT JOIN routes r ON b.route_id = r.route_id
                ORDER BY b.bus_id
            """)

            buses = cursor.fetchall()

            return [
                {
                    "bus_id": bus[0],
                    "bus_number": bus[1],
                    "bus_type": bus[2],
                    "capacity": bus[3],
                    "registration_number": bus[4],
                    "driver_id": bus[5],
                    "front_photo": bus[6],
                    "side_photo": bus[7],
                    "route_id": bus[8],
                    "route_code": bus[9],
                    "route_name": bus[10]
                }
                for bus in buses
            ]

    finally:
        conn.close()


# Admin: View all drivers
@router.get("/drivers")
def get_drivers(
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    d.driver_id,
                    u.user_id,
                    u.name,
                    u.email,
                    d.license_number,
                    d.phone
                FROM drivers d
                JOIN users u
                    ON d.user_id = u.user_id
                ORDER BY d.driver_id
            """)

            drivers = cursor.fetchall()

            return [
                {
                    "driver_id": driver[0],
                    "user_id": driver[1],
                    "name": driver[2],
                    "email": driver[3],
                    "license_number": driver[4],
                    "phone": driver[5]
                }
                for driver in drivers
            ]

    finally:
        conn.close()   


# Admin: View all faculty members
@router.get("/faculty")
def get_faculty(
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    f.faculty_id,
                    u.user_id,
                    u.name,
                    u.email,
                    f.employee_id,
                    f.department,
                    u.is_active
                FROM faculty f
                JOIN users u ON f.user_id = u.user_id
                WHERE u.role = 'FACULTY'
                ORDER BY f.faculty_id
            """)

            faculty_members = cursor.fetchall()

            return [
                {
                    "faculty_id": faculty[0],
                    "user_id": faculty[1],
                    "name": faculty[2],
                    "email": faculty[3],
                    "employee_id": faculty[4],
                    "department": faculty[5],
                    "is_active": faculty[6]
                }
                for faculty in faculty_members
            ]

    finally:
        conn.close()


# Admin: View all students
@router.get("/students")
def get_students(
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    s.student_id,
                    u.user_id,
                    u.name,
                    u.email,
                    s.enrollment_no,
                    s.department,
                    s.semester,
                    u.is_active
                FROM students s
                JOIN users u ON s.user_id = u.user_id
                WHERE u.role = 'STUDENT'
                ORDER BY s.student_id
            """)

            students = cursor.fetchall()

            return [
                {
                    "student_id": student[0],
                    "user_id": student[1],
                    "name": student[2],
                    "email": student[3],
                    "enrollment_no": student[4],
                    "department": student[5],
                    "semester": student[6],
                    "is_active": student[7]
                }
                for student in students
            ]

    finally:
        conn.close()



# Admin: Update bus details
@router.put("/buses/{bus_id}")
def update_bus(
    bus_id: int,
    bus: BusUpdate,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        update_fields = bus.model_dump(exclude_unset=True)

        if not update_fields:
            raise HTTPException(
                status_code=400,
                detail="No fields provided for update"
            )

        allowed_fields = {
            "bus_number",
            "bus_type",
            "capacity",
            "registration_number",
            "route_id"
        }

        invalid_fields = set(update_fields) - allowed_fields

        if invalid_fields:
            raise HTTPException(
                status_code=400,
                detail="Invalid fields provided"
            )

        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT bus_id, bus_type, route_id
                FROM buses
                WHERE bus_id = %s
                FOR UPDATE
            """, (bus_id,))

            existing_bus = cursor.fetchone()

            if not existing_bus:
                raise HTTPException(
                    status_code=404,
                    detail="Bus not found"
                )

            effective_type = update_fields.get("bus_type", existing_bus[1])
            effective_route = update_fields.get("route_id", existing_bus[2])

            validate_bus_route(cursor, effective_type, effective_route)

            set_clause = ", ".join(
                f"{field} = %s" for field in update_fields
            )
            values = list(update_fields.values()) + [bus_id]

            cursor.execute(
                f"""
                UPDATE buses
                SET {set_clause}
                WHERE bus_id = %s
                RETURNING bus_id, bus_number, bus_type,
                          capacity, registration_number, driver_id, route_id
                """,
                values
            )

            updated_bus = cursor.fetchone()
            conn.commit()

            return {
                "message": "Bus updated successfully",
                "bus_id": updated_bus[0],
                "bus_number": updated_bus[1],
                "bus_type": updated_bus[2],
                "capacity": updated_bus[3],
                "registration_number": updated_bus[4],
                "driver_id": updated_bus[5],
                "route_id": updated_bus[6]
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


# Admin: Delete a bus
@router.delete("/buses/{bus_id}")
def delete_bus(
    bus_id: int,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            # Check whether bus exists
            cursor.execute("""
                SELECT bus_id
                FROM buses
                WHERE bus_id = %s
            """, (bus_id,))

            bus = cursor.fetchone()

            if not bus:
                raise HTTPException(
                    status_code=404,
                    detail="Bus not found"
                )

            # Prevent deletion if trips are linked
            cursor.execute("""
                SELECT COUNT(*)
                FROM trips
                WHERE bus_id = %s
            """, (bus_id,))

            trip_count = cursor.fetchone()[0]

            if trip_count > 0:
                raise HTTPException(
                    status_code=409,
                    detail="Cannot delete bus because trips are linked to it"
                )

            # Delete bus
            cursor.execute("""
                DELETE FROM buses
                WHERE bus_id = %s
                RETURNING bus_id, bus_number
            """, (bus_id,))

            deleted_bus = cursor.fetchone()
            conn.commit()

            return {
                "message": "Bus deleted successfully",
                "bus_id": deleted_bus[0],
                "bus_number": deleted_bus[1]
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


# Admin: Upload bus photos
@router.post("/buses/{bus_id}/photos")
def upload_bus_photos(
    bus_id: int,
    front_photo: UploadFile | None = File(None),
    side_photo: UploadFile | None = File(None),
    current_user: dict = Depends(require_admin)
):
    upload_dir = Path("backend/uploads/buses")
    upload_dir.mkdir(parents=True, exist_ok=True)

    allowed_types = ["image/jpeg", "image/png", "image/webp"]

    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT bus_id FROM buses WHERE bus_id = %s",
                (bus_id,)
            )

            if not cursor.fetchone():
                raise HTTPException(
                    status_code=404,
                    detail="Bus not found"
                )

            photo_paths = {}

            for field, photo in [
                ("front_photo", front_photo),
                ("side_photo", side_photo)
            ]:
                if photo is None:
                    continue

                if photo.content_type not in allowed_types:
                    raise HTTPException(
                        status_code=400,
                        detail="Only JPG, PNG and WEBP images are allowed"
                    )

                extension = Path(photo.filename or "").suffix.lower()

                if extension not in [".jpg", ".jpeg", ".png", ".webp"]:
                    raise HTTPException(
                        status_code=400,
                        detail="Invalid image extension"
                    )

                filename = f"{bus_id}_{field}_{uuid.uuid4().hex}{extension}"
                file_path = upload_dir / filename

                with file_path.open("wb") as buffer:
                    shutil.copyfileobj(photo.file, buffer)

                photo_paths[field] = f"/uploads/buses/{filename}"

            if not photo_paths:
                raise HTTPException(
                    status_code=400,
                    detail="Please select at least one photo"
                )

            set_clause = ", ".join(
                f"{field} = %s" for field in photo_paths
            )

            cursor.execute(
                f"""
                UPDATE buses
                SET {set_clause}
                WHERE bus_id = %s
                """,
                list(photo_paths.values()) + [bus_id]
            )

            conn.commit()

            return {
                "message": "Bus photos uploaded successfully",
                "bus_id": bus_id,
                **photo_paths
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()

# Admin: Assign a driver to a bus
@router.put("/buses/{bus_id}/driver")
def assign_driver_to_bus(
    bus_id: int,
    assignment: BusAssignDriver,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            # Check whether bus exists
            cursor.execute("""
                SELECT bus_id
                FROM buses
                WHERE bus_id = %s
            """, (bus_id,))

            bus = cursor.fetchone()

            if not bus:
                from fastapi import HTTPException
                raise HTTPException(
                    status_code=404,
                    detail="Bus not found"
                )

            # Check whether driver exists
            cursor.execute("""
                SELECT driver_id
                FROM drivers
                WHERE driver_id = %s
            """, (assignment.driver_id,))

            driver = cursor.fetchone()

            if not driver:
                from fastapi import HTTPException
                raise HTTPException(
                    status_code=404,
                    detail="Driver not found"
                )

            # Assign driver to bus
            cursor.execute("""
                UPDATE buses
                SET driver_id = %s
                WHERE bus_id = %s
                RETURNING
                    bus_id,
                    bus_number,
                    bus_type,
                    capacity,
                    registration_number,
                    driver_id
            """, (
                assignment.driver_id,
                bus_id
            ))

            updated_bus = cursor.fetchone()
            conn.commit()

            return {
                "message": "Driver assigned to bus successfully",
                "bus_id": updated_bus[0],
                "bus_number": updated_bus[1],
                "bus_type": updated_bus[2],
                "capacity": updated_bus[3],
                "registration_number": updated_bus[4],
                "driver_id": updated_bus[5]
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()             

# Admin: Create a bus trip
@router.post("/trips")
def create_trip(
    bus_id: int,
    route_id: int,
    driver_id: int | None = None,
    status: str = "SCHEDULED",
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            # Check bus
            cursor.execute("""
                SELECT bus_id
                FROM buses
                WHERE bus_id = %s
            """, (bus_id,))

            bus = cursor.fetchone()

            if not bus:
                raise HTTPException(
                    status_code=404,
                    detail="Bus not found"
                )

            # Check route
            cursor.execute("""
                SELECT route_id
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

            # Create trip
            cursor.execute("""
                INSERT INTO trips
                    (bus_id, route_id, driver_id, trip_date, status)
                VALUES
                    (%s, %s, %s, CURRENT_DATE, %s)
                RETURNING
                    trip_id,
                    bus_id,
                    route_id,
                    driver_id,
                    trip_date,
                    status
            """, (
                bus_id,
                route_id,
                driver_id,
                status
            ))

            trip = cursor.fetchone()

            conn.commit()

            return {
                "message": "Trip created successfully",
                "trip_id": trip[0],
                "bus_id": trip[1],
                "route_id": trip[2],
                "driver_id": trip[3],
                "trip_date": str(trip[4]),
                "status": trip[5]
            }

    except HTTPException:
        conn.rollback()
        raise

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()        




# ============================================
# DRIVER APPROVAL SYSTEM
# ============================================


# Admin: View pending driver requests
@router.get("/driver-requests")
def get_driver_requests(
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    r.request_id,
                    r.user_id,
                    u.name,
                    u.email,
                    r.license_number,
                    r.phone,
                    r.status,
                    r.created_at
                FROM driver_registration_requests r
                JOIN users u ON r.user_id = u.user_id
                WHERE r.status = 'PENDING'
                ORDER BY r.created_at DESC
            """)

            requests = cursor.fetchall()

            return [
                {
                    "request_id": row[0],
                    "user_id": row[1],
                    "name": row[2],
                    "email": row[3],
                    "license_number": row[4],
                    "phone": row[5],
                    "status": row[6],
                    "created_at": row[7]
                }
                for row in requests
            ]

    finally:
        conn.close()


# Admin: Approve driver request
@router.put("/driver-requests/{request_id}/approve")
def approve_driver_request(
    request_id: int,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            # Lock request to prevent duplicate approval
            cursor.execute("""
                SELECT
                    r.user_id,
                    r.license_number,
                    r.phone,
                    r.status
                FROM driver_registration_requests r
                WHERE r.request_id = %s
                FOR UPDATE
            """, (request_id,))

            request = cursor.fetchone()

            if not request:
                raise HTTPException(
                    status_code=404,
                    detail="Driver request not found"
                )

            user_id, license_number, phone, status = request

            if status != "PENDING":
                raise HTTPException(
                    status_code=409,
                    detail=f"Request is already {status}"
                )

            # Check existing license number
            cursor.execute("""
                SELECT driver_id
                FROM drivers
                WHERE license_number = %s
            """, (license_number,))

            if cursor.fetchone():
                raise HTTPException(
                    status_code=409,
                    detail="This license number is already registered"
                )

            # Create driver profile
            cursor.execute("""
                INSERT INTO drivers
                    (user_id, license_number, phone)
                VALUES (%s, %s, %s)
                RETURNING driver_id
            """, (
                user_id,
                license_number,
                phone
            ))

            driver_id = cursor.fetchone()[0]

            # Activate driver account
            cursor.execute("""
                UPDATE users
                SET is_active = TRUE
                WHERE user_id = %s
            """, (user_id,))

            # Update approval request
            cursor.execute("""
                UPDATE driver_registration_requests
                SET
                    status = 'APPROVED',
                    reviewed_by = %s,
                    reviewed_at = CURRENT_TIMESTAMP
                WHERE request_id = %s
            """, (
                current_user["user_id"],
                request_id
            ))

            # Notify driver
            cursor.execute("""
                INSERT INTO notifications
                    (user_id, title, message, notification_type)
                VALUES (%s, %s, %s, %s)
            """, (
                user_id,
                "Driver Registration Approved",
                "Your driver registration has been approved. You can now login.",
                "DRIVER_APPROVED"
            ))

            conn.commit()

            return {
                "message": "Driver approved successfully",
                "request_id": request_id,
                "driver_id": driver_id,
                "user_id": user_id,
                "status": "APPROVED"
            }

    except HTTPException:
        conn.rollback()
        raise

    except Exception as e:
        conn.rollback()
        print("Driver approval error:", e)

        raise HTTPException(
            status_code=500,
            detail="Driver approval failed"
        )

    finally:
        conn.close()


# Admin: Reject driver request
@router.put("/driver-requests/{request_id}/reject")
def reject_driver_request(
    request_id: int,
    reason: str | None = None,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT user_id, status
                FROM driver_registration_requests
                WHERE request_id = %s
                FOR UPDATE
            """, (request_id,))

            request = cursor.fetchone()

            if not request:
                raise HTTPException(
                    status_code=404,
                    detail="Driver request not found"
                )

            user_id, status = request

            if status != "PENDING":
                raise HTTPException(
                    status_code=409,
                    detail=f"Request is already {status}"
                )

            # Update request status
            cursor.execute("""
                UPDATE driver_registration_requests
                SET
                    status = 'REJECTED',
                    reviewed_by = %s,
                    reviewed_at = CURRENT_TIMESTAMP,
                    rejection_reason = %s
                WHERE request_id = %s
            """, (
                current_user["user_id"],
                reason,
                request_id
            ))

            # Keep account inactive
            cursor.execute("""
                UPDATE users
                SET is_active = FALSE
                WHERE user_id = %s
            """, (user_id,))

            # Notify driver
            cursor.execute("""
                INSERT INTO notifications
                    (user_id, title, message, notification_type)
                VALUES (%s, %s, %s, %s)
            """, (
                user_id,
                "Driver Registration Rejected",
                reason or "Your driver registration request was rejected.",
                "DRIVER_REJECTED"
            ))

            conn.commit()

            return {
                "message": "Driver request rejected",
                "request_id": request_id,
                "user_id": user_id,
                "status": "REJECTED",
                "reason": reason
            }

    except HTTPException:
        conn.rollback()
        raise

    except Exception as e:
        conn.rollback()
        print("Driver rejection error:", e)

        raise HTTPException(
            status_code=500,
            detail="Driver rejection failed"
        )

    finally:
        conn.close()





# ============================================
# ADMIN: NOTIFICATIONS
# ============================================

# Get notifications for logged-in admin
@router.get("/notifications")
def get_admin_notifications(
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT
                    notification_id,
                    title,
                    message,
                    notification_type,
                    is_read,
                    created_at
                FROM notifications
                WHERE user_id = %s
                ORDER BY created_at DESC
                LIMIT 50
            """, (current_user["user_id"],))

            rows = cursor.fetchall()

            cursor.execute("""
                SELECT COUNT(*)
                FROM notifications
                WHERE user_id = %s AND is_read = FALSE
            """, (current_user["user_id"],))

            unread_count = cursor.fetchone()[0]

            notifications = [
                {
                    "notification_id": row[0],
                    "title": row[1],
                    "message": row[2],
                    "type": row[3],
                    "is_read": row[4],
                    "created_at": row[5]
                }
                for row in rows
            ]

            return {
                "unread_count": unread_count,
                "notifications": notifications
            }

    finally:
        conn.close()


# Mark one notification as read
@router.patch("/notifications/{notification_id}/read")
def mark_notification_read(
    notification_id: int,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE notifications
                SET is_read = TRUE
                WHERE notification_id = %s
                  AND user_id = %s
                RETURNING notification_id
            """, (
                notification_id,
                current_user["user_id"]
            ))

            result = cursor.fetchone()

            if not result:
                raise HTTPException(
                    status_code=404,
                    detail="Notification not found"
                )

            conn.commit()

            return {
                "message": "Notification marked as read",
                "notification_id": notification_id
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


# Mark all admin notifications as read
@router.patch("/notifications/read-all")
def mark_all_notifications_read(
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE notifications
                SET is_read = TRUE
                WHERE user_id = %s
                  AND is_read = FALSE
            """, (current_user["user_id"],))

            updated_count = cursor.rowcount
            conn.commit()

            return {
                "message": "All notifications marked as read",
                "updated_count": updated_count
            }

    except Exception:
        conn.rollback()
        raise

    finally:
        conn.close()


