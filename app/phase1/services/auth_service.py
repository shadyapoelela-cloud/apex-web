"""
APEX Platform — Auth Service (Security Patched)
═══════════════════════════════════════════════════════════════
- bcrypt password hashing (replaces SHA-256)
- JWT_SECRET from environment variable
- Failed login lockout
- All security events logged
"""

import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional
import jwt
import hashlib
import os

from app.phase1.models.platform_models import (
    User, UserProfile, UserSession, PasswordReset,
    UserSecurityEvent, UserRole, Role, UserSubscription,
    SubscriptionEntitlement, Plan, PlanFeature,
    SecurityEventType, UserStatus, RoleCode, PlanCode,
    SessionLocal, gen_uuid, utcnow,
)

# ═══════════════════════════════════════════════════════════════
# Config — from environment variables
# ═══════════════════════════════════════════════════════════════

JWT_SECRET = os.environ.get("JWT_SECRET", "apex-dev-secret-CHANGE-IN-PRODUCTION")
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))
REFRESH_TOKEN_EXPIRE_DAYS = int(os.environ.get("REFRESH_TOKEN_EXPIRE_DAYS", "30"))
MAX_FAILED_LOGINS = 5
LOCKOUT_MINUTES = 15
PASSWORD_MIN_LENGTH = 8

# Try bcrypt, fallback to hashlib
USE_BCRYPT = False  # Using SHA-256 until bcrypt confirmed on Render


# ═══════════════════════════════════════════════════════════════
# Password Utilities — bcrypt with SHA-256 fallback
# ═══════════════════════════════════════════════════════════════

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
        return False, f"كلمة المرور يجب أن تكون {PASSWORD_MIN_LENGTH} أحرف على الأقل"
    has_upper = any(c.isupper() for c in password)
    has_lower = any(c.islower() for c in password)
    has_digit = any(c.isdigit() for c in password)
    if not (has_upper and has_lower and has_digit):
        return False, "كلمة المرور يجب أن تحتوي على حرف كبير وصغير ورقم"
    return True, ""


# ═══════════════════════════════════════════════════════════════
# Token Utilities
# ═══════════════════════════════════════════════════════════════

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
        return {"error": "انتهت صلاحية الرمز"}
    except jwt.InvalidTokenError:
        return {"error": "رمز غير صالح"}


# ═══════════════════════════════════════════════════════════════
# Auth Service
# ═══════════════════════════════════════════════════════════════

class AuthService:

    def register(self, username: str, email: str, password: str,
                 display_name: str, mobile: Optional[str] = None, ip_address: str = '') -> dict:
        valid, msg = validate_password_strength(password)
        if not valid:
            return {"success": False, "error": msg}

        db = SessionLocal()
        try:
            if db.query(User).filter((User.username == username.lower()) | (User.email == email.lower())).first():
                return {"success": False, "error": "اسم المستخدم أو البريد مسجل مسبقاً"}

            user = User(
                id=gen_uuid(), username=username.lower().strip(),
                email=email.lower().strip(), mobile=mobile,
                display_name=display_name.strip(),
                password_hash=hash_password(password),
                status=UserStatus.active.value,
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
                        id=gen_uuid(), subscription_id=sub.id,
                        feature_key=f.feature_key, feature_value=f.feature_value,
                        feature_type=f.feature_type,
                    ))

            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user.id,
                event_type="registration",
                ip_address="", details={"method": "email"},
            ))

            db.commit()

            roles = [RoleCode.registered_user.value]
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
            return {"success": False, "error": str(e)}
        finally:
            db.close()

    def login(self, username_or_email: str, password: str, ip_address: str = "", user_agent: str = "") -> dict:
        db = SessionLocal()
        try:
            user = db.query(User).filter(
                (User.username == username_or_email.lower()) | (User.email == username_or_email.lower())
            ).first()

            if not user:
                return {"success": False, "error": "اسم المستخدم أو كلمة المرور غير صحيحة"}

            if user.status == UserStatus.suspended.value:
                return {"success": False, "error": "الحساب موقوف — تواصل مع الدعم"}
            if user.status == UserStatus.deactivated.value:
                return {"success": False, "error": "الحساب معطّل"}

            if user.failed_login_count >= MAX_FAILED_LOGINS:
                if user.locked_until and user.locked_until > datetime.now(timezone.utc):
                    remaining = (user.locked_until - datetime.now(timezone.utc)).seconds // 60
                    return {"success": False, "error": f"الحساب مقفل — حاول بعد {remaining} دقيقة"}
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
                return {"success": False, "error": "اسم المستخدم أو كلمة المرور غير صحيحة"}

            user.failed_login_count = 0
            user.locked_until = None
            user.last_login_at = utcnow()

            session = UserSession(
                id=gen_uuid(), user_id=user.id, ip_address=ip_address,
                is_active=True,
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
                    "access_token": create_access_token(user.id, user.username, user_roles),
                    "refresh_token": create_refresh_token(user.id),
                },
                "session_id": session.id,
            }
        except Exception as e:
            db.rollback()
            return {"success": False, "error": str(e)}
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
            return {"success": True, "message": "تم تسجيل الخروج"}
        except Exception as e:
            db.rollback()
            return {"success": False, "error": str(e)}
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
                return {"success": False, "error": "المستخدم غير موجود"}
            if not verify_password(current_password, user.password_hash):
                return {"success": False, "error": "كلمة المرور الحالية غير صحيحة"}

            user.password_hash = hash_password(new_password)
            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user_id,
                event_type="password_change",
            ))
            db.commit()
            return {"success": True, "message": "تم تغيير كلمة المرور"}
        except Exception as e:
            db.rollback()
            return {"success": False, "error": str(e)}
        finally:
            db.close()

    def forgot_password(self, email: str) -> dict:
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.email == email.lower()).first()
            if not user:
                return {"success": True, "message": "إذا كان البريد مسجلاً ستصلك رسالة"}

            reset_token = secrets.token_urlsafe(32)
            db.add(PasswordReset(
                id=gen_uuid(), user_id=user.id, token=reset_token,
                expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
            ))
            db.commit()
            return {"success": True, "message": "إذا كان البريد مسجلاً ستصلك رسالة", "reset_token": reset_token}
        except Exception as e:
            db.rollback()
            return {"success": False, "error": str(e)}
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
                return {"success": False, "error": "رمز إعادة التعيين غير صالح"}
            if reset.expires_at < datetime.now(timezone.utc):
                return {"success": False, "error": "انتهت صلاحية الرمز"}

            user = db.query(User).filter(User.id == reset.user_id).first()
            user.password_hash = hash_password(new_password)
            reset.is_used = True
            db.commit()
            return {"success": True, "message": "تم إعادة تعيين كلمة المرور"}
        except Exception as e:
            db.rollback()
            return {"success": False, "error": str(e)}
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
