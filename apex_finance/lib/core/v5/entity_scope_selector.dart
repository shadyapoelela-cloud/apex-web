/// APEX V5.1 — Entity Scope Selector (Wave 147).
///
/// A top-bar widget that controls the **consolidation scope** for the
/// entire app. All screens filter by the entities selected here.
///
/// Modes:
///   1. **Single entity** — operations on one company
///   2. **Multi-entity** — consolidation across N entities
///   3. **All entities** — group-wide view
///
/// Visual design matches SAP Fiori + NetSuite patterns:
///   - Compact chip in the top bar showing current scope
///   - Click opens a dropdown with hierarchy tree + multi-select
///   - Group/consolidated totals vs. single-entity drilldown
///   - FX conversion indicator when entities span currencies
///
/// Global state is held by [EntityScopeController] (ChangeNotifier).
/// Any screen can listen via `EntityScopeController.instance` and
/// rebuild when scope changes.
library;

import 'package:flutter/material.dart';

// ──────────────────────────────────────────────────────────────────────
// Data model — entity tree
// ──────────────────────────────────────────────────────────────────────

/// A legal entity (company / branch / sub).
@immutable
class Entity {
  final String id;
  final String labelAr;
  final String labelEn;
  final String currency; // ISO 4217 — SAR, USD, AED...
  final String country; // ISO 3166 alpha-2 — SA, AE, EG...
  final String? parentId; // null = top-level holding
  final EntityKind kind;

  const Entity({
    required this.id,
    required this.labelAr,
    required this.labelEn,
    required this.currency,
    required this.country,
    required this.kind,
    this.parentId,
  });
}

enum EntityKind {
  holding, // قابضة
  subsidiary, // تابعة
  associate, // زميلة
  jointVenture, // مشروع مشترك
  branch, // فرع
}

/// Demo entity tree — production loads from `/entities/tree` endpoint.
const demoEntities = <Entity>[
  Entity(
    id: 'apex-group',
    labelAr: 'مجموعة أبكس القابضة',
    labelEn: 'APEX Holding Group',
    currency: 'SAR',
    country: 'SA',
    kind: EntityKind.holding,
  ),
  Entity(
    id: 'apex-ksa',
    labelAr: 'أبكس المملكة العربية السعودية',
    labelEn: 'APEX KSA Co.',
    currency: 'SAR',
    country: 'SA',
    parentId: 'apex-group',
    kind: EntityKind.subsidiary,
  ),
  Entity(
    id: 'apex-uae',
    labelAr: 'أبكس الإمارات',
    labelEn: 'APEX UAE LLC',
    currency: 'AED',
    country: 'AE',
    parentId: 'apex-group',
    kind: EntityKind.subsidiary,
  ),
  Entity(
    id: 'apex-eg',
    labelAr: 'أبكس مصر',
    labelEn: 'APEX Egypt S.A.E.',
    currency: 'EGP',
    country: 'EG',
    parentId: 'apex-group',
    kind: EntityKind.subsidiary,
  ),
  Entity(
    id: 'apex-kw',
    labelAr: 'أبكس الكويت',
    labelEn: 'APEX Kuwait W.L.L.',
    currency: 'KWD',
    country: 'KW',
    parentId: 'apex-group',
    kind: EntityKind.associate,
  ),
  Entity(
    id: 'apex-ksa-riyadh',
    labelAr: 'فرع الرياض',
    labelEn: 'Riyadh Branch',
    currency: 'SAR',
    country: 'SA',
    parentId: 'apex-ksa',
    kind: EntityKind.branch,
  ),
  Entity(
    id: 'apex-ksa-jeddah',
    labelAr: 'فرع جدة',
    labelEn: 'Jeddah Branch',
    currency: 'SAR',
    country: 'SA',
    parentId: 'apex-ksa',
    kind: EntityKind.branch,
  ),
];

// ──────────────────────────────────────────────────────────────────────
// Controller — global scope state
// ──────────────────────────────────────────────────────────────────────

enum ScopeMode {
  single, // one entity
  multi, // selected set
  all, // entire group
}

class EntityScopeController extends ChangeNotifier {
  EntityScopeController._();
  static final EntityScopeController instance = EntityScopeController._();

  ScopeMode _mode = ScopeMode.single;
  Set<String> _selected = {'apex-ksa'};
  String _reportingCurrency = 'SAR';

  ScopeMode get mode => _mode;
  Set<String> get selected => Set.unmodifiable(_selected);
  String get reportingCurrency => _reportingCurrency;

  /// All entities that match current scope.
  List<Entity> get scopedEntities {
    switch (_mode) {
      case ScopeMode.all:
        return demoEntities;
      case ScopeMode.single:
      case ScopeMode.multi:
        return demoEntities.where((e) => _selected.contains(e.id)).toList();
    }
  }

  /// Human-readable label for the current scope.
  String get scopeLabelAr {
    switch (_mode) {
      case ScopeMode.all:
        return 'جميع الكيانات (${demoEntities.length})';
      case ScopeMode.single:
        if (_selected.length == 1) {
          final e = demoEntities.firstWhere(
            (e) => e.id == _selected.first,
            orElse: () => demoEntities.first,
          );
          return e.labelAr;
        }
        return 'كيان واحد';
      case ScopeMode.multi:
        return '${_selected.length} كيانات مُوحّدة';
    }
  }

  bool isScopeConsolidated() => _mode == ScopeMode.all || _selected.length > 1;

  bool hasMixedCurrencies() {
    final currencies = scopedEntities.map((e) => e.currency).toSet();
    return currencies.length > 1;
  }

  void setSingle(String entityId) {
    _mode = ScopeMode.single;
    _selected = {entityId};
    notifyListeners();
  }

  void setAll() {
    _mode = ScopeMode.all;
    _selected = demoEntities.map((e) => e.id).toSet();
    notifyListeners();
  }

  void setMulti(Set<String> ids) {
    if (ids.isEmpty) return;
    _mode = ids.length == 1 ? ScopeMode.single : ScopeMode.multi;
    _selected = Set.of(ids);
    notifyListeners();
  }

  void setReportingCurrency(String currency) {
    _reportingCurrency = currency;
    notifyListeners();
  }
}

// ──────────────────────────────────────────────────────────────────────
// UI — top-bar chip + popover
// ──────────────────────────────────────────────────────────────────────

class EntityScopeSelector extends StatefulWidget {
  const EntityScopeSelector({super.key});

  @override
  State<EntityScopeSelector> createState() => _EntityScopeSelectorState();
}

class _EntityScopeSelectorState extends State<EntityScopeSelector> {
  @override
  void initState() {
    super.initState();
    EntityScopeController.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    EntityScopeController.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = EntityScopeController.instance;
    final consolidated = ctrl.isScopeConsolidated();
    final mixedCurrency = ctrl.hasMixedCurrencies();

    // Auto-adapt to dark/light background using Theme brightness.
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final baseForeground = isDark ? Colors.white : Colors.black87;
    final baseSubtle = isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.04);
    final baseBorder = isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.12);

    return InkWell(
      onTap: () => _openPopover(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: consolidated
              ? const Color(0xFFD4AF37).withOpacity(0.12)
              : baseSubtle,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: consolidated ? const Color(0xFFD4AF37) : baseBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              consolidated ? Icons.merge : Icons.business,
              size: 14,
              color: consolidated ? const Color(0xFFB8860B) : baseForeground,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                ctrl.scopeLabelAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: consolidated ? const Color(0xFFB8860B) : baseForeground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (mixedCurrency) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                ),
                child: Text(
                  'FX→${ctrl.reportingCurrency}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 16,
              color: consolidated ? const Color(0xFFB8860B) : baseForeground,
            ),
          ],
        ),
      ),
    );
  }

  void _openPopover(BuildContext context) {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);
    final size = button.size;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) {
        return Stack(
          children: [
            Positioned(
              top: offset.dy + size.height + 8,
              right: MediaQuery.of(ctx).size.width - offset.dx - size.width,
              child: const _ScopePopover(),
            ),
          ],
        );
      },
    );
  }
}

class _ScopePopover extends StatefulWidget {
  const _ScopePopover();

  @override
  State<_ScopePopover> createState() => _ScopePopoverState();
}

class _ScopePopoverState extends State<_ScopePopover> {
  late Set<String> _selected;
  late ScopeMode _mode;
  late String _currency;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(EntityScopeController.instance.selected);
    _mode = EntityScopeController.instance.mode;
    _currency = EntityScopeController.instance.reportingCurrency;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 420,
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF4A148C)],
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_tree, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'نطاق الكيانات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Quick mode buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeButton(
                        label: 'كيان واحد',
                        icon: Icons.business,
                        active: _mode == ScopeMode.single,
                        onTap: () => setState(() {
                          _mode = ScopeMode.single;
                          if (_selected.isEmpty) {
                            _selected = {demoEntities.first.id};
                          } else if (_selected.length > 1) {
                            _selected = {_selected.first};
                          }
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeButton(
                        label: 'تعدد كيانات',
                        icon: Icons.merge,
                        active: _mode == ScopeMode.multi,
                        onTap: () => setState(() => _mode = ScopeMode.multi),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeButton(
                        label: 'المجموعة',
                        icon: Icons.account_tree,
                        active: _mode == ScopeMode.all,
                        onTap: () => setState(() {
                          _mode = ScopeMode.all;
                          _selected = demoEntities.map((e) => e.id).toSet();
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Entity tree
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: _buildEntityTree(),
                  ),
                ),
              ),

              const Divider(height: 1),

              // Reporting currency (only when multi/all)
              if (_mode != ScopeMode.single)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.currency_exchange, size: 16, color: Colors.black54),
                      const SizedBox(width: 8),
                      const Text('عملة التقرير:', style: TextStyle(fontSize: 12, color: Colors.black87)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _currency,
                          isDense: true,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: const [
                            DropdownMenuItem(value: 'SAR', child: Text('ر.س — SAR')),
                            DropdownMenuItem(value: 'USD', child: Text('دولار — USD')),
                            DropdownMenuItem(value: 'AED', child: Text('د.إ — AED')),
                            DropdownMenuItem(value: 'EUR', child: Text('يورو — EUR')),
                          ],
                          onChanged: (v) => setState(() => _currency = v ?? 'SAR'),
                        ),
                      ),
                    ],
                  ),
                ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                        ),
                        onPressed: () {
                          final ctrl = EntityScopeController.instance;
                          ctrl.setReportingCurrency(_currency);
                          if (_mode == ScopeMode.all) {
                            ctrl.setAll();
                          } else if (_mode == ScopeMode.single && _selected.isNotEmpty) {
                            ctrl.setSingle(_selected.first);
                          } else {
                            ctrl.setMulti(_selected);
                          }
                          Navigator.of(context).pop();
                        },
                        child: const Text('تطبيق'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEntityTree() {
    final tops = demoEntities.where((e) => e.parentId == null).toList();
    final rows = <Widget>[];
    for (final top in tops) {
      rows.add(_buildEntityRow(top, 0));
      for (final c in demoEntities.where((e) => e.parentId == top.id)) {
        rows.add(_buildEntityRow(c, 1));
        for (final gc in demoEntities.where((e) => e.parentId == c.id)) {
          rows.add(_buildEntityRow(gc, 2));
        }
      }
    }
    return rows;
  }

  Widget _buildEntityRow(Entity e, int depth) {
    final selected = _selected.contains(e.id);
    final disabled = _mode == ScopeMode.all;
    return InkWell(
      onTap: disabled
          ? null
          : () => setState(() {
                if (_mode == ScopeMode.single) {
                  _selected = {e.id};
                } else {
                  if (selected) {
                    _selected.remove(e.id);
                  } else {
                    _selected.add(e.id);
                  }
                }
              }),
      child: Container(
        padding: EdgeInsetsDirectional.only(
          start: 16.0 + (depth * 22.0),
          end: 16,
          top: 8,
          bottom: 8,
        ),
        color: selected ? const Color(0xFFD4AF37).withOpacity(0.08) : null,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: _mode == ScopeMode.single
                  ? Radio<String>(
                      value: e.id,
                      groupValue: _selected.isEmpty ? null : _selected.first,
                      onChanged: disabled
                          ? null
                          : (v) => setState(() => _selected = {v ?? e.id}),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  : Checkbox(
                      value: selected,
                      onChanged: disabled
                          ? null
                          : (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(e.id);
                                } else {
                                  _selected.remove(e.id);
                                }
                              });
                            },
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
            ),
            const SizedBox(width: 8),
            Icon(_kindIcon(e.kind), size: 16, color: _kindColor(e.kind)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.labelAr,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${e.labelEn} · ${e.currency} · ${e.country}',
                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _kindColor(e.kind).withOpacity(0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _kindLabelAr(e.kind),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _kindColor(e.kind),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _kindIcon(EntityKind k) {
    switch (k) {
      case EntityKind.holding:
        return Icons.account_tree;
      case EntityKind.subsidiary:
        return Icons.business;
      case EntityKind.associate:
        return Icons.handshake;
      case EntityKind.jointVenture:
        return Icons.group_work;
      case EntityKind.branch:
        return Icons.store;
    }
  }

  Color _kindColor(EntityKind k) {
    switch (k) {
      case EntityKind.holding:
        return const Color(0xFF4A148C);
      case EntityKind.subsidiary:
        return const Color(0xFF1565C0);
      case EntityKind.associate:
        return const Color(0xFF2E7D5B);
      case EntityKind.jointVenture:
        return const Color(0xFFD4AF37);
      case EntityKind.branch:
        return Colors.black54;
    }
  }

  String _kindLabelAr(EntityKind k) {
    switch (k) {
      case EntityKind.holding:
        return 'قابضة';
      case EntityKind.subsidiary:
        return 'تابعة';
      case EntityKind.associate:
        return 'زميلة';
      case EntityKind.jointVenture:
        return 'مشروع مشترك';
      case EntityKind.branch:
        return 'فرع';
    }
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFD4AF37).withOpacity(0.12) : Colors.grey.shade50,
          border: Border.all(
            color: active ? const Color(0xFFD4AF37) : Colors.grey.shade300,
            width: active ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? const Color(0xFFD4AF37) : Colors.black54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? const Color(0xFFD4AF37) : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
