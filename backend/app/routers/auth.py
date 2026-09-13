from fastapi import APIRouter, HTTPException
from backend.app.database.connection import get_connection
from backend.app.schemas.user import UserLogin
from backend.app.services.security import verify_password
from backend.app.services.auth import create_access_token

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