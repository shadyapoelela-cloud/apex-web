/// APEX — Sales Quotes / Proposals
/// /sales/quotes — pre-invoice proposals with conversion tracking
library;

import 'package:flutter/material.dart';

import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/apex_whatsapp_share.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class QuotesListScreen extends StatefulWidget {
  const QuotesListScreen({super.key});
  @override
  State<QuotesListScreen> createState() => _QuotesListScreenState();
}

class _QuotesListScreenState extends State<QuotesListScreen> {
  String _filter = 'all';

  final List<Map<String, dynamic>> _quotes = [
    {'id': 'QT-2026-0042', 'customer': 'شركة الرياض', 'amount': 45000.0, 'date': '2026-04-18', 'expires': '2026-05-18', 'status': 'sent', 'probability': 60},
    {'id': 'QT-2026-0041', 'customer': 'شركة الدمام', 'amount': 22500.0, 'date': '2026-04-15', 'expires': '2026-05-15', 'status': 'accepted', 'probability': 100},
    {'id': 'QT-2026-0040', 'customer': 'شركة جدة', 'amount': 18000.0, 'date': '2026-04-10', 'expires': '2026-05-10', 'status': 'sent', 'probability': 75},
    {'id': 'QT-2026-0039', 'customer': 'شركة المدينة', 'amount': 95000.0, 'date': '2026-04-05', 'expires': '2026-05-05', 'status': 'declined', 'probability': 0},
    {'id': 'QT-2026-0038', 'customer': 'شركة مكة', 'amount': 12500.0, 'date': '2026-03-28', 'expires': '2026-04-28', 'status': 'expired', 'probability': 0},
    {'id': 'QT-2026-0037', 'customer': 'شركة الطائف', 'amount': 60000.0, 'date': '2026-03-25', 'expires': '2026-04-25', 'status': 'draft', 'probability': 30},
  ];

  String _statusAr(String s) => switch (s) {
        'draft' => 'مسودة',
        'sent' => 'مرسلة',
        'accepted' => 'مقبولة',
        'declined' => 'مرفوضة',
        'expired' => 'منتهية',
        _ => s,
      };

  Color _statusColor(String s) => switch (s) {
        'accepted' => AC.ok,
        'sent' => AC.gold,
        'draft' => AC.warn,
        'declined' => AC.err,
        'expired' => AC.ts,
        _ => AC.ts,
      };

  IconData _statusIcon(String s) => switch (s) {
        'accepted' => Icons.check_circle,
        'sent' => Icons.send,
        'draft' => Icons.edit_note,
        'declined' => Icons.cancel,
        'expired' => Icons.schedule,
        _ => Icons.help,
      };

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _quotes;
    return _quotes.where((q) => q['status'] == _filter).toList();
  }

  double get _pipelineValue => _quotes
      .where((q) => q['status'] == 'sent' || q['status'] == 'draft')
      .fold<double>(0, (a, q) => a + (q['amount'] as double) * ((q['probability'] as int) / 100));
  double get _wonValue => _quotes
      .where((q) => q['status'] == 'accepted')
      .fold<double>(0, (a, q) => a + (q['amount'] as double));

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'عروض الأسعار',
      subtitle: 'Pipeline ${_pipelineValue.toStringAsFixed(0)} · Won ${_wonValue.toStringAsFixed(0)} SAR',
      primaryCta: ApexCta(
        label: 'عرض جديد',
        icon: Icons.add,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('شاشة إنشاء عرض — قادمة')),
          );
        },
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل', selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _quotes.length),
        for (final s in [
          ('draft', 'مسودة'),
          ('sent', 'مرسلة'),
          ('accepted', 'مقبولة'),
          ('declined', 'مرفوضة'),
          ('expired', 'منتهية'),
        ])
          ApexFilterChip(
            label: s.$2,
            selected: _filter == s.$1,
            onTap: () => setState(() => _filter = s.$1),
            icon: _statusIcon(s.$1),
            count: _quotes.where((q) => q['status'] == s.$1).length,
          ),
      ],
      items: _filtered,
      onRefresh: () async {},
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('الفواتير', '/sales/invoices', Icons.receipt),
        ApexChipLink('العملاء', '/sales/customers', Icons.people),
        ApexChipLink('أعمار AR', '/sales/aging', Icons.timeline),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.description,
        title: 'لا توجد عروض أسعار',
        description: 'ابدأ بإرسال عرض سعر لعميلك',
        primaryLabel: 'عرض جديد',
        primaryIcon: Icons.add,
        onPrimary: () {},
      ),
      itemBuilder: (ctx, q) {
        final color = _statusColor(q['status'] as String);
        final probability = q['probability'] as int;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color.withValues(alpha: 0.20),
              child: Icon(_statusIcon(q['status'] as String), color: color, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${q['id']} — ${q['customer']}',
                    style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w700)),
                Row(children: [
                  Text(_statusAr(q['status'] as String),
                      style: TextStyle(color: color, fontSize: 11)),
                  Text(' · ${q['date']} → ${q['expires']}',
                      style: TextStyle(color: AC.ts, fontSize: 10.5, fontFamily: 'monospace')),
                ]),
                if (probability > 0 && (q['status'] == 'sent' || q['status'] == 'draft'))
                  Row(children: [
                    Text('احتمال الفوز: $probability%',
                        style: TextStyle(color: AC.gold, fontSize: 10.5)),
                  ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(q['amount'] as double).toStringAsFixed(0)} SAR',
                  style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
            if (q['status'] == 'sent')
              ApexWhatsAppShareButton(
                compact: true,
                tooltip: 'إعادة إرسال على واتساب',
                message: 'عرض أسعار ${q['id']} بقيمة ${q['amount']} ريال — ينتهي ${q['expires']}',
              ),
          ]),
        );
      },
    );
  }
}
