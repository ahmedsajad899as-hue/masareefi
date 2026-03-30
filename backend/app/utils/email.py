"""
Email utility — sends password reset codes via SMTP.
Uses Python's built-in smtplib in a thread executor (no extra dependencies).
If SMTP is not configured, silently skips sending — the endpoint returns the
code in the JSON response as a fallback (shown on screen).
"""
import asyncio
import logging
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from functools import partial

from app.config import settings

logger = logging.getLogger("masareefi.email")


def _build_reset_email(to_email: str, code: str) -> MIMEMultipart:
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "🔑 رمز إعادة تعيين كلمة المرور — مصاريفي"
    msg["From"] = settings.SMTP_FROM or settings.SMTP_USER or "noreply@masareefi.app"
    msg["To"] = to_email

    text_body = f"""\
مرحباً،

لقد طلبت إعادة تعيين كلمة المرور لحسابك في مصاريفي.

رمز التحقق الخاص بك:
  {code}

هذا الرمز صالح لمدة 15 دقيقة فقط.
إذا لم تطلب إعادة التعيين، يمكنك تجاهل هذه الرسالة.

— فريق مصاريفي
"""

    html_body = f"""\
<!DOCTYPE html>
<html dir="rtl" lang="ar">
<head><meta charset="UTF-8"></head>
<body style="font-family:Arial,sans-serif;background:#f4f4f4;margin:0;padding:20px;">
  <div style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.08);">
    <div style="background:linear-gradient(135deg,#667eea,#764ba2);padding:28px;text-align:center;">
      <h1 style="color:#fff;margin:0;font-size:22px;">🔑 إعادة تعيين كلمة المرور</h1>
    </div>
    <div style="padding:32px;text-align:center;">
      <p style="color:#555;font-size:15px;margin-bottom:24px;">
        لقد طلبت إعادة تعيين كلمة المرور لحسابك في <strong>مصاريفي</strong>.
      </p>
      <div style="display:inline-block;background:#f0f4ff;border:2px dashed #667eea;border-radius:12px;padding:16px 32px;margin-bottom:24px;">
        <div style="color:#999;font-size:12px;margin-bottom:8px;">رمز التحقق</div>
        <div style="font-size:36px;font-weight:700;letter-spacing:8px;color:#667eea;font-family:monospace;">{code}</div>
      </div>
      <p style="color:#999;font-size:13px;">صالح لمدة <strong>15 دقيقة</strong> فقط.</p>
      <hr style="border:none;border-top:1px solid #f0f0f0;margin:24px 0;">
      <p style="color:#ccc;font-size:12px;">إذا لم تطلب إعادة التعيين، تجاهل هذا البريد.</p>
    </div>
  </div>
</body>
</html>
"""

    msg.attach(MIMEText(text_body, "plain", "utf-8"))
    msg.attach(MIMEText(html_body, "html", "utf-8"))
    return msg


def _send_sync(to_email: str, code: str) -> None:
    """Blocking SMTP send — runs in a thread executor."""
    host = settings.SMTP_HOST
    port = settings.SMTP_PORT
    user = settings.SMTP_USER
    password = settings.SMTP_PASSWORD

    if not all([host, user, password]):
        logger.debug("SMTP not configured — skipping email send")
        return

    msg = _build_reset_email(to_email, code)

    if settings.SMTP_USE_TLS:
        # STARTTLS (port 587)
        with smtplib.SMTP(host, port, timeout=15) as smtp:
            smtp.ehlo()
            smtp.starttls(context=ssl.create_default_context())
            smtp.login(user, password)
            smtp.sendmail(user, to_email, msg.as_string())
    else:
        # SSL (port 465)
        ctx = ssl.create_default_context()
        with smtplib.SMTP_SSL(host, port, context=ctx, timeout=15) as smtp:
            smtp.login(user, password)
            smtp.sendmail(user, to_email, msg.as_string())

    logger.info("Reset email sent to %s", to_email)


async def send_reset_email(to_email: str, code: str) -> bool:
    """
    Send a password reset email asynchronously.
    Returns True if email was sent, False if SMTP is not configured or failed.
    """
    if not all([settings.SMTP_HOST, settings.SMTP_USER, settings.SMTP_PASSWORD]):
        return False
    try:
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, partial(_send_sync, to_email, code))
        return True
    except Exception as exc:
        logger.error("Failed to send reset email to %s: %s", to_email, exc)
        return False
