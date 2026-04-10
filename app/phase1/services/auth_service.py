"""
APEX Platform â€” Auth Service (Security Patched)
â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
- bcrypt password hashing (replaces SHA-256)
- JWT_SECRET from environment variable
- Failed login lockout
- All security events logged
"""

import secrets
import logging
from datetime import datetime, timedelta, timezone
from typing import Optional
import jwt
import hashlib
import os
import bcrypt as _bcrypt

from app.phase1.models.platform_models import (
    User, UserProfile, UserSession, PasswordReset,
    UserSecurityEvent, UserRole, Role, UserSubscription,
    SubscriptionEntitlement, Plan, PlanFeature,
    SecurityEventType, UserStatus, RoleCode, PlanCode,
    SessionLocal, gen_uuid, utcnow,
)

# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Config â€” from environment variables
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

JWT_SECRET = os.environ.get("JWT_SECRET", "apex-dev-secret-CHANGE-IN-PRODUCTION")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.environ.get("REFRESH_TOKEN_EXPIRE_DAYS", "30"))
MAX_FAILED_LOGINS = 5
LOCKOUT_MINUTES = 15


# ── Safe datetime helper (v6.5.1) ──────────────────────────
def safe_aware(dt):
    """Ensure a datetime is timezone-aware (UTC). Fixes naive vs aware comparison."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt
PASSWORD_MIN_LENGTH = 8

# Try bcrypt, fallback to hashlib
USE_BCRYPT = True


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Password Utilities â€” bcrypt with SHA-256 fallback
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

def hash_password(password: str) -> str:
    if USE_BCRYPT:
        return _bcrypt.hashpw(password.encode(), _bcrypt.gensalt()).decode()
    salt = secrets.token_hex(16)
    h = hashlib.sha256(f"{salt}{password}".encode()).hexdigest()
    return f"{salt}${h}"


def verify_password(password: str, password_hash: str) -> bool:
    try:
        if USE_BCRYPT and password_hash.startswith("$2"):
            return _bcrypt.checkpw(password.encode(), password_hash.encode())
        # Fallback: SHA-256 (for existing users before migration)
        salt, h = password_hash.split("$", 1)
        return hashlib.sha256(f"{salt}{password}".encode()).hexdigest() == h
    except (ValueError, AttributeError):
        return False


def validate_password_strength(password: str):
    if len(password) < PASSWORD_MIN_LENGTH:
        return False, f"ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظٹط¬ط¨ ط£ظ† طھظƒظˆظ† {PASSWORD_MIN_LENGTH} ط£ط­ط±ظپ ط¹ظ„ظ‰ ط§ظ„ط£ظ‚ظ„"
    has_upper = any(c.isupper() for c in password)
    has_lower = any(c.islower() for c in password)
    has_digit = any(c.isdigit() for c in password)
    if not (has_upper and has_lower and has_digit):
        return False, "ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ظٹط¬ط¨ ط£ظ† طھط­طھظˆظٹ ط¹ظ„ظ‰ ط­ط±ظپ ظƒط¨ظٹط± ظˆطµط؛ظٹط± ظˆط±ظ‚ظ…"
    return True, ""


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Token Utilities
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

def create_access_token(user_id: str, username: str, roles: list) -> str:
    payload = {
        "sub": user_id, "username": username, "roles": roles,
        "type": "access",
        "exp": datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def create_refresh_token(user_id: str) -> str:
    payload = {
        "sub": user_id, "type": "refresh",
        "exp": datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
        "iat": datetime.now(timezone.utc),
        "jti": gen_uuid(),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        return {"error": "ط§ظ†طھظ‡طھ طµظ„ط§ط­ظٹط© ط§ظ„ط±ظ…ط²"}
    except jwt.InvalidTokenError:
        return {"error": "ط±ظ…ط² ط؛ظٹط± طµط§ظ„ط­"}


# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
# Auth Service
# â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ

class AuthService:

    def register(self, username: str, email: str, password: str,
                 display_name: str, mobile: Optional[str] = None, ip_address: str = '') -> dict:
        valid, msg = validate_password_strength(password)
        if not valid:
            return {"success": False, "error": msg}

        db = SessionLocal()
        try:
            if db.query(User).filter((User.username == username.lower()) | (User.email == email.lower())).first():
                return {"success": False, "error": "ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ… ط£ظˆ ط§ظ„ط¨ط±ظٹط¯ ظ…ط³ط¬ظ„ ظ…ط³ط¨ظ‚ط§ظ‹"}

            user = User(
                id=gen_uuid(), username=username.lower().strip(),
                email=email.lower().strip(), mobile=mobile,
                display_name=display_name.strip(),
                password_hash=hash_password(password),
                status="active",
            )
            db.add(user)

            db.add(UserProfile(id=gen_uuid(), user_id=user.id))

            role = db.query(Role).filter(Role.code == RoleCode.registered_user.value).first()
            if role:
                db.add(UserRole(id=gen_uuid(), user_id=user.id, role_id=role.id))

            free_plan = db.query(Plan).filter(Plan.code == PlanCode.free.value).first()
            if free_plan:
                sub = UserSubscription(
                    id=gen_uuid(), user_id=user.id, plan_id=free_plan.id,
                    status="active", billing_cycle="monthly",
                )
                db.add(sub)
                features = db.query(PlanFeature).filter(PlanFeature.plan_id == free_plan.id).all()
                for f in features:
                    db.add(SubscriptionEntitlement(
                        id=gen_uuid(), user_id=user.id,
                        feature_code=f.feature_code, value=f.value,
                        value_type=f.value_type,
                    ))

            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user.id,
                event_type="registration",
                ip_address="", details={"method": "email"},
            ))

            db.commit()

            roles = [RoleCode.registered_user.value]
            
            # Phase 10: Welcome notification
            try:
                from app.phase10.services.notification_service import seed_welcome_notification
                seed_welcome_notification(user.id)
            except Exception:
                pass
            return {
                "success": True,
                "user": {
                    "id": user.id, "username": user.username,
                    "email": user.email, "display_name": user.display_name,
                    "status": user.status,
                    "plan": free_plan.code if free_plan else "free",
                    "roles": roles,
                },
                "tokens": {
                    "access_token": create_access_token(user.id, user.username, roles),
                    "refresh_token": create_refresh_token(user.id),
                },
            }
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def login(self, username_or_email: str, password: str, ip_address: str = "", user_agent: str = "") -> dict:
        db = SessionLocal()
        try:
            user = db.query(User).filter(
                (User.username == username_or_email.lower()) | (User.email == username_or_email.lower())
            ).first()

            if not user:
                return {"success": False, "error": "ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ… ط£ظˆ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± طµط­ظٹط­ط©"}

            if user.status == "suspended":
                return {"success": False, "error": "ط§ظ„ط­ط³ط§ط¨ ظ…ظˆظ‚ظˆظپ â€” طھظˆط§طµظ„ ظ…ط¹ ط§ظ„ط¯ط¹ظ…"}
            if user.status in ("deactivated_temp", "deactivated_permanent"):
                return {"success": False, "error": "ط§ظ„ط­ط³ط§ط¨ ظ…ط¹ط·ظ‘ظ„"}

            if user.failed_login_count >= MAX_FAILED_LOGINS:
                if user.locked_until and safe_aware(user.locked_until) > datetime.now(timezone.utc):
                    remaining = (safe_aware(user.locked_until) - datetime.now(timezone.utc)).seconds // 60
                    return {"success": False, "error": f"ط§ظ„ط­ط³ط§ط¨ ظ…ظ‚ظپظ„ â€” ط­ط§ظˆظ„ ط¨ط¹ط¯ {remaining} ط¯ظ‚ظٹظ‚ط©"}
                else:
                    user.failed_login_count = 0
                    user.locked_until = None

            if not verify_password(password, user.password_hash):
                user.failed_login_count += 1
                if user.failed_login_count >= MAX_FAILED_LOGINS:
                    user.locked_until = datetime.now(timezone.utc) + timedelta(minutes=LOCKOUT_MINUTES)
                db.add(UserSecurityEvent(
                    id=gen_uuid(), user_id=user.id,
                    event_type="failed_login",
                    ip_address=ip_address,
                ))
                db.commit()
                return {"success": False, "error": "ط§ط³ظ… ط§ظ„ظ…ط³طھط®ط¯ظ… ط£ظˆ ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط؛ظٹط± طµط­ظٹط­ط©"}

            user.failed_login_count = 0
            user.locked_until = None
            user.last_login_at = utcnow()

            session = UserSession(
                id=gen_uuid(), user_id=user.id, ip_address=ip_address,
                token_hash="pending",
                refresh_token_hash=None,
                device_info=user_agent,
                is_active=True,
                expires_at=datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
            )
            db.add(session)

            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user.id,
                event_type="login",
                ip_address=ip_address,
            ))

            user_roles = []
            for ur in db.query(UserRole).filter(UserRole.user_id == user.id).all():
                role = db.query(Role).filter(Role.id == ur.role_id).first()
                if role:
                    user_roles.append(role.code)

            access_tok = create_access_token(user.id, user.username, user_roles)
            refresh_tok = create_refresh_token(user.id)

            # Update session with token hashes
            session.token_hash = hashlib.sha256(access_tok.encode()).hexdigest()
            session.refresh_token_hash = hashlib.sha256(refresh_tok.encode()).hexdigest()

            db.commit()

            return {
                "success": True,
                "user": {
                    "id": user.id, "username": user.username,
                    "email": user.email, "display_name": user.display_name,
                    "status": user.status,
                    "plan": self._get_user_plan(db, user.id),
                    "roles": user_roles,
                },
                "tokens": {
                    "access_token": access_tok,
                    "refresh_token": refresh_tok,
                },
                "session_id": session.id,
            }
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def logout(self, user_id: str, token: str = "", session_id: str = "") -> dict:
        db = SessionLocal()
        try:
            sessions = db.query(UserSession).filter(
                UserSession.user_id == user_id, UserSession.is_active == True
            ).all()
            for s in sessions:
                s.is_active = False
                s.ended_at = utcnow()
            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user_id,
                event_type=SecurityEventType.logout.value,
            ))
            db.commit()
            return {"success": True, "message": "طھظ… طھط³ط¬ظٹظ„ ط§ظ„ط®ط±ظˆط¬"}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def change_password(self, user_id: str, current_password: str, new_password: str) -> dict:
        valid, msg = validate_password_strength(new_password)
        if not valid:
            return {"success": False, "error": msg}

        db = SessionLocal()
        try:
            user = db.query(User).filter(User.id == user_id).first()
            if not user:
                return {"success": False, "error": "ط§ظ„ظ…ط³طھط®ط¯ظ… ط؛ظٹط± ظ…ظˆط¬ظˆط¯"}
            if not verify_password(current_password, user.password_hash):
                return {"success": False, "error": "ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط± ط§ظ„ط­ط§ظ„ظٹط© ط؛ظٹط± طµط­ظٹط­ط©"}

            user.password_hash = hash_password(new_password)
            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user_id,
                event_type="password_change",
            ))
            db.commit()
            return {"success": True, "message": "طھظ… طھط؛ظٹظٹط± ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±"}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def forgot_password(self, email: str) -> dict:
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.email == email.lower()).first()
            if not user:
                return {"success": True, "message": "ط¥ط°ط§ ظƒط§ظ† ط§ظ„ط¨ط±ظٹط¯ ظ…ط³ط¬ظ„ط§ظ‹ ط³طھطµظ„ظƒ ط±ط³ط§ظ„ط©"}

            reset_token = secrets.token_urlsafe(32)
            db.add(PasswordReset(
                id=gen_uuid(), user_id=user.id, token=reset_token,
                expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
            ))
            db.commit()
            return {"success": True, "message": "ط¥ط°ط§ ظƒط§ظ† ط§ظ„ط¨ط±ظٹط¯ ظ…ط³ط¬ظ„ط§ظ‹ ط³طھطµظ„ظƒ ط±ط³ط§ظ„ط©", "reset_token": reset_token}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def reset_password(self, token: str, new_password: str) -> dict:
        valid, msg = validate_password_strength(new_password)
        if not valid:
            return {"success": False, "error": msg}

        db = SessionLocal()
        try:
            reset = db.query(PasswordReset).filter(
                PasswordReset.token == token, PasswordReset.is_used == False,
            ).first()
            if not reset:
                return {"success": False, "error": "ط±ظ…ط² ط¥ط¹ط§ط¯ط© ط§ظ„طھط¹ظٹظٹظ† ط؛ظٹط± طµط§ظ„ط­"}
            if safe_aware(reset.expires_at) < datetime.now(timezone.utc):
                return {"success": False, "error": "ط§ظ†طھظ‡طھ طµظ„ط§ط­ظٹط© ط§ظ„ط±ظ…ط²"}

            user = db.query(User).filter(User.id == reset.user_id).first()
            user.password_hash = hash_password(new_password)
            reset.is_used = True
            db.commit()
            return {"success": True, "message": "طھظ… ط¥ط¹ط§ط¯ط© طھط¹ظٹظٹظ† ظƒظ„ظ…ط© ط§ظ„ظ…ط±ظˆط±"}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def _get_user_plan(self, db, user_id: str) -> str:
        sub = db.query(UserSubscription).filter(
            UserSubscription.user_id == user_id, UserSubscription.status == "active"
        ).first()
        if sub:
            plan = db.query(Plan).filter(Plan.id == sub.plan_id).first()
            return plan.code if plan else "free"
        return "free"


    def get_active_sessions(self, user_id: str) -> dict:
        """Get active sessions for a user."""
        from app.phase1.models.platform_models import SessionLocal, UserSession
        db = SessionLocal()
        try:
            sessions = db.query(UserSession).filter_by(user_id=user_id, is_active=True).all()
            return {
                "sessions": [{
                    "id": s.id,
                    "ip_address": getattr(s, 'ip_address', ''),
                    "user_agent": getattr(s, 'user_agent', ''),
                    "created_at": str(s.created_at) if hasattr(s, 'created_at') else '',
                    "last_active": str(getattr(s, 'last_active', '')),
                } for s in sessions],
                "total": len(sessions)
            }
        except Exception:
            return {"sessions": [], "total": 0}
        finally:
            db.close()
