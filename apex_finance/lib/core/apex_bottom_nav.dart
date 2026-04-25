/// APEX Mobile Bottom Navigation — shown only on mobile breakpoints.
///
/// Source: 2026 mobile navigation standard (Odoo 19 mobile, Xero, QuickBooks).
/// Desktops/tablets continue to use the sidebar; on mobile the sidebar is
/// hidden and this replaces it.
///
/// 5 primary destinations:
///   🏠 الرئيسية (Home)
///   📊 المحاسبة (Accounting)
///   🛒 المبيعات (Sales)
///   🤖 المساعد (Copilot)
///   ⋯  المزيد (More — opens full module list as bottom sheet)
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'apex_responsive.dart';
import 'design_tokens.dart';
import 'theme.dart';
import 'theme.dart' as core_theme;

class ApexBottomNav extends StatelessWidget {
  final String currentPath;
  final Widget? child;

  const ApexBottomNav({
    super.key,
    required this.currentPath,
    this.child,
  });

  static const _items = [
    _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'اليوم', path: '/today'),
    _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'المبيعات', path: '/operations/live-sales-cycle'),
    _NavItem(icon: Icons.assessment_outlined, activeIcon: Icons.assessment, label: 'القوائم', path: '/compliance/financial-statements'),
    _NavItem(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome, label: 'كوبايلوت', path: '/copilot'),
    _NavItem(icon: Icons.more_horiz, activeIcon: Icons.more_horiz, label: 'المزيد', path: '__more__'),
  ];

  int get _selectedIndex {
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].path != '__more__' && currentPath.startsWith(_items[i].path)) {
        return i;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Don't render on non-mobile.
    if (!ApexResponsive.isMobile(context)) {
      return child ?? const SizedBox.shrink();
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          boxShadow: [
            BoxShadow(
              color: core_theme.AC.tp.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                final selected = i == _selectedIndex;
                return Expanded(
                  child: InkWell(
                    onTap: () {
                      if (item.path == '__more__') {
                        _showMoreSheet(context);
                      } else {
                        GoRouter.of(context).go(item.path);
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          color: selected ? AC.gold : AC.ts,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            color: selected ? AC.gold : AC.ts,
                            fontSize: AppFontSize.xs,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AC.navy2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => _MoreSheet(),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}

class _MoreSheet extends StatelessWidget {
  static const _entries = [
    ('لوحة التحكم التنفيذية', Icons.dashboard, '/compliance/executive-dashboard'),
    ('الزكاة', Icons.calculate, '/compliance/zakat'),
    ('ضريبة القيمة المضافة', Icons.description, '/compliance/vat-return'),
    ('المطابقة البنكية', Icons.compare_arrows, '/compliance/bank-rec'),
    ('الرواتب', Icons.badge, '/compliance/payroll'),
    ('النسب المالية', Icons.bar_chart, '/compliance/ratios'),
    ('Copilot', Icons.psychology, '/copilot'),
    ('المعرفة', Icons.menu_book, '/knowledge'),
    ('الإعدادات', Icons.settings, '/settings'),
    ('معرض المكونات', Icons.auto_awesome, '/showcase'),
    ('ما الجديد', Icons.rocket_launch, '/whats-new'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AC.navy4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'كل الأدوات',
              style: TextStyle(
                color: AC.gold,
                fontSize: AppFontSize.xl,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ..._entries.map((e) {
              final (label, icon, path) = e;
              return ListTile(
                leading: Icon(icon, color: AC.gold),
                title: Text(label, style: TextStyle(color: AC.tp)),
                onTap: () {
                  Navigator.of(context).pop();
                  GoRouter.of(context).go(path);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
