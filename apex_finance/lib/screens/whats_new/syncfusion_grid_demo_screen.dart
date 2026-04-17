/// Syncfusion DataGrid demo screen.
///
/// Shows the high-performance alternative from V2 blueprint § 2.0 in
/// action: 5,000 rows, 2 frozen columns, sortable + inline-edit-ready.
/// ApexDataTable is fine up to ~500 rows; beyond that this widget
/// kicks in.
library;

import 'package:flutter/material.dart';

import '../../core/apex_app_bar.dart';
import '../../core/apex_data_table.dart' show ApexColumn;
import '../../core/apex_syncfusion_grid.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class SyncfusionGridDemoScreen extends StatelessWidget {
  const SyncfusionGridDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = _seed(5000);
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: const ApexAppBar(title: '📊 Syncfusion DataGrid — 5,000 صف'),
      body: Column(
        children: [
          _banner(rows.length),
          Expanded(
            child: ApexSyncfusionGrid<_Row>(
              rows: rows,
              frozenColumns: const {'id', 'customer'},
              columns: [
                ApexColumn<_Row>(
                  key: 'id',
                  label: 'رقم',
                  cell: (r) => Text(r.id,
                      style: TextStyle(
                          color: AC.gold,
                          fontSize: AppFontSize.sm,
                          fontFamily: 'monospace')),
                  sortValue: (r) => r.id,
                  width: 110,
                ),
                ApexColumn<_Row>(
                  key: 'customer',
                  label: 'العميل',
                  cell: (r) => Text(r.customer,
                      style: TextStyle(color: AC.tp, fontSize: AppFontSize.sm)),
                  sortValue: (r) => r.customer,
                  width: 180,
                ),
                ApexColumn<_Row>(
                  key: 'date',
                  label: 'التاريخ',
                  cell: (r) => Text(r.date,
                      style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm)),
                  sortValue: (r) => r.date,
                  width: 130,
                ),
                ApexColumn<_Row>(
                  key: 'amount',
                  label: 'المبلغ',
                  numeric: true,
                  cell: (r) => Text(r.amount.toStringAsFixed(2),
                      style: TextStyle(
                          color: AC.gold,
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                  sortValue: (r) => r.amount,
                  width: 130,
                ),
                ApexColumn<_Row>(
                  key: 'status',
                  label: 'الحالة',
                  cell: (r) => _statusPill(r.status),
                  sortValue: (r) => r.status,
                  width: 120,
                ),
                ApexColumn<_Row>(
                  key: 'vat',
                  label: 'VAT',
                  numeric: true,
                  cell: (r) => Text(r.vat.toStringAsFixed(2),
                      style: TextStyle(
                          color: AC.ts, fontSize: AppFontSize.sm)),
                  sortValue: (r) => r.vat,
                  width: 100,
                ),
                ApexColumn<_Row>(
                  key: 'total',
                  label: 'الإجمالي',
                  numeric: true,
                  cell: (r) => Text(r.total.toStringAsFixed(2),
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: AppFontSize.sm,
                          fontWeight: FontWeight.w700)),
                  sortValue: (r) => r.total,
                  width: 130,
                ),
                ApexColumn<_Row>(
                  key: 'currency',
                  label: 'العملة',
                  cell: (r) => Text(r.currency,
                      style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm)),
                  sortValue: (r) => r.currency,
                  width: 80,
                ),
                ApexColumn<_Row>(
                  key: 'notes',
                  label: 'ملاحظات',
                  cell: (r) => Text(r.notes,
                      style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                      overflow: TextOverflow.ellipsis),
                  sortValue: (r) => r.notes,
                  width: 220,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner(int n) => Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.2), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.bolt, color: AC.gold, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$n صف — 9 أعمدة — عمودان مجمّدان',
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: AppFontSize.lg,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Syncfusion virtual-scroll يُرسم فقط ما يظهر على الشاشة. جرّب الفرز على أي عمود، ثم مرّر أفقياً لتجربة الأعمدة المجمّدة.',
                    style: TextStyle(
                        color: AC.ts, fontSize: AppFontSize.sm),
                  ),
                ]),
          ),
        ]),
      );

  Widget _statusPill(String s) {
    final (color, label) = switch (s) {
      'paid' => (AC.ok, 'مدفوعة'),
      'overdue' => (AC.err, 'متأخرة'),
      'sent' => (AC.gold, 'مُرسلة'),
      _ => (AC.ts, 'مسودة'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w700)),
    );
  }

  static List<_Row> _seed(int n) {
    const customers = [
      'شركة الرياض للتجارة',
      'مؤسسة النجم الذهبي',
      'المتحدة للمقاولات',
      'آفاق التقنية',
      'صناعات الخليج',
      'مجموعة الأمانة',
      'البنك الأهلي السعودي',
      'مطاعم النخبة',
    ];
    const statuses = ['paid', 'sent', 'overdue', 'draft'];
    final rows = <_Row>[];
    for (var i = 0; i < n; i++) {
      final amount = (1000 + (i * 37) % 98000).toDouble();
      final vat = amount * 0.15;
      rows.add(_Row(
        id: 'INV-${(1000 + i).toString()}',
        customer: customers[i % customers.length],
        date: '2026-${(1 + (i % 12)).toString().padLeft(2, '0')}-${(1 + (i % 28)).toString().padLeft(2, '0')}',
        amount: amount,
        vat: vat,
        total: amount + vat,
        status: statuses[i % statuses.length],
        currency: i % 5 == 0 ? 'USD' : 'SAR',
        notes: 'ملاحظة رقم $i — تفاصيل إضافية هنا',
      ));
    }
    return rows;
  }
}

class _Row {
  final String id;
  final String customer;
  final String date;
  final double amount;
  final double vat;
  final double total;
  final String status;
  final String currency;
  final String notes;
  const _Row({
    required this.id,
    required this.customer,
    required this.date,
    required this.amount,
    required this.vat,
    required this.total,
    required this.status,
    required this.currency,
    required this.notes,
  });
}
