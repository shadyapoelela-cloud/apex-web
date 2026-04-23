/// APEX Wave 65 — VAT Return Builder.
/// Route: /app/compliance/tax/vat-return
///
/// Monthly/quarterly VAT return per ZATCA format.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class VatReturnBuilderScreen extends StatefulWidget {
  const VatReturnBuilderScreen({super.key});
  @override
  State<VatReturnBuilderScreen> createState() => _VatReturnBuilderScreenState();
}

class _VatReturnBuilderScreenState extends State<VatReturnBuilderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _period = '2026-04';

  // ZATCA VAT Return fields
  final _salesStandard = TextEditingController(text: '1850000');
  final _salesZero = TextEditingController(text: '125000');
  final _salesExempt = TextEditingController(text: '45000');
  final _exports = TextEditingController(text: '180000');
  final _purchasesStandard = TextEditingController(text: '920000');
  final _purchasesImport = TextEditingController(text: '245000');
  final _adjustmentsOut = TextEditingController(text: '0');
  final _adjustmentsIn = TextEditingController(text: '8500');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _salesStandard.dispose();
    _salesZero.dispose();
    _salesExempt.dispose();
    _exports.dispose();
    _purchasesStandard.dispose();
    _purchasesImport.dispose();
    _adjustmentsOut.dispose();
    _adjustmentsIn.dispose();
    super.dispose();
  }

  double _val(TextEditingController c) => double.tryParse(c.text) ?? 0;
  double get _outputVat => _val(_salesStandard) * 0.15 + _val(_adjustmentsOut);
  double get _inputVat => _val(_purchasesStandard) * 0.15 + _val(_purchasesImport) * 0.15 + _val(_adjustmentsIn);
  double get _netVat => _outputVat - _inputVat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.ok,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.ok,
          tabs: const [
            Tab(icon: Icon(Icons.edit_note, size: 16), text: 'بيانات الإقرار'),
            Tab(icon: Icon(Icons.preview, size: 16), text: 'معاينة'),
            Tab(icon: Icon(Icons.cloud_upload, size: 16), text: 'التقديم'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildDataTab(),
              _buildPreviewTab(),
              _buildSubmitTab(),
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
        gradient: LinearGradient(colors: [core_theme.AC.ok, core_theme.AC.ok]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.percent, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إقرار ضريبة القيمة المضافة',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('VAT Return · ZATCA format · 15% · فوترة إلكترونية Phase 2',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _period,
              dropdownColor: core_theme.AC.ok,
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              iconEnabledColor: Colors.white,
              items: const [
                DropdownMenuItem(value: '2026-04', child: Text('أبريل 2026')),
                DropdownMenuItem(value: '2026-03', child: Text('مارس 2026')),
                DropdownMenuItem(value: '2026-Q1', child: Text('الربع الأول 2026')),
              ],
              onChanged: (v) => setState(() => _period = v ?? _period),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _section(
                'المبيعات ومخرجات الضريبة',
                Icons.trending_up,
                core_theme.AC.ok,
                [
                  _input('1', 'مبيعات محلية خاضعة للمعدل القياسي 15%', _salesStandard, 'total'),
                  _input('2', 'مبيعات خاضعة للمعدل الصفري', _salesZero, 'info'),
                  _input('3', 'مبيعات معفاة', _salesExempt, 'info'),
                  _input('4', 'صادرات خارج دول الخليج', _exports, 'info'),
                  _input('5', 'تعديلات على ضريبة المخرجات', _adjustmentsOut, 'total'),
                  const Divider(),
                  _summaryRow('إجمالي ضريبة المخرجات (Output VAT)', _outputVat, core_theme.AC.ok),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _section(
                'المشتريات ومدخلات الضريبة',
                Icons.trending_down,
                core_theme.AC.info,
                [
                  _input('6', 'مشتريات محلية خاضعة 15%', _purchasesStandard, 'total'),
                  _input('7', 'واردات (Reverse Charge)', _purchasesImport, 'total'),
                  _input('8', 'تعديلات على ضريبة المدخلات', _adjustmentsIn, 'total'),
                  const SizedBox(height: 20),
                  const Divider(),
                  _summaryRow('إجمالي ضريبة المدخلات (Input VAT)', _inputVat, core_theme.AC.info),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _netVat >= 0
                  ? [core_theme.AC.warn, core_theme.AC.warn]
                  : [core_theme.AC.ok, core_theme.AC.ok],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(_netVat >= 0 ? Icons.upload : Icons.download, color: Colors.white, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_netVat >= 0 ? 'ضريبة مستحقة الدفع إلى ZATCA' : 'ضريبة مستردة من ZATCA',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                    Text(_fmt(_netVat.abs()),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    Text('ر.س', style: TextStyle(color: core_theme.AC.ts, fontSize: 14)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('تاريخ الاستحقاق', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                  Text('2026-05-31',
                      style: TextStyle(color: Color(0xFFFFD700), fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('متبقي 42 يوم',
                        style: TextStyle(color: core_theme.AC.warn, fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildAutoPopulateBanner(),
      ],
    );
  }

  Widget _input(String code, String label, TextEditingController c, String type) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: core_theme.AC.bdr,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(code,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.tp, height: 1.4)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextField(
              controller: c,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisSize.min == MainAxisAlignment.spaceBetween
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
          Text(_fmt(value),
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: color)),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, Color color, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAutoPopulateBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: core_theme.AC.info,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.info),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: core_theme.AC.info),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'الأرقام معبّأة تلقائياً من نظام ZATCA E-Invoicing (Phase 2) — راجع ثم قدّم. أي تعديل يدوي يترك سجل تدقيق تلقائي.',
              style: TextStyle(fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
            boxShadow: [BoxShadow(color: core_theme.AC.bdr.withValues(alpha: 0.05), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Text('المملكة العربية السعودية',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('هيئة الزكاة والضريبة والجمارك',
                        style: TextStyle(fontSize: 13, color: core_theme.AC.ts)),
                    Text('Zakat, Tax and Customs Authority',
                        style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                    SizedBox(height: 12),
                    Text('إقرار ضريبة القيمة المضافة (VAT Return)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0A5F38))),
                  ],
                ),
              ),
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(child: _kv('اسم المكلّف', 'شركة APEX للحلول المالية')),
                  Expanded(child: _kv('الرقم الضريبي', '300123456700003')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _kv('فترة الإقرار', _period == '2026-04' ? 'أبريل 2026' : _period)),
                  Expanded(child: _kv('تاريخ التقديم', '2026-04-19')),
                ],
              ),
              const Divider(height: 32),
              Text('القسم الأول: ضريبة المخرجات',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: core_theme.AC.ok)),
              const SizedBox(height: 10),
              _previewRow('1', 'مبيعات محلية خاضعة 15%', _val(_salesStandard), _val(_salesStandard) * 0.15),
              _previewRow('2', 'مبيعات خاضعة للمعدل الصفري', _val(_salesZero), 0),
              _previewRow('3', 'مبيعات معفاة', _val(_salesExempt), 0),
              _previewRow('4', 'صادرات', _val(_exports), 0),
              _previewRow('5', 'تعديلات', _val(_adjustmentsOut), _val(_adjustmentsOut)),
              const Divider(),
              _previewTotalRow('إجمالي ضريبة المخرجات', _outputVat, core_theme.AC.ok),
              const SizedBox(height: 20),
              Text('القسم الثاني: ضريبة المدخلات',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: core_theme.AC.info)),
              const SizedBox(height: 10),
              _previewRow('6', 'مشتريات محلية خاضعة 15%', _val(_purchasesStandard), _val(_purchasesStandard) * 0.15),
              _previewRow('7', 'واردات (Reverse Charge)', _val(_purchasesImport), _val(_purchasesImport) * 0.15),
              _previewRow('8', 'تعديلات', _val(_adjustmentsIn), _val(_adjustmentsIn)),
              const Divider(),
              _previewTotalRow('إجمالي ضريبة المدخلات', _inputVat, core_theme.AC.info),
              const Divider(height: 32),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: core_theme.AC.ok,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: core_theme.AC.ok, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('صافي الضريبة المستحقة / المستردة',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.ok)),
                    Text(_fmt(_netVat),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'monospace',
                          color: _netVat >= 0 ? core_theme.AC.warn : core_theme.AC.ok,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _previewRow(String code, String label, double amount, double vat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 30, child: Text(code, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts))),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          SizedBox(
            width: 120,
            child: Text(_fmt(amount), textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
          ),
          SizedBox(
            width: 120,
            child: Text(_fmt(vat), textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
          ),
        ],
      ),
    );
  }

  Widget _previewTotalRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
          Text(_fmt(value),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: color)),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSubmitTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stepCard(1, 'المراجعة الذاتية', true, 'تم فحص جميع البنود تلقائياً — لا أخطاء محاسبية'),
        _stepCard(2, 'المطابقة مع القيود المحاسبية', true, 'مطابق مع الحسابات 4100, 2300 بدون فروقات'),
        _stepCard(3, 'اعتماد المدير المالي', true, 'اعتمد أحمد العتيبي — 2026-04-19 14:30'),
        _stepCard(4, 'ربط بفواتير ZATCA Phase 2', true, '1,247 فاتورة مربوطة بالإقرار'),
        _stepCard(5, 'إرسال إلى ZATCA عبر API', false, 'انقر الزر أدناه لتقديم الإقرار'),
        _stepCard(6, 'استلام رقم إشعار', false, 'يصل تلقائياً بعد القبول'),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Row(
            children: [
              Icon(Icons.security, color: core_theme.AC.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'التوقيع الرقمي سيُطبّق تلقائياً باستخدام شهادة CSID المُسجّلة لدى ZATCA.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('جاري التقديم إلى ZATCA — المبلغ: ${_fmt(_netVat.abs())} ر.س'),
                  backgroundColor: core_theme.AC.ok,
                ),
              );
            },
            icon: const Icon(Icons.cloud_upload),
            label: Text('تقديم الإقرار إلى ZATCA (${_fmt(_netVat.abs())} ر.س)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: core_theme.AC.ok,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepCard(int num, String title, bool done, String detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done ? core_theme.AC.ok : core_theme.AC.navy3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: done ? core_theme.AC.ok : core_theme.AC.bdr),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: done ? core_theme.AC.ok : core_theme.AC.bdr,
            child: done
                ? const Icon(Icons.check, color: Colors.white)
                : Text('$num', style: TextStyle(color: core_theme.AC.ts, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text(detail, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.abs() >= 1000 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}
