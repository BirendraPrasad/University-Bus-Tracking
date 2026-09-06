from fastapi import FastAPI
from backend.app.database.connection import get_connection

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