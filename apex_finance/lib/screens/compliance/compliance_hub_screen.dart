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
