from backend.app.routers import notifications
from fastapi import FastAPI
from backend.app.database.connection import get_connection
from backend.app.routers.user import router as user_router
from backend.app.routers.auth import router as auth_router
from backend.app.routers.student import router as student_router
from backend.app.routers.driver import router as driver_router
from backend.app.routers.faculty import router as faculty_router
from fastapi.middleware.cors import CORSMiddleware
from backend.app.routers import trips
from backend.app.routers import schedules
from fastapi.staticfiles import StaticFiles
from pathlib import Path

app = FastAPI(title="University Bus Tracking API")

# Bus Photo Storage
UPLOAD_DIR = Path("backend/uploads/buses")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)

app.mount(
    "/uploads",
    StaticFiles(directory="backend/uploads"),
    name="uploads"
)

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:5500",
        "http://localhost:5500",
        "http://172.21.102.212:5500",
        "http://10.11.97.212:5500",
        "https://appassets.androidplatform.net"
    ],
    allow_origin_regex=r"^http://(10\.\d{1,3}\.\d{1,3}\.\d{1,3}|172\.(1[6-9]|2[0-9]|3[01])\.\d{1,3}\.\d{1,3}):5500$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def home():
    return {
        "message": "University Bus Tracking API is running"
    }


@app.get("/db-test")
def database_test():
    try:
        conn = get_connection()
        conn.close()

        return {
            "message": "Database connection successful!"
        }

    except Exception as e:
        return {
            "message": "Database connection failed!",
            "error": str(e)
        }


app.include_router(user_router)
app.include_router(auth_router)
app.include_router(student_router)
app.include_router(driver_router)
app.include_router(trips.router)
app.include_router(schedules.router)
app.include_router(faculty_router)

app.include_router(notifications.router)

