import os
from pathlib import Path

import httpx
from dotenv import load_dotenv
from fastapi import APIRouter, Depends, HTTPException

from backend.app.dependencies import require_admin


BASE_DIR = Path(__file__).resolve().parents[3]
load_dotenv(BASE_DIR / ".env")

router = APIRouter(
    prefix="/api/superset",
    tags=["Superset Analytics"]
)


@router.post("/guest-token")
def create_guest_token(
    current_user: dict = Depends(require_admin)
):
    superset_url = os.getenv("SUPERSET_URL", "").rstrip("/")
    username = os.getenv("SUPERSET_USERNAME")
    password = os.getenv("SUPERSET_PASSWORD")
    dashboard_id = os.getenv("SUPERSET_EMBEDDED_DASHBOARD_ID")

    if not all([superset_url, username, password, dashboard_id]):
        raise HTTPException(
            status_code=500,
            detail="Superset configuration is incomplete"
        )

    try:
        with httpx.Client(
            timeout=20,
            headers={"Referer": superset_url + "/"}
        ) as client:

            # Authenticate service account
            login = client.post(
                f"{superset_url}/api/v1/security/login",
                json={
                    "username": username,
                    "password": password,
                    "provider": "db",
                    "refresh": True
                }
            )

            login.raise_for_status()
            access_token = login.json()["access_token"]

            headers = {
                "Authorization": f"Bearer {access_token}"
            }

            # Get CSRF token
            csrf_response = client.get(
                f"{superset_url}/api/v1/security/csrf_token/",
                headers=headers
            )

            csrf_response.raise_for_status()
            csrf_token = csrf_response.json()["result"]

            headers["X-CSRFToken"] = csrf_token

            # Generate Guest Token
            response = client.post(
                f"{superset_url}/api/v1/security/guest_token/",
                headers=headers,
                json={
                    "user": {
                        "username": f"university_admin_{current_user['user_id']}",
                        "first_name": "University",
                        "last_name": "Admin"
                    },
                    "resources": [
                        {
                            "type": "dashboard",
                            "id": dashboard_id
                        }
                    ],
                    "rls": []
                }
            )

            response.raise_for_status()
            token = response.json().get("token")

            if not token:
                raise HTTPException(
                    status_code=502,
                    detail="Superset did not return a Guest Token"
                )

            return {"token": token}

    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Superset request failed with status {exc.response.status_code}"
        )

    except httpx.RequestError:
        raise HTTPException(
            status_code=503,
            detail="Could not connect to Superset"
        )
