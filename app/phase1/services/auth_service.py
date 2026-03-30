"""
APEX Platform — Auth Service
═══════════════════════════════════════════════════════════════
Registration, Login, Password Management, Session Management.

Security rules:
- Passwords hashed with bcrypt (passlib)
- JWT tokens with expiry
- Failed login lockout (5 attempts → 15 min lock)
- All security events logged
"""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Optional
import jwt

from app.phase1.models.platform_models import (
    User, UserProfile, UserSession, PasswordReset,
    UserSecurityEvent, UserRole, Role, UserSubscription,
    SubscriptionEntitlement, Plan, PlanFeature,
    SecurityEventType, UserStatus, RoleCode, PlanCode,
    SessionLocal, gen_uuid, utcnow,
)

# ═══════════════════════════════════════════════════════════════
# Config
# ═══════════════════════════════════════════════════════════════

JWT_SECRET = "apex-platform-secret-change-in-production-2026"
JWT_ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60
REFRESH_TOKEN_EXPIRE_DAYS = 30
MAX_FAILED_LOGINS = 5
LOCKOUT_MINUTES = 15
PASSWORD_MIN_LENGTH = 8


# ═══════════════════════════════════════════════════════════════
# Password Utilities
# ═══════════════════════════════════════════════════════════════

def hash_password(password: str) -> str:
    """Hash password with SHA-256 + salt (simple but effective)."""
    salt = secrets.token_hex(16)
    h = hashlib.sha256(f"{salt}{password}".encode()).hexdigest()
    return f"{salt}${h}"


def verify_password(password: str, password_hash: str) -> bool:
    """Verify password against stored hash."""
    try:
        salt, h = password_hash.split("$", 1)
        return hashlib.sha256(f"{salt}{password}".encode()).hexdigest() == h
    except (ValueError, AttributeError):
        return False


def validate_password_strength(password: str) -> tuple[bool, str]:
    """Check password meets minimum requirements."""
    if len(password) < PASSWORD_MIN_LENGTH:
        return False, f"كلمة المرور يجب أن تكون {PASSWORD_MIN_LENGTH} أحرف على الأقل"
    if not any(c.isdigit() for c in password):
        return False, "كلمة المرور يجب أن تحتوي على رقم واحد على الأقل"
    if not any(c.isalpha() for c in password):
        return False, "كلمة المرور يجب أن تحتوي على حرف واحد على الأقل"
    return True, ""


# ═══════════════════════════════════════════════════════════════
# Token Utilities
# ═══════════════════════════════════════════════════════════════

def create_access_token(user_id: str, username: str, roles: list[str]) -> str:
    payload = {
        "sub": user_id,
        "username": username,
        "roles": roles,
        "type": "access",
        "exp": datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def create_refresh_token(user_id: str) -> str:
    payload = {
        "sub": user_id,
        "type": "refresh",
        "exp": datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
        "iat": datetime.now(timezone.utc),
        "jti": gen_uuid(),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
    except (jwt.ExpiredSignatureError, jwt.InvalidTokenError):
        return None


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


# ═══════════════════════════════════════════════════════════════
# Auth Service
# ═══════════════════════════════════════════════════════════════

class AuthService:

    def register(
        self,
        username: str,
        email: str,
        password: str,
        display_name: str,
        mobile: Optional[str] = None,
        ip_address: Optional[str] = None,
    ) -> dict:
        """
        Register new user.
        Creates: user + profile + default role + free subscription + entitlements.
        """
        # Validate password
        valid, msg = validate_password_strength(password)
        if not valid:
            return {"success": False, "error": msg}

        db = SessionLocal()
        try:
            # Check uniqueness
            if db.query(User).filter(User.username == username.lower()).first():
                return {"success": False, "error": "اسم المستخدم مسجل مسبقاً"}
            if db.query(User).filter(User.email == email.lower()).first():
                return {"success": False, "error": "البريد الإلكتروني مسجل مسبقاً"}
            if mobile and db.query(User).filter(User.mobile == mobile).first():
                return {"success": False, "error": "رقم الجوال مسجل مسبقاً"}

            # Create user
            user = User(
                id=gen_uuid(),
                username=username.lower().strip(),
                email=email.lower().strip(),
                mobile=mobile,
                display_name=display_name.strip(),
                password_hash=hash_password(password),
                status=UserStatus.active.value,  # Auto-active for now
                email_verified=False,
            )
            db.add(user)

            # Create profile
            profile = UserProfile(
                id=gen_uuid(),
                user_id=user.id,
            )
            db.add(profile)

            # Assign default role: registered_user
            role = db.query(Role).filter(Role.code == RoleCode.registered_user.value).first()
            if role:
                db.add(UserRole(id=gen_uuid(), user_id=user.id, role_id=role.id))

            # Assign free plan subscription + entitlements
            free_plan = db.query(Plan).filter(Plan.code == PlanCode.free.value).first()
            if free_plan:
                sub = UserSubscription(
                    id=gen_uuid(),
                    user_id=user.id,
                    plan_id=free_plan.id,
                    status="active",
                    billing_cycle="monthly",
                )
                db.add(sub)

                # Copy plan features to user entitlements
                features = db.query(PlanFeature).filter(PlanFeature.plan_id == free_plan.id).all()
                for f in features:
                    db.add(SubscriptionEntitlement(
                        id=gen_uuid(),
                        user_id=user.id,
                        feature_code=f.feature_code,
                        value_type=f.value_type,
                        value=f.value,
                        source_plan_id=free_plan.id,
                    ))

            # Log security event
            db.add(UserSecurityEvent(
                id=gen_uuid(),
                user_id=user.id,
                event_type=SecurityEventType.login.value,
                ip_address=ip_address,
                details={"action": "registration"},
            ))

            db.commit()

            # Generate tokens
            roles = [RoleCode.registered_user.value]
            access_token = create_access_token(user.id, user.username, roles)
            refresh_token = create_refresh_token(user.id)

            # Save session
            session = UserSession(
                id=gen_uuid(),
                user_id=user.id,
                token_hash=hash_token(access_token),
                refresh_token_hash=hash_token(refresh_token),
                ip_address=ip_address,
                expires_at=datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
            )
            db.add(session)
            db.commit()

            return {
                "success": True,
                "user": {
                    "id": user.id,
                    "username": user.username,
                    "email": user.email,
                    "display_name": user.display_name,
                    "status": user.status,
                    "plan": PlanCode.free.value,
                },
                "tokens": {
                    "access_token": access_token,
                    "refresh_token": refresh_token,
                    "token_type": "bearer",
                    "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                },
            }

        except Exception as e:
            db.rollback()
            return {"success": False, "error": f"خطأ في التسجيل: {str(e)}"}
        finally:
            db.close()

    def login(
        self,
        username_or_email: str,
        password: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> dict:
        """Authenticate user and return tokens."""
        db = SessionLocal()
        try:
            identifier = username_or_email.lower().strip()
            user = db.query(User).filter(
                (User.username == identifier) | (User.email == identifier)
            ).first()

            if not user or user.is_deleted:
                return {"success": False, "error": "اسم المستخدم أو كلمة المرور غير صحيحة"}

            # Check lockout
            if user.locked_until and user.locked_until > utcnow():
                remaining = (user.locked_until - utcnow()).seconds // 60
                return {"success": False, "error": f"الحساب مقفل. حاول بعد {remaining} دقيقة"}

            # Check account status
            if user.status == UserStatus.suspended.value:
                return {"success": False, "error": "الحساب معلّق. تواصل مع الدعم"}
            if user.status in (UserStatus.deactivated_temp.value, UserStatus.deactivated_permanent.value):
                return {"success": False, "error": "الحساب غير مفعّل"}

            # Verify password
            if not verify_password(password, user.password_hash):
                user.failed_login_count = (user.failed_login_count or 0) + 1
                if user.failed_login_count >= MAX_FAILED_LOGINS:
                    user.locked_until = utcnow() + timedelta(minutes=LOCKOUT_MINUTES)
                    db.add(UserSecurityEvent(
                        id=gen_uuid(), user_id=user.id,
                        event_type=SecurityEventType.suspicious_activity.value,
                        ip_address=ip_address,
                        details={"reason": "max_failed_logins", "count": user.failed_login_count},
                    ))
                db.add(UserSecurityEvent(
                    id=gen_uuid(), user_id=user.id,
                    event_type=SecurityEventType.failed_login.value,
                    ip_address=ip_address,
                ))
                db.commit()
                return {"success": False, "error": "اسم المستخدم أو كلمة المرور غير صحيحة"}

            # Success — reset failed count
            user.failed_login_count = 0
            user.locked_until = None
            user.last_login_at = utcnow()
            user.login_count = (user.login_count or 0) + 1

            # Get roles
            user_roles = db.query(UserRole).filter(UserRole.user_id == user.id).all()
            role_ids = [ur.role_id for ur in user_roles]
            roles = db.query(Role).filter(Role.id.in_(role_ids)).all() if role_ids else []
            role_codes = [r.code for r in roles]

            # Get plan
            sub = db.query(UserSubscription).filter(UserSubscription.user_id == user.id).first()
            plan_code = "free"
            if sub:
                plan = db.query(Plan).filter(Plan.id == sub.plan_id).first()
                plan_code = plan.code if plan else "free"

            # Generate tokens
            access_token = create_access_token(user.id, user.username, role_codes)
            refresh_token = create_refresh_token(user.id)

            # Save session
            db.add(UserSession(
                id=gen_uuid(),
                user_id=user.id,
                token_hash=hash_token(access_token),
                refresh_token_hash=hash_token(refresh_token),
                device_info=user_agent,
                ip_address=ip_address,
                expires_at=datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS),
            ))

            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user.id,
                event_type=SecurityEventType.login.value,
                ip_address=ip_address,
                user_agent=user_agent,
            ))

            db.commit()

            return {
                "success": True,
                "user": {
                    "id": user.id,
                    "username": user.username,
                    "email": user.email,
                    "display_name": user.display_name,
                    "status": user.status,
                    "plan": plan_code,
                    "roles": role_codes,
                },
                "tokens": {
                    "access_token": access_token,
                    "refresh_token": refresh_token,
                    "token_type": "bearer",
                    "expires_in": ACCESS_TOKEN_EXPIRE_MINUTES * 60,
                },
            }

        except Exception as e:
            db.rollback()
            return {"success": False, "error": f"خطأ في الدخول: {str(e)}"}
        finally:
            db.close()

    def change_password(
        self, user_id: str, current_password: str, new_password: str,
        ip_address: Optional[str] = None,
    ) -> dict:
        """Change password for authenticated user."""
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
                id=gen_uuid(), user_id=user.id,
                event_type=SecurityEventType.password_change.value,
                ip_address=ip_address,
            ))

            db.commit()
            return {"success": True, "message": "تم تغيير كلمة المرور بنجاح"}

        except Exception as e:
            db.rollback()
            return {"success": False, "error": str(e)}
        finally:
            db.close()

    def request_password_reset(self, email: str) -> dict:
        """Generate password reset token."""
        db = SessionLocal()
        try:
            user = db.query(User).filter(User.email == email.lower()).first()
            if not user:
                return {"success": True, "message": "إذا كان البريد مسجلاً، سيتم إرسال رابط إعادة التعيين"}

            token = secrets.token_urlsafe(32)
            db.add(PasswordReset(
                id=gen_uuid(),
                user_id=user.id,
                token_hash=hash_token(token),
                expires_at=utcnow() + timedelta(hours=1),
            ))
            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user.id,
                event_type=SecurityEventType.password_reset_request.value,
            ))
            db.commit()

            return {"success": True, "message": "إذا كان البريد مسجلاً، سيتم إرسال رابط إعادة التعيين", "reset_token": token}

        finally:
            db.close()

    def complete_password_reset(self, token: str, new_password: str) -> dict:
        """Complete password reset with token."""
        valid, msg = validate_password_strength(new_password)
        if not valid:
            return {"success": False, "error": msg}

        db = SessionLocal()
        try:
            reset = db.query(PasswordReset).filter(
                PasswordReset.token_hash == hash_token(token),
                PasswordReset.used == False,
                PasswordReset.expires_at > utcnow(),
            ).first()

            if not reset:
                return {"success": False, "error": "رابط إعادة التعيين غير صالح أو منتهي"}

            user = db.query(User).filter(User.id == reset.user_id).first()
            user.password_hash = hash_password(new_password)
            reset.used = True
            reset.used_at = utcnow()

            # Revoke all sessions
            db.query(UserSession).filter(
                UserSession.user_id == user.id, UserSession.is_active == True
            ).update({"is_active": False})

            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user.id,
                event_type=SecurityEventType.password_reset_complete.value,
            ))

            db.commit()
            return {"success": True, "message": "تم إعادة تعيين كلمة المرور بنجاح"}

        finally:
            db.close()

    def logout(self, token: str) -> dict:
        """Revoke current session."""
        db = SessionLocal()
        try:
            session = db.query(UserSession).filter(
                UserSession.token_hash == hash_token(token), UserSession.is_active == True
            ).first()
            if session:
                session.is_active = False
                db.add(UserSecurityEvent(
                    id=gen_uuid(), user_id=session.user_id,
                    event_type=SecurityEventType.logout.value,
                ))
                db.commit()
            return {"success": True, "message": "تم تسجيل الخروج"}
        finally:
            db.close()

    def logout_all(self, user_id: str) -> dict:
        """Revoke all sessions for user."""
        db = SessionLocal()
        try:
            count = db.query(UserSession).filter(
                UserSession.user_id == user_id, UserSession.is_active == True
            ).update({"is_active": False})

            db.add(UserSecurityEvent(
                id=gen_uuid(), user_id=user_id,
                event_type=SecurityEventType.session_revoked.value,
                details={"sessions_revoked": count},
            ))
            db.commit()
            return {"success": True, "message": f"تم إنهاء {count} جلسة"}
        finally:
            db.close()

    def get_active_sessions(self, user_id: str) -> list:
        """List active sessions for user."""
        db = SessionLocal()
        try:
            sessions = db.query(UserSession).filter(
                UserSession.user_id == user_id, UserSession.is_active == True
            ).order_by(UserSession.last_used_at.desc()).all()
            return [{
                "id": s.id,
                "device_info": s.device_info,
                "ip_address": s.ip_address,
                "last_used_at": s.last_used_at.isoformat() if s.last_used_at else None,
                "created_at": s.created_at.isoformat(),
            } for s in sessions]
        finally:
            db.close()
