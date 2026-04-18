/// APEX Wave 43 — Zakat Calculator (ZATCA-compliant).
/// Route: /app/compliance/tax/zakat
///
/// Computes Zakat using the wealth (capital) method per ZATCA
/// regulations: Zakat base = Equity + Long-term liabilities − Fixed
/// assets − Long-term investments. Rate: 2.5% for Hijri year.
library;

import 'package:flutter/material.dart';

class ZakatCalculatorV5Screen extends StatefulWidget {
  const ZakatCalculatorV5Screen({super.key});
  @override
  State<ZakatCalculatorV5Screen> createState() => _ZakatCalculatorV5ScreenState();
}

class _ZakatCalculatorV5ScreenState extends State<ZakatCalculatorV5Screen> {
  // Prefilled with realistic mid-size KSA firm numbers
  final _equity = TextEditingController(text: '1287300');
  final _longTermLiab = TextEditingController(text: '750000');
  final _retainedEarnings = TextEditingController(text: '287300');
  final _fixedAssets = TextEditingController(text: '1250000');
  final _longTermInvest = TextEditingController(text: '180000');
  final _adjustmentsAdd = TextEditingController(text: '0');
  final _adjustmentsSub = TextEditingController(text: '45000');

  String _period = '1447H';

  double get _equityV => double.tryParse(_equity.text) ?? 0;
  double get _longTermLiabV => double.tryParse(_longTermLiab.text) ?? 0;
  double get _fixedAssetsV => double.tryParse(_fixedAssets.text) ?? 0;
  double get _longTermInvestV => double.tryParse(_longTermInvest.text) ?? 0;
  double get _adjustmentsAddV => double.tryParse(_adjustmentsAdd.text) ?? 0;
  double get _adjustmentsSubV => double.tryParse(_adjustmentsSub.text) ?? 0;

  double get _zakatBase =>
      (_equityV + _longTermLiabV + _adjustmentsAddV) -
      (_fixedAssetsV + _longTermInvestV + _adjustmentsSubV);

  double get _zakatDue => (_zakatBase * 0.025).clamp(0, double.infinity);

  @override
  void dispose() {
    _equity.dispose();
    _longTermLiab.dispose();
    _retainedEarnings.dispose();
    _fixedAssets.dispose();
    _longTermInvest.dispose();
    _adjustmentsAdd.dispose();
    _adjustmentsSub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Inputs
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  _buildInputSection(),
                  const SizedBox(height: 16),
                  _buildAdjustments(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Result sidebar
            Expanded(flex: 2, child: _buildResultCard()),
          ],
        ),
        const SizedBox(height: 20),
        _buildRulesCard(),
        const SizedBox(height: 20),
        _buildFilingSection(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0A5F38), Color(0xFF10B981)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('حاسبة الزكاة',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('طريقة رأس المال العامل — وفقاً لأنظمة هيئة الزكاة والضريبة والجمارك (ZATCA)',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _period,
              dropdownColor: const Color(0xFF0A5F38),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              iconEnabledColor: Colors.white,
              items: const [
                DropdownMenuItem(value: '1447H', child: Text('1447 هـ')),
                DropdownMenuItem(value: '1446H', child: Text('1446 هـ')),
                DropdownMenuItem(value: '1445H', child: Text('1445 هـ')),
              ],
              onChanged: (v) => setState(() => _period = v ?? _period),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_circle, color: Colors.green, size: 18),
              SizedBox(width: 6),
              Text('يُضاف إلى وعاء الزكاة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _inputRow('حقوق الملكية', _equity, 'رأس المال + الاحتياطيات + الأرباح المحتجزة'),
          _inputRow('الالتزامات طويلة الأجل', _longTermLiab, 'قروض بنكية، صكوك، مكافآت نهاية الخدمة'),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.remove_circle, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text('يُخصم من وعاء الزكاة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _inputRow('الأصول الثابتة (صافي)', _fixedAssets, 'بعد خصم الإهلاك المتراكم'),
          _inputRow('الاستثمارات طويلة الأجل', _longTermInvest, 'استثمارات في شركات زميلة وتابعة'),
        ],
      ),
    );
  }

  Widget _inputRow(String label, TextEditingController ctl, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(hint, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: TextField(
              controller: ctl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'monospace'),
              decoration: InputDecoration(
                suffixText: ' ر.س',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustments() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Colors.amber, size: 18),
              SizedBox(width: 6),
              Text('تعديلات إضافية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          _inputRow('إضافات', _adjustmentsAdd, 'مثلاً: مخصصات غير جائزة'),
          _inputRow('استقطاعات', _adjustmentsSub, 'مثلاً: مشاريع تحت التنفيذ غير نشطة'),
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
              colors: [Color(0xFF0A5F38), Color(0xFF064E2F)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('وعاء الزكاة',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_fmt(_zakatBase),
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              const Divider(color: Colors.white24, height: 32),
              const Text('الزكاة المستحقة (2.5%)',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_fmt(_zakatDue),
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              const SizedBox(height: 4),
              const Text('ر.س',
                  style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              _summaryLine('حقوق الملكية', _equityV, '+', Colors.green),
              _summaryLine('التزامات طويلة الأجل', _longTermLiabV, '+', Colors.green),
              _summaryLine('تعديلات إضافة', _adjustmentsAddV, '+', Colors.green),
              _summaryLine('أصول ثابتة', _fixedAssetsV, '-', Colors.red),
              _summaryLine('استثمارات طويلة', _longTermInvestV, '-', Colors.red),
              _summaryLine('تعديلات خصم', _adjustmentsSubV, '-', Colors.red),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الوعاء النهائي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                  Text(_fmt(_zakatBase), style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Color(0xFF0A5F38))),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryLine(String label, double val, String sign, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(sign, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
          Text(_fmt(val), style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gavel, color: Colors.blue),
              SizedBox(width: 8),
              Text('المرجع النظامي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          const Text('• اللائحة التنفيذية لجباية الزكاة رقم 2082 بتاريخ 01/06/1438 هـ',
              style: TextStyle(fontSize: 12, height: 1.7)),
          const Text('• طريقة رأس المال العامل لأصحاب النشاط الخاضع لنظام الشركات',
              style: TextStyle(fontSize: 12, height: 1.7)),
          const Text('• السعر القانوني: 2.5% من الوعاء الزكوي للسنة الهجرية الكاملة',
              style: TextStyle(fontSize: 12, height: 1.7)),
          const Text('• الاستحقاق: بعد حولان الحول الهجري على المال',
              style: TextStyle(fontSize: 12, height: 1.7)),
        ],
      ),
    );
  }

  Widget _buildFilingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الخطوات التالية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('تصدير بيان الزكاة'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.attach_file, size: 16),
                  label: const Text('إرفاق القوائم'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('يتم إعداد الإقرار الزكوي لتقديمه إلى ZATCA — المبلغ: ${_fmt(_zakatDue)} ر.س'),
                        backgroundColor: const Color(0xFF0A5F38),
                      ),
                    );
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('تقديم إلى ZATCA'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A5F38),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
