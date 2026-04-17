/// APEX App Switcher — Odoo 18-style 9-module grid overlay.
///
/// Shows the full module set as big coloured tiles in a modal. Intended
/// to be opened from a globe / grid button in the top bar or via a
/// keyboard shortcut. Each tile is tappable and routes to the module
/// landing screen.
///
/// Unlike the Cmd+K palette (which is keyboard-first + fuzzy search),
/// this is image-first + one-level hierarchy. Pennylane and SAP Fiori
/// use the same pattern for users who think in "where is payroll" rather
/// than "type p-a-y".
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'design_tokens.dart';
import 'theme.dart';

class ApexModuleTile {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final String route;

  const ApexModuleTile({
    required this.label,
    this.subtitle,
    required this.icon,
    required this.accent,
    required this.route,
  });
}

/// The canonical APEX module set. Each group maps to a colour band.
const List<ApexModuleTile> kApexModules = [
  // Core finance
  ApexModuleTile(
    label: 'الامتثال',
    subtitle: 'ZATCA · VAT · Zakat',
    icon: Icons.shield_outlined,
    accent: Color(0xFF2E75B6),
    route: '/compliance',
  ),
  ApexModuleTile(
    label: 'قيود اليومية',
    subtitle: 'GL + Trial Balance',
    icon: Icons.receipt_long_outlined,
    accent: Color(0xFF4A6FA5),
    route: '/compliance/journal-entries',
  ),
  ApexModuleTile(
    label: 'القوائم المالية',
    subtitle: 'P&L · ميزانية · تدفق',
    icon: Icons.insert_chart_outlined,
    accent: Color(0xFF5A8F3D),
    route: '/compliance/financial-statements',
  ),
  ApexModuleTile(
    label: 'الرواتب',
    subtitle: 'GOSI · WPS · EOSB',
    icon: Icons.badge_outlined,
    accent: Color(0xFFB97A3E),
    route: '/compliance/payroll',
  ),
  ApexModuleTile(
    label: 'المطابقة البنكية',
    subtitle: 'OCR + Matching',
    icon: Icons.compare_arrows_outlined,
    accent: Color(0xFF6C63FF),
    route: '/compliance/bank-rec',
  ),
  // AI
  ApexModuleTile(
    label: 'Copilot',
    subtitle: 'مساعد AI مالي',
    icon: Icons.psychology_outlined,
    accent: Color(0xFFD4AF37),
    route: '/copilot',
  ),
  ApexModuleTile(
    label: 'المعرفة',
    subtitle: 'Knowledge Brain',
    icon: Icons.menu_book_outlined,
    accent: Color(0xFF8B5CF6),
    route: '/knowledge',
  ),
  // New
  ApexModuleTile(
    label: 'ما الجديد',
    subtitle: 'Sprint 35 → 42',
    icon: Icons.rocket_launch_outlined,
    accent: Color(0xFFE74C3C),
    route: '/whats-new',
  ),
  ApexModuleTile(
    label: 'الإعدادات',
    subtitle: 'Users · Roles · API',
    icon: Icons.settings_outlined,
    accent: Color(0xFF64748B),
    route: '/settings',
  ),
];

/// Shows the app-switcher modal over the current route.
Future<void> showApexAppSwitcher(
  BuildContext context, {
  List<ApexModuleTile> modules = kApexModules,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => ApexAppSwitcherDialog(modules: modules),
  );
}

class ApexAppSwitcherDialog extends StatelessWidget {
  final List<ApexModuleTile> modules;
  const ApexAppSwitcherDialog({super.key, required this.modules});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final crossAxis = size.width >= 1024
        ? 3
        : size.width >= 600
            ? 3
            : 2;
    final maxWidth = size.width >= 1024 ? 720.0 : size.width - 32;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: AC.bdr),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.apps, color: AC.gold, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text('مبدّل الوحدات',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.xl,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AC.ts),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: modules.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxis,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (_, i) =>
                    _ModuleCard(module: modules[i]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  final ApexModuleTile module;
  const _ModuleCard({required this.module});

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    return Semantics(
      button: true,
      label: 'فتح ${m.label}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            Navigator.pop(context);
            GoRouter.of(context).go(m.route);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            transform: Matrix4.identity()..scale(_hover ? 1.03 : 1.0),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _hover ? m.accent : AC.bdr,
                width: _hover ? 1.5 : 1,
              ),
              gradient: _hover
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        m.accent.withValues(alpha: 0.18),
                        AC.navy3,
                      ],
                    )
                  : null,
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: m.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(m.icon, color: m.accent, size: 24),
                ),
                const SizedBox(height: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.label,
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: AppFontSize.lg,
                            fontWeight: FontWeight.w700)),
                    if (m.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(m.subtitle!,
                          style: TextStyle(
                              color: AC.ts,
                              fontSize: AppFontSize.xs,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
