from fastapi import APIRouter, Depends, HTTPException
from backend.app.dependencies import get_current_user
from backend.app.database.connection import get_connection

router = APIRouter(prefix="/faculty", tags=["Faculty"])


def require_faculty(current_user: dict = Depends(get_current_user)):
    if current_user.get("role") != "FACULTY":
        raise HTTPException(status_code=403, detail="Faculty access required")
    return current_user


def _iso(value):
    return value.isoformat() if value else None


@router.get("/me")
def get_my_profile(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT u.user_id, u.name, u.email, u.role, u.is_active,
                       f.faculty_id, f.employee_id, f.department
                FROM users u
                JOIN faculty f ON f.user_id = u.user_id
                WHERE u.user_id = %s
            """, (current_user["user_id"],))
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Faculty profile not found")
            return {
                "user_id": row[0], "name": row[1], "email": row[2],
                "role": row[3], "is_active": row[4], "faculty_id": row[5],
                "employee_id": row[6], "department": row[7]
            }
    finally:
        conn.close()


@router.get("/summary")
def get_faculty_summary(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) FROM routes WHERE is_active = TRUE")
            routes = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM stops s JOIN routes r ON r.route_id=s.route_id WHERE r.is_active=TRUE")
            stops = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM buses")
            buses = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM notifications WHERE user_id=%s AND is_read=FALSE", (current_user["user_id"],))
            unread = cursor.fetchone()[0]
            cursor.execute("SELECT COUNT(*) FROM trips WHERE status='ACTIVE'")
            active_trips = cursor.fetchone()[0]
            return {"route_count": routes, "stop_count": stops, "bus_count": buses,
                    "unread_notifications": unread, "active_trip_count": active_trips}
    finally:
        conn.close()


@router.get("/routes")
def get_faculty_routes(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT r.route_id, r.route_name, r.route_code, r.description,
                       r.start_point, r.end_point, r.is_active,
                       COUNT(DISTINCT b.bus_id) AS bus_count,
                       COUNT(DISTINCT s.stop_id) AS stop_count
                FROM routes r
                LEFT JOIN trips t ON t.route_id=r.route_id
                LEFT JOIN buses b ON b.bus_id=t.bus_id
                LEFT JOIN stops s ON s.route_id=r.route_id
                WHERE r.is_active=TRUE
                GROUP BY r.route_id
                ORDER BY r.route_name
            """)
            return [{"route_id": r[0], "route_name": r[1], "route_code": r[2],
                     "description": r[3], "start_point": r[4], "end_point": r[5],
                     "is_active": r[6], "bus_count": r[7], "stop_count": r[8]}
                    for r in cursor.fetchall()]
    finally:
        conn.close()


@router.get("/stops")
def get_faculty_stops(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT s.stop_id, s.stop_name, s.route_id, r.route_name,
                       s.stop_order, s.latitude, s.longitude
                FROM stops s JOIN routes r ON r.route_id=s.route_id
                WHERE r.is_active=TRUE
                ORDER BY r.route_name, s.stop_order
            """)
            return [{"stop_id": r[0], "stop_name": r[1], "route_id": r[2],
                     "route_name": r[3], "stop_order": r[4],
                     "latitude": float(r[5]), "longitude": float(r[6])}
                    for r in cursor.fetchall()]
    finally:
        conn.close()


@router.get("/trips")
def get_faculty_trips(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT t.trip_id, t.trip_date, t.start_time, t.end_time, t.status,
                       b.bus_number, r.route_name, u.name
                FROM trips t
                JOIN buses b ON b.bus_id=t.bus_id
                JOIN routes r ON r.route_id=t.route_id
                LEFT JOIN drivers d ON d.driver_id=t.driver_id
                LEFT JOIN users u ON u.user_id=d.user_id
                ORDER BY t.trip_date DESC, t.trip_id DESC
                LIMIT 100
            """)
            return [{"trip_id": r[0], "trip_date": str(r[1]) if r[1] else None,
                     "start_time": _iso(r[2]), "end_time": _iso(r[3]),
                     "status": r[4], "bus_number": r[5],
                     "route_name": r[6], "driver_name": r[7]}
                    for r in cursor.fetchall()]
    finally:
        conn.close()


@router.get("/live-buses")
def get_faculty_live_buses(current_user: dict = Depends(require_faculty)):
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                SELECT DISTINCT ON (t.bus_id)
                       t.trip_id, t.status, b.bus_id, b.bus_number,
                       r.route_name, u.name AS driver_name,
                       bl.latitude, bl.longitude, bl.speed, bl.recorded_at,
                       (bl.recorded_at >= NOW() - INTERVAL '2 minutes') AS gps_online
                FROM trips t
                JOIN buses b ON b.bus_id=t.bus_id
                JOIN routes r ON r.route_id=t.route_id
                LEFT JOIN drivers d ON d.driver_id=t.driver_id
                LEFT JOIN users u ON u.user_id=d.user_id
                LEFT JOIN bus_locations bl ON bl.trip_id=t.trip_id AND bl.bus_id=t.bus_id
                WHERE t.status='ACTIVE'
                ORDER BY t.bus_id, bl.recorded_at DESC NULLS LAST
            """)
            rows = cursor.fetchall()
            return [{"trip_id": r[0], "trip_status": r[1], "bus_id": r[2],
                     "bus_number": r[3], "route_name": r[4], "driver_name": r[5],
                     "latitude": float(r[6]) if r[6] is not None else None,
                     "longitude": float(r[7]) if r[7] is not None else None,
                     "speed": float(r[8]) if r[8] is not None else None,
                     "recorded_at": _iso(r[9]), "gps_online": bool(r[10]) if r[10] is not None else False}
                    for r in rows]
    finally:
        conn.close()

























===========================================================================================================

(BUS-Tracking) asus@birendra:/mnt/g/University-Bus-Tracking$ python kafka/gps_consumer.py

(BUS-Tracking) asus@birendra:/mnt/g/University-Bus-Tracking$ ~/kafka/bin/kafka-server-start.sh ~/kafka/config/server.properties

(BUS-Tracking) asus@birendra:/mnt/g/University-Bus-Tracking$ uvicorn backend.app.main:app --reload --host 0.0.0.0 --port 8000




===============================Terminal -1 ================ Frontend for android app ====================================

asus@birendra:~$ cd /mnt/g/University-Bus-Tracking
asus@birendra:/mnt/g/University-Bus-Tracking$ source BUS-Tracking/bin/activate
(BUS-Tracking) asus@birendra:/mnt/g/University-Bus-Tracking$ python -m http.server 5500 --directory frontend
Serving HTTP on 0.0.0.0 port 5500 (http://0.0.0.0:5500/) ...


============================================Terminal - 2 =====================For Backend Started ===============================

asus@birendra:~$ cd /mnt/g/University-Bus-Tracking
asus@birendra:/mnt/g/University-Bus-Tracking$ source BUS-Tracking/bin/activate
(BUS-Tracking) asus@birendra:/mnt/g/University-Bus-Tracking$ uvicorn backend.app.main:app --host 0.0.0.0 --port 8000 --reload


============================================Terminal - 3 =====================For Kafka  Started ===============================
asus@birendra:~$ cd /home/asus/kafka
asus@birendra:~/kafka$ bin/kafka-server-start.sh config/server.properties
asus@birendra:~/kafka$ nc -vz localhost 9092
asus@birendra:~/kafka$ grep '^log.dirs' /home/asus/kafka/config/server.properties
asus@birendra:~/kafka$ ls -lah /tmp/kraft-combined-logs
asus@birendra:~/kafka$ find /tmp/kraft-combined-logs -name meta.properties -print 2>/dev/null
asus@birendra:~/kafka$ [200~mkdir -p /home/asus/kafka-data~
asus@birendra:~/kafkamkdir -p /home/asus/kafka-datata
asus@birendra:~/kafka$ cp /home/asus/kafka/config/server.properties /home/asus/kafka/config/server.properties.backup
asus@birendra:~/kafka$ sed -i 's|^log.dirs=.*|log.dirs=/home/asus/kafka-data|' /home/asus/kafka/config/server.properties
asus@birendra:~/kafka$ grep '^log.dirs' /home/asus/kafka/config/server.properties
asus@birendra:~/kafka$ cd /home/asus/kafka
bin/kafka-storage.sh format --standalone -t sawO-kSaQb2Hz0Ms-beirw -c config/server.properties
asus@birendra:~/kafka$ bin/kafka-server-start.sh config/server.properties

........

==================================window Powershell================For Android studio connented =======================================

PS C:\Users\asus> & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
List of devices attached
00078346T001921 device

PS C:\Users\asus> & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000
8000
PS C:\Users\asus> & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" reverse --list
UsbFfs tcp:8000 tcp:8000

PS C:\Users\asus>









==============================super set ==========================
   Dashboard Embed UUID:-  (95ddec6d-af5a-4d19-ad3b-bc81ba7d236)


=============================== .env ==============

SUPERSET_URL=http://localhost:8088
SUPERSET_USERNAME=bus_tracking_embed
SUPERSET_PASSWORD=YOUR_SUPERSET_USER_PASSWORD


