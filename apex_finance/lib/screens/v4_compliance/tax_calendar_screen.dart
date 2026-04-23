/// APEX Wave 54 — Tax Calendar.
/// Route: /app/compliance/tax/calendar
///
/// Unified view of all tax & regulatory filing deadlines.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class TaxCalendarScreen extends StatefulWidget {
  const TaxCalendarScreen({super.key});
  @override
  State<TaxCalendarScreen> createState() => _TaxCalendarScreenState();
}

class _TaxCalendarScreenState extends State<TaxCalendarScreen> {
  String _filter = 'all';

  final _deadlines = <_Deadline>[
    _Deadline('VAT', 'ضريبة القيمة المضافة — أبريل', '2026-05-31', 'monthly', 'upcoming', 'ZATCA', 48250, 'إقرار + دفع'),
    _Deadline('WHT', 'ضريبة الاستقطاع — أبريل', '2026-05-31', 'monthly', 'upcoming', 'ZATCA', 21500, 'إقرار + دفع'),
    _Deadline('GOSI', 'التأمينات الاجتماعية — أبريل', '2026-05-15', 'monthly', 'upcoming', 'GOSI', 156700, 'مسير + دفع'),
    _Deadline('WPS', 'نظام حماية الأجور — أبريل', '2026-05-01', 'monthly', 'urgent', 'BANK/SAMA', 820000, 'تحويل بنكي'),
    _Deadline('ZATCA E-INV', 'الفوترة الإلكترونية اليومية', '2026-04-19', 'daily', 'today', 'ZATCA', 0, 'إرسال الفواتير'),
    _Deadline('VAT', 'ضريبة القيمة المضافة — الربع الأول', '2026-04-30', 'quarterly', 'urgent', 'ZATCA', 185000, 'تسوية ربعية'),
    _Deadline('CT', 'ضريبة الدخل السنوية 2025', '2026-09-30', 'yearly', 'planned', 'ZATCA', 425000, 'إقرار + دفع'),
    _Deadline('ZAKAT', 'الزكاة 1447هـ', '2026-11-23', 'yearly', 'planned', 'ZATCA', 185600, 'إقرار سنوي'),
    _Deadline('WHT', 'ضريبة الاستقطاع — السنوية 2025', '2026-04-30', 'yearly', 'urgent', 'ZATCA', 0, 'إقرار سنوي'),
    _Deadline('TP', 'إفصاح أسعار التحويل 2025', '2026-09-30', 'yearly', 'planned', 'ZATCA', 0, 'نموذج + وثائق'),
    _Deadline('CBCR', 'CbCR Notification 1447', '2026-03-31', 'yearly', 'overdue', 'ZATCA', 0, 'إشعار'),
    _Deadline('ESR', 'الاختبار الاقتصادي UAE', '2026-06-30', 'yearly', 'planned', 'UAE FTA', 0, 'إفادة'),
  ];

  List<_Deadline> get _filtered {
    if (_filter == 'all') return _deadlines;
    return _deadlines.where((d) => d.status == _filter || d.type == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _deadlines.where((d) => d.status == 'overdue').length;
    final urgent = _deadlines.where((d) => d.status == 'urgent').length;
    final today = _deadlines.where((d) => d.status == 'today').length;
    final totalAmount = _deadlines.fold(0.0, (s, d) => s + d.amount);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('متأخر', '$overdue', core_theme.AC.err, Icons.error),
            _kpi('عاجل', '$urgent', core_theme.AC.warn, Icons.warning),
            _kpi('اليوم', '$today', core_theme.AC.info, Icons.today),
            _kpi('إجمالي المستحق', _fmtM(totalAmount), core_theme.AC.gold, Icons.payments),
          ],
        ),
        const SizedBox(height: 16),
        _buildFilters(),
        const SizedBox(height: 16),
        _buildTimeline(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رزنامة الالتزامات الضريبية',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('كل مواعيد الإقرارات والدفعات — مربوطة بـ ZATCA / GOSI / WPS / UAE FTA',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterChip('all', 'الكل', Icons.apps),
        _filterChip('overdue', 'متأخر', Icons.error, core_theme.AC.err),
        _filterChip('today', 'اليوم', Icons.today, core_theme.AC.info),
        _filterChip('urgent', 'عاجل (< 7 أيام)', Icons.warning, core_theme.AC.warn),
        _filterChip('VAT', 'VAT', Icons.percent, core_theme.AC.ok),
        _filterChip('WHT', 'WHT', Icons.money_off, core_theme.AC.purple),
        _filterChip('GOSI', 'GOSI / WPS', Icons.shield, core_theme.AC.info),
        _filterChip('ZAKAT', 'الزكاة', Icons.star, core_theme.AC.warn),
      ],
    );
  }

  Widget _filterChip(String id, String label, IconData icon, [Color? color]) {
    final selected = _filter == id;
    final c = color ?? core_theme.AC.gold;
    return InkWell(
      onTap: () => setState(() => _filter = id),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : c.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : c),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : c,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeline() {
    final sorted = _filtered.toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sorted.length; i++) _timelineRow(sorted[i], i == sorted.length - 1),
        ],
      ),
    );
  }

  Widget _timelineRow(_Deadline d, bool isLast) {
    final statusColor = _statusColor(d.status);
    final daysLeft = DateTime.parse(d.dueDate).difference(DateTime(2026, 4, 19)).inDays;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 90,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: isLast ? Colors.transparent : core_theme.AC.bdr),
                right: BorderSide(color: statusColor, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(d.dueDate.substring(5),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
                Text(d.dueDate.substring(0, 4),
                    style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    daysLeft < 0 ? 'متأخر ${-daysLeft}' : daysLeft == 0 ? 'اليوم' : 'بعد $daysLeft',
                    style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : core_theme.AC.bdr)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _typeColor(d.type).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(d.type,
                        style: TextStyle(fontSize: 11, color: _typeColor(d.type), fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Row(
                          children: [
                            Icon(_frequencyIcon(d.frequency), size: 11, color: core_theme.AC.ts),
                            const SizedBox(width: 4),
                            Text(_frequencyLabel(d.frequency),
                                style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                            const SizedBox(width: 10),
                            Icon(Icons.business, size: 11, color: core_theme.AC.ts),
                            const SizedBox(width: 4),
                            Text(d.authority, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                            const SizedBox(width: 10),
                            Icon(Icons.task_alt, size: 11, color: core_theme.AC.ts),
                            const SizedBox(width: 4),
                            Text(d.action, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (d.amount > 0) ...[
                    Text(_fmt(d.amount),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
                    Text(' ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  ],
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: Text('تنفيذ', style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: statusColor,
                      side: BorderSide(color: statusColor),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(60, 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'overdue':
        return core_theme.AC.err;
      case 'urgent':
        return core_theme.AC.warn;
      case 'today':
        return core_theme.AC.info;
      case 'upcoming':
        return core_theme.AC.warn;
      default:
        return core_theme.AC.td;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'VAT':
        return core_theme.AC.ok;
      case 'WHT':
        return core_theme.AC.purple;
      case 'GOSI':
      case 'WPS':
        return core_theme.AC.info;
      case 'ZATCA E-INV':
        return core_theme.AC.err;
      case 'CT':
        return core_theme.AC.info;
      case 'ZAKAT':
        return core_theme.AC.warn;
      case 'TP':
        return core_theme.AC.purple;
      case 'CBCR':
        return core_theme.AC.purple;
      case 'ESR':
        return core_theme.AC.info;
      default:
        return core_theme.AC.td;
    }
  }

  IconData _frequencyIcon(String f) {
    switch (f) {
      case 'daily':
        return Icons.today;
      case 'monthly':
        return Icons.calendar_view_month;
      case 'quarterly':
        return Icons.view_timeline;
      case 'yearly':
        return Icons.event;
      default:
        return Icons.schedule;
    }
  }

  String _frequencyLabel(String f) {
    switch (f) {
      case 'daily':
        return 'يومي';
      case 'monthly':
        return 'شهري';
      case 'quarterly':
        return 'ربعي';
      case 'yearly':
        return 'سنوي';
      default:
        return f;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _Deadline {
  final String type;
  final String title;
  final String dueDate;
  final String frequency;
  final String status;
  final String authority;
  final double amount;
  final String action;
  const _Deadline(this.type, this.title, this.dueDate, this.frequency, this.status, this.authority, this.amount, this.action);
}
