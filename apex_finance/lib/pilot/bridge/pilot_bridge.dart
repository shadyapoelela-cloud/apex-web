/// Pilot ↔ V5 Architecture Bridge.
/// ═════════════════════════════════════════════════════════════════════
/// Connects the V5 `EntityScopeController` (the top-bar entity selector)
/// to the Pilot backend so that:
///   1. When user selects an entity, real data loads from /pilot/*
///   2. Real entities (from DB) replace the hardcoded `demoEntities`
///   3. Pilot-wired screens read current scope from EntityScopeController
///
/// Usage:
///   await PilotBridge.instance.bindTenant(tenantId);   // once at login/setup
///   // now every screen using EntityScopeController gets live pilot data

library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/v5/entity_scope_selector.dart' as v5;
import '../api/pilot_client.dart';

/// Bridges the V5 EntityScopeController to the Pilot multi-tenant backend.
///
/// Singleton — use [PilotBridge.instance].
class PilotBridge extends ChangeNotifier {
  PilotBridge._();
  static final PilotBridge instance = PilotBridge._();

  final PilotClient _client = pilotClient;

  // ── Bound state ──
  String? _tenantId;
  String? _tenantNameAr;
  String? _tenantSlug;
  Map<String, dynamic>? _tenantSettings;
  List<Map<String, dynamic>> _entities = [];
  List<Map<String, dynamic>> _branches = [];

  // Map V5 entity-id → Pilot entity-id (they may differ)
  final Map<String, String> _v5ToPilotEntity = {};

  /// Is there a tenant bound?
  bool get isBound => _tenantId != null;
  String? get tenantId => _tenantId;
  String? get tenantNameAr => _tenantNameAr;
  String? get tenantSlug => _tenantSlug;
  Map<String, dynamic>? get tenantSettings => _tenantSettings;
  List<Map<String, dynamic>> get entities => List.unmodifiable(_entities);
  List<Map<String, dynamic>> get branches => List.unmodifiable(_branches);
  String get baseCurrency =>
      _tenantSettings?['base_currency'] as String? ?? 'SAR';

  // ── Per-screen helpers ──────────────────────────────────────────────

  /// Resolve the currently-selected Pilot entity ID from the V5 scope
  /// controller. Returns null if no mapping exists yet.
  String? resolvePilotEntityId() {
    final selected = v5.EntityScopeController.instance.selected;
    if (selected.isEmpty) return null;
    final first = selected.first;
    // direct match (demoEntities id = pilot entity id) or mapped
    return _v5ToPilotEntity[first] ?? first;
  }

  /// The pilot entity object (raw JSON map) currently selected, if any.
  Map<String, dynamic>? get currentPilotEntity {
    final eid = resolvePilotEntityId();
    if (eid == null) return null;
    for (final e in _entities) {
      if (e['id'] == eid) return e;
    }
    return null;
  }

  /// Branches in the currently-selected entity.
  List<Map<String, dynamic>> branchesForCurrentEntity() {
    final eid = resolvePilotEntityId();
    if (eid == null) return [];
    return _branches.where((b) => b['entity_id'] == eid).toList();
  }

  // ── Binding ─────────────────────────────────────────────────────────

  /// Bind a pilot tenant to this session. Loads tenant + entities + branches
  /// and updates the V5 EntityScopeController with the real list.
  Future<bool> bindTenant(String tenantId) async {
    final r = await _client.getTenant(tenantId);
    if (!r.success) {
      debugPrint('PilotBridge.bindTenant failed: ${r.error}');
      return false;
    }
    final t = r.data as Map;
    _tenantId = t['id'];
    _tenantNameAr = t['legal_name_ar'];
    _tenantSlug = t['slug'];

    // fetch settings (non-fatal if fails)
    final s = await _client.getTenantSettings(tenantId);
    if (s.success) {
      _tenantSettings = Map<String, dynamic>.from(s.data);
    }

    // fetch all entities
    final e = await _client.listEntities(tenantId);
    _entities = e.success ? List<Map<String, dynamic>>.from(e.data) : [];

    // fetch all branches across all entities (parallel)
    final futures = _entities.map((ent) => _client.listBranches(ent['id']));
    final results = await Future.wait(futures);
    _branches = [];
    for (final r in results) {
      if (r.success) _branches.addAll(List<Map<String, dynamic>>.from(r.data));
    }

    // sync V5 EntityScopeController with real entities
    _syncV5EntityController();

    notifyListeners();
    return true;
  }

  /// Rebuilds the V5 demoEntities-equivalent list from the real pilot
  /// entities, and selects the first one.
  void _syncV5EntityController() {
    _v5ToPilotEntity.clear();
    for (final ent in _entities) {
      _v5ToPilotEntity[ent['id']] = ent['id'];
    }
    // Reset scope to single-mode on the first entity
    if (_entities.isNotEmpty) {
      final firstId = _entities.first['id'] as String;
      v5.EntityScopeController.instance.setSingle(firstId);
    }
  }

  /// Expose real entities as V5 Entity objects (for use by entity selector UI).
  List<v5.Entity> toV5Entities() {
    return _entities.map((e) {
      return v5.Entity(
        id: e['id'] as String,
        labelAr: e['name_ar'] as String? ?? e['code'] as String,
        labelEn: e['name_en'] as String? ?? e['code'] as String,
        currency: e['functional_currency'] as String? ?? 'SAR',
        country: e['country'] as String? ?? 'SA',
        kind: v5.EntityKind.subsidiary,
      );
    }).toList();
  }

  /// Unbind + reset everything.
  void unbind() {
    _tenantId = null;
    _tenantNameAr = null;
    _tenantSlug = null;
    _tenantSettings = null;
    _entities = [];
    _branches = [];
    _v5ToPilotEntity.clear();
    notifyListeners();
  }
}

/// InheritedNotifier wrapper for Flutter widgets that want to rebuild
/// when the bridge changes (without depending on Riverpod).
class PilotBridgeScope extends StatefulWidget {
  final Widget child;
  const PilotBridgeScope({super.key, required this.child});

  @override
  State<PilotBridgeScope> createState() => _PilotBridgeScopeState();
}

class _PilotBridgeScopeState extends State<PilotBridgeScope> {
  @override
  void initState() {
    super.initState();
    PilotBridge.instance.addListener(_onChanged);
    v5.EntityScopeController.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    PilotBridge.instance.removeListener(_onChanged);
    v5.EntityScopeController.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
