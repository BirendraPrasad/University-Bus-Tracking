FACULTY DASHBOARD MERGED UPDATE
================================

This package updates the Faculty dashboard UI to use the Student dashboard visual system while preserving Faculty-only modules and APIs.

Files:
1. frontend/HTML code/faculty dashboard.html
2. frontend/CSS/faculty-dashboard.css
3. frontend/JavaScript/faculty-dashboard.js
4. backend/app/routers/faculty.py (Faculty APIs, including read-only buses and timetable endpoints)

Faculty modules included:
- Overview and faculty profile
- Bus routes and stop listing/search
- Read-only Bus Details directory using GET /faculty/buses
- Read-only Timetable using GET /faculty/timetable
- Live tracking using GET /faculty/live-buses
- Trip history using GET /faculty/trips
- Notifications, mark one read, mark all read
- Settings stored locally
- Responsive navigation and global search

Important:
- Bus Details and Timetable are included with new read-only Faculty endpoints based on the supplied database schema.
- The live map only plots records where gps_online is true and coordinates are valid. It intentionally does not plot stale/offline GPS points.
- No fake bus, timetable, notification, or GPS data is generated.

Install:
Extract this ZIP at the project root and allow replacement of the four listed files.
Then run:
  python -m py_compile backend/app/routers/faculty.py backend/app/main.py
  node --check frontend/JavaScript/faculty-dashboard.js
  git diff --check

Run the backend:
  uvicorn backend.app.main:app --reload

Open the existing Faculty HTML with Live Server:
  frontend/HTML code/faculty dashboard.html

The API base URL is read from frontend/JavaScript/api-config.js as window.API_BASE_URL.
Keep the existing api-config.js file unchanged.
