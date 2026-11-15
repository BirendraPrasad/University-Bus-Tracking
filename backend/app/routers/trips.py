
from datetime import date
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from backend.app.dependencies import require_admin
from backend.app.database.connection import get_connection

router = APIRouter(prefix="/trips", tags=["Trips"])


class TripCreate(BaseModel):
    bus_id: int = Field(gt=0)
    route_id: int = Field(gt=0)
    driver_id: int = Field(gt=0)
    trip_date: date


# Admin: Get all trips
@router.get("/")
def get_trips(current_user: dict = Depends(require_admin)):
    conn = get_connection()

    try:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT
                    t.trip_id,
                    t.bus_id,
                    b.bus_number,
                    t.route_id,
                    r.route_name,
                    r.route_code,
                    t.driver_id,
                    u.name AS driver_name,
                    t.trip_date,
                    t.start_time,
                    t.end_time,
                    t.status
                FROM trips t
                LEFT JOIN buses b
                    ON t.bus_id = b.bus_id
                LEFT JOIN routes r
                    ON t.route_id = r.route_id
                LEFT JOIN drivers d
                    ON t.driver_id = d.driver_id
                LEFT JOIN users u
                    ON d.user_id = u.user_id
                ORDER BY t.trip_date DESC, t.trip_id DESC
            """)

            rows = cur.fetchall()

            return [
                {
                    "trip_id": row[0],
                    "bus_id": row[1],
                    "bus_number": row[2],
                    "route_id": row[3],
                    "route_name": row[4],
                    "route_code": row[5],
                    "driver_id": row[6],
                    "driver_name": row[7],
                    "trip_date": row[8],
                    "start_time": row[9],
                    "end_time": row[10],
                    "status": row[11]
                }
                for row in rows
            ]

    finally:
        conn.close()



@router.post("/")
def create_trip(
    trip: TripCreate,
    current_user: dict = Depends(require_admin),
):
    conn = get_connection()

    try:
        with conn.cursor() as cur:
            # Verify bus exists and is assigned to the selected driver.
            cur.execute(
                """
                SELECT bus_id, driver_id
                FROM buses
                WHERE bus_id = %s
                """,
                (trip.bus_id,),
            )
            bus = cur.fetchone()

            if not bus:
                raise HTTPException(status_code=404, detail="Bus not found")

            if bus[1] != trip.driver_id:
                raise HTTPException(
                    status_code=400,
                    detail="Selected driver is not assigned to this bus",
                )

            cur.execute(
                "SELECT route_id FROM routes WHERE route_id = %s AND is_active = TRUE",
                (trip.route_id,),
            )
            if not cur.fetchone():
                raise HTTPException(
                    status_code=404,
                    detail="Active route not found",
                )

            # Prevent another unfinished trip for this bus or driver.
            cur.execute(
                """
                SELECT trip_id
                FROM trips
                WHERE status IN ('SCHEDULED', 'ACTIVE')
                  AND (bus_id = %s OR driver_id = %s)
                LIMIT 1
                """,
                (trip.bus_id, trip.driver_id),
            )
            if cur.fetchone():
                raise HTTPException(
                    status_code=409,
                    detail="This bus or driver already has a scheduled/active trip",
                )

            cur.execute(
                """
                INSERT INTO trips (bus_id, route_id, driver_id, trip_date, status)
                VALUES (%s, %s, %s, %s, 'SCHEDULED')
                RETURNING trip_id, bus_id, route_id, driver_id, trip_date, status
                """,
                (
                    trip.bus_id,
                    trip.route_id,
                    trip.driver_id,
                    trip.trip_date,
                ),
            )

            row = cur.fetchone()
            conn.commit()

            return {
                "message": "Trip scheduled successfully",
                "trip_id": row[0],
                "bus_id": row[1],
                "route_id": row[2],
                "driver_id": row[3],
                "trip_date": row[4],
                "status": row[5],
            }

    except HTTPException:
        conn.rollback()
        raise
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()
