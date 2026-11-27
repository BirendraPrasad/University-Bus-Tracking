import csv
import io

from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, Query
from backend.app.dependencies import require_admin
from backend.app.database.connection import get_connection
from backend.app.services.security import hash_password

router = APIRouter(prefix="/users", tags=["Bulk Import"])

MAX_FILE_SIZE = 5 * 1024 * 1024

FIELDS = {
    "students": ["name", "email", "password", "enrollment_no", "department", "semester"],
    "drivers": ["name", "email", "password", "license_number", "phone"],
    "faculty": ["name", "email", "password", "employee_id", "department"],
    "buses": ["bus_number", "bus_type", "capacity", "registration_number", "route_id"],
    "routes": ["route_name", "route_code", "description", "start_point", "end_point"],
    "stops": ["route_id", "stop_name", "latitude", "longitude", "stop_order",
              "pickup_time", "drop_time"],
}


def clean(value):
    return (value or "").strip()


async def read_csv(file):
    if not file.filename or not file.filename.lower().endswith(".csv"):
        raise HTTPException(400, "Please upload a CSV file.")

    content = await file.read(MAX_FILE_SIZE + 1)
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(413, "Maximum file size is 5 MB.")

    try:
        text = content.decode("utf-8-sig")
        reader = csv.DictReader(io.StringIO(text))
        if not reader.fieldnames:
            raise ValueError("CSV header is missing.")

        headers = [clean(h) for h in reader.fieldnames]
        rows = []
        for row in reader:
            rows.append({clean(k): clean(v) for k, v in row.items() if k})
        return headers, rows
    except (UnicodeDecodeError, csv.Error, ValueError) as exc:
        raise HTTPException(400, f"Invalid CSV: {exc}")


def validate_row(kind, row, cursor):
    required = [f for f in FIELDS[kind]
                if f not in ("route_id", "pickup_time", "drop_time", "department",
                             "phone", "description", "start_point", "end_point")]
    missing = [f for f in required if not clean(row.get(f))]
    if missing:
        return "Missing: " + ", ".join(missing)

    try:
        if kind in ("students", "drivers", "faculty"):
            email = clean(row.get("email")).lower()
            if "@" not in email or "." not in email.split("@")[-1]:
                return "Invalid email address."
            if len(row.get("password", "")) < 8:
                return "Password must contain at least 8 characters."

            cursor.execute("SELECT 1 FROM users WHERE LOWER(email)=LOWER(%s)", (email,))
            if cursor.fetchone():
                return "Email already exists."

            if kind == "students":
                int(row["semester"])
                cursor.execute("SELECT 1 FROM students WHERE enrollment_no=%s",
                               (row["enrollment_no"],))
                if cursor.fetchone():
                    return "Enrollment number already exists."

            elif kind == "drivers":
                cursor.execute("SELECT 1 FROM drivers WHERE license_number=%s",
                               (row["license_number"],))
                if cursor.fetchone():
                    return "License number already exists."

            else:
                cursor.execute("SELECT 1 FROM faculty WHERE employee_id=%s",
                               (row["employee_id"],))
                if cursor.fetchone():
                    return "Employee ID already exists."

        elif kind == "buses":
            if row["bus_type"] not in ("ROUTE_BUS", "SHUTTLE_BUS"):
                return "bus_type must be ROUTE_BUS or SHUTTLE_BUS."
            if int(row["capacity"]) <= 0:
                return "Capacity must be positive."
            cursor.execute(
                "SELECT 1 FROM buses WHERE bus_number=%s OR registration_number=%s",
                (row["bus_number"], row["registration_number"])
            )
            if cursor.fetchone():
                return "Bus number or registration number already exists."

            if row.get("route_id"):
                route_id = int(row["route_id"])
                cursor.execute("SELECT route_code,is_active FROM routes WHERE route_id=%s",
                               (route_id,))
                route = cursor.fetchone()
                if not route or not route[1]:
                    return "Route does not exist or is inactive."
                allowed = ({"R001", "R002", "R003", "R004", "R005", "R006"}
                           if row["bus_type"] == "ROUTE_BUS" else {"R007", "R008"})
                if route[0] not in allowed:
                    return "Route does not match bus type."

        elif kind == "routes":
            cursor.execute("SELECT 1 FROM routes WHERE route_code=%s",
                           (row["route_code"],))
            if cursor.fetchone():
                return "Route code already exists."

        elif kind == "stops":
            route_id = int(row["route_id"])
            lat, lon, order = float(row["latitude"]), float(row["longitude"]), int(row["stop_order"])
            if not -90 <= lat <= 90 or not -180 <= lon <= 180:
                return "Invalid latitude or longitude."
            if order < 1:
                return "stop_order must be at least 1."
            cursor.execute("SELECT 1 FROM routes WHERE route_id=%s", (route_id,))
            if not cursor.fetchone():
                return "Route does not exist."
            cursor.execute(
                "SELECT 1 FROM stops WHERE route_id=%s AND stop_order=%s",
                (route_id, order)
            )
            if cursor.fetchone():
                return "Stop order already exists for this route."

    except (ValueError, TypeError):
        return "Invalid number or field format."

    return None


def insert_row(kind, row, cursor):
    if kind in ("students", "drivers", "faculty"):
        role = kind[:-1].upper() if kind != "faculty" else "FACULTY"
        if kind == "students":
            role = "STUDENT"
        elif kind == "drivers":
            role = "DRIVER"

        cursor.execute("""
            INSERT INTO users (name,email,password_hash,role)
            VALUES (%s,%s,%s,%s) RETURNING user_id
        """, (row["name"], row["email"].lower(),
              hash_password(row["password"]), role))
        user_id = cursor.fetchone()[0]

        if kind == "students":
            cursor.execute("""
                INSERT INTO students (user_id,enrollment_no,department,semester)
                VALUES (%s,%s,%s,%s)
            """, (user_id, row["enrollment_no"], row.get("department") or None,
                  int(row["semester"])))
        elif kind == "drivers":
            cursor.execute("""
                INSERT INTO drivers (user_id,license_number,phone)
                VALUES (%s,%s,%s)
            """, (user_id, row["license_number"], row.get("phone") or None))
        else:
            cursor.execute("""
                INSERT INTO faculty (user_id,employee_id,department)
                VALUES (%s,%s,%s)
            """, (user_id, row["employee_id"], row.get("department") or None))

    elif kind == "buses":
        cursor.execute("""
            INSERT INTO buses (bus_number,bus_type,capacity,registration_number,route_id)
            VALUES (%s,%s,%s,%s,%s)
        """, (row["bus_number"], row["bus_type"], int(row["capacity"]),
              row["registration_number"], int(row["route_id"]) if row.get("route_id") else None))

    elif kind == "routes":
        cursor.execute("""
            INSERT INTO routes (route_name,route_code,description,start_point,end_point)
            VALUES (%s,%s,%s,%s,%s)
        """, (row["route_name"], row["route_code"], row.get("description") or "",
              row.get("start_point") or None, row.get("end_point") or None))

    elif kind == "stops":
        cursor.execute("""
            INSERT INTO stops (route_id,stop_name,latitude,longitude,stop_order,pickup_time,drop_time)
            VALUES (%s,%s,%s,%s,%s,%s,%s)
        """, (int(row["route_id"]), row["stop_name"], float(row["latitude"]),
              float(row["longitude"]), int(row["stop_order"]),
              row.get("pickup_time") or None, row.get("drop_time") or None))


@router.post("/bulk-import/{kind}")
async def bulk_import(
    kind: str,
    confirm: bool = Query(False),
    file: UploadFile = File(...),
    current_user: dict = Depends(require_admin)
):
    if kind not in FIELDS:
        raise HTTPException(400, "Unsupported import type.")

    headers, rows = await read_csv(file)
    missing_headers = [f for f in FIELDS[kind] if f not in headers]
    if missing_headers:
        raise HTTPException(400, "Missing CSV columns: " + ", ".join(missing_headers))

    if not rows:
        raise HTTPException(400, "CSV contains no data rows.")

    if len(rows) > 1000:
        raise HTTPException(400, "Maximum 1000 rows per import.")

    conn = get_connection()
    results = []
    seen = set()

    try:
        with conn.cursor() as cursor:
            for number, row in enumerate(rows, start=2):
                error = validate_row(kind, row, cursor)

                # Detect duplicates inside the uploaded file.
                key_field = {
                    "students": "email", "drivers": "email", "faculty": "email",
                    "buses": "bus_number", "routes": "route_code",
                    "stops": "stop_order"
                }[kind]
                key = clean(row.get(key_field)).lower()
                if kind == "stops":
                    key = f'{row.get("route_id")}:{key}'
                if key in seen:
                    error = f"Duplicate {key_field} inside CSV."
                seen.add(key)

                results.append({
                    "row": number,
                    "valid": error is None,
                    "error": error,
                    "data": {k: v for k, v in row.items() if k != "password"},
                    "_raw": row
                })

            valid_count = sum(1 for r in results if r["valid"])
            invalid_count = len(results) - valid_count

            if not confirm:
                conn.rollback()
                return {
                    "mode": "preview",
                    "total": len(rows),
                    "valid": valid_count,
                    "invalid": invalid_count,
                    "rows": [{k: v for k, v in r.items() if k != "_raw"} for r in results]
                }

            if invalid_count:
                conn.rollback()
                raise HTTPException(
                    400,
                    detail={"message": "Import cancelled. Fix invalid rows first.",
                            "valid": valid_count, "invalid": invalid_count,
                            "rows": [{k: v for k, v in r.items() if k != "_raw"} for r in results]}
                )

            # All rows are inserted atomically.
            for result in results:
                insert_row(kind, result["_raw"], cursor)

        conn.commit()
        return {
            "mode": "imported",
            "message": "Bulk import completed successfully.",
            "imported": valid_count
        }

    except HTTPException:
        conn.rollback()
        raise
    except Exception as exc:
        conn.rollback()
        raise HTTPException(400, f"Import failed; no rows were saved: {exc}")
    finally:
        conn.close()
