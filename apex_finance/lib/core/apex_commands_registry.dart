/// APEX Commands Registry — single source of truth for Cmd+K palette.
///
/// Call [buildAppCommands] to get the full list of app-level commands
/// (navigation + actions). Feature-level commands can be merged in at
/// the feature boundary by calling [buildAppCommands] + adding their own.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'apex_command_palette.dart';

/// Builds the list of commands available everywhere in the app.
List<ApexCommand> buildAppCommands(BuildContext context) {
  void go(String path) => GoRouter.of(context).go(path);

  return [
    // ── Navigation ──
    ApexCommand.navigation(
      id: 'nav_home',
      label: 'الرئيسية',
      path: '/home',
      icon: Icons.home_outlined,
      shortcut: 'G H',
    ),
    ApexCommand(
      id: 'nav_dashboard',
      label: 'لوحة التحكم التنفيذية',
      kind: ApexCommandKind.navigation,
      icon: Icons.dashboard_outlined,
      onRun: (_) => go('/compliance/executive-dashboard'),
    ),
    ApexCommand(
      id: 'nav_compliance',
      label: 'الامتثال',
      kind: ApexCommandKind.navigation,
      icon: Icons.shield_outlined,
      onRun: (_) => go('/compliance'),
    ),
    ApexCommand(
      id: 'nav_journal_entries',
      label: 'قيود اليومية',
      kind: ApexCommandKind.navigation,
      icon: Icons.receipt_long_outlined,
      onRun: (_) => go('/compliance/journal-entries'),
    ),
    ApexCommand(
      id: 'nav_zatca',
      label: 'فاتورة ZATCA',
      subtitle: 'إنشاء فاتورة إلكترونية متوافقة مع هيئة الزكاة',
      kind: ApexCommandKind.navigation,
      icon: Icons.qr_code_2,
      onRun: (_) => go('/compliance/zatca-invoice'),
    ),
    ApexCommand(
      id: 'nav_vat_return',
      label: 'إقرار ضريبة القيمة المضافة',
      kind: ApexCommandKind.navigation,
      icon: Icons.description_outlined,
      onRun: (_) => go('/compliance/vat-return'),
    ),
    ApexCommand(
      id: 'nav_zakat',
      label: 'حاسبة الزكاة',
      kind: ApexCommandKind.navigation,
      icon: Icons.calculate_outlined,
      onRun: (_) => go('/compliance/zakat'),
    ),
    ApexCommand(
      id: 'nav_bank_rec',
      label: 'المطابقة البنكية',
      kind: ApexCommandKind.navigation,
      icon: Icons.compare_arrows,
      onRun: (_) => go('/compliance/bank-rec'),
    ),
    ApexCommand(
      id: 'nav_payroll',
      label: 'الرواتب',
      kind: ApexCommandKind.navigation,
      icon: Icons.badge_outlined,
      onRun: (_) => go('/compliance/payroll'),
    ),
    ApexCommand(
      id: 'nav_ratios',
      label: 'النسب المالية',
      kind: ApexCommandKind.navigation,
      icon: Icons.bar_chart,
      onRun: (_) => go('/compliance/ratios'),
    ),
    ApexCommand(
      id: 'nav_fixed_assets',
      label: 'الأصول الثابتة',
      kind: ApexCommandKind.navigation,
      icon: Icons.business_outlined,
      onRun: (_) => go('/compliance/depreciation'),
    ),
    ApexCommand(
      id: 'nav_cashflow',
      label: 'التدفق النقدي',
      kind: ApexCommandKind.navigation,
      icon: Icons.waterfall_chart,
      onRun: (_) => go('/compliance/cashflow'),
    ),
    ApexCommand(
      id: 'nav_breakeven',
      label: 'نقطة التعادل',
      kind: ApexCommandKind.navigation,
      icon: Icons.trending_up,
      onRun: (_) => go('/compliance/breakeven'),
    ),

    // ── Actions ──
    ApexCommand.action(
      id: 'action_new_journal_entry',
      label: 'قيد يومية جديد',
      subtitle: 'إنشاء قيد بالدائن والمدين',
      icon: Icons.add_box_outlined,
      shortcut: 'N J',
      onRun: (ctx) => GoRouter.of(ctx).go('/compliance/journal-entries/new'),
    ),
    ApexCommand.action(
      id: 'action_new_zatca_invoice',
      label: 'فاتورة ZATCA جديدة',
      icon: Icons.add_to_photos,
      shortcut: 'N I',
      onRun: (ctx) => GoRouter.of(ctx).go('/compliance/zatca-invoice'),
    ),
    ApexCommand.action(
      id: 'action_upload_coa',
      label: 'رفع دليل الحسابات',
      icon: Icons.upload_file,
      onRun: (ctx) => GoRouter.of(ctx).go('/coa/upload'),
    ),
    ApexCommand.action(
      id: 'action_open_copilot',
      label: 'المساعد الذكي',
      subtitle: 'اسأل Copilot بالعربية أو الإنجليزية',
      icon: Icons.auto_awesome,
      onRun: (ctx) => GoRouter.of(ctx).go('/copilot'),
    ),
    ApexCommand.action(
      id: 'action_knowledge_brain',
      label: 'قاعدة المعرفة',
      icon: Icons.psychology_outlined,
      onRun: (ctx) => GoRouter.of(ctx).go('/knowledge'),
    ),
    ApexCommand.action(
      id: 'action_settings',
      label: 'الإعدادات',
      icon: Icons.settings_outlined,
      onRun: (ctx) => GoRouter.of(ctx).go('/settings'),
    ),
    ApexCommand.action(
      id: 'action_marketplace',
      label: 'سوق الخدمات',
      icon: Icons.storefront_outlined,
      onRun: (ctx) => GoRouter.of(ctx).go('/marketplace'),
    ),
  ];
}
