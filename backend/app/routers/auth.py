
from fastapi import APIRouter, HTTPException

from backend.app.database.connection import get_connection
from backend.app.schemas.user import UserLogin, RegisterRequest
from backend.app.services.security import verify_password, hash_password
from backend.app.services.auth import create_access_token

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"]
)


# ============================================
# LOGIN
# ============================================

@router.post("/login")
def login(user: UserLogin):
    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT user_id, name, email, password_hash, role, is_active
                FROM users
                WHERE email = %s
            """, (user.email,))

            db_user = cursor.fetchone()

            if not db_user:
                raise HTTPException(
                    status_code=401,
                    detail="Invalid email or password"
                )

            if not verify_password(user.password, db_user[3]):
                raise HTTPException(
                    status_code=401,
                    detail="Invalid email or password"
                )

            # Driver approval verification
            if db_user[4] == "DRIVER":

                cursor.execute("""
                    SELECT status
                    FROM driver_registration_requests
                    WHERE user_id = %s
                """, (db_user[0],))

                driver_request = cursor.fetchone()

                if driver_request:

                    if driver_request[0] == "PENDING":
                        raise HTTPException(
                            status_code=403,
                            detail="Your driver account is waiting for admin approval"
                        )

                    if driver_request[0] == "REJECTED":
                        raise HTTPException(
                            status_code=403,
                            detail="Your driver registration has been rejected"
                        )

                else:
                    # Preserve Admin-created existing drivers
                    cursor.execute("""
                        SELECT driver_id
                        FROM drivers
                        WHERE user_id = %s
                    """, (db_user[0],))

                    existing_driver = cursor.fetchone()

                    if not existing_driver:
                        raise HTTPException(
                            status_code=403,
                            detail="Driver registration request not found"
                        )

            if not db_user[5]:
                raise HTTPException(
                    status_code=403,
                    detail="User account is inactive"
                )

            access_token = create_access_token(
                user_id=db_user[0],
                role=db_user[4]
            )

            # Notify all Admin accounts about successful login
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
                "User Login",
                f"{db_user[1]} ({db_user[4]}) successfully logged in.",
                "LOGIN"
            ))

            conn.commit()

            return {
                "message": "Login successful",
                "access_token": access_token,
                "token_type": "bearer",
                "user_id": db_user[0],
                "name": db_user[1],
                "email": db_user[2],
                "role": db_user[4]
            }

    except HTTPException:
        conn.rollback()
        raise

    finally:
        conn.close()


# ============================================
# REGISTER
# ============================================

@router.post("/register")
def register(user: RegisterRequest):

    # Public Admin registration blocked
    if user.role == "ADMIN":
        raise HTTPException(
            status_code=403,
            detail="ADMIN accounts cannot be created through public registration"
        )

    # Password validation
    if len(user.password) < 8:
        raise HTTPException(
            status_code=400,
            detail="Password must contain at least 8 characters"
        )

    # Student validation
    if user.role == "STUDENT":

        if not user.enrollment_no:
            raise HTTPException(
                status_code=400,
                detail="Enrollment number is required for students"
            )

        if not user.department:
            raise HTTPException(
                status_code=400,
                detail="Department is required for students"
            )

        if user.semester is None:
            raise HTTPException(
                status_code=400,
                detail="Semester is required for students"
            )

    # Faculty validation
    if user.role == "FACULTY":

        if not user.employee_id:
            raise HTTPException(
                status_code=400,
                detail="Employee ID is required for faculty"
            )

        if not user.department:
            raise HTTPException(
                status_code=400,
                detail="Department is required for faculty"
            )

    # Driver validation
    if user.role == "DRIVER":

        if not user.license_number:
            raise HTTPException(
                status_code=400,
                detail="License number is required for drivers"
            )

        if not user.phone:
            raise HTTPException(
                status_code=400,
                detail="Phone number is required for drivers"
            )

    conn = get_connection()

    try:

        with conn.cursor() as cursor:

            # Check duplicate email
            cursor.execute("""
                SELECT user_id
                FROM users
                WHERE email = %s
            """, (user.email,))

            if cursor.fetchone():
                raise HTTPException(
                    status_code=409,
                    detail="An account with this email already exists"
                )

            # Hash password
            password_hash = hash_password(user.password)

            # Create user
            # Driver account remains inactive until approval
            is_active = user.role != "DRIVER"

            cursor.execute("""
                INSERT INTO users
                    (name, email, password_hash, role, is_active)
                VALUES (%s, %s, %s, %s, %s)
                RETURNING user_id, name, email, role
            """, (
                user.name,
                user.email,
                password_hash,
                user.role,
                is_active
            ))

            created_user = cursor.fetchone()
            user_id = created_user[0]

            # Student record
            if user.role == "STUDENT":

                cursor.execute("""
                    INSERT INTO students
                        (user_id, enrollment_no, department, semester)
                    VALUES (%s, %s, %s, %s)
                    RETURNING student_id
                """, (
                    user_id,
                    user.enrollment_no,
                    user.department,
                    user.semester
                ))

                student_id = cursor.fetchone()[0]

            # Faculty record
            elif user.role == "FACULTY":

                cursor.execute("""
                    INSERT INTO faculty
                        (user_id, employee_id, department)
                    VALUES (%s, %s, %s)
                    RETURNING faculty_id
                """, (
                    user_id,
                    user.employee_id,
                    user.department
                ))

                faculty_id = cursor.fetchone()[0]

            # Driver registration request
            elif user.role == "DRIVER":

                cursor.execute("""
                    INSERT INTO driver_registration_requests
                        (user_id, license_number, phone, status)
                    VALUES (%s, %s, %s, 'PENDING')
                """, (
                    user_id,
                    user.license_number,
                    user.phone
                ))

                # Notify all Admin accounts
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
                    "New Driver Registration",
                    f"{user.name} has submitted a driver registration request.",
                    "DRIVER_REQUEST"
                ))

            conn.commit()

            # Registration response
            response = {
                "message": "Registration successful",
                "user_id": user_id,
                "name": created_user[1],
                "email": created_user[2],
                "role": created_user[3]
            }

            if user.role == "STUDENT":
                response["student_id"] = student_id

            elif user.role == "FACULTY":
                response["faculty_id"] = faculty_id

            elif user.role == "DRIVER":
                response["approval_status"] = "PENDING"
                response["message"] = (
                    "Registration submitted. Waiting for admin approval."
                )

            return response

    except HTTPException:
        conn.rollback()
        raise

    except Exception as e:

        conn.rollback()

        print("Registration error:", e)

        raise HTTPException(
            status_code=500,
            detail="Registration failed due to a server error"
        )

    finally:
        conn.close()
