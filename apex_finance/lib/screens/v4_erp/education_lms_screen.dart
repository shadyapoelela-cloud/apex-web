import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 123 — Education / School SIS (Student Information System)
class EducationLmsScreen extends StatefulWidget {
  const EducationLmsScreen({super.key});
  @override
  State<EducationLmsScreen> createState() => _EducationLmsScreenState();
}

class _EducationLmsScreenState extends State<EducationLmsScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'الطلاب'), Tab(text: 'المعلمون'), Tab(text: 'الرسوم'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_studentsTab(), _teachersTab(), _feesTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0D47A1)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.school, color: Color(0xFF0D47A1), size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('نظام إدارة المدارس SIS', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('طلاب، درجات، حضور، رسوم — متوافق مع نظام نور', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final paid = _fees.where((f)=>f.status.contains('مدفوع')).fold<double>(0, (s, f) => s + f.amount);
    final outstanding = _fees.where((f)=>!f.status.contains('مدفوع')).fold<double>(0, (s, f) => s + f.amount);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('الطلاب', '${_students.length}', Icons.group, const Color(0xFF0D47A1))),
      Expanded(child: _kpi('المعلمون', '${_teachers.length}', Icons.badge, const Color(0xFF4A148C))),
      Expanded(child: _kpi('مُحصل', '${(paid/1000).toStringAsFixed(0)}K', Icons.payments, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('مستحق', '${(outstanding/1000).toStringAsFixed(0)}K', Icons.hourglass_bottom, const Color(0xFFE65100))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _studentsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _students.length, itemBuilder: (_, i) {
    final s = _students[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF0D47A1).withValues(alpha: 0.1),
        child: Text(s.name.substring(0, 1), style: const TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold))),
      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${s.grade} • ${s.classroom}', style: const TextStyle(fontSize: 11)),
        Row(children: [
          Text('معدل: ${s.gpa}%', style: TextStyle(fontSize: 10, color: _gpaColor(s.gpa), fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text('حضور: ${s.attendance}%', style: TextStyle(fontSize: 10, color: _gpaColor(s.attendance), fontWeight: FontWeight.bold)),
        ]),
      ]),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: _gpaColor(s.gpa).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text(s.status, style: TextStyle(color: _gpaColor(s.gpa), fontSize: 10, fontWeight: FontWeight.bold))),
    ));
  });

  Widget _teachersTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _teachers.length, itemBuilder: (_, i) {
    final t = _teachers[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: const CircleAvatar(backgroundColor: Color(0xFF4A148C), child: Icon(Icons.badge, color: Colors.white)),
      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${t.subject} • ${t.classes} صف • ${t.students} طالب', style: const TextStyle(fontSize: 11)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.star, color: core_theme.AC.gold, size: 16),
        Text(' ${t.rating}', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ));
  });

  Widget _feesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _fees.length, itemBuilder: (_, i) {
    final f = _fees[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: _feeStatus(f.status).withValues(alpha: 0.15),
        child: Icon(Icons.payments, color: _feeStatus(f.status))),
      title: Text(f.student, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${f.feeType} • فصل ${f.term}', style: const TextStyle(fontSize: 11)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${f.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _feeStatus(f.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(f.status, style: TextStyle(color: _feeStatus(f.status), fontSize: 9, fontWeight: FontWeight.bold))),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('📚 المعدل العام', '84.2% — ارتفاع 3.2% عن العام السابق', const Color(0xFF2E7D32)),
    _insight('👨‍🎓 معدل الحضور', '94% — الهدف 95%', core_theme.AC.gold),
    _insight('💰 تحصيل الرسوم', '87% — متوسط تأخر 12 يوم', const Color(0xFFE65100)),
    _insight('⭐ تقييم المعلمين', '4.6/5 متوسط تقييمات الأهالي', const Color(0xFF4A148C)),
    _insight('📖 المادة الأقوى', 'الرياضيات 88% • العلوم 85% • اللغة العربية 90%', const Color(0xFF0D47A1)),
    _insight('📱 تكامل نظام نور', '100% درجات مُرحّلة آلياً', const Color(0xFF2E7D32)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _gpaColor(int s) {
    if (s >= 90) return const Color(0xFF2E7D32);
    if (s >= 75) return core_theme.AC.gold;
    if (s >= 60) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }

  Color _feeStatus(String s) {
    if (s.contains('مدفوع')) return const Color(0xFF2E7D32);
    if (s.contains('جزئي')) return const Color(0xFFE65100);
    if (s.contains('متأخر')) return const Color(0xFFC62828);
    return core_theme.AC.ts;
  }

  static const List<_Student> _students = [
    _Student('أحمد محمد العتيبي', 'الصف 6أ', '6-أ', 92, 96, 'ممتاز'),
    _Student('فاطمة خالد الزهراني', 'الصف 5ب', '5-ب', 88, 94, 'جيد جداً'),
    _Student('محمد علي القحطاني', 'الصف 4أ', '4-أ', 78, 85, 'جيد'),
    _Student('نورة سعد الشمري', 'الصف 6ب', '6-ب', 95, 98, 'ممتاز'),
    _Student('خالد أحمد الدوسري', 'الصف 3أ', '3-أ', 65, 82, 'مقبول'),
    _Student('سارة عبدالله المطيري', 'الصف 5أ', '5-أ', 91, 92, 'ممتاز'),
    _Student('عبدالرحمن الغامدي', 'الصف 6أ', '6-أ', 55, 78, 'ضعيف'),
    _Student('ريم فهد السبيعي', 'الصف 4ب', '4-ب', 87, 95, 'جيد جداً'),
  ];

  static const List<_Teacher> _teachers = [
    _Teacher('أ. أحمد الحارثي', 'الرياضيات', 6, 180, 4.8),
    _Teacher('أ. فاطمة الزهراني', 'اللغة العربية', 5, 150, 4.9),
    _Teacher('أ. محمد العتيبي', 'العلوم', 4, 120, 4.6),
    _Teacher('أ. نورة القحطاني', 'اللغة الإنجليزية', 6, 180, 4.7),
    _Teacher('أ. خالد الدوسري', 'التربية الإسلامية', 8, 240, 4.5),
    _Teacher('أ. سعاد المطيري', 'الدراسات الاجتماعية', 5, 150, 4.6),
  ];

  static const List<_Fee> _fees = [
    _Fee('أحمد محمد العتيبي', 'رسوم دراسية', 'الفصل الثاني', 8500, 'مدفوع'),
    _Fee('فاطمة خالد الزهراني', 'رسوم دراسية', 'الفصل الثاني', 8500, 'مدفوع'),
    _Fee('محمد علي القحطاني', 'رسوم دراسية', 'الفصل الثاني', 8500, 'جزئي'),
    _Fee('نورة سعد الشمري', 'رسوم دراسية + نقل', 'الفصل الثاني', 10200, 'مدفوع'),
    _Fee('خالد أحمد الدوسري', 'رسوم دراسية', 'الفصل الثاني', 8500, 'متأخر'),
    _Fee('سارة عبدالله المطيري', 'رسوم دراسية', 'الفصل الثاني', 8500, 'مدفوع'),
    _Fee('عبدالرحمن الغامدي', 'رسوم دراسية', 'الفصل الثاني', 8500, 'متأخر'),
    _Fee('ريم فهد السبيعي', 'رسوم + أنشطة', 'الفصل الثاني', 9200, 'جزئي'),
  ];
}

class _Student { final String name, grade, classroom; final int gpa, attendance; final String status;
  const _Student(this.name, this.grade, this.classroom, this.gpa, this.attendance, this.status); }
class _Teacher { final String name, subject; final int classes, students; final double rating;
  const _Teacher(this.name, this.subject, this.classes, this.students, this.rating); }
class _Fee { final String student, feeType, term; final double amount; final String status;
  const _Fee(this.student, this.feeType, this.term, this.amount, this.status); }
