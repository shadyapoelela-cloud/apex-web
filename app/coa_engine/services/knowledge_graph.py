"""
APEX COA Engine v4.2 — Knowledge Graph (Wave 5)
Accounting ontology with typed relationships, BFS/DFS traversal,
dependency analysis, and impact propagation.

Relationship types (TABLE 128):
  PARENT_OF     — Hierarchical parent→child
  CONTRA_OF     — Contra account (e.g. Accum Depreciation contra PPE)
  REQUIRES      — Mandatory pair (e.g. Receivables requires ECL)
  TRIGGERS_ERROR — Absence triggers error (e.g. no ECL → E28)
  PART_OF       — Section membership (e.g. Cash PART_OF current_assets)
  BALANCES_WITH — Balancing pair (e.g. VAT Input balances VAT Output)
"""

import logging
from collections import deque
from typing import Dict, List, Optional, Set, Tuple

logger = logging.getLogger(__name__)

# Relationship types
REL_PARENT_OF = "PARENT_OF"
REL_CONTRA_OF = "CONTRA_OF"
REL_REQUIRES = "REQUIRES"
REL_TRIGGERS_ERROR = "TRIGGERS_ERROR"
REL_PART_OF = "PART_OF"
REL_BALANCES_WITH = "BALANCES_WITH"

ALL_RELATIONSHIPS = frozenset([
    REL_PARENT_OF, REL_CONTRA_OF, REL_REQUIRES,
    REL_TRIGGERS_ERROR, REL_PART_OF, REL_BALANCES_WITH,
])

# Built-in ontology rules — concept-level relationships
ONTOLOGY_RULES: List[Tuple[str, str, str, Dict]] = [
    # (source_concept, relationship, target_concept, metadata)
    # Contra relationships
    ("ACCUM_DEPRECIATION", REL_CONTRA_OF, "PPE", {"description": "مجمع الإهلاك مقابل الأصول الثابتة"}),
    ("ACCUM_DEPRECIATION", REL_CONTRA_OF, "BUILDINGS", {"description": "مجمع الإهلاك مقابل المباني"}),
    ("ACCUM_DEPRECIATION", REL_CONTRA_OF, "EQUIPMENT", {"description": "مجمع الإهلاك مقابل المعدات"}),
    ("ACCUM_DEPRECIATION", REL_CONTRA_OF, "VEHICLES", {"description": "مجمع الإهلاك مقابل السيارات"}),
    ("ACCUM_DEPRECIATION", REL_CONTRA_OF, "FURNITURE", {"description": "مجمع الإهلاك مقابل الأثاث"}),
    ("SALES_RETURNS", REL_CONTRA_OF, "SALES_REVENUE", {"description": "مردودات المبيعات مقابل إيرادات المبيعات"}),
    ("PURCHASE_RETURNS", REL_CONTRA_OF, "PURCHASES", {"description": "مردودات المشتريات مقابل المشتريات"}),
    # Requires relationships
    ("ACC_RECEIVABLE", REL_REQUIRES, "ECL_PROVISION", {"error_code": "E28", "reference": "IFRS 9 §5.5"}),
    ("PPE", REL_REQUIRES, "ACCUM_DEPRECIATION", {"error_code": "E48", "reference": "IAS 16 §43"}),
    ("PPE", REL_REQUIRES, "DEPRECIATION_EXP", {"error_code": "E37", "reference": "IAS 16 §43"}),
    ("BUILDINGS", REL_REQUIRES, "ACCUM_DEPRECIATION", {"error_code": "E48"}),
    ("EQUIPMENT", REL_REQUIRES, "ACCUM_DEPRECIATION", {"error_code": "E48"}),
    ("VEHICLES", REL_REQUIRES, "ACCUM_DEPRECIATION", {"error_code": "E48"}),
    ("SALES_REVENUE", REL_REQUIRES, "COGS", {"error_code": "E50", "reference": "IASB Framework"}),
    ("SALARIES_EXPENSE", REL_REQUIRES, "END_OF_SERVICE", {"error_code": "E38", "reference": "Saudi Labor Law"}),
    ("LEASE_LIABILITY", REL_REQUIRES, "INTEREST_EXP", {"error_code": "E27", "reference": "IFRS 16"}),
    # Balances relationships
    ("VAT_INPUT", REL_BALANCES_WITH, "VAT_OUTPUT", {"error_code": "E33", "reference": "ZATCA"}),
    ("SHARE_CAPITAL", REL_BALANCES_WITH, "RESERVES", {"reference": "نظام الشركات السعودي"}),
    # Triggers error
    ("ACC_RECEIVABLE", REL_TRIGGERS_ERROR, "E28", {"condition": "missing ECL_PROVISION"}),
    ("SALES_REVENUE", REL_TRIGGERS_ERROR, "E50", {"condition": "missing COGS"}),
    ("PPE", REL_TRIGGERS_ERROR, "E48", {"condition": "missing ACCUM_DEPRECIATION"}),
    ("PPE", REL_TRIGGERS_ERROR, "E37", {"condition": "missing DEPRECIATION_EXP"}),
]

# Section membership rules
SECTION_MEMBERSHIP = {
    "current_asset": ["CASH", "BANK", "ACC_RECEIVABLE", "NOTES_RECEIVABLE", "INVENTORY",
                       "PREPAID", "SHORT_TERM_INV", "ADVANCES", "DEPOSITS_PAID", "VAT"],
    "non_current_asset": ["PPE", "LAND", "BUILDINGS", "EQUIPMENT", "VEHICLES", "FURNITURE",
                           "ACCUM_DEPRECIATION", "INTANGIBLES", "GOODWILL", "LONG_TERM_INV", "CIP"],
    "current_liability": ["ACC_PAYABLE", "NOTES_PAYABLE", "ACCRUED_EXPENSES", "SALARIES_PAYABLE",
                           "TAX_PAYABLE", "UNEARNED_REVENUE", "SHORT_TERM_LOANS", "CURRENT_PORTION_LTD"],
    "non_current_liability": ["LONG_TERM_LOANS", "END_OF_SERVICE", "BONDS_PAYABLE", "LEASE_LIABILITY"],
    "equity": ["SHARE_CAPITAL", "RESERVES", "RETAINED_EARNINGS", "ACCUMULATED_LOSSES",
               "OWNER_DRAWINGS", "DIVIDENDS", "TREASURY_SHARES"],
    "revenue": ["SALES_REVENUE", "SERVICE_REVENUE", "SALES_RETURNS", "OTHER_REVENUE",
                 "INVESTMENT_INCOME", "RENTAL_INCOME"],
    "cogs": ["COGS", "PURCHASES", "PURCHASE_RETURNS", "DIRECT_LABOR", "MFG_OVERHEAD"],
    "expense": ["SALARIES_EXPENSE", "RENT_EXPENSE", "UTILITIES", "DEPRECIATION_EXP",
                 "MARKETING_EXP", "TRAVEL_EXP", "LEGAL_EXP", "INSURANCE_EXP"],
    "finance_cost": ["BANK_CHARGES", "INTEREST_EXP"],
    "tax_expense": ["INCOME_TAX"],
    "closing": ["INCOME_SUMMARY"],
}


class KnowledgeGraph:
    """In-memory knowledge graph for COA accounts and their relationships."""

    def __init__(self):
        # Adjacency list: node_id -> [(target_id, rel_type, metadata)]
        self._edges: Dict[str, List[Tuple[str, str, Dict]]] = {}
        # Reverse adjacency for incoming edges
        self._reverse_edges: Dict[str, List[Tuple[str, str, Dict]]] = {}
        # Node metadata
        self._nodes: Dict[str, Dict] = {}

    @property
    def node_count(self) -> int:
        return len(self._nodes)

    @property
    def edge_count(self) -> int:
        return sum(len(edges) for edges in self._edges.values())

    def add_node(self, node_id: str, metadata: Dict = None) -> None:
        """Add a node to the graph."""
        self._nodes[node_id] = metadata or {}
        if node_id not in self._edges:
            self._edges[node_id] = []
        if node_id not in self._reverse_edges:
            self._reverse_edges[node_id] = []

    def add_edge(self, source: str, target: str, rel_type: str, metadata: Dict = None) -> None:
        """Add a directed edge between two nodes."""
        if source not in self._nodes:
            self.add_node(source)
        if target not in self._nodes:
            self.add_node(target)
        self._edges[source].append((target, rel_type, metadata or {}))
        self._reverse_edges[target].append((source, rel_type, metadata or {}))

    def get_node(self, node_id: str) -> Optional[Dict]:
        """Get node metadata."""
        return self._nodes.get(node_id)

    def get_neighbors(self, node_id: str, rel_type: str = None) -> List[Tuple[str, str, Dict]]:
        """Get outgoing edges from a node, optionally filtered by relationship type."""
        edges = self._edges.get(node_id, [])
        if rel_type:
            return [(t, r, m) for t, r, m in edges if r == rel_type]
        return edges

    def get_incoming(self, node_id: str, rel_type: str = None) -> List[Tuple[str, str, Dict]]:
        """Get incoming edges to a node."""
        edges = self._reverse_edges.get(node_id, [])
        if rel_type:
            return [(s, r, m) for s, r, m in edges if r == rel_type]
        return edges

    def bfs(self, start: str, max_depth: int = 10) -> List[Dict]:
        """Breadth-first search from a starting node.

        Returns list of {node_id, depth, path, relationships} for each reachable node.
        """
        if start not in self._nodes:
            return []

        visited: Set[str] = {start}
        queue: deque = deque([(start, 0, [start])])
        results: List[Dict] = []

        while queue:
            current, depth, path = queue.popleft()
            if depth > max_depth:
                break

            results.append({
                "node_id": current,
                "depth": depth,
                "path": path,
                "metadata": self._nodes.get(current, {}),
            })

            for target, rel_type, meta in self._edges.get(current, []):
                if target not in visited:
                    visited.add(target)
                    queue.append((target, depth + 1, path + [target]))

        return results

    def find_dependencies(self, node_id: str) -> Dict:
        """Find all dependencies for a node (what it requires and what requires it).

        Returns:
            Dict with: requires (outgoing REQUIRES), required_by (incoming REQUIRES),
                       contra_of, balances_with, part_of
        """
        result = {
            "node_id": node_id,
            "requires": [],
            "required_by": [],
            "contra_of": [],
            "contra_for": [],
            "balances_with": [],
            "part_of": [],
        }

        for target, rel, meta in self.get_neighbors(node_id):
            if rel == REL_REQUIRES:
                result["requires"].append({"target": target, **meta})
            elif rel == REL_CONTRA_OF:
                result["contra_of"].append({"target": target, **meta})
            elif rel == REL_BALANCES_WITH:
                result["balances_with"].append({"target": target, **meta})
            elif rel == REL_PART_OF:
                result["part_of"].append({"target": target, **meta})

        for source, rel, meta in self.get_incoming(node_id):
            if rel == REL_REQUIRES:
                result["required_by"].append({"source": source, **meta})
            elif rel == REL_CONTRA_OF:
                result["contra_for"].append({"source": source, **meta})

        return result

    def impact_analysis(self, node_id: str, change_type: str = "deleted") -> List[Dict]:
        """Analyze the impact of changing/removing a node.

        Returns a list of impacted nodes with severity and description.
        """
        if node_id not in self._nodes:
            return []

        impacts: List[Dict] = []

        # Check what requires this node
        for source, rel, meta in self.get_incoming(node_id, REL_REQUIRES):
            impacts.append({
                "impacted_node": source,
                "relationship": REL_REQUIRES,
                "severity": "High",
                "description_ar": f"الحساب {source} يتطلب {node_id} — حذفه يُشغِّل خطأ",
                "error_code": meta.get("error_code", ""),
            })

        # Check contra relationships
        for source, rel, meta in self.get_incoming(node_id, REL_CONTRA_OF):
            impacts.append({
                "impacted_node": source,
                "relationship": REL_CONTRA_OF,
                "severity": "High",
                "description_ar": f"{source} هو حساب مقابل لـ {node_id}",
            })

        # Check balancing pairs
        for target, rel, meta in self.get_neighbors(node_id, REL_BALANCES_WITH):
            impacts.append({
                "impacted_node": target,
                "relationship": REL_BALANCES_WITH,
                "severity": "Medium",
                "description_ar": f"{target} مرتبط بـ {node_id} في زوج متوازن",
            })

        # Check children (PARENT_OF)
        children = self.get_neighbors(node_id, REL_PARENT_OF)
        if children:
            impacts.append({
                "impacted_node": f"{len(children)} child accounts",
                "relationship": REL_PARENT_OF,
                "severity": "Critical",
                "description_ar": f"حذف الأب يُيتِّم {len(children)} حساب فرعي",
            })

        return impacts

    def to_dict(self) -> Dict:
        """Serialize the graph to a dict for API responses."""
        nodes = []
        for nid, meta in self._nodes.items():
            nodes.append({"id": nid, **meta})

        edges = []
        for source, edge_list in self._edges.items():
            for target, rel, meta in edge_list:
                edges.append({
                    "source": source,
                    "target": target,
                    "relationship": rel,
                    **meta,
                })

        return {
            "node_count": self.node_count,
            "edge_count": self.edge_count,
            "nodes": nodes,
            "edges": edges,
        }


def build_graph_from_accounts(accounts: List[Dict]) -> KnowledgeGraph:
    """Build a knowledge graph from classified COA accounts.

    Adds:
    1. Account nodes with metadata
    2. PARENT_OF edges from hierarchy
    3. PART_OF edges from section membership
    4. Ontology rules (REQUIRES, CONTRA_OF, BALANCES_WITH, TRIGGERS_ERROR)

    Args:
        accounts: Classified account list from the pipeline.

    Returns:
        Populated KnowledgeGraph instance.
    """
    graph = KnowledgeGraph()

    # Step 1: Add account nodes
    concept_to_code: Dict[str, str] = {}
    for acct in accounts:
        code = str(acct.get("code", "")).strip()
        if not code:
            continue

        concept_id = acct.get("concept_id")
        graph.add_node(code, {
            "code": code,
            "name": acct.get("name", ""),
            "concept_id": concept_id,
            "main_class": acct.get("main_class"),
            "sub_class": acct.get("sub_class"),
            "nature": acct.get("nature"),
            "level": acct.get("level", 0),
            "node_type": "account",
        })

        if concept_id:
            concept_to_code[concept_id] = code

    # Step 2: Add PARENT_OF edges from hierarchy
    for acct in accounts:
        code = str(acct.get("code", "")).strip()
        parent = str(acct.get("parent_code", "") or "").strip()
        if code and parent and parent in graph._nodes:
            graph.add_edge(parent, code, REL_PARENT_OF)

    # Step 3: Add section concept nodes and PART_OF edges
    for section, concepts in SECTION_MEMBERSHIP.items():
        section_id = f"section:{section}"
        graph.add_node(section_id, {"name": section, "node_type": "section"})
        for concept in concepts:
            if concept in concept_to_code:
                graph.add_edge(concept_to_code[concept], section_id, REL_PART_OF)

    # Step 4: Add ontology rules
    for source_concept, rel, target_concept, meta in ONTOLOGY_RULES:
        source_code = concept_to_code.get(source_concept, source_concept)
        target_code = concept_to_code.get(target_concept, target_concept)
        # Only add if at least source exists as a real account
        if source_concept in concept_to_code:
            graph.add_edge(source_code, target_code, rel, meta)

    logger.info(
        "Knowledge graph built: %d nodes, %d edges from %d accounts",
        graph.node_count, graph.edge_count, len(accounts),
    )

    return graph
