/// APEX — Customers List (V5 chip body for /app/erp/app/erp/finance/sales-customers)
///
/// Wave 2 of APEX_IMPROVEMENT_PLAN.md — migrated from `ApexListShell`
/// to the unified `ApexListToolbar` pattern (Odoo-style ribbon, chip
/// search bar, accordion filter panel, bulk-select + AI drawer).
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
import 'customer_create_modal.dart';

const String _kScreenKey = '/app/erp/finance/sales-customers';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});
  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
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
    final res = await ApiService.pilotListCustomers(tenantId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _all = (res.data as List).cast<Map<String, dynamic>>();
      } else {
        _error = res.error ?? 'تعذّر تحميل العملاء';
      }
    });
  }

  // ── Selection helpers ────────────────────────────────────────────────
  bool _isSelected(Map c) =>
      _selectedIds.contains(c['id']?.toString());

  void _toggleSelected(Map c) {
    final id = c['id']?.toString();
    if (id == null) return;
    setState(() {
      if (!_selectedIds.add(id)) _selectedIds.remove(id);
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  // ── Filter / sort derivation ─────────────────────────────────────────
  List<Map<String, dynamic>> get _visible {
    final q = _searchCtl.text.trim().toLowerCase();
    var list = _all.where((c) {
      // Active multi: 'active' / 'inactive' keys
      if (_activeMulti.isNotEmpty) {
        final isActive = c['is_active'] == true;
        final wantActive = _activeMulti.contains('active');
        final wantInactive = _activeMulti.contains('inactive');
        if (isActive && !wantActive) return false;
        if (!isActive && !wantInactive) return false;
      }
      // City single-select
      if (_city != 'all') {
        if ((c['city'] ?? '').toString() != _city) return false;
      }
      // Free-text search
      if (q.isNotEmpty) {
        final hay = [
          c['code'],
          c['name_ar'],
          c['name_en'],
          c['phone'],
          c['email'],
          c['vat_number'],
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
    for (final c in list) {
      final key = switch (_groupBy) {
        'active' => (c['is_active'] == true) ? 'نشط' : 'غير نشط',
        'city' => (c['city'] ?? 'بدون مدينة').toString(),
        _ => '__all__',
      };
      out.putIfAbsent(key, () => []).add(c);
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
  // G-FIN-CUSTOMERS-COMPLETE (Sprint 2, 2026-05-09): the toolbar
  // "+ جديد" button now opens `CustomerCreateModal` (POSTs
  // `/pilot/tenants/{id}/customers`) and refreshes the list inline on
  // success, instead of routing to the placeholder /sales page.
  Future<void> _onCreate() async {
    final created = await CustomerCreateModal.show(context);
    if (created == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.ok,
      content: Text(
          'تم إنشاء العميل ${created['name_ar'] ?? ''} (${created['code'] ?? ''})'),
    ));
    await _load();
  }
  void _onAiCreate() => _scaffoldKey.currentState?.openEndDrawer();

  void _bulkExportCsv() {
    final selectedRows = _all
        .where((c) => _selectedIds.contains(c['id']?.toString()))
        .toList();
    if (selectedRows.isEmpty) return;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    ApexCsvExport.download<Map<String, dynamic>>(
      filename: 'customers-$stamp',
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
        content: Text('تم تصدير ${selectedRows.length} عميل كـ CSV',
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
        screenName: 'العملاء',
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

    // Build city options dynamically
    final cities = <String>{};
    for (final c in _all) {
      final city = (c['city'] ?? '').toString();
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
      titleAr: 'العملاء',
      titleIcon: Icons.people_rounded,
      itemNounAr: 'عميل',
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
          labelAr: 'حملة WhatsApp',
          icon: Icons.message_outlined,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: AC.navy3,
            content: Text(
              'حملة WhatsApp لـ ${_selectedIds.length} عميل — قيد التطوير',
              style: TextStyle(color: AC.tp),
              textAlign: TextAlign.right,
            ),
          )),
        ),
      ],
      shortcuts: const [
        ApexShortcut('N', 'عميل جديد'),
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
          titleAr: 'بحث سريع',
          bodyAr:
              'حقل البحث يطابق الكود، الاسم العربي/الإنجليزي، الهاتف، البريد، والرقم الضريبي دفعة واحدة. اكتب أي جزء وستظهر النتائج فوراً.',
          icon: Icons.search_rounded,
        ),
        ApexTip(
          titleAr: 'تجميع حسب المدينة',
          bodyAr:
              'استخدم تجميع "المدينة" لرؤية انتشار قاعدة عملائك جغرافياً — مفيد لفِرَق المبيعات الميدانية وتخطيط الزيارات.',
          icon: Icons.location_city_rounded,
        ),
        ApexTip(
          titleAr: 'حملات WhatsApp مستهدفة',
          bodyAr:
              'حدّد عملاء (long-press أو checkbox) ثم "حملة WhatsApp" لإرسال رسالة موحّدة — تذكير بفاتورة، عرض موسمي، إعلان منتج جديد.',
          icon: Icons.message_outlined,
        ),
      ],
    );
  }

  // ── Body / row / card ────────────────────────────────────────────────
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
            Icon(Icons.people_outline, color: AC.ts, size: 48),
            const SizedBox(height: 12),
            Text('لا يوجد عملاء مطابقون',
                style: TextStyle(color: AC.tp, fontSize: 14)),
            const SizedBox(height: 6),
            Text('جرّب إزالة الفلتر أو ابدأ بإضافة أول عميل',
                style: TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('عميل جديد'),
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
                  ...entry.value.map(_customerRow),
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
              itemBuilder: (_, i) => _customerCard(visible[i]),
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

  Widget _customerRow(Map<String, dynamic> c) {
    final selected = _isSelected(c);
    final inSelectionMode = _selectedIds.isNotEmpty;
    final isActive = c['is_active'] == true;
    return InkWell(
      onTap: () => inSelectionMode
          ? _toggleSelected(c)
          : context.go('/app/erp/finance/customers/${c['id']}'),
      onLongPress: () => _toggleSelected(c),
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
              onTap: () => _toggleSelected(c),
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
            child: Icon(Icons.business, color: AC.gold, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['code'] ?? ''} — ${c['name_ar'] ?? '-'}',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                Text('${c['phone'] ?? c['email'] ?? ''}',
                    style: TextStyle(color: AC.ts, fontSize: 11)),
              ],
            ),
          ),
          if (!isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AC.td.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('غير نشط',
                  style: TextStyle(
                      color: AC.td,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          if (c['vat_number'] != null) ...[
            const SizedBox(width: 8),
            Text('${c['vat_number']}',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 10,
                    fontFamily: 'monospace')),
          ],
        ]),
      ),
    );
  }

  Widget _customerCard(Map<String, dynamic> c) {
    final selected = _isSelected(c);
    final inSelectionMode = _selectedIds.isNotEmpty;
    final isActive = c['is_active'] == true;
    return InkWell(
      onTap: () => inSelectionMode
          ? _toggleSelected(c)
          : context.go('/app/erp/finance/customers/${c['id']}'),
      onLongPress: () => _toggleSelected(c),
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
                  onTap: () => _toggleSelected(c),
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
                child: Icon(Icons.business, color: AC.gold, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${c['name_ar'] ?? '-'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
              ),
            ]),
            const SizedBox(height: 8),
            Text('${c['code'] ?? ''}',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            const SizedBox(height: 2),
            Text('${c['phone'] ?? c['email'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AC.tp, fontSize: 12)),
            const Spacer(),
            Row(children: [
              if (c['vat_number'] != null)
                Text('${c['vat_number']}',
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
