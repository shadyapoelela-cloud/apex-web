/// APEX V5.2 — Quick Create (global + button).
///
/// Global "+ New" dropdown shown in the top bar. Opens a palette of
/// common create actions across all services — mirrors Xero's "+ New"
/// button and QuickBooks' quick-create widget.
///
/// Unlike Cmd+K (which is search-first), Quick Create is action-first:
/// a curated list of the most common objects a user creates.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme.dart' as core_theme;

class QuickCreateAction {
  final String labelAr;
  final String sublabelAr;
  final IconData icon;
  final Color color;
  final String route;
  final String? shortcut;

  const QuickCreateAction({
    required this.labelAr,
    required this.sublabelAr,
    required this.icon,
    required this.color,
    required this.route,
    this.shortcut,
  });
}

// Fallback colors for quick-create actions (Navy-Gold signature).
// These are compile-time constants because the action list is const.
// The main "إنشاء" button itself pulls live colors from theme
// (see QuickCreateButton.build — gradient uses AC.gold/goldLight).
const _goldC = Color(0xFFD4AF37);
const _navyC = Color(0xFF1A237E);

const quickCreateActions = <QuickCreateAction>[
  QuickCreateAction(
    labelAr: 'فاتورة مبيعات',
    sublabelAr: 'إنشاء فاتورة جديدة لعميل',
    icon: Icons.receipt,
    color: _goldC,
    route: '/app/erp/sales/invoices',
    shortcut: 'I',
  ),
  QuickCreateAction(
    labelAr: 'قيد يومية',
    sublabelAr: 'إنشاء قيد محاسبي',
    icon: Icons.edit_note,
    color: _navyC,
    route: '/app/erp/finance/je-builder',
    shortcut: 'J',
  ),
  QuickCreateAction(
    labelAr: 'مطالبة مصروفات',
    sublabelAr: 'مطالبة نفقات موظف',
    icon: Icons.receipt_long,
    color: Colors.orange,
    route: '/app/erp/expenses/expenses',
    shortcut: 'E',
  ),
  QuickCreateAction(
    labelAr: 'أمر شراء',
    sublabelAr: 'طلب شراء جديد',
    icon: Icons.shopping_cart,
    color: Colors.teal,
    route: '/app/erp/purchasing/requisitions',
    shortcut: 'P',
  ),
  QuickCreateAction(
    labelAr: 'عميل جديد',
    sublabelAr: 'إضافة سجل عميل',
    icon: Icons.person_add,
    color: Colors.blue,
    route: '/app/erp/crm-marketing/crm',
    shortcut: 'C',
  ),
  QuickCreateAction(
    labelAr: 'مورد جديد',
    sublabelAr: 'إضافة مورد للسجلات',
    icon: Icons.store,
    color: Colors.brown,
    route: '/app/erp/purchasing/vendor-onboarding',
    shortcut: 'V',
  ),
  QuickCreateAction(
    labelAr: 'موظف جديد',
    sublabelAr: 'تسجيل موظف في HR',
    icon: Icons.person_pin,
    color: Colors.indigo,
    route: '/app/erp/hr/employees',
    shortcut: 'H',
  ),
  QuickCreateAction(
    labelAr: 'مشروع جديد',
    sublabelAr: 'فتح مشروع مع عميل',
    icon: Icons.work,
    color: Colors.deepPurple,
    route: '/app/erp/projects/projects',
    shortcut: 'R',
  ),
  QuickCreateAction(
    labelAr: 'إقرار ضريبي',
    sublabelAr: 'بدء إعداد إقرار VAT',
    icon: Icons.request_quote,
    color: Colors.green,
    route: '/app/compliance/tax/vat-return',
    shortcut: 'T',
  ),
  QuickCreateAction(
    labelAr: 'دراسة جدوى',
    sublabelAr: 'تحليل مشروع جديد',
    icon: Icons.lightbulb,
    color: Colors.amber,
    route: '/app/advisory/feasibility/market',
    shortcut: 'F',
  ),
  QuickCreateAction(
    labelAr: 'طلب خدمة (Marketplace)',
    sublabelAr: 'اطلب خدمة من مزوّد',
    icon: Icons.handshake,
    color: Colors.deepOrange,
    route: '/app/marketplace/client/requests',
    shortcut: 'M',
  ),
  QuickCreateAction(
    labelAr: 'ارتباط مراجعة',
    sublabelAr: 'فتح ملف مراجعة جديد',
    icon: Icons.fact_check,
    color: Color(0xFF4A148C),
    route: '/app/audit/engagement/acceptance',
    shortcut: 'A',
  ),
];

class QuickCreateButton extends StatelessWidget {
  const QuickCreateButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Use topBarAccent (brighter primaryLight of dark variant) so the button
    // pops against the medium-dark branded header regardless of palette.
    final primary = core_theme.AC.topBarAccent;
    final primaryDark = core_theme.AC.gold;
    final onPrimary = _bestContrastOn(primary);
    return PopupMenuButton<QuickCreateAction>(
      tooltip: 'إنشاء سريع',
      offset: const Offset(0, 42),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [primary, primaryDark],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: onPrimary),
            const SizedBox(width: 4),
            Text(
              'إنشاء',
              style: TextStyle(
                color: onPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 16, color: onPrimary),
          ],
        ),
      ),
      itemBuilder: (ctx) {
        return [
          PopupMenuItem<QuickCreateAction>(
            enabled: false,
            height: 30,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'إنشاء سريع',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          ...quickCreateActions.map((a) => PopupMenuItem<QuickCreateAction>(
                value: a,
                child: _QuickCreateItem(action: a),
              )),
        ];
      },
      onSelected: (a) => context.go(a.route),
    );
  }
}

class _QuickCreateItem extends StatelessWidget {
  final QuickCreateAction action;
  const _QuickCreateItem({required this.action});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(action.icon, size: 16, color: action.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(action.labelAr,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700)),
                Text(action.sublabelAr,
                    style: const TextStyle(
                        fontSize: 10, color: Colors.black54, height: 1.2)),
              ],
            ),
          ),
          if (action.shortcut != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                action.shortcut!,
                style: const TextStyle(
                    fontSize: 9,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: Colors.black54),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pick black or white depending on background luminance — WCAG-style.
Color _bestContrastOn(Color bg) {
  final luma =
      (0.299 * bg.r * 255 + 0.587 * bg.g * 255 + 0.114 * bg.b * 255);
  return luma > 140 ? const Color(0xFF0A1628) : const Color(0xFFFFFFFF);
}
