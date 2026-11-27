
import os
import smtplib
import ssl
import secrets
import hashlib
import hmac

from pathlib import Path
from email.message import EmailMessage
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[3]
load_dotenv(BASE_DIR / ".env")


def generate_email_otp() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def hash_email_otp(otp: str) -> str:
    secret = os.getenv("EMAIL_OTP_SECRET")

    if not secret:
        raise RuntimeError("EMAIL_OTP_SECRET is missing")

    return hmac.new(
        secret.encode("utf-8"),
        otp.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()


def verify_email_otp_hash(otp: str, stored_hash: str) -> bool:
    return hmac.compare_digest(
        hash_email_otp(otp),
        stored_hash
    )


def send_email_otp(
    to_email: str,
    otp: str,
    purpose: str = "REGISTER"
) -> None:

    host = os.getenv("EMAIL_HOST", "smtp.gmail.com")
    port = int(os.getenv("EMAIL_PORT", "587"))
    username = os.getenv("EMAIL_USERNAME")
    password = os.getenv("EMAIL_APP_PASSWORD", "").replace(" ", "")
    sender = os.getenv("EMAIL_FROM") or username

    if not username or not password or not sender:
        raise RuntimeError("Gmail SMTP configuration is incomplete")

    if purpose == "RESET":
        subject = "University Bus Tracking - Password Reset OTP"
        heading = "Your password reset code is:"
        instruction = "Use this code to reset your password."
    else:
        subject = "University Bus Tracking - Email Verification"
        heading = "Your email verification code is:"
        instruction = "Use this code to verify your email address."

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = sender
    message["To"] = to_email

    message.set_content(f"""
Hello,

{heading}

{otp}

This OTP is valid for 5 minutes.

{instruction}

If you did not request this code, please ignore this email.

University Bus Tracking Team
""")

    context = ssl.create_default_context()

    with smtplib.SMTP(host, port, timeout=20) as server:
        server.ehlo()
        server.starttls(context=context)
        server.ehlo()
        server.login(username, password)
        server.send_message(message)
