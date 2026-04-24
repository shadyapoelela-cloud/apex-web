/// APEX — Tax Timeline screen
/// ═══════════════════════════════════════════════════════════
/// Visualizes upcoming tax / compliance obligations (KSA VAT, Zakat,
/// UAE VAT + Corporate Tax, Egypt VAT, ZATCA CSID expiry) as a
/// chronologically-sorted feed of cards. Each card shows:
///   • Arabic title
///   • Days remaining (big, color-coded by severity)
///   • Jurisdiction badge
///   • Short Arabic action hint
///
/// Backed by GET /api/v1/ai/tax-timeline.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class TaxTimelineScreen extends StatefulWidget {
  const TaxTimelineScreen({super.key});

  @override
  State<TaxTimelineScreen> createState() => _TaxTimelineScreenState();
}

class _TaxTimelineScreenState extends State<TaxTimelineScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.aiTaxTimeline(
      country: 'sa',
      vatCadence: 'monthly',
      fiscalYearEnd: '${DateTime.now().year}-12-31',
    );
    if (!mounted) return;
    if (res.success && res.data != null) {
      final list = (res.data['data'] as List?) ?? [];
      setState(() {
        _rows = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } else {
      setState(() {
        _error = res.error ?? 'تعذّر تحميل التقويم الضريبي';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text(
            'التقويم الضريبي',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: AC.err, fontFamily: 'Tajawal')),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined, color: AC.ts, size: 56),
            const SizedBox(height: 8),
            Text(
              'لا توجد استحقاقات في الأفق القريب',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ObligationCard(row: _rows[i]),
    );
  }
}

class _ObligationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _ObligationCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final severity = (row['severity'] ?? 'info') as String;
    final title = (row['title'] ?? '') as String;
    final dueDate = (row['due_date'] ?? '') as String;
    final period = (row['period_label'] ?? '') as String;
    final hint = (row['action_hint'] ?? '') as String;
    final jurisdiction = (row['jurisdiction'] ?? '') as String;
    final daysUntil = (row['days_until'] ?? 0) as int;
    final kind = (row['kind'] ?? '') as String;
    final color = _severityColor(severity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          right: BorderSide(color: color, width: 4),
          top: BorderSide(color: color.withValues(alpha: 0.15)),
          bottom: BorderSide(color: color.withValues(alpha: 0.15)),
          left: BorderSide(color: color.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dayCounter(daysUntil, color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _badge(_kindLabel(kind), AC.gold),
                    const SizedBox(width: 6),
                    _badge(_jurisdictionLabel(jurisdiction), AC.ts),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: AC.tp,
                    fontFamily: 'Tajawal',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: AC.ts),
                    const SizedBox(width: 4),
                    Text(
                      'الاستحقاق: $dueDate — الفترة: $period',
                      style: TextStyle(
                        color: AC.ts,
                        fontFamily: 'Tajawal',
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    style: TextStyle(
                      color: AC.tp,
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayCounter(int days, Color color) {
    final label = days < 0
        ? 'متأخر'
        : (days == 0 ? 'اليوم' : '$days');
    final sub = days < 0
        ? 'عن ${-days} يوم'
        : (days <= 1 ? '' : 'يوم');
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontFamily: 'Tajawal',
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (sub.isNotEmpty)
            Text(
              sub,
              style: TextStyle(
                color: color,
                fontFamily: 'Tajawal',
                fontSize: 10.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontFamily: 'Tajawal',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  static Color _severityColor(String s) {
    switch (s) {
      case 'error':
        return const Color(0xFFEF4444);
      case 'warning':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  static String _kindLabel(String k) {
    switch (k) {
      case 'vat':
        return 'ضريبة القيمة المضافة';
      case 'zakat':
        return 'زكاة';
      case 'corporate_tax':
        return 'ضريبة الشركات';
      case 'zatca_csid':
        return 'شهادة ZATCA';
      default:
        return k;
    }
  }

  static String _jurisdictionLabel(String j) {
    switch (j) {
      case 'sa':
        return 'السعودية';
      case 'ae':
        return 'الإمارات';
      case 'eg':
        return 'مصر';
      case 'om':
        return 'عُمان';
      case 'bh':
        return 'البحرين';
      default:
        return j;
    }
  }
}
