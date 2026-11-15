
from fastapi import APIRouter, Depends, HTTPException

from backend.app.dependencies import get_current_user
from backend.app.database.connection import get_connection


router = APIRouter(
    prefix="/faculty",
    tags=["Faculty"]
)


# ============================================
# FACULTY: VIEW OWN PROFILE
# ============================================

@router.get("/me")
def get_my_profile(
    current_user: dict = Depends(get_current_user)
):

    if current_user["role"] != "FACULTY":
        raise HTTPException(
            status_code=403,
            detail="Faculty access required"
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
                    f.faculty_id,
                    f.employee_id,
                    f.department
                FROM users u
                JOIN faculty f
                    ON u.user_id = f.user_id
                WHERE u.user_id = %s
            """, (current_user["user_id"],))

            faculty = cursor.fetchone()

            if not faculty:
                raise HTTPException(
                    status_code=404,
                    detail="Faculty profile not found"
                )

            return {
                "user_id": faculty[0],
                "name": faculty[1],
                "email": faculty[2],
                "role": faculty[3],
                "is_active": faculty[4],
                "faculty_id": faculty[5],
                "employee_id": faculty[6],
                "department": faculty[7]
            }

    finally:
        conn.close()
