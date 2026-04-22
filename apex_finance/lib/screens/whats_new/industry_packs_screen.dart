/// Industry Packs Picker — shows all 5 packs with COA preview + widgets.
///
/// Mirrors the Python registry in app/industry_packs/registry.py so the
/// user can see them visually without a backend call.
library;

import 'package:flutter/material.dart';

import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class IndustryPacksScreen extends StatefulWidget {
  const IndustryPacksScreen({super.key});

  @override
  State<IndustryPacksScreen> createState() => _IndustryPacksScreenState();
}

class _IndustryPacksScreenState extends State<IndustryPacksScreen> {
  String _selected = 'fnb_retail';

  static final Map<String, _Pack> _packs = {
    'fnb_retail': _Pack(
      id: 'fnb_retail',
      nameAr: 'المطاعم والتجزئة',
      nameEn: 'F&B and Retail',
      icon: Icons.restaurant_menu,
      description: 'POS-integrated COA with tip pooling and delivery platform fees.',
      accounts: [
        ('1100', 'الصندوق الرئيسي', 'asset'),
        ('1110', 'نقدية Mada', 'asset'),
        ('1200', 'مخزون أطعمة', 'asset'),
        ('4100', 'مبيعات طعام', 'revenue'),
        ('4300', 'خدمة التوصيل', 'revenue'),
        ('5300', 'عمولة منصات التوصيل', 'expense'),
        ('5400', 'رواتب المطبخ', 'expense'),
        ('2300', 'الإكراميات المستحقة', 'liability'),
      ],
      widgets: [
        ('مبيعات اليوم', 'kpi', Icons.today),
        ('أفضل الأصناف مبيعاً', 'table', Icons.star),
        ('نسبة تكلفة الطعام', 'kpi', Icons.pie_chart),
        ('رصيد الإكراميات', 'kpi', Icons.attach_money),
        ('توزيع المنصات', 'chart', Icons.donut_large),
      ],
    ),
    'construction': _Pack(
      id: 'construction',
      nameAr: 'المقاولات',
      nameEn: 'Construction',
      icon: Icons.construction,
      description: 'Project-based accounting with WIP, retention, and progress billing.',
      accounts: [
        ('1250', 'أعمال تحت التنفيذ', 'asset'),
        ('1260', 'محتجزات العملاء', 'asset'),
        ('2250', 'محتجزات الموردين', 'liability'),
        ('4500', 'إيرادات العقود', 'revenue'),
        ('4510', 'أوامر التغيير', 'revenue'),
        ('5500', 'تكلفة المواد', 'expense'),
        ('5510', 'تكلفة العمالة', 'expense'),
        ('5520', 'مقاولون من الباطن', 'expense'),
      ],
      widgets: [
        ('المشاريع النشطة', 'kpi', Icons.work),
        ('ملخص WIP', 'table', Icons.engineering),
        ('محتجزات معلقة', 'kpi', Icons.account_balance),
        ('هامش كل مشروع', 'chart', Icons.percent),
      ],
    ),
    'medical': _Pack(
      id: 'medical',
      nameAr: 'العيادات والمستشفيات',
      nameEn: 'Medical',
      icon: Icons.medical_services,
      description: 'Patient billing with insurance claim tracking and medical inventory.',
      accounts: [
        ('1300', 'ذمم تأمين طبي', 'asset'),
        ('1310', 'مطالبات معلقة', 'asset'),
        ('4600', 'إيرادات الاستشارات', 'revenue'),
        ('4610', 'إيرادات العمليات', 'revenue'),
        ('4620', 'إيرادات الأدوية', 'revenue'),
        ('4630', 'إيرادات المختبر', 'revenue'),
        ('5600', 'مستلزمات طبية', 'expense'),
        ('5610', 'رواتب الأطباء', 'expense'),
      ],
      widgets: [
        ('عدد المرضى اليوم', 'kpi', Icons.people),
        ('مطالبات معلقة', 'kpi', Icons.description),
        ('تقادم ذمم التأمين', 'chart', Icons.av_timer),
        ('مزيج الإيرادات', 'chart', Icons.pie_chart),
      ],
    ),
    'logistics': _Pack(
      id: 'logistics',
      nameAr: 'النقل واللوجستيات',
      nameEn: 'Logistics',
      icon: Icons.local_shipping,
      description: 'Fleet cost tracking, driver settlements, and fuel-card reconciliation.',
      accounts: [
        ('1400', 'مركبات أسطول', 'asset'),
        ('1410', 'بطاقات الوقود', 'asset'),
        ('2400', 'ذمم السائقين', 'liability'),
        ('4700', 'إيرادات نقل البضائع', 'revenue'),
        ('5700', 'وقود وزيوت', 'expense'),
        ('5710', 'صيانة الأسطول', 'expense'),
        ('5720', 'رسوم الطرق', 'expense'),
        ('5730', 'رواتب السائقين', 'expense'),
      ],
      widgets: [
        ('الأسطول النشط', 'kpi', Icons.directions_car),
        ('إنفاق الوقود', 'kpi', Icons.local_gas_station),
        ('ذمم السائقين', 'table', Icons.person),
        ('استغلال الأسطول', 'chart', Icons.speed),
      ],
    ),
    'services': _Pack(
      id: 'services',
      nameAr: 'الخدمات والاستشارات',
      nameEn: 'Services / SaaS',
      icon: Icons.psychology_outlined,
      description: 'Professional services + SaaS metrics (MRR / burn / runway).',
      accounts: [
        ('4800', 'إيرادات استشارات', 'revenue'),
        ('4810', 'إيرادات اشتراكات (MRR)', 'revenue'),
        ('4820', 'إيرادات المشاريع', 'revenue'),
        ('5800', 'رواتب فريق المنتج', 'expense'),
        ('5810', 'رواتب المبيعات', 'expense'),
        ('5820', 'أدوات SaaS', 'expense'),
      ],
      widgets: [
        ('الإيراد المتكرر', 'kpi', Icons.autorenew),
        ('معدل الحرق', 'kpi', Icons.local_fire_department),
        ('المدى بالأشهر', 'kpi', Icons.timer),
        ('عملاء نشطون', 'kpi', Icons.people),
      ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final pack = _packs[_selected]!;
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: 'حزم الصناعات — Industry Packs'),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sidebar(),
                const VerticalDivider(width: 1),
                Expanded(child: _detail(pack)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 260,
      color: AC.navy2,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: _packs.values
            .map(
              (p) => InkWell(
                onTap: () => setState(() => _selected = p.id),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _selected == p.id
                        ? AC.gold.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: _selected == p.id ? AC.gold : AC.navy4,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(p.icon,
                          color: _selected == p.id ? AC.gold : AC.ts, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nameAr,
                                style: TextStyle(
                                    color: AC.tp,
                                    fontWeight: FontWeight.w600)),
                            Text(p.nameEn,
                                style: TextStyle(
                                    color: AC.td,
                                    fontSize: AppFontSize.sm)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _detail(_Pack p) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AC.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(p.icon, color: AC.gold, size: 32),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.nameAr,
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: AppFontSize.h2,
                            fontWeight: FontWeight.w700)),
                    Text(p.description,
                        style: TextStyle(color: AC.ts)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('تركيب الحزمة'),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('سيتم تركيب ${p.nameAr} (demo)'),
                      backgroundColor: AC.ok,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('دليل الحسابات (${p.accounts.length} حساب)',
              style: TextStyle(
                  color: AC.gold,
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          _coaTable(p.accounts),
          const SizedBox(height: AppSpacing.xxl),
          Text('Dashboard Widgets (${p.widgets.length})',
              style: TextStyle(
                  color: AC.gold,
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.md),
          _widgetsGrid(p.widgets),
        ],
      ),
    );
  }

  Widget _coaTable(List<(String, String, String)> accounts) {
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.navy4),
      ),
      child: Column(
        children: accounts.map((row) {
          final (code, name, type) = row;
          final typeColor = {
            'asset': AC.ok,
            'liability': AC.warn,
            'equity': AC.cyan,
            'revenue': AC.gold,
            'expense': AC.err,
          }[type] ?? AC.td;
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AC.navy4.withValues(alpha: 0.4))),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    code,
                    style: TextStyle(
                      color: AC.td,
                      fontFamily: 'monospace',
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(name, style: TextStyle(color: AC.tp)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(type,
                      style: TextStyle(
                          color: typeColor, fontSize: AppFontSize.sm)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _widgetsGrid(List<(String, String, IconData)> widgets) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: widgets.map((w) {
        final (title, kind, icon) = w;
        return Container(
          width: 220,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AC.navy4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AC.gold),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AC.cyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(kind,
                        style:
                            TextStyle(color: AC.cyan, fontSize: AppFontSize.xs)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title,
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Pack {
  final String id;
  final String nameAr;
  final String nameEn;
  final IconData icon;
  final String description;
  final List<(String, String, String)> accounts;
  final List<(String, String, IconData)> widgets;

  const _Pack({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.icon,
    required this.description,
    required this.accounts,
    required this.widgets,
  });
}
