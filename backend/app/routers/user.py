from fastapi import APIRouter, Depends, UploadFile, File, HTTPException

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
    StopCreate,
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
@router.post("/buses")
def create_bus(
    bus: BusCreate,
    current_user: dict = Depends(require_admin)
):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                INSERT INTO buses
                    (bus_number, bus_type, capacity, registration_number)
                VALUES
                    (%s, %s, %s, %s)
                RETURNING
                    bus_id,
                    bus_number,
                    bus_type,
                    capacity,
                    registration_number
            """, (
                bus.bus_number,
                bus.bus_type,
                bus.capacity,
                bus.registration_number
            ))

            new_bus = cursor.fetchone()
            conn.commit()

            return {
                "message": "Bus created successfully",
                "bus_id": new_bus[0],
                "bus_number": new_bus[1],
                "bus_type": new_bus[2],
                "capacity": new_bus[3],
                "registration_number": new_bus[4]
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
                    (route_id, stop_name, latitude, longitude, stop_order)
                VALUES
                    (%s, %s, %s, %s, %s)
                RETURNING
                    stop_id,
                    route_id,
                    stop_name,
                    latitude,
                    longitude,
                    stop_order
            """, (
                stop.route_id,
                stop.stop_name,
                stop.latitude,
                stop.longitude,
                stop.stop_order
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
                "stop_order": new_stop[5]
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
                    bus_id,
                    bus_number,
                    bus_type,
                    capacity,
                    registration_number,
                    driver_id
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
                    "driver_id": bus[5]
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
            "registration_number"
        }

        invalid_fields = set(update_fields) - allowed_fields

        if invalid_fields:
            raise HTTPException(
                status_code=400,
                detail="Invalid fields provided"
            )

        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT bus_id
                FROM buses
                WHERE bus_id = %s
            """, (bus_id,))

            if not cursor.fetchone():
                raise HTTPException(
                    status_code=404,
                    detail="Bus not found"
                )

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
                          capacity, registration_number, driver_id
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
                "driver_id": updated_bus[5]
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