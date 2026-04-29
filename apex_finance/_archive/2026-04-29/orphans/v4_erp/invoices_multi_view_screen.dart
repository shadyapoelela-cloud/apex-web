/// APEX V5.1 — Invoices with Multiple Views (Enhancement #4 demo).
///
/// Shows the same invoice data in 5 different views:
///   - List    (tabular, default)
///   - Kanban  (by status: draft/sent/paid/overdue)
///   - Calendar (by due date)
///   - Gallery (cards grid)
///   - Pivot   (aggregated by customer × month)
///
/// Route: /app/erp/finance/invoices
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/apex_v5_multi_view.dart';

class InvoicesMultiViewScreen extends StatelessWidget {
  const InvoicesMultiViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final invoices = _mockInvoices();
    return ApexV5MultiView<_Invoice>(
      items: invoices,
      initialMode: V5ViewMode.list,
      availableModes: const [
        V5ViewMode.list,
        V5ViewMode.kanban,
        V5ViewMode.calendar,
        V5ViewMode.gallery,
        V5ViewMode.pivot,
      ],
      trailing: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: core_theme.AC.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${invoices.length} فاتورة',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: core_theme.AC.info,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 14),
            label: const Text('فاتورة جديدة'),
            style: OutlinedButton.styleFrom(
              textStyle: const TextStyle(fontSize: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          ),
        ],
      ),
      listBuilder: (ctx, items) => _ListView(invoices: items),
      kanbanBuilder: (ctx, items) => _KanbanView(invoices: items),
      calendarBuilder: (ctx, items) => _CalendarView(invoices: items),
      galleryBuilder: (ctx, items) => _GalleryView(invoices: items),
      pivotBuilder: (ctx, items) => _PivotView(invoices: items),
    );
  }

  List<_Invoice> _mockInvoices() => [
        _Invoice('INV-2026-001', 'ABC Trading Co', 12500, DateTime(2026, 4, 10), _Status.paid),
        _Invoice('INV-2026-002', 'Marriott Hotels', 5000, DateTime(2026, 4, 15), _Status.sent),
        _Invoice('INV-2026-003', 'STC Telecom', 1250, DateTime(2026, 4, 5), _Status.paid),
        _Invoice('INV-2026-004', 'Al Rajhi Bank', 87500, DateTime(2026, 4, 20), _Status.overdue),
        _Invoice('INV-2026-005', 'ARAMCO', 245000, DateTime(2026, 4, 28), _Status.sent),
        _Invoice('INV-2026-006', 'SABIC', 18500, DateTime(2026, 5, 3), _Status.draft),
        _Invoice('INV-2026-007', 'Etihad Airways', 32000, DateTime(2026, 5, 7), _Status.sent),
        _Invoice('INV-2026-008', 'Saudi Telecom', 9800, DateTime(2026, 4, 12), _Status.paid),
        _Invoice('INV-2026-009', 'Mobily', 7200, DateTime(2026, 4, 22), _Status.overdue),
        _Invoice('INV-2026-010', 'Jarir Bookstore', 4500, DateTime(2026, 5, 10), _Status.draft),
        _Invoice('INV-2026-011', 'Almarai', 15600, DateTime(2026, 5, 14), _Status.sent),
        _Invoice('INV-2026-012', 'NCB', 58000, DateTime(2026, 4, 8), _Status.paid),
      ];
}

enum _Status { draft, sent, paid, overdue }

class _Invoice {
  final String id;
  final String customer;
  final double amount;
  final DateTime dueDate;
  final _Status status;

  _Invoice(this.id, this.customer, this.amount, this.dueDate, this.status);
}

Color _statusColor(_Status s) {
  switch (s) {
    case _Status.draft: return const Color(0xFF6B7280);
    case _Status.sent: return core_theme.AC.info;
    case _Status.paid: return core_theme.AC.ok;
    case _Status.overdue: return const Color(0xFFB91C1C);
  }
}

String _statusLabel(_Status s) {
  switch (s) {
    case _Status.draft: return 'مسودّة';
    case _Status.sent: return 'مرسلة';
    case _Status.paid: return 'مدفوعة';
    case _Status.overdue: return 'متأخرة';
  }
}

// ──────────────────────────────────────────────────────────────────────
// View 1: List (Table)
// ──────────────────────────────────────────────────────────────────────

class _ListView extends StatelessWidget {
  final List<_Invoice> invoices;
  const _ListView({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.1)),
        ),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
          columns: const [
            DataColumn(label: Text('الرقم', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('العميل', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('المبلغ', style: TextStyle(fontWeight: FontWeight.w700)), numeric: true),
            DataColumn(label: Text('تاريخ الاستحقاق', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('الحالة', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
          rows: invoices.map((inv) {
            final color = _statusColor(inv.status);
            return DataRow(cells: [
              DataCell(Text(inv.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
              DataCell(Text(inv.customer)),
              DataCell(Text('${inv.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontFamily: 'monospace'))),
              DataCell(Text(inv.dueDate.toString().substring(0, 10))),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _statusLabel(inv.status),
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                ),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// View 2: Kanban (by status)
// ──────────────────────────────────────────────────────────────────────

class _KanbanView extends StatelessWidget {
  final List<_Invoice> invoices;
  const _KanbanView({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in _Status.values) ...[
            _kanbanColumn(s),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }

  Widget _kanbanColumn(_Status status) {
    final items = invoices.where((i) => i.status == status).toList();
    final total = items.fold(0.0, (sum, i) => sum + i.amount);
    final color = _statusColor(status);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.25))),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                  _statusLabel(status),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'الإجمالي: ${total.toStringAsFixed(0)} ر.س',
              style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace'),
            ),
          ),
          for (final inv in items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: _KanbanCard(invoice: inv),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _KanbanCard extends StatelessWidget {
  final _Invoice invoice;
  const _KanbanCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(color: core_theme.AC.tp.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            invoice.id,
            style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 2),
          Text(
            invoice.customer,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${invoice.amount.toStringAsFixed(0)} ر.س',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace'),
              ),
              const Spacer(),
              Icon(Icons.event, size: 11, color: core_theme.AC.td),
              const SizedBox(width: 2),
              Text(
                invoice.dueDate.toString().substring(5, 10),
                style: TextStyle(fontSize: 10, color: core_theme.AC.ts),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// View 3: Calendar (by due date)
// ──────────────────────────────────────────────────────────────────────

class _CalendarView extends StatelessWidget {
  final List<_Invoice> invoices;
  const _CalendarView({required this.invoices});

  @override
  Widget build(BuildContext context) {
    // Group by date
    final byDate = <String, List<_Invoice>>{};
    for (final inv in invoices) {
      final key = inv.dueDate.toString().substring(0, 10);
      byDate.putIfAbsent(key, () => []).add(inv);
    }
    final sortedDates = byDate.keys.toList()..sort();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (ctx, i) {
        final date = sortedDates[i];
        final items = byDate[date]!;
        final total = items.fold(0.0, (s, i) => s + i.amount);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: core_theme.AC.info.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 16, color: core_theme.AC.info),
                    const SizedBox(width: 8),
                    Text(
                      date,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length} فواتير · ${total.toStringAsFixed(0)} ر.س',
                      style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
                    ),
                  ],
                ),
              ),
              for (final inv in items)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _statusColor(inv.status),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv.customer, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(inv.id, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                      Text(
                        '${inv.amount.toStringAsFixed(0)} ر.س',
                        style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// View 4: Gallery (grid of cards)
// ──────────────────────────────────────────────────────────────────────

class _GalleryView extends StatelessWidget {
  final List<_Invoice> invoices;
  const _GalleryView({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = constraints.maxWidth > 1000 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: cols,
            childAspectRatio: 1.3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final inv in invoices) _GalleryCard(invoice: inv),
            ],
          ),
        );
      },
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final _Invoice invoice;
  const _GalleryCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(invoice.status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.receipt, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invoice.id,
                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            invoice.customer,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            '${invoice.amount.toStringAsFixed(0)} ر.س',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _statusLabel(invoice.status),
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────
// View 5: Pivot (customer × month aggregation)
// ──────────────────────────────────────────────────────────────────────

class _PivotView extends StatelessWidget {
  final List<_Invoice> invoices;
  const _PivotView({required this.invoices});

  @override
  Widget build(BuildContext context) {
    // Pivot: customer → month → sum
    final customers = invoices.map((i) => i.customer).toSet().toList()..sort();
    final months = invoices.map((i) => i.dueDate.month).toSet().toList()..sort();

    double sumFor(String customer, int month) {
      return invoices
          .where((i) => i.customer == customer && i.dueDate.month == month)
          .fold(0.0, (s, i) => s + i.amount);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.1)),
          ),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
            columns: [
              const DataColumn(label: Text('العميل', style: TextStyle(fontWeight: FontWeight.w700))),
              for (final m in months)
                DataColumn(
                  label: Text('شهر $m', style: const TextStyle(fontWeight: FontWeight.w700)),
                  numeric: true,
                ),
              const DataColumn(label: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w700)), numeric: true),
            ],
            rows: [
              for (final c in customers)
                DataRow(cells: [
                  DataCell(Text(c, style: const TextStyle(fontWeight: FontWeight.w600))),
                  for (final m in months)
                    DataCell(Text(
                      sumFor(c, m) > 0 ? '${sumFor(c, m).toStringAsFixed(0)}' : '—',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: sumFor(c, m) > 0 ? core_theme.AC.tp : core_theme.AC.td,
                      ),
                    )),
                  DataCell(Text(
                    '${months.fold(0.0, (s, m) => s + sumFor(c, m)).toStringAsFixed(0)} ر.س',
                    style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700, color: core_theme.AC.ok),
                  )),
                ]),
              DataRow(
                color: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                cells: [
                  const DataCell(Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w800))),
                  for (final m in months)
                    DataCell(Text(
                      invoices.where((i) => i.dueDate.month == m).fold(0.0, (s, i) => s + i.amount).toStringAsFixed(0),
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800),
                    )),
                  DataCell(Text(
                    '${invoices.fold(0.0, (s, i) => s + i.amount).toStringAsFixed(0)} ر.س',
                    style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, color: core_theme.AC.ok),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
