/// APEX Wave 64 — Activity Log / Audit Trail.
/// Route: /app/platform/security/audit-trail
///
/// System-wide immutable log for compliance & investigation.
library;

import 'package:flutter/material.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});
  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  String _severity = 'all';
  String _module = 'all';
  String _query = '';

  final _events = <_Event>[
    _Event('EVT-2026-048521', '2026-04-19 09:42:15', 'أحمد العتيبي', 'finance', 'LOGIN', 'تسجيل دخول ناجح', 'info', '192.168.1.42', 'Chrome/Windows'),
    _Event('EVT-2026-048520', '2026-04-19 09:40:02', 'سارة الدوسري', 'compliance', 'VAT_RETURN_SUBMIT', 'تقديم إقرار VAT لشهر أبريل — 48,250 ر.س', 'critical', '10.0.5.18', 'Chrome/Windows'),
    _Event('EVT-2026-048519', '2026-04-19 09:35:47', 'محمد القحطاني', 'audit', 'WORKPAPER_EDIT', 'تعديل ورقة عمل WP-2026-142 — قسم المخزون', 'info', '10.0.5.22', 'Edge/Windows'),
    _Event('EVT-2026-048518', '2026-04-19 09:28:14', 'فهد الشمري', 'erp', 'JE_POST', 'ترحيل قيد JE-2026-145 — 87,250 ر.س', 'warning', '10.0.5.31', 'Chrome/Mac'),
    _Event('EVT-2026-048517', '2026-04-19 09:15:32', 'النظام', 'zatca', 'INVOICE_SIGN', 'توقيع 342 فاتورة Phase 2 وإرسالها', 'info', 'system', 'ZATCA Gateway'),
    _Event('EVT-2026-048516', '2026-04-19 09:10:08', 'لينا البكري', 'hr', 'EMPLOYEE_CREATE', 'إنشاء ملف موظف جديد EMP-0125 — ياسر التميمي', 'info', '10.0.5.42', 'Firefox/Windows'),
    _Event('EVT-2026-048515', '2026-04-19 08:58:21', 'د. عبدالله السهلي', 'audit', 'ENGAGEMENT_ACCEPT', 'قبول ارتباط مراجعة NEOM — 2.4M ر.س', 'critical', '192.168.1.5', 'Safari/Mac'),
    _Event('EVT-2026-048514', '2026-04-19 08:45:10', 'أحمد العتيبي', 'erp', 'APPROVE', 'اعتماد مطالبة مصروفات EXP-2026-0287 — 4,850 ر.س', 'info', '192.168.1.42', 'Chrome/Windows'),
    _Event('EVT-2026-048513', '2026-04-19 08:30:55', 'نورة الغامدي', 'erp', 'INVOICE_CREATE', 'إصدار فاتورة INV-2026-0512 — 485,000 ر.س', 'info', '10.0.5.67', 'Chrome/Windows'),
    _Event('EVT-2026-048512', '2026-04-19 08:15:33', 'مجهول', 'auth', 'LOGIN_FAIL', 'محاولة تسجيل دخول فاشلة — حساب admin@apex.sa', 'warning', '84.23.115.204', 'curl/8.1'),
    _Event('EVT-2026-048511', '2026-04-19 08:12:45', 'مجهول', 'auth', 'LOGIN_FAIL', 'محاولة تسجيل دخول فاشلة — حساب admin@apex.sa', 'warning', '84.23.115.204', 'curl/8.1'),
    _Event('EVT-2026-048510', '2026-04-19 08:12:41', 'مجهول', 'auth', 'LOGIN_FAIL', 'محاولة تسجيل دخول فاشلة — حساب admin@apex.sa', 'critical', '84.23.115.204', 'curl/8.1'),
    _Event('EVT-2026-048509', '2026-04-18 22:00:00', 'النظام', 'system', 'BACKUP', 'نسخ احتياطي ليلي مكتمل — 48.2 GB', 'info', 'system', 'Cron'),
    _Event('EVT-2026-048508', '2026-04-18 17:30:21', 'محمد القحطاني', 'erp', 'DELETE', 'حذف فاتورة مسوّدة DRAFT-INV-892', 'warning', '10.0.5.22', 'Chrome/Windows'),
    _Event('EVT-2026-048507', '2026-04-18 16:45:02', 'سارة الدوسري', 'compliance', 'PERMISSION_GRANT', 'منح صلاحية "Tax Manager" للمستخدم فهد الشمري', 'critical', '10.0.5.18', 'Chrome/Windows'),
    _Event('EVT-2026-048506', '2026-04-18 15:20:18', 'النظام', 'ai', 'AGENT_RUN', 'تشغيل وكيل "مطابقة بنكية" — 847 معاملة', 'info', 'system', 'AI Agent'),
    _Event('EVT-2026-048505', '2026-04-18 14:05:47', 'أحمد العتيبي', 'finance', 'REPORT_EXPORT', 'تصدير القوائم المالية Q1 2026 بصيغة PDF', 'info', '192.168.1.42', 'Chrome/Windows'),
    _Event('EVT-2026-048504', '2026-04-18 13:30:12', 'لينا البكري', 'hr', 'SALARY_REVISION', 'تعديل راتب الموظف EMP-0098 — زيادة 8%', 'critical', '10.0.5.42', 'Firefox/Windows'),
  ];

  List<_Event> get _filtered {
    return _events.where((e) {
      if (_severity != 'all' && e.severity != _severity) return false;
      if (_module != 'all' && e.module != _module) return false;
      if (_query.isNotEmpty && !e.description.contains(_query) && !e.user.contains(_query)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final critical = _events.where((e) => e.severity == 'critical').length;
    final warning = _events.where((e) => e.severity == 'warning').length;
    final info = _events.where((e) => e.severity == 'info').length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('مجموع الأحداث', '${_events.length}', Colors.blue, Icons.receipt_long),
            _kpi('حرجة', '$critical', Colors.red, Icons.error),
            _kpi('تحذيرات', '$warning', Colors.orange, Icons.warning),
            _kpi('معلوماتية', '$info', Colors.green, Icons.info),
          ],
        ),
        const SizedBox(height: 16),
        _buildFilters(),
        const SizedBox(height: 16),
        for (final e in _filtered) _eventCard(e),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('سجل النشاط والتدقيق',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('سجل غير قابل للتعديل (Immutable) لكل الأحداث عبر النظام · متوافق مع ISO 27001',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, size: 16),
            label: const Text('تصدير'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1A237E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'ابحث في الأوصاف أو المستخدمين...',
              prefixIcon: const Icon(Icons.search, size: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _dropdown('الشدّة', _severity, const [
          DropdownMenuItem(value: 'all', child: Text('جميع المستويات')),
          DropdownMenuItem(value: 'critical', child: Text('حرج')),
          DropdownMenuItem(value: 'warning', child: Text('تحذير')),
          DropdownMenuItem(value: 'info', child: Text('معلومات')),
        ], (v) => setState(() => _severity = v))),
        const SizedBox(width: 10),
        Expanded(child: _dropdown('الوحدة', _module, const [
          DropdownMenuItem(value: 'all', child: Text('جميع الوحدات')),
          DropdownMenuItem(value: 'finance', child: Text('المالية')),
          DropdownMenuItem(value: 'erp', child: Text('ERP')),
          DropdownMenuItem(value: 'hr', child: Text('الموارد البشرية')),
          DropdownMenuItem(value: 'compliance', child: Text('الامتثال')),
          DropdownMenuItem(value: 'audit', child: Text('المراجعة')),
          DropdownMenuItem(value: 'zatca', child: Text('ZATCA')),
          DropdownMenuItem(value: 'auth', child: Text('المصادقة')),
          DropdownMenuItem(value: 'ai', child: Text('الذكاء الاصطناعي')),
          DropdownMenuItem(value: 'system', child: Text('النظام')),
        ], (v) => setState(() => _module = v))),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<DropdownMenuItem<String>> items, void Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label:', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(width: 6),
          Expanded(
            child: DropdownButton<String>(
              value: value,
              underline: const SizedBox(),
              isDense: true,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87),
              items: items,
              onChanged: (v) => onChanged(v ?? 'all'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventCard(_Event e) {
    final color = _severityColor(e.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 44,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Icon(_severityIcon(e.severity), color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(e.id, style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black54)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _moduleColor(e.module).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(e.module,
                          style: TextStyle(
                              fontSize: 10,
                              color: _moduleColor(e.module),
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace')),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(e.action, style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.black87, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(e.description, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.4)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person, size: 11, color: Colors.black45),
                    const SizedBox(width: 4),
                    Text(e.user, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule, size: 11, color: Colors.black45),
                    const SizedBox(width: 4),
                    Text(e.timestamp, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
                    const SizedBox(width: 12),
                    const Icon(Icons.public, size: 11, color: Colors.black45),
                    const SizedBox(width: 4),
                    Text(e.ip, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
                    const SizedBox(width: 12),
                    const Icon(Icons.devices, size: 11, color: Colors.black45),
                    const SizedBox(width: 4),
                    Text(e.device, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz, size: 18),
            tooltip: 'التفاصيل',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _severityIcon(String s) {
    switch (s) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      default:
        return Icons.circle;
    }
  }

  Color _moduleColor(String m) {
    switch (m) {
      case 'finance':
      case 'erp':
        return const Color(0xFFD4AF37);
      case 'hr':
        return Colors.teal;
      case 'compliance':
      case 'zatca':
        return Colors.green;
      case 'audit':
        return const Color(0xFF4A148C);
      case 'auth':
        return Colors.red;
      case 'ai':
        return Colors.purple;
      case 'system':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}

class _Event {
  final String id;
  final String timestamp;
  final String user;
  final String module;
  final String action;
  final String description;
  final String severity;
  final String ip;
  final String device;
  const _Event(this.id, this.timestamp, this.user, this.module, this.action, this.description, this.severity, this.ip, this.device);
}
