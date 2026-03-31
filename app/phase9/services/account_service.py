"""
APEX Phase 9 — Account Center Services
Handles: forgot-password, reset-password, sessions, profile update, closure
"""
import secrets, hashlib
from datetime import datetime, timedelta
from app.phase1.models.platform_models import SessionLocal, User, gen_uuid, utcnow
from app.phase9.models.phase9_models import PasswordReset, UserSession, AccountAction

# ─── Password Reset ──────────────────────────────────────
def create_password_reset(email: str):
    """Generate a reset token for the given email."""
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            # Don't reveal whether email exists
            return {"status": "ok", "message": "إذا كان البريد مسجلاً، سيتم إرسال رابط إعادة التعيين"}

        # Generate secure token
        token = secrets.token_urlsafe(48)
        reset = PasswordReset(
            id=gen_uuid(),
            user_id=user.id,
            email=email,
            reset_token=token,
            expires_at=datetime.utcnow() + timedelta(hours=1),
        )
        db.add(reset)

        # Log action
        action = AccountAction(
            id=gen_uuid(), user_id=user.id,
            action_type="password_reset_requested",
            action_details=f"Reset requested for {email}",
        )
        db.add(action)
        db.commit()

        return {
            "status": "ok",
            "message": "إذا كان البريد مسجلاً، سيتم إرسال رابط إعادة التعيين",
            "reset_token": token,  # In production: send via email, don't return
            "expires_in_minutes": 60,
        }
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

def execute_password_reset(token: str, new_password: str):
    """Reset password using a valid token."""
    db = SessionLocal()
    try:
        reset = db.query(PasswordReset).filter(
            PasswordReset.reset_token == token,
            PasswordReset.is_used == False,
        ).first()

        if not reset:
            return {"status": "error", "detail": "رمز إعادة التعيين غير صالح"}

        if datetime.utcnow() > reset.expires_at:
            return {"status": "error", "detail": "انتهت صلاحية رمز إعادة التعيين"}

        # Update password
        user = db.query(User).filter(User.id == reset.user_id).first()
        if not user:
            return {"status": "error", "detail": "المستخدم غير موجود"}

        user.password_hash = hashlib.sha256(new_password.encode()).hexdigest()

        # Mark token as used
        reset.is_used = True
        reset.used_at = datetime.utcnow()

        # Log action
        action = AccountAction(
            id=gen_uuid(), user_id=user.id,
            action_type="password_reset_completed",
            action_details="Password reset via token",
        )
        db.add(action)
        db.commit()

        return {"status": "ok", "message": "تم تغيير كلمة المرور بنجاح"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

# ─── Sessions ─────────────────────────────────────────────
def create_session(user_id: str, device_info: str = None, ip_address: str = None):
    """Create a new session record on login."""
    db = SessionLocal()
    try:
        token = secrets.token_urlsafe(32)
        session = UserSession(
            id=gen_uuid(), user_id=user_id,
            session_token=token,
            device_info=device_info or "unknown",
            ip_address=ip_address or "unknown",
        )
        db.add(session)
        db.commit()
        return {"session_id": session.id, "session_token": token}
    except Exception as e:
        db.rollback()
        return None
    finally:
        db.close()

def get_user_sessions(user_id: str):
    """Get all active sessions for a user."""
    db = SessionLocal()
    try:
        sessions = db.query(UserSession).filter(
            UserSession.user_id == user_id,
            UserSession.is_active == True,
        ).order_by(UserSession.last_activity.desc()).all()

        return [{
            "id": s.id,
            "device_info": s.device_info,
            "ip_address": s.ip_address,
            "last_activity": str(s.last_activity) if s.last_activity else None,
            "created_at": str(s.created_at) if s.created_at else None,
        } for s in sessions]
    finally:
        db.close()

def logout_all_sessions(user_id: str, except_current: str = None):
    """Terminate all active sessions for a user."""
    db = SessionLocal()
    try:
        query = db.query(UserSession).filter(
            UserSession.user_id == user_id,
            UserSession.is_active == True,
        )
        if except_current:
            query = query.filter(UserSession.id != except_current)

        count = 0
        for s in query.all():
            s.is_active = False
            s.ended_at = datetime.utcnow()
            count += 1

        action = AccountAction(
            id=gen_uuid(), user_id=user_id,
            action_type="logout_all_sessions",
            action_details=f"Terminated {count} sessions",
        )
        db.add(action)
        db.commit()
        return {"status": "ok", "terminated": count}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

def logout_session(user_id: str, session_id: str):
    """Terminate a specific session."""
    db = SessionLocal()
    try:
        s = db.query(UserSession).filter(
            UserSession.id == session_id,
            UserSession.user_id == user_id,
            UserSession.is_active == True,
        ).first()
        if not s:
            return {"status": "error", "detail": "الجلسة غير موجودة"}
        s.is_active = False
        s.ended_at = datetime.utcnow()
        db.commit()
        return {"status": "ok", "message": "تم إنهاء الجلسة"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

# ─── Profile Update ───────────────────────────────────────
def update_profile(user_id: str, display_name: str = None, email: str = None, mobile: str = None):
    """Update user profile fields."""
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return {"status": "error", "detail": "المستخدم غير موجود"}

        changes = []
        if display_name and display_name != getattr(user, "display_name", None):
            user.display_name = display_name
            changes.append(f"display_name→{display_name}")
        if email and email != user.email:
            # Check uniqueness
            existing = db.query(User).filter(User.email == email, User.id != user_id).first()
            if existing:
                return {"status": "error", "detail": "البريد الإلكتروني مستخدم بالفعل"}
            user.email = email
            changes.append(f"email→{email}")
        if mobile is not None:
            if hasattr(user, "mobile"):
                user.mobile = mobile
                changes.append(f"mobile→{mobile}")

        if changes:
            action = AccountAction(
                id=gen_uuid(), user_id=user_id,
                action_type="profile_updated",
                action_details=", ".join(changes),
            )
            db.add(action)

        db.commit()
        return {"status": "ok", "changes": changes}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

# ─── Account Closure ──────────────────────────────────────
def request_account_closure(user_id: str, closure_type: str = "temporary", reason: str = ""):
    """Request temporary or permanent account closure."""
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return {"status": "error", "detail": "المستخدم غير موجود"}

        if closure_type == "temporary":
            user.is_active = False
            action_type = "account_suspended_temporary"
            message = "تم تعطيل الحساب مؤقتاً. يمكنك إعادة التفعيل بتسجيل الدخول."
        elif closure_type == "permanent":
            user.is_active = False
            action_type = "account_closure_permanent_requested"
            message = "تم طلب إغلاق الحساب نهائياً. سيتم مراجعة الطلب خلال 30 يوماً."
        else:
            return {"status": "error", "detail": "نوع الإغلاق غير صالح"}

        # Terminate all sessions
        sessions = db.query(UserSession).filter(
            UserSession.user_id == user_id,
            UserSession.is_active == True
        ).all()
        for s in sessions:
            s.is_active = False
            s.ended_at = datetime.utcnow()

        action = AccountAction(
            id=gen_uuid(), user_id=user_id,
            action_type=action_type,
            action_details=f"type={closure_type}, reason={reason}",
        )
        db.add(action)
        db.commit()

        return {"status": "ok", "closure_type": closure_type, "message": message}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

# ─── Activity History ─────────────────────────────────────
def get_account_activity(user_id: str, limit: int = 50):
    """Get recent account actions for audit trail."""
    db = SessionLocal()
    try:
        actions = db.query(AccountAction).filter(
            AccountAction.user_id == user_id
        ).order_by(AccountAction.created_at.desc()).limit(limit).all()

        return [{
            "id": a.id,
            "action_type": a.action_type,
            "action_details": a.action_details,
            "created_at": str(a.created_at) if a.created_at else None,
        } for a in actions]
    finally:
        db.close()
