import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 139 — ZATCA CSID Certificate Manager
class ZatcaCsidManagerScreen extends StatefulWidget {
  const ZatcaCsidManagerScreen({super.key});
  @override
  State<ZatcaCsidManagerScreen> createState() => _ZatcaCsidManagerScreenState();
}

class _ZatcaCsidManagerScreenState extends State<ZatcaCsidManagerScreen> with SingleTickerProviderStateMixin {
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
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold, indicatorWeight: 3,
          tabs: const [Tab(text: 'الشهادات النشطة'), Tab(text: 'التسجيل الجديد'), Tab(text: 'تنبيهات الانتهاء'), Tab(text: 'السجل')])),
        Expanded(child: TabBarView(controller: _tc, children: [_activeTab(), _registerTab(), _alertsTab(), _historyTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.vpn_key, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مدير شهادات ZATCA CSID', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Cryptographic Stamp ID — تسجيل وإدارة ودورة حياة كاملة', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('شهادات نشطة', '${_certs.where((c)=>c.status=="نشطة").length}', Icons.verified, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('ستنتهي قريباً', '${_certs.where((c)=>c.status=="قريب الانتهاء").length}', Icons.warning, const Color(0xFFE65100))),
    Expanded(child: _kpi('منتهية', '${_certs.where((c)=>c.status=="منتهية").length}', Icons.error, const Color(0xFFC62828))),
    Expanded(child: _kpi('فواتير موقّعة', '8,420', Icons.receipt, const Color(0xFF4A148C))),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _activeTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _certs.length, itemBuilder: (_, i) {
    final c = _certs[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _statusColor(c.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.vpn_key, color: _statusColor(c.status))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('CSID: ${c.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)),
            Text('${c.vatNumber} • ${c.environment}', style: const TextStyle(fontSize: 11)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: _statusColor(c.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(c.status, style: TextStyle(color: _statusColor(c.status), fontSize: 10, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _mini('الإصدار', c.issueDate),
          _mini('الانتهاء', c.expiryDate),
          _mini('الأيام المتبقية', '${c.daysUntilExpiry} يوم'),
          _mini('SN', c.serial),
        ]),
        const SizedBox(height: 6),
        Text('فواتير موقّعة: ${c.invoicesSigned}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
  ]));

  Widget _registerTab() => ListView(padding: const EdgeInsets.all(14), children: [
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('تسجيل شهادة CSID جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF4A148C))),
      const SizedBox(height: 14),
      _step(1, 'إنشاء CSR', 'Certificate Signing Request بمعلومات البائع'),
      _step(2, 'الحصول على OTP', 'من بوابة ZATCA Fatoora', isActive: true),
      _step(3, 'إرسال للـ Compliance API', 'POST /compliance/csids'),
      _step(4, 'اختبار فاتورة', 'توقيع 3 فواتير اختبار + مطابقة'),
      _step(5, 'الحصول على Production CSID', 'بعد نجاح الـ compliance'),
      const SizedBox(height: 14),
      ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.add_circle),
        label: Text('بدء التسجيل'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A148C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    ]))),
  ]);

  Widget _step(int num, String title, String desc, {bool isActive = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(
        color: isActive ? core_theme.AC.gold : core_theme.AC.td, shape: BoxShape.circle),
        child: Center(child: Text('$num', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13,
          color: isActive ? core_theme.AC.gold : core_theme.AC.tp)),
        Text(desc, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ])),
    ]));

  Widget _alertsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _alerts.length, itemBuilder: (_, i) {
    final a = _alerts[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: Icon(Icons.warning_amber, color: _alertColor(a.severity)),
      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Text(a.message, style: const TextStyle(fontSize: 11)),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: _alertColor(a.severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(a.severity, style: TextStyle(color: _alertColor(a.severity), fontWeight: FontWeight.bold, fontSize: 9))),
    ));
  });

  Widget _historyTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _history.length, itemBuilder: (_, i) {
    final h = _history[i];
    return Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
      leading: Icon(_historyIcon(h.$2), color: const Color(0xFF1A237E)),
      title: Text(h.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      subtitle: Text(h.$2, style: const TextStyle(fontSize: 10)),
      trailing: Text(h.$3, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
    ));
  });

  IconData _historyIcon(String t) {
    if (t.contains('إصدار')) return Icons.add_circle;
    if (t.contains('تجديد')) return Icons.refresh;
    if (t.contains('إلغاء')) return Icons.cancel;
    if (t.contains('تحديث')) return Icons.update;
    return Icons.history;
  }

  Color _statusColor(String s) {
    if (s.contains('نشطة')) return const Color(0xFF2E7D32);
    if (s.contains('قريب')) return const Color(0xFFE65100);
    if (s.contains('منتهية')) return const Color(0xFFC62828);
    return core_theme.AC.ts;
  }

  Color _alertColor(String s) {
    if (s.contains('حرج')) return const Color(0xFFC62828);
    if (s.contains('عالي')) return const Color(0xFFE65100);
    if (s.contains('متوسط')) return core_theme.AC.gold;
    return const Color(0xFF1A237E);
  }

  static const List<_Cert> _certs = [
    _Cert('csid_PRD_2024_4851', '310175494400003', 'Production', '2024-03-15', '2027-03-15', 698, 'SN:4851', 4820, 'نشطة'),
    _Cert('csid_PRD_2024_4852', '310175494400004', 'Production', '2024-06-10', '2027-06-10', 785, 'SN:4852', 2480, 'نشطة'),
    _Cert('csid_PRD_2025_5102', '310175494400005', 'Production', '2025-11-20', '2026-05-20', 32, 'SN:5102', 1120, 'قريب الانتهاء'),
    _Cert('csid_COMP_2025_0128', '310175494400003', 'Compliance', '2025-09-15', '2026-09-15', 150, 'SN:0128', 485, 'نشطة'),
    _Cert('csid_PRD_2023_3951', '310175494400001', 'Production', '2023-04-01', '2026-04-01', 0, 'SN:3951', 0, 'منتهية'),
  ];

  static const List<_Alert> _alerts = [
    _Alert('شهادة ستنتهي خلال 32 يوم', 'CSID csid_PRD_2025_5102 تحتاج تجديد قبل 2026-05-20', 'عالي'),
    _Alert('تنبيه حرج: شهادة منتهية', 'CSID csid_PRD_2023_3951 منتهية منذ 2 يوم — الفواتير لن توقع', 'حرج'),
    _Alert('تحديث اختياري متاح', 'معيار ZATCA جديد TLV QR — تحديث مستحسن', 'متوسط'),
    _Alert('تجديد سلس متاح', '3 شهادات يمكن تجديدها تلقائياً قبل 30 يوم من الانتهاء', 'منخفض'),
  ];

  static const List<(String, String, String)> _history = [
    ('csid_PRD_2025_5102', 'إصدار شهادة جديدة', '2025-11-20'),
    ('csid_PRD_2024_4852', 'تحديث SN', '2024-06-10'),
    ('csid_PRD_2024_4851', 'إصدار شهادة جديدة', '2024-03-15'),
    ('csid_PRD_2023_3951', 'إلغاء تلقائي (انتهت)', '2026-04-01'),
    ('csid_COMP_2025_0128', 'تجديد Compliance', '2025-09-15'),
    ('csid_PRD_2023_3750', 'إلغاء يدوي (استبدال)', '2024-12-01'),
  ];
}

class _Cert { final String id, vatNumber, environment, issueDate, expiryDate; final int daysUntilExpiry; final String serial; final int invoicesSigned; final String status;
  const _Cert(this.id, this.vatNumber, this.environment, this.issueDate, this.expiryDate, this.daysUntilExpiry, this.serial, this.invoicesSigned, this.status); }
class _Alert { final String title, message, severity;
  const _Alert(this.title, this.message, this.severity); }
