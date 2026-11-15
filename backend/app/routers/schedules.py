from datetime import time
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from backend.app.dependencies import require_admin
from backend.app.database.connection import get_connection

router = APIRouter(prefix="/schedules", tags=["Schedules"])


class ScheduleCreate(BaseModel):
    bus_id: int = Field(gt=0)
    route_id: int = Field(gt=0)
    departure_time: time
    arrival_time: time | None = None
    day_of_week: str = Field(default="WORKING_DAYS", max_length=20)
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
