import json

"""
APEX Platform — Client Service
═══════════════════════════════════════════════════════════════
Client creation, type selection, knowledge mode, memberships.
Per execution document sections 5, 7.
"""

import logging
from typing import Optional
from app.phase1.models.platform_models import (
    User,
    AuditEvent,
    Notification,
    SessionLocal,
    gen_uuid,
    utcnow,
)
from app.phase2.models.phase2_models import (
    Client,
    ClientTypeRef,
    ClientMembership,
    ClientType,
    KNOWLEDGE_MODE_ELIGIBLE_TYPES,
)


class ClientService:

    def get_client_types(self) -> list:
        """List all available client types."""
        db = SessionLocal()
        try:
            types = (
                db.query(ClientTypeRef).filter(ClientTypeRef.is_active == True).order_by(ClientTypeRef.sort_order).all()
            )
            return [
                {
                    "code": t.code,
                    "name_ar": t.name_ar,
                    "name_en": t.name_en,
                    "description_ar": t.description_ar,
                    "knowledge_mode_eligible": t.knowledge_mode_eligible,
                    "knowledge_mode_features_ar": t.knowledge_mode_features_ar,
                }
                for t in types
            ]
        finally:
            db.close()

    def create_client(
        self,
        user_id: str,
        name_ar: str,
        client_type_code: str,
        name_en: Optional[str] = None,
        cr_number: Optional[str] = None,
        tax_number: Optional[str] = None,
        sector: Optional[str] = None,
        city: Optional[str] = None,
        inventory_system: Optional[str] = None,
    ) -> dict:
        """Create client entity with auto knowledge mode."""
        db = SessionLocal()
        try:
            # Validate client type
            valid_types = [t.value for t in ClientType]
            if client_type_code not in valid_types:
                return {"success": False, "error": f"نوع العميل غير صالح. الأنواع المتاحة: {', '.join(valid_types)}"}

            # Auto-enable knowledge mode
            knowledge_mode = client_type_code in KNOWLEDGE_MODE_ELIGIBLE_TYPES

            client = Client(
                id=gen_uuid(),
                name_ar=name_ar.strip(),
                name_en=name_en.strip() if name_en else None,
                client_type_code=client_type_code,
                cr_number=cr_number,
                tax_number=tax_number,
                sector=sector,
                city=city,
                inventory_system=inventory_system or "unknown",
                knowledge_mode=knowledge_mode,
                created_by=user_id,
            )
            db.add(client)

            # Add creator as owner
            db.add(
                ClientMembership(
                    id=gen_uuid(),
                    client_id=client.id,
                    user_id=user_id,
                    role_in_client="owner",
                )
            )

            db.add(
                AuditEvent(
                    id=gen_uuid(),
                    user_id=user_id,
                    action="client_created",
                    resource_type="client",
                    resource_id=client.id,
                    details=json.dumps({"type": client_type_code, "knowledge_mode": knowledge_mode}),
                )
            )

            db.add(
                Notification(
                    id=gen_uuid(),
                    user_id=user_id,
                    title_ar=f"تم إنشاء العميل: {name_ar}",
                    title_en=f"Client created: {name_en or name_ar}",
                    category="general",
                    source_type="client_created",
                    source_id=client.id,
                )
            )

            db.commit()

            return {
                "success": True,
                "client": {
                    "id": client.id,
                    "name_ar": client.name_ar,
                    "name_en": client.name_en,
                    "client_type": client.client_type_code,
                    "knowledge_mode": client.knowledge_mode,
                    "inventory_system": client.inventory_system,
                    "created_at": client.created_at.isoformat(),
                },
            }

        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def get_client(self, client_id: str, user_id: str) -> dict:
        """Get client details — checks membership."""
        db = SessionLocal()
        try:
            membership = (
                db.query(ClientMembership)
                .filter(
                    ClientMembership.client_id == client_id,
                    ClientMembership.user_id == user_id,
                    ClientMembership.is_active == True,
                )
                .first()
            )
            if not membership:
                return {"success": False, "error": "ليس لديك صلاحية الوصول لهذا العميل"}

            client = db.query(Client).filter(Client.id == client_id, Client.is_deleted == False).first()
            if not client:
                return {"success": False, "error": "العميل غير موجود"}

            members = (
                db.query(ClientMembership)
                .filter(ClientMembership.client_id == client_id, ClientMembership.is_active == True)
                .all()
            )

            return {
                "success": True,
                "client": {
                    "id": client.id,
                    "name_ar": client.name_ar,
                    "name_en": client.name_en,
                    "client_type": client.client_type_code,
                    "cr_number": client.cr_number,
                    "tax_number": client.tax_number,
                    "sector": client.sector,
                    "city": client.city,
                    "knowledge_mode": client.knowledge_mode,
                    "inventory_system": client.inventory_system,
                    "fiscal_year_end": client.fiscal_year_end,
                    "created_at": client.created_at.isoformat(),
                },
                "your_role": membership.role_in_client,
                "team_count": len(members),
            }
        finally:
            db.close()

    def list_my_clients(self, user_id: str) -> list:
        """List all clients the user belongs to."""
        db = SessionLocal()
        try:
            memberships = (
                db.query(ClientMembership)
                .filter(ClientMembership.user_id == user_id, ClientMembership.is_active == True)
                .all()
            )

            clients = []
            for m in memberships:
                c = db.query(Client).filter(Client.id == m.client_id, Client.is_deleted == False).first()
                if c:
                    clients.append(
                        {
                            "id": c.id,
                            "name_ar": c.name_ar,
                            "client_type": c.client_type_code,
                            "knowledge_mode": c.knowledge_mode,
                            "your_role": m.role_in_client,
                        }
                    )
            return clients
        finally:
            db.close()

    def add_member(self, client_id: str, target_user_id: str, role: str, added_by: str) -> dict:
        """Add team member to client."""
        db = SessionLocal()
        try:
            # Check requester is admin/owner
            requester_membership = (
                db.query(ClientMembership)
                .filter(
                    ClientMembership.client_id == client_id,
                    ClientMembership.user_id == added_by,
                    ClientMembership.role_in_client.in_(["owner", "admin"]),
                )
                .first()
            )
            if not requester_membership:
                return {"success": False, "error": "ليس لديك صلاحية إضافة أعضاء"}

            existing = (
                db.query(ClientMembership)
                .filter(
                    ClientMembership.client_id == client_id,
                    ClientMembership.user_id == target_user_id,
                )
                .first()
            )
            if existing:
                return {"success": False, "error": "المستخدم عضو بالفعل"}

            db.add(
                ClientMembership(
                    id=gen_uuid(),
                    client_id=client_id,
                    user_id=target_user_id,
                    role_in_client=role,
                )
            )
            db.commit()
            return {"success": True, "message": "تمت إضافة العضو"}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()

    def update_client(self, client_id: str, user_id: str, updates: dict) -> dict:
        """Update client settings."""
        db = SessionLocal()
        try:
            membership = (
                db.query(ClientMembership)
                .filter(
                    ClientMembership.client_id == client_id,
                    ClientMembership.user_id == user_id,
                    ClientMembership.role_in_client.in_(["owner", "admin"]),
                )
                .first()
            )
            if not membership:
                return {"success": False, "error": "ليس لديك صلاحية التعديل"}

            client = db.query(Client).filter(Client.id == client_id).first()
            allowed = {
                "name_ar",
                "name_en",
                "sector",
                "city",
                "fiscal_year_end",
                "inventory_system",
                "cr_number",
                "tax_number",
            }
            for k, v in updates.items():
                if k in allowed and v is not None:
                    setattr(client, k, v)

            db.commit()
            return {"success": True, "message": "تم تحديث بيانات العميل"}
        except Exception as e:
            db.rollback()
            logging.error("Operation failed", exc_info=True)
            return {"success": False, "error": "Internal server error"}
        finally:
            db.close()
