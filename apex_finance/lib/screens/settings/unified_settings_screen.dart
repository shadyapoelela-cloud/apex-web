/// APEX — Unified Settings (one page, side tabs)
/// ═══════════════════════════════════════════════════════════════════════
/// Per blueprint §12: settings live on ONE screen with side tabs, not
/// scattered across many routes. Sections:
///   - الحساب (account)
///   - الكيان النشط (active entity)
///   - التكاملات (integrations)
///   - الإشعارات (notifications)
///   - المظهر (theme + white-label)
///
/// Sign-out at the bottom (NEVER red — reversible action per blueprint §0).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/session.dart';
import '../../core/theme.dart';

class UnifiedSettingsScreen extends StatefulWidget {
  const UnifiedSettingsScreen({super.key});
  @override
  State<UnifiedSettingsScreen> createState() => _UnifiedSettingsScreenState();
}

class _UnifiedSettingsScreenState extends State<UnifiedSettingsScreen> {
  int _selected = 0;

  static const _sections = [
    _Section(icon: Icons.person_outline, title: 'الحساب'),
    _Section(icon: Icons.business_outlined, title: 'الكيان النشط'),
    _Section(icon: Icons.power_outlined, title: 'التكاملات'),
    _Section(icon: Icons.notifications_outlined, title: 'الإشعارات'),
    _Section(icon: Icons.palette_outlined, title: 'المظهر'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('الإعدادات', style: TextStyle(color: AC.gold)),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Side tabs (RTL: visually on the right edge)
          Container(
            width: 220,
            color: AC.navy2,
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                ..._sections.asMap().entries.map((e) {
                  final selected = e.key == _selected;
                  return InkWell(
                    onTap: () => setState(() => _selected = e.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? AC.gold.withValues(alpha: 0.15) : Colors.transparent,
                        border: BorderDirectional(
                          end: BorderSide(
                              color: selected ? AC.gold : Colors.transparent,
                              width: 3),
                        ),
                      ),
                      child: Row(children: [
                        Icon(e.value.icon,
                            color: selected ? AC.gold : AC.ts, size: 16),
                        const SizedBox(width: 10),
                        Text(e.value.title,
                            style: TextStyle(
                                color: selected ? AC.gold : AC.tp,
                                fontSize: 13,
                                fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
                      ]),
                    ),
                  );
                }),
                const Divider(),
                // Sign out — NOT red (reversible)
                InkWell(
                  onTap: _confirmSignOut,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(children: [
                      Icon(Icons.logout, color: AC.ts, size: 16),
                      const SizedBox(width: 10),
                      Text('تسجيل الخروج',
                          style: TextStyle(color: AC.tp, fontSize: 13)),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: AC.bdr),
          Expanded(
            child: _content(),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: switch (_selected) {
        0 => _accountSection(),
        1 => _entitySection(),
        2 => _integrationsSection(),
        3 => _notificationsSection(),
        _ => _themeSection(),
      },
    );
  }

  Widget _accountSection() => _sectionWrapper('الحساب', [
        _kv('البريد', S.email ?? '-'),
        _kv('الاسم', S.uname ?? '-'),
        _kv('الخطة', S.planAr()),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _ctaButton(Icons.lock_outline, 'تغيير كلمة المرور',
              () => context.go('/password/change'))),
          const SizedBox(width: 8),
          Expanded(child: _ctaButton(Icons.security, 'MFA',
              () => context.go('/account/mfa'))),
        ]),
        const SizedBox(height: 8),
        _ctaButton(Icons.history, 'سجل النشاط',
            () => context.go('/account/activity')),
      ]);

  Widget _entitySection() => _sectionWrapper('الكيان النشط', [
        _kv('Tenant ID', '${S.savedTenantId?.substring(0, 12) ?? '-'}…'),
        _kv('Entity ID', '${S.savedEntityId?.substring(0, 12) ?? '-'}…'),
        const SizedBox(height: 16),
        _ctaButton(Icons.swap_horiz, 'إنشاء كيان جديد',
            () => context.go('/onboarding')),
        const SizedBox(height: 8),
        _ctaButton(Icons.account_tree_outlined, 'شجرة الحسابات',
            () => context.go('/coa-tree')),
        const SizedBox(height: 8),
        _ctaButton(Icons.calendar_month, 'الفترات المالية',
            () => context.go('/operations/period-close')),
      ]);

  Widget _integrationsSection() => _sectionWrapper('التكاملات', [
        _integrationRow(Icons.account_balance, 'البنوك (Lean / Tarabut)',
            'متصل: 0 من 11 بنك سعودي', false),
        _integrationRow(Icons.receipt_long, 'ZATCA',
            'CSID صالح حتى 2027-04-15', true),
        _integrationRow(Icons.chat_bubble_outline, 'WhatsApp Business',
            'لم يتم الربط', false),
        _integrationRow(Icons.point_of_sale, 'نقاط البيع (POS)',
            'Foodics غير متصل', false),
        _integrationRow(Icons.payment, 'بوابات الدفع',
            'Mada / STC Pay / Apple Pay', true),
      ]);

  Widget _notificationsSection() => _sectionWrapper('الإشعارات', [
        Row(children: [
          Icon(Icons.email_outlined, color: AC.ts, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('البريد الإلكتروني', style: TextStyle(color: AC.tp))),
          Switch(value: true, onChanged: (_) {}, activeColor: AC.gold),
        ]),
        Row(children: [
          Icon(Icons.chat, color: AC.ts, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('واتساب', style: TextStyle(color: AC.tp))),
          Switch(value: false, onChanged: (_) {}, activeColor: AC.gold),
        ]),
        Row(children: [
          Icon(Icons.phone_iphone, color: AC.ts, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text('Push (الجوال)', style: TextStyle(color: AC.tp))),
          Switch(value: true, onChanged: (_) {}, activeColor: AC.gold),
        ]),
      ]);

  Widget _themeSection() => _sectionWrapper('المظهر', [
        Text('الوضع', style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          ChoiceChip(
            label: const Text('داكن'),
            selected: true,
            onSelected: (_) {},
            selectedColor: AC.gold,
          ),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('فاتح'), selected: false, onSelected: (_) {}),
          const SizedBox(width: 8),
          ChoiceChip(label: const Text('تلقائي'), selected: false, onSelected: (_) {}),
        ]),
        const SizedBox(height: 24),
        _ctaButton(Icons.brush, 'White Label (شعار + ألوان)',
            () {}),
      ]);

  // ─── helpers ───
  Widget _sectionWrapper(String title, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          ...children,
        ],
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 130, child: Text(k, style: TextStyle(color: AC.ts, fontSize: 12))),
          Expanded(child: Text(v, style: TextStyle(color: AC.tp, fontSize: 13, fontFamily: 'monospace'))),
        ]),
      );

  Widget _ctaButton(IconData icon, String label, VoidCallback onTap) =>
      OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: AC.gold),
        label: Text(label, style: TextStyle(color: AC.gold)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AC.gold.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          alignment: AlignmentDirectional.centerStart,
        ),
      );

  Widget _integrationRow(IconData icon, String name, String status, bool connected) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(icon, color: connected ? AC.ok : AC.ts, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(status, style: TextStyle(color: connected ? AC.ok : AC.ts, fontSize: 11)),
          ]),
        ),
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
              backgroundColor: connected ? AC.navy3 : AC.gold,
              foregroundColor: connected ? AC.tp : AC.navy),
          child: Text(connected ? 'إعدادات' : 'اربط'),
        ),
      ]),
    );
  }

  void _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('تسجيل الخروج؟', style: TextStyle(color: AC.tp)),
        content: Text('سيتم إنهاء جلستك على هذا الجهاز.',
            style: TextStyle(color: AC.ts, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('إلغاء', style: TextStyle(color: AC.ts))),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      S.clear();
      context.go('/login');
    }
  }
}

class _Section {
  final IconData icon;
  final String title;
  const _Section({required this.icon, required this.title});
}
