/// APEX — Anomaly Detail (drill from feed)
/// /audit/anomaly/:id — full detail of an AI-detected anomaly
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

class AnomalyDetailScreen extends StatelessWidget {
  final String anomalyId;
  const AnomalyDetailScreen({super.key, required this.anomalyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('تفاصيل الملاحظة', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _severityCard(),
          const SizedBox(height: 12),
          _evidenceCard(),
          const SizedBox(height: 12),
          _aiAnalysisCard(),
          const SizedBox(height: 12),
          _actionsCard(context),
        ]),
      ),
    );
  }

  Widget _severityCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AC.err.withValues(alpha: 0.20), AC.navy3],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          border: Border.all(color: AC.err.withValues(alpha: 0.5), width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.warning_amber, color: AC.err, size: 28),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AC.err.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('شدة عالية',
                  style: TextStyle(color: AC.err, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            const Spacer(),
            Text('Confidence: 94%',
                style: TextStyle(color: AC.gold, fontSize: 11.5, fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 10),
          Text('فاتورة مكررة محتملة',
              style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('فاتورة من نفس المورد بنفس المبلغ خلال 48 ساعة — مؤشر قوي على التكرار',
              style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.6)),
        ]),
      );

  Widget _evidenceCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الدليل',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _evidenceRow('الفاتورة الأولى', 'BILL-2026-0142', '15,500 SAR', '2026-04-22 10:15'),
          _evidenceRow('الفاتورة الثانية', 'BILL-2026-0145', '15,500 SAR', '2026-04-23 14:30'),
          const Divider(),
          Row(children: [
            Icon(Icons.info_outline, color: AC.warn, size: 14),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'نفس المورد · نفس المبلغ · فرق 28 ساعة فقط',
              style: TextStyle(color: AC.warn, fontSize: 11.5, fontWeight: FontWeight.w700),
            )),
          ]),
        ]),
      );

  Widget _evidenceRow(String label, String ref, String amount, String date) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AC.gold.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(label, style: TextStyle(color: AC.gold, fontSize: 9.5, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ref, style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 12)),
              Text(date, style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 10.5)),
            ]),
          ),
          Text(amount,
              style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _aiAnalysisCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AC.gold.withValues(alpha: 0.18), AC.navy3],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.psychology, color: AC.gold),
            const SizedBox(width: 8),
            Text('تحليل الذكاء الاصطناعي',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text(
            'الفاتورتان تشتركان في 7 خصائص (نفس المورد، نفس المبلغ بالعشرة ريال، نفس بنود الخدمة، نفس مركز التكلفة). '
            'احتمال أن تكون الثانية إعادة إدخال بالخطأ يبلغ 94%. '
            'يُنصح بإلغاء الثانية بإشعار دائن أو طلب تأكيد من المورد.',
            style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.7),
          ),
        ]),
      );

  Widget _actionsCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('الإجراءات المقترحة',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => context.go('/sales/memos'),
            icon: const Icon(Icons.note, size: 16),
            label: const Text('إنشاء إشعار دائن لإلغاء الثانية'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {},
            icon: Icon(Icons.email, color: AC.gold, size: 16),
            label: Text('راسل المورد للتأكيد', style: TextStyle(color: AC.gold)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {},
            icon: Icon(Icons.close, color: AC.ts, size: 16),
            label: Text('استبعاد كملاحظة خاطئة', style: TextStyle(color: AC.ts)),
          ),
        ]),
      );
}
