/// APEX Wave 33 — Industry Packs (F&B, Manufacturing, Healthcare, Logistics, Retail).
///
/// Pre-configured templates with industry-specific CoA, KPIs, reports, and rules.
///
/// Route: /app/marketplace/client/industry-packs
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/apex_v5_undo_toast.dart';

class IndustryPacksScreen extends StatefulWidget {
  const IndustryPacksScreen({super.key});

  @override
  State<IndustryPacksScreen> createState() => _IndustryPacksScreenState();
}

class _IndustryPacksScreenState extends State<IndustryPacksScreen> {
  String _selected = 'fnb';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 260, child: _buildSidebar()),
        const VerticalDivider(width: 1),
        Expanded(child: _buildDetail()),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('باقات القطاعات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFE65100))),
          ),
          for (final p in _packs)
            GestureDetector(
              onTap: () => setState(() => _selected = p.id),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selected == p.id ? p.color.withOpacity(0.1) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _selected == p.id ? p.color : core_theme.AC.tp.withOpacity(0.06), width: _selected == p.id ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: p.color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Icon(p.icon, color: p.color, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.nameAr, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          Text('${p.customers} عميل', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                        ],
                      ),
                    ),
                    if (p.popular)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(3)),
                        child: Text('شائع', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetail() {
    final pack = _packs.firstWhere((p) => p.id == _selected);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [pack.color, pack.color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: Icon(pack.icon, color: Colors.white, size: 40),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(pack.nameAr, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                      Text(pack.nameEn, style: TextStyle(color: core_theme.AC.ts, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(pack.description, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.5)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Text('${pack.customers} عميل', style: TextStyle(color: pack.color, fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: Text(pack.rating, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // What's included
          Text('ما يحتويه هذا الباقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 800 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 2.4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _includedCard('شجرة حسابات جاهزة', '${pack.coaAccounts} حساب مُعدّ مسبقاً', Icons.account_tree, pack.color),
                  _includedCard('قوالب فواتير', '${pack.invoiceTemplates} قالب حسب الخدمة', Icons.receipt, pack.color),
                  _includedCard('KPIs حسب القطاع', '${pack.kpis} مؤشّر', Icons.trending_up, pack.color),
                  _includedCard('تقارير مخصّصة', '${pack.reports} تقرير', Icons.assessment, pack.color),
                  _includedCard('قواعد Workflow', '${pack.workflows} قاعدة جاهزة', Icons.account_tree, pack.color),
                  _includedCard('تكاملات خاصة', '${pack.integrations}', Icons.extension, pack.color),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Unique features
          Text('ميزات خاصة بالقطاع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final feature in pack.uniqueFeatures)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: pack.color, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text(feature, style: const TextStyle(fontSize: 13))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KPIs preview
          Text('المؤشّرات الأساسية المضمّنة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 800 ? 4 : 2;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 1.5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final kpi in pack.sampleKpis)
                    _kpiPreview(kpi.label, kpi.value, kpi.unit, pack.color),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Activate button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: pack.color.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: pack.color.withOpacity(0.2))),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: pack.color, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'تفعيل الباقة مجاني لعملاء APEX — سيتم تطبيق الإعدادات فوراً.\nيمكنك إلغاء التفعيل في أي وقت.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ApexV5UndoToast.show(
                      context,
                      messageAr: 'تم تفعيل باقة ${pack.nameAr} — ${pack.coaAccounts} حساب + ${pack.kpis} KPI',
                      onUndo: () {},
                    );
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: Text('فعّل الباقة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pack.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _includedCard(String title, String detail, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                Text(detail, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiPreview(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
            ],
          ),
        ],
      ),
    );
  }

  final _packs = [
    _Pack(
      id: 'fnb',
      nameAr: 'المطاعم والمقاهي (F&B)',
      nameEn: 'Food & Beverage',
      description: 'محاسبة مطاعم مع إدارة وصفات + تكلفة الصنف + نقاط البيع + تتبع الهدر',
      icon: Icons.restaurant,
      color: core_theme.AC.warn,
      customers: 47,
      rating: '⭐ 4.8/5',
      coaAccounts: 145,
      invoiceTemplates: 8,
      kpis: 24,
      reports: 18,
      workflows: 12,
      integrations: 'Foodics, Uber Eats, Marn POS',
      popular: true,
      uniqueFeatures: [
        'إدارة الوصفات (Recipe Costing) مع تكلفة كل طبق',
        'تتبع الهدر (Food Waste) بالوزن والقيمة',
        'تكامل مع أنظمة POS (Foodics/Marn)',
        'رسوم التوصيل من Uber Eats/Jahez/HungerStation',
        'إدارة المخزون بـ FIFO مع تواريخ انتهاء',
        'تقارير أداء الفرع والوجبات الأعلى مبيعاً',
      ],
      sampleKpis: [
        _KpiSample('تكلفة الطعام %', '32', '%'),
        _KpiSample('متوسط الفاتورة', '85', 'ر.س'),
        _KpiSample('الهدر اليومي', '3.2', '%'),
        _KpiSample('Food Cost Ratio', '28', '%'),
      ],
    ),
    _Pack(
      id: 'manufacturing',
      nameAr: 'التصنيع',
      nameEn: 'Manufacturing',
      description: 'Job Costing + Bills of Material + Work Orders + Machine efficiency',
      icon: Icons.precision_manufacturing,
      color: Color(0xFF1565C0),
      customers: 32,
      rating: '⭐ 4.7/5',
      coaAccounts: 210,
      invoiceTemplates: 6,
      kpis: 35,
      reports: 28,
      workflows: 18,
      integrations: 'SAP ERP, Oracle ERP, Ignition SCADA',
      popular: false,
      uniqueFeatures: [
        'قوائم المواد (BOM) متعدّدة المستويات',
        'أوامر التشغيل (Work Orders) مع Gantt',
        'Job Costing + Process Costing',
        'كفاءة الآلات (OEE: Availability × Performance × Quality)',
        'تكلفة العمالة المباشرة وغير المباشرة',
        'تتبع الإنتاج بالوقت الفعلي',
      ],
      sampleKpis: [
        _KpiSample('OEE', '78', '%'),
        _KpiSample('الهدر', '2.1', '%'),
        _KpiSample('معدّل الإنتاج', '1,240', 'وحدة/يوم'),
        _KpiSample('تكلفة الوحدة', '42.5', 'ر.س'),
      ],
    ),
    _Pack(
      id: 'healthcare',
      nameAr: 'الرعاية الصحية',
      nameEn: 'Healthcare',
      description: 'إدارة التأمين + فواتير المريض + CMS/CPT + تكلفة الخدمة',
      icon: Icons.medical_services,
      color: Color(0xFFEC4899),
      customers: 23,
      rating: '⭐ 4.9/5',
      coaAccounts: 180,
      invoiceTemplates: 12,
      kpis: 28,
      reports: 22,
      workflows: 15,
      integrations: 'NPHIES, Bupa, Tawuniya, Medgulf',
      popular: false,
      uniqueFeatures: [
        'تكامل NPHIES (المنصّة الوطنية للصحة)',
        'فوترة متعدّدة (مريض + تأمين + حكومي)',
        'تصنيف CPT و ICD-10 الطبي',
        'تتبع المطالبات والرفوضات',
        'تكاليف الأدوية والمستلزمات',
        'تقارير عقود التأمين (Bupa/Tawuniya/Medgulf)',
      ],
      sampleKpis: [
        _KpiSample('معدّل القبول', '96', '%'),
        _KpiSample('متوسط الإقامة', '3.2', 'يوم'),
        _KpiSample('هامش الخدمة', '28', '%'),
        _KpiSample('DSO تأمين', '45', 'يوم'),
      ],
    ),
    _Pack(
      id: 'logistics',
      nameAr: 'اللوجستيات',
      nameEn: 'Logistics',
      description: 'إدارة الشحنات + مسارات + تكلفة الرحلة + تتبع الأسطول',
      icon: Icons.local_shipping,
      color: core_theme.AC.ok,
      customers: 41,
      rating: '⭐ 4.6/5',
      coaAccounts: 195,
      invoiceTemplates: 10,
      kpis: 32,
      reports: 25,
      workflows: 14,
      integrations: 'Fasah, TAHAKOM, Mashroey',
      popular: true,
      uniqueFeatures: [
        'تكامل منصّة فسح (TAHAKOM)',
        'حساب تكلفة الرحلة (الوقود + سائق + صيانة)',
        'تتبع الأسطول الحيّ (GPS + سرعة)',
        'Route Optimization + ETA calculation',
        'إدارة العقود مع العملاء (per-trip / monthly)',
        'تقارير استهلاك الوقود وأداء السائقين',
      ],
      sampleKpis: [
        _KpiSample('Cost/km', '3.2', 'ر.س'),
        _KpiSample('On-time Delivery', '94', '%'),
        _KpiSample('Fleet Utilization', '82', '%'),
        _KpiSample('Fuel Efficiency', '8.5', 'l/100km'),
      ],
    ),
    _Pack(
      id: 'retail',
      nameAr: 'التجزئة',
      nameEn: 'Retail',
      description: 'POS متعدّد الفروع + إدارة SKU + عروض الترويج + تحليل السلّة',
      icon: Icons.shopping_cart,
      color: core_theme.AC.purple,
      customers: 68,
      rating: '⭐ 4.8/5',
      coaAccounts: 160,
      invoiceTemplates: 5,
      kpis: 30,
      reports: 24,
      workflows: 16,
      integrations: 'Foodics, Rewaa, Zid, Salla',
      popular: true,
      uniqueFeatures: [
        'POS متعدّد الفروع مع مزامنة فورية',
        'إدارة SKU + باركود + صور',
        'عروض ترويجية (BOGO, Bundle, %)',
        'Loyalty Program مدمج',
        'تحليل سلّة المشتريات (Basket Analysis)',
        'تكامل مع Zid/Salla (إيكوميرس)',
      ],
      sampleKpis: [
        _KpiSample('Same Store Sales', '+12.3', '%'),
        _KpiSample('متوسط المبيعة', '187', 'ر.س'),
        _KpiSample('Conversion Rate', '34', '%'),
        _KpiSample('Inventory Turnover', '6.8', 'x/yr'),
      ],
    ),
  ];
}

class _Pack {
  final String id, nameAr, nameEn, description, rating, integrations;
  final IconData icon;
  final Color color;
  final int customers, coaAccounts, invoiceTemplates, kpis, reports, workflows;
  final bool popular;
  final List<String> uniqueFeatures;
  final List<_KpiSample> sampleKpis;

  const _Pack({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    required this.icon,
    required this.color,
    required this.customers,
    required this.rating,
    required this.coaAccounts,
    required this.invoiceTemplates,
    required this.kpis,
    required this.reports,
    required this.workflows,
    required this.integrations,
    required this.popular,
    required this.uniqueFeatures,
    required this.sampleKpis,
  });
}

class _KpiSample {
  final String label, value, unit;
  const _KpiSample(this.label, this.value, this.unit);
}

/// Wave 34 — Help Center.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hero search
        Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [core_theme.AC.info, core_theme.AC.purple]),
          ),
          child: Column(
            children: [
              const Icon(Icons.help_center, color: Colors.white, size: 48),
              const SizedBox(height: 12),
              Text('مركز المساعدة', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('كيف يمكننا مساعدتك؟', style: TextStyle(color: core_theme.AC.ts, fontSize: 14)),
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxWidth: 600),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث عن دليل، فيديو، سؤال شائع...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in ['بدء الاستخدام', 'ZATCA', 'الفواتير', 'الرواتب', 'المراجعة', 'الذكاء'])
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                      child: Text(s, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Tabs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: core_theme.AC.tp.withOpacity(0.08)))),
          child: Row(
            children: [
              _tabBtn(0, 'الأدلّة', Icons.menu_book),
              _tabBtn(1, 'الفيديوهات', Icons.play_circle),
              _tabBtn(2, 'الأسئلة الشائعة', Icons.question_answer),
              _tabBtn(3, 'الاختصارات', Icons.keyboard),
              _tabBtn(4, 'تواصل معنا', Icons.support_agent),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? core_theme.AC.info : Colors.transparent, width: 2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? core_theme.AC.info : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? core_theme.AC.info : core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _guides();
      case 1: return _videos();
      case 2: return _faq();
      case 3: return _shortcuts();
      case 4: return _contact();
      default: return const SizedBox();
    }
  }

  Widget _guides() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
          return GridView.count(
            shrinkWrap: true,
            crossAxisCount: cols,
            childAspectRatio: 1.8,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _guideCard('بدء الاستخدام', 'كيف تبدأ مع APEX في 10 دقائق', Icons.rocket_launch, core_theme.AC.gold, 'المبتدئون · 8 دقائق'),
              _guideCard('إعداد ZATCA', 'دليل CSID + أول فاتورة إلكترونية', Icons.receipt, const Color(0xFF2E7D5B), 'ZATCA · 15 دقيقة'),
              _guideCard('ربط البنك', 'Lean/Tarabut — مزامنة تلقائية', Icons.account_balance, core_theme.AC.info, 'البنوك · 5 دقائق'),
              _guideCard('إدارة الرواتب', 'GOSI + WPS + EOSB', Icons.payments, core_theme.AC.purple, 'HR · 20 دقيقة'),
              _guideCard('المطابقة بالذكاء', 'Bank Reconciliation AI', Icons.compare_arrows, core_theme.AC.gold, 'AI · 10 دقائق'),
              _guideCard('بناء التقارير', 'مُنشئ التقارير المخصّصة', Icons.bar_chart, const Color(0xFFEC4899), 'التقارير · 12 دقيقة'),
            ],
          );
        },
      ),
    );
  }

  Widget _guideCard(String title, String desc, IconData icon, Color color, String meta) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          const Spacer(),
          Row(
            children: [
              Text(meta, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              const Spacer(),
              Icon(Icons.arrow_back, color: color, size: 14),
            ],
          ),
        ],
      ),
    );
  }

  Widget _videos() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
          return GridView.count(
            shrinkWrap: true,
            crossAxisCount: cols,
            childAspectRatio: 1.3,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final v in [
                ('جولة في APEX', '3:45', core_theme.AC.info),
                ('إصدار فاتورة ZATCA', '4:20', const Color(0xFF2E7D5B)),
                ('AI Bank Reconciliation', '5:15', core_theme.AC.gold),
                ('إعداد الموظفين', '6:30', core_theme.AC.purple),
                ('مراجعة وضوابط الاعتماد', '4:50', const Color(0xFFB91C1C)),
                ('تخصيص المنصّة (Studio)', '8:10', const Color(0xFFEC4899)),
              ])
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(color: v.$3, borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            Text(v.$2, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _faq() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final q in [
            ('كيف أُفعّل شهادة زاتكا؟', 'من /app/compliance/zatca/csid اختر "إصدار جديد" واتبع الإرشادات. تستغرق العملية 5-10 دقائق.'),
            ('هل APEX يدعم العملات المتعدّدة؟', 'نعم، يدعم SAR + AED + BHD + OMR + QAR + KWD + USD + EUR مع تحويل FX تلقائي.'),
            ('ما الفرق بين الرأي النظيف والمتحفّظ؟', 'الرأي النظيف: القوائم عادلة من جميع النواحي. المتحفّظ: باستثناء نقاط محدّدة.'),
            ('كيف يعمل AI Guardrails؟', 'كل اقتراح AI يمرّ بقاعدة — لو الثقة < 95% يُرسل للمراجعة. غير ذلك يُنفَّذ مباشرة.'),
            ('هل بياناتي آمنة؟', 'نعم — Hash-chain audit trail + Row-Level Security + Fernet encryption + ISO 27001 compliant.'),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
              child: ExpansionTile(
                title: Text(q.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(q.$2, style: const TextStyle(fontSize: 12, height: 1.6)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _shortcuts() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اختصارات لوحة المفاتيح', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _shortcutGroup('التنقّل', [
            ('Ctrl+K', 'Command Palette — بحث عالمي'),
            ('Ctrl+Shift+K', 'مبدّل الخدمات'),
            ('Alt+1', 'انتقل إلى ERP'),
            ('Alt+2', 'انتقل إلى Compliance'),
            ('Alt+3', 'انتقل إلى Audit'),
            ('Alt+4', 'انتقل إلى Advisory'),
            ('Alt+5', 'انتقل إلى Marketplace'),
          ]),
          _shortcutGroup('العمليات', [
            ('Ctrl+Z', 'تراجع آخر عملية'),
            ('Ctrl+Shift+Z', 'إعادة'),
            ('Ctrl+S', 'حفظ'),
            ('Ctrl+N', 'عنصر جديد (حسب السياق)'),
            ('Ctrl+F', 'بحث في الصفحة الحالية'),
          ]),
          _shortcutGroup('العامة', [
            ('?', 'عرض مساعدة الاختصارات'),
            ('Escape', 'إغلاق حوار/نافذة'),
            ('/', 'تركيز البحث'),
          ]),
        ],
      ),
    );
  }

  Widget _shortcutGroup(String title, List<(String, String)> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: core_theme.AC.info)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(border: i < items.length - 1 ? Border(bottom: BorderSide(color: core_theme.AC.tp.withOpacity(0.04))) : null),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4), border: Border.all(color: core_theme.AC.tp.withOpacity(0.1))),
                          child: Text(items[i].$1, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Text(items[i].$2, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contact() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final cols = constraints.maxWidth > 700 ? 3 : 1;
          return GridView.count(
            shrinkWrap: true,
            crossAxisCount: cols,
            childAspectRatio: 1.5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _contactCard('دردشة مباشرة', 'متاحة 24/7 باللغة العربية', Icons.chat, core_theme.AC.info, '<1 دقيقة'),
              _contactCard('البريد الإلكتروني', 'support@apex-financial.com', Icons.email, core_theme.AC.purple, '<2 ساعة'),
              _contactCard('WhatsApp', '+966 11 xxx xxxx', Icons.phone_android, core_theme.AC.ok, '<15 دقيقة'),
              _contactCard('اتصال هاتفي', 'عملاء Enterprise فقط', Icons.phone, core_theme.AC.warn, 'مباشر'),
              _contactCard('الأكاديمية', 'دورات مجانية + شهادات', Icons.school, const Color(0xFFEC4899), 'ذاتي'),
              _contactCard('المجتمع', 'منتدى المستخدمين', Icons.forum, core_theme.AC.gold, 'مجتمعي'),
            ],
          );
        },
      ),
    );
  }

  Widget _contactCard(String title, String detail, IconData icon, Color color, String sla) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withOpacity(0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          Text(detail, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const Spacer(),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)), child: Text('زمن الاستجابة: $sla', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
        ],
      ),
    );
  }
}
