from fastapi import APIRouter, HTTPException
from backend.app.database.connection import get_connection
from backend.app.schemas.user import UserLogin,RegisterRequest
from backend.app.services.security import verify_password
from backend.app.services.auth import create_access_token
from backend.app.schemas.user import UserLogin, RegisterRequest
from backend.app.services.security import verify_password, hash_password

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"]
)


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

            if not db_user[5]:
                raise HTTPException(
                    status_code=403,
                    detail="User account is inactive"
                )

            access_token = create_access_token(
                user_id=db_user[0],
                role=db_user[4]
            )

            return {
                "message": "Login successful",
                "access_token": access_token,
                "token_type": "bearer",
                "user_id": db_user[0],
                "name": db_user[1],
                "email": db_user[2],
                "role": db_user[4]
            }

    finally:
        conn.close()

# register 
# 
@router.post("/register")
def register(user: RegisterRequest):

    # -----------------------------------------
    # Validate role
    # -----------------------------------------

    if user.role in ["DRIVER", "ADMIN"]:
        raise HTTPException(
            status_code=403,
            detail=f"{user.role} accounts cannot be created through public registration"
        )

    # -----------------------------------------
    # Validate password
    # -----------------------------------------

    if len(user.password) < 8:
        raise HTTPException(
            status_code=400,
            detail="Password must contain at least 8 characters"
        )

    # -----------------------------------------
    # Student validation
    # -----------------------------------------

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

    # -----------------------------------------
    # Faculty validation
    # -----------------------------------------

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

    # -----------------------------------------
    # Database connection
    # -----------------------------------------

    conn = get_connection()

    try:

        with conn.cursor() as cursor:

            # -------------------------------------
            # Check duplicate email
            # -------------------------------------

            cursor.execute(
                """
                SELECT user_id
                FROM users
                WHERE email = %s
                """,
                (user.email,)
            )

            existing_user = cursor.fetchone()

            if existing_user:

                raise HTTPException(
                    status_code=409,
                    detail="An account with this email already exists"
                )

            # -------------------------------------
            # Hash password
            # -------------------------------------

            password_hash = hash_password(user.password)

            # -------------------------------------
            # Create user
            # -------------------------------------

            cursor.execute(
                """
                INSERT INTO users
                (
                    name,
                    email,
                    password_hash,
                    role
                )
                VALUES (%s, %s, %s, %s)
                RETURNING user_id, name, email, role
                """,
                (
                    user.name,
                    user.email,
                    password_hash,
                    user.role
                )
            )

            created_user = cursor.fetchone()

            user_id = created_user[0]

            # -------------------------------------
            # Student record
            # -------------------------------------

            if user.role == "STUDENT":

                cursor.execute(
                    """
                    INSERT INTO students
                    (
                        user_id,
                        enrollment_no,
                        department,
                        semester
                    )
                    VALUES (%s, %s, %s, %s)
                    RETURNING student_id
                    """,
                    (
                        user_id,
                        user.enrollment_no,
                        user.department,
                        user.semester
                    )
                )

                student = cursor.fetchone()

                student_id = student[0]

            # -------------------------------------
            # Faculty record
            # -------------------------------------

            elif user.role == "FACULTY":

                cursor.execute(
                    """
                    INSERT INTO faculty
                    (
                        user_id,
                        employee_id,
                        department
                    )
                    VALUES (%s, %s, %s)
                    RETURNING faculty_id
                    """,
                    (
                        user_id,
                        user.employee_id,
                        user.department
                    )
                )

                faculty = cursor.fetchone()

                faculty_id = faculty[0]

            # -------------------------------------
            # Commit
            # -------------------------------------

            conn.commit()

            # -------------------------------------
            # Response
            # -------------------------------------

            response = {
                "message": "Registration successful",
                "user_id": user_id,
                "name": created_user[1],
                "email": created_user[2],
                "role": created_user[3]
            }

            if user.role == "STUDENT":
                response["student_id"] = student_id

            if user.role == "FACULTY":
                response["faculty_id"] = faculty_id

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