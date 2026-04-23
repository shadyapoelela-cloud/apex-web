/// APEX Wave 72 — Service Helpdesk / Tickets.
/// Route: /app/erp/operations/tickets
///
/// Support ticket queue with SLA tracking.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class HelpdeskTicketsScreen extends StatefulWidget {
  const HelpdeskTicketsScreen({super.key});
  @override
  State<HelpdeskTicketsScreen> createState() => _HelpdeskTicketsScreenState();
}

class _HelpdeskTicketsScreenState extends State<HelpdeskTicketsScreen> {
  String _view = 'all';

  final _tickets = <_Ticket>[
    _Ticket('TKT-2026-1045', 'مشكلة في توليد فاتورة ZATCA', 'أرامكو — سارة المطيري', 'urgent', 'in-progress', 'محمد القحطاني', '2026-04-19 08:15', 'ZATCA', 4),
    _Ticket('TKT-2026-1044', 'طلب تدريب على وحدة CRM', 'STC — عبدالله الدوسري', 'normal', 'open', null, '2026-04-19 09:30', 'Training', 0),
    _Ticket('TKT-2026-1043', 'استفسار عن تقرير الأعمار', 'سابك — فهد البقمي', 'normal', 'in-progress', 'نورة الغامدي', '2026-04-18 14:20', 'Reports', 18),
    _Ticket('TKT-2026-1042', 'فشل في مزامنة البيانات البنكية', 'NEOM — خالد الحربي', 'critical', 'in-progress', 'راشد العنزي', '2026-04-18 10:45', 'Integration', 27),
    _Ticket('TKT-2026-1041', 'طلب إضافة حقل مخصص', 'مصرف الراجحي — لينا القحطاني', 'low', 'waiting', 'فريق التطوير', '2026-04-17 16:30', 'Customization', 44),
    _Ticket('TKT-2026-1040', 'تصدير قائمة دليل الحسابات', 'الاتحاد للطيران — أحمد الصالح', 'normal', 'resolved', 'فهد الشمري', '2026-04-17 11:00', 'Export', 70),
    _Ticket('TKT-2026-1039', 'مشكلة في صلاحيات المستخدم', 'مجموعة الحبتور — ياسر العتيبي', 'urgent', 'resolved', 'محمد القحطاني', '2026-04-16 09:15', 'Access', 120),
    _Ticket('TKT-2026-1038', 'تحديث معدل VAT في النظام', 'شركة ABC — سامي المالكي', 'normal', 'resolved', 'راشد العنزي', '2026-04-15 15:45', 'Tax', 140),
    _Ticket('TKT-2026-1037', 'تعديل على سير عمل الاعتماد', 'NEOM — نواف الأحمد', 'low', 'resolved', 'فريق التطوير', '2026-04-15 12:00', 'Workflow', 165),
    _Ticket('TKT-2026-1036', 'تحميل القوائم المالية PDF', 'سابك — رنا الرشيد', 'normal', 'closed', 'فهد الشمري', '2026-04-14 10:30', 'Reports', 180),
  ];

  List<_Ticket> get _filtered {
    if (_view == 'all') return _tickets;
    if (_view == 'active') return _tickets.where((t) => t.status == 'open' || t.status == 'in-progress' || t.status == 'waiting').toList();
    if (_view == 'sla-breach') return _tickets.where((t) => _slaBreached(t)).toList();
    return _tickets.where((t) => t.status == _view).toList();
  }

  bool _slaBreached(_Ticket t) {
    final slaHours = t.priority == 'critical' ? 4 : t.priority == 'urgent' ? 8 : t.priority == 'normal' ? 48 : 120;
    return t.hoursOpen > slaHours && (t.status != 'resolved' && t.status != 'closed');
  }

  @override
  Widget build(BuildContext context) {
    final open = _tickets.where((t) => t.status == 'open' || t.status == 'in-progress' || t.status == 'waiting').length;
    final critical = _tickets.where((t) => t.priority == 'critical' && (t.status != 'resolved' && t.status != 'closed')).length;
    final slaBreach = _tickets.where(_slaBreached).length;
    final resolved = _tickets.where((t) => t.status == 'resolved' || t.status == 'closed').length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('تذاكر نشطة', '$open', core_theme.AC.info, Icons.inbox),
            _kpi('حرجة', '$critical', core_theme.AC.err, Icons.error),
            _kpi('انتهاك SLA', '$slaBreach', core_theme.AC.warn, Icons.schedule),
            _kpi('معدل الحل', '${(resolved / _tickets.length * 100).toStringAsFixed(0)}%', core_theme.AC.ok, Icons.check_circle),
            _kpi('متوسط زمن الاستجابة', '2.4 ساعة', core_theme.AC.gold, Icons.timer),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            _viewChip('all', 'الكل'),
            _viewChip('active', 'نشط'),
            _viewChip('open', 'جديد'),
            _viewChip('in-progress', 'قيد التنفيذ'),
            _viewChip('waiting', 'بانتظار رد'),
            _viewChip('resolved', 'محلولة'),
            _viewChip('sla-breach', 'انتهاك SLA'),
          ],
        ),
        const SizedBox(height: 16),
        for (final t in _filtered) _ticketCard(t),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF00897B)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('خدمة العملاء والدعم الفني',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Helpdesk · SLA tracking · تصعيد تلقائي · قاعدة معرفية',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: Text('تذكرة جديدة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00695C),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewChip(String id, String label) {
    final selected = _view == id;
    return InkWell(
      onTap: () => setState(() => _view = id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00695C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? const Color(0xFF00695C) : core_theme.AC.td),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : core_theme.AC.tp)),
      ),
    );
  }

  Widget _ticketCard(_Ticket t) {
    final pc = _priorityColor(t.priority);
    final sc = _statusColor(t.status);
    final slaBreach = _slaBreached(t);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: slaBreach ? core_theme.AC.err : pc.withValues(alpha: 0.3), width: slaBreach ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: pc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.confirmation_number, color: pc, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(t.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: pc, borderRadius: BorderRadius.circular(3)),
                          child: Text(_priorityLabel(t.priority),
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: core_theme.AC.bdr, borderRadius: BorderRadius.circular(3)),
                          child: Text(t.category,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                        if (slaBreach) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: core_theme.AC.err, borderRadius: BorderRadius.circular(3)),
                            child: Text('SLA BREACH',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(t.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.business, size: 11, color: core_theme.AC.td),
                        const SizedBox(width: 4),
                        Text(t.customer, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                        const SizedBox(width: 10),
                        Icon(Icons.schedule, size: 11, color: core_theme.AC.td),
                        const SizedBox(width: 4),
                        Text(t.createdAt, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                        const SizedBox(width: 10),
                        Icon(Icons.timer, size: 11, color: slaBreach ? core_theme.AC.err : core_theme.AC.td),
                        const SizedBox(width: 4),
                        Text('مفتوحة ${t.hoursOpen} ساعة',
                            style: TextStyle(
                                fontSize: 11,
                                color: slaBreach ? core_theme.AC.err : core_theme.AC.ts,
                                fontWeight: slaBreach ? FontWeight.w800 : FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: sc.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(t.status), size: 12, color: sc),
                        const SizedBox(width: 4),
                        Text(_statusLabel(t.status),
                            style: TextStyle(fontSize: 11, color: sc, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (t.assignee != null)
                    Row(
                      children: [
                        Icon(Icons.person, size: 12, color: core_theme.AC.ts),
                        const SizedBox(width: 4),
                        Text(t.assignee!, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    )
                  else
                    Text('غير مُعيّن', style: TextStyle(fontSize: 11, color: core_theme.AC.warn, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String p) {
    switch (p) {
      case 'critical':
        return core_theme.AC.err;
      case 'urgent':
        return core_theme.AC.warn;
      case 'normal':
        return core_theme.AC.info;
      case 'low':
        return core_theme.AC.td;
      default:
        return core_theme.AC.td;
    }
  }

  String _priorityLabel(String p) {
    switch (p) {
      case 'critical':
        return 'حرج';
      case 'urgent':
        return 'عاجل';
      case 'normal':
        return 'عادي';
      case 'low':
        return 'منخفض';
      default:
        return p;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'open':
        return core_theme.AC.info;
      case 'in-progress':
        return core_theme.AC.warn;
      case 'waiting':
        return core_theme.AC.purple;
      case 'resolved':
        return core_theme.AC.ok;
      case 'closed':
        return core_theme.AC.td;
      default:
        return core_theme.AC.td;
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'open':
        return Icons.mail_outline;
      case 'in-progress':
        return Icons.sync;
      case 'waiting':
        return Icons.hourglass_empty;
      case 'resolved':
        return Icons.check_circle;
      case 'closed':
        return Icons.archive;
      default:
        return Icons.circle;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'open':
        return 'جديد';
      case 'in-progress':
        return 'قيد التنفيذ';
      case 'waiting':
        return 'بانتظار رد';
      case 'resolved':
        return 'محلول';
      case 'closed':
        return 'مغلق';
      default:
        return s;
    }
  }
}

class _Ticket {
  final String id;
  final String title;
  final String customer;
  final String priority;
  final String status;
  final String? assignee;
  final String createdAt;
  final String category;
  final int hoursOpen;
  const _Ticket(this.id, this.title, this.customer, this.priority, this.status, this.assignee, this.createdAt, this.category, this.hoursOpen);
}
