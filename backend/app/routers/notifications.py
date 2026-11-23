import json
from fastapi import APIRouter, Depends, HTTPException, Body
from backend.app.dependencies import get_current_user
from backend.app.database.connection import get_connection

router = APIRouter(prefix="/notifications", tags=["Notifications"])

ALLOWED_ROLES = {"ADMIN", "DRIVER", "STUDENT", "FACULTY"}

DEFAULT_PREFERENCES = {
    "busArrival": True,
    "routeUpdates": True,
    "timetableReminders": False,
    "tripAlerts": True,
    "gpsAlerts": True,
    "systemAlerts": True,
    "showRecentNotifications": True,
    "compactTables": False
}


def check_user(user):
    if user.get("role") not in ALLOWED_ROLES:
        raise HTTPException(status_code=403, detail="Access denied")


@router.get("/")
def get_notifications(current_user: dict = Depends(get_current_user)):
    check_user(current_user)
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT notification_id, title, message,
                       notification_type, is_read, created_at
                FROM notifications
                WHERE user_id = %s
                ORDER BY created_at DESC LIMIT 50
            """, (current_user["user_id"],))
            rows = cursor.fetchall()

            cursor.execute("""
                SELECT COUNT(*) FROM notifications
                WHERE user_id = %s AND is_read = FALSE
            """, (current_user["user_id"],))
            unread = cursor.fetchone()[0]

            return {
                "unread_count": unread,
                "notifications": [{
                    "notification_id": r[0],
                    "title": r[1],
                    "message": r[2],
                    "type": r[3],
                    "is_read": r[4],
                    "created_at": r[5].isoformat() if r[5] else None
                } for r in rows]
            }
    finally:
        conn.close()


@router.get("/preferences")
def get_preferences(current_user: dict = Depends(get_current_user)):
    check_user(current_user)
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT preferences FROM user_notification_preferences
                WHERE user_id = %s
            """, (current_user["user_id"],))
            row = cursor.fetchone()
            saved = row[0] if row else {}
            if isinstance(saved, str):
                saved = json.loads(saved)
            return {"preferences": {**DEFAULT_PREFERENCES, **(saved or {})}}
    finally:
        conn.close()


@router.put("/preferences")
def save_preferences(
    preferences: dict = Body(...),
    current_user: dict = Depends(get_current_user)
):
    check_user(current_user)
    if not isinstance(preferences, dict) or any(
        key not in DEFAULT_PREFERENCES or not isinstance(value, bool)
        for key, value in preferences.items()
    ):
        raise HTTPException(status_code=422, detail="Invalid notification preferences")

    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO user_notification_preferences
                    (user_id, preferences, updated_at)
                VALUES (%s, %s::jsonb, CURRENT_TIMESTAMP)
                ON CONFLICT (user_id) DO UPDATE
                SET preferences = EXCLUDED.preferences,
                    updated_at = CURRENT_TIMESTAMP
                RETURNING preferences
            """, (current_user["user_id"], json.dumps(preferences)))
            saved = cursor.fetchone()[0]
            conn.commit()
            if isinstance(saved, str):
                saved = json.loads(saved)
            return {"message": "Preferences saved", "preferences": saved}
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@router.patch("/{notification_id}/read")
def mark_notification_read(
    notification_id: int,
    current_user: dict = Depends(get_current_user)
):
    check_user(current_user)
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
    check_user(current_user)
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
