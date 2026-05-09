/// APEX Platform — Unified Entity / Company / Branch Setup Screen
/// ════════════════════════════════════════════════════════════════════
/// SINGLE entry point for setting up:
///   • Entities (مجموعات / كيانات قابضة) — optional grouping container
///   • Companies (شركات) — legal entities, local OR international
///   • Branches (فروع) — operational units with independent controls
///
/// Design synthesis of 13-round research:
///   • Oracle Fusion / Sage Intacct → tree view + detail pane
///   • SAP S/4HANA / NetSuite → country + currency per company
///   • Odoo 17 → branches share legal entity but have own addresses
///   • ZATCA → optional seller branch code field per branch
///   • Workday / D365 → per-branch independence toggles
///   • Carbon / PatternFly → accessible tree UI with keyboard nav
///
/// Route: /settings/entities
/// ════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/entity_store.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../pilot/api/pilot_client.dart';
import '../../pilot/session.dart';

class EntitySetupScreen extends StatefulWidget {
  /// Optional initial action: 'new-entity' / 'new-company' / 'new-branch'
  final String? initialAction;
  const EntitySetupScreen({super.key, this.initialAction});

  @override
  State<EntitySetupScreen> createState() => _EntitySetupScreenState();
}

/// G-ERP-UNIFICATION (2026-05-09): result of a one-shot migration of
/// localStorage companies + branches to the pilot ERP via
/// `pilotClient.createEntity` + `createBranch`. Surfaced in the UI
/// after the migration completes so the user sees exactly which
/// records made it through and which didn't.
class _MigrationResult {
  int entitiesOk = 0;
  int entitiesFail = 0;
  int branchesOk = 0;
  int branchesFail = 0;
  final List<String> failures = <String>[];

  bool get hasFailures => entitiesFail > 0 || branchesFail > 0;
  int get totalOk => entitiesOk + branchesOk;
  int get totalFail => entitiesFail + branchesFail;
}

class _EntitySetupScreenState extends State<EntitySetupScreen> {
  // Expanded state per entity id
  final Set<String> _expanded = {};
  // Expanded state per company id
  final Set<String> _expandedCompanies = {};

  List<EntityRecord> _entities = [];
  List<CompanyRecord> _companies = [];
  List<BranchRecord> _branches = [];

  // G-ERP-UNIFICATION (2026-05-09): migration UI state.
  bool _migrating = false;
  String? _migrationStatus;

  @override
  void initState() {
    super.initState();
    _reload();
    // Auto-trigger create modal if requested via route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.initialAction) {
        case 'new-entity':
          _editEntity(null);
          break;
        case 'new-company':
          _editCompany(null);
          break;
        case 'new-branch':
          if (_companies.isNotEmpty) _editBranch(null, _companies.first);
          break;
      }
    });
  }

  void _reload() {
    setState(() {
      _entities = EntityStore.listEntities();
      _companies = EntityStore.listCompanies();
      _branches = EntityStore.listBranches();
      // Expand all by default on first load for discoverability.
      for (final e in _entities) {
        _expanded.add(e.id);
      }
      for (final c in _companies) {
        _expandedCompanies.add(c.id);
      }
    });
  }

  List<CompanyRecord> _companiesFor(String? entityId) =>
      _companies.where((c) => c.entityId == entityId).toList();

  List<BranchRecord> _branchesFor(String companyId) =>
      _branches.where((b) => b.companyId == companyId).toList();

  // ─────────────────────────────────────────────────────────────
  // Edit dialogs
  // ─────────────────────────────────────────────────────────────
  Future<void> _editEntity(EntityRecord? rec) async {
    final result = await showDialog<EntityRecord>(
      context: context,
      barrierColor: AC.sidebarScrim,
      builder: (_) => _EntityDialog(initial: rec),
    );
    if (result != null) _reload();
  }

  Future<void> _editCompany(CompanyRecord? rec, {String? lockedEntityId}) async {
    final result = await showDialog<CompanyRecord>(
      context: context,
      barrierColor: AC.sidebarScrim,
      builder: (_) => _CompanyDialog(
        initial: rec,
        entities: _entities,
        lockedEntityId: lockedEntityId,
      ),
    );
    if (result != null) _reload();
  }

  Future<void> _editBranch(BranchRecord? rec, CompanyRecord company) async {
    final result = await showDialog<BranchRecord>(
      context: context,
      barrierColor: AC.sidebarScrim,
      builder: (_) => _BranchDialog(initial: rec, company: company),
    );
    if (result != null) _reload();
  }

  Future<void> _confirmDelete(String titleAr, VoidCallback onYes) async {
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: AC.sidebarScrim,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.sidebarBg,
        title: Text('حذف $titleAr؟',
            style: TextStyle(color: AC.textStrong, fontSize: 16)),
        content: Text('هذا الإجراء لا يمكن التراجع عنه.',
            style: TextStyle(color: AC.textMedium, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: AC.textMedium))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AC.err, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes == true) {
      onYes();
      _reload();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final standaloneCompanies = _companiesFor(null);
    final hasAny =
        _entities.isNotEmpty || _companies.isNotEmpty || _branches.isNotEmpty;

    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        // G-ERP-UNIFICATION (2026-05-09): one-shot migration banner.
        // Shows whenever localStorage has any legacy companies or
        // entities. Two paths: "نعم، انقلها" calls _runMigration()
        // which POSTs each row to the pilot ERP via PilotClient and
        // then clears localStorage; "لا، تجاهل واحذف" wipes
        // localStorage after a confirmation dialog. After either
        // path completes, the user is sent to the unified onboarding
        // wizard (which now handles ALL entity creation server-side).
        if (hasAny) _buildMigrationBanner(),
        ApexStickyToolbar(
          title: 'إعداد الكيانات والشركات والفروع',
          actions: [
            ApexToolbarAction(
              label: 'كيان جديد',
              icon: Icons.corporate_fare_rounded,
              onPressed: () => _editEntity(null),
            ),
            ApexToolbarAction(
              label: 'شركة جديدة',
              icon: Icons.domain_add_rounded,
              onPressed: () => _editCompany(null),
              primary: true,
            ),
          ],
        ),
        // 2026 pattern: adaptive setup checklist with progress indicator
        if (hasAny) _buildSetupChecklist(),
        Expanded(
          child: !hasAny ? _buildEmptyState() : _buildTree(standaloneCompanies),
        ),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // G-ERP-UNIFICATION (2026-05-09) — migration banner + logic.
  //
  // The legacy entity_setup_screen wrote everything to localStorage.
  // Post-G-WIZARD-TENANT-FIX, every fresh user has a JWT-bound
  // tenant in the pilot ERP. This screen now exists ONLY to migrate
  // any pre-existing localStorage data into the ERP — once that's
  // done, an empty-store check in the router redirects future
  // visits straight to /app/erp/finance/onboarding.
  //
  // Files NOT deleted: entity_store.dart stays on disk so a future
  // rollback can re-read the localStorage keys (they're only wiped
  // on user confirmation in this banner — never automatically).
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMigrationBanner() {
    final companyCount = _companies.length;
    final branchCount = _branches.length;
    final hasTenant = PilotSession.hasTenant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AC.warn.withValues(alpha: 0.16),
        border: Border(bottom: BorderSide(color: AC.warn, width: 2)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined, color: AC.warn, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تم اكتشاف بيانات قديمة محفوظة محلياً',
                    style: TextStyle(
                      color: AC.tp,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'وجدنا $companyCount شركة + $branchCount فرع محفوظة محلياً '
                    '(نظام قديم). هل تريد نقلها إلى الـ ERP الرسمي؟ '
                    '(محفوظة في DB، آمنة، تظهر في القوائم المالية)',
                    style: TextStyle(color: AC.ts, fontSize: 12),
                  ),
                  if (!hasTenant) ...[
                    const SizedBox(height: 6),
                    Text(
                      '⚠️ لا يوجد كيان (tenant) نشط مرتبط بالجلسة. '
                      'افتح الـ ERP أولاً (سيُنشأ tenant من registration).',
                      style: TextStyle(
                        color: AC.err,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (_migrationStatus != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _migrationStatus!,
                      style: TextStyle(
                        color: AC.tp,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            // "Yes, migrate" — green, primary action.
            ElevatedButton.icon(
              icon: _migrating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_migrating ? 'جاري النقل...' : 'نعم، انقلها'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.ok,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onPressed:
                  (_migrating || !hasTenant) ? null : _runMigration,
            ),
            const SizedBox(width: 8),
            // "No, ignore and delete" — red destructive.
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: const Text('لا، تجاهل واحذف'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AC.err,
                side: BorderSide(color: AC.err),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              onPressed: _migrating ? null : _confirmIgnoreAndDelete,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runMigration() async {
    final tid = PilotSession.tenantId;
    if (tid == null || tid.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'لا يوجد tenant نشط — افتح الـ ERP أولاً وسجّل دخول',
          ),
          backgroundColor: AC.err,
        ),
      );
      return;
    }

    setState(() {
      _migrating = true;
      _migrationStatus = 'جاري نقل الشركات...';
    });

    // pilot_client.dart exports a top-level `pilotClient` singleton
    // (see line 807 of that file). The wizard uses the same one.
    final client = pilotClient;
    final result = _MigrationResult();
    // legacy_company_id → new_pilot_entity_id
    final entityMapping = <String, String>{};

    // ── Migrate companies as pilot entities ────────────────────
    for (final c in _companies) {
      final code = _legacyCompanyCode(c);
      final body = <String, dynamic>{
        'code': code,
        'name_ar': c.nameAr.trim().isEmpty ? c.id : c.nameAr,
        if (c.nameEn.trim().isNotEmpty) 'name_en': c.nameEn,
        'country': c.country.isEmpty ? 'SA' : c.country,
        'functional_currency':
            c.currency.isEmpty ? 'SAR' : c.currency,
        'type': 'company',
      };
      try {
        final r = await client.createEntity(tid, body);
        if (r.success) {
          final newId = (r.data as Map)['id'] as String?;
          if (newId != null) {
            entityMapping[c.id] = newId;
            result.entitiesOk++;
          } else {
            result.entitiesFail++;
            result.failures.add(
              'شركة "${c.nameAr}": استجابة بدون id',
            );
          }
        } else {
          result.entitiesFail++;
          result.failures.add(
            'شركة "${c.nameAr}": ${r.error ?? "خطأ غير معروف"}',
          );
        }
      } catch (ex) {
        result.entitiesFail++;
        result.failures.add('شركة "${c.nameAr}": $ex');
      }
    }

    // ── Migrate branches under their migrated companies ────────
    if (mounted) {
      setState(() => _migrationStatus = 'جاري نقل الفروع...');
    }
    for (final b in _branches) {
      final newEntityId = entityMapping[b.companyId];
      if (newEntityId == null) {
        // Parent company didn't migrate (or never existed) — skip
        // and record the failure.
        result.branchesFail++;
        result.failures.add(
          'فرع "${b.nameAr}": لم تُهاجَر الشركة الأم',
        );
        continue;
      }
      final parent = _companies.firstWhere(
        (c) => c.id == b.companyId,
        orElse: () => CompanyRecord(
          id: b.companyId,
          nameAr: '',
          nameEn: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final code = _legacyBranchCode(b);
      final body = <String, dynamic>{
        'code': code,
        'name_ar': b.nameAr.trim().isEmpty ? b.id : b.nameAr,
        if (b.nameEn.trim().isNotEmpty) 'name_en': b.nameEn,
        'country': parent.country.isEmpty ? 'SA' : parent.country,
        // Pilot schema requires `city` — fall back to a placeholder
        // so migration doesn't fail on records that never set one.
        'city': (b.city == null || b.city!.trim().isEmpty)
            ? 'غير محدد'
            : b.city!,
        'type': 'retail',
        'status': 'active',
      };
      try {
        final r = await client.createBranch(newEntityId, body);
        if (r.success) {
          result.branchesOk++;
        } else {
          result.branchesFail++;
          result.failures.add(
            'فرع "${b.nameAr}": ${r.error ?? "خطأ غير معروف"}',
          );
        }
      } catch (ex) {
        result.branchesFail++;
        result.failures.add('فرع "${b.nameAr}": $ex');
      }
    }

    // ── Clear localStorage (only after the migration completed,
    // success or partial-fail). Failures stay visible in the result
    // dialog so the user can re-create them in the ERP if needed.
    _clearLocalStorage();

    if (!mounted) return;
    setState(() {
      _migrating = false;
      _migrationStatus = null;
      _entities = [];
      _companies = [];
      _branches = [];
    });

    await _showMigrationResultDialog(result);
    if (!mounted) return;
    context.go('/app/erp/finance/onboarding');
  }

  Future<void> _showMigrationResultDialog(_MigrationResult r) async {
    await showDialog<void>(
      context: context,
      barrierColor: AC.sidebarScrim,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.sidebarBg,
        title: Row(
          children: [
            Icon(
              r.hasFailures ? Icons.warning_amber_rounded : Icons.check_circle,
              color: r.hasFailures ? AC.warn : AC.ok,
            ),
            const SizedBox(width: 8),
            Text(
              r.hasFailures ? 'نقل جزئي' : 'تم النقل بنجاح',
              style: TextStyle(color: AC.tp),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تم نقل ${r.entitiesOk} شركة و${r.branchesOk} فرع.',
                style: TextStyle(color: AC.tp, fontSize: 14),
              ),
              if (r.hasFailures) ...[
                const SizedBox(height: 10),
                Text(
                  'فشل نقل ${r.totalFail} سجل:',
                  style: TextStyle(color: AC.err, fontSize: 13),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: r.failures
                          .map((f) => Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '• $f',
                                  style: TextStyle(
                                    color: AC.ts,
                                    fontSize: 11,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'تم مسح البيانات المحلية. سيتم تحويلك إلى الـ ERP لإكمال الإعداد.',
                style: TextStyle(color: AC.ts, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('متابعة'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmIgnoreAndDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: AC.sidebarScrim,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.sidebarBg,
        title: Text('حذف البيانات المحلية؟', style: TextStyle(color: AC.tp)),
        content: Text(
          'هذا سيحذف جميع الشركات والفروع المحفوظة محلياً بشكل نهائي. '
          'لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(color: AC.ts, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AC.err,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    _clearLocalStorage();
    if (!mounted) return;
    setState(() {
      _entities = [];
      _companies = [];
      _branches = [];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف البيانات المحلية')),
    );
    context.go('/app/erp/finance/onboarding');
  }

  /// Wipe localStorage. `EntityStore.clearAll()` removes the three
  /// data keys (entities / companies / branches) plus the migration
  /// flag — see entity_store.dart line 583.
  void _clearLocalStorage() {
    EntityStore.clearAll();
  }

  /// Synthesize a pilot-schema-valid `code` from a legacy company id.
  /// The pilot endpoint requires `^[A-Z0-9_-]+$` with `min_length=2`.
  String _legacyCompanyCode(CompanyRecord c) {
    final cleaned = c.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final tail = cleaned.length >= 8
        ? cleaned.substring(cleaned.length - 8)
        : cleaned;
    return tail.length >= 2 ? 'MIG-$tail' : 'MIG-LEGACY';
  }

  String _legacyBranchCode(BranchRecord b) {
    final cleaned = b.id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final tail = cleaned.length >= 6
        ? cleaned.substring(cleaned.length - 6)
        : cleaned;
    return tail.length >= 2 ? 'BR-$tail' : 'BR-LEGACY';
  }

  // ─────────────────────────────────────────────────────────────
  // Setup progress checklist — SaaS 2026 / SAP Task List pattern
  // Shows 5 steps with adaptive completion markers.
  // ─────────────────────────────────────────────────────────────
  Widget _buildSetupChecklist() {
    final hasEntities = _entities.isNotEmpty;
    final hasCompanies = _companies.isNotEmpty;
    final hasBranches = _branches.isNotEmpty;
    // "CoA configured" heuristic: at least one company OR any branch
    // with independentCoA=true (local-only flag — real persistence
    // to be wired when user enables backend auth).
    final coaStarted = hasCompanies;

    final steps = [
      _Step(
        label: 'الكيان / الشركة',
        icon: Icons.corporate_fare_rounded,
        done: hasCompanies,
        onTap: () {}, // already on this screen
        estMin: 3,
      ),
      _Step(
        label: 'الفروع',
        icon: Icons.store_mall_directory_outlined,
        done: hasBranches,
        onTap: () {
          if (_companies.isNotEmpty) {
            _editBranch(null, _companies.first);
          }
        },
        estMin: 2,
      ),
      _Step(
        label: 'شجرة الحسابات',
        icon: Icons.account_tree_rounded,
        done: false, // backend wiring comes later
        onTap: () => _openChip('coa-editor'),
        estMin: 5,
        enabled: coaStarted,
      ),
      _Step(
        label: 'مراكز التكلفة',
        icon: Icons.pie_chart_rounded,
        done: false,
        onTap: () => _openChip('cost-centers'),
        estMin: 4,
        enabled: coaStarted,
      ),
      _Step(
        label: 'القوائم المالية',
        icon: Icons.insert_chart_rounded,
        done: false,
        onTap: () => _openChip('statements'),
        estMin: 2,
        enabled: coaStarted,
      ),
    ];

    final doneCount = steps.where((s) => s.done).length;
    final pct = doneCount / steps.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(DS.rLg),
        border: Border.all(color: AC.sidebarBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.checklist_rounded, color: AC.gold, size: 18),
          const SizedBox(width: 8),
          Text('رحلة الإعداد — ${(pct * 100).toInt()}%',
              style: TextStyle(
                  color: AC.textStrong,
                  fontSize: 13.5,
                  fontWeight: DS.fwBold)),
          const Spacer(),
          _pill('$doneCount / ${steps.length} خطوات مكتملة',
              pct >= 0.6 ? AC.ok : AC.info),
          if (!hasEntities && !hasBranches) ...[
            const SizedBox(width: 6),
            _pill('ابدأ بإنشاء شركة', AC.warn),
          ],
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 4,
            backgroundColor: AC.sidebarBgElevated,
            valueColor: AlwaysStoppedAnimation(AC.gold),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, cons) {
          final isNarrow = cons.maxWidth < 720;
          if (isNarrow) {
            return Column(
              children: steps.map(_stepRow).toList(),
            );
          }
          return Row(
            children: steps.map((s) => Expanded(child: _stepTile(s))).toList(),
          );
        }),
      ]),
    );
  }

  Widget _stepTile(_Step s) {
    final enabled = s.enabled;
    final done = s.done;
    final color =
        done ? AC.ok : (enabled ? AC.gold : AC.sidebarItemDim);
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: InkWell(
        onTap: enabled ? s.onTap : null,
        borderRadius: BorderRadius.circular(DS.rMd),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: done
                ? AC.ok.withValues(alpha: 0.08)
                : (enabled
                    ? AC.sidebarBgElevated
                    : AC.sidebarBgElevated.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(DS.rMd),
            border: Border.all(
                color: done ? AC.ok.withValues(alpha: 0.4) : AC.sidebarBorder),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check_rounded : s.icon,
                color: color,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: AC.textStrong,
                          fontSize: 11.5,
                          fontWeight: DS.fwSemibold)),
                  Text('~${s.estMin} د',
                      style: TextStyle(
                          color: AC.textMedium, fontSize: 9.5)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _stepRow(_Step s) {
    final enabled = s.enabled;
    final done = s.done;
    final color =
        done ? AC.ok : (enabled ? AC.gold : AC.sidebarItemDim);
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: InkWell(
        onTap: enabled ? s.onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check_rounded : s.icon,
                color: color,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(s.label,
                    style: TextStyle(
                        color: AC.textStrong,
                        fontSize: 12.5,
                        fontWeight: DS.fwSemibold))),
            Text('~${s.estMin} د',
                style: TextStyle(color: AC.textMedium, fontSize: 10)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_left_rounded,
                color: AC.sidebarItemDim, size: 16),
          ]),
        ),
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(DS.rPill),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10.5, fontWeight: DS.fwSemibold)),
      );

  /// Navigate to a chip inside the Finance module. Used by the "next-step"
  /// CTAs to send the user from Entity Setup → Chart of Accounts, etc.
  void _openChip(String chipId) {
    try {
      context.go('/app/erp/finance/$chipId');
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // Empty state
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AC.surface,
          borderRadius: BorderRadius.circular(DS.rLg),
          border: Border.all(color: AC.sidebarBorder),
        ),
        child: Column(children: [
          Icon(Icons.corporate_fare_rounded, color: AC.gold, size: 56),
          const SizedBox(height: 14),
          Text('ابدأ بإعداد بنية مؤسستك',
              style: TextStyle(
                  color: AC.textStrong, fontSize: 18, fontWeight: DS.fwBold)),
          const SizedBox(height: 8),
          Text(
            'مثال: "مجموعة أبوالعلا" ← "شركة أبوالعلا للمقاولات (SA)" ← "فرع الرياض" / "فرع جدة"',
            textAlign: TextAlign.center,
            style: TextStyle(color: AC.textMedium, fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton.icon(
              onPressed: () => _editEntity(null),
              icon: const Icon(Icons.corporate_fare_rounded, size: 18),
              label: const Text('إنشاء كيان'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AC.gold,
                side: BorderSide(color: AC.gold),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => _editCompany(null),
              icon: const Icon(Icons.domain_add_rounded, size: 18),
              label: const Text('إنشاء شركة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.btnFg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AC.infoSoft,
              borderRadius: BorderRadius.circular(DS.rMd),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: AC.info, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'يمكنك إنشاء شركة مستقلة مباشرة، أو كيان يحتوي عدة شركات محلية ودولية. '
                  'كل شركة قابلة للتقسيم إلى فروع مع صلاحيات مستقلة (شجرة حسابات، مخزون، مراكز تكلفة).',
                  style: TextStyle(
                      color: AC.textMedium, fontSize: 12, height: 1.5),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tree
  // ─────────────────────────────────────────────────────────────
  Widget _buildTree(List<CompanyRecord> standaloneCompanies) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Entities with their companies
        for (final e in _entities) _buildEntityNode(e),
        // Standalone companies
        if (standaloneCompanies.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(children: [
              Icon(Icons.flag_outlined, color: AC.sidebarItemDim, size: 15),
              const SizedBox(width: 6),
              Text('شركات مستقلة (بدون كيان)',
                  style: TextStyle(
                      color: AC.sidebarItemDim,
                      fontSize: 12,
                      fontWeight: DS.fwSemibold)),
            ]),
          ),
          for (final c in standaloneCompanies) _buildCompanyNode(c),
        ],
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEntityNode(EntityRecord e) {
    final childCompanies = _companiesFor(e.id);
    final open = _expanded.contains(e.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(DS.rLg),
        border: Border.all(color: AC.sidebarBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        InkWell(
          onTap: () => setState(() {
            if (open) {
              _expanded.remove(e.id);
            } else {
              _expanded.add(e.id);
            }
          }),
          borderRadius: BorderRadius.circular(DS.rLg),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AC.goldSoft,
                  borderRadius: BorderRadius.circular(DS.rMd),
                ),
                child: Icon(Icons.corporate_fare_rounded,
                    color: AC.gold, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.nameAr,
                        style: TextStyle(
                            color: AC.textStrong,
                            fontSize: 14,
                            fontWeight: DS.fwBold)),
                    const SizedBox(height: 2),
                    Row(children: [
                      _chip(_entityTypeLabel(e.type), AC.gold),
                      if (e.consolidated) ...[
                        const SizedBox(width: 4),
                        _chip('توحيد مفعّل', AC.ok),
                      ],
                      const SizedBox(width: 6),
                      Text('${childCompanies.length} شركة',
                          style: TextStyle(
                              color: AC.textMedium, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
              _nodeAction(Icons.add_rounded, 'إضافة شركة لهذا الكيان',
                  () => _editCompany(null, lockedEntityId: e.id)),
              _nodeAction(Icons.edit_outlined, 'تعديل الكيان',
                  () => _editEntity(e)),
              _nodeAction(
                  Icons.delete_outline_rounded,
                  'حذف الكيان',
                  () => _confirmDelete(
                      'الكيان "${e.nameAr}"', () => EntityStore.deleteEntity(e.id)),
                  danger: true),
              Icon(open ? Icons.expand_less : Icons.expand_more,
                  color: AC.sidebarItemDim, size: 20),
            ]),
          ),
        ),
        // Children (companies under this entity)
        if (open)
          Padding(
            padding: const EdgeInsetsDirectional.only(
                start: 16, end: 12, bottom: 10),
            child: Column(children: [
              if (childCompanies.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text('لا توجد شركات في هذا الكيان — أضف أول شركة',
                      style: TextStyle(
                          color: AC.textMedium,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
                ),
              for (final c in childCompanies) _buildCompanyNode(c, indent: 12),
            ]),
          ),
      ]),
    );
  }

  Widget _buildCompanyNode(CompanyRecord c, {double indent = 0}) {
    final branches = _branchesFor(c.id);
    final open = _expandedCompanies.contains(c.id);
    return Container(
      margin: EdgeInsetsDirectional.only(start: indent, bottom: 8),
      decoration: BoxDecoration(
        color: AC.sidebarBgElevated,
        borderRadius: BorderRadius.circular(DS.rMd),
        border: Border.all(color: AC.sidebarBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          onTap: () => setState(() {
            if (open) {
              _expandedCompanies.remove(c.id);
            } else {
              _expandedCompanies.add(c.id);
            }
          }),
          borderRadius: BorderRadius.circular(DS.rMd),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: c.scope == 'international'
                      ? AC.infoSoft
                      : AC.purpleSoft,
                  borderRadius: BorderRadius.circular(DS.rSm),
                ),
                child: Icon(
                  c.scope == 'international'
                      ? Icons.public_rounded
                      : Icons.domain_rounded,
                  color: c.scope == 'international' ? AC.info : AC.purple,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.nameAr,
                        style: TextStyle(
                            color: AC.textStrong,
                            fontSize: 13,
                            fontWeight: DS.fwSemibold)),
                    const SizedBox(height: 2),
                    Row(children: [
                      _chip(c.country, AC.info),
                      const SizedBox(width: 4),
                      _chip(c.currency, AC.ok),
                      const SizedBox(width: 4),
                      _chip(
                          c.scope == 'international' ? 'دولية' : 'محلية',
                          c.scope == 'international' ? AC.info : AC.purple),
                      if (c.includeInConsolidation) ...[
                        const SizedBox(width: 4),
                        _chip('ضمن التوحيد', AC.ok),
                      ],
                      const SizedBox(width: 6),
                      Text('${branches.length} فرع',
                          style: TextStyle(
                              color: AC.textMedium, fontSize: 10.5)),
                    ]),
                  ],
                ),
              ),
              _nodeAction(Icons.add_location_alt_outlined, 'إضافة فرع',
                  () => _editBranch(null, c)),
              _nodeAction(Icons.edit_outlined, 'تعديل الشركة',
                  () => _editCompany(c)),
              _nodeAction(
                  Icons.delete_outline_rounded,
                  'حذف الشركة',
                  () => _confirmDelete('الشركة "${c.nameAr}"',
                      () => EntityStore.deleteCompany(c.id)),
                  danger: true),
              Icon(open ? Icons.expand_less : Icons.expand_more,
                  color: AC.sidebarItemDim, size: 18),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsetsDirectional.only(
                start: 16, end: 10, bottom: 10),
            child: Column(children: [
              if (branches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        color: AC.textMedium, size: 13),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          'الشركة تعمل بفرع واحد افتراضي. لإضافة فروع متعددة اضغط "إضافة فرع".',
                          style: TextStyle(
                              color: AC.textMedium,
                              fontSize: 11,
                              fontStyle: FontStyle.italic)),
                    ),
                  ]),
                ),
              for (final b in branches) _buildBranchNode(b, c),
            ]),
          ),
      ]),
    );
  }

  Widget _buildBranchNode(BranchRecord b, CompanyRecord company) {
    final indeps = <String>[];
    if (b.independentCoA) indeps.add('شجرة حسابات');
    if (b.independentInventory) indeps.add('مخزون');
    if (b.independentCostCenters) indeps.add('مراكز تكلفة');
    if (b.independentCurrency) indeps.add('عملة');

    // Next-step CTAs: show per-branch quick links to configure the
    // independent modules the user toggled on. Based on NetSuite +
    // Sage Intacct pattern: each node exposes its "configure" actions.
    final ctas = <_BranchCta>[];
    if (b.independentCoA) {
      ctas.add(_BranchCta(
          label: 'تهيئة شجرة الحسابات',
          icon: Icons.account_tree_rounded,
          chipId: 'coa-editor',
          color: AC.info));
    }
    if (b.independentCostCenters) {
      ctas.add(_BranchCta(
          label: 'مراكز التكلفة',
          icon: Icons.pie_chart_rounded,
          chipId: 'cost-centers',
          color: AC.purple));
    }
    if (b.independentInventory) {
      ctas.add(_BranchCta(
          label: 'المخازن',
          icon: Icons.warehouse_rounded,
          chipId: 'warehouse',
          color: AC.ok,
          moduleId: 'inventory'));
    }

    return Container(
      margin: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(DS.rSm),
        border: Border.all(color: AC.dividerSubtle),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.store_mall_directory_outlined,
              color: AC.sidebarItemDim, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(b.nameAr,
                      style: TextStyle(
                          color: AC.textStrong,
                          fontSize: 12.5,
                          fontWeight: DS.fwSemibold)),
                  if (b.city != null) ...[
                    const SizedBox(width: 6),
                    Text('· ${b.city}',
                        style: TextStyle(
                            color: AC.textMedium, fontSize: 11)),
                  ],
                  if (b.zatcaBranchCode != null &&
                      b.zatcaBranchCode!.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _chip('ZATCA: ${b.zatcaBranchCode}', AC.gold),
                  ],
                ]),
                if (indeps.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Wrap(spacing: 4, runSpacing: 2, children: [
                    for (final s in indeps) _chip('مستقل: $s', AC.info),
                    if (b.includeInConsolidation) _chip('ضمن التوحيد', AC.ok),
                  ]),
                ] else if (b.includeInConsolidation)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: _chip('وراثة كاملة من الشركة الأم', AC.textMedium),
                  ),
              ],
            ),
          ),
          _nodeAction(Icons.edit_outlined, 'تعديل الفرع',
              () => _editBranch(b, company)),
          _nodeAction(
              Icons.delete_outline_rounded,
              'حذف الفرع',
              () => _confirmDelete('الفرع "${b.nameAr}"',
                  () => EntityStore.deleteBranch(b.id)),
              danger: true),
        ]),
        // Next-step CTA row — only visible if the branch has independent
        // modules. Gives the user a clear forward path into the
        // per-module setup screens (COA / Cost Centers / Warehouses).
        if (ctas.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 24, end: 4),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final cta in ctas) _ctaButton(cta),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _ctaButton(_BranchCta cta) {
    return InkWell(
      onTap: () {
        try {
          final mod = cta.moduleId ?? 'finance';
          context.go('/app/erp/$mod/${cta.chipId}');
        } catch (_) {}
      },
      borderRadius: BorderRadius.circular(DS.rSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cta.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(DS.rSm),
          border: Border.all(color: cta.color.withValues(alpha: 0.35)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(cta.icon, color: cta.color, size: 13),
          const SizedBox(width: 6),
          Text(cta.label,
              style: TextStyle(
                  color: cta.color,
                  fontSize: 11,
                  fontWeight: DS.fwSemibold)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_left_rounded, color: cta.color, size: 13),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────
  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: DS.fwSemibold)),
      );

  Widget _nodeAction(IconData icon, String tooltip, VoidCallback onTap,
      {bool danger = false}) {
    return IconButton(
      icon: Icon(icon,
          color: danger ? AC.err : AC.sidebarItemDim, size: 18),
      onPressed: onTap,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
    );
  }

  String _entityTypeLabel(String t) => switch (t) {
        'group' => 'مجموعة',
        'holding' => 'شركة قابضة',
        'standalone' => 'مستقل',
        _ => t,
      };
}

// ═══════════════════════════════════════════════════════════════════
// Entity dialog
// ═══════════════════════════════════════════════════════════════════
class _EntityDialog extends StatefulWidget {
  final EntityRecord? initial;
  const _EntityDialog({this.initial});
  @override
  State<_EntityDialog> createState() => _EntityDialogState();
}

class _EntityDialogState extends State<_EntityDialog> {
  late TextEditingController _nameAr;
  late TextEditingController _nameEn;
  late TextEditingController _notes;
  String _type = 'group';
  bool _consolidated = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameAr = TextEditingController(text: i?.nameAr ?? '');
    _nameEn = TextEditingController(text: i?.nameEn ?? '');
    _notes = TextEditingController(text: i?.notes ?? '');
    _type = i?.type ?? 'group';
    _consolidated = i?.consolidated ?? true;
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameAr.text.trim().isEmpty) return;
    if (widget.initial == null) {
      final rec = EntityStore.addEntity(
        nameAr: _nameAr.text.trim(),
        nameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        type: _type,
        consolidated: _consolidated,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      Navigator.pop(context, rec);
    } else {
      final rec = EntityStore.updateEntity(widget.initial!.id,
          nameAr: _nameAr.text.trim(),
          nameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
          type: _type,
          consolidated: _consolidated,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim());
      Navigator.pop(context, rec);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AC.sidebarBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.rLg),
          side: BorderSide(color: AC.sidebarBorder)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.corporate_fare_rounded, color: AC.gold, size: 22),
            const SizedBox(width: 10),
            Text(widget.initial == null ? 'كيان جديد' : 'تعديل الكيان',
                style: TextStyle(
                    color: AC.textStrong,
                    fontSize: 16,
                    fontWeight: DS.fwBold)),
            const Spacer(),
            IconButton(
                icon: Icon(Icons.close, color: AC.sidebarItemDim),
                onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 12),
          _field(_nameAr, 'الاسم بالعربية *', icon: Icons.badge_outlined),
          const SizedBox(height: 10),
          _field(_nameEn, 'Name in English', icon: Icons.badge_outlined),
          const SizedBox(height: 10),
          _typeSelector(),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _consolidated,
            onChanged: (v) => setState(() => _consolidated = v),
            title: Text('تفعيل التوحيد (Consolidation)',
                style: TextStyle(color: AC.textStrong, fontSize: 13)),
            subtitle: Text('تجميع القوائم المالية لكل الشركات التابعة',
                style: TextStyle(color: AC.textMedium, fontSize: 11)),
            activeColor: AC.gold,
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 6),
          _field(_notes, 'ملاحظات (اختياري)',
              icon: Icons.notes_outlined, maxLines: 2),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: TextStyle(color: AC.textMedium))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.btnFg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: Text(widget.initial == null ? 'إنشاء الكيان' : 'حفظ'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _typeSelector() {
    final opts = [
      ('group', 'مجموعة'),
      ('holding', 'شركة قابضة'),
      ('standalone', 'مستقل'),
    ];
    return Row(children: [
      Icon(Icons.category_outlined, color: AC.gold, size: 18),
      const SizedBox(width: 8),
      Text('النوع:',
          style: TextStyle(color: AC.textMedium, fontSize: 12.5)),
      const SizedBox(width: 10),
      Expanded(
        child: Wrap(
          spacing: 6,
          children: opts
              .map((o) => ChoiceChip(
                    label: Text(o.$2, style: const TextStyle(fontSize: 12)),
                    selected: _type == o.$1,
                    selectedColor: AC.gold.withValues(alpha: 0.2),
                    onSelected: (_) => setState(() => _type = o.$1),
                    labelStyle: TextStyle(
                        color: _type == o.$1
                            ? AC.gold
                            : AC.textMedium),
                  ))
              .toList(),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════
// Company dialog
// ═══════════════════════════════════════════════════════════════════
class _CompanyDialog extends StatefulWidget {
  final CompanyRecord? initial;
  final List<EntityRecord> entities;
  final String? lockedEntityId;
  const _CompanyDialog({
    this.initial,
    required this.entities,
    this.lockedEntityId,
  });
  @override
  State<_CompanyDialog> createState() => _CompanyDialogState();
}

class _CompanyDialogState extends State<_CompanyDialog> {
  late TextEditingController _nameAr;
  late TextEditingController _nameEn;
  late TextEditingController _taxNumber;
  late TextEditingController _crNumber;
  String? _entityId;
  String _scope = 'local';
  String _country = 'SA';
  String _currency = 'SAR';
  String _clientType = 'standard_business';
  bool _includeInConsolidation = true;

  // Short reference tables. Full lists can be expanded later.
  static const _countries = [
    ('SA', 'السعودية', 'SAR'),
    ('AE', 'الإمارات', 'AED'),
    ('KW', 'الكويت', 'KWD'),
    ('BH', 'البحرين', 'BHD'),
    ('OM', 'عُمان', 'OMR'),
    ('QA', 'قطر', 'QAR'),
    ('EG', 'مصر', 'EGP'),
    ('JO', 'الأردن', 'JOD'),
    ('US', 'الولايات المتحدة', 'USD'),
    ('GB', 'بريطانيا', 'GBP'),
    ('EU', 'الاتحاد الأوروبي', 'EUR'),
  ];
  static const _clientTypes = [
    ('standard_business', 'شركة تجارية عادية'),
    ('financial_entity', 'جهة مالية'),
    ('financing_entity', 'جهة تمويلية'),
    ('accounting_firm', 'مكتب محاسبة'),
    ('audit_firm', 'مكتب مراجعة'),
    ('investment_entity', 'جهة استثمارية'),
    ('sector_consulting_entity', 'جهة استشارية'),
    ('government_entity', 'جهة حكومية'),
    ('legal_regulatory_entity', 'جهة قانونية أو تنظيمية'),
  ];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameAr = TextEditingController(text: i?.nameAr ?? '');
    _nameEn = TextEditingController(text: i?.nameEn ?? '');
    _taxNumber = TextEditingController(text: i?.taxNumber ?? '');
    _crNumber = TextEditingController(text: i?.crNumber ?? '');
    _entityId = i?.entityId ?? widget.lockedEntityId;
    _scope = i?.scope ?? 'local';
    _country = i?.country ?? 'SA';
    _currency = i?.currency ?? 'SAR';
    _clientType = i?.clientType ?? 'standard_business';
    _includeInConsolidation = i?.includeInConsolidation ?? true;
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _taxNumber.dispose();
    _crNumber.dispose();
    super.dispose();
  }

  void _onCountryChanged(String c) {
    final row = _countries.firstWhere((e) => e.$1 == c,
        orElse: () => const ('SA', 'السعودية', 'SAR'));
    setState(() {
      _country = row.$1;
      _currency = row.$3;
      // Auto-detect scope — GCC+Egypt = local by default, else international.
      _scope = ['SA', 'AE', 'KW', 'BH', 'OM', 'QA', 'EG', 'JO'].contains(c)
          ? 'local'
          : 'international';
    });
  }

  void _save() {
    if (_nameAr.text.trim().isEmpty) return;
    final nameEn = _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim();
    final tax = _taxNumber.text.trim().isEmpty ? null : _taxNumber.text.trim();
    final cr = _crNumber.text.trim().isEmpty ? null : _crNumber.text.trim();
    if (widget.initial == null) {
      final rec = EntityStore.addCompany(
        entityId: _entityId,
        nameAr: _nameAr.text.trim(),
        nameEn: nameEn,
        scope: _scope,
        country: _country,
        currency: _currency,
        clientType: _clientType,
        taxNumber: tax,
        crNumber: cr,
        includeInConsolidation: _includeInConsolidation,
      );
      Navigator.pop(context, rec);
    } else {
      final rec = EntityStore.updateCompany(widget.initial!.id,
          entityId: _entityId,
          nameAr: _nameAr.text.trim(),
          nameEn: nameEn,
          scope: _scope,
          country: _country,
          currency: _currency,
          clientType: _clientType,
          taxNumber: tax,
          crNumber: cr,
          includeInConsolidation: _includeInConsolidation);
      Navigator.pop(context, rec);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AC.sidebarBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.rLg),
          side: BorderSide(color: AC.sidebarBorder)),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 640),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.domain_rounded, color: AC.gold, size: 22),
            const SizedBox(width: 10),
            Text(widget.initial == null ? 'شركة جديدة' : 'تعديل الشركة',
                style: TextStyle(
                    color: AC.textStrong,
                    fontSize: 16,
                    fontWeight: DS.fwBold)),
            const Spacer(),
            IconButton(
                icon: Icon(Icons.close, color: AC.sidebarItemDim),
                onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [
                if (widget.entities.isNotEmpty) _entityPicker(),
                if (widget.entities.isNotEmpty) const SizedBox(height: 10),
                _field(_nameAr, 'الاسم بالعربية *',
                    icon: Icons.badge_outlined),
                const SizedBox(height: 10),
                _field(_nameEn, 'Name in English',
                    icon: Icons.badge_outlined),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _countryPicker()),
                  const SizedBox(width: 10),
                  Expanded(child: _currencyField()),
                ]),
                const SizedBox(height: 10),
                _scopeSelector(),
                const SizedBox(height: 10),
                _typeDropdown(),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _field(_taxNumber, 'الرقم الضريبي (VAT)',
                          icon: Icons.receipt_long)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _field(_crNumber, 'السجل التجاري (CR)',
                          icon: Icons.assignment_ind_outlined)),
                ]),
                const SizedBox(height: 6),
                SwitchListTile(
                  value: _includeInConsolidation,
                  onChanged: (v) =>
                      setState(() => _includeInConsolidation = v),
                  title: Text('تضمينها في التوحيد',
                      style: TextStyle(color: AC.textStrong, fontSize: 13)),
                  subtitle: Text(
                      'روّل هذه الشركة ضمن القوائم الموحّدة للكيان الأم',
                      style: TextStyle(color: AC.textMedium, fontSize: 11)),
                  activeColor: AC.gold,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: TextStyle(color: AC.textMedium))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.btnFg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: Text(widget.initial == null ? 'إنشاء الشركة' : 'حفظ'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _entityPicker() {
    return DropdownButtonFormField<String?>(
      value: _entityId,
      decoration: InputDecoration(
        labelText: 'الكيان الأم (اختياري)',
        prefixIcon: Icon(Icons.corporate_fare_rounded, color: AC.gold),
        filled: true,
        fillColor: AC.sidebarBgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.rMd),
          borderSide: BorderSide(color: AC.sidebarBorder),
        ),
      ),
      style: TextStyle(color: AC.textStrong, fontSize: 13),
      dropdownColor: AC.sidebarBg,
      items: [
        DropdownMenuItem(
            value: null,
            child: Text('— بدون كيان (مستقلة) —',
                style: TextStyle(color: AC.textMedium))),
        ...widget.entities.map((e) =>
            DropdownMenuItem(value: e.id, child: Text(e.nameAr))),
      ],
      onChanged: (v) => setState(() => _entityId = v),
    );
  }

  Widget _countryPicker() {
    return DropdownButtonFormField<String>(
      value: _country,
      decoration: InputDecoration(
        labelText: 'الدولة',
        prefixIcon: Icon(Icons.flag_outlined, color: AC.gold),
        filled: true,
        fillColor: AC.sidebarBgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.rMd),
          borderSide: BorderSide(color: AC.sidebarBorder),
        ),
      ),
      style: TextStyle(color: AC.textStrong, fontSize: 13),
      dropdownColor: AC.sidebarBg,
      items: _countries
          .map((e) => DropdownMenuItem(
                value: e.$1,
                child: Text('${e.$1} — ${e.$2}'),
              ))
          .toList(),
      onChanged: (v) => v != null ? _onCountryChanged(v) : null,
    );
  }

  Widget _currencyField() {
    return TextField(
      controller: TextEditingController(text: _currency),
      readOnly: false,
      onChanged: (v) => _currency = v.trim().toUpperCase(),
      decoration: InputDecoration(
        labelText: 'العملة',
        prefixIcon: Icon(Icons.attach_money_rounded, color: AC.gold),
        filled: true,
        fillColor: AC.sidebarBgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.rMd),
          borderSide: BorderSide(color: AC.sidebarBorder),
        ),
      ),
      style: TextStyle(color: AC.textStrong, fontSize: 13),
    );
  }

  Widget _scopeSelector() {
    return Row(children: [
      Icon(Icons.public, color: AC.gold, size: 18),
      const SizedBox(width: 8),
      Text('النطاق:',
          style: TextStyle(color: AC.textMedium, fontSize: 12.5)),
      const SizedBox(width: 10),
      ChoiceChip(
        label: const Text('محلية'),
        selected: _scope == 'local',
        selectedColor: AC.purple.withValues(alpha: 0.2),
        onSelected: (_) => setState(() => _scope = 'local'),
      ),
      const SizedBox(width: 6),
      ChoiceChip(
        label: const Text('دولية'),
        selected: _scope == 'international',
        selectedColor: AC.info.withValues(alpha: 0.2),
        onSelected: (_) => setState(() => _scope = 'international'),
      ),
    ]);
  }

  Widget _typeDropdown() {
    return DropdownButtonFormField<String>(
      value: _clientType,
      decoration: InputDecoration(
        labelText: 'نوع الشركة',
        prefixIcon: Icon(Icons.category_outlined, color: AC.gold),
        filled: true,
        fillColor: AC.sidebarBgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DS.rMd),
          borderSide: BorderSide(color: AC.sidebarBorder),
        ),
      ),
      style: TextStyle(color: AC.textStrong, fontSize: 13),
      dropdownColor: AC.sidebarBg,
      items: _clientTypes
          .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
          .toList(),
      onChanged: (v) => v != null ? setState(() => _clientType = v) : null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Branch dialog
// ═══════════════════════════════════════════════════════════════════
class _BranchDialog extends StatefulWidget {
  final BranchRecord? initial;
  final CompanyRecord company;
  const _BranchDialog({this.initial, required this.company});
  @override
  State<_BranchDialog> createState() => _BranchDialogState();
}

class _BranchDialogState extends State<_BranchDialog> {
  late TextEditingController _nameAr;
  late TextEditingController _nameEn;
  late TextEditingController _city;
  late TextEditingController _address;
  late TextEditingController _zatca;
  late TextEditingController _currencyOverride;
  bool _indepCoA = false;
  bool _indepInventory = false;
  bool _indepCC = false;
  bool _indepCurrency = false;
  bool _includeInConsolidation = true;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _nameAr = TextEditingController(text: i?.nameAr ?? '');
    _nameEn = TextEditingController(text: i?.nameEn ?? '');
    _city = TextEditingController(text: i?.city ?? '');
    _address = TextEditingController(text: i?.address ?? '');
    _zatca = TextEditingController(text: i?.zatcaBranchCode ?? '');
    _currencyOverride = TextEditingController(
        text: i?.currencyOverride ?? widget.company.currency);
    _indepCoA = i?.independentCoA ?? false;
    _indepInventory = i?.independentInventory ?? false;
    _indepCC = i?.independentCostCenters ?? false;
    _indepCurrency = i?.independentCurrency ?? false;
    _includeInConsolidation = i?.includeInConsolidation ?? true;
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _city.dispose();
    _address.dispose();
    _zatca.dispose();
    _currencyOverride.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameAr.text.trim().isEmpty) return;
    if (widget.initial == null) {
      final rec = EntityStore.addBranch(
        companyId: widget.company.id,
        nameAr: _nameAr.text.trim(),
        nameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        address:
            _address.text.trim().isEmpty ? null : _address.text.trim(),
        zatcaBranchCode:
            _zatca.text.trim().isEmpty ? null : _zatca.text.trim(),
        independentCoA: _indepCoA,
        independentInventory: _indepInventory,
        independentCostCenters: _indepCC,
        independentCurrency: _indepCurrency,
        currencyOverride:
            _indepCurrency ? _currencyOverride.text.trim() : null,
        includeInConsolidation: _includeInConsolidation,
      );
      Navigator.pop(context, rec);
    } else {
      final rec = EntityStore.updateBranch(widget.initial!.id,
          nameAr: _nameAr.text.trim(),
          nameEn: _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
          city: _city.text.trim().isEmpty ? null : _city.text.trim(),
          address: _address.text.trim().isEmpty ? null : _address.text.trim(),
          zatcaBranchCode:
              _zatca.text.trim().isEmpty ? null : _zatca.text.trim(),
          independentCoA: _indepCoA,
          independentInventory: _indepInventory,
          independentCostCenters: _indepCC,
          independentCurrency: _indepCurrency,
          currencyOverride:
              _indepCurrency ? _currencyOverride.text.trim() : null,
          includeInConsolidation: _includeInConsolidation);
      Navigator.pop(context, rec);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AC.sidebarBg,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DS.rLg),
          side: BorderSide(color: AC.sidebarBorder)),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 720),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Icon(Icons.store_mall_directory_outlined,
                color: AC.gold, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  widget.initial == null
                      ? 'فرع جديد — ${widget.company.nameAr}'
                      : 'تعديل الفرع',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: AC.textStrong,
                      fontSize: 16,
                      fontWeight: DS.fwBold)),
            ),
            IconButton(
                icon: Icon(Icons.close, color: AC.sidebarItemDim),
                onPressed: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(children: [
                _field(_nameAr, 'اسم الفرع *',
                    icon: Icons.store_mall_directory_outlined),
                const SizedBox(height: 10),
                _field(_nameEn, 'Name in English',
                    icon: Icons.store_mall_directory_outlined),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: _field(_city, 'المدينة',
                          icon: Icons.location_city_outlined)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _field(_zatca, 'كود فرع ZATCA',
                          icon: Icons.qr_code_rounded)),
                ]),
                const SizedBox(height: 10),
                _field(_address, 'العنوان',
                    icon: Icons.place_outlined, maxLines: 2),
                const SizedBox(height: 16),
                // Independence section
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Text('الاستقلالية عن الشركة الأم',
                        style: TextStyle(
                            color: AC.gold,
                            fontSize: 13,
                            fontWeight: DS.fwBold)),
                  ),
                ),
                _switchTile(
                    'شجرة حسابات مستقلة', _indepCoA,
                    (v) => setState(() => _indepCoA = v),
                    'استخدم CoA خاصاً بالفرع بدل الوراثة من الشركة'),
                _switchTile(
                    'مخزون مستقل', _indepInventory,
                    (v) => setState(() => _indepInventory = v),
                    'مستودعات وأرصدة مستقلة لكل فرع'),
                _switchTile(
                    'مراكز تكلفة مستقلة', _indepCC,
                    (v) => setState(() => _indepCC = v),
                    'تتبع تكاليف مستقل عن الشركة الأم'),
                _switchTile(
                    'عملة مستقلة', _indepCurrency,
                    (v) => setState(() => _indepCurrency = v),
                    'العملة التشغيلية للفرع تختلف عن عملة الشركة'),
                if (_indepCurrency) ...[
                  const SizedBox(height: 8),
                  _field(_currencyOverride, 'عملة الفرع',
                      icon: Icons.attach_money_rounded),
                ],
                const SizedBox(height: 6),
                _switchTile('تضمين ضمن التوحيد', _includeInConsolidation,
                    (v) => setState(() => _includeInConsolidation = v),
                    'إدراج أرقام الفرع في القوائم الموحّدة للشركة/الكيان'),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء',
                    style: TextStyle(color: AC.textMedium))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.btnFg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: Text(widget.initial == null ? 'إنشاء الفرع' : 'حفظ'),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _switchTile(String title, bool value, ValueChanged<bool> onChanged,
      String subtitle) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(title,
          style: TextStyle(color: AC.textStrong, fontSize: 12.5)),
      subtitle: Text(subtitle,
          style: TextStyle(color: AC.textMedium, fontSize: 10.5)),
      activeColor: AC.gold,
      dense: true,
      contentPadding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════════
// Setup-step model (used by the 2026 progress checklist)
// ═══════════════════════════════════════════════════════════════════
class _Step {
  final String label;
  final IconData icon;
  final bool done;
  final VoidCallback onTap;
  final int estMin;
  final bool enabled;
  const _Step({
    required this.label,
    required this.icon,
    required this.done,
    required this.onTap,
    required this.estMin,
    this.enabled = true,
  });
}

// Per-branch "configure this" CTA descriptor
class _BranchCta {
  final String label;
  final IconData icon;
  final String chipId;
  final Color color;
  final String? moduleId; // defaults to 'finance' if null
  const _BranchCta({
    required this.label,
    required this.icon,
    required this.chipId,
    required this.color,
    this.moduleId,
  });
}

Widget _field(TextEditingController c, String label,
    {IconData? icon, int maxLines = 1}) {
  return TextField(
    controller: c,
    maxLines: maxLines,
    style: TextStyle(color: AC.textStrong, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: AC.gold, size: 18) : null,
      filled: true,
      fillColor: AC.sidebarBgElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DS.rMd),
        borderSide: BorderSide(color: AC.sidebarBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DS.rMd),
        borderSide: BorderSide(color: AC.sidebarBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DS.rMd),
        borderSide: BorderSide(color: AC.gold, width: 1.5),
      ),
      labelStyle: TextStyle(color: AC.textMedium, fontSize: 12.5),
    ),
  );
}
