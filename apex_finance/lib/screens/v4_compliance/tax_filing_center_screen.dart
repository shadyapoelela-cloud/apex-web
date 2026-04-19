import 'package:flutter/material.dart';

/// Wave 141 — Unified Tax Filing Center
class TaxFilingCenterScreen extends StatefulWidget {
  const TaxFilingCenterScreen({super.key});
  @override
  State<TaxFilingCenterScreen> createState() => _TaxFilingCenterScreenState();
}

class _TaxFilingCenterScreenState extends State<TaxFilingCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: Column(children: [
        _hero(), _kpis(),
        Container(color: Colors.white, child: TabBar(controller: _tc,
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37), indicatorWeight: 3,
          tabs: const [Tab(text: 'الإقرارات المستحقة'), Tab(text: 'تحت المعالجة'), Tab(text: 'المقدّمة'), Tab(text: 'السجل')])),
        Expanded(child: TabBarView(controller: _tc, children: [_dueTab(), _inProgressTab(), _submittedTab(), _historyTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00695C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.assignment, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مركز الإقرارات الضريبية الموحّد', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('VAT + Zakat + WHT + Excise + Corporate Tax — كل ما تحتاجه', style: TextStyle(color: Colors.white70, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final due = _fillings.where((f)=>f.status.contains('مستحق')).length;
    final processing = _fillings.where((f)=>f.status.contains('معالجة')).length;
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('مستحقة', '$due', Icons.schedule, const Color(0xFFE65100))),
      Expanded(child: _kpi('قيد المعالجة', '$processing', Icons.hourglass_bottom, const Color(0xFFD4AF37))),
      Expanded(child: _kpi('مُقدّمة', '${_fillings.length - due - processing}', Icons.check_circle, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('إجمالي مدفوع 2026', '2.8M', Icons.payments, const Color(0xFF4A148C))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _dueTab() => ListView.builder(padding: const EdgeInsets.all(12),
    itemCount: _fillings.where((f)=>f.status.contains('مستحق')).length,
    itemBuilder: (_, i) {
      final f = _fillings.where((x)=>x.status.contains('مستحق')).toList()[i];
      return _card(f);
    });

  Widget _inProgressTab() => ListView.builder(padding: const EdgeInsets.all(12),
    itemCount: _fillings.where((f)=>f.status.contains('معالجة')).length,
    itemBuilder: (_, i) {
      final f = _fillings.where((x)=>x.status.contains('معالجة')).toList()[i];
      return _card(f);
    });

  Widget _submittedTab() => ListView.builder(padding: const EdgeInsets.all(12),
    itemCount: _fillings.where((f)=>f.status.contains('مُقدّم')).length,
    itemBuilder: (_, i) {
      final f = _fillings.where((x)=>x.status.contains('مُقدّم')).toList()[i];
      return _card(f);
    });

  Widget _card(_Filing f) => Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _typeColor(f.type).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(_typeIcon(f.type), color: _typeColor(f.type))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text('${f.type} • ${f.period}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ])),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(color: _statusColor(f.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(f.status, style: TextStyle(color: _statusColor(f.status), fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _mini('المبلغ', f.amount),
        _mini('الموعد', f.deadline),
        _mini('الأيام المتبقية', '${f.daysRemaining}'),
      ]),
      if (f.status.contains('مستحق') && f.daysRemaining < 10)
        Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: const Color(0xFFC62828).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Row(children: [
            const Icon(Icons.warning, color: Color(0xFFC62828), size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text('موعد حرج — تأكد من التقديم خلال ${f.daysRemaining} يوم',
              style: const TextStyle(color: Color(0xFFC62828), fontSize: 11, fontWeight: FontWeight.bold))),
          ])),
    ]),
  ));

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 9, color: Colors.black54)),
    Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
  ]));

  Widget _historyTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _history.length, itemBuilder: (_, i) {
    final h = _history[i];
    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
      leading: Icon(_typeIcon(h.$2), color: _typeColor(h.$2)),
      title: Text(h.$1, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      subtitle: Text('${h.$2} • ${h.$3}', style: const TextStyle(fontSize: 10)),
      trailing: Text(h.$4, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
    ));
  });

  Color _typeColor(String t) {
    if (t.contains('VAT')) return const Color(0xFF1A237E);
    if (t.contains('Zakat')) return const Color(0xFF2E7D32);
    if (t.contains('WHT')) return const Color(0xFFE65100);
    if (t.contains('Excise')) return const Color(0xFFD4AF37);
    if (t.contains('Corporate')) return const Color(0xFF4A148C);
    return Colors.black54;
  }

  IconData _typeIcon(String t) {
    if (t.contains('VAT')) return Icons.receipt;
    if (t.contains('Zakat')) return Icons.star;
    if (t.contains('WHT')) return Icons.money_off;
    if (t.contains('Excise')) return Icons.local_gas_station;
    if (t.contains('Corporate')) return Icons.business;
    return Icons.description;
  }

  Color _statusColor(String s) {
    if (s.contains('مُقدّم')) return const Color(0xFF2E7D32);
    if (s.contains('معالجة')) return const Color(0xFFD4AF37);
    if (s.contains('مستحق')) return const Color(0xFFE65100);
    if (s.contains('متأخر')) return const Color(0xFFC62828);
    return Colors.black54;
  }

  static const List<_Filing> _fillings = [
    _Filing('إقرار VAT أبريل 2026', 'VAT', 'شهري', '480,250 ر.س', '2026-05-28', 9, 'مستحق'),
    _Filing('إقرار الزكاة السنوي 2025', 'Zakat', 'سنوي', '1,240,000 ر.س', '2026-04-30', 11, 'قيد المعالجة'),
    _Filing('إقرار WHT أبريل 2026', 'WHT', 'شهري', '48,200 ر.س', '2026-05-10', -1, 'مُقدّم'),
    _Filing('Excise Tax Q1 2026', 'Excise', 'ربعي', '185,400 ر.س', '2026-04-30', 11, 'مستحق'),
    _Filing('Corporate Tax — فرع UAE', 'Corporate Tax UAE', 'سنوي', '320,000 د.إ', '2026-09-30', 164, 'مستحق'),
    _Filing('إقرار VAT مارس 2026', 'VAT', 'شهري', '425,800 ر.س', '2026-04-28', -7, 'مُقدّم'),
    _Filing('إقرار WHT مارس 2026', 'WHT', 'شهري', '52,100 ر.س', '2026-04-10', -25, 'مُقدّم'),
    _Filing('Pillar 2 Top-Up Tax', 'Corporate Tax Global', 'سنوي', '—', '2027-04-30', 378, 'قيد المعالجة'),
  ];

  static const List<(String, String, String, String)> _history = [
    ('إقرار VAT مارس 2026', 'VAT', '2026-04-27', '+425K ر.س'),
    ('إقرار WHT مارس 2026', 'WHT', '2026-04-09', '+52K ر.س'),
    ('إقرار VAT فبراير 2026', 'VAT', '2026-03-26', '+410K ر.س'),
    ('Excise Q4 2025', 'Excise', '2026-01-28', '+198K ر.س'),
    ('إقرار الزكاة 2024', 'Zakat', '2025-04-25', '+1.2M ر.س'),
    ('Corporate Tax UAE 2024', 'Corporate Tax UAE', '2024-09-28', '+280K د.إ'),
  ];
}

class _Filing { final String title, type, period, amount, deadline; final int daysRemaining; final String status;
  const _Filing(this.title, this.type, this.period, this.amount, this.deadline, this.daysRemaining, this.status); }
