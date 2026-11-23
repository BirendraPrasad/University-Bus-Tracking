UNIVERSITY BUS TRACKING - FACULTY DASHBOARD UPDATE

Included replacement files (keep these paths exactly):
1. backend/app/routers/faculty.py
2. frontend/JavaScript/faculty-dashboard.js
3. frontend/CSS/faculty-dashboard.css

No database migration is required for these Faculty endpoints. They use the tables/columns in the supplied database/schema.sql:
users, faculty, routes, stops, buses, trips, drivers, bus_locations, notifications.

BACKUP BEFORE REPLACING (run from project root):
mkdir -p backup/faculty-before-update
cp backend/app/routers/faculty.py backup/faculty-before-update/
cp frontend/JavaScript/faculty-dashboard.js backup/faculty-before-update/
cp frontend/CSS/faculty-dashboard.css backup/faculty-before-update/

REPLACE:
Extract this ZIP into the project root and allow overwrite, preserving folder paths.

CHECK:
python -m py_compile backend/app/routers/faculty.py backend/app/main.py
node --check "frontend/JavaScript/faculty-dashboard.js"

RESTART BACKEND:
Stop the running Uvicorn process (Ctrl+C), then run your existing project command, for example:
uvicorn backend.app.main:app --reload

VERIFY:
Open http://127.0.0.1:8000/docs and confirm these routes exist:
GET /faculty/me
GET /faculty/summary
GET /faculty/routes
GET /faculty/stops
GET /faculty/trips
GET /faculty/live-buses

Then log in with a FACULTY account and open the Faculty dashboard through the frontend server (not file://).

NOTES:
- Faculty endpoints are read-only and require a FACULTY JWT role.
- Live bus markers are only shown for active trips with recorded GPS coordinates.
- GPS is reported online only when the last location was recorded within 2 minutes.
- If there are no active trips or no GPS records, the map correctly shows no live locations; it does not generate fake buses.
- Existing Student and Driver files are intentionally not changed.
