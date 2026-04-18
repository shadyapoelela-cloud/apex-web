/// APEX Wave 80 — Internal Controls Library (SOX / COSO).
/// Route: /app/audit/fieldwork/controls-library
///
/// Registry of internal controls with test results and rating.
library;

import 'package:flutter/material.dart';

class ControlsLibraryScreen extends StatefulWidget {
  const ControlsLibraryScreen({super.key});
  @override
  State<ControlsLibraryScreen> createState() => _ControlsLibraryScreenState();
}

class _ControlsLibraryScreenState extends State<ControlsLibraryScreen> {
  String _domainFilter = 'all';
  String _typeFilter = 'all';

  final _controls = const [
    _Control('CTL-001', 'مصادقة العميل قبل تعديل بيانات الدفع', 'AR', 'preventive', 'automated', 'effective', 120, 118, 'عالٍ'),
    _Control('CTL-002', 'الفصل بين واجبات إدخال الفواتير واعتمادها', 'AR', 'preventive', 'manual', 'effective', 45, 45, 'عالٍ'),
    _Control('CTL-003', 'المطابقة البنكية اليومية', 'Cash', 'detective', 'automated', 'effective', 90, 87, 'عالٍ'),
    _Control('CTL-004', 'حدود الاعتماد على المدفوعات', 'AP', 'preventive', 'automated', 'effective', 60, 60, 'عالٍ'),
    _Control('CTL-005', 'الجرد المادي الدوري للمخزون', 'Inventory', 'detective', 'manual', 'partial', 4, 3, 'متوسط'),
    _Control('CTL-006', 'استعراض التقارير الشاذة شهرياً', 'General', 'detective', 'manual', 'needs-improvement', 12, 9, 'متوسط'),
    _Control('CTL-007', 'توثيق عقود الموظفين الجدد', 'HR', 'preventive', 'manual', 'effective', 24, 24, 'منخفض'),
    _Control('CTL-008', 'مراجعة الجدول الزمني للمشاريع', 'Projects', 'detective', 'manual', 'effective', 48, 45, 'متوسط'),
    _Control('CTL-009', 'اختبار النسخ الاحتياطية الأسبوعي', 'IT', 'detective', 'automated', 'effective', 52, 52, 'عالٍ'),
    _Control('CTL-010', 'فحص صلاحيات المستخدمين ربع سنوي', 'IT', 'detective', 'manual', 'effective', 4, 4, 'عالٍ'),
    _Control('CTL-011', 'مراجعة مستقلة للإقرارات الضريبية', 'Tax', 'detective', 'manual', 'effective', 12, 12, 'عالٍ'),
    _Control('CTL-012', 'توقيع إلكتروني على قيود التسوية', 'GL', 'preventive', 'automated', 'effective', 180, 175, 'عالٍ'),
    _Control('CTL-013', 'التحقق من الهوية قبل تحويل الرواتب', 'Payroll', 'preventive', 'automated', 'effective', 12, 12, 'عالٍ'),
    _Control('CTL-014', 'تدريب منع الاحتيال السنوي', 'General', 'preventive', 'manual', 'partial', 1, 0, 'متوسط'),
    _Control('CTL-015', 'فحص مصروفات أعلى من 50K', 'AP', 'detective', 'manual', 'needs-improvement', 35, 22, 'متوسط'),
  ];

  List<_Control> get _filtered {
    return _controls.where((c) {
      if (_domainFilter != 'all' && c.domain != _domainFilter) return false;
      if (_typeFilter != 'all' && c.type != _typeFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final effective = _controls.where((c) => c.status == 'effective').length;
    final needsImp = _controls.where((c) => c.status == 'needs-improvement').length;
    final partial = _controls.where((c) => c.status == 'partial').length;
    final totalTests = _controls.fold(0, (s, c) => s + c.expectedTests);
    final passedTests = _controls.fold(0, (s, c) => s + c.passedTests);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('إجمالي الضوابط', '${_controls.length}', const Color(0xFF4A148C), Icons.library_books),
            _kpi('فعّالة', '$effective', Colors.green, Icons.check_circle),
            _kpi('جزئياً', '$partial', Colors.orange, Icons.warning),
            _kpi('تحتاج تحسين', '$needsImp', Colors.red, Icons.error),
            _kpi('نسبة نجاح الاختبار', '${(passedTests / totalTests * 100).toStringAsFixed(0)}%', Colors.blue, Icons.analytics),
          ],
        ),
        const SizedBox(height: 16),
        _buildFilters(),
        const SizedBox(height: 16),
        _buildControlsTable(),
        const SizedBox(height: 16),
        _buildCosoFramework(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.security, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مكتبة الضوابط الداخلية',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('SOX · COSO 2013 · ISO 31000 — سجل الضوابط مع نتائج الاختبار والتقييم',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterBtn('المجال', _domainFilter, const [
          _FOp('all', 'الكل'),
          _FOp('AR', 'المدينون'),
          _FOp('AP', 'الدائنون'),
          _FOp('Cash', 'النقدية'),
          _FOp('Inventory', 'المخزون'),
          _FOp('HR', 'الموارد البشرية'),
          _FOp('Payroll', 'الرواتب'),
          _FOp('Tax', 'الضرائب'),
          _FOp('IT', 'التقنية'),
          _FOp('GL', 'الدفتر العام'),
          _FOp('Projects', 'المشاريع'),
          _FOp('General', 'عام'),
        ], (v) => setState(() => _domainFilter = v)),
        _filterBtn('النوع', _typeFilter, const [
          _FOp('all', 'الكل'),
          _FOp('preventive', 'وقائي'),
          _FOp('detective', 'اكتشافي'),
        ], (v) => setState(() => _typeFilter = v)),
      ],
    );
  }

  Widget _filterBtn(String label, String value, List<_FOp> ops, void Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label:', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
            items: ops.map((o) => DropdownMenuItem(value: o.id, child: Text(o.label))).toList(),
            onChanged: (v) => onChanged(v ?? 'all'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Expanded(child: Text('رقم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 4, child: Text('الضابط', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('المجال', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('النوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('التنفيذ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('المخاطر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('نسبة الاختبار', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          for (final c in _filtered) _controlRow(c),
        ],
      ),
    );
  }

  Widget _controlRow(_Control c) {
    final pct = c.expectedTests > 0 ? c.passedTests / c.expectedTests : 0.0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(child: Text(c.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
          Expanded(flex: 4, child: Text(c.description, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
              child: Text(c.domain, style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (c.type == 'preventive' ? Colors.green : Colors.orange).withOpacity(0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(c.type == 'preventive' ? 'وقائي' : 'اكتشافي',
                  style: TextStyle(
                      fontSize: 10,
                      color: c.type == 'preventive' ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(c.execution == 'automated' ? Icons.smart_toy : Icons.person, size: 12),
                const SizedBox(width: 4),
                Text(c.execution == 'automated' ? 'آلي' : 'يدوي',
                    style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _riskColor(c.risk).withOpacity(0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(c.risk, style: TextStyle(fontSize: 10, color: _riskColor(c.risk), fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(pct >= 0.95 ? Colors.green : pct >= 0.7 ? Colors.orange : Colors.red),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 6),
                Text('${c.passedTests}/${c.expectedTests}',
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _statusColor(c.status).withOpacity(0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(_statusLabel(c.status),
                  style: TextStyle(fontSize: 10, color: _statusColor(c.status), fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCosoFramework() {
    final components = const [
      _Coso('Control Environment', 'بيئة الرقابة', 5, 5, Colors.blue),
      _Coso('Risk Assessment', 'تقييم المخاطر', 4, 4, Colors.orange),
      _Coso('Control Activities', 'الأنشطة الرقابية', 10, 12, Colors.green),
      _Coso('Information & Communication', 'المعلومات والتواصل', 3, 3, Colors.purple),
      _Coso('Monitoring Activities', 'أنشطة المتابعة', 2, 3, Colors.teal),
    ];
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
              Icon(Icons.architecture, color: Color(0xFF4A148C)),
              SizedBox(width: 8),
              Text('إطار COSO 2013 — تقييم المكوّنات الخمسة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          for (final c in components) _cosoRow(c),
        ],
      ),
    );
  }

  Widget _cosoRow(_Coso c) {
    final pct = c.total > 0 ? c.covered / c.total : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: c.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.verified_user, color: c.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.nameAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(c.nameEn, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(c.color),
                    minHeight: 10,
                  ),
                ),
                const SizedBox(width: 10),
                Text('${c.covered} / ${c.total}',
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: c.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'effective':
        return Colors.green;
      case 'partial':
        return Colors.orange;
      case 'needs-improvement':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'effective':
        return 'فعّال';
      case 'partial':
        return 'جزئي';
      case 'needs-improvement':
        return 'يحتاج تحسين';
      default:
        return s;
    }
  }

  Color _riskColor(String r) {
    switch (r) {
      case 'عالٍ':
        return Colors.red;
      case 'متوسط':
        return Colors.orange;
      case 'منخفض':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class _Control {
  final String id;
  final String description;
  final String domain;
  final String type;
  final String execution;
  final String status;
  final int expectedTests;
  final int passedTests;
  final String risk;
  const _Control(this.id, this.description, this.domain, this.type, this.execution, this.status, this.expectedTests, this.passedTests, this.risk);
}

class _Coso {
  final String nameEn;
  final String nameAr;
  final int covered;
  final int total;
  final Color color;
  const _Coso(this.nameEn, this.nameAr, this.covered, this.total, this.color);
}

class _FOp {
  final String id;
  final String label;
  const _FOp(this.id, this.label);
}
