/// APEX Platform — Compliance Hub
/// ═══════════════════════════════════════════════════════════════
/// Single entry point for all ZATCA / IFRS / SOCPA compliance tools.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class ComplianceHubScreen extends StatefulWidget {
  const ComplianceHubScreen({super.key});
  @override
  State<ComplianceHubScreen> createState() => _ComplianceHubScreenState();
}

class _ComplianceHubScreenState extends State<ComplianceHubScreen> {
  bool? _chainOk;
  int? _verified;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshChain();
  }

  Future<void> _refreshChain() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.auditVerify(limit: 100);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        final d = (r.data['data'] ?? r.data) as Map<String, dynamic>;
        setState(() {
          _chainOk = d['ok'] == true;
          _verified = d['verified'] as int?;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: Text('مركز الامتثال (ZATCA / IFRS / SOCPA)',
          style: TextStyle(color: AC.gold)),
        backgroundColor: AC.navy2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AC.gold),
            onPressed: _loading ? null : _refreshChain,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusBar(),
            const SizedBox(height: 20),
            _sectionTitle('أدوات الامتثال'),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (ctx, cons) {
              final cols = cons.maxWidth > 900 ? 3 : (cons.maxWidth > 540 ? 2 : 1);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _toolCard(
                    icon: Icons.receipt_long,
                    title: 'منشئ الفاتورة',
                    subtitle: 'ZATCA Phase 2 + QR',
                    color: AC.gold,
                    onTap: () => context.go('/compliance/zatca-invoice'),
                  ),
                  _toolCard(
                    icon: Icons.savings,
                    title: 'حاسبة الزكاة',
                    subtitle: 'قاعدة الزكاة × 2.5%',
                    color: AC.ok,
                    onTap: () => context.go('/compliance/zakat'),
                  ),
                  _toolCard(
                    icon: Icons.receipt,
                    title: 'إقرار VAT',
                    subtitle: 'KSA 15% · UAE 5%',
                    color: AC.warn,
                    onTap: () => context.go('/compliance/vat-return'),
                  ),
                  _toolCard(
                    icon: Icons.confirmation_number,
                    title: 'أرقام القيود',
                    subtitle: 'ترقيم متسلسل بدون فجوات',
                    color: AC.info,
                    onTap: () => context.go('/compliance/journal-entries'),
                  ),
                  _toolCard(
                    icon: Icons.lock_outline,
                    title: 'سجل التدقيق',
                    subtitle: 'hash chain + integrity',
                    color: AC.purple,
                    onTap: () => context.go('/compliance/audit-trail'),
                  ),
                  _toolCard(
                    icon: Icons.analytics,
                    title: 'المؤشرات المالية',
                    subtitle: '18 مؤشر في 5 فئات',
                    color: AC.info,
                    onTap: () => context.go('/compliance/ratios'),
                  ),
                  _toolCard(
                    icon: Icons.auto_graph,
                    title: 'الإهلاك',
                    subtitle: 'SL · DDB · SYD',
                    color: AC.warn,
                    onTap: () => context.go('/compliance/depreciation'),
                  ),
                  _toolCard(
                    icon: Icons.water_drop,
                    title: 'التدفقات النقدية',
                    subtitle: 'تشغيلية · استثمارية · تمويلية',
                    color: AC.info,
                    onTap: () => context.go('/compliance/cashflow'),
                  ),
                  _toolCard(
                    icon: Icons.schedule,
                    title: 'أقساط القرض',
                    subtitle: 'جدول السداد الكامل',
                    color: AC.ok,
                    onTap: () => context.go('/compliance/amortization'),
                  ),
                  _toolCard(
                    icon: Icons.badge,
                    title: 'الرواتب + GOSI',
                    subtitle: 'حساب الراتب الصافي + التأمينات',
                    color: AC.purple,
                    onTap: () => context.go('/compliance/payroll'),
                  ),
                  _toolCard(
                    icon: Icons.balance,
                    title: 'نقطة التعادل',
                    subtitle: 'تحليل هامش المساهمة',
                    color: AC.gold,
                    onTap: () => context.go('/compliance/breakeven'),
                  ),
                  _toolCard(
                    icon: Icons.insights,
                    title: 'تقييم الاستثمار',
                    subtitle: 'NPV · IRR · Payback',
                    color: AC.info,
                    onTap: () => context.go('/compliance/investment'),
                  ),
                  _toolCard(
                    icon: Icons.compare_arrows,
                    title: 'الميزانية مقابل الفعلي',
                    subtitle: 'تحليل الانحرافات',
                    color: AC.warn,
                    onTap: () => context.go('/compliance/budget-variance'),
                  ),
                  _toolCard(
                    icon: Icons.account_balance,
                    title: 'التسوية البنكية',
                    subtitle: 'مطابقة الدفاتر بكشف البنك',
                    color: AC.info,
                    onTap: () => context.go('/compliance/bank-rec'),
                  ),
                  _toolCard(
                    icon: Icons.inventory_2,
                    title: 'تقييم المخزون',
                    subtitle: 'FIFO · LIFO · WAC',
                    color: AC.ok,
                    onTap: () => context.go('/compliance/inventory'),
                  ),
                  _toolCard(
                    icon: Icons.bar_chart,
                    title: 'تقرير الأعمار',
                    subtitle: 'AR/AP + ECL',
                    color: AC.err,
                    onTap: () => context.go('/compliance/aging'),
                  ),
                  _toolCard(
                    icon: Icons.sync,
                    title: 'رأس المال العامل',
                    subtitle: 'DSO · DIO · DPO · CCC',
                    color: AC.gold,
                    onTap: () => context.go('/compliance/working-capital'),
                  ),
                  _toolCard(
                    icon: Icons.speed,
                    title: 'مؤشر الصحة المالية',
                    subtitle: 'درجة مركّبة A-F',
                    color: AC.info,
                    onTap: () => context.go('/compliance/health-score'),
                  ),
                  _toolCard(
                    icon: Icons.document_scanner,
                    title: 'OCR الفواتير',
                    subtitle: 'استخراج الحقول تلقائياً',
                    color: AC.purple,
                    onTap: () => context.go('/compliance/ocr'),
                  ),
                  _toolCard(
                    icon: Icons.dashboard_customize,
                    title: 'لوحة CFO التنفيذية',
                    subtitle: 'كل الأدوات في مكان واحد',
                    color: AC.gold,
                    onTap: () => context.go('/compliance/executive'),
                  ),
                  _toolCard(
                    icon: Icons.account_balance,
                    title: 'تغطية خدمة الدين',
                    subtitle: 'DSCR + قدرة الاقتراض',
                    color: AC.ok,
                    onTap: () => context.go('/compliance/dscr'),
                  ),
                  _toolCard(
                    icon: Icons.query_stats,
                    title: 'تقييم الأعمال',
                    subtitle: 'WACC + DCF',
                    color: AC.info,
                    onTap: () => context.go('/compliance/valuation'),
                  ),
                  _toolCard(
                    icon: Icons.edit_note,
                    title: 'بنّاء القيود',
                    subtitle: 'قيود متوازنة + 10 قوالب',
                    color: AC.purple,
                    onTap: () => context.go('/compliance/journal-entry-builder'),
                  ),
                  _toolCard(
                    icon: Icons.swap_horiz,
                    title: 'محوّل العملات',
                    subtitle: 'FX + IAS 21 revaluation',
                    color: AC.gold,
                    onTap: () => context.go('/compliance/fx-converter'),
                  ),
                  _toolCard(
                    icon: Icons.analytics_outlined,
                    title: 'انحرافات التكاليف',
                    subtitle: 'Material · Labour · Overhead',
                    color: AC.warn,
                    onTap: () => context.go('/compliance/cost-variance'),
                  ),
                  _toolCard(
                    icon: Icons.auto_graph,
                    title: 'القوائم المالية',
                    subtitle: 'TB · IS · BS · Closing',
                    color: AC.ok,
                    onTap: () => context.go('/compliance/financial-statements'),
                  ),
                  _toolCard(
                    icon: Icons.water_drop,
                    title: 'قائمة التدفقات',
                    subtitle: 'IAS 7 · CFO · CFI · CFF',
                    color: AC.info,
                    onTap: () => context.go('/compliance/cashflow-statement'),
                  ),
                  _toolCard(
                    icon: Icons.gavel,
                    title: 'ضريبة الاستقطاع',
                    subtitle: 'WHT KSA · 5-20% حسب الفئة',
                    color: AC.err,
                    onTap: () => context.go('/compliance/wht'),
                  ),
                  _toolCard(
                    icon: Icons.merge_type,
                    title: 'القوائم الموحّدة',
                    subtitle: 'IFRS 10 · NCI + Interco',
                    color: AC.purple,
                    onTap: () => context.go('/compliance/consolidation'),
                  ),
                  _toolCard(
                    icon: Icons.schedule_send,
                    title: 'الضرائب المؤجّلة',
                    subtitle: 'IAS 12 · DTA/DTL',
                    color: AC.info,
                    onTap: () => context.go('/compliance/deferred-tax'),
                  ),
                  _toolCard(
                    icon: Icons.timeline,
                    title: 'محاسبة الإيجار',
                    subtitle: 'IFRS 16 · ROU + Liability',
                    color: AC.ok,
                    onTap: () => context.go('/compliance/lease'),
                  ),
                  _toolCard(
                    icon: Icons.style,
                    title: 'أدوات IFRS',
                    subtitle: 'Revenue·EOSB·Impair·ECL·Provisions',
                    color: AC.purple,
                    onTap: () => context.go('/compliance/ifrs-tools'),
                  ),
                  _toolCard(
                    icon: Icons.inventory,
                    title: 'سجل الأصول الثابتة',
                    subtitle: 'Lifecycle · Dep · Reval · Dispose',
                    color: AC.info,
                    onTap: () => context.go('/compliance/fixed-assets'),
                  ),
                  _toolCard(
                    icon: Icons.compare,
                    title: 'تسعير التحويل',
                    subtitle: 'BEPS 13 · KSA TP · CbCR',
                    color: AC.warn,
                    onTap: () => context.go('/compliance/transfer-pricing'),
                  ),
                ],
              );
            }),
            const SizedBox(height: 24),
            _sectionTitle('المرجعيات'),
            const SizedBox(height: 8),
            _refsCard(),
          ],
        ),
      ),
    );
  }

  Widget _statusBar() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.bdr),
        ),
        child: Row(children: [
          const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text('فحص سلامة سلسلة التدقيق...',
            style: TextStyle(color: AC.ts, fontSize: 13)),
        ]),
      );
    }
    final ok = _chainOk == true;
    final color = ok ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Icon(ok ? Icons.verified : Icons.warning_amber_rounded,
          color: color, size: 30),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ok ? 'النظام متكامل ✓' : 'انكسار في السلسلة',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              ok
                ? 'سلسلة التدقيق سليمة — تم التحقق من ${_verified ?? 0} حدث'
                : 'تحقق من شاشة سجل التدقيق لعرض التفاصيل',
              style: TextStyle(color: AC.tp, fontSize: 12),
            ),
          ],
        )),
      ]),
    );
  }

  Widget _sectionTitle(String t) => Row(children: [
    Container(width: 4, height: 22, decoration: BoxDecoration(
      color: AC.gold, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 10),
    Text(t, style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.w800)),
  ]);

  Widget _toolCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(
            color: AC.tp, fontSize: 15, fontWeight: FontWeight.w700)),
          Text(subtitle, style: TextStyle(
            color: AC.ts, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );

  Widget _refsCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _refRow('ZATCA Phase 2', 'v5 — E-invoicing specs'),
        _refRow('UBL 2.1', 'OASIS Invoice schema'),
        _refRow('VAT', '15% الرياض / 5% الإمارات'),
        _refRow('IFRS / SOCPA', 'معايير المحاسبة السعودية'),
      ],
    ),
  );

  Widget _refRow(String title, String sub) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Icon(Icons.check_circle_outline, color: AC.ok, size: 16),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(
        color: AC.tp, fontWeight: FontWeight.w600, fontSize: 13)),
      const SizedBox(width: 8),
      Text('— $sub', style: TextStyle(color: AC.ts, fontSize: 12)),
    ]),
  );
}
