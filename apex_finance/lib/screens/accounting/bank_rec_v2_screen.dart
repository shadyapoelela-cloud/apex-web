/// APEX — Bank Reconciliation AI v2 (Xero JAX pattern)
/// /app/erp/treasury/recon — auto-match >95% + suggestions for the rest
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_loading_states.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class BankRecV2Screen extends StatefulWidget {
  const BankRecV2Screen({super.key});
  @override
  State<BankRecV2Screen> createState() => _BankRecV2ScreenState();
}

class _BankRecV2ScreenState extends State<BankRecV2Screen> {
  bool _autoMatchRunning = false;
  Map<String, dynamic>? _autoMatchResult;
  String? _error;

  Future<void> _runAutoMatch() async {
    setState(() {
      _autoMatchRunning = true;
      _error = null;
    });
    final res = await ApiService.aiBankRecAutoMatch();
    if (!mounted) return;
    setState(() {
      _autoMatchRunning = false;
      if (res.success && res.data is Map) {
        _autoMatchResult = res.data as Map<String, dynamic>;
      } else {
        _error = res.error ?? 'فشل التشغيل';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('التسوية البنكية AI', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _heroCard(),
          const SizedBox(height: 12),
          if (_error != null)
            ApexErrorBanner(message: _error!, onRetry: _runAutoMatch),
          if (_autoMatchResult != null) _resultCard(),
          const SizedBox(height: 12),
          _explanationCard(),
          const ApexOutputChips(items: [
            ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
            ApexChipLink('ميزان المراجعة', '/compliance/financial-statements', Icons.assessment),
            ApexChipLink('ربط البنوك', '/settings/bank-feeds', Icons.account_balance),
            ApexChipLink('سجل النشاط', '/compliance/activity-log-v2', Icons.history),
          ]),
        ]),
      ),
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: AC.gold.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.psychology, color: AC.gold, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text('AI Auto-Match',
                style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          'الذكاء يقارن كل معاملة بنكية بقيود اليومية ويطابق تلقائياً ما تتجاوز ثقته 95%. الباقي يدخل قائمة المراجعة.',
          style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.6),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _autoMatchRunning ? null : _runAutoMatch,
            icon: _autoMatchRunning
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(_autoMatchRunning ? 'جارٍ التشغيل…' : 'شغّل المطابقة الآن'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold, foregroundColor: AC.navy),
          ),
        ),
      ]),
    );
  }

  Widget _resultCard() {
    final r = _autoMatchResult!;
    final matched = r['matched_count'] ?? r['matched'] ?? 0;
    final total = r['total_count'] ?? r['total'] ?? 0;
    final pending = (total is int && matched is int) ? total - matched : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.ok.withValues(alpha: 0.10),
        border: Border.all(color: AC.ok.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.celebration, color: AC.ok),
          const SizedBox(width: 8),
          Text('اكتمل التشغيل',
              style: TextStyle(color: AC.ok, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _statBox('متطابقة تلقائياً', '$matched', AC.ok)),
          const SizedBox(width: 8),
          Expanded(child: _statBox('تحتاج مراجعة', '$pending', AC.warn)),
        ]),
      ]),
    );
  }

  Widget _statBox(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: AC.ts, fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
        ]),
      );

  Widget _explanationCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('كيف يعمل المطابق الذكي؟',
            style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _bullet('1', 'يستورد المعاملات البنكية من البنك (Lean / Tarabut)'),
        _bullet('2', 'يقارن كل معاملة بقيود اليومية باستخدام 12 سمة موزّنة'),
        _bullet('3', 'الثقة ≥95% → مطابقة تلقائية + Audit Trail'),
        _bullet('4', 'الثقة 30-95% → اقتراحات للمراجعة'),
        _bullet('5', 'الثقة <30% → معاملات تحتاج إنشاء قيد جديد'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.go('/compliance/bank-rec-ai'),
          icon: Icon(Icons.list, color: AC.gold, size: 16),
          label: Text('عرض القائمة الكاملة (legacy)', style: TextStyle(color: AC.gold)),
          style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
        ),
      ]),
    );
  }

  Widget _bullet(String num, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(
            radius: 9,
            backgroundColor: AC.gold.withValues(alpha: 0.20),
            child: Text(num,
                style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: AC.tp, fontSize: 12))),
        ]),
      );
}
