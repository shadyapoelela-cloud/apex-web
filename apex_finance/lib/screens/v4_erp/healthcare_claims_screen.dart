import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 113 — Healthcare Claims Processing
/// Insurance claims, CCHI compliance, medical billing
class HealthcareClaimsScreen extends StatefulWidget {
  const HealthcareClaimsScreen({super.key});
  @override
  State<HealthcareClaimsScreen> createState() => _HealthcareClaimsScreenState();
}

class _HealthcareClaimsScreenState extends State<HealthcareClaimsScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'المطالبات'), Tab(text: 'المرضى'), Tab(text: 'الموافقات المسبقة'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_claimsTab(), _patientsTab(), _priorAuthTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF00838F), Color(0xFF006064)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.local_hospital, color: Color(0xFF006064), size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('مطالبات التأمين الصحي', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('معالجة المطالبات مع CCHI، NPHIES، ICD-10', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified, color: Colors.white, size: 16), SizedBox(width: 4),
          Text('NPHIES', style: TextStyle(color: Colors.white, fontSize: 12)),
        ])),
    ]),
  );

  Widget _kpis() {
    final total = _claims.length;
    final approved = _claims.where((c)=>c.status.contains('معتمد')).length;
    final pending = _claims.where((c)=>c.status.contains('قيد')).length;
    final totalAmount = _claims.fold<double>(0, (s, c) => s + c.amount);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('المطالبات', '$total', Icons.medical_services, const Color(0xFF006064))),
      Expanded(child: _kpi('معتمد', '$approved', Icons.check_circle, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('قيد المعالجة', '$pending', Icons.hourglass_bottom, const Color(0xFFE65100))),
      Expanded(child: _kpi('إجمالي القيمة', '${(totalAmount/1000).toStringAsFixed(0)}K', Icons.payments, core_theme.AC.gold)),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _claimsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _claims.length, itemBuilder: (_, i) {
    final c = _claims[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _statusColor(c.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.medical_information, color: _statusColor(c.status))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${c.patient} • ${c.insurer}', style: const TextStyle(fontSize: 11)),
          ])),
          Text('${c.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006064))),
        ]),
        const SizedBox(height: 8),
        Text('التشخيص: ${c.diagnosis}', style: const TextStyle(fontSize: 11.5)),
        Text('ICD-10: ${c.icd10}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 6),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _statusColor(c.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(c.status, style: TextStyle(color: _statusColor(c.status), fontSize: 10, fontWeight: FontWeight.bold))),
          const Spacer(),
          Text(c.date, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ]),
      ]),
    ));
  });

  Widget _patientsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _patients.length, itemBuilder: (_, i) {
    final p = _patients[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF006064).withValues(alpha: 0.1), child: const Icon(Icons.person, color: Color(0xFF006064))),
      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('ID: ${p.nationalId} • ${p.age} سنة', style: const TextStyle(fontSize: 11)),
        Text('${p.insurer} • بوليصة: ${p.policy}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${p.visits} زيارة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        Text('${p.totalClaims.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
    ));
  });

  Widget _priorAuthTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _auths.length, itemBuilder: (_, i) {
    final a = _auths[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _statusColor(a.status).withValues(alpha: 0.15), child: Icon(Icons.assignment, color: _statusColor(a.status))),
      title: Text(a.procedure, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${a.patient} • ${a.insurer}', style: const TextStyle(fontSize: 11)),
        Text('CPT: ${a.cpt} • تاريخ: ${a.date}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${a.estimatedCost.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _statusColor(a.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(a.status, style: TextStyle(color: _statusColor(a.status), fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🏥 نشاط الأسبوع', '487 مطالبة — ارتفاع 12% عن الأسبوع السابق', const Color(0xFF006064)),
    _insight('✅ معدل الاعتماد', '93.4% مطالبات معتمدة من الشركات التأمينية', const Color(0xFF2E7D32)),
    _insight('⏱️ زمن المعالجة', 'متوسط 2.8 يوم من التقديم للسداد', const Color(0xFF1A237E)),
    _insight('💊 أكثر الإجراءات', 'استشارات 45% • فحوصات 28% • أشعة 18% • أخرى 9%', const Color(0xFF4A148C)),
    _insight('⚠️ الرفض', '6.6% رفض — السبب الأول: وثائق ناقصة (62%)', const Color(0xFFC62828)),
    _insight('🇸🇦 NPHIES Integration', '100% مطالبات مُرسلة عبر NPHIES', const Color(0xFF2E7D32)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _statusColor(String s) {
    if (s.contains('معتمد') || s.contains('موافق')) return const Color(0xFF2E7D32);
    if (s.contains('قيد')) return const Color(0xFFE65100);
    if (s.contains('مرفوض')) return const Color(0xFFC62828);
    if (s.contains('مسودة')) return core_theme.AC.ts;
    return const Color(0xFF1A237E);
  }

  static const List<_Claim> _claims = [
    _Claim('CLM-2026-0451', 'أحمد العتيبي', 'بوبا العربية', 'التهاب حاد في الجيوب الأنفية', 'J01.00', 1250, '2026-04-18', 'معتمد'),
    _Claim('CLM-2026-0452', 'فاطمة السبيعي', 'التعاونية', 'فحص سكري روتيني', 'Z13.1', 420, '2026-04-17', 'معتمد'),
    _Claim('CLM-2026-0453', 'محمد القحطاني', 'ميدغلف', 'كسر في الذراع - تثبيت', 'S52.501A', 8500, '2026-04-16', 'قيد المراجعة'),
    _Claim('CLM-2026-0454', 'نورة الشمري', 'بوبا العربية', 'حمل طبيعي - متابعة', 'Z34.83', 680, '2026-04-15', 'معتمد'),
    _Claim('CLM-2026-0455', 'خالد الزهراني', 'الدرع العربي', 'ارتفاع ضغط الدم', 'I10', 380, '2026-04-14', 'مرفوض'),
    _Claim('CLM-2026-0456', 'سارة المهندس', 'التعاونية', 'عملية استئصال الزائدة', 'K35.80', 12_500, '2026-04-13', 'معتمد'),
    _Claim('CLM-2026-0457', 'أحمد الغامدي', 'بوبا العربية', 'تنظيف أسنان', 'D1110', 250, '2026-04-12', 'معتمد'),
    _Claim('CLM-2026-0458', 'هند العتيبي', 'ميدغلف', 'فحص قلب شامل', 'I25.10', 2_800, '2026-04-11', 'قيد المراجعة'),
  ];

  static const List<_Patient> _patients = [
    _Patient('أحمد العتيبي', '1091234567', 42, 'بوبا العربية', 'BUPA-2026-1845', 8, 14_520),
    _Patient('فاطمة السبيعي', '1092345678', 35, 'التعاونية', 'TAW-2026-0932', 12, 6_340),
    _Patient('محمد القحطاني', '1093456789', 58, 'ميدغلف', 'MED-2026-4521', 22, 45_800),
    _Patient('نورة الشمري', '1094567890', 28, 'بوبا العربية', 'BUPA-2026-2145', 6, 3_240),
    _Patient('خالد الزهراني', '1095678901', 50, 'الدرع العربي', 'DRA-2026-1234', 18, 28_900),
  ];

  static const List<_Auth> _auths = [
    _Auth('عملية تنظير مفصل الركبة', 'محمد القحطاني', 'ميدغلف', '29881', '2026-04-25', 18_500, 'قيد المراجعة'),
    _Auth('أشعة رنين مغناطيسي - دماغ', 'أحمد العتيبي', 'بوبا العربية', '70553', '2026-04-22', 2_400, 'موافق'),
    _Auth('جلسات علاج طبيعي', 'فاطمة السبيعي', 'التعاونية', '97110', '2026-04-20', 1_200, 'موافق'),
    _Auth('فحص وظائف الكبد شامل', 'خالد الزهراني', 'الدرع العربي', '80076', '2026-04-21', 680, 'مرفوض'),
  ];
}

class _Claim { final String id, patient, insurer, diagnosis, icd10; final double amount; final String date, status;
  const _Claim(this.id, this.patient, this.insurer, this.diagnosis, this.icd10, this.amount, this.date, this.status); }
class _Patient { final String name, nationalId; final int age; final String insurer, policy; final int visits; final double totalClaims;
  const _Patient(this.name, this.nationalId, this.age, this.insurer, this.policy, this.visits, this.totalClaims); }
class _Auth { final String procedure, patient, insurer, cpt, date; final double estimatedCost; final String status;
  const _Auth(this.procedure, this.patient, this.insurer, this.cpt, this.date, this.estimatedCost, this.status); }
