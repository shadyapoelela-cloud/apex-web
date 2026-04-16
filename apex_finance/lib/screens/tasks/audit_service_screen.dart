import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../api_service.dart';

Widget _card(String t, List<Widget> c, {Color? accent}) => Container(
  margin: EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: accent ?? AC.bdr)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: TextStyle(color: accent ?? AC.gold, fontWeight: FontWeight.bold, fontSize: 15)),
    Divider(color: AC.bdr, height: 18), ...c]));

Widget _kv(String k, String v, {Color? vc}) => Padding(
  padding: EdgeInsets.only(bottom: 5),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: TextStyle(color: AC.ts, fontSize: 13)),
    Flexible(child: Text(v, style: TextStyle(color: vc ?? AC.tp, fontSize: 13), textAlign: TextAlign.end))]));

Widget _badge(String t, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
  child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)));

class AuditServiceScreen extends StatefulWidget {
  final String caseId;
  final String clientName;
  final String? token;
  const AuditServiceScreen({super.key, required this.caseId, required this.clientName, this.token});
  @override State<AuditServiceScreen> createState() => _AuditServiceS();
}

class _AuditServiceS extends State<AuditServiceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabC;
  bool _loading = true;
  List<dynamic> _templates = [], _samples = [], _workpapers = [], _findings = [];

  static const _stages = [
    {'key': 'coa_setup', 'label': 'شجرة الحسابات', 'icon': Icons.account_tree},
    {'key': 'tb_upload', 'label': 'ميزان المراجعة', 'icon': Icons.balance},
    {'key': 'audit_program', 'label': 'برنامج المراجعة', 'icon': Icons.checklist},
    {'key': 'sampling', 'label': 'العينات', 'icon': Icons.filter_list},
    {'key': 'execution', 'label': 'أوراق العمل', 'icon': Icons.edit_document},
    {'key': 'findings', 'label': 'الملاحظات', 'icon': Icons.warning_amber},
    {'key': 'report', 'label': 'التقرير', 'icon': Icons.description},
  ];

  @override
  void initState() {
    super.initState();
    _tabC = TabController(length: _stages.length, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final tR = await ApiService.getAuditTemplates();
    if (tR.success) _templates = tR.data['data'] ?? [];
    final sR = await ApiService.getAuditSamples(widget.caseId);
    if (sR.success) _samples = sR.data['data'] ?? [];
    final wR = await ApiService.getWorkpapers(widget.caseId);
    if (wR.success) _workpapers = wR.data['data'] ?? [];
    final fR = await ApiService.getFindings(widget.caseId);
    if (fR.success) _findings = fR.data['data'] ?? [];
    if (mounted) setState(() => _loading = false);
  }

  @override void dispose() { _tabC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: Text('المراجعة: ' + widget.clientName, style: TextStyle(color: AC.gold, fontSize: 14)),
      backgroundColor: AC.navy2,
      bottom: TabBar(controller: _tabC, isScrollable: true,
        labelColor: AC.gold, unselectedLabelColor: AC.ts, indicatorColor: AC.gold,
        tabs: _stages.map((s) => Tab(icon: Icon(s['icon'] as IconData, size: 18), text: s['label'] as String)).toList()),
    ),
    body: _loading ? Center(child: CircularProgressIndicator(color: AC.gold))
      : TabBarView(controller: _tabC, children: [
          _stageView('شجرة الحسابات', 'تأكد من اعتماد شجرة الحسابات', [_card('الحالة', [_kv('الشجرة', 'معتمدة', vc: AC.ok)])]),
          _stageView('ميزان المراجعة', 'ارفع الميزان وتأكد من ربطه', [_card('الحالة', [_kv('الميزان', 'مربوط', vc: AC.ok)])]),
          _stageView('برنامج المراجعة', 'إجراءات المراجعة', [_card('الإجراءات (' + _templates.length.toString() + ')',
            _templates.isEmpty ? [Text('لا توجد إجراءات', style: TextStyle(color: AC.ts))]
            : _templates.take(10).map((t) => Padding(padding: EdgeInsets.only(bottom: 6), child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
                  color: t['risk_level'] == 'high' ? AC.err : t['risk_level'] == 'medium' ? AC.warn : AC.ok)),
                SizedBox(width: 8),
                Expanded(child: Text(t['title_ar'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13))),
                Text(t['risk_level'] ?? '', style: TextStyle(color: AC.ts, fontSize: 11)),
              ]))).toList())]),
          _stageView('العينات', 'اختيار عينات المراجعة', [_card('العينات (' + _samples.length.toString() + ')',
            _samples.isEmpty ? [Text('لم يتم اختيار عينات', style: TextStyle(color: AC.ts))]
            : _samples.map((s) => Padding(padding: EdgeInsets.only(bottom: 6), child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(s['area'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13)),
                  Text((s['selected_count'] ?? 0).toString() + ' عينة', style: TextStyle(color: AC.cyan, fontSize: 12)),
                ]))).toList())]),
          _stageView('أوراق العمل', 'توثيق تنفيذ الاختبارات', [_card('أوراق العمل (' + _workpapers.length.toString() + ')',
            _workpapers.isEmpty ? [Text('لا توجد أوراق عمل', style: TextStyle(color: AC.ts))]
            : _workpapers.map((w) => Container(margin: EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AC.navy, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(w['reviewer_status'] == 'approved' ? Icons.check_circle : Icons.pending,
                    color: w['reviewer_status'] == 'approved' ? AC.ok : AC.warn, size: 18),
                  SizedBox(width: 8),
                  Expanded(child: Text(w['procedure_code'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold))),
                ]))).toList())]),
          _stageView('الملاحظات', 'تجميع الملاحظات', [_card('الملاحظات (' + _findings.length.toString() + ')',
            _findings.isEmpty ? [Text('لا توجد ملاحظات', style: TextStyle(color: AC.ts))]
            : _findings.map((f) => Container(margin: EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AC.navy, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: f['severity'] == 'critical' ? AC.err : AC.bdr)),
                child: Row(children: [
                  Expanded(child: Text(f['title_ar'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold))),
                  _badge(f['severity'] ?? '', f['severity'] == 'critical' ? AC.err : f['severity'] == 'high' ? AC.warn : AC.ok),
                ]))).toList())]),
          _stageView('التقرير', 'مسودة التقرير النهائي', [
            _card('ملخص المراجعة', [
              _kv('الإجراءات', _templates.length.toString()),
              _kv('العينات', _samples.length.toString()),
              _kv('أوراق العمل', _workpapers.length.toString()),
              _kv('الملاحظات', _findings.length.toString(), vc: _findings.isNotEmpty ? AC.warn : AC.ok),
            ]),
            Container(padding: EdgeInsets.all(12),
              decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AC.warn.withValues(alpha: 0.3))),
              child: Row(children: [Icon(Icons.person_search, color: AC.warn, size: 20), SizedBox(width: 8),
                Expanded(child: Text('التقرير يتطلب اعتماد المشرف قبل الإصدار', style: TextStyle(color: AC.warn, fontSize: 12)))])),
          ]),
        ]),
  );

  Widget _stageView(String title, String subtitle, List<Widget> children) => SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
      SizedBox(height: 4),
      Text(subtitle, style: TextStyle(color: AC.ts, fontSize: 12)),
      Divider(color: AC.bdr, height: 24),
      ...children,
    ]));
}
