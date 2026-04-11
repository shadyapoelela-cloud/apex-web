"""
APEX Platform -- Email Service
Supports SMTP, SendGrid, and Console (dev) backends.
Config via environment variables.
"""

import os
import logging
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

logger = logging.getLogger(__name__)

# ── Configuration ─────────────────────────────────────────────

EMAIL_BACKEND = os.environ.get("EMAIL_BACKEND", "console")  # "smtp", "sendgrid", "console"

# SMTP settings
SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD", "")
SMTP_FROM = os.environ.get("SMTP_FROM", SMTP_USER)

# SendGrid settings
SENDGRID_API_KEY = os.environ.get("SENDGRID_API_KEY", "")
SENDGRID_FROM = os.environ.get("SENDGRID_FROM", "")

# Platform settings
PLATFORM_NAME = "APEX Financial Platform"
PLATFORM_URL = os.environ.get("PLATFORM_URL", "https://apex-app.com")


# ── Backend Implementations ───────────────────────────────────


def _send_via_console(to: str, subject: str, body_html: str, body_text: str = None) -> dict:
    """Development backend -- logs email to console."""
    logger.info(
        "EMAIL [console] To=%s Subject=%s\n--- TEXT ---\n%s\n--- HTML ---\n%s",
        to,
        subject,
        body_text or "(none)",
        body_html[:500],
    )
    return {"success": True, "backend": "console"}


def _send_via_smtp(to: str, subject: str, body_html: str, body_text: str = None) -> dict:
    """Send email via SMTP (e.g., Gmail, AWS SES, any SMTP server)."""
    if not SMTP_USER or not SMTP_PASSWORD:
        logger.error("SMTP credentials not configured (SMTP_USER / SMTP_PASSWORD)")
        return {"success": False, "error": "SMTP not configured"}

    msg = MIMEMultipart("alternative")
    msg["From"] = SMTP_FROM
    msg["To"] = to
    msg["Subject"] = subject

    if body_text:
        msg.attach(MIMEText(body_text, "plain", "utf-8"))
    msg.attach(MIMEText(body_html, "html", "utf-8"))

    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as server:
            server.ehlo()
            if SMTP_PORT != 25:
                server.starttls()
                server.ehlo()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.sendmail(SMTP_FROM, [to], msg.as_string())
        logger.info("EMAIL [smtp] sent to %s subject=%s", to, subject)
        return {"success": True, "backend": "smtp"}
    except smtplib.SMTPException as e:
        logger.error("SMTP send failed to=%s: %s", to, e)
        return {"success": False, "error": str(e)}
    except Exception as e:
        logger.error("SMTP unexpected error to=%s: %s", to, e)
        return {"success": False, "error": "SMTP send failed"}


def _send_via_sendgrid(to: str, subject: str, body_html: str, body_text: str = None) -> dict:
    """Send email via SendGrid HTTP API v3."""
    if not SENDGRID_API_KEY or not SENDGRID_FROM:
        logger.error("SendGrid not configured (SENDGRID_API_KEY / SENDGRID_FROM)")
        return {"success": False, "error": "SendGrid not configured"}

    try:
        import requests
    except ImportError:
        logger.error("requests library not installed -- needed for SendGrid backend")
        return {"success": False, "error": "requests library not available"}

    content = [{"type": "text/html", "value": body_html}]
    if body_text:
        content.insert(0, {"type": "text/plain", "value": body_text})

    payload = {
        "personalizations": [{"to": [{"email": to}]}],
        "from": {"email": SENDGRID_FROM, "name": PLATFORM_NAME},
        "subject": subject,
        "content": content,
    }

    try:
        resp = requests.post(
            "https://api.sendgrid.com/v3/mail/send",
            json=payload,
            headers={
                "Authorization": f"Bearer {SENDGRID_API_KEY}",
                "Content-Type": "application/json",
            },
            timeout=30,
        )
        if resp.status_code in (200, 201, 202):
            logger.info("EMAIL [sendgrid] sent to %s subject=%s", to, subject)
            return {"success": True, "backend": "sendgrid"}
        else:
            logger.error("SendGrid API error %s: %s", resp.status_code, resp.text[:300])
            return {"success": False, "error": f"SendGrid API {resp.status_code}"}
    except requests.RequestException as e:
        logger.error("SendGrid request failed to=%s: %s", to, e)
        return {"success": False, "error": str(e)}


# ── Public API ────────────────────────────────────────────────

_BACKENDS = {
    "console": _send_via_console,
    "smtp": _send_via_smtp,
    "sendgrid": _send_via_sendgrid,
}


def send_email(to: str, subject: str, body_html: str, body_text: str = None) -> dict:
    """
    Send an email using the configured backend.
    Returns {"success": True/False, ...}
    """
    backend_fn = _BACKENDS.get(EMAIL_BACKEND)
    if not backend_fn:
        logger.error("Unknown EMAIL_BACKEND=%s, falling back to console", EMAIL_BACKEND)
        backend_fn = _send_via_console

    try:
        return backend_fn(to, subject, body_html, body_text)
    except Exception as e:
        logger.error("Email send failed (backend=%s, to=%s): %s", EMAIL_BACKEND, to, e)
        return {"success": False, "error": "Email delivery failed"}


def send_verification_email(to: str, code: str) -> dict:
    """Send an account verification email with a code."""
    subject = f"{PLATFORM_NAME} - تأكيد البريد الإلكتروني"
    body_html = f"""
    <div dir="rtl" style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #1a73e8;">تأكيد البريد الإلكتروني</h2>
        <p>مرحباً،</p>
        <p>رمز التحقق الخاص بك هو:</p>
        <div style="background: #f5f5f5; padding: 20px; text-align: center;
                    font-size: 32px; font-weight: bold; letter-spacing: 8px;
                    border-radius: 8px; margin: 20px 0;">
            {code}
        </div>
        <p>هذا الرمز صالح لمدة 15 دقيقة.</p>
        <p style="color: #666; font-size: 12px;">
            إذا لم تطلب هذا الرمز، تجاهل هذه الرسالة.
        </p>
    </div>
    """
    body_text = f"رمز التحقق الخاص بك: {code}\nصالح لمدة 15 دقيقة."
    return send_email(to, subject, body_html, body_text)


def send_password_reset_email(to: str, token: str) -> dict:
    """Send a password reset email with a token/link."""
    reset_url = f"{PLATFORM_URL}/reset-password?token={token}"
    subject = f"{PLATFORM_NAME} - إعادة تعيين كلمة المرور"
    body_html = f"""
    <div dir="rtl" style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #1a73e8;">إعادة تعيين كلمة المرور</h2>
        <p>مرحباً،</p>
        <p>لقد طلبت إعادة تعيين كلمة المرور. اضغط على الزر أدناه:</p>
        <div style="text-align: center; margin: 30px 0;">
            <a href="{reset_url}"
               style="background: #1a73e8; color: white; padding: 14px 32px;
                      text-decoration: none; border-radius: 6px; font-size: 16px;">
                إعادة تعيين كلمة المرور
            </a>
        </div>
        <p>أو انسخ هذا الرابط:</p>
        <p style="word-break: break-all; color: #1a73e8;">{reset_url}</p>
        <p>هذا الرابط صالح لمدة ساعة واحدة.</p>
        <p style="color: #666; font-size: 12px;">
            إذا لم تطلب إعادة تعيين كلمة المرور، تجاهل هذه الرسالة.
        </p>
    </div>
    """
    body_text = f"إعادة تعيين كلمة المرور\n" f"اضغط على الرابط التالي: {reset_url}\n" f"صالح لمدة ساعة واحدة."
    return send_email(to, subject, body_html, body_text)


def send_notification_email(to: str, title: str, body: str) -> dict:
    """Send a general notification email."""
    subject = f"{PLATFORM_NAME} - {title}"
    body_html = f"""
    <div dir="rtl" style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #1a73e8;">{title}</h2>
        <div style="padding: 16px 0; line-height: 1.8;">
            {body}
        </div>
        <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;">
        <p style="color: #999; font-size: 12px; text-align: center;">
            {PLATFORM_NAME} &mdash;
            <a href="{PLATFORM_URL}" style="color: #1a73e8;">زيارة المنصة</a>
        </p>
    </div>
    """
    body_text = f"{title}\n\n{body}"
    return send_email(to, subject, body_html, body_text)
