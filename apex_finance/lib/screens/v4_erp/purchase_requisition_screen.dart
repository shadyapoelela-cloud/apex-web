/// APEX Wave 87 — Purchase Requisition Workflow.
/// Route: /app/erp/operations/requisitions
///
/// Request-to-PO pipeline with approvals and vendor selection.
library;

import 'package:flutter/material.dart';

class PurchaseRequisitionScreen extends StatefulWidget {
  const PurchaseRequisitionScreen({super.key});
  @override
  State<PurchaseRequisitionScreen> createState() => _PurchaseRequisitionScreenState();
}

class _PurchaseRequisitionScreenState extends State<PurchaseRequisitionScreen> {
  String _view = 'kanban';

  final _requisitions = <_PR>[
    _PR('PR-2026-0248', 'أجهزة Dell Laptops × 8', 58000, 'IT', 'فهد الشمري', '2026-04-19', 'pending', 1, 3),
    _PR('PR-2026-0247', 'ترخيص SAP PS إضافي', 185000, 'IT', 'محمد القحطاني', '2026-04-18', 'sourcing', 2, 3),
    _PR('PR-2026-0246', 'أثاث مكتبي للطابق 4', 92000, 'Facilities', 'لينا البكري', '2026-04-17', 'approved', 3, 3),
    _PR('PR-2026-0245', 'خدمات تنظيف ربعية', 28500, 'Facilities', 'ياسر العنزي', '2026-04-16', 'converted', 3, 3),
    _PR('PR-2026-0244', 'مواد استهلاكية للمختبر', 45200, 'R&D', 'نورة الغامدي', '2026-04-15', 'pending', 1, 3),
    _PR('PR-2026-0243', 'تجديد عقد Microsoft 365', 125000, 'IT', 'محمد القحطاني', '2026-04-14', 'approved', 3, 3),
    _PR('PR-2026-0242', 'سيارات أسطول × 3', 780000, 'Fleet', 'أحمد العتيبي', '2026-04-12', 'sourcing', 2, 3),
    _PR('PR-2026-0241', 'تدريب AML للموظفين', 48000, 'Compliance', 'سارة الدوسري', '2026-04-10', 'converted', 3, 3),
    _PR('PR-2026-0240', 'كراتين تعبئة دورية', 12500, 'Warehouse', 'خالد الحربي', '2026-04-08', 'rejected', 0, 3),
    _PR('PR-2026-0239', 'خدمات ضيافة حدث Q2', 85000, 'Marketing', 'رنا الرشيد', '2026-04-05', 'draft', 0, 3),
  ];

  @override
  Widget build(BuildContext context) {
    final total = _requisitions.fold(0, (s, r) => s + r.amount);
    final pending = _requisitions.where((r) => r.status == 'pending').length;
    final sourcing = _requisitions.where((r) => r.status == 'sourcing').length;
    final approved = _requisitions.where((r) => r.status == 'approved').length;
    final converted = _requisitions.where((r) => r.status == 'converted').length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('إجمالي القيم', _fmtM(total.toDouble()), Colors.blue, Icons.monetization_on),
            _kpi('بانتظار الاعتماد', '$pending', Colors.orange, Icons.pending),
            _kpi('جارٍ التوريد', '$sourcing', Colors.purple, Icons.local_shipping),
            _kpi('معتمدة', '$approved', Colors.green, Icons.check_circle),
            _kpi('تحوّلت لـ PO', '$converted', const Color(0xFFD4AF37), Icons.receipt),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _viewBtn('kanban', 'Kanban', Icons.view_kanban),
            const SizedBox(width: 8),
            _viewBtn('list', 'قائمة', Icons.list),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add, size: 16),
              label: const Text('طلب شراء جديد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _view == 'kanban' ? _buildKanban() : _buildList(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF546E7A)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.shopping_cart, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('طلبات الشراء (PR)',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Purchase Requisition Workflow — طلب → اعتماد → توريد → أمر شراء → استلام',
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
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewBtn(String id, String label, IconData icon) {
    final selected = _view == id;
    return InkWell(
      onTap: () => setState(() => _view = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF37474F) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? const Color(0xFF37474F) : Colors.black26),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : Colors.black54),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildKanban() {
    final stages = const [
      _Stage('draft', 'مسوّدة', Colors.grey),
      _Stage('pending', 'بانتظار الاعتماد', Colors.orange),
      _Stage('sourcing', 'جارٍ التوريد', Colors.purple),
      _Stage('approved', 'معتمد', Colors.green),
      _Stage('converted', 'تحوّل لـ PO', Color(0xFFD4AF37)),
    ];
    return SizedBox(
      height: 520,
      child: Row(
        children: [
          for (final stage in stages)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: stage.color.withOpacity(0.12),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      ),
                      child: Row(
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: stage.color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(stage.name,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: stage.color)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: stage.color, borderRadius: BorderRadius.circular(10)),
                            child: Text('${_requisitions.where((r) => r.status == stage.id).length}',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(8),
                        children: [
                          for (final r in _requisitions.where((r) => r.status == stage.id)) _prCard(r, stage.color),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _prCard(_PR r, Color stageColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.id, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black54)),
          const SizedBox(height: 4),
          Text(r.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
            child: Text('${_fmt(r.amount.toDouble())} ر.س',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person, size: 11, color: Colors.black45),
              const SizedBox(width: 3),
              Expanded(child: Text(r.requester, style: const TextStyle(fontSize: 10, color: Colors.black54))),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 10, color: Colors.black45),
              const SizedBox(width: 3),
              Text(r.createdAt.substring(5),
                  style: const TextStyle(fontSize: 10, color: Colors.black54, fontFamily: 'monospace')),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3)),
                child: Text(r.department, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < r.totalSteps; i++) ...[
                Expanded(
                  child: Container(
                    height: 4,
                    color: i < r.stepsCompleted ? stageColor : Colors.grey.shade300,
                  ),
                ),
                if (i < r.totalSteps - 1) const SizedBox(width: 2),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: const Row(
              children: [
                Expanded(child: Text('الرقم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 3, child: Text('الوصف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('المبلغ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('القسم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('الطالب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('التاريخ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(flex: 2, child: Text('التقدّم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              ],
            ),
          ),
          for (final r in _requisitions) _prListRow(r),
        ],
      ),
    );
  }

  Widget _prListRow(_PR r) {
    final stageColor = _stageColor(r.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          Expanded(child: Text(r.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
          Expanded(flex: 3, child: Text(r.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
          Expanded(
            child: Text(_fmt(r.amount.toDouble()),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(3)),
              child: Text(r.department, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            ),
          ),
          Expanded(flex: 2, child: Text(r.requester, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text(r.createdAt, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace'))),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: r.stepsCompleted / r.totalSteps,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(stageColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(width: 6),
                Text('${r.stepsCompleted}/${r.totalSteps}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: stageColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
              child: Text(_stageLabel(r.status),
                  style: TextStyle(fontSize: 10, color: stageColor, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Color _stageColor(String s) {
    switch (s) {
      case 'draft':
        return Colors.grey;
      case 'pending':
        return Colors.orange;
      case 'sourcing':
        return Colors.purple;
      case 'approved':
        return Colors.green;
      case 'converted':
        return const Color(0xFFD4AF37);
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _stageLabel(String s) {
    switch (s) {
      case 'draft':
        return 'مسوّدة';
      case 'pending':
        return 'اعتماد';
      case 'sourcing':
        return 'توريد';
      case 'approved':
        return 'معتمد';
      case 'converted':
        return 'PO';
      case 'rejected':
        return 'مرفوض';
      default:
        return s;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(2)}M';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _PR {
  final String id;
  final String title;
  final int amount;
  final String department;
  final String requester;
  final String createdAt;
  final String status;
  final int stepsCompleted;
  final int totalSteps;
  const _PR(this.id, this.title, this.amount, this.department, this.requester, this.createdAt, this.status, this.stepsCompleted, this.totalSteps);
}

class _Stage {
  final String id;
  final String name;
  final Color color;
  const _Stage(this.id, this.name, this.color);
}
