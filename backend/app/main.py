from fastapi import FastAPI
from backend.app.database.connection import get_connection
from backend.app.routers.user import router as user_router
from backend.app.routers.auth import router as auth_router

app = FastAPI(title="University Bus Tracking API")


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