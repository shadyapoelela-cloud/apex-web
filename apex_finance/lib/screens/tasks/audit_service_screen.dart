import 'package:flutter/material.dart';
import '../copilot/copilot_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';

const _api = apiBase;

class AC {
  static const gold = Color(0xFFC9A84C);
  static const navy = Color(0xFF050D1A);
  static const navy2 = Color(0xFF080F1F);
  static const navy3 = Color(0xFF0D1829);
  static const cyan = Color(0xFF00C2E0);
  static const tp = Color(0xFFF0EDE6);
  static const ts = Color(0xFF8A8880);
  static const ok = Color(0xFF2ECC8A);
  static const warn = Color(0xFFF0A500);
  static const err = Color(0xFFE05050);
  static const bdr = Color(0x26C9A84C);
}

Widget _card(String t, List<Widget> c, {Color? accent}) => Container(
  margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: accent ?? AC.bdr)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: TextStyle(color: accent ?? AC.gold, fontWeight: FontWeight.bold, fontSize: 15)),
    const Divider(color: AC.bdr, height: 18), ...c]));

Widget _kv(String k, String v, {Color? vc}) => Padding(
  padding: const EdgeInsets.only(bottom: 5),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: const TextStyle(color: AC.ts, fontSize: 13)),
    Flexible(child: Text(v, style: TextStyle(color: vc ?? AC.tp, fontSize: 13), textAlign: TextAlign.end))]));

Widget _badge(String t, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
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

  Map<String, String> get _h => {'Authorization': 'Bearer ${widget.token ?? ""}'};

  static const _stages = [
    {'key': 'coa_setup', 'label': 'ط´ط¬ط±ط© ط§ظ„ط­ط³ط§ط¨ط§طھ', 'icon': Icons.account_tree},
    {'key': 'tb_upload', 'label': 'ظ…ظٹط²ط§ظ† ط§ظ„ظ…ط±ط§ط¬ط¹ط©', 'icon': Icons.balance},
    {'key': 'audit_program', 'label': 'ط¨ط±ظ†ط§ظ…ط¬ ط§ظ„ظ…ط±ط§ط¬ط¹ط©', 'icon': Icons.checklist},
    {'key': 'sampling', 'label': 'ط§ظ„ط¹ظٹظ†ط§طھ', 'icon': Icons.filter_list},
    {'key': 'execution', 'label': 'ط£ظˆط±ط§ظ‚ ط§ظ„ط¹ظ…ظ„', 'icon': Icons.edit_document},
    {'key': 'findings', 'label': 'ط§ظ„ظ…ظ„ط§ط­ط¸ط§طھ', 'icon': Icons.warning_amber},
    {'key': 'report', 'label': 'ط§ظ„طھظ‚ط±ظٹط±', 'icon': Icons.description},
  ];

  @override
  void initState() {
    super.initState();
    _tabC = TabController(length: _stages.length, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final tR = await http.get(Uri.parse('$_api/audit/templates'), headers: _h);
      if (tR.statusCode == 200) _templates = jsonDecode(tR.body)['data'] ?? [];
      final sR = await http.get(Uri.parse('$_api/audit/cases/${widget.caseId}/samples'), headers: _h);
      if (sR.statusCode == 200) _samples = jsonDecode(sR.body)['data'] ?? [];
      final wR = await http.get(Uri.parse('$_api/audit/cases/${widget.caseId}/workpapers'), headers: _h);
      if (wR.statusCode == 200) _workpapers = jsonDecode(wR.body)['data'] ?? [];
      final fR = await http.get(Uri.parse('$_api/audit/cases/${widget.caseId}/findings'), headers: _h);
      if (fR.statusCode == 200) _findings = jsonDecode(fR.body)['data'] ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override void dispose() { _tabC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: Text('ط§ظ„ظ…ط±ط§ط¬ط¹ط©: ' + widget.clientName, style: const TextStyle(color: AC.gold, fontSize: 14)),
      backgroundColor: AC.navy2,
      bottom: TabBar(controller: _tabC, isScrollable: true,
        labelColor: AC.gold, unselectedLabelColor: AC.ts, indicatorColor: AC.gold,
        tabs: _stages.map((s) => Tab(icon: Icon(s['icon'] as IconData, size: 18), text: s['label'] as String)).toList()),
    ),
    body: _loading ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : TabBarView(controller: _tabC, children: [
          _stageView('ط´ط¬ط±ط© ط§ظ„ط­ط³ط§ط¨ط§طھ', 'طھط£ظƒط¯ ظ…ظ† ط§ط¹طھظ…ط§ط¯ ط´ط¬ط±ط© ط§ظ„ط­ط³ط§ط¨ط§طھ', [_card('ط§ظ„ط­ط§ظ„ط©', [_kv('ط§ظ„ط´ط¬ط±ط©', 'ظ…ط¹طھظ…ط¯ط©', vc: AC.ok)])]),
          _stageView('ظ…ظٹط²ط§ظ† ط§ظ„ظ…ط±ط§ط¬ط¹ط©', 'ط§ط±ظپط¹ ط§ظ„ظ…ظٹط²ط§ظ† ظˆطھط£ظƒط¯ ظ…ظ† ط±ط¨ط·ظ‡', [_card('ط§ظ„ط­ط§ظ„ط©', [_kv('ط§ظ„ظ…ظٹط²ط§ظ†', 'ظ…ط±ط¨ظˆط·', vc: AC.ok)])]),
          _stageView('ط¨ط±ظ†ط§ظ…ط¬ ط§ظ„ظ…ط±ط§ط¬ط¹ط©', 'ط¥ط¬ط±ط§ط،ط§طھ ط§ظ„ظ…ط±ط§ط¬ط¹ط©', [_card('ط§ظ„ط¥ط¬ط±ط§ط،ط§طھ (' + _templates.length.toString() + ')',
            _templates.isEmpty ? [const Text('ظ„ط§ طھظˆط¬ط¯ ط¥ط¬ط±ط§ط،ط§طھ', style: TextStyle(color: AC.ts))]
            : _templates.take(10).map((t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
                  color: t['risk_level'] == 'high' ? AC.err : t['risk_level'] == 'medium' ? AC.warn : AC.ok)),
                const SizedBox(width: 8),
                Expanded(child: Text(t['title_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13))),
                Text(t['risk_level'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 11)),
              ]))).toList())]),
          _stageView('ط§ظ„ط¹ظٹظ†ط§طھ', 'ط§ط®طھظٹط§ط± ط¹ظٹظ†ط§طھ ط§ظ„ظ…ط±ط§ط¬ط¹ط©', [_card('ط§ظ„ط¹ظٹظ†ط§طھ (' + _samples.length.toString() + ')',
            _samples.isEmpty ? [const Text('ظ„ظ… ظٹطھظ… ط§ط®طھظٹط§ط± ط¹ظٹظ†ط§طھ', style: TextStyle(color: AC.ts))]
            : _samples.map((s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(s['area'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13)),
                  Text((s['selected_count'] ?? 0).toString() + ' ط¹ظٹظ†ط©', style: const TextStyle(color: AC.cyan, fontSize: 12)),
                ]))).toList())]),
          _stageView('ط£ظˆط±ط§ظ‚ ط§ظ„ط¹ظ…ظ„', 'طھظˆط«ظٹظ‚ طھظ†ظپظٹط° ط§ظ„ط§ط®طھط¨ط§ط±ط§طھ', [_card('ط£ظˆط±ط§ظ‚ ط§ظ„ط¹ظ…ظ„ (' + _workpapers.length.toString() + ')',
            _workpapers.isEmpty ? [const Text('ظ„ط§ طھظˆط¬ط¯ ط£ظˆط±ط§ظ‚ ط¹ظ…ظ„', style: TextStyle(color: AC.ts))]
            : _workpapers.map((w) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AC.navy, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Icon(w['reviewer_status'] == 'approved' ? Icons.check_circle : Icons.pending,
                    color: w['reviewer_status'] == 'approved' ? AC.ok : AC.warn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(w['procedure_code'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold))),
                ]))).toList())]),
          _stageView('ط§ظ„ظ…ظ„ط§ط­ط¸ط§طھ', 'طھط¬ظ…ظٹط¹ ط§ظ„ظ…ظ„ط§ط­ط¸ط§طھ', [_card('ط§ظ„ظ…ظ„ط§ط­ط¸ط§طھ (' + _findings.length.toString() + ')',
            _findings.isEmpty ? [const Text('ظ„ط§ طھظˆط¬ط¯ ظ…ظ„ط§ط­ط¸ط§طھ', style: TextStyle(color: AC.ts))]
            : _findings.map((f) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AC.navy, borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: f['severity'] == 'critical' ? AC.err : AC.bdr)),
                child: Row(children: [
                  Expanded(child: Text(f['title_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold))),
                  _badge(f['severity'] ?? '', f['severity'] == 'critical' ? AC.err : f['severity'] == 'high' ? AC.warn : AC.ok),
                ]))).toList())]),
          _stageView('ط§ظ„طھظ‚ط±ظٹط±', 'ظ…ط³ظˆط¯ط© ط§ظ„طھظ‚ط±ظٹط± ط§ظ„ظ†ظ‡ط§ط¦ظٹ', [
            _card('ظ…ظ„ط®طµ ط§ظ„ظ…ط±ط§ط¬ط¹ط©', [
              _kv('ط§ظ„ط¥ط¬ط±ط§ط،ط§طھ', _templates.length.toString()),
              _kv('ط§ظ„ط¹ظٹظ†ط§طھ', _samples.length.toString()),
              _kv('ط£ظˆط±ط§ظ‚ ط§ظ„ط¹ظ…ظ„', _workpapers.length.toString()),
              _kv('ط§ظ„ظ…ظ„ط§ط­ط¸ط§طھ', _findings.length.toString(), vc: _findings.isNotEmpty ? AC.warn : AC.ok),
            ]),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AC.warn.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AC.warn.withOpacity(0.3))),
              child: const Row(children: [Icon(Icons.person_search, color: AC.warn, size: 20), SizedBox(width: 8),
                Expanded(child: Text('ط§ظ„طھظ‚ط±ظٹط± ظٹطھط·ظ„ط¨ ط§ط¹طھظ…ط§ط¯ ط§ظ„ظ…ط´ط±ظپ ظ‚ط¨ظ„ ط§ظ„ط¥طµط¯ط§ط±', style: TextStyle(color: AC.warn, fontSize: 12)))])),
          ]),
        ]),
  );

  Widget _stageView(String title, String subtitle, List<Widget> children) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(title, style: const TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: AC.ts, fontSize: 12)),
      const Divider(color: AC.bdr, height: 24),
      ...children,
    ]));
}
