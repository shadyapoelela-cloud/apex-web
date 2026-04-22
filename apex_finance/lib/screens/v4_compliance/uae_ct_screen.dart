/// APEX Wave 50 — UAE Corporate Tax (CT).
/// Route: /app/compliance/tax/uae_ct
///
/// UAE CT @ 9% on taxable profits above AED 375,000,
/// 0% below, plus Free Zone qualifying-income logic.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class UaeCtScreen extends StatefulWidget {
  const UaeCtScreen({super.key});
  @override
  State<UaeCtScreen> createState() => _UaeCtScreenState();
}

class _UaeCtScreenState extends State<UaeCtScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _entityType = 'mainland';
  final _revenue = TextEditingController(text: '12500000');
  final _expenses = TextEditingController(text: '9800000');
  final _nonDeductible = TextEditingController(text: '125000');
  final _exemptIncome = TextEditingController(text: '0');
  final _lossesBf = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _revenue.dispose();
    _expenses.dispose();
    _nonDeductible.dispose();
    _exemptIncome.dispose();
    _lossesBf.dispose();
    super.dispose();
  }

  double _parse(TextEditingController c) => double.tryParse(c.text) ?? 0;
  double get _accountingProfit => _parse(_revenue) - _parse(_expenses);
  double get _taxableIncome {
    var t = _accountingProfit + _parse(_nonDeductible) - _parse(_exemptIncome);
    // 75% cap on loss offset
    final maxLossOffset = t * 0.75;
    final lossApplied = _parse(_lossesBf).clamp(0.0, maxLossOffset);
    t -= lossApplied;
    return t.clamp(0.0, double.infinity);
  }

  double get _ctDue {
    if (_entityType == 'freezone_qualifying') return 0;
    if (_entityType == 'small_business' && _parse(_revenue) <= 3_000_000) return 0;
    const threshold = 375_000.0;
    if (_taxableIncome <= threshold) return 0;
    return (_taxableIncome - threshold) * 0.09;
  }

  double get _effectiveRate => _taxableIncome > 0 ? (_ctDue / _taxableIncome * 100) : 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.calculate, size: 16), text: 'حاسبة CT'),
            Tab(icon: Icon(Icons.article, size: 16), text: 'الإقرار'),
            Tab(icon: Icon(Icons.gavel, size: 16), text: 'الأحكام والقواعد'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildCalculatorTab(),
              _buildReturnTab(),
              _buildRulesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF006C35), Color(0xFF00925F)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ضريبة الشركات الإماراتية 🇦🇪',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('UAE Corporate Tax — 9% على الأرباح الخاضعة فوق 375,000 درهم · 0% للشركات الصغيرة',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('السنة المالية', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
              Text('2025', style: TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatorTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 20, right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card(
                  'نوع المنشأة',
                  Column(
                    children: [
                      _radioTile('mainland', 'منشأة رئيسية (Mainland)', '9% فوق 375,000 درهم'),
                      _radioTile('freezone_qualifying', 'منطقة حرة — دخل مؤهّل', '0% على الدخل المؤهّل'),
                      _radioTile('freezone_nonqualifying', 'منطقة حرة — دخل غير مؤهّل', '9% كامل'),
                      _radioTile('small_business', 'إعفاء الأعمال الصغيرة', 'إيرادات ≤ 3 مليون = 0%'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  'الحساب من القوائم المالية',
                  Column(
                    children: [
                      _input('إجمالي الإيرادات', _revenue),
                      _input('إجمالي المصروفات (المخصومة)', _expenses),
                      _input('مصروفات غير مخصومة (+)', _nonDeductible),
                      _input('دخل معفى (-)', _exemptIncome),
                      _input('خسائر مرحّلة من سنوات سابقة', _lossesBf),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, bottom: 20, left: 10),
            child: _buildResultCard(),
          ),
        ),
      ],
    );
  }

  Widget _radioTile(String id, String title, String subtitle) {
    final selected = _entityType == id;
    return InkWell(
      onTap: () => setState(() => _entityType = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? core_theme.AC.gold.withOpacity(0.1) : core_theme.AC.navy3,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? core_theme.AC.gold : core_theme.AC.bdr,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: id,
              groupValue: _entityType,
              onChanged: (v) => setState(() => _entityType = v ?? _entityType),
              activeColor: core_theme.AC.gold,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                  Text(subtitle, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(String label, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 4),
          TextField(
            controller: c,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
            decoration: InputDecoration(
              suffixText: ' د.إ',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  Widget _card(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF006C35), Color(0xFF004D26)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('ضريبة الشركات المستحقة',
                  style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_fmt(_ctDue),
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              Text('د.إ · معدل فعلي ${_effectiveRate.toStringAsFixed(2)}%',
                  style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            children: [
              _line('الربح المحاسبي', _accountingProfit, core_theme.AC.tp),
              _line('+ مصروفات غير مخصومة', _parse(_nonDeductible), core_theme.AC.err),
              _line('- دخل معفى', _parse(_exemptIncome), core_theme.AC.ok),
              _line('- خسائر مستخدمة', _parse(_lossesBf).clamp(0.0, double.infinity), core_theme.AC.info),
              const Divider(),
              _line('الدخل الخاضع للضريبة', _taxableIncome, core_theme.AC.gold, bold: true),
              _line('الشريحة المعفاة (0%)', 375000, core_theme.AC.ok),
              _line('الشريحة الخاضعة (9%)', (_taxableIncome - 375000).clamp(0.0, double.infinity), core_theme.AC.warn),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_ctDue == 0 && _taxableIncome > 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: core_theme.AC.ok,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: core_theme.AC.ok),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: core_theme.AC.ok),
                SizedBox(width: 8),
                Expanded(child: Text('معفى من الضريبة بناءً على نوع المنشأة المختار', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إعداد إقرار CT — مستحق: ${_fmt(_ctDue)} د.إ'),
                  backgroundColor: const Color(0xFF006C35),
                ),
              );
            },
            icon: const Icon(Icons.description),
            label: Text('توليد الإقرار السنوي'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006C35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(String label, double value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(_fmt(value),
              style: TextStyle(
                fontSize: bold ? 15 : 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: color,
              )),
        ],
      ),
    );
  }

  Widget _buildReturnTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.article, color: Color(0xFF006C35)),
                  SizedBox(width: 8),
                  Text('الإقرار السنوي للضريبة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 12),
              _kv('رقم الإقرار', 'CT-2025-AE-4582'),
              _kv('فترة الإقرار', '01/01/2025 — 31/12/2025'),
              _kv('الرقم الضريبي', '100123456700003'),
              _kv('تاريخ الاستحقاق', '30/09/2026 (9 أشهر من نهاية السنة)'),
              _kv('طريقة التقديم', 'EmaraTax portal (FTA)'),
              const Divider(height: 30),
              Text('بنود الإقرار الرئيسية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _returnLine('1', 'إجمالي الإيرادات', _parse(_revenue)),
              _returnLine('2', 'تعديلات ضريبية — إضافات', _parse(_nonDeductible)),
              _returnLine('3', 'تعديلات ضريبية — خصومات', _parse(_exemptIncome)),
              _returnLine('4', 'الدخل الخاضع قبل الخسائر', _accountingProfit + _parse(_nonDeductible) - _parse(_exemptIncome)),
              _returnLine('5', 'الخسائر المستخدمة (حد أقصى 75%)', -_parse(_lossesBf).clamp(0.0, double.infinity)),
              _returnLine('6', 'الدخل الخاضع بعد الخسائر', _taxableIncome),
              _returnLine('7', 'الشريحة الأولى (0%)', -375000),
              _returnLine('8', 'الدخل الخاضع للمعدل 9%', (_taxableIncome - 375000).clamp(0.0, double.infinity)),
              _returnLine('9', 'الضريبة المستحقة', _ctDue, highlight: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.upload_file),
            label: Text('إرسال إلى EmaraTax'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006C35),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _returnLine(String num, String label, double value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: highlight ? core_theme.AC.gold.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(width: 24, child: Text(num, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace'))),
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: highlight ? FontWeight.w900 : FontWeight.w500))),
          Text(_fmt(value),
              style: TextStyle(
                fontSize: highlight ? 14 : 12,
                fontWeight: FontWeight.w800,
                color: highlight ? core_theme.AC.gold : (value < 0 ? core_theme.AC.err : core_theme.AC.tp),
                fontFamily: 'monospace',
              )),
        ],
      ),
    );
  }

  Widget _buildRulesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ruleSection(
          'الأساسيات',
          Icons.flag,
          core_theme.AC.info,
          const [
            'ضريبة الشركات الاتحادية UAE CT — نافذة من 1 يونيو 2023',
            'القانون الاتحادي رقم 47 لسنة 2022 — الهيئة الاتحادية للضرائب FTA',
            'المعدل الأساسي: 9% على الدخل الخاضع فوق 375,000 درهم',
            'المعدل المخفّض: 0% للدخل حتى 375,000 درهم',
          ],
        ),
        const SizedBox(height: 12),
        _ruleSection(
          'المناطق الحرة',
          Icons.apartment,
          core_theme.AC.info,
          const [
            'الشركات في المناطق الحرة قد تكون Qualifying Free Zone Person (QFZP)',
            'الدخل المؤهّل (Qualifying Income): 0%',
            'الدخل غير المؤهّل: 9% كامل',
            'شروط QFZP: حضور اقتصادي كافٍ، معاملات مع أطراف ذات علاقة، امتثال أسعار التحويل',
          ],
        ),
        const SizedBox(height: 12),
        _ruleSection(
          'إعفاء الأعمال الصغيرة',
          Icons.store,
          core_theme.AC.ok,
          const [
            'Small Business Relief متاح للشركات ذات إيرادات ≤ 3 مليون درهم',
            'تطبيق حتى 31 ديسمبر 2026 (قرار مجلس الوزراء رقم 73/2023)',
            'يُعتبر فيه الدخل صفراً بغض النظر عن الأرباح الفعلية',
            'يجب التقديم للحصول على الإعفاء — ليس تلقائياً',
          ],
        ),
        const SizedBox(height: 12),
        _ruleSection(
          'الخسائر والأسعار بين الأطراف',
          Icons.warning,
          core_theme.AC.warn,
          const [
            'ترحيل خسائر لسنوات لاحقة — بدون حد زمني',
            'الحد الأقصى للخسارة المستخدمة في السنة: 75% من الدخل الخاضع',
            'مشاركة الخسائر بين المجموعة: بشروط (ملكية 75%+)',
            'أسعار التحويل (TP) إلزامية بين الشركات ذات العلاقة (Arm\'s Length Principle)',
          ],
        ),
      ],
    );
  }

  Widget _ruleSection(String title, IconData icon, Color color, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 14, color: color),
                  const SizedBox(width: 6),
                  Expanded(child: Text(i, style: const TextStyle(fontSize: 12, height: 1.6))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(k, style: TextStyle(fontSize: 12, color: core_theme.AC.ts))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.abs() >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
