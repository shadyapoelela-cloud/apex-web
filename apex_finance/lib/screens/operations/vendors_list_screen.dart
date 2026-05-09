/// APEX — Vendors List (V5 chip body for /app/erp/purchasing/suppliers).
///
/// Wave 2 of APEX_IMPROVEMENT_PLAN.md — migrated from `ApexListShell`
/// to `ApexListToolbar` (Odoo ribbon, chips, accordion, bulk-select,
/// AI drawer). Mirror of customers_list_screen.dart with vendor-side
/// labels and routes.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_csv_export.dart';
import '../../core/apex_saved_views_v2.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_copilot_drawer.dart';
import '../../widgets/apex_list_toolbar.dart';
import 'vendor_create_modal.dart';

const String _kScreenKey = '/app/erp/purchasing/suppliers';

class VendorsListScreen extends StatefulWidget {
  const VendorsListScreen({super.key});
  @override
  State<VendorsListScreen> createState() => _VendorsListScreenState();
}

class _VendorsListScreenState extends State<VendorsListScreen> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = false;
  String? _error;

  // Toolbar state
  final TextEditingController _searchCtl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final Set<String> _activeMulti = <String>{};
  String _city = 'all';
  String _groupBy = 'none';
  String _sortKey = 'name_asc';
  String _viewMode = 'list';

  // Bulk-select
  final Set<String> _selectedIds = <String>{};

  // Scaffold key for AI drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final tenantId = S.savedTenantId;
    if (tenantId == null) {
      setState(() => _error = 'لا يوجد كيان نشط');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotListVendors(tenantId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _all = (res.data as List).cast<Map<String, dynamic>>();
      } else {
        _error = res.error ?? 'تعذّر تحميل الموردين';
      }
    });
  }

  // ── Selection helpers ────────────────────────────────────────────────
  bool _isSelected(Map v) => _selectedIds.contains(v['id']?.toString());

  void _toggleSelected(Map v) {
    final id = v['id']?.toString();
    if (id == null) return;
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  // ── Filter / sort derivation ─────────────────────────────────────────
  List<Map<String, dynamic>> get _visible {
    final q = _searchCtl.text.trim().toLowerCase();
    var list = _all.where((v) {
      if (_activeMulti.isNotEmpty) {
        final isActive = v['is_active'] == true;
        final wantActive = _activeMulti.contains('active');
        final wantInactive = _activeMulti.contains('inactive');
        if (isActive && !wantActive) return false;
        if (!isActive && !wantInactive) return false;
      }
      if (_city != 'all') {
        if ((v['city'] ?? '').toString() != _city) return false;
      }
      if (q.isNotEmpty) {
        final hay = [
          v['code'],
          v['name_ar'],
          v['name_en'],
          v['phone'],
          v['email'],
          v['vat_number'],
        ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
    list.sort((a, b) {
      switch (_sortKey) {
        case 'name_asc':
          return (a['name_ar'] ?? '')
              .toString()
              .compareTo((b['name_ar'] ?? '').toString());
        case 'name_desc':
          return (b['name_ar'] ?? '')
              .toString()
              .compareTo((a['name_ar'] ?? '').toString());
        case 'code_asc':
          return (a['code'] ?? '')
              .toString()
              .compareTo((b['code'] ?? '').toString());
        case 'recent':
          return (b['created_at'] ?? '')
              .toString()
              .compareTo((a['created_at'] ?? '').toString());
      }
      return 0;
    });
    return list;
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final list = _visible;
    if (_groupBy == 'none') return {'__all__': list};
    final out = <String, List<Map<String, dynamic>>>{};
    for (final v in list) {
      final key = switch (_groupBy) {
        'active' => (v['is_active'] == true) ? 'نشط' : 'غير نشط',
        'city' => (v['city'] ?? 'بدون مدينة').toString(),
        _ => '__all__',
      };
      out.putIfAbsent(key, () => []).add(v);
    }
    return out;
  }

  void _clearAllFilters() {
    setState(() {
      _searchCtl.clear();
      _activeMulti.clear();
      _city = 'all';
    });
  }

  // ── Saved views (favorites) ──────────────────────────────────────────
  Map<String, dynamic> _captureFiltersAsMap() => {
        'search': _searchCtl.text,
        'active': _activeMulti.toList(),
        'city': _city,
        'group_by': _groupBy,
        'sort_key': _sortKey,
        'view_mode': _viewMode,
      };

  void _restoreFiltersFromMap(Map<String, dynamic> m) {
    setState(() {
      _searchCtl.text = (m['search'] as String?) ?? '';
      _activeMulti
        ..clear()
        ..addAll(((m['active'] as List?) ?? []).cast<String>());
      _city = (m['city'] as String?) ?? 'all';
      _groupBy = (m['group_by'] as String?) ?? 'none';
      _sortKey = (m['sort_key'] as String?) ?? 'name_asc';
      _viewMode = (m['view_mode'] as String?) ?? 'list';
    });
  }

  Future<void> _onSaveCurrentView() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AC.bdr),
        ),
        title: Row(children: [
          Icon(Icons.bookmark_add_rounded, color: AC.gold, size: 20),
          const SizedBox(width: 8),
          Text('حفظ البحث الحالي',
              style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textDirection: TextDirection.rtl,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            hintText: 'اسم البحث',
            hintStyle: TextStyle(color: AC.td),
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.gold)),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('إلغاء', style: TextStyle(color: AC.td))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            style: FilledButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    ApexSavedViewsRepo.add(ApexSavedView(
      id: 'view_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      screen: _kScreenKey,
      filters: _captureFiltersAsMap(),
      createdAt: DateTime.now(),
      icon: Icons.bookmark_rounded,
    ));
    if (mounted) setState(() {});
  }

  List<ApexFavorite> _loadFavorites() {
    return ApexSavedViewsRepo.all()
        .where((v) => v.screen == _kScreenKey)
        .map((v) => ApexFavorite(
              key: v.id,
              labelAr: v.name,
              onApply: () => _restoreFiltersFromMap(v.filters),
              onDelete: () {
                ApexSavedViewsRepo.remove(v.id);
                setState(() {});
              },
            ))
        .toList();
  }

  // ── CTA actions ──────────────────────────────────────────────────────
  // G-FIN-VENDORS-COMPLETE (Sprint 3, 2026-05-09): toolbar `+ جديد`
  // opens VendorCreateModal and refreshes the list inline. Pre-fix
  // the button routed to the placeholder `/purchase` page.
  Future<void> _onCreate() async {
    final created = await VendorCreateModal.show(context);
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.ok,
      content: Text(
          'تم إنشاء المورد ${created['legal_name_ar'] ?? ''} (${created['code'] ?? ''})'),
    ));
    await _load();
  }
  void _onAiCreate() => _scaffoldKey.currentState?.openEndDrawer();

  void _bulkExportCsv() {
    final selectedRows = _all
        .where((v) => _selectedIds.contains(v['id']?.toString()))
        .toList();
    if (selectedRows.isEmpty) return;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    ApexCsvExport.download<Map<String, dynamic>>(
      filename: 'vendors-$stamp',
      rows: selectedRows,
      columns: [
        ApexCsvColumn(
            header: 'الكود', extract: (r) => (r['code'] ?? '').toString()),
        ApexCsvColumn(
            header: 'الاسم العربي',
            extract: (r) => (r['name_ar'] ?? '').toString()),
        ApexCsvColumn(
            header: 'الاسم الإنجليزي',
            extract: (r) => (r['name_en'] ?? '').toString()),
        ApexCsvColumn(
            header: 'الهاتف', extract: (r) => (r['phone'] ?? '').toString()),
        ApexCsvColumn(
            header: 'البريد', extract: (r) => (r['email'] ?? '').toString()),
        ApexCsvColumn(
            header: 'الرقم الضريبي',
            extract: (r) => (r['vat_number'] ?? '').toString()),
        ApexCsvColumn(
            header: 'المدينة', extract: (r) => (r['city'] ?? '').toString()),
        ApexCsvColumn(
            header: 'الحالة',
            extract: (r) => (r['is_active'] == true) ? 'نشط' : 'غير نشط'),
      ],
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.navy3,
        content: Text('تم تصدير ${selectedRows.length} مورد كـ CSV',
            style: TextStyle(color: AC.tp), textAlign: TextAlign.right),
      ));
    }
  }

  Map<String, dynamic> _buildScreenContext() => {
        'totalCount': _all.length,
        'visibleCount': _visible.length,
        'filters': _captureFiltersAsMap(),
        'groupBy': _groupBy,
        'sortKey': _sortKey,
        'viewMode': _viewMode,
      };

  // ─────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AC.navy,
      endDrawer: ApexCopilotDrawer(
        screenName: 'الموردون',
        screenContext: _buildScreenContext(),
      ),
      body: Column(children: [
        _buildToolbar(),
        if (_error != null) _buildErrorBanner(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildToolbar() {
    final activeGroup = ApexFilterGroup(
      labelAr: 'الحالة',
      icon: Icons.toggle_on_rounded,
      multi: true,
      selected: _activeMulti,
      onToggle: (k) => setState(() {
        if (!_activeMulti.add(k)) _activeMulti.remove(k);
      }),
      options: [
        ApexFilterOption(
            key: 'active',
            labelAr: 'نشط',
            icon: Icons.check_circle_outline,
            color: AC.ok),
        ApexFilterOption(
            key: 'inactive',
            labelAr: 'غير نشط',
            icon: Icons.block,
            color: AC.td),
      ],
    );

    final cities = <String>{};
    for (final v in _all) {
      final city = (v['city'] ?? '').toString();
      if (city.isNotEmpty) cities.add(city);
    }
    final cityGroup = ApexFilterGroup(
      labelAr: 'المدينة',
      icon: Icons.location_city_rounded,
      multi: false,
      selected: {_city},
      onToggle: (k) => setState(() => _city = k),
      options: [
        const ApexFilterOption(key: 'all', labelAr: 'كل المدن'),
        for (final city in cities)
          ApexFilterOption(key: city, labelAr: city),
      ],
    );

    return ApexListToolbar(
      titleAr: 'الموردون',
      titleIcon: Icons.local_shipping_rounded,
      itemNounAr: 'مورد',
      totalCount: _all.length,
      visibleCount: _visible.length,
      searchCtl: _searchCtl,
      searchFocus: _searchFocus,
      searchHint: 'بحث بالاسم/الكود/الهاتف…',
      onSearchChanged: () => setState(() {}),
      filterGroups: [
        activeGroup,
        if (cities.isNotEmpty) cityGroup,
      ],
      groupOptions: const [
        ApexGroupOption(
            key: 'none', labelAr: 'بلا تجميع', icon: Icons.view_list_rounded),
        ApexGroupOption(
            key: 'active',
            labelAr: 'الحالة',
            icon: Icons.toggle_on_rounded),
        ApexGroupOption(
            key: 'city',
            labelAr: 'المدينة',
            icon: Icons.location_city_rounded),
      ],
      activeGroupKey: _groupBy,
      onChangeGroup: (k) => setState(() => _groupBy = k),
      sortOptions: const [
        ApexFilterOption(key: 'name_asc', labelAr: 'الاسم (أ-ي)'),
        ApexFilterOption(key: 'name_desc', labelAr: 'الاسم (ي-أ)'),
        ApexFilterOption(key: 'code_asc', labelAr: 'الكود'),
        ApexFilterOption(key: 'recent', labelAr: 'الأحدث'),
      ],
      activeSortKey: _sortKey,
      onChangeSort: (k) => setState(() => _sortKey = k),
      onClearAllFilters: _activeMulti.isNotEmpty ||
              _city != 'all' ||
              _searchCtl.text.isNotEmpty
          ? _clearAllFilters
          : null,
      viewModes: const [
        ApexViewMode(
            key: 'list', labelAr: 'قائمة', icon: Icons.view_list_rounded),
        ApexViewMode(
            key: 'cards',
            labelAr: 'بطاقات',
            icon: Icons.grid_view_rounded),
      ],
      activeViewKey: _viewMode,
      onChangeView: (k) => setState(() => _viewMode = k),
      onCreate: _onCreate,
      createLabelAr: 'جديد',
      onAiCreate: _onAiCreate,
      aiCreateLabelAr: 'ذكاء',
      favorites: _loadFavorites(),
      onSaveFavorite: _onSaveCurrentView,
      selectedCount: _selectedIds.length,
      onClearSelection: _clearSelection,
      bulkActions: [
        ApexBulkAction(
          labelAr: 'تصدير CSV',
          icon: Icons.file_download_outlined,
          onTap: _bulkExportCsv,
        ),
        ApexBulkAction(
          labelAr: 'دفعة موحّدة',
          icon: Icons.payments_outlined,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AC.navy3,
            content: Text(
              'دفعة موحّدة لـ ${_selectedIds.length} مورد — قيد التطوير',
              style: TextStyle(color: AC.tp),
              textAlign: TextAlign.right,
            ),
          )),
        ),
      ],
      shortcuts: const [
        ApexShortcut('N', 'مورد جديد'),
        ApexShortcut('A', 'سؤال الذكاء'),
        ApexShortcut('/', 'بحث'),
        ApexShortcut('F', 'فلتر'),
        ApexShortcut('G', 'تجميع'),
        ApexShortcut('R', 'تحديث'),
        ApexShortcut('S', 'حفظ البحث الحالي'),
        ApexShortcut('Esc', 'إلغاء التحديد / إغلاق'),
      ],
      tips: const [
        ApexTip(
          titleAr: 'دفعة موحّدة لعدة موردين',
          bodyAr:
              'حدّد الموردين الذين تريد دفع مستحقاتهم في نفس اليوم ثم "دفعة موحّدة" — يولّد أمر دفع واحد من البنك بدل عمليات منفصلة، يوفّر رسوم التحويل.',
          icon: Icons.payments_outlined,
        ),
        ApexTip(
          titleAr: 'بحث بالرقم الضريبي',
          bodyAr:
              'حقل البحث يقبل الرقم الضريبي مباشرةً — مفيد عند تسجيل فاتورة جديدة وأنت تتحقق من وجود المورّد قبل إنشاء سجل مكرّر.',
          icon: Icons.numbers_rounded,
        ),
        ApexTip(
          titleAr: 'مساعد ذكاء على بيانات المورّدين',
          bodyAr:
              'زر "ذكاء" يفتح مساعد AI يعرف الموردين الظاهرين على شاشتك — اسأله "من أكثر مورّد تعاملنا معه آخر سنة؟" أو "أيهم لم نشتر منه منذ ٦ أشهر؟".',
          icon: Icons.auto_awesome_rounded,
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      color: AC.errSoft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Icon(Icons.error_outline, color: AC.err, size: 16),
        const SizedBox(width: 8),
        Expanded(
            child: Text(_error ?? '',
                style: TextStyle(color: AC.err, fontSize: 12))),
        TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading && _all.isEmpty) {
      return Center(
          child: CircularProgressIndicator(color: AC.gold, strokeWidth: 2));
    }
    final visible = _visible;
    if (visible.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_shipping_outlined, color: AC.ts, size: 48),
            const SizedBox(height: 12),
            Text('لا يوجد موردون مطابقون',
                style: TextStyle(color: AC.tp, fontSize: 14)),
            const SizedBox(height: 6),
            Text('جرّب إزالة الفلتر أو ابدأ بإضافة أول مورد',
                style: TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('مورد جديد'),
              style: FilledButton.styleFrom(
                  backgroundColor: AC.gold, foregroundColor: AC.navy),
            ),
          ],
        ),
      );
    }
    final groups = _grouped;
    return RefreshIndicator(
      onRefresh: _load,
      color: AC.gold,
      child: _viewMode == 'list'
          ? ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final entry in groups.entries) ...[
                  if (_groupBy != 'none')
                    _groupHeader(entry.key, entry.value.length),
                  ...entry.value.map(_vendorRow),
                ],
              ],
            )
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisExtent: 130,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: visible.length,
              itemBuilder: (_, i) => _vendorCard(visible[i]),
            ),
    );
  }

  Widget _groupHeader(String key, int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AC.navy3,
        border: Border(right: BorderSide(color: AC.gold, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        Text(key,
            style: TextStyle(
                color: AC.gold, fontSize: 12.5, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Text('($count)',
            style: TextStyle(
                color: AC.ts, fontSize: 11, fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _vendorRow(Map<String, dynamic> v) {
    final selected = _isSelected(v);
    final inSelectionMode = _selectedIds.isNotEmpty;
    final isActive = v['is_active'] == true;
    return InkWell(
      onTap: () => inSelectionMode
          ? _toggleSelected(v)
          : context.go('/app/erp/finance/vendors/${v['id']}'),
      onLongPress: () => _toggleSelected(v),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AC.gold.withValues(alpha: 0.10) : AC.navy2,
          border: Border.all(
              color: selected ? AC.gold.withValues(alpha: 0.6) : AC.bdr),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          if (inSelectionMode) ...[
            InkWell(
              onTap: () => _toggleSelected(v),
              child: Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: selected ? AC.gold : AC.td,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
          ],
          CircleAvatar(
            radius: 16,
            backgroundColor: AC.gold.withValues(alpha: 0.20),
            child: Icon(Icons.local_shipping, color: AC.gold, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${v['code'] ?? ''} — ${v['name_ar'] ?? '-'}',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('${v['phone'] ?? v['email'] ?? ''}',
                    style: TextStyle(color: AC.ts, fontSize: 11)),
              ],
            ),
          ),
          if (!isActive)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AC.td.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('غير نشط',
                  style: TextStyle(
                      color: AC.td,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          if (v['vat_number'] != null) ...[
            const SizedBox(width: 8),
            Text('${v['vat_number']}',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 10,
                    fontFamily: 'monospace')),
          ],
        ]),
      ),
    );
  }

  Widget _vendorCard(Map<String, dynamic> v) {
    final selected = _isSelected(v);
    final inSelectionMode = _selectedIds.isNotEmpty;
    final isActive = v['is_active'] == true;
    return InkWell(
      onTap: () => inSelectionMode
          ? _toggleSelected(v)
          : context.go('/app/erp/finance/vendors/${v['id']}'),
      onLongPress: () => _toggleSelected(v),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AC.gold.withValues(alpha: 0.10) : AC.navy2,
          border: Border.all(
              color: selected ? AC.gold.withValues(alpha: 0.6) : AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (inSelectionMode) ...[
                InkWell(
                  onTap: () => _toggleSelected(v),
                  child: Icon(
                    selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: selected ? AC.gold : AC.td,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              CircleAvatar(
                radius: 14,
                backgroundColor: AC.gold.withValues(alpha: 0.20),
                child: Icon(Icons.local_shipping, color: AC.gold, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${v['name_ar'] ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${v['code'] ?? ''}',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            const SizedBox(height: 2),
            Text('${v['phone'] ?? v['email'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AC.tp, fontSize: 12)),
            const Spacer(),
            Row(children: [
              if (v['vat_number'] != null)
                Text('${v['vat_number']}',
                    style: TextStyle(
                        color: AC.gold,
                        fontSize: 10,
                        fontFamily: 'monospace')),
              const Spacer(),
              if (!isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: AC.td.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('غير نشط',
                      style: TextStyle(
                          color: AC.td,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}
