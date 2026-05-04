/// APEX Platform — Compliance Health Widget
/// ═══════════════════════════════════════════════════════════════
/// Drop-in card for the main dashboard that surfaces the current
/// compliance posture at a glance:
///   • audit chain status (healthy / broken)
///   • number of events verified
///   • quick links to all 7 compliance tools
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class ComplianceHealthWidget extends StatefulWidget {
  const ComplianceHealthWidget({super.key});
  @override
  State<ComplianceHealthWidget> createState() => _ComplianceHealthWidgetState();
}

class _ComplianceHealthWidgetState extends State<ComplianceHealthWidget> {
  bool? _chainOk;
  int? _verified;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
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
      } else {
        setState(() { _chainOk = null; _verified = null; });
      }
    } catch (_) {
      if (mounted) setState(() { _chainOk = null; _verified = null; });
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 12),
          _statusRow(),
          const SizedBox(height: 14),
          _quickLinks(),
        ],
      ),
    );
  }

  Widget _header() => Row(children: [
    Icon(Icons.shield_outlined, color: AC.gold, size: 22),
    const SizedBox(width: 8),
    Text('مركز الامتثال',
      style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.w800)),
    const Spacer(),
    IconButton(
      icon: Icon(Icons.refresh, color: AC.ts, size: 18),
      tooltip: 'تحديث',
      onPressed: _loading ? null : _refresh,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    ),
    TextButton(
      onPressed: () => context.go('/compliance'),
      child: Text('عرض الكل', style: TextStyle(color: AC.gold, fontSize: 12)),
    ),
  ]);

  Widget _statusRow() {
    if (_loading) {
      return Row(children: [
        const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 10),
        Text('فحص سلامة السلسلة...',
          style: TextStyle(color: AC.ts, fontSize: 13)),
      ]);
    }
    if (_chainOk == null) {
      return Row(children: [
        Icon(Icons.cloud_off, color: AC.ts, size: 18),
        const SizedBox(width: 8),
        Text('تعذر الاتصال',
          style: TextStyle(color: AC.ts, fontSize: 13)),
      ]);
    }
    final ok = _chainOk == true;
    final color = ok ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(ok ? Icons.verified : Icons.warning_amber_rounded, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ok ? 'السلسلة سليمة' : 'انكسار في السلسلة',
            style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(ok
              ? 'تم التحقق من ${_verified ?? 0} حدث — كل شيء يعمل'
              : 'توجد عملية تدقيق مطلوبة',
            style: TextStyle(color: AC.tp, fontSize: 11)),
        ])),
      ]),
    );
  }

  Widget _quickLinks() {
    final tools = [
      ('/app/compliance/zatca/invoice', Icons.receipt_long, 'فاتورة ZATCA', AC.gold),
      ('/app/compliance/tax/zakat',         Icons.savings,      'الزكاة',       AC.ok),
      ('/app/compliance/tax/vat-return',    Icons.receipt,      'إقرار VAT',    AC.warn),
      ('/app/advisory/ratios/dashboard',        Icons.analytics,    'المؤشرات',     AC.info),
      ('/app/erp/finance/cashflow',      Icons.water_drop,   'التدفقات',     AC.info),
      ('/app/erp/finance/amortization',  Icons.schedule,     'الأقساط',      AC.ok),
      ('/app/erp/hr/payroll',       Icons.badge,        'الرواتب',      AC.purple),
      ('/app/advisory/ratios/breakeven',     Icons.balance,      'نقطة التعادل', AC.gold),
      ('/app/advisory/valuation/investment',    Icons.insights,     'NPV/IRR',      AC.info),
      ('/app/erp/finance/budget-actual', Icons.compare_arrows, 'الميزانية',  AC.warn),
      ('/app/erp/treasury/recon',      Icons.account_balance, 'التسوية',    AC.info),
      ('/app/erp/inventory/inventory',     Icons.inventory_2,  'المخزون',      AC.ok),
      ('/compliance/aging',         Icons.bar_chart,    'الأعمار',      AC.err),
      ('/app/advisory/ratios/working-capital', Icons.sync,       'WC + CCC',     AC.gold),
      ('/app/erp/finance/health-score',  Icons.speed,        'الصحة المالية', AC.info),
      ('/app/erp/finance/receipt-capture',           Icons.document_scanner, 'OCR',        AC.purple),
      ('/app/advisory/ratios/dscr',          Icons.account_balance, 'DSCR',        AC.ok),
      ('/app/advisory/valuation/dashboard',     Icons.query_stats,  'DCF',            AC.info),
      ('/compliance/executive',     Icons.dashboard_customize, 'CFO Dashboard', AC.gold),
      ('/app/erp/finance/je-builder', Icons.confirmation_number, 'القيود', AC.purple),
      ('/app/erp/finance/depreciation',  Icons.auto_graph,   'الإهلاك',      AC.warn),
      ('/app/audit/trail',   Icons.lock_outline, 'سجل التدقيق',  AC.purple),
      ('/app/erp/finance/je-builder/new', Icons.edit_note, 'بنّاء القيود', AC.purple),
      ('/app/erp/treasury/fx-converter',  Icons.swap_horiz,   'FX',             AC.gold),
      ('/app/erp/finance/dashboard', Icons.analytics_outlined, 'الانحرافات', AC.warn),
      ('/app/erp/finance/statements', Icons.auto_graph, 'القوائم المالية', AC.ok),
      ('/app/erp/finance/cashflow', Icons.water_drop, 'CFS', AC.info),
      ('/app/compliance/tax/wht',            Icons.gavel,        'WHT',            AC.err),
      ('/app/erp/consolidation/dashboard',  Icons.merge_type,   'التوحيد',         AC.purple),
      ('/app/compliance/ifrs/deferred-tax',   Icons.schedule_send, 'DT',             AC.info),
      ('/app/compliance/ifrs/dashboard',          Icons.timeline,     'Lease',           AC.ok),
      ('/app/compliance/ifrs/tools',     Icons.style,        'IFRS',            AC.purple),
      ('/app/erp/finance/fixed-assets',   Icons.inventory,    'FA',              AC.info),
      ('/app/compliance/tax/tp', Icons.compare,    'TP',              AC.warn),
      ('/app/compliance/ifrs/extras',     Icons.all_inclusive, 'Extras',        AC.gold),
    ];

    return Wrap(
      spacing: 8, runSpacing: 8,
      children: tools.map((t) => _toolChip(t.$1, t.$2, t.$3, t.$4)).toList(),
    );
  }

  Widget _toolChip(String route, IconData icon, String label, Color color) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.go(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
