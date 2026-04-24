/// APEX — "+ جديد" omni-create FAB
/// ═══════════════════════════════════════════════════════════
/// Universal "new" button modeled on QuickBooks' "+ New" omni-create.
/// One press, pick what to create — invoice, journal entry, client,
/// expense, payment, bill. Each item navigates to the correct route.
///
/// Drop `ApexOmniCreateFab()` anywhere in `Scaffold.floatingActionButton`.
/// For shells that already show an Ask APEX FAB, wrap both with
/// `ApexDualFab` which positions Ask + omni-create side by side.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'apex_ask_panel.dart';
import 'theme.dart';

class ApexOmniCreateFab extends StatelessWidget {
  final String heroTag;
  const ApexOmniCreateFab({super.key, this.heroTag = 'apex_omni_create_fab'});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: () => _showMenu(context),
      backgroundColor: AC.gold,
      foregroundColor: AC.btnFg,
      icon: const Icon(Icons.add),
      label: const Text('جديد', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AC.navy2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AC.gold.withValues(alpha: 0.18)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6, bottom: 10, top: 2),
                    child: Text(
                      'ما الذي تريد إنشاءه؟',
                      style: TextStyle(
                        color: AC.tp,
                        fontFamily: 'Tajawal',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _tile(ctx, 'فاتورة ضريبية', Icons.receipt_long_outlined,
                          () => GoRouter.of(ctx).go('/compliance/zatca-invoice')),
                      _tile(ctx, 'قيد يومية', Icons.edit_note,
                          () => GoRouter.of(ctx).go('/compliance/journal-entry-builder')),
                      _tile(ctx, 'عميل', Icons.person_add_alt_outlined,
                          () => GoRouter.of(ctx).go('/settings/entities?action=new-company')),
                      _tile(ctx, 'تذكير دفع', Icons.campaign_outlined,
                          () => _askAboutReminder(ctx)),
                      _tile(ctx, 'إقرار VAT', Icons.description_outlined,
                          () => GoRouter.of(ctx).go('/compliance/vat-return')),
                      _tile(ctx, 'احتساب زكاة', Icons.calculate_outlined,
                          () => GoRouter.of(ctx).go('/compliance/zakat')),
                      _tile(ctx, 'سؤال للمساعد', Icons.auto_awesome,
                          () {
                        Navigator.of(ctx).pop();
                        openApexAskPanel(ctx);
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, String label, IconData icon, VoidCallback onTap) {
    return SizedBox(
      width: (MediaQuery.of(ctx).size.width - 60) / 2,
      child: InkWell(
        onTap: () {
          Navigator.of(ctx).pop();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AC.navy3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AC.gold.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AC.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AC.tp,
                    fontFamily: 'Tajawal',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _askAboutReminder(BuildContext ctx) {
    Navigator.of(ctx).pop();
    openApexAskPanel(ctx, initialQuery: 'أرسل تذكير دفع مهذب لأحدث فاتورة متأخرة');
  }
}

/// Small helper: show Ask APEX + omni-create side by side.
class ApexDualFab extends StatelessWidget {
  const ApexDualFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        ApexAskFab(),
        SizedBox(width: 10),
        ApexOmniCreateFab(),
      ],
    );
  }
}
