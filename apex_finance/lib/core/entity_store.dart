/// APEX Platform — Entity / Company / Branch Local Store
/// ════════════════════════════════════════════════════════════════════
/// Unified hierarchical setup storage, synthesized from 13-round research:
///   • SAP S/4HANA            → Client > Company Code > Plant
///   • Oracle Fusion          → Enterprise > Legal Entity > Business Unit
///   • Odoo 17                → Company (legal) > Branch (operational)
///   • NetSuite OneWorld      → Root Subsidiary > Subsidiaries > Locations
///   • Dynamics 365 Finance   → Legal Entity > Operating Unit
///   • Sage Intacct           → Entity > Location (with dimensions)
///   • ZATCA (KSA)            → Seller branch code per VAT-registered entity
///
/// Model:
///   Entity  — optional parent group / holding. A user can have zero, one,
///             or many Entities (e.g. "مجموعة أبوالإلعا للتوظيف").
///   Company — legal entity (local OR international). Has its own tax ID
///             and base currency. Can stand alone or belong to an Entity.
///   Branch  — operational unit under a Company. Each branch can
///             independently toggle: own Chart of Accounts, own inventory,
///             own cost centers, own currency, and whether it rolls up
///             into the parent's consolidated reports.
/// ════════════════════════════════════════════════════════════════════
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

// ═══════════════════════════════════════════════════════════════════
// Data records
// ═══════════════════════════════════════════════════════════════════

class EntityRecord {
  final String id;
  String nameAr;
  String nameEn;
  String type; // 'group' | 'holding' | 'standalone'
  bool consolidated; // enable consolidation across children
  String? notes;
  DateTime createdAt;
  DateTime updatedAt;

  EntityRecord({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    this.type = 'group',
    this.consolidated = true,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_ar': nameAr,
        'name_en': nameEn,
        'type': type,
        'consolidated': consolidated,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory EntityRecord.fromJson(Map<String, dynamic> m) => EntityRecord(
        id: m['id'] as String,
        nameAr: (m['name_ar'] ?? '') as String,
        nameEn: (m['name_en'] ?? '') as String,
        type: (m['type'] ?? 'group') as String,
        consolidated: (m['consolidated'] ?? true) as bool,
        notes: m['notes'] as String?,
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now(),
      );
}

class CompanyRecord {
  final String id;
  String? entityId; // nullable → standalone company
  String nameAr;
  String nameEn;
  String scope; // 'local' | 'international'
  String country; // ISO-2: SA, AE, KW, EG...
  String currency; // ISO-4217: SAR, AED, USD...
  String clientType; // existing 9 types (standard_business, audit_firm, …)
  String? taxNumber; // VAT / TIN
  String? crNumber; // Commercial Registration number
  bool includeInConsolidation;
  DateTime createdAt;
  DateTime updatedAt;

  CompanyRecord({
    required this.id,
    this.entityId,
    required this.nameAr,
    required this.nameEn,
    this.scope = 'local',
    this.country = 'SA',
    this.currency = 'SAR',
    this.clientType = 'standard_business',
    this.taxNumber,
    this.crNumber,
    this.includeInConsolidation = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'entity_id': entityId,
        'name_ar': nameAr,
        'name_en': nameEn,
        'scope': scope,
        'country': country,
        'currency': currency,
        'client_type_code': clientType,
        'tax_number': taxNumber,
        'cr_number': crNumber,
        'include_in_consolidation': includeInConsolidation,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CompanyRecord.fromJson(Map<String, dynamic> m) => CompanyRecord(
        id: m['id'] as String,
        entityId: m['entity_id'] as String?,
        nameAr: (m['name_ar'] ?? m['name'] ?? '') as String,
        nameEn: (m['name_en'] ?? m['name'] ?? '') as String,
        scope: (m['scope'] ?? 'local') as String,
        country: (m['country'] ?? 'SA') as String,
        currency: (m['currency'] ?? 'SAR') as String,
        clientType:
            (m['client_type_code'] ?? m['client_type'] ?? 'standard_business')
                as String,
        taxNumber: m['tax_number'] as String?,
        crNumber: m['cr_number'] as String?,
        includeInConsolidation: (m['include_in_consolidation'] ?? true) as bool,
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now(),
      );
}

class BranchRecord {
  final String id;
  String companyId; // parent company (required)
  String nameAr;
  String nameEn;
  String? city;
  String? address;
  String? zatcaBranchCode; // mandatory for KSA e-invoicing
  // ── Independence flags (per-branch autonomy) ──
  bool independentCoA;
  bool independentInventory;
  bool independentCostCenters;
  bool independentCurrency;
  String? currencyOverride;
  bool includeInConsolidation;
  DateTime createdAt;
  DateTime updatedAt;

  BranchRecord({
    required this.id,
    required this.companyId,
    required this.nameAr,
    required this.nameEn,
    this.city,
    this.address,
    this.zatcaBranchCode,
    this.independentCoA = false,
    this.independentInventory = false,
    this.independentCostCenters = false,
    this.independentCurrency = false,
    this.currencyOverride,
    this.includeInConsolidation = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'name_ar': nameAr,
        'name_en': nameEn,
        'city': city,
        'address': address,
        'zatca_branch_code': zatcaBranchCode,
        'independent_coa': independentCoA,
        'independent_inventory': independentInventory,
        'independent_cost_centers': independentCostCenters,
        'independent_currency': independentCurrency,
        'currency_override': currencyOverride,
        'include_in_consolidation': includeInConsolidation,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory BranchRecord.fromJson(Map<String, dynamic> m) => BranchRecord(
        id: m['id'] as String,
        companyId: (m['company_id'] ?? '') as String,
        nameAr: (m['name_ar'] ?? '') as String,
        nameEn: (m['name_en'] ?? '') as String,
        city: m['city'] as String?,
        address: m['address'] as String?,
        zatcaBranchCode: m['zatca_branch_code'] as String?,
        independentCoA: (m['independent_coa'] ?? false) as bool,
        independentInventory: (m['independent_inventory'] ?? false) as bool,
        independentCostCenters:
            (m['independent_cost_centers'] ?? false) as bool,
        independentCurrency: (m['independent_currency'] ?? false) as bool,
        currencyOverride: m['currency_override'] as String?,
        includeInConsolidation: (m['include_in_consolidation'] ?? true) as bool,
        createdAt: DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(m['updated_at'] ?? '') ?? DateTime.now(),
      );
}

// ═══════════════════════════════════════════════════════════════════
// Store (localStorage-backed, with one-time migration from v1 companies)
// ═══════════════════════════════════════════════════════════════════

class EntityStore {
  EntityStore._();

  // Keys
  static const _kEntities = 'apex_entities_v1';
  static const _kCompanies = 'apex_companies_v2';
  static const _kBranches = 'apex_branches_v1';
  // Legacy (was used in an earlier iteration — migrate on first read)
  static const _kLegacyCompaniesV1 = 'apex_companies_v1';
  static const _kMigratedFlag = 'apex_entity_store_migrated';

  // ── Low-level IO ────────────────────────────────────────────────
  static String? _read(String k) {
    try {
      return html.window.localStorage[k];
    } catch (_) {
      return null;
    }
  }

  static void _write(String k, String v) {
    try {
      html.window.localStorage[k] = v;
    } catch (_) {}
  }

  static void _delete(String k) {
    try {
      html.window.localStorage.remove(k);
    } catch (_) {}
  }

  // ── Migration v1 → v2 ───────────────────────────────────────────
  static void _migrateIfNeeded() {
    if (_read(_kMigratedFlag) == '1') return;
    final legacy = _read(_kLegacyCompaniesV1);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        final decoded = jsonDecode(legacy);
        if (decoded is List) {
          final migrated = <Map<String, dynamic>>[];
          for (final raw in decoded) {
            if (raw is! Map) continue;
            final now = DateTime.now();
            final id = (raw['id']?.toString().isNotEmpty == true)
                ? raw['id'].toString()
                : 'company_${now.microsecondsSinceEpoch}_${migrated.length}';
            migrated.add(CompanyRecord(
              id: id,
              nameAr: (raw['name_ar'] ?? raw['name'] ?? '') as String,
              nameEn: (raw['name_en'] ?? raw['name'] ?? '') as String,
              clientType: (raw['client_type_code'] ??
                      raw['client_type'] ??
                      'standard_business')
                  as String,
              createdAt:
                  DateTime.tryParse(raw['created_at'] ?? '') ?? now,
              updatedAt: now,
            ).toJson());
          }
          _write(_kCompanies, jsonEncode(migrated));
          _delete(_kLegacyCompaniesV1);
        }
      } catch (_) {}
    }
    _write(_kMigratedFlag, '1');
  }

  // ═══════════════════════════════════════════════════════════════
  // Entities CRUD
  // ═══════════════════════════════════════════════════════════════

  static List<EntityRecord> listEntities() {
    _migrateIfNeeded();
    final raw = _read(_kEntities);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => EntityRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static EntityRecord addEntity({
    required String nameAr,
    String? nameEn,
    String type = 'group',
    bool consolidated = true,
    String? notes,
  }) {
    final list = listEntities();
    final now = DateTime.now();
    final rec = EntityRecord(
      id: 'entity_${now.microsecondsSinceEpoch}',
      nameAr: nameAr,
      nameEn: nameEn ?? nameAr,
      type: type,
      consolidated: consolidated,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    list.add(rec);
    _write(_kEntities, jsonEncode(list.map((e) => e.toJson()).toList()));
    return rec;
  }

  static EntityRecord? updateEntity(String id,
      {String? nameAr,
      String? nameEn,
      String? type,
      bool? consolidated,
      String? notes}) {
    final list = listEntities();
    final idx = list.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    final e = list[idx];
    if (nameAr != null) e.nameAr = nameAr;
    if (nameEn != null) e.nameEn = nameEn;
    if (type != null) e.type = type;
    if (consolidated != null) e.consolidated = consolidated;
    if (notes != null) e.notes = notes;
    e.updatedAt = DateTime.now();
    _write(_kEntities, jsonEncode(list.map((x) => x.toJson()).toList()));
    return e;
  }

  static void deleteEntity(String id) {
    // Detach child companies (set entityId = null) so we don't orphan.
    final companies = listCompanies();
    for (final c in companies) {
      if (c.entityId == id) c.entityId = null;
    }
    _write(_kCompanies, jsonEncode(companies.map((c) => c.toJson()).toList()));
    final list = listEntities()..removeWhere((e) => e.id == id);
    _write(_kEntities, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  // ═══════════════════════════════════════════════════════════════
  // Companies CRUD
  // ═══════════════════════════════════════════════════════════════

  static List<CompanyRecord> listCompanies({String? entityId}) {
    _migrateIfNeeded();
    final raw = _read(_kCompanies);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final all = decoded
          .whereType<Map>()
          .map((m) => CompanyRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (entityId == null) return all;
      return all.where((c) => c.entityId == entityId).toList();
    } catch (_) {
      return [];
    }
  }

  static CompanyRecord addCompany({
    String? entityId,
    required String nameAr,
    String? nameEn,
    String scope = 'local',
    String country = 'SA',
    String currency = 'SAR',
    String clientType = 'standard_business',
    String? taxNumber,
    String? crNumber,
    bool includeInConsolidation = true,
  }) {
    final list = listCompanies();
    final now = DateTime.now();
    final rec = CompanyRecord(
      id: 'company_${now.microsecondsSinceEpoch}',
      entityId: entityId,
      nameAr: nameAr,
      nameEn: nameEn ?? nameAr,
      scope: scope,
      country: country,
      currency: currency,
      clientType: clientType,
      taxNumber: taxNumber,
      crNumber: crNumber,
      includeInConsolidation: includeInConsolidation,
      createdAt: now,
      updatedAt: now,
    );
    list.add(rec);
    _write(_kCompanies, jsonEncode(list.map((c) => c.toJson()).toList()));
    return rec;
  }

  static CompanyRecord? updateCompany(String id,
      {String? entityId,
      String? nameAr,
      String? nameEn,
      String? scope,
      String? country,
      String? currency,
      String? clientType,
      String? taxNumber,
      String? crNumber,
      bool? includeInConsolidation}) {
    final list = listCompanies();
    final idx = list.indexWhere((c) => c.id == id);
    if (idx < 0) return null;
    final c = list[idx];
    if (entityId != null || (entityId == null && nameAr == null)) {
      c.entityId = entityId;
    }
    if (nameAr != null) c.nameAr = nameAr;
    if (nameEn != null) c.nameEn = nameEn;
    if (scope != null) c.scope = scope;
    if (country != null) c.country = country;
    if (currency != null) c.currency = currency;
    if (clientType != null) c.clientType = clientType;
    if (taxNumber != null) c.taxNumber = taxNumber;
    if (crNumber != null) c.crNumber = crNumber;
    if (includeInConsolidation != null) {
      c.includeInConsolidation = includeInConsolidation;
    }
    c.updatedAt = DateTime.now();
    _write(_kCompanies, jsonEncode(list.map((x) => x.toJson()).toList()));
    return c;
  }

  static void deleteCompany(String id) {
    // Cascade: delete branches under this company.
    final branches = listBranches()..removeWhere((b) => b.companyId == id);
    _write(_kBranches, jsonEncode(branches.map((b) => b.toJson()).toList()));
    final list = listCompanies()..removeWhere((c) => c.id == id);
    _write(_kCompanies, jsonEncode(list.map((c) => c.toJson()).toList()));
  }

  // ═══════════════════════════════════════════════════════════════
  // Branches CRUD
  // ═══════════════════════════════════════════════════════════════

  static List<BranchRecord> listBranches({String? companyId}) {
    _migrateIfNeeded();
    final raw = _read(_kBranches);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final all = decoded
          .whereType<Map>()
          .map((m) => BranchRecord.fromJson(Map<String, dynamic>.from(m)))
          .toList();
      if (companyId == null) return all;
      return all.where((b) => b.companyId == companyId).toList();
    } catch (_) {
      return [];
    }
  }

  static BranchRecord addBranch({
    required String companyId,
    required String nameAr,
    String? nameEn,
    String? city,
    String? address,
    String? zatcaBranchCode,
    bool independentCoA = false,
    bool independentInventory = false,
    bool independentCostCenters = false,
    bool independentCurrency = false,
    String? currencyOverride,
    bool includeInConsolidation = true,
  }) {
    final list = listBranches();
    final now = DateTime.now();
    final rec = BranchRecord(
      id: 'branch_${now.microsecondsSinceEpoch}',
      companyId: companyId,
      nameAr: nameAr,
      nameEn: nameEn ?? nameAr,
      city: city,
      address: address,
      zatcaBranchCode: zatcaBranchCode,
      independentCoA: independentCoA,
      independentInventory: independentInventory,
      independentCostCenters: independentCostCenters,
      independentCurrency: independentCurrency,
      currencyOverride: currencyOverride,
      includeInConsolidation: includeInConsolidation,
      createdAt: now,
      updatedAt: now,
    );
    list.add(rec);
    _write(_kBranches, jsonEncode(list.map((b) => b.toJson()).toList()));
    return rec;
  }

  static BranchRecord? updateBranch(String id,
      {String? nameAr,
      String? nameEn,
      String? city,
      String? address,
      String? zatcaBranchCode,
      bool? independentCoA,
      bool? independentInventory,
      bool? independentCostCenters,
      bool? independentCurrency,
      String? currencyOverride,
      bool? includeInConsolidation}) {
    final list = listBranches();
    final idx = list.indexWhere((b) => b.id == id);
    if (idx < 0) return null;
    final b = list[idx];
    if (nameAr != null) b.nameAr = nameAr;
    if (nameEn != null) b.nameEn = nameEn;
    if (city != null) b.city = city;
    if (address != null) b.address = address;
    if (zatcaBranchCode != null) b.zatcaBranchCode = zatcaBranchCode;
    if (independentCoA != null) b.independentCoA = independentCoA;
    if (independentInventory != null) {
      b.independentInventory = independentInventory;
    }
    if (independentCostCenters != null) {
      b.independentCostCenters = independentCostCenters;
    }
    if (independentCurrency != null) b.independentCurrency = independentCurrency;
    if (currencyOverride != null) b.currencyOverride = currencyOverride;
    if (includeInConsolidation != null) {
      b.includeInConsolidation = includeInConsolidation;
    }
    b.updatedAt = DateTime.now();
    _write(_kBranches, jsonEncode(list.map((x) => x.toJson()).toList()));
    return b;
  }

  static void deleteBranch(String id) {
    final list = listBranches()..removeWhere((b) => b.id == id);
    _write(_kBranches, jsonEncode(list.map((b) => b.toJson()).toList()));
  }

  // ═══════════════════════════════════════════════════════════════
  // Convenience / summary accessors
  // ═══════════════════════════════════════════════════════════════

  /// Total counts — for dashboard badges.
  static Map<String, int> counts() => {
        'entities': listEntities().length,
        'companies': listCompanies().length,
        'branches': listBranches().length,
      };

  /// Flat list projection for legacy consumers (e.g. the old /clients
  /// screen). Returns Company records in the plain-Map shape the UI
  /// currently expects.
  static List<Map<String, dynamic>> legacyClientsProjection() {
    return listCompanies().map((c) => c.toJson()).toList();
  }

  /// DANGER: clear everything.
  static void clearAll() {
    _delete(_kEntities);
    _delete(_kCompanies);
    _delete(_kBranches);
    _delete(_kMigratedFlag);
  }
}
