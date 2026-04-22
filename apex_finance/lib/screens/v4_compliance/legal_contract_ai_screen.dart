import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 126 — Legal Contract AI Review
class LegalContractAiScreen extends StatefulWidget {
  const LegalContractAiScreen({super.key});
  @override
  State<LegalContractAiScreen> createState() => _LegalContractAiScreenState();
}

class _LegalContractAiScreenState extends State<LegalContractAiScreen> with SingleTickerProviderStateMixin {
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
          tabs: const [Tab(text: 'العقود'), Tab(text: 'المخاطر المكتشفة'), Tab(text: 'القوالب'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_contractsTab(), _risksTab(), _templatesTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.gavel, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('المراجعة القانونية AI', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('مراجعة العقود بالذكاء الاصطناعي — NLP عربي/إنجليزي', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() => Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
    Expanded(child: _kpi('عقود مراجعة', '${_contracts.length}', Icons.description, const Color(0xFF4A148C))),
    Expanded(child: _kpi('مخاطر حرجة', '${_risks.where((r)=>r.severity.contains('حرج')).length}', Icons.warning, const Color(0xFFC62828))),
    Expanded(child: _kpi('زمن مراجعة', '12 دقيقة', Icons.speed, const Color(0xFF2E7D32))),
    Expanded(child: _kpi('دقة AI', '96%', Icons.verified, core_theme.AC.gold)),
  ]));

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _contractsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _contracts.length, itemBuilder: (_, i) {
    final c = _contracts[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _scoreColor(c.riskScore).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.description, color: _scoreColor(c.riskScore))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('${c.type} • ${c.counterparty}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${c.riskScore}/100', style: TextStyle(fontWeight: FontWeight.bold, color: _scoreColor(c.riskScore))),
            Text(c.status, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ]),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _mini('بنود مشبوهة', '${c.flaggedClauses}'),
          _mini('القيمة', '${(c.value/1000).toStringAsFixed(0)}K ر.س'),
          _mini('الطرف', c.counterparty.length > 12 ? '${c.counterparty.substring(0,12)}...' : c.counterparty),
        ]),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
  ]));

  Widget _risksTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _risks.length, itemBuilder: (_, i) {
    final r = _risks[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _severity(r.severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.warning_amber, color: _severity(r.severity), size: 16)),
          const SizedBox(width: 10),
          Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _severity(r.severity).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(r.severity, style: TextStyle(color: _severity(r.severity), fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 6),
        Text('في: ${r.contract}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        const SizedBox(height: 6),
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(6)),
          child: Text('توصية AI: ${r.recommendation}', style: const TextStyle(fontSize: 11))),
      ]),
    ));
  });

  Widget _templatesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _templates.length, itemBuilder: (_, i) {
    final t = _templates[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: const CircleAvatar(backgroundColor: Color(0xFF4A148C), child: Icon(Icons.description, color: Colors.white)),
      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${t.category} • استُخدم ${t.usage} مرة', style: const TextStyle(fontSize: 11)),
      trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xFF2E7D32).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
        child: Text('معتمد', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold))),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🤖 توفير الوقت', '12 دقيقة لمراجعة العقد بدلاً من 4 ساعات يدوياً', const Color(0xFF2E7D32)),
    _insight('🎯 دقة الاكتشاف', '96% للبنود القانونية المخاطرة', core_theme.AC.gold),
    _insight('💰 توفير قانوني', 'وفّرت 48K ر.س رسوم محاماة هذا الشهر', const Color(0xFF4A148C)),
    _insight('⚠️ المخاطر الشائعة', 'Indemnification 34% • Limitation of Liability 28% • IP 18%', const Color(0xFFE65100)),
    _insight('🌐 لغات مدعومة', 'عربي + إنجليزي + إماراتي-كويتي (عقود محلية)', const Color(0xFF1A237E)),
    _insight('📚 قاعدة معرفية', '12,400 حكم قضائي سعودي مفهرس', const Color(0xFF1A237E)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  Color _scoreColor(int s) {
    if (s >= 75) return const Color(0xFFC62828);
    if (s >= 50) return const Color(0xFFE65100);
    if (s >= 25) return core_theme.AC.gold;
    return const Color(0xFF2E7D32);
  }

  Color _severity(String s) {
    if (s.contains('حرج')) return const Color(0xFFC62828);
    if (s.contains('عالي')) return const Color(0xFFE65100);
    if (s.contains('متوسط')) return core_theme.AC.gold;
    return const Color(0xFF2E7D32);
  }

  static const List<_Contract> _contracts = [
    _Contract('اتفاقية SaaS - شركة الأفق', 'اتفاقية خدمات', 'شركة الأفق التقني', 12_500_000, 82, 5, 'يتطلب مراجعة'),
    _Contract('عقد توريد مواد خام', 'توريد', 'مؤسسة المواد الأولية', 4_800_000, 45, 3, 'مراجعة AI مكتملة'),
    _Contract('NDA اتفاقية سرية', 'اتفاقية سرية', 'شركة استشارات دولية', 0, 18, 1, 'معتمد'),
    _Contract('عقد إيجار مقر', 'إيجار', 'شركة الاستثمار العقاري', 8_400_000, 62, 4, 'يتطلب مراجعة'),
    _Contract('اتفاقية توزيع حصري', 'توزيع', 'الشريك الإقليمي', 24_000_000, 88, 7, 'حرج — تم تعليق'),
    _Contract('عقد خدمات استشارية', 'استشارات', 'مكتب KPMG', 2_400_000, 35, 2, 'معتمد'),
    _Contract('اتفاقية شراكة استراتيجية', 'شراكة', 'Microsoft KSA', 18_000_000, 58, 4, 'قيد المراجعة'),
  ];

  static const List<_Risk> _risks = [
    _Risk('بند تعويض غير محدود', 'حرج', 'اتفاقية SaaS - شركة الأفق', 'احدد سقف التعويض بمبلغ قيمة العقد — صيغة موصى بها متوفرة'),
    _Risk('شرط إنهاء أحادي الجانب', 'عالي', 'عقد توريد مواد خام', 'أضف مهلة إشعار مسبق 90 يوم للطرف الآخر'),
    _Risk('ملكية فكرية غير واضحة', 'حرج', 'اتفاقية توزيع حصري', 'أضف قسم مفصل عن ملكية التحسينات والمشتقات'),
    _Risk('غياب بند القوة القاهرة', 'متوسط', 'عقد إيجار مقر', 'أدرج البنود القياسية لـ Force Majeure تشمل الأوبئة'),
    _Risk('حد أقصى للمسؤولية مفقود', 'عالي', 'اتفاقية شراكة استراتيجية', 'اقترح سقف مسؤولية = 2x قيمة العقد السنوية'),
    _Risk('بنود عقوبات غير متوازنة', 'متوسط', 'اتفاقية توزيع حصري', 'وازن البنود بحيث تنطبق على الطرفين'),
  ];

  static const List<_Template> _templates = [
    _Template('نموذج اتفاقية خدمات SaaS', 'خدمات', 48),
    _Template('نموذج عقد توريد', 'توريد', 82),
    _Template('نموذج NDA - عربي/إنجليزي', 'سرية', 240),
    _Template('نموذج عقد إيجار تجاري', 'عقاري', 32),
    _Template('نموذج اتفاقية مساهمين', 'شركاء', 12),
    _Template('نموذج عقد توظيف - متوافق GOSI', 'توظيف', 185),
  ];
}

class _Contract { final String title, type, counterparty; final double value; final int riskScore, flaggedClauses; final String status;
  const _Contract(this.title, this.type, this.counterparty, this.value, this.riskScore, this.flaggedClauses, this.status); }
class _Risk { final String title, severity, contract, recommendation;
  const _Risk(this.title, this.severity, this.contract, this.recommendation); }
class _Template { final String name, category; final int usage;
  const _Template(this.name, this.category, this.usage); }
