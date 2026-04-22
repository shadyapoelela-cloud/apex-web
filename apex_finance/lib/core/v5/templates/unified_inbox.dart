/// APEX V5.2 — Unified Inbox (one place for all pending tasks).
///
/// Aggregates items from every app that need the user's attention:
///   - Approval requests (JEs, POs, expenses, travel)
///   - Assigned reviews (workpapers, contracts, tax returns)
///   - Regulatory deadlines (VAT due, ZATCA CSID expiring)
///   - Mentions & comments (from Chatter)
///   - Anomaly alerts (AI-flagged transactions)
///
/// Inspired by:
///   - Workday Inbox (unified tasks)
///   - Salesforce Lightning (My Tasks)
///   - Linear (assigned issues)
///
/// Opens as a right-side drawer triggered from the bell icon in the top bar.
library;

import 'package:flutter/material.dart';
import '../../theme.dart' as core_theme;
import 'package:go_router/go_router.dart';

enum InboxCategory { approval, review, deadline, mention, alert }

extension InboxCategoryX on InboxCategory {
  String get labelAr {
    switch (this) {
      case InboxCategory.approval:
        return 'اعتمادات';
      case InboxCategory.review:
        return 'مراجعات';
      case InboxCategory.deadline:
        return 'استحقاقات';
      case InboxCategory.mention:
        return 'إشارات';
      case InboxCategory.alert:
        return 'تنبيهات';
    }
  }

  Color get color {
    switch (this) {
      case InboxCategory.approval:
        return core_theme.AC.warn;
      case InboxCategory.review:
        return core_theme.AC.info;
      case InboxCategory.deadline:
        return core_theme.AC.err;
      case InboxCategory.mention:
        return core_theme.AC.purple;
      case InboxCategory.alert:
        return core_theme.AC.gold;
    }
  }

  IconData get icon {
    switch (this) {
      case InboxCategory.approval:
        return Icons.pending_actions;
      case InboxCategory.review:
        return Icons.fact_check;
      case InboxCategory.deadline:
        return Icons.schedule;
      case InboxCategory.mention:
        return Icons.alternate_email;
      case InboxCategory.alert:
        return Icons.warning_amber;
    }
  }
}

class InboxItem {
  final String id;
  final InboxCategory category;
  final String titleAr;
  final String subtitleAr;
  final String fromAppAr;
  final DateTime? dueAt;
  final String? route;
  final IconData? iconOverride;

  const InboxItem({
    required this.id,
    required this.category,
    required this.titleAr,
    required this.subtitleAr,
    required this.fromAppAr,
    this.dueAt,
    this.route,
    this.iconOverride,
  });
}

/// Demo inbox items — production loads from /inbox/me endpoint.
final demoInboxItems = <InboxItem>[
  InboxItem(
    id: 'i1',
    category: InboxCategory.approval,
    titleAr: 'قيد يومية #JE-2026-4218 ينتظر اعتمادك',
    subtitleAr: '45,000 ر.س · تعديلات نهاية الفترة',
    fromAppAr: 'Finance › Journal Entries',
    dueAt: DateTime.now().add(const Duration(hours: 6)),
    route: '/app/erp/finance/je-builder',
  ),
  InboxItem(
    id: 'i2',
    category: InboxCategory.deadline,
    titleAr: 'إقرار VAT مستحق خلال 3 أيام',
    subtitleAr: 'Q1 2026 · آخر موعد 23 أبريل',
    fromAppAr: 'Compliance › Tax',
    dueAt: DateTime.now().add(const Duration(days: 3)),
    route: '/app/compliance/tax/vat-return',
  ),
  InboxItem(
    id: 'i3',
    category: InboxCategory.approval,
    titleAr: '3 مطالبات مصروفات بانتظارك',
    subtitleAr: 'الإجمالي 8,420 ر.س من 3 موظفين',
    fromAppAr: 'ERP › Expenses',
    dueAt: DateTime.now().add(const Duration(days: 1)),
    route: '/app/erp/expenses/expenses',
  ),
  InboxItem(
    id: 'i4',
    category: InboxCategory.alert,
    titleAr: '⚠️ 4 معاملات شاذّة اكتشفها AI Detector',
    subtitleAr: 'معاملات فوق الحد المعتاد — تحتاج مراجعة',
    fromAppAr: 'Finance › AI Anomalies',
    route: '/app/erp/finance/anomalies',
  ),
  InboxItem(
    id: 'i5',
    category: InboxCategory.review,
    titleAr: 'ورقة عمل A-101 بانتظار مراجعتك كـ EQCR',
    subtitleAr: 'شركة الراجحي للتجارة · سنة 2025',
    fromAppAr: 'Audit › Quality Control',
    dueAt: DateTime.now().add(const Duration(days: 2)),
    route: '/app/audit/quality/eqcr',
  ),
  InboxItem(
    id: 'i6',
    category: InboxCategory.mention,
    titleAr: 'أحمد محمد أشار إليك في تعليق',
    subtitleAr: '"@أنت هل يمكنك التحقق من الفاتورة INV-2026-142؟"',
    fromAppAr: 'Sales › Invoices',
    route: '/app/erp/sales/invoices',
  ),
  InboxItem(
    id: 'i7',
    category: InboxCategory.deadline,
    titleAr: '🔴 شهادة CSID تنتهي خلال 12 يوم',
    subtitleAr: 'جدّد الشهادة قبل انتهاء صلاحيتها',
    fromAppAr: 'Compliance › ZATCA',
    dueAt: DateTime.now().add(const Duration(days: 12)),
    route: '/app/compliance/zatca/csid',
  ),
  InboxItem(
    id: 'i8',
    category: InboxCategory.review,
    titleAr: 'عقد مورد جديد ينتظر المراجعة القانونية',
    subtitleAr: 'AWS Cloud Services · مدة 3 سنوات',
    fromAppAr: 'Compliance › Legal AI',
    route: '/app/compliance/legal-security/legal-ai',
  ),
];

class UnifiedInbox extends StatefulWidget {
  const UnifiedInbox({super.key});

  static void show(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: core_theme.AC.td,
      builder: (ctx) => const _InboxDrawer(),
    );
  }

  @override
  State<UnifiedInbox> createState() => _UnifiedInboxState();
}

class _UnifiedInboxState extends State<UnifiedInbox> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

class _InboxDrawer extends StatefulWidget {
  const _InboxDrawer();

  @override
  State<_InboxDrawer> createState() => _InboxDrawerState();
}

class _InboxDrawerState extends State<_InboxDrawer> {
  InboxCategory? _filter;
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  List<InboxItem> get _filtered => _filter == null
      ? demoInboxItems
      : demoInboxItems.where((i) => i.category == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 420,
            height: double.infinity,
            color: Colors.white,
            child: Column(
              children: [
                _buildHeader(),
                _buildCategoryFilter(),
                const Divider(height: 1),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.inbox, size: 64, color: core_theme.AC.td),
                              SizedBox(height: 12),
                              Text('لا توجد عناصر', style: TextStyle(color: core_theme.AC.td)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (ctx, i) => _InboxItemTile(item: _filtered[i]),
                        ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: core_theme.AC.navy3,
                    border: Border(top: BorderSide(color: core_theme.AC.bdr)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.done_all, size: 16),
                          label: const Text('وضع الكل مقروء'),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.settings, size: 16),
                        label: const Text('إعدادات التنبيهات'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, Color(0xFF4A148C)],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('صندوق الوارد الموحّد',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
                Text('كل ما ينتظرك في مكان واحد',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 10)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _CatChip(
              label: 'الكل (${demoInboxItems.length})',
              color: _gold,
              active: _filter == null,
              icon: Icons.all_inbox,
              onTap: () => setState(() => _filter = null),
            ),
            ...InboxCategory.values.map((c) {
              final count = demoInboxItems.where((i) => i.category == c).length;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _CatChip(
                  label: '${c.labelAr} ($count)',
                  color: c.color,
                  icon: c.icon,
                  active: _filter == c,
                  onTap: () => setState(() => _filter = c),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _CatChip({
    required this.label,
    required this.color,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(0.15) : core_theme.AC.navy3,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? color : core_theme.AC.bdr),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: active ? color : core_theme.AC.ts),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? color : core_theme.AC.tp),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxItemTile extends StatelessWidget {
  final InboxItem item;
  const _InboxItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    String? dueText;
    Color? dueColor;
    if (item.dueAt != null) {
      final diff = item.dueAt!.difference(DateTime.now());
      if (diff.inHours < 12) {
        dueText = 'خلال ${diff.inHours} ساعة';
        dueColor = core_theme.AC.err;
      } else if (diff.inDays < 3) {
        dueText = 'خلال ${diff.inDays} أيام';
        dueColor = core_theme.AC.warn;
      } else if (diff.inDays < 30) {
        dueText = 'خلال ${diff.inDays} يوم';
        dueColor = core_theme.AC.info;
      }
    }

    return InkWell(
      onTap: item.route != null
          ? () {
              Navigator.pop(context);
              context.go(item.route!);
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: item.category.color.withOpacity(0.15),
              child: Icon(
                item.iconOverride ?? item.category.icon,
                size: 16,
                color: item.category.color,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.titleAr,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, height: 1.3)),
                  const SizedBox(height: 2),
                  Text(item.subtitleAr,
                      style: TextStyle(
                          fontSize: 11, color: core_theme.AC.ts, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(item.fromAppAr,
                          style: TextStyle(
                              fontSize: 10,
                              color: core_theme.AC.td,
                              fontWeight: FontWeight.w600)),
                      if (dueText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: dueColor!.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(dueText,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: dueColor)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
