/// UAE Corporate Tax Calculator — interactive client-side implementation.
///
/// Mirrors app/integrations/uae_fta/corporate_tax.py exactly so you can
/// preview the result without a backend call. When the REST endpoint is
/// wired in, switch to ApiService.
library;

import 'package:flutter/material.dart';

import '../../core/apex_form_field.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/validators_ui.dart';

class UaeCorpTaxScreen extends StatefulWidget {
  const UaeCorpTaxScreen({super.key});

  @override
  State<UaeCorpTaxScreen> createState() => _UaeCorpTaxScreenState();
}

class _UaeCorpTaxScreenState extends State<UaeCorpTaxScreen> {
  final _revenueCtrl = TextEditingController(text: '5000000');
  final _priorRevenueCtrl = TextEditingController(text: '4500000');
  final _taxableCtrl = TextEditingController(text: '800000');
  final _lossCtrl = TextEditingController(text: '100000');
  final _qfzpQCtrl = TextEditingController(text: '0');
  final _qfzpNqCtrl = TextEditingController(text: '0');
  bool _elect_sbr = false;
  bool _isQfzp = false;

  @override
  void dispose() {
    _revenueCtrl.dispose();
    _priorRevenueCtrl.dispose();
    _taxableCtrl.dispose();
    _lossCtrl.dispose();
    _qfzpQCtrl.dispose();
    _qfzpNqCtrl.dispose();
    super.dispose();
  }

  double _d(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '')) ?? 0;

  _CtResult _compute() {
    final revenue = _d(_revenueCtrl);
    final priorRevenue = _d(_priorRevenueCtrl);
    final taxable = _d(_taxableCtrl);
    final lossBf = _d(_lossCtrl);
    final qfzpQ = _d(_qfzpQCtrl);
    final qfzpNq = _d(_qfzpNqCtrl);

    const exempt = 375000.0;
    const rate = 0.09;
    const sbrMaxRev = 3000000.0;
    const lossCapRatio = 0.75;

    // Small Business Relief
    if (_elect_sbr && revenue <= sbrMaxRev && priorRevenue <= sbrMaxRev) {
      return _CtResult(
        ruleApplied: 'sbr',
        taxableAfterLosses: taxable,
        lossesUtilized: 0,
        lossesCarryForward: lossBf,
        exemptSlabUsed: taxable.clamp(0, exempt).toDouble(),
        taxableAboveExempt: 0,
        ctDue: 0,
        effectiveRate: 0,
        note:
            'Small Business Relief applied — 0% حتى 31 ديسمبر 2026.',
      );
    }

    // QFZP
    if (_isQfzp) {
      final nq = qfzpNq.clamp(0, double.infinity).toDouble();
      final ct = nq * rate;
      final total = qfzpQ + nq;
      return _CtResult(
        ruleApplied: 'qfzp',
        taxableAfterLosses: total,
        lossesUtilized: 0,
        lossesCarryForward: lossBf,
        exemptSlabUsed: 0,
        taxableAboveExempt: nq,
        ctDue: ct,
        effectiveRate: total > 0 ? (ct / total * 100) : 0,
        note:
            'QFZP — 0% على الدخل المؤهل، 9% على الدخل غير المؤهل دون إعفاء.',
      );
    }

    // Standard
    final lossCap = taxable * lossCapRatio;
    final used = lossBf > lossCap ? lossCap : lossBf;
    final taxableAfter = taxable - used;
    final exemptUsed = taxableAfter.clamp(0, exempt).toDouble();
    final above = (taxableAfter - exempt).clamp(0, double.infinity).toDouble();
    final ct = above * rate;
    return _CtResult(
      ruleApplied: 'standard',
      taxableAfterLosses: taxableAfter,
      lossesUtilized: used,
      lossesCarryForward: lossBf - used,
      exemptSlabUsed: exemptUsed,
      taxableAboveExempt: above,
      ctDue: ct,
      effectiveRate: taxableAfter > 0 ? (ct / taxableAfter * 100) : 0,
      note: used < lossBf ? 'تم تحديد الخصم بسقف 75% من الدخل الخاضع.' : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _compute();
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(
            title: 'حاسبة ضريبة الشركات الإماراتية (FTA)',
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                if (constraints.maxWidth > 900) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _inputs()),
                      Expanded(flex: 2, child: _result(result)),
                    ],
                  );
                }
                return SingleChildScrollView(
                  child: Column(
                    children: [
                      _inputs(),
                      _result(result),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputs() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldSection('البيانات الأساسية (بالدرهم الإماراتي)', [
            ApexFormField(
              label: 'الإيرادات السنوية',
              controller: _revenueCtrl,
              validator: validateSarAmount,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
            ),
            ApexFormField(
              label: 'إيرادات الفترة السابقة (للتحقق من SBR)',
              controller: _priorRevenueCtrl,
              validator: validateSarAmount,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
            ),
            ApexFormField(
              label: 'الدخل الخاضع للضريبة (بعد الخصومات)',
              controller: _taxableCtrl,
              validator: validateSarAmount,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
            ),
            ApexFormField(
              label: 'خسائر مُرحَّلة من فترات سابقة',
              controller: _lossCtrl,
              validator: validateSarAmount,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
            ),
          ]),
          SwitchListTile(
            activeColor: AC.gold,
            title: Text('تفعيل Small Business Relief (اختياري حتى ٢٠٢٦)',
                style: TextStyle(color: AC.tp)),
            subtitle: Text(
              'متاح إذا كانت الإيرادات الحالية والسابقة ≤ 3M درهم.',
              style: TextStyle(color: AC.td, fontSize: AppFontSize.sm),
            ),
            value: _elect_sbr,
            onChanged: (v) => setState(() => _elect_sbr = v),
          ),
          SwitchListTile(
            activeColor: AC.gold,
            title: Text('Qualifying Free Zone Person',
                style: TextStyle(color: AC.tp)),
            subtitle: Text(
              '0% على الدخل المؤهل، 9% على غير المؤهل بدون إعفاء 375K.',
              style: TextStyle(color: AC.td, fontSize: AppFontSize.sm),
            ),
            value: _isQfzp,
            onChanged: (v) => setState(() => _isQfzp = v),
          ),
          if (_isQfzp) ...[
            const SizedBox(height: AppSpacing.md),
            ApexFormField(
              label: 'دخل مؤهل (Qualifying Income)',
              controller: _qfzpQCtrl,
              validator: validateSarAmount,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.md),
            ApexFormField(
              label: 'دخل غير مؤهل',
              controller: _qfzpNqCtrl,
              validator: validateSarAmount,
              onChanged: (_) => setState(() {}),
              keyboardType: TextInputType.number,
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: AC.gold,
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: AppSpacing.md),
        ...children.expand((w) => [
              w,
              const SizedBox(height: AppSpacing.md),
            ]),
      ],
    );
  }

  Widget _result(_CtResult r) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.xl),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: AC.gold),
              const SizedBox(width: AppSpacing.sm),
              Text('نتيجة الحساب',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: AppFontSize.xl,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: AC.cyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(r.ruleApplied,
                    style:
                        TextStyle(color: AC.cyan, fontSize: AppFontSize.sm)),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl * 1.5),
          _kv('الدخل بعد الخسائر', r.taxableAfterLosses),
          _kv('خسائر مستخدمة', r.lossesUtilized),
          _kv('خسائر مُرحَّلة للفترة القادمة', r.lossesCarryForward),
          _kv('شريحة الإعفاء المستخدمة (حتى 375K)', r.exemptSlabUsed),
          _kv('المبلغ فوق الإعفاء (خاضع لـ 9%)', r.taxableAboveExempt),
          const Divider(height: AppSpacing.xl * 1.5),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AC.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ضريبة الشركات المستحقة',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w700)),
                Text(
                  '${formatSarAmount(r.ctDue)} د.إ',
                  style: TextStyle(
                    color: AC.gold,
                    fontSize: AppFontSize.h2,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('المعدل الفعلي: ${r.effectiveRate.toStringAsFixed(2)}%',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.md)),
          if (r.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AC.cyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AC.cyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AC.cyan, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(r.note,
                        style: TextStyle(
                            color: AC.ts, fontSize: AppFontSize.md)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kv(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AC.ts)),
          Text(
            formatSarAmount(value),
            style: TextStyle(
              color: AC.tp,
              fontFamily: 'monospace',
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CtResult {
  final String ruleApplied;
  final double taxableAfterLosses;
  final double lossesUtilized;
  final double lossesCarryForward;
  final double exemptSlabUsed;
  final double taxableAboveExempt;
  final double ctDue;
  final double effectiveRate;
  final String note;

  _CtResult({
    required this.ruleApplied,
    required this.taxableAfterLosses,
    required this.lossesUtilized,
    required this.lossesCarryForward,
    required this.exemptSlabUsed,
    required this.taxableAboveExempt,
    required this.ctDue,
    required this.effectiveRate,
    required this.note,
  });
}
