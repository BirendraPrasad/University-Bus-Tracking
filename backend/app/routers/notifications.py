from fastapi import APIRouter, Depends, HTTPException
from backend.app.dependencies import get_current_user
from backend.app.database.connection import get_connection

router = APIRouter(prefix="/notifications", tags=["Notifications"])

ALLOWED_ROLES = {"ADMIN", "DRIVER", "STUDENT", "FACULTY"}


@router.get("/")
def get_notifications(current_user: dict = Depends(get_current_user)):
    if current_user["role"] not in ALLOWED_ROLES:
        raise HTTPException(status_code=403, detail="Access denied")

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT notification_id, title, message,
                       notification_type, is_read, created_at
                FROM notifications
                WHERE user_id = %s
                ORDER BY created_at DESC
                LIMIT 50
            """, (current_user["user_id"],))
            rows = cursor.fetchall()

            cursor.execute("""
                SELECT COUNT(*) FROM notifications
                WHERE user_id = %s AND is_read = FALSE
            """, (current_user["user_id"],))
            unread_count = cursor.fetchone()[0]

            return {
                "unread_count": unread_count,
                "notifications": [
                    {
                        "notification_id": r[0],
                        "title": r[1],
                        "message": r[2],
                        "type": r[3],
                        "is_read": r[4],
                        "created_at": r[5].isoformat() if r[5] else None
                    }
                    for r in rows
                ]
            }
    finally:
        conn.close()


@router.patch("/{notification_id}/read")
def mark_notification_read(
    notification_id: int,
    current_user: dict = Depends(get_current_user)
):
    if current_user["role"] not in ALLOWED_ROLES:
        raise HTTPException(status_code=403, detail="Access denied")

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE notifications SET is_read = TRUE
                WHERE notification_id = %s AND user_id = %s
                RETURNING notification_id
            """, (notification_id, current_user["user_id"]))

            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="Notification not found")

            conn.commit()
            return {"message": "Notification marked as read"}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@router.patch("/read-all")
def mark_all_notifications_read(current_user: dict = Depends(get_current_user)):
    if current_user["role"] not in ALLOWED_ROLES:
        raise HTTPException(status_code=403, detail="Access denied")

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                UPDATE notifications SET is_read = TRUE
                WHERE user_id = %s AND is_read = FALSE
            """, (current_user["user_id"],))
            count = cursor.rowcount
            conn.commit()
            return {"message": "All notifications marked as read", "updated_count": count}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
