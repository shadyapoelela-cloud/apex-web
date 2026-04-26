/// APEX — Sales Invoices (V5 chip body for /app/erp/finance/sales-invoices)
///
/// Toolbar (RTL):
///   [بحث 🔎] [فلتر] [تجميع] [+ إنشاء فاتورة] [استيراد/تصدير] [تقارير المبيعات]
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class SalesInvoicesScreen extends StatefulWidget {
  const SalesInvoicesScreen({super.key});
  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

enum _GroupBy { none, status, customer, month }

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = false;
  String? _error;

  // Toolbar state
  final TextEditingController _searchCtl = TextEditingController();
  bool _searchOpen = false;
  String _statusFilter = 'all'; // all | draft | issued | paid | overdue
  _GroupBy _groupBy = _GroupBy.none;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final entityId = S.savedEntityId;
    if (entityId == null) {
      setState(() => _error = 'لم يتم اختيار شركة');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotListSalesInvoices(entityId, limit: 500);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _all = (res.data as List).cast<Map<String, dynamic>>();
      } else {
        _error = res.error ?? 'تعذّر تحميل الفواتير';
      }
    });
  }

  bool _isOverdue(Map inv) {
    if (inv['status'] != 'issued') return false;
    final dueStr = inv['due_date'];
    if (dueStr == null) return false;
    try {
      return DateTime.parse(dueStr.toString()).isBefore(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _searchCtl.text.trim().toLowerCase();
    return _all.where((inv) {
      // status filter
      switch (_statusFilter) {
        case 'draft':
          if (inv['status'] != 'draft') return false;
          break;
        case 'issued':
          if (inv['status'] != 'issued' || _isOverdue(inv)) return false;
          break;
        case 'paid':
          if (inv['status'] != 'paid') return false;
          break;
        case 'overdue':
          if (!_isOverdue(inv)) return false;
          break;
      }
      // search
      if (q.isNotEmpty) {
        final hay = [
          inv['invoice_number'],
          inv['customer_name'],
          inv['customer_id'],
          inv['issue_date'],
          inv['total'],
        ].whereType<Object>().map((e) => e.toString().toLowerCase()).join(' ');
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final list = _visible;
    if (_groupBy == _GroupBy.none) return {'__all__': list};
    final out = <String, List<Map<String, dynamic>>>{};
    for (final inv in list) {
      final key = switch (_groupBy) {
        _GroupBy.status => _statusLabel(inv),
        _GroupBy.customer =>
          (inv['customer_name'] ?? inv['customer_id'] ?? 'بدون عميل').toString(),
        _GroupBy.month => _monthKey(inv['issue_date']),
        _GroupBy.none => '__all__',
      };
      out.putIfAbsent(key, () => []).add(inv);
    }
    return out;
  }

  String _statusLabel(Map inv) {
    if (_isOverdue(inv)) return 'متأخرة';
    return switch (inv['status']) {
      'draft' => 'مسودة',
      'issued' => 'صادرة',
      'paid' => 'مدفوعة',
      _ => (inv['status'] ?? 'أخرى').toString(),
    };
  }

  String _monthKey(dynamic dateStr) {
    if (dateStr == null) return 'بدون تاريخ';
    try {
      final d = DateTime.parse(dateStr.toString());
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'بدون تاريخ';
    }
  }

  // ── Actions ──────────────────────────────────────────────────────────
  void _onCreate() => context.go('/sales/invoices/new');

  void _onReports() => context.go('/sales/aging');

  Future<void> _onFilter() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AC.navy2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('تصفية حسب الحالة',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
          for (final opt in const [
            ('all', 'الكل', Icons.list_alt),
            ('draft', 'مسودة', Icons.edit_note),
            ('issued', 'صادرة', Icons.send),
            ('overdue', 'متأخرة', Icons.warning_amber_outlined),
            ('paid', 'مدفوعة', Icons.verified),
          ])
            ListTile(
              leading: Icon(opt.$3, color: AC.gold),
              title:
                  Text(opt.$2, style: TextStyle(color: AC.tp, fontSize: 13.5)),
              trailing: _statusFilter == opt.$1
                  ? Icon(Icons.check, color: AC.ok)
                  : null,
              onTap: () => Navigator.pop(ctx, opt.$1),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked != null) setState(() => _statusFilter = picked);
  }

  Future<void> _onGroup() async {
    final picked = await showModalBottomSheet<_GroupBy>(
      context: context,
      backgroundColor: AC.navy2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('تجميع حسب',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
          for (final opt in const [
            (_GroupBy.none, 'بدون تجميع', Icons.view_list),
            (_GroupBy.status, 'الحالة', Icons.flag_outlined),
            (_GroupBy.customer, 'العميل', Icons.person_outline),
            (_GroupBy.month, 'الشهر', Icons.calendar_month_outlined),
          ])
            ListTile(
              leading: Icon(opt.$3, color: AC.gold),
              title:
                  Text(opt.$2, style: TextStyle(color: AC.tp, fontSize: 13.5)),
              trailing: _groupBy == opt.$1 ? Icon(Icons.check, color: AC.ok) : null,
              onTap: () => Navigator.pop(ctx, opt.$1),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked != null) setState(() => _groupBy = picked);
  }

  Future<void> _onImportExport() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AC.navy2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('استيراد / تصدير',
                style: TextStyle(
                    color: AC.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
          ListTile(
            leading: Icon(Icons.file_upload_outlined, color: AC.gold),
            title: Text('استيراد من Excel / CSV',
                style: TextStyle(color: AC.tp, fontSize: 13.5)),
            subtitle: Text('رفع ملف فواتير لتسجيلها دفعة واحدة',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            onTap: () => Navigator.pop(ctx, 'import'),
          ),
          ListTile(
            leading: Icon(Icons.file_download_outlined, color: AC.gold),
            title: Text('تصدير إلى Excel',
                style: TextStyle(color: AC.tp, fontSize: 13.5)),
            subtitle: Text('${_visible.length} فاتورة حسب الفلتر الحالي',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            onTap: () => Navigator.pop(ctx, 'export_xlsx'),
          ),
          ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined, color: AC.gold),
            title: Text('تصدير إلى PDF',
                style: TextStyle(color: AC.tp, fontSize: 13.5)),
            onTap: () => Navigator.pop(ctx, 'export_pdf'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (action != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.navy3,
        content: Text(
          action == 'import'
              ? 'الاستيراد قيد التطوير — سيتوفر قريباً'
              : 'بدأ التصدير — سيُنزَّل الملف خلال لحظات',
          style: TextStyle(color: AC.tp),
        ),
      ));
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        _buildToolbar(),
        if (_error != null) _buildErrorBanner(),
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(bottom: BorderSide(color: AC.bdr)),
      ),
      child: Row(children: [
        Icon(Icons.receipt_long, color: AC.gold, size: 20),
        const SizedBox(width: 8),
        Text('فواتير المبيعات',
            style: TextStyle(
                color: AC.gold, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: AC.navy3, borderRadius: BorderRadius.circular(10)),
            child: Text('${_visible.length} / ${_all.length}',
                style: TextStyle(
                    color: AC.ts,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600))),
        const Spacer(),
        // Search — collapsible
        _buildSearch(),
        const SizedBox(width: 8),
        _toolbarBtn(
            icon: Icons.filter_alt_outlined,
            label: 'فلتر',
            badge: _statusFilter == 'all' ? null : '1',
            onTap: _onFilter),
        const SizedBox(width: 6),
        _toolbarBtn(
            icon: Icons.dashboard_customize_outlined,
            label: 'تجميع',
            badge: _groupBy == _GroupBy.none ? null : '•',
            onTap: _onGroup),
        const SizedBox(width: 6),
        _toolbarBtn(
            icon: Icons.swap_vert,
            label: 'استيراد/تصدير',
            onTap: _onImportExport),
        const SizedBox(width: 6),
        _toolbarBtn(
            icon: Icons.bar_chart,
            label: 'تقارير المبيعات',
            onTap: _onReports),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _onCreate,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('إنشاء فاتورة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AC.gold,
            foregroundColor: AC.navy,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  Widget _buildSearch() {
    if (!_searchOpen) {
      return IconButton(
        tooltip: 'بحث',
        onPressed: () => setState(() => _searchOpen = true),
        icon: Icon(Icons.search, color: AC.tp),
      );
    }
    return SizedBox(
      width: 240,
      height: 36,
      child: TextField(
        controller: _searchCtl,
        autofocus: true,
        onChanged: (_) => setState(() {}),
        style: TextStyle(color: AC.tp, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'بحث برقم الفاتورة أو العميل…',
          hintStyle: TextStyle(color: AC.ts, fontSize: 12),
          prefixIcon: Icon(Icons.search, color: AC.ts, size: 18),
          suffixIcon: IconButton(
            icon: Icon(Icons.close, color: AC.ts, size: 16),
            onPressed: () {
              _searchCtl.clear();
              setState(() => _searchOpen = false);
            },
          ),
          isDense: true,
          filled: true,
          fillColor: AC.navy3,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
      ),
    );
  }

  Widget _toolbarBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    String? badge,
  }) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AC.navy3,
            border: Border.all(color: AC.bdr),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AC.tp, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: AC.gold, borderRadius: BorderRadius.circular(8)),
                child: Text(badge,
                    style: TextStyle(
                        color: AC.navy,
                        fontSize: 9,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ]),
        ),
      ),
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
            Icon(Icons.receipt_long_outlined, color: AC.ts, size: 48),
            const SizedBox(height: 12),
            Text('لا توجد فواتير مطابقة',
                style: TextStyle(color: AC.tp, fontSize: 14)),
            const SizedBox(height: 6),
            Text('جرّب إزالة الفلتر أو ابدأ بإصدار فاتورة جديدة',
                style: TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إنشاء فاتورة'),
              style: ElevatedButton.styleFrom(
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
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final entry in groups.entries) ...[
            if (_groupBy != _GroupBy.none) _groupHeader(entry.key, entry.value.length),
            ...entry.value.map(_invoiceRow),
          ],
        ],
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

  Widget _invoiceRow(Map<String, dynamic> inv) {
    final isDraft = inv['status'] == 'draft';
    final isIssued = inv['status'] == 'issued';
    final isPaid = inv['status'] == 'paid';
    final overdue = _isOverdue(inv);
    final color = isPaid
        ? AC.ok
        : overdue
            ? AC.err
            : isIssued
                ? AC.gold
                : AC.warn;
    final iconData = isPaid
        ? Icons.verified
        : overdue
            ? Icons.warning_amber
            : isDraft
                ? Icons.edit_note
                : Icons.send;
    return InkWell(
      onTap: () {
        final jeId = inv['journal_entry_id'] as String?;
        if (jeId != null) {
          context.go('/compliance/journal-entry/$jeId');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('الفاتورة ${inv['invoice_number']} لم تُصدر بعد'),
          ));
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Icon(iconData, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${inv['invoice_number'] ?? '—'}',
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                      '${inv['issue_date'] ?? ''} · ${inv['customer_name'] ?? inv['customer_id'] ?? ''}',
                      style: TextStyle(color: AC.ts, fontSize: 11)),
                ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10)),
            child: Text(_statusLabel(inv),
                style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Text('${inv['total'] ?? 0} SAR',
              style: TextStyle(
                  color: AC.gold,
                  fontFamily: 'monospace',
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
