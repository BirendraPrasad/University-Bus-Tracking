
import re
from datetime import timedelta

from fastapi import APIRouter, HTTPException

from backend.app.database.connection import get_connection
from backend.app.schemas.user import (
    UserLogin,
    RegisterRequest,
    EmailOTPVerify,
    EmailOTPResend,
    PasswordResetRequest,
    PasswordResetConfirm,
)
from backend.app.services.security import verify_password, hash_password
from backend.app.services.auth import create_access_token
from backend.app.services.email_service import (
    generate_email_otp,
    hash_email_otp,
    verify_email_otp_hash,
    send_email_otp,
)

router = APIRouter(
    prefix="/auth",
    tags=["Authentication"]
)


# ============================================
# PASSWORD VALIDATION
# ============================================

def validate_password(password: str):
    if len(password) < 8:
        raise HTTPException(
            status_code=400,
            detail="Password must contain at least 8 characters"
        )

    if not re.search(r"[A-Z]", password):
        raise HTTPException(
            status_code=400,
            detail="Password must contain an uppercase letter"
        )

    if not re.search(r"[a-z]", password):
        raise HTTPException(
            status_code=400,
            detail="Password must contain a lowercase letter"
        )

    if not re.search(r"\d", password):
        raise HTTPException(
            status_code=400,
            detail="Password must contain a number"
        )

    if not re.search(r"[^A-Za-z0-9]", password):
        raise HTTPException(
            status_code=400,
            detail="Password must contain a special character"
        )


# ============================================
# OTP HELPER
# ============================================

def save_otp(cursor, user_id: int, purpose: str, otp: str):
    cursor.execute("""
        INSERT INTO email_verification_otps
            (user_id, otp_hash, expires_at, attempts, purpose, created_at)
        VALUES (
            %s, %s,
            CURRENT_TIMESTAMP + INTERVAL '5 minutes',
            0, %s, CURRENT_TIMESTAMP
        )
        ON CONFLICT (user_id)
        DO UPDATE SET
            otp_hash = EXCLUDED.otp_hash,
            expires_at = EXCLUDED.expires_at,
            attempts = 0,
            purpose = EXCLUDED.purpose,
            created_at = CURRENT_TIMESTAMP
    """, (
        user_id,
        hash_email_otp(otp),
        purpose
    ))


def send_otp_safely(email: str, otp: str, purpose: str):
    try:
        send_email_otp(email, otp, purpose)
    except Exception as exc:
        print("OTP email sending failed:", str(exc))
        raise HTTPException(
            status_code=503,
            detail="Email could not be sent. Please try resending the OTP."
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
                SELECT user_id, name, email, password_hash,
                       role, is_active, email_verified
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

            # Email verification check
            if not db_user[6]:
                raise HTTPException(
                    status_code=403,
                    detail="Please verify your email before login"
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

            # Driver Route ID Verification
            if db_user[4] == "DRIVER":

                if user.route_id is None:
                    raise HTTPException(
                        status_code=400,
                        detail="Route ID is required for driver login"
                    )

                cursor.execute("""
                    SELECT b.route_id
                    FROM drivers d
                    JOIN buses b ON b.driver_id = d.driver_id
                    WHERE d.user_id = %s
                      AND b.route_id = %s
                    LIMIT 1
                """, (db_user[0], user.route_id))

                assigned_route = cursor.fetchone()

                if not assigned_route:
                    raise HTTPException(
                        status_code=403,
                        detail="Invalid Route ID or route is not assigned to this driver"
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

    validate_password(user.password)

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

            password_hash = hash_password(user.password)

            # All new accounts remain inactive until email verification.
            # Driver also requires Admin approval after email verification.
            cursor.execute("""
                INSERT INTO users
                    (name, email, password_hash, role,
                     is_active, email_verified)
                VALUES (%s, %s, %s, %s, FALSE, FALSE)
                RETURNING user_id, name, email, role
            """, (
                user.name,
                user.email,
                password_hash,
                user.role
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

            # Create registration OTP
            otp = generate_email_otp()
            save_otp(cursor, user_id, "REGISTER", otp)

            conn.commit()

        # Send OTP after database commit
        send_otp_safely(user.email, otp, "REGISTER")

        response = {
            "message": "Registration successful. Please verify your email using the OTP sent to your inbox.",
            "user_id": user_id,
            "name": created_user[1],
            "email": created_user[2],
            "role": created_user[3],
            "email_verification_required": True
        }

        if user.role == "STUDENT":
            response["student_id"] = student_id

        elif user.role == "FACULTY":
            response["faculty_id"] = faculty_id

        elif user.role == "DRIVER":
            response["approval_status"] = "PENDING"
            response["message"] = (
                "Registration submitted. Verify your email first. "
                "Admin approval is also required for driver login."
            )

        return response

    except HTTPException:
        conn.rollback()
        raise

    except Exception as exc:
        conn.rollback()
        print("Registration error:", str(exc))

        raise HTTPException(
            status_code=500,
            detail="Registration failed due to a server error"
        )

    finally:
        conn.close()


# ============================================
# VERIFY EMAIL OTP
# ============================================

@router.post("/verify-email")
def verify_email(data: EmailOTPVerify):

    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT
                    u.user_id,
                    u.role,
                    u.email_verified,
                    o.otp_hash,
                    o.expires_at,
                    o.attempts,
                    o.purpose
                FROM users u
                JOIN email_verification_otps o
                    ON o.user_id = u.user_id
                WHERE u.email = %s
                FOR UPDATE OF u, o
            """, (data.email,))

            record = cursor.fetchone()

            if not record:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid or expired OTP"
                )

            user_id, role, email_verified, otp_hash, expires_at, attempts, purpose = record

            if email_verified:
                raise HTTPException(
                    status_code=400,
                    detail="Email is already verified"
                )

            if purpose != "REGISTER":
                raise HTTPException(
                    status_code=400,
                    detail="Invalid registration OTP"
                )

            if attempts >= 5:
                raise HTTPException(
                    status_code=429,
                    detail="Too many incorrect attempts. Request a new OTP."
                )

            cursor.execute("""
                SELECT expires_at <= CURRENT_TIMESTAMP
                FROM email_verification_otps
                WHERE user_id = %s
            """, (user_id,))

            expired = cursor.fetchone()[0]

            if expired:
                raise HTTPException(
                    status_code=400,
                    detail="OTP has expired. Please request a new OTP."
                )

            if not verify_email_otp_hash(data.otp, otp_hash):
                cursor.execute("""
                    UPDATE email_verification_otps
                    SET attempts = attempts + 1
                    WHERE user_id = %s
                """, (user_id,))

                conn.commit()

                raise HTTPException(
                    status_code=400,
                    detail="Incorrect OTP"
                )

            # Verify email. Driver still waits for Admin approval.
            if role in ("STUDENT", "FACULTY"):
                cursor.execute("""
                    UPDATE users
                    SET email_verified = TRUE,
                        is_active = TRUE
                    WHERE user_id = %s
                """, (user_id,))
            else:
                cursor.execute("""
                    UPDATE users
                    SET email_verified = TRUE,
                        is_active = FALSE
                    WHERE user_id = %s
                """, (user_id,))

            cursor.execute("""
                DELETE FROM email_verification_otps
                WHERE user_id = %s
            """, (user_id,))

            conn.commit()

            if role == "DRIVER":
                return {
                    "message": "Email verified successfully. Your driver account is waiting for Admin approval.",
                    "email_verified": True,
                    "approval_status": "PENDING"
                }

            return {
                "message": "Email verified successfully. You can now login.",
                "email_verified": True
            }

    except HTTPException:
        if conn.info.transaction_status != 0:
            conn.rollback()
        raise

    except Exception as exc:
        conn.rollback()
        print("Email verification error:", str(exc))

        raise HTTPException(
            status_code=500,
            detail="Email verification failed"
        )

    finally:
        conn.close()


# ============================================
# RESEND REGISTRATION OTP
# ============================================

@router.post("/resend-otp")
def resend_otp(data: EmailOTPResend):

    conn = get_connection()
    otp = None

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT user_id, email_verified
                FROM users
                WHERE email = %s
            """, (data.email,))

            account = cursor.fetchone()

            if not account:
                raise HTTPException(
                    status_code=404,
                    detail="Account not found"
                )

            user_id, email_verified = account

            if email_verified:
                raise HTTPException(
                    status_code=400,
                    detail="Email is already verified"
                )

            cursor.execute("""
                SELECT created_at, purpose
                FROM email_verification_otps
                WHERE user_id = %s
                FOR UPDATE
            """, (user_id,))

            existing = cursor.fetchone()

            if existing and existing[1] == "REGISTER":
                cursor.execute("""
                    SELECT created_at > CURRENT_TIMESTAMP - INTERVAL '60 seconds'
                    FROM email_verification_otps
                    WHERE user_id = %s
                """, (user_id,))

                cooldown_active = cursor.fetchone()[0]

                if cooldown_active:
                    raise HTTPException(
                        status_code=429,
                        detail="Please wait 60 seconds before requesting another OTP"
                    )

            otp = generate_email_otp()
            save_otp(cursor, user_id, "REGISTER", otp)

            conn.commit()

        send_otp_safely(data.email, otp, "REGISTER")

        return {
            "message": "A new verification OTP has been sent to your email."
        }

    except HTTPException:
        conn.rollback()
        raise

    except Exception as exc:
        conn.rollback()
        print("Resend OTP error:", str(exc))

        raise HTTPException(
            status_code=500,
            detail="Could not resend OTP"
        )

    finally:
        conn.close()


# ============================================
# FORGOT PASSWORD - REQUEST OTP
# ============================================

@router.post("/forgot-password")
def forgot_password(data: PasswordResetRequest):

    conn = get_connection()
    otp = None
    should_send = False

    # Same response whether the email exists or not.
    generic_response = {
        "message": "If an account exists with this email, a password reset OTP will be sent."
    }

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT user_id
                FROM users
                WHERE email = %s
            """, (data.email,))

            account = cursor.fetchone()

            if account:
                user_id = account[0]

                cursor.execute("""
                    SELECT created_at
                    FROM email_verification_otps
                    WHERE user_id = %s
                    FOR UPDATE
                """, (user_id,))

                existing = cursor.fetchone()

                if existing:
                    cursor.execute("""
                        SELECT created_at > CURRENT_TIMESTAMP - INTERVAL '60 seconds'
                        FROM email_verification_otps
                        WHERE user_id = %s
                    """, (user_id,))

                    cooldown_active = cursor.fetchone()[0]

                    if cooldown_active:
                        conn.commit()
                        return generic_response

                otp = generate_email_otp()
                save_otp(cursor, user_id, "RESET", otp)
                should_send = True

            conn.commit()

        if should_send:
            try:
                send_email_otp(data.email, otp, "RESET")
            except Exception as exc:
                print("Password reset email failed:", str(exc))

        return generic_response

    except Exception as exc:
        conn.rollback()
        print("Forgot password error:", str(exc))

        return generic_response

    finally:
        conn.close()


# ============================================
# RESET PASSWORD - VERIFY OTP
# ============================================

@router.post("/reset-password")
def reset_password(data: PasswordResetConfirm):

    validate_password(data.new_password)

    conn = get_connection()

    try:
        with conn.cursor() as cursor:

            cursor.execute("""
                SELECT
                    u.user_id,
                    o.otp_hash,
                    o.expires_at,
                    o.attempts,
                    o.purpose
                FROM users u
                JOIN email_verification_otps o
                    ON o.user_id = u.user_id
                WHERE u.email = %s
                FOR UPDATE OF u, o
            """, (data.email,))

            record = cursor.fetchone()

            if not record:
                raise HTTPException(
                    status_code=400,
                    detail="Invalid or expired OTP"
                )

            user_id, otp_hash, expires_at, attempts, purpose = record

            if purpose != "RESET":
                raise HTTPException(
                    status_code=400,
                    detail="Invalid password reset OTP"
                )

            if attempts >= 5:
                raise HTTPException(
                    status_code=429,
                    detail="Too many incorrect attempts. Request a new OTP."
                )

            cursor.execute("""
                SELECT expires_at <= CURRENT_TIMESTAMP
                FROM email_verification_otps
                WHERE user_id = %s
            """, (user_id,))

            expired = cursor.fetchone()[0]

            if expired:
                raise HTTPException(
                    status_code=400,
                    detail="OTP has expired. Request a new one."
                )

            if not verify_email_otp_hash(data.otp, otp_hash):
                cursor.execute("""
                    UPDATE email_verification_otps
                    SET attempts = attempts + 1
                    WHERE user_id = %s
                """, (user_id,))

                conn.commit()

                raise HTTPException(
                    status_code=400,
                    detail="Incorrect OTP"
                )

            new_hash = hash_password(data.new_password)

            cursor.execute("""
                UPDATE users
                SET password_hash = %s
                WHERE user_id = %s
            """, (new_hash, user_id))

            cursor.execute("""
                DELETE FROM email_verification_otps
                WHERE user_id = %s
            """, (user_id,))

            conn.commit()

            return {
                "message": "Password reset successful. Please login with your new password."
            }

    except HTTPException:
        conn.rollback()
        raise

    except Exception as exc:
        conn.rollback()
        print("Password reset error:", str(exc))

        raise HTTPException(
            status_code=500,
            detail="Password reset failed"
        )

    finally:
        conn.close()
