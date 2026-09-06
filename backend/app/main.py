from fastapi import FastAPI

app = FastAPI(title="University Bus Tracking API")


@app.get("/")
def home():
    return {
        "message": "University Bus Tracking API is running"
    }