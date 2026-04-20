/// Pilot Shell — نقطة دخول العميل الفعلي للمنصّة.
/// ═════════════════════════════════════════════════════════════
/// يعرض اختيار tenant + entity + branch في الأعلى، ثم tabs للأقسام
/// الأساسية: Dashboard / POS / Products / Reports / Compliance.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/pilot_session_provider.dart';
import 'pilot_dashboard_screen.dart';
import 'pilot_pos_screen.dart';
import 'pilot_products_screen.dart';
import 'pilot_reports_screen.dart';
import 'pilot_compliance_screen.dart';
import 'pilot_context_picker.dart';

class PilotShellScreen extends ConsumerStatefulWidget {
  const PilotShellScreen({super.key});
  @override
  ConsumerState<PilotShellScreen> createState() => _PilotShellScreenState();
}

class _PilotShellScreenState extends ConsumerState<PilotShellScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(pilotSessionProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: Row(children: [
            Icon(Icons.storefront, color: AC.gold),
            const SizedBox(width: 8),
            Text('APEX Pilot — منصّة التجزئة',
                style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
          ]),
          actions: [
            TextButton.icon(
              onPressed: () => _openPicker(context),
              icon: Icon(Icons.business, color: AC.gold),
              label: Text(
                selection.hasTenant
                    ? '${selection.tenantNameAr ?? selection.tenantSlug ?? "المستأجر"}${selection.hasEntity ? " / ${selection.entityCode}" : ""}${selection.hasBranch ? " / ${selection.branchCode}" : ""}'
                    : 'اختر مستأجراً',
                style: TextStyle(color: AC.tp),
              ),
            ),
            const SizedBox(width: 12),
          ],
          bottom: TabBar(
            controller: _tabs,
            isScrollable: true,
            indicatorColor: AC.gold,
            labelColor: AC.gold,
            unselectedLabelColor: AC.ts,
            tabs: const [
              Tab(icon: Icon(Icons.dashboard), text: 'اللوحة'),
              Tab(icon: Icon(Icons.point_of_sale), text: 'نقطة البيع'),
              Tab(icon: Icon(Icons.inventory_2), text: 'المنتجات'),
              Tab(icon: Icon(Icons.assessment), text: 'التقارير'),
              Tab(icon: Icon(Icons.verified_user), text: 'الامتثال'),
            ],
          ),
        ),
        body: selection.hasTenant
            ? TabBarView(
                controller: _tabs,
                children: const [
                  PilotDashboardScreen(),
                  PilotPosScreen(),
                  PilotProductsScreen(),
                  PilotReportsScreen(),
                  PilotComplianceScreen(),
                ],
              )
            : _emptyState(),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 96, color: AC.td),
            const SizedBox(height: 16),
            Text('لم يتم اختيار مستأجر بعد',
                style: TextStyle(color: AC.tp, fontSize: 20)),
            const SizedBox(height: 8),
            Text('انقر على "اختر مستأجراً" في الأعلى للبدء.',
                style: TextStyle(color: AC.ts)),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.btnFg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: () => _openPicker(context),
              icon: const Icon(Icons.business),
              label: const Text('اختر مستأجراً'),
            ),
          ],
        ),
      );

  void _openPicker(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => const Dialog(child: PilotContextPicker()),
    );
  }
}
