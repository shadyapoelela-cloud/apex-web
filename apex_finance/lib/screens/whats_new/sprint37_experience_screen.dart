/// Sprint 37-38 Enhanced Experience — right preview panel, app switcher,
/// contextual toolbar, entity breadcrumb, responsive demo.
library;

import 'package:flutter/material.dart';

import '../../core/apex_app_switcher.dart';
import '../../core/apex_contextual_toolbar.dart';
import '../../core/apex_data_table.dart';
import '../../core/apex_entity_breadcrumb.dart';
import '../../core/apex_preview_panel.dart';
import '../../core/apex_responsive.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class Sprint37ExperienceScreen extends StatefulWidget {
  const Sprint37ExperienceScreen({super.key});

  @override
  State<Sprint37ExperienceScreen> createState() =>
      _Sprint37ExperienceScreenState();
}

class _Sprint37ExperienceScreenState extends State<Sprint37ExperienceScreen> {
  final Set<_Row> _selected = {};
  _Row? _preview;

  late final List<_Row> _rows = List.generate(8, (i) {
    return _Row(
      id: 'INV-${1000 + i}',
      client: [
        'شركة الرياض للتجارة',
        'مؤسسة النجم الذهبي',
        'المتحدة للمقاولات',
        'آفاق التقنية',
      ][i % 4],
      amount: 1250.0 + i * 370.5,
      status: ['draft', 'sent', 'paid', 'overdue'][i % 4],
    );
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: '✨ Sprint 37-38: تجربة محسَّنة',
            actions: [
              ApexToolbarAction(
                label: 'التطبيقات',
                icon: Icons.apps,
                onPressed: () => showApexAppSwitcher(context),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: ApexEntityBreadcrumb(
              crumbs: [
                const ApexCrumb(
                    label: 'الرئيسية',
                    route: '/home',
                    icon: Icons.home_outlined),
                const ApexCrumb(
                    label: 'ما الجديد', route: '/whats-new'),
                const ApexCrumb(
                    label: 'Sprint 37-38: تجربة محسَّنة'),
              ],
            ),
          ),
          ApexContextualToolbar(
            selectedCount: _selected.length,
            idleActions: [
              ApexAction(
                label: 'فاتورة جديدة',
                icon: Icons.add,
                onPressed: () => _toast('سيُفتح نموذج الفاتورة'),
              ),
              ApexAction(
                label: 'استيراد CSV',
                icon: Icons.file_upload_outlined,
                onPressed: () => _toast('استيراد CSV'),
              ),
              ApexAction(
                label: 'تصدير',
                icon: Icons.file_download_outlined,
                onPressed: () => _toast('تصدير'),
              ),
            ],
            bulkActions: [
              ApexAction(
                label: 'تعليم كمدفوعة',
                icon: Icons.check_circle_outline,
                onPressed: () => _bulkMarkPaid(),
              ),
              ApexAction(
                label: 'إرسال تذكير',
                icon: Icons.notifications_active_outlined,
                onPressed: () => _toast('إرسال ${_selected.length} تذكيراً'),
              ),
              ApexAction(
                label: 'حذف',
                icon: Icons.delete_outline,
                destructive: true,
                onPressed: () => _bulkDelete(),
              ),
            ],
            onClearSelection: () => setState(_selected.clear),
          ),
          Expanded(child: _splitLayout(context)),
        ],
      ),
    );
  }

  Widget _splitLayout(BuildContext context) {
    // On mobile: stacked, no preview panel.
    // On tablet: 60/40 split with collapsible preview.
    // On desktop: 65/35 split, preview always visible.
    return ResponsiveBuilder(
      mobile: _list(),
      tablet: Row(children: [
        Expanded(flex: 6, child: _list()),
        if (_preview != null)
          Expanded(flex: 4, child: _previewPane()),
      ]),
      desktop: Row(children: [
        Expanded(flex: 13, child: _list()),
        if (_preview != null)
          Expanded(flex: 7, child: _previewPane()),
      ]),
    );
  }

  Widget _list() {
    return ApexDataTable<_Row>(
      rows: _rows,
      showCheckboxes: true,
      onSelectionChanged: (s) => setState(() {
        _selected
          ..clear()
          ..addAll(s);
      }),
      onRowTap: (r) => setState(() => _preview = r),
      columns: [
        ApexColumn<_Row>(
          key: 'id',
          label: 'رقم الفاتورة',
          cell: (r) => Text(r.id, style: TextStyle(color: AC.tp)),
          sortValue: (r) => r.id,
          width: 130,
        ),
        ApexColumn<_Row>(
          key: 'client',
          label: 'العميل',
          cell: (r) => Text(r.client,
              style: TextStyle(color: AC.tp),
              overflow: TextOverflow.ellipsis),
          sortValue: (r) => r.client,
          flex: 2,
        ),
        ApexColumn<_Row>(
          key: 'amount',
          label: 'المبلغ',
          numeric: true,
          cell: (r) => Text(r.amount.toStringAsFixed(2),
              style: TextStyle(
                  color: AC.gold,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          sortValue: (r) => r.amount,
          width: 130,
        ),
        ApexColumn<_Row>(
          key: 'status',
          label: 'الحالة',
          cell: (r) => _statusBadge(r.status),
          sortValue: (r) => r.status,
          width: 110,
        ),
      ],
    );
  }

  Widget _previewPane() {
    final r = _preview!;
    return ApexPreviewPanel(
      title: r.id,
      subtitle: r.client,
      onClose: () => setState(() => _preview = null),
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('رقم الفاتورة', r.id),
              _kv('العميل', r.client),
              _kv('المبلغ', '${r.amount.toStringAsFixed(2)} ر.س'),
              _kv('الحالة', _statusLabel(r.status)),
              const Divider(height: 32),
              Text('تفاصيل',
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'هذه لوحة المعاينة اليمنى (Xero-style). افتح أي صف من القائمة لترى تفاصيله هنا دون مغادرة الشاشة — يوفّر نقرات ويُبقي المستخدم في تدفّقه.',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('فتح كاملاً'),
                onPressed: () =>
                    _toast('سينتقل إلى /compliance/zatca-invoice/${r.id}'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 100,
              child: Text(k,
                  style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm))),
          Expanded(
              child: Text(v,
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w500))),
        ]),
      );

  Widget _statusBadge(String s) {
    final (color, label) = switch (s) {
      'paid' => (AC.ok, 'مدفوعة'),
      'sent' => (AC.gold, 'مُرسلة'),
      'overdue' => (AC.err, 'متأخرة'),
      _ => (AC.ts, 'مسودة'),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600)),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'paid' => 'مدفوعة',
        'sent' => 'مُرسلة',
        'overdue' => 'متأخرة',
        _ => 'مسودة',
      };

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));
  }

  void _bulkMarkPaid() {
    setState(() {
      for (final r in _selected) {
        r.status = 'paid';
      }
      _selected.clear();
    });
    _toast('تم التعليم');
  }

  void _bulkDelete() {
    setState(() {
      _rows.removeWhere(_selected.contains);
      _selected.clear();
      if (_preview != null && !_rows.contains(_preview)) _preview = null;
    });
    _toast('تم الحذف');
  }
}

class _Row {
  final String id;
  String client;
  double amount;
  String status;
  _Row({
    required this.id,
    required this.client,
    required this.amount,
    required this.status,
  });
}
