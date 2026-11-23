from datetime import time
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from backend.app.dependencies import require_admin
from backend.app.database.connection import get_connection
from backend.app.services.notifications import create_notification_if_enabled

router = APIRouter(prefix="/schedules", tags=["Schedules"])


class ScheduleCreate(BaseModel):
    bus_id: int = Field(gt=0)
    route_id: int = Field(gt=0)
    departure_time: time
    arrival_time: time | None = None
    day_of_week: Literal[
        "WORKING_DAYS",
        "MONDAY",
        "TUESDAY",
        "WEDNESDAY",
        "THURSDAY",
        "FRIDAY",
        "SATURDAY",
        "SUNDAY"
    ] = "WORKING_DAYS"
    direction: Literal["OUTBOUND", "RETURN"]


@router.get("/")
def get_schedules(current_user: dict = Depends(require_admin)):
    conn = get_connection()

    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    s.schedule_id,
                    s.bus_id,
                    b.bus_number,
                    s.route_id,
                    r.route_name,
                    s.departure_time,
                    s.arrival_time,
                    s.day_of_week,
                    s.direction
                FROM schedules s
                LEFT JOIN buses b ON s.bus_id = b.bus_id
                LEFT JOIN routes r ON s.route_id = r.route_id
                ORDER BY s.bus_id, s.direction, s.departure_time
            """)
            rows = cur.fetchall()

            return [
                {
                    "schedule_id": row[0],
                    "bus_id": row[1],
                    "bus_number": row[2],
                    "route_id": row[3],
                    "route_name": row[4],
                    "departure_time": row[5],
                    "arrival_time": row[6],
                    "day_of_week": row[7],
                    "direction": row[8],
                }
                for row in rows
            ]
    finally:
        conn.close()


@router.post("/")
def create_schedule(
    schedule: ScheduleCreate,
    current_user: dict = Depends(require_admin),
):
    conn = get_connection()

    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT bus_id FROM buses WHERE bus_id = %s",
                (schedule.bus_id,),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Bus not found")

            cur.execute(
                "SELECT route_id FROM routes WHERE route_id = %s AND is_active = TRUE",
                (schedule.route_id,),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Active route not found")

            cur.execute("""
                SELECT schedule_id
                FROM schedules
                WHERE bus_id = %s
                  AND route_id = %s
                  AND day_of_week = %s
                  AND direction = %s
                  AND departure_time = %s
                LIMIT 1
            """, (
                schedule.bus_id,
                schedule.route_id,
                schedule.day_of_week,
                schedule.direction,
                schedule.departure_time,
            ))

            if cur.fetchone():
                raise HTTPException(
                    status_code=409,
                    detail="This schedule already exists",
                )

            cur.execute("""
                INSERT INTO schedules (
                    bus_id,
                    route_id,
                    departure_time,
                    arrival_time,
                    day_of_week,
                    direction
                )
                VALUES (%s, %s, %s, %s, %s, %s)
                RETURNING schedule_id
            """, (
                schedule.bus_id,
                schedule.route_id,
                schedule.departure_time,
                schedule.arrival_time,
                schedule.day_of_week,
                schedule.direction,
            ))

            schedule_id = cur.fetchone()[0]

            cur.execute("""
                SELECT DISTINCT s.user_id
                FROM subscriptions sub
                JOIN students s ON s.student_id = sub.student_id
                WHERE sub.route_id = %s AND sub.is_active = TRUE
            """, (schedule.route_id,))

            for recipient in cur.fetchall():
                create_notification_if_enabled(
                    cur, recipient[0],
                    "Timetable Updated",
                    f"A new bus schedule has been added for route {schedule.route_id}.",
                    preference_key="timetableReminders",
                    notification_type="TIMETABLE_UPDATED"
                )

            conn.commit()

            return {
                "message": "Schedule created successfully",
                "schedule_id": schedule_id,
            }

    except HTTPException:
        conn.rollback()
        raise
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@router.put("/{schedule_id}")
def update_schedule(
    schedule_id: int,
    schedule: ScheduleCreate,
    current_user: dict = Depends(require_admin),
):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT schedule_id, route_id FROM schedules WHERE schedule_id = %s FOR UPDATE",
                (schedule_id,),
            )
            existing_schedule = cur.fetchone()
            if not existing_schedule:
                raise HTTPException(status_code=404, detail="Schedule not found")
            old_route_id = existing_schedule[1]

            cur.execute("SELECT bus_id FROM buses WHERE bus_id = %s", (schedule.bus_id,))
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Bus not found")

            cur.execute(
                "SELECT route_id FROM routes WHERE route_id = %s AND is_active = TRUE",
                (schedule.route_id,),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Active route not found")

            cur.execute("""
                SELECT schedule_id FROM schedules
                WHERE bus_id = %s AND route_id = %s
                  AND day_of_week = %s AND direction = %s
                  AND departure_time = %s AND schedule_id != %s
                LIMIT 1
            """, (
                schedule.bus_id, schedule.route_id, schedule.day_of_week,
                schedule.direction, schedule.departure_time, schedule_id,
            ))
            if cur.fetchone():
                raise HTTPException(status_code=409, detail="This schedule already exists")

            cur.execute("""
                UPDATE schedules
                SET bus_id = %s, route_id = %s, departure_time = %s,
                    arrival_time = %s, day_of_week = %s, direction = %s
                WHERE schedule_id = %s
            """, (
                schedule.bus_id, schedule.route_id, schedule.departure_time,
                schedule.arrival_time, schedule.day_of_week,
                schedule.direction, schedule_id,
            ))
            affected_route_ids = list({old_route_id, schedule.route_id})
            cur.execute("""
                SELECT DISTINCT s.user_id
                FROM subscriptions sub
                JOIN students s ON s.student_id = sub.student_id
                WHERE sub.route_id = ANY(%s) AND sub.is_active = TRUE
            """, (affected_route_ids,))

            for recipient in cur.fetchall():
                create_notification_if_enabled(
                    cur, recipient[0],
                    "Timetable Updated",
                    "A bus timetable has been changed. Please check the latest schedule.",
                    preference_key="timetableReminders",
                    notification_type="TIMETABLE_UPDATED"
                )

            conn.commit()
            return {"message": "Schedule updated successfully"}
    except HTTPException:
        conn.rollback()
        raise
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


@router.delete("/{schedule_id}")
def delete_schedule(
    schedule_id: int,
    current_user: dict = Depends(require_admin),
):
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                "DELETE FROM schedules WHERE schedule_id = %s RETURNING schedule_id",
                (schedule_id,),
            )
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail="Schedule not found")

            conn.commit()
            return {"message": "Schedule deleted successfully"}
    except HTTPException:
        conn.rollback()
        raise
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
