/// APEX Wave 40 — Payroll Run (HR/payroll).
/// Route: /app/erp/hr/payroll
///
/// Monthly payroll processing with GOSI, WPS integration.
library;

import 'package:flutter/material.dart';

class PayrollRunScreen extends StatefulWidget {
  const PayrollRunScreen({super.key});
  @override
  State<PayrollRunScreen> createState() => _PayrollRunScreenState();
}

class _PayrollRunScreenState extends State<PayrollRunScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _period = '2026-04';

  final _rows = <_PayRow>[
    _PayRow('EMP-001', 'أحمد محمد العتيبي', 'مدير مالي', 18000, 4000, 1620, 150, 0, true),
    _PayRow('EMP-002', 'سارة خالد الدوسري', 'محاسبة أولى', 12000, 2500, 1080, 200, 500, true),
    _PayRow('EMP-003', 'محمد عبدالله القحطاني', 'مدقق داخلي', 14000, 3000, 1260, 0, 0, true),
    _PayRow('EMP-004', 'نورة سعد الغامدي', 'محللة ضرائب', 10000, 2000, 900, 100, 0, true),
    _PayRow('EMP-005', 'فهد ناصر الشمري', 'محاسب', 8000, 1500, 720, 0, 250, true),
    _PayRow('EMP-006', 'لينا عادل البكري', 'مسؤولة موارد بشرية', 9500, 1800, 855, 0, 0, false),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  double get _grossTotal => _rows.where((r) => r.included).fold(0.0, (s, r) => s + r.basic + r.allowances);
  double get _gosiTotal => _rows.where((r) => r.included).fold(0.0, (s, r) => s + r.gosi);
  double get _deductionsTotal => _rows.where((r) => r.included).fold(0.0, (s, r) => s + r.deductions);
  double get _netTotal => _grossTotal - _gosiTotal - _deductionsTotal;
  int get _includedCount => _rows.where((r) => r.included).length;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildStatsRow(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(icon: Icon(Icons.people, size: 16), text: 'الموظفون'),
            Tab(icon: Icon(Icons.health_and_safety, size: 16), text: 'GOSI / WPS'),
            Tab(icon: Icon(Icons.request_quote, size: 16), text: 'الحسومات'),
            Tab(icon: Icon(Icons.check_circle, size: 16), text: 'الاعتماد والصرف'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildEmployeesTab(),
              _buildGosiWpsTab(),
              _buildDeductionsTab(),
              _buildApprovalTab(),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مسير الرواتب',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('حساب تلقائي للأساسي والبدلات والحسومات و GOSI — مرتبط بـ WPS',
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
              dropdownColor: const Color(0xFF1E3A8A),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              iconEnabledColor: Colors.white,
              items: const [
                DropdownMenuItem(value: '2026-04', child: Text('أبريل 2026')),
                DropdownMenuItem(value: '2026-03', child: Text('مارس 2026')),
                DropdownMenuItem(value: '2026-02', child: Text('فبراير 2026')),
              ],
              onChanged: (v) => setState(() => _period = v ?? _period),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _stat('موظفون مشمولون', '$_includedCount', Colors.blue, Icons.people),
          _stat('إجمالي الرواتب', _fmt(_grossTotal), Colors.green, Icons.attach_money),
          _stat('GOSI', _fmt(_gosiTotal), Colors.orange, Icons.health_and_safety),
          _stat('الصافي', _fmt(_netTotal), const Color(0xFFD4AF37), Icons.account_balance_wallet),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: const Row(
                  children: [
                    SizedBox(width: 40),
                    Expanded(flex: 2, child: Text('الموظف', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(flex: 2, child: Text('المسمى', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(child: Text('الأساسي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(child: Text('البدلات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(child: Text('GOSI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(child: Text('حسومات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12))),
                    Expanded(child: Text('الصافي', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFD4AF37)))),
                  ],
                ),
              ),
              for (var i = 0; i < _rows.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _rows[i].included ? null : Colors.grey.shade50,
                    border: Border(top: BorderSide(color: Colors.black12.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _rows[i].included,
                        onChanged: (v) => setState(() => _rows[i].included = v ?? false),
                        activeColor: const Color(0xFFD4AF37),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_rows[i].name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(_rows[i].id, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Expanded(flex: 2, child: Text(_rows[i].title, style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text(_fmt(_rows[i].basic), style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text(_fmt(_rows[i].allowances), style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text(_fmt(_rows[i].gosi), style: const TextStyle(fontSize: 12, color: Colors.orange))),
                      Expanded(child: Text(_fmt(_rows[i].deductions), style: const TextStyle(fontSize: 12, color: Colors.red))),
                      Expanded(
                        child: Text(
                          _fmt(_rows[i].basic + _rows[i].allowances - _rows[i].gosi - _rows[i].deductions),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGosiWpsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoCard(
          'GOSI — التأمينات الاجتماعية',
          'المستحق على صاحب العمل: ${_fmt(_gosiTotal * 9 / 9)} ر.س (9%)',
          'المستحق على الموظف: ${_fmt(_gosiTotal)} ر.س (9%)',
          'الإجمالي للإيداع: ${_fmt(_gosiTotal * 2)} ر.س',
          Colors.orange,
          Icons.health_and_safety,
        ),
        const SizedBox(height: 12),
        _infoCard(
          'WPS — نظام حماية الأجور',
          'البنك المحول منه: الراجحي — SA03 8000 0000 6080 1016 7519',
          'تاريخ التنفيذ المقترح: 2026-05-01',
          'عدد المستفيدين: $_includedCount موظف',
          Colors.blue,
          Icons.shield,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ملف SIF جاهز للتحميل — WPS format v2.0، موافق لمواصفات البنك المركزي',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Icon(Icons.download, color: Colors.green, size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard(String title, String line1, String line2, String line3, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          Text(line1, style: const TextStyle(fontSize: 12, height: 1.6)),
          Text(line2, style: const TextStyle(fontSize: 12, height: 1.6)),
          Text(line3, style: const TextStyle(fontSize: 12, height: 1.6, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildDeductionsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('أنواع الحسومات المطبّقة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _deductionRow('سلفة', 2, 750),
        _deductionRow('غياب', 1, 300),
        _deductionRow('قرض سكني', 1, 200),
        _deductionRow('ضريبة دخل (غير سعودي)', 0, 0),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('إجمالي الحسومات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            Text(_fmt(_deductionsTotal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.red)),
          ],
        ),
      ],
    );
  }

  Widget _deductionRow(String type, int count, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black12))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(type, style: const TextStyle(fontSize: 13))),
          Expanded(child: Text('$count موظف', style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Text(_fmt(amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildApprovalTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _stepCard(1, 'احتساب المسير', true, 'تم بواسطة النظام — 2026-04-28 09:15'),
        _stepCard(2, 'مراجعة مدير الموارد البشرية', true, 'اعتمد لينا البكري — 2026-04-28 14:30'),
        _stepCard(3, 'مراجعة المدير المالي', false, 'في انتظار: أحمد العتيبي'),
        _stepCard(4, 'ترحيل قيد المسير', false, 'سيُنشأ قيد على حساب 5100 — مصروف رواتب'),
        _stepCard(5, 'إيداع WPS', false, 'بعد الاعتماد النهائي'),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم إرسال المسير للمدير المالي — إجمالي $_includedCount موظف، صافي ${_fmt(_netTotal)}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.send),
            label: Text('إرسال للمدير المالي — ${_fmt(_netTotal)} صافي'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
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
        color: done ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: done ? Colors.green.shade200 : Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: done ? Colors.green : Colors.grey.shade300,
            child: done
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text('$num', style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(detail, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
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

class _PayRow {
  final String id;
  final String name;
  final String title;
  final double basic;
  final double allowances;
  final double gosi;
  final double deductions;
  final double advance;
  bool included;
  _PayRow(this.id, this.name, this.title, this.basic, this.allowances, this.gosi, this.deductions, this.advance, this.included);
}
