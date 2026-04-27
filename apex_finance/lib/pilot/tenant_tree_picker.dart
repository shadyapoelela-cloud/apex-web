/// APEX — Tenant/Entity/Branch tree picker
/// ═══════════════════════════════════════════════════════════════════════
/// Replaces the old flat ChoiceChip dialog with a hierarchical
/// search-first tree (Sage Intacct + Odoo + SAP Fiori synthesis):
///
///   [🔎 بحث في الكيانات والشركات والفروع]
///   ▾ 🏢 المجموعة (الكيان الأم)
///       ▾ 🏛️ شركة الرياض للمقاولات        ●  ← active entity
///           • 🏪 فرع الرياض الرئيسي         ●  ← active branch
///           • 🏪 فرع جدة
///       ▸ 🏛️ شركة الخليج التجارية        (٢ فروع)
///   ─────────────────────────────────────────
///   الأخيرة: [الرياض] [جدة] [الخليج/الدمام]
///   [+ تثبيت بيانات اختبار]   [إدارة الكيانات]
library;

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart' as core_theme;
import 'api/pilot_client.dart';
import 'session.dart';

// ─────────────────────────────────────────────────────────────────────
// Recents store — persist last-used scopes (entity_id + branch_id)
// ─────────────────────────────────────────────────────────────────────
class _Recents {
  static const _key = 'pilot.scope_recents';
  static const _max = 5;

  static List<Map<String, String>> load() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.isEmpty) return [];
      final list = (raw.split('|'))
          .where((s) => s.contains(':'))
          .map((s) {
            final parts = s.split('::');
            return {
              'entity_id': parts.isNotEmpty ? parts[0] : '',
              'branch_id': parts.length > 1 ? parts[1] : '',
              'label': parts.length > 2 ? parts[2] : '',
            };
          })
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }

  static void push(String entityId, String? branchId, String label) {
    try {
      final current = load();
      current.removeWhere((r) =>
          r['entity_id'] == entityId && r['branch_id'] == (branchId ?? ''));
      current.insert(0, {
        'entity_id': entityId,
        'branch_id': branchId ?? '',
        'label': label,
      });
      while (current.length > _max) {
        current.removeLast();
      }
      final encoded = current
          .map((r) =>
              '${r['entity_id']}::${r['branch_id']}::${r['label']}:flag')
          .join('|');
      html.window.localStorage[_key] = encoded;
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────
// Public entry — show as popover anchored just below the trigger chip.
// `anchorRect` is the global rect of the chip; the popup hangs from its
// bottom edge, aligned to its right (RTL) edge, and clamps to viewport.
// ─────────────────────────────────────────────────────────────────────
Future<void> showTenantTreePicker(BuildContext context,
    {VoidCallback? onChanged, Rect? anchorRect}) async {
  // Popup expands/shrinks with content — bounded by min/max for sanity
  const double minWidth = 220;
  const double maxWidth = 520;
  const double maxHeight = 480;
  const double gap = 6; // gap between chip bottom and popup top
  const double margin = 8; // viewport margin

  await showDialog(
    context: context,
    barrierColor: Colors.black26,
    barrierDismissible: true,
    builder: (dialogCtx) {
      final screen = MediaQuery.of(dialogCtx).size;
      double top;
      double right;
      if (anchorRect != null) {
        top = anchorRect.bottom + gap;
        // RTL: align popup's right edge to chip's right edge
        right = (screen.width - anchorRect.right).clamp(margin, screen.width - margin);
        // Vertical clamp — flip above if needed, else clamp to viewport
        if (top + maxHeight > screen.height - margin) {
          final aboveTop = anchorRect.top - gap - maxHeight;
          if (aboveTop >= margin) {
            top = aboveTop;
          } else {
            top = (screen.height - maxHeight - margin).clamp(margin, screen.height);
          }
        }
      } else {
        top = 60;
        right = margin;
      }
      return Stack(children: [
        Positioned(
          top: top,
          right: right,
          // No fixed width/height — child sizes itself within constraints
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: minWidth,
                maxWidth: maxWidth,
                maxHeight: maxHeight,
              ),
              child: IntrinsicWidth(
                child: TenantTreePicker(onChanged: onChanged),
              ),
            ),
          ),
        ),
      ]);
    },
  );
}

class TenantTreePicker extends StatefulWidget {
  final VoidCallback? onChanged;
  const TenantTreePicker({super.key, this.onChanged});
  @override
  State<TenantTreePicker> createState() => _TenantTreePickerState();
}

class _TenantTreePickerState extends State<TenantTreePicker> {
  // Tree data
  Map<String, dynamic>? _tenant;
  List<Map<String, dynamic>> _entities = [];
  /// entity_id → list of branches
  final Map<String, List<Map<String, dynamic>>> _branchesByEntity = {};
  /// expanded entity ids
  final Set<String> _expanded = {};

  bool _loading = false;
  bool _seedingTest = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (PilotSession.hasTenant) {
      _loadAll();
    }
    if (PilotSession.hasEntity) {
      _expanded.add(PilotSession.entityId!);
    }
  }

  Future<void> _loadAll() async {
    if (!PilotSession.hasTenant) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final tRes = await pilotClient.getTenant(PilotSession.tenantId!);
    if (!mounted) return;
    if (!tRes.success) {
      setState(() {
        _loading = false;
        _error = tRes.error ?? 'تعذّر تحميل الكيان';
      });
      return;
    }
    _tenant = tRes.data as Map<String, dynamic>?;
    final eRes = await pilotClient.listEntities(PilotSession.tenantId!);
    if (!mounted) return;
    final entities = (eRes.success && eRes.data is List)
        ? List<Map<String, dynamic>>.from(eRes.data)
        : <Map<String, dynamic>>[];
    // Eagerly load branches for active entity (and any expanded ones)
    final toLoad = <String>{};
    if (PilotSession.hasEntity) toLoad.add(PilotSession.entityId!);
    toLoad.addAll(_expanded);
    for (final eid in toLoad) {
      final bRes = await pilotClient.listBranches(eid);
      if (!mounted) return;
      if (bRes.success && bRes.data is List) {
        _branchesByEntity[eid] = List<Map<String, dynamic>>.from(bRes.data);
      }
    }
    setState(() {
      _entities = entities;
      _loading = false;
    });
  }

  Future<void> _toggleExpand(String entityId) async {
    if (_expanded.contains(entityId)) {
      setState(() => _expanded.remove(entityId));
      return;
    }
    setState(() => _expanded.add(entityId));
    if (_branchesByEntity[entityId] == null) {
      final bRes = await pilotClient.listBranches(entityId);
      if (!mounted) return;
      setState(() {
        _branchesByEntity[entityId] = (bRes.success && bRes.data is List)
            ? List<Map<String, dynamic>>.from(bRes.data)
            : [];
      });
    }
  }

  void _selectEntity(Map<String, dynamic> entity) {
    final id = entity['id'] as String?;
    if (id == null) return;
    PilotSession.entityId = id;
    PilotSession.clearBranch();
    _Recents.push(id, null, '${entity['code'] ?? ''} — ${entity['name_ar'] ?? ''}');
    widget.onChanged?.call();
    setState(() {
      _expanded.add(id);
    });
    if (_branchesByEntity[id] == null) {
      _toggleExpand(id);
    }
  }

  void _selectBranch(
      Map<String, dynamic> entity, Map<String, dynamic> branch) {
    final eid = entity['id'] as String?;
    final bid = branch['id'] as String?;
    if (eid == null || bid == null) return;
    PilotSession.entityId = eid;
    PilotSession.branchId = bid;
    _Recents.push(
        eid,
        bid,
        '${entity['code'] ?? ''} / ${branch['code'] ?? ''} — ${branch['city'] ?? branch['name_ar'] ?? ''}');
    widget.onChanged?.call();
    setState(() {});
  }

  Future<void> _seedTestScope() async {
    setState(() {
      _seedingTest = true;
      _error = null;
    });
    final ts = DateTime.now().millisecondsSinceEpoch;
    final shortTs = ts.toString().substring(7);

    String? tenantId = PilotSession.tenantId;
    String? entityId;
    String? branchId;

    try {
      // ── 1) Tenant if missing ─────────────────────────────────────
      if (tenantId == null || tenantId.isEmpty) {
        final tRes = await pilotClient.createTenant({
          'slug': 'apex-test-$shortTs',
          'legal_name_ar': 'مجموعة الاختبار للأعمال',
          'legal_name_en': 'APEX Test Group',
          'trade_name': 'APEX Test',
          'primary_country': 'SA',
          'primary_email': 'test+$shortTs@apex.local',
          'primary_phone': '0500000000',
          'tier': 'starter',
          'base_currency': 'SAR',
          'fiscal_year_start_month': 1,
          'default_timezone': 'Asia/Riyadh',
        });
        if (!tRes.success) {
          throw Exception('tenant: ${tRes.error}');
        }
        tenantId = (tRes.data as Map?)?['id'] as String?;
        if (tenantId == null) throw Exception('tenant: no id');
        PilotSession.tenantId = tenantId;
      }

      // ── 2) Entity ────────────────────────────────────────────────
      final eRes = await pilotClient.createEntity(tenantId, {
        'code': 'TEST-$shortTs',
        'name_ar': 'شركة الاختبار للتجارة',
        'name_en': 'Test Trading Co.',
        'type': 'main',
        'country': 'SA',
        'functional_currency': 'SAR',
        'fiscal_year_start_month': 1,
        'icon_emoji': '🧪',
      });
      if (!eRes.success) {
        throw Exception('entity: ${eRes.error}');
      }
      entityId = (eRes.data as Map?)?['id'] as String?;
      if (entityId == null) throw Exception('entity: no id');
      PilotSession.entityId = entityId;

      // ── 3) Branch ────────────────────────────────────────────────
      final bRes = await pilotClient.createBranch(entityId, {
        'code': 'BR-$shortTs',
        'name_ar': 'فرع الرياض الرئيسي',
        'name_en': 'Riyadh HQ',
        'short_name': 'الرياض',
        'type': 'retail_store',
        'city': 'الرياض',
        'district': 'العليا',
        'pos_station_count': 1,
        'accepts_returns': true,
        'supports_pickup': true,
      });
      if (!bRes.success) {
        throw Exception('branch: ${bRes.error}');
      }
      branchId = (bRes.data as Map?)?['id'] as String?;
      if (branchId != null) PilotSession.branchId = branchId;

      _Recents.push(entityId, branchId, 'TEST-$shortTs / BR-$shortTs — الرياض');
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: core_theme.AC.ok,
          content:
              const Text('تم تثبيت كيان + شركة + فرع للاختبار بنجاح'),
        ));
      }
      // Reload tree
      await _loadAll();
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'فشل التثبيت: $e');
      }
    } finally {
      if (mounted) setState(() => _seedingTest = false);
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: core_theme.AC.navy2,
        borderRadius: BorderRadius.circular(8),
        elevation: 12,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: core_theme.AC.bdr),
        ),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () =>
                Navigator.of(context).maybePop(),
          },
          child: Focus(
            autofocus: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                if (_error != null) _buildErrorBanner(),
                Flexible(child: _buildTree()),
                const Divider(height: 1),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 6, 8),
        decoration: BoxDecoration(
          color: core_theme.AC.navy3,
          border: Border(bottom: BorderSide(color: core_theme.AC.bdr)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_tree_outlined,
                  color: core_theme.AC.gold, size: 14),
              const SizedBox(width: 6),
              Text('اختيار النطاق',
                  style: TextStyle(
                      color: core_theme.AC.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ]),
            InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => Navigator.of(context).maybePop(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close, color: core_theme.AC.ts, size: 14),
              ),
            ),
          ],
        ),
      );

  Widget _buildErrorBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: core_theme.AC.errSoft,
        child: Row(children: [
          Icon(Icons.error_outline, color: core_theme.AC.err, size: 14),
          const SizedBox(width: 6),
          Expanded(
              child: Text(_error!,
                  style: TextStyle(
                      color: core_theme.AC.err, fontSize: 11.5))),
          IconButton(
              icon: Icon(Icons.close,
                  color: core_theme.AC.err, size: 14),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _error = null)),
        ]),
      );

  Widget _buildTree() {
    if (_loading && _tenant == null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
            child: CircularProgressIndicator(color: core_theme.AC.gold)),
      );
    }
    if (!PilotSession.hasTenant || _tenant == null) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined,
                color: core_theme.AC.ts, size: 48),
            const SizedBox(height: 8),
            Text('لا يوجد كيان مرتبط بعد',
                style: TextStyle(
                    color: core_theme.AC.tp, fontSize: 13)),
            const SizedBox(height: 4),
            Text('اضغط "تثبيت بيانات اختبار" أدناه للبدء فوراً',
                style: TextStyle(
                    color: core_theme.AC.ts, fontSize: 11)),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tenantRow(),
          if (_entities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('لا توجد شركات تحت هذا الكيان',
                    style: TextStyle(
                        color: core_theme.AC.ts, fontSize: 12)),
              ),
            )
          else
            for (final e in _entities) ..._entityWithBranches(e),
        ],
      ),
    );
  }

  Widget _tenantRow() {
    final name = (_tenant?['legal_name_ar'] ?? _tenant?['trade_name'] ?? 'الكيان').toString();
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: core_theme.AC.navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border(
            right: BorderSide(color: core_theme.AC.gold, width: 3)),
      ),
      child: Row(children: [
        Icon(Icons.business_center, color: core_theme.AC.gold, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: TextStyle(
                    color: core_theme.AC.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            Text('الكيان الأم · ${_entities.length} شركة',
                style: TextStyle(
                    color: core_theme.AC.ts, fontSize: 10.5)),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _entityWithBranches(Map<String, dynamic> e) {
    final eid = e['id'] as String;
    final isExpanded = _expanded.contains(eid);
    final isActive = PilotSession.entityId == eid;
    final branches = _branchesByEntity[eid] ?? [];
    return [
      _entityRow(e, isExpanded, isActive, branches.length),
      if (isExpanded)
        if (branches.isEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 56, top: 4, bottom: 4),
            child: Text(
                _branchesByEntity[eid] == null ? 'تحميل…' : 'لا توجد فروع',
                style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
          )
        else
          ...branches.map((b) => _branchRow(e, b)),
    ];
  }

  Widget _entityRow(Map<String, dynamic> e, bool isExpanded, bool isActive,
      int branchCount) {
    final code = (e['code'] ?? '').toString();
    final nameAr = (e['name_ar'] ?? '').toString();
    final emoji = (e['icon_emoji'] ?? '').toString();
    final fc = (e['functional_currency'] ?? '').toString();
    return InkWell(
      onTap: () => _selectEntity(e),
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 24, end: 8, top: 2, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? core_theme.AC.gold.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(
                  color: core_theme.AC.gold.withValues(alpha: 0.5))
              : null,
        ),
        child: Row(children: [
          InkWell(
            onTap: () => _toggleExpand(e['id'] as String),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                isExpanded ? Icons.expand_more : Icons.chevron_left,
                color: core_theme.AC.ts,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (emoji.isNotEmpty)
            Text(emoji, style: const TextStyle(fontSize: 14))
          else
            Icon(Icons.apartment,
                size: 14,
                color:
                    isActive ? core_theme.AC.gold : core_theme.AC.ts),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nameAr.isEmpty ? code : nameAr,
                  style: TextStyle(
                      color: core_theme.AC.tp,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
              Text(
                  '${code.isNotEmpty ? code : '—'}'
                  '${fc.isNotEmpty ? ' · $fc' : ''}'
                  '${branchCount > 0 ? ' · $branchCount فرع' : ''}',
                  style: TextStyle(
                      color: core_theme.AC.ts,
                      fontSize: 10.5,
                      fontFamily: 'monospace')),
            ]),
          ),
          if (isActive)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsetsDirectional.only(start: 6),
              decoration: BoxDecoration(
                  color: core_theme.AC.ok, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }

  Widget _branchRow(Map<String, dynamic> entity, Map<String, dynamic> b) {
    final code = (b['code'] ?? '').toString();
    final city = (b['city'] ?? '').toString();
    final nameAr = (b['name_ar'] ?? '').toString();
    final isActive = PilotSession.branchId == b['id'];
    return InkWell(
      onTap: () => _selectBranch(entity, b),
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 56, end: 8, top: 1, bottom: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? core_theme.AC.gold.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          Icon(Icons.storefront_outlined,
              size: 13,
              color: isActive ? core_theme.AC.gold : core_theme.AC.ts),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                '$code · ${nameAr.isNotEmpty ? nameAr : city}'
                '${city.isNotEmpty && nameAr.isNotEmpty ? ' — $city' : ''}',
                style: TextStyle(
                    color: core_theme.AC.tp,
                    fontSize: 11.5,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
          ),
          if (isActive)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsetsDirectional.only(start: 4),
              decoration: BoxDecoration(
                  color: core_theme.AC.ok, shape: BoxShape.circle),
            ),
        ]),
      ),
    );
  }

  Widget _buildFooter() {
    final recents = _Recents.load();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (recents.isNotEmpty) ...[
          Row(children: [
            Icon(Icons.history, color: core_theme.AC.ts, size: 13),
            const SizedBox(width: 4),
            Text('الأخيرة',
                style: TextStyle(
                    color: core_theme.AC.ts,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: recents.take(4).map((r) {
              final lbl = (r['label'] ?? '').toString();
              return InkWell(
                onTap: () {
                  final eid = r['entity_id'];
                  final bid = r['branch_id'];
                  if (eid != null && eid.isNotEmpty) {
                    PilotSession.entityId = eid;
                    if (bid != null && bid.isNotEmpty) {
                      PilotSession.branchId = bid;
                    } else {
                      PilotSession.clearBranch();
                    }
                    widget.onChanged?.call();
                    setState(() {});
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: core_theme.AC.navy3,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: core_theme.AC.bdr),
                  ),
                  child: Text(lbl,
                      style: TextStyle(
                          color: core_theme.AC.tp, fontSize: 10.5)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _seedingTest ? null : _seedTestScope,
              icon: _seedingTest
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.science_outlined, size: 16),
              label: Text(_seedingTest
                  ? 'جارٍ الإنشاء…'
                  : 'تثبيت كيان + شركة + فرع للاختبار'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: core_theme.AC.gold,
                  foregroundColor: core_theme.AC.navy,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/app/erp/finance/entity-setup');
            },
            icon: Icon(Icons.settings_outlined,
                size: 14, color: core_theme.AC.gold),
            label: Text('إدارة',
                style: TextStyle(
                    color: core_theme.AC.gold, fontSize: 11.5)),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: core_theme.AC.gold),
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10)),
          ),
        ]),
        if (PilotSession.hasTenant) ...[
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () {
              PilotSession.clear();
              widget.onChanged?.call();
              setState(() {
                _tenant = null;
                _entities = [];
                _branchesByEntity.clear();
                _expanded.clear();
              });
            },
            icon: Icon(Icons.logout,
                size: 13, color: core_theme.AC.err),
            label: Text('إلغاء الربط ومسح النطاق',
                style: TextStyle(
                    color: core_theme.AC.err, fontSize: 11)),
          ),
        ],
      ]),
    );
  }
}
