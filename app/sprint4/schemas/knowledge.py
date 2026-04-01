# -*- coding: utf-8 -*-
"""Sprint 4 — Knowledge Brain Pydantic schemas."""
from pydantic import BaseModel
from typing import Optional, List, Dict, Any


class ConceptCreate(BaseModel):
    canonical_name_ar: str
    canonical_name_en: Optional[str] = None
    domain_pack: str = "accounting"
    sector_scope: Optional[str] = None
    jurisdiction_scope: Optional[str] = None
    authority_level: str = "platform"
    description_ar: Optional[str] = None
    description_en: Optional[str] = None
    effective_from: Optional[str] = None
    effective_to: Optional[str] = None


class AliasCreate(BaseModel):
    concept_id: str
    alias_text: str
    language_code: str = "ar"
    alias_type: str = "synonym"
    source_system: Optional[str] = None
    client_scope: Optional[str] = None
    sector_scope: Optional[str] = None
    confidence_weight: float = 1.0
    is_approved: bool = False


class RuleCreate(BaseModel):
    rule_name: str
    domain_pack: str
    rule_logic_json: Dict[str, Any]
    authority_level: str = "platform"
    source_concept_ids: List[str] = []
    effective_from: Optional[str] = None
    description_ar: Optional[str] = None
    description_en: Optional[str] = None


class TerminologyReview(BaseModel):
    alias_id: str
    decision: str  # approve / reject / escalate
    reviewer_notes: Optional[str] = None


class RulePromotion(BaseModel):
    candidate_rule_id: str
    decision: str  # approve / reject
    reviewer_notes: Optional[str] = None
    effective_from: Optional[str] = None
