/// Wave 150 — Corporate Cards Management.
///
/// Ramp / Brex / Airbase-class corporate card platform.
/// Features:
///   - Card issuance (virtual/physical)
///   - Real-time transaction feed
///   - Policy enforcement (MCC restrictions)
///   - Auto-categorization + receipt matching
///   - Spend limits per cardholder
///   - Freeze/unfreeze in one click
library;

import 'package:flutter/material.dart';

class CorporateCardsScreen extends StatefulWidget {
  const CorporateCardsScreen({super.key});

  @override
  State<CorporateCardsScreen> createState() => _CorporateCardsScreenState();
}

class _CorporateCardsScreenState extends State<CorporateCardsScreen> {
  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);

  int _tab = 0;

  static const _cards = <_Card>[
    _Card(holder: 'أحمد محمد', role: 'مدير تسويق', last4: '4521', spent: 8420, limit: 15000, type: 'فيزا بلاتينيوم', status: _CStatus.active),
    _Card(holder: 'سارة علي', role: 'مديرة عمليات', last4: '3879', spent: 12200, limit: 25000, type: 'ماستركارد', status: _CStatus.active),
    _Card(holder: 'عمر حسن', role: 'مبيعات', last4: '1156', spent: 3450, limit: 5000, type: 'فيزا بزنس', status: _CStatus.active),
    _Card(holder: 'ليلى أحمد', role: 'موارد بشرية', last4: '9042', spent: 1890, limit: 8000, type: 'ماستركارد', status: _CStatus.frozen),
    _Card(holder: 'خالد إبراهيم', role: 'مشتريات', last4: '6613', spent: 18500, limit: 20000, type: 'أمريكان إكسبرس', status: _CStatus.alert),
  ];

  static const _transactions = <_Txn>[
    _Txn(date: '2026-04-18', merchant: 'أرامكس الرياض', amount: 320, cardLast4: '4521', category: 'شحن', status: 'معتمد'),
    _Txn(date: '2026-04-18', merchant: 'Amazon Business', amount: 1240, cardLast4: '3879', category: 'مكتبية', status: 'معتمد'),
    _Txn(date: '2026-04-17', merchant: 'مطعم النخيل', amount: 380, cardLast4: '1156', category: 'ضيافة عميل', status: 'ينتظر إيصال'),
    _Txn(date: '2026-04-17', merchant: 'Uber Rides', amount: 85, cardLast4: '3879', category: 'نقل', status: 'معتمد'),
    _Txn(date: '2026-04-16', merchant: 'AWS Cloud', amount: 4200, cardLast4: '4521', category: 'اشتراكات', status: 'معتمد'),
    _Txn(date: '2026-04-16', merchant: 'Starbucks', amount: 42, cardLast4: '1156', category: 'ضيافة', status: 'مخالف للسياسة'),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.credit_card, color: _gold),
                  const SizedBox(width: 8),
                  const Text('بطاقات الشركة',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {},
                    style: FilledButton.styleFrom(backgroundColor: _gold),
                    icon: const Icon(Icons.add_card),
                    label: const Text('إصدار بطاقة جديدة'),
                  ),
                ],
              ),
            ),

            // Stats
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: const [
                  Expanded(child: _StatCard(icon: Icons.credit_card, label: 'بطاقات نشطة', value: '4', color: Colors.green)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.account_balance_wallet, label: 'إجمالي الصرف الشهري', value: '44,460 ر.س', color: Color(0xFFD4AF37))),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.warning, label: 'تنبيهات سياسة', value: '2', color: Colors.orange)),
                  SizedBox(width: 10),
                  Expanded(child: _StatCard(icon: Icons.schedule, label: 'إيصالات ناقصة', value: '1', color: Colors.red)),
                ],
              ),
            ),

            // Tabs
            Container(
              color: Colors.white,
              child: Row(
                children: [
                  _Tab(label: 'البطاقات', active: _tab == 0, onTap: () => setState(() => _tab = 0)),
                  _Tab(label: 'المعاملات', active: _tab == 1, onTap: () => setState(() => _tab = 1)),
                  _Tab(label: 'السياسات', active: _tab == 2, onTap: () => setState(() => _tab = 2)),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: _tab == 0 ? _buildCardsView() : (_tab == 1 ? _buildTxnsView() : _buildPoliciesView()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardsView() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _cards.length,
      itemBuilder: (ctx, i) {
        final c = _cards[i];
        final pct = (c.spent / c.limit * 100).clamp(0.0, 100.0);
        final (statusColor, statusLabel, statusIcon) = switch (c.status) {
          _CStatus.active => (Colors.green, 'نشطة', Icons.check_circle),
          _CStatus.frozen => (Colors.grey, 'مجمّدة', Icons.ac_unit),
          _CStatus.alert => (Colors.red, 'حد شبه منتهٍ', Icons.warning),
        };
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_navy, Color(0xFF4A148C)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.credit_card, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.holder,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('${c.role} · ${c.type}',
                          style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      Text('**** **** **** ${c.last4}',
                          style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.black87)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('الصرف', style: TextStyle(fontSize: 11, color: Colors.black54)),
                          const Spacer(),
                          Text('${c.spent.toStringAsFixed(0)} / ${c.limit.toStringAsFixed(0)} ر.س',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          color: pct > 90 ? Colors.red : (pct > 70 ? Colors.orange : Colors.green),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTxnsView() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final t = _transactions[i];
        final problem = t.status == 'مخالف للسياسة' || t.status == 'ينتظر إيصال';
        return Card(
          elevation: 1,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: (problem ? Colors.red : Colors.green).withOpacity(0.1),
              child: Icon(
                problem ? Icons.warning : Icons.check_circle,
                color: problem ? Colors.red : Colors.green,
              ),
            ),
            title: Text(t.merchant, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            subtitle: Text('${t.date} · ${t.category} · بطاقة ****${t.cardLast4}',
                style: const TextStyle(fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${t.amount.toStringAsFixed(0)} ر.س',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
                Text(t.status,
                    style: TextStyle(fontSize: 10, color: problem ? Colors.red : Colors.green)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPoliciesView() {
    final policies = [
      ('حد الضيافة اليومي', '150 ر.س للشخص', Icons.restaurant, Colors.orange),
      ('نقل بين المدن', 'يتطلب اعتماد مسبق', Icons.flight, Colors.blue),
      ('اشتراكات البرمجيات', 'بدون حد لمن له صلاحية', Icons.subscriptions, Colors.purple),
      ('ترفيه شخصي', 'محظور تماماً', Icons.block, Colors.red),
      ('شحن دولي', 'حد 2,000 ر.س شهرياً', Icons.local_shipping, Colors.teal),
      ('تبرعات', 'يتطلب اعتماد مدير مالي', Icons.volunteer_activism, Colors.green),
    ];
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: policies.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final (name, rule, icon, color) = policies[i];
        return Card(
          elevation: 1,
          child: ListTile(
            leading: CircleAvatar(backgroundColor: color.withOpacity(0.15), child: Icon(icon, color: color)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            subtitle: Text(rule, style: const TextStyle(fontSize: 11)),
            trailing: Switch(value: true, onChanged: (_) {}),
          ),
        );
      },
    );
  }
}

enum _CStatus { active, frozen, alert }

class _Card {
  final String holder;
  final String role;
  final String last4;
  final double spent;
  final double limit;
  final String type;
  final _CStatus status;
  const _Card({
    required this.holder,
    required this.role,
    required this.last4,
    required this.spent,
    required this.limit,
    required this.type,
    required this.status,
  });
}

class _Txn {
  final String date;
  final String merchant;
  final double amount;
  final String cardLast4;
  final String category;
  final String status;
  const _Txn({
    required this.date,
    required this.merchant,
    required this.amount,
    required this.cardLast4,
    required this.category,
    required this.status,
  });
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
                Text(value,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _Tab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFFD4AF37) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFFD4AF37) : Colors.black54,
          ),
        ),
      ),
    );
  }
}
