/// APEX Wave 70 — Approval Workflows & Delegation Matrix.
/// Route: /app/erp/finance/workflows
///
/// Centralized approval queue + delegation-of-authority matrix.
library;

import 'package:flutter/material.dart';

class ApprovalWorkflowsScreen extends StatefulWidget {
  const ApprovalWorkflowsScreen({super.key});
  @override
  State<ApprovalWorkflowsScreen> createState() => _ApprovalWorkflowsScreenState();
}

class _ApprovalWorkflowsScreenState extends State<ApprovalWorkflowsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _queue = <_Request>[
    _Request('REQ-2026-0892', 'فاتورة مبيعات INV-2026-0528', 'invoice', 285000, 'نورة الغامدي', '2026-04-19 09:30', 'pending', 'manager', 2),
    _Request('REQ-2026-0891', 'أمر شراء PO-2026-0342', 'po', 145000, 'فهد الشمري', '2026-04-19 09:15', 'pending', 'manager', 1),
    _Request('REQ-2026-0890', 'مطالبة مصروفات EXP-2026-0287', 'expense', 4850, 'أحمد العتيبي', '2026-04-19 08:42', 'in-progress', 'finance', 2),
    _Request('REQ-2026-0889', 'عقد جديد CTR-2026-028', 'contract', 1850000, 'سارة الدوسري', '2026-04-18 16:30', 'escalated', 'cfo', 3),
    _Request('REQ-2026-0888', 'تعديل راتب EMP-0098', 'hr', 15000, 'لينا البكري', '2026-04-18 15:20', 'approved', 'cfo', 3),
    _Request('REQ-2026-0887', 'دفعة مورد VEND-0042', 'payment', 485000, 'محمد القحطاني', '2026-04-18 14:05', 'approved', 'cfo', 3),
    _Request('REQ-2026-0886', 'قيد محاسبي استثنائي JE-2026-145', 'je', 125000, 'فهد الشمري', '2026-04-18 12:30', 'rejected', 'cfo', 3),
    _Request('REQ-2026-0885', 'خصم على فاتورة DISC-2026-015', 'discount', 32000, 'نورة الغامدي', '2026-04-18 11:15', 'approved', 'manager', 2),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = _queue.where((r) => r.status == 'pending' || r.status == 'in-progress').length;
    final approved = _queue.where((r) => r.status == 'approved').length;
    final escalated = _queue.where((r) => r.status == 'escalated').length;
    final rejected = _queue.where((r) => r.status == 'rejected').length;

    return Column(
      children: [
        _buildHero(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              _kpi('قيد الاعتماد', '$pending', Colors.orange, Icons.pending),
              _kpi('معتمدة اليوم', '$approved', Colors.green, Icons.check_circle),
              _kpi('تصعيد', '$escalated', Colors.purple, Icons.trending_up),
              _kpi('مرفوضة', '$rejected', Colors.red, Icons.cancel),
              _kpi('متوسط وقت الاعتماد', '2.4 ساعة', Colors.blue, Icons.schedule),
            ],
          ),
        ),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(icon: Icon(Icons.inbox, size: 16), text: 'قائمة الاعتمادات'),
            Tab(icon: Icon(Icons.rule, size: 16), text: 'مصفوفة الصلاحيات'),
            Tab(icon: Icon(Icons.account_tree, size: 16), text: 'مسارات الموافقة'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildQueueTab(),
              _buildDelegationTab(),
              _buildRoutesTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.approval, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مسارات الاعتماد',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Workflow engine · صلاحيات ديناميكية · تصعيد تلقائي عند التأخر',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _queue.length,
      itemBuilder: (ctx, i) {
        final r = _queue[i];
        final sc = _statusColor(r.status);
        final ti = _typeInfo(r.type);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sc.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: ti.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(ti.icon, color: ti.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(r.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: ti.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(ti.label,
                              style: TextStyle(fontSize: 10, color: ti.color, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(r.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 11, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(r.requester, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        const SizedBox(width: 10),
                        const Icon(Icons.schedule, size: 11, color: Colors.black45),
                        const SizedBox(width: 4),
                        Text(r.submittedAt, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt(r.amount),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
                  const Text('ر.س', style: TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _stepIndicator(r.stepsCompleted, 3),
                    const SizedBox(height: 4),
                    Text(_roleLabel(r.currentRole),
                        style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_statusLabel(r.status),
                    style: TextStyle(fontSize: 11, color: sc, fontWeight: FontWeight.w800)),
              ),
              if (r.status == 'pending' || r.status == 'in-progress') ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 22),
                  onPressed: () => setState(() => r.status = 'approved'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 22),
                  onPressed: () => setState(() => r.status = 'rejected'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _stepIndicator(int completed, int total) {
    return Row(
      children: [
        for (var i = 0; i < total; i++)
          Expanded(
            child: Container(
              height: 6,
              margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
              decoration: BoxDecoration(
                color: i < completed ? Colors.green : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDelegationTab() {
    final roles = const [
      _Delegation('المدير العام / CEO', '> 5,000,000', 'أحمد السعدون', 'أي نوع — حد أقصى', Color(0xFF1A237E)),
      _Delegation('المدير المالي / CFO', '1,000,001 — 5,000,000', 'أحمد العتيبي', 'مالي، شراء، عقود', Color(0xFF0D47A1)),
      _Delegation('مدير الإدارة', '250,001 — 1,000,000', 'محمد القحطاني', 'مالي، شراء', Color(0xFF1565C0)),
      _Delegation('مسؤول القسم', '50,001 — 250,000', 'سارة الدوسري', 'شراء، مصاريف', Color(0xFF1976D2)),
      _Delegation('المشرف المباشر', '10,001 — 50,000', 'نورة الغامدي', 'مصاريف فقط', Color(0xFF1E88E5)),
      _Delegation('المشرف الذاتي', '≤ 10,000', 'أي موظف ذاتي', 'مصاريف صغيرة', Color(0xFF42A5F5)),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مصفوفة تفويض الصلاحيات المعتمدة من مجلس الإدارة — أي طلب يتجاوز الحد يُصعَّد تلقائياً للمستوى الأعلى.',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final d in roles)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: d.color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: d.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.verified_user, color: d.color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.role, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                      Text(d.holder, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('النطاق المالي (ر.س)', style: TextStyle(fontSize: 10, color: Colors.black54)),
                      Text(d.range,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: d.color, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('أنواع الطلبات', style: TextStyle(fontSize: 10, color: Colors.black54)),
                      Text(d.scope, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRoutesTab() {
    final routes = const [
      _Route(
        'فاتورة مبيعات > 500K ر.س',
        [
          _Step(1, 'مدير المبيعات', 'نورة الغامدي', Icons.person),
          _Step(2, 'مدير الإدارة', 'محمد القحطاني', Icons.supervised_user_circle),
          _Step(3, 'المدير المالي', 'أحمد العتيبي', Icons.star),
        ],
      ),
      _Route(
        'أمر شراء 100K - 500K ر.س',
        [
          _Step(1, 'طالب الشراء', 'أي موظف', Icons.person_outline),
          _Step(2, 'مسؤول القسم', 'حسب القسم', Icons.group),
          _Step(3, 'مدير الإدارة', 'محمد القحطاني', Icons.supervised_user_circle),
        ],
      ),
      _Route(
        'قيد محاسبي استثنائي',
        [
          _Step(1, 'المحاسب', 'فهد الشمري', Icons.person_outline),
          _Step(2, 'المدير المالي', 'أحمد العتيبي', Icons.star),
          _Step(3, 'الشريك المسؤول (للمدقّقين)', 'د. عبدالله', Icons.verified),
        ],
      ),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final r in routes)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_tree, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 10),
                    Text(r.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    for (var i = 0; i < r.steps.length; i++) ...[
                      Expanded(child: _stepBlock(r.steps[i])),
                      if (i < r.steps.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.arrow_forward, color: Color(0xFFD4AF37)),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _stepBlock(_Step s) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.15),
            child: Text('${s.order}',
                style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.w900, fontSize: 14)),
          ),
          const SizedBox(height: 6),
          Icon(s.icon, size: 18, color: const Color(0xFFD4AF37)),
          const SizedBox(height: 4),
          Text(s.role, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text(s.holder, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  _TypeInfo _typeInfo(String t) {
    switch (t) {
      case 'invoice':
        return const _TypeInfo('فاتورة', Icons.receipt, Color(0xFFD4AF37));
      case 'po':
        return const _TypeInfo('أمر شراء', Icons.shopping_cart, Colors.blue);
      case 'expense':
        return const _TypeInfo('مطالبة مصروفات', Icons.payments, Colors.orange);
      case 'contract':
        return const _TypeInfo('عقد', Icons.gavel, Colors.purple);
      case 'hr':
        return const _TypeInfo('موارد بشرية', Icons.people, Colors.teal);
      case 'payment':
        return const _TypeInfo('دفعة', Icons.send_to_mobile, Colors.green);
      case 'je':
        return const _TypeInfo('قيد محاسبي', Icons.book, Colors.indigo);
      case 'discount':
        return const _TypeInfo('خصم', Icons.local_offer, Colors.red);
      default:
        return const _TypeInfo('أخرى', Icons.category, Colors.grey);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'pending':
        return Colors.orange;
      case 'in-progress':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'escalated':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'بانتظار';
      case 'in-progress':
        return 'قيد الاعتماد';
      case 'approved':
        return 'معتمد';
      case 'rejected':
        return 'مرفوض';
      case 'escalated':
        return 'مصعَّد';
      default:
        return s;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'manager':
        return 'المدير المباشر';
      case 'finance':
        return 'المالية';
      case 'cfo':
        return 'المدير المالي';
      case 'ceo':
        return 'الرئيس التنفيذي';
      default:
        return role;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Request {
  final String id;
  final String title;
  final String type;
  final double amount;
  final String requester;
  final String submittedAt;
  String status;
  final String currentRole;
  final int stepsCompleted;
  _Request(this.id, this.title, this.type, this.amount, this.requester, this.submittedAt, this.status, this.currentRole, this.stepsCompleted);
}

class _Delegation {
  final String role;
  final String range;
  final String holder;
  final String scope;
  final Color color;
  const _Delegation(this.role, this.range, this.holder, this.scope, this.color);
}

class _Route {
  final String name;
  final List<_Step> steps;
  const _Route(this.name, this.steps);
}

class _Step {
  final int order;
  final String role;
  final String holder;
  final IconData icon;
  const _Step(this.order, this.role, this.holder, this.icon);
}

class _TypeInfo {
  final String label;
  final IconData icon;
  final Color color;
  const _TypeInfo(this.label, this.icon, this.color);
}
