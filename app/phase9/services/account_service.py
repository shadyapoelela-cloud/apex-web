"""
APEX Phase 9 — Account Center Services
Uses Phase 1 PasswordReset + UserSession models
"""
import secrets, hashlib
from datetime import datetime, timedelta
from app.phase1.models.platform_models import SessionLocal, User, gen_uuid, utcnow, PasswordReset, UserSession
from app.phase9.models.phase9_models import AccountAction

# --- Password Reset ---
def create_password_reset(email: str):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            return {"status": "ok", "message": "\u0625\u0630\u0627 \u0643\u0627\u0646 \u0627\u0644\u0628\u0631\u064a\u062f \u0645\u0633\u062c\u0644\u0627\u064b\u060c \u0633\u064a\u062a\u0645 \u0625\u0631\u0633\u0627\u0644 \u0631\u0627\u0628\u0637 \u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u062a\u0639\u064a\u064a\u0646"}

        raw_token = secrets.token_urlsafe(48)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()

        reset = PasswordReset(
            id=gen_uuid(),
            user_id=user.id,
            token_hash=token_hash,
            expires_at=datetime.utcnow() + timedelta(hours=1),
        )
        db.add(reset)

        action = AccountAction(
            id=gen_uuid(), user_id=user.id,
            action_type="password_reset_requested",
            action_details=f"Reset for {email}",
        )
        db.add(action)
        db.commit()

        return {
            "status": "ok",
            "message": "\u0625\u0630\u0627 \u0643\u0627\u0646 \u0627\u0644\u0628\u0631\u064a\u062f \u0645\u0633\u062c\u0644\u0627\u064b\u060c \u0633\u064a\u062a\u0645 \u0625\u0631\u0633\u0627\u0644 \u0631\u0627\u0628\u0637 \u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u062a\u0639\u064a\u064a\u0646",
            "reset_token": raw_token,
            "expires_in_minutes": 60,
        }
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

def execute_password_reset(raw_token: str, new_password: str):
    db = SessionLocal()
    try:
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        reset = db.query(PasswordReset).filter(
            PasswordReset.token_hash == token_hash,
            PasswordReset.used == False,
        ).first()

        if not reset:
            return {"status": "error", "detail": "\u0631\u0645\u0632 \u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u062a\u0639\u064a\u064a\u0646 \u063a\u064a\u0631 \u0635\u0627\u0644\u062d"}

        if datetime.utcnow() > reset.expires_at:
            return {"status": "error", "detail": "\u0627\u0646\u062a\u0647\u062a \u0635\u0644\u0627\u062d\u064a\u0629 \u0631\u0645\u0632 \u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u062a\u0639\u064a\u064a\u0646"}

        user = db.query(User).filter(User.id == reset.user_id).first()
        if not user:
            return {"status": "error", "detail": "\u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f"}

        try:
            from app.phase1.services.auth_service import hash_password
            user.password_hash = hash_password(new_password)
        except Exception:
            user.password_hash = hashlib.sha256(new_password.encode()).hexdigest()
        reset.used = True
        reset.used_at = datetime.utcnow()

        action = AccountAction(
            id=gen_uuid(), user_id=user.id,
            action_type="password_reset_completed",
        )
        db.add(action)
        db.commit()

        return {"status": "ok", "message": "\u062a\u0645 \u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631 \u0628\u0646\u062c\u0627\u062d"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

# --- Sessions ---
def create_session(user_id, device_info=None, ip_address=None):
    db = SessionLocal()
    try:
        raw_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(raw_token.encode()).hexdigest()
        session = UserSession(
            id=gen_uuid(), user_id=user_id,
            token_hash=token_hash,
            device_info=device_info or "unknown",
            ip_address=ip_address or "unknown",
            expires_at=datetime.utcnow() + timedelta(days=30),
        )
        db.add(session)
        db.commit()
        return {"session_id": session.id, "session_token": raw_token}
    except Exception as e:
        db.rollback()
        return None
    finally:
        db.close()

def get_user_sessions(user_id):
    db = SessionLocal()
    try:
        sessions = db.query(UserSession).filter(
            UserSession.user_id == user_id,
            UserSession.is_active == True,
        ).order_by(UserSession.last_used_at.desc()).all()

        return [{
            "id": s.id,
            "device_info": s.device_info,
            "ip_address": s.ip_address,
            "last_activity": str(s.last_used_at) if s.last_used_at else None,
            "created_at": str(s.created_at) if s.created_at else None,
        } for s in sessions]
    finally:
        db.close()

def logout_all_sessions(user_id, except_current=None):
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

def logout_session(user_id, session_id):
    db = SessionLocal()
    try:
        s = db.query(UserSession).filter(
            UserSession.id == session_id,
            UserSession.user_id == user_id,
            UserSession.is_active == True,
        ).first()
        if not s:
            return {"status": "error", "detail": "\u0627\u0644\u062c\u0644\u0633\u0629 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f\u0629"}
        s.is_active = False
        db.commit()
        return {"status": "ok", "message": "\u062a\u0645 \u0625\u0646\u0647\u0627\u0621 \u0627\u0644\u062c\u0644\u0633\u0629"}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

# --- Profile Update ---
def update_profile(user_id, display_name=None, email=None, mobile=None):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return {"status": "error", "detail": "\u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f"}

        changes = []
        if display_name and display_name != getattr(user, "display_name", None):
            user.display_name = display_name
            changes.append(f"display_name={display_name}")
        if email and email != user.email:
            existing = db.query(User).filter(User.email == email, User.id != user_id).first()
            if existing:
                return {"status": "error", "detail": "\u0627\u0644\u0628\u0631\u064a\u062f \u0645\u0633\u062a\u062e\u062f\u0645 \u0628\u0627\u0644\u0641\u0639\u0644"}
            user.email = email
            changes.append(f"email={email}")

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

# --- Account Closure ---
def request_account_closure(user_id, closure_type="temporary", reason=""):
    db = SessionLocal()
    try:
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return {"status": "error", "detail": "\u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645 \u063a\u064a\u0631 \u0645\u0648\u062c\u0648\u062f"}

        if closure_type == "temporary":
            user.is_active = False
            msg = "\u062a\u0645 \u062a\u0639\u0637\u064a\u0644 \u0627\u0644\u062d\u0633\u0627\u0628 \u0645\u0624\u0642\u062a\u0627\u064b"
        elif closure_type == "permanent":
            user.is_active = False
            msg = "\u062a\u0645 \u0637\u0644\u0628 \u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u062d\u0633\u0627\u0628 \u0646\u0647\u0627\u0626\u064a\u0627\u064b"
        else:
            return {"status": "error", "detail": "\u0646\u0648\u0639 \u0625\u063a\u0644\u0627\u0642 \u063a\u064a\u0631 \u0635\u0627\u0644\u062d"}

        # End all sessions
        for s in db.query(UserSession).filter(UserSession.user_id == user_id, UserSession.is_active == True).all():
            s.is_active = False

        action = AccountAction(
            id=gen_uuid(), user_id=user_id,
            action_type=f"account_closure_{closure_type}",
            action_details=f"reason={reason}",
        )
        db.add(action)
        db.commit()
        return {"status": "ok", "closure_type": closure_type, "message": msg}
    except Exception as e:
        db.rollback()
        return {"status": "error", "detail": str(e)}
    finally:
        db.close()

# --- Activity History ---
def get_account_activity(user_id, limit=50):
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
