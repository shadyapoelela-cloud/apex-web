/// APEX — ZATCA Status Center (CSID + Queue + Errors in one)
/// /app/erp/finance/zatca-status — single source for ZATCA Phase 2 ops
library;

import 'package:flutter/material.dart';
import '../../core/apex_csid_warning.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class ZatcaStatusCenterScreen extends StatelessWidget {
  const ZatcaStatusCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final daysToExpiry = 25; // demo
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('مركز ZATCA Phase 2', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ApexCsidWarningBanner(
            daysUntilExpiry: daysToExpiry,
            onRenew: () {},
          ),
          _statusGrid(),
          const SizedBox(height: 12),
          _queueCard(),
          const SizedBox(height: 12),
          _recentErrorsCard(),
          const ApexOutputChips(items: [
            ApexChipLink('VAT Return', '/app/compliance/tax/vat-return', Icons.receipt_long),
            ApexChipLink('الفواتير', '/app/erp/sales/invoices', Icons.receipt),
            ApexChipLink('التقويم الضريبي', '/app/compliance/tax/calendar', Icons.event),
            ApexChipLink('سجل النشاط', '/compliance/activity-log-v2', Icons.history),
          ]),
        ]),
      ),
    );
  }

  Widget _statusGrid() {
    final cards = [
      _StatusCard(
        title: 'CSID',
        value: 'صالح',
        subtitle: '25 يوم متبقي',
        icon: Icons.verified_user,
        color: AC.warn,
      ),
      _StatusCard(
        title: 'B2B Cleared',
        value: '142',
        subtitle: 'هذا الشهر',
        icon: Icons.send,
        color: AC.ok,
      ),
      _StatusCard(
        title: 'B2C Reported',
        value: '1,287',
        subtitle: 'هذا الشهر',
        icon: Icons.receipt,
        color: AC.gold,
      ),
      _StatusCard(
        title: 'Pending',
        value: '3',
        subtitle: 'في طابور الإرسال',
        icon: Icons.pending,
        color: AC.info,
      ),
      _StatusCard(
        title: 'Errors',
        value: '2',
        subtitle: 'تحتاج إصلاح',
        icon: Icons.error,
        color: AC.err,
      ),
      _StatusCard(
        title: 'Compliance',
        value: '98%',
        subtitle: 'نسبة الامتثال',
        icon: Icons.trending_up,
        color: AC.ok,
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: cards.map((c) => _statusCardWidget(c)).toList(),
    );
  }

  Widget _statusCardWidget(_StatusCard c) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: c.color.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(c.icon, color: c.color, size: 16),
          const SizedBox(height: 6),
          Text(c.title, style: TextStyle(color: AC.ts, fontSize: 10.5)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(c.value,
                style: TextStyle(
                    color: c.color,
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900)),
          ),
          Text(c.subtitle, style: TextStyle(color: AC.ts, fontSize: 9.5)),
        ]),
      );

  Widget _queueCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.queue, color: AC.info, size: 18),
            const SizedBox(width: 8),
            Text('طابور الإرسال (3)',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          _queueRow('INV-2026-0145', 'في الطريق إلى ZATCA', 'جارٍ', AC.info),
          _queueRow('INV-2026-0146', 'انتظار توقيع رقمي', 'جارٍ', AC.info),
          _queueRow('INV-2026-0147', 'إعادة محاولة (محاولة 2/3)', 'متأخر', AC.warn),
        ]),
      );

  Widget _queueRow(String num, String desc, String status, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(Icons.fiber_manual_record, color: color, size: 8),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(num,
                style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11)),
          ),
          Expanded(child: Text(desc, style: TextStyle(color: AC.tp, fontSize: 11))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _recentErrorsCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.err.withValues(alpha: 0.06),
          border: Border.all(color: AC.err.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.error_outline, color: AC.err, size: 18),
            const SizedBox(width: 8),
            Text('آخر الأخطاء (2)',
                style: TextStyle(color: AC.err, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          _errorRow(
            'INV-2026-0098',
            'BR-KSA-EN16931-04',
            'BuyerVAT format invalid (must be 15 digits)',
          ),
          _errorRow(
            'INV-2026-0102',
            'BR-CL-29',
            'Invalid invoice type code (300/388/383 only)',
          ),
        ]),
      );

  Widget _errorRow(String num, String code, String message) => Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(num,
                style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11.5)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AC.err.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(code,
                  style: TextStyle(color: AC.err, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {},
              child: Text('أصلح', style: TextStyle(color: AC.err)),
            ),
          ]),
          Text(message,
              style: TextStyle(color: AC.tp, fontSize: 11.5, fontFamily: 'monospace')),
        ]),
      );
}

class _StatusCard {
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
  _StatusCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
