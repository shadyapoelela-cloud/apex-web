import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _api = 'https://apex-api-ootk.onrender.com';

class AC {
  static const gold = Color(0xFFC9A84C);
  static const navy = Color(0xFF050D1A);
  static const navy2 = Color(0xFF080F1F);
  static const navy3 = Color(0xFF0D1829);
  static const navy4 = Color(0xFF0F2040);
  static const cyan = Color(0xFF00C2E0);
  static const tp = Color(0xFFF0EDE6);
  static const ts = Color(0xFF8A8880);
  static const ok = Color(0xFF2ECC8A);
  static const warn = Color(0xFFF0A500);
  static const err = Color(0xFFE05050);
  static const bdr = Color(0x26C9A84C);
}

class S {
  static String? token, uid, uname, dname, plan, email;
  static List<String> roles = [];
  static Map<String,String> h() => {'Authorization': 'Bearer ${token ?? ""}'};
  static Map<String,String> hj() => {'Authorization': 'Bearer ${token ?? ""}', 'Content-Type': 'application/json'};
}

InputDecoration _inp(String l, {IconData? ic}) => InputDecoration(
  labelText: l, prefixIcon: ic != null ? Icon(ic, color: AC.gold, size: 20) : null,
  filled: true, fillColor: AC.navy3, labelStyle: const TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold)));

Widget _card(String t, List<Widget> c, {Color? accent}) => Container(
  margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: accent ?? AC.bdr)),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(t, style: TextStyle(color: accent ?? AC.gold, fontWeight: FontWeight.bold, fontSize: 15)),
    const Divider(color: AC.bdr, height: 18), ...c]));

Widget _kv(String k, String v, {Color? vc}) => Padding(padding: const EdgeInsets.only(bottom: 5),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(k, style: const TextStyle(color: AC.ts, fontSize: 13)),
    Flexible(child: Text(v, style: TextStyle(color: vc ?? AC.tp, fontSize: 13), textAlign: TextAlign.end))]));

Widget _badge(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
  child: Text(t, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)));

// ═══════════════════════════════════════════════════
class ReviewerConsoleScreen extends StatefulWidget {
  const ReviewerConsoleScreen({super.key});
  @override State<ReviewerConsoleScreen> createState() => _RevCS();
}
class _RevCS extends State<ReviewerConsoleScreen> {
  List _items = []; bool _ld = true; String _filter = 'all';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/admin/knowledge-feedback'), headers: S.h());
      if(mounted) setState(() { try { _items = jsonDecode(r.body); } catch(_) { _items = []; } _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  Future<void> _review(String id, String decision) async {
    await http.post(Uri.parse('$_api/admin/knowledge-feedback/$id/review'),
      headers: {'Authorization':'Bearer ${S.token}','Content-Type':'application/json'},
      body: jsonEncode({'decision': decision}));
    _load();
  }
  List get _filtered => _filter == 'all' ? _items : _items.where((i) => i['status'] == _filter).toList();
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u0644\u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      Column(children: [
        // Filter chips
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12),
          child: Row(children: ['all','submitted','under_review','accepted','rejected'].map((f) =>
            Padding(padding: const EdgeInsets.only(left: 6), child: FilterChip(
              selected: _filter == f, onSelected: (_) => setState(()=> _filter = f),
              label: Text(f == 'all' ? '\u0627\u0644\u0643\u0644' : f == 'submitted' ? '\u0645\u0642\u062f\u0645\u0629' : f == 'under_review' ? '\u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629' : f == 'accepted' ? '\u0645\u0642\u0628\u0648\u0644\u0629' : '\u0645\u0631\u0641\u0648\u0636\u0629',
                style: TextStyle(color: _filter == f ? AC.navy : AC.tp, fontSize: 12)),
              selectedColor: AC.gold, backgroundColor: AC.navy3,
              side: BorderSide(color: _filter == f ? AC.gold : AC.bdr)))).toList())),
        // Items list
        Expanded(child: _filtered.isEmpty ?
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.inbox_outlined, color: AC.ts, size: 50), const SizedBox(height: 10),
            const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0644\u0627\u062d\u0638\u0627\u062a', style: TextStyle(color: AC.ts))])) :
          RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final item = _filtered[i];
              final status = item['status'] ?? 'submitted';
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(item['title']??'', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14))),
                    _badge(status == 'submitted' ? '\u0645\u0642\u062f\u0645\u0629' : status == 'accepted' ? '\u0645\u0642\u0628\u0648\u0644\u0629' : status == 'rejected' ? '\u0645\u0631\u0641\u0648\u0636\u0629' : status,
                      status == 'accepted' ? AC.ok : status == 'rejected' ? AC.err : AC.warn)]),
                  const SizedBox(height: 6),
                  Text(item['feedback_type']??'', style: const TextStyle(color: AC.cyan, fontSize: 11)),
                  if(item['description']!=null && item['description'].toString().isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(item['description'], style: const TextStyle(color: AC.ts, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis)),
                  Text('\u0628\u0648\u0627\u0633\u0637\u0629: ${item['submitted_by_name']??item['submitted_by']??''}', style: const TextStyle(color: AC.ts, fontSize: 10)),
                  if(status == 'submitted') ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AC.ok, padding: const EdgeInsets.symmetric(vertical: 8)),
                        onPressed: ()=> _review(item['id']??item['feedback_id']??'', 'accepted'),
                        icon: const Icon(Icons.check, size: 16), label: const Text('\u0642\u0628\u0648\u0644', style: TextStyle(fontSize: 12)))),
                      const SizedBox(width: 8),
                      Expanded(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AC.err, padding: const EdgeInsets.symmetric(vertical: 8)),
                        onPressed: ()=> _review(item['id']??item['feedback_id']??'', 'rejected'),
                        icon: const Icon(Icons.close, size: 16), label: const Text('\u0631\u0641\u0636', style: TextStyle(fontSize: 12)))),
                    ])],
                ]));
            })))
      ]));
}

// ═══════════════════════════════════════════════════
// PROVIDER VERIFICATION QUEUE
// ═══════════════════════════════════════════════════
class ProviderVerificationScreen extends StatefulWidget {
  const ProviderVerificationScreen({super.key});
  @override State<ProviderVerificationScreen> createState() => _PVS();
}
class _PVS extends State<ProviderVerificationScreen> {
  List _provs = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/admin/providers'), headers: S.h());
      if(mounted) setState(() { try { _provs = jsonDecode(r.body); } catch(_) { _provs = []; } _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  Future<void> _action(String id, String action) async {
    await http.post(Uri.parse('$_api/admin/providers/$id/$action'), headers: S.h());
    _load();
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u062a\u062d\u0642\u0642 \u0645\u0642\u062f\u0645\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _provs.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.verified_user_outlined, color: AC.ts, size: 50), const SizedBox(height: 10),
        const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u062a\u062d\u0642\u0642', style: TextStyle(color: AC.ts))])) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
        padding: const EdgeInsets.all(12), itemCount: _provs.length,
        itemBuilder: (_, i) {
          final p = _provs[i];
          final vStatus = p['verification_status'] ?? 'pending';
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(backgroundColor: AC.navy4, radius: 20,
                  child: Text((p['display_name']??p['username']??'?')[0], style: const TextStyle(color: AC.gold, fontSize: 16))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['display_name']??p['username']??'', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(p['category']??'', style: const TextStyle(color: AC.cyan, fontSize: 11))])),
                _badge(vStatus == 'approved' ? '\u0645\u0639\u062a\u0645\u062f' : vStatus == 'pending' ? '\u0642\u064a\u062f \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631' : vStatus,
                  vStatus == 'approved' ? AC.ok : vStatus == 'rejected' ? AC.err : AC.warn)]),
              if(p['service_scopes']!=null) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: (p['service_scopes'] as List).map((s) =>
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AC.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(s['name_ar']??s['code']??'', style: const TextStyle(color: AC.cyan, fontSize: 10)))).toList())],
              if(p['required_documents']!=null) ...[
                const SizedBox(height: 6),
                Text('\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a: ${(p['required_documents'] as List).join(", ")}', style: const TextStyle(color: AC.ts, fontSize: 10))],
              if(vStatus == 'pending') ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AC.ok, padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: ()=> _action(p['provider_id']??p['id']??'', 'approve'),
                    icon: const Icon(Icons.check, size: 16), label: const Text('\u0627\u0639\u062a\u0645\u0627\u062f', style: TextStyle(fontSize: 12)))),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AC.err, padding: const EdgeInsets.symmetric(vertical: 8)),
                    onPressed: ()=> _action(p['provider_id']??p['id']??'', 'reject'),
                    icon: const Icon(Icons.close, size: 16), label: const Text('\u0631\u0641\u0636', style: TextStyle(fontSize: 12)))),
                ])],
            ]));
        })));
}

// ═══════════════════════════════════════════════════
// POLICY MANAGEMENT
// ═══════════════════════════════════════════════════
class PolicyManagementScreen extends StatefulWidget {
  const PolicyManagementScreen({super.key});
  @override State<PolicyManagementScreen> createState() => _PMS();
}
class _PMS extends State<PolicyManagementScreen> {
  List _policies = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/legal/policies'), headers: S.h());
      if(mounted) setState(() { try { _policies = jsonDecode(r.body); } catch(_) { _policies = []; } _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: const Text('\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold)) :
      _policies.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.policy_outlined, color: AC.ts, size: 50), const SizedBox(height: 10),
        const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0633\u064a\u0627\u0633\u0627\u062a', style: TextStyle(color: AC.ts))])) :
      ListView.builder(padding: const EdgeInsets.all(14), itemCount: _policies.length,
        itemBuilder: (_, i) {
          final p = _policies[i];
          return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_policyIcon(p['policy_type']??''), color: AC.gold, size: 24),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['title_ar']??p['title']??p['policy_type']??'', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('\u0627\u0644\u0625\u0635\u062f\u0627\u0631: ${p['version']??'1.0'}', style: const TextStyle(color: AC.ts, fontSize: 11))])),
                _badge(p['is_active']==true?'\u0641\u0639\u0627\u0644':'\u063a\u064a\u0631 \u0641\u0639\u0627\u0644', p['is_active']==true?AC.ok:AC.ts)]),
              if(p['summary_ar']!=null || p['content_preview']!=null) ...[
                const SizedBox(height: 8),
                Text(p['summary_ar']??p['content_preview']??'', style: const TextStyle(color: AC.ts, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis)],
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.calendar_today, color: AC.ts, size: 12), const SizedBox(width: 4),
                Text(p['effective_date']?.toString().substring(0,10)??p['created_at']?.toString().substring(0,10)??'', style: const TextStyle(color: AC.ts, fontSize: 10)),
                const Spacer(),
                if(p['acceptance_count']!=null) Text('\u0645\u0648\u0627\u0641\u0642\u0627\u062a: ${p['acceptance_count']}', style: const TextStyle(color: AC.ts, fontSize: 10)),
              ]),
            ]));
        }));

  IconData _policyIcon(String t) {
    if(t.contains('terms')) return Icons.description;
    if(t.contains('privacy')) return Icons.privacy_tip;
    if(t.contains('provider')) return Icons.work;
    if(t.contains('acceptable')) return Icons.rule;
    return Icons.policy;
  }
}


// ============================================================
// Legal Acceptance Screen (Execution Master §15)
// ============================================================
class LegalAcceptanceScreen extends StatefulWidget {
  final VoidCallback onAccepted;
  const LegalAcceptanceScreen({Key? key, required this.onAccepted}) : super(key: key);
  @override State<LegalAcceptanceScreen> createState() => _LegalAcceptanceScreenState();
}

class _LegalAcceptanceScreenState extends State<LegalAcceptanceScreen> {
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _usageAccepted = false;
  bool _loading = false;

  bool get _allAccepted => _termsAccepted && _privacyAccepted && _usageAccepted;

  Future<void> _submit() async {
    if (!_allAccepted) return;
    setState(() => _loading = true);
    try {
      await http.post(Uri.parse('https://apex-api-ootk.onrender.com/legal/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'document_type': 'terms', 'version': '1.0'}));
      await http.post(Uri.parse('https://apex-api-ootk.onrender.com/legal/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'document_type': 'privacy', 'version': '1.0'}));
      await http.post(Uri.parse('https://apex-api-ootk.onrender.com/legal/accept'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'document_type': 'acceptable_use', 'version': '1.0'}));
      widget.onAccepted();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('الشروط والأحكام'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Color(0xFF856404)),
              const SizedBox(width: 12),
              const Expanded(child: Text('يجب الموافقة على جميع الشروط والسياسات قبل إكمال التسجيل',
                style: TextStyle(color: Color(0xFF856404), fontSize: 13))),
            ]),
          ),
          const SizedBox(height: 24),

          _buildPolicyCard('شروط وأحكام المنصة', 'الإصدار 1.0',
            'تتضمن شروط استخدام المنصة والتزامات المستخدم وحقوق المنصة في تعليق الحسابات عند المخالفة.',
            Icons.description, _termsAccepted, (v) => setState(() => _termsAccepted = v!)),

          _buildPolicyCard('سياسة الخصوصية', 'الإصدار 1.0',
            'كيفية جمع واستخدام وحماية بياناتك الشخصية والمالية.',
            Icons.privacy_tip, _privacyAccepted, (v) => setState(() => _privacyAccepted = v!)),

          _buildPolicyCard('سياسة الاستخدام المقبول', 'الإصدار 1.0',
            'القواعد المنظمة لاستخدام المنصة بما يشمل رفع الملفات والتحليلات وطلب الخدمات.',
            Icons.verified_user, _usageAccepted, (v) => setState(() => _usageAccepted = v!)),

          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _allAccepted && !_loading ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _allAccepted ? AC.gold : Colors.grey,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('أوافق وأتابع', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  Widget _buildPolicyCard(String title, String version, String desc, IconData icon, bool value, ValueChanged<bool?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? AC.gold : const Color(0xFFE0E0E0), width: value ? 2 : 1),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: AC.navy, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1B2A4A))),
            Text(version, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
          ])),
        ]),
        const SizedBox(height: 8),
        Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          Checkbox(value: value, onChanged: onChanged, activeColor: AC.gold),
          const Text('أوافق على هذه السياسة', style: TextStyle(fontSize: 13)),
          const Spacer(),
          TextButton(onPressed: () {}, child: const Text('قراءة كاملة', style: TextStyle(color: Color(0xFF1B2A4A)))),
        ]),
      ]),
    );
  }
}

// ============================================================
// Client Type Selection Screen (Execution Master §5)
// ============================================================
class ClientTypeSelectionScreen extends StatefulWidget {
  final Function(String) onSelected;
  const ClientTypeSelectionScreen({Key? key, required this.onSelected}) : super(key: key);
  @override State<ClientTypeSelectionScreen> createState() => _ClientTypeSelectionScreenState();
}

class _ClientTypeSelectionScreenState extends State<ClientTypeSelectionScreen> {
  String? _selected;

  final _types = [
    {'id': 'standard_business', 'name': 'منشأة تجارية', 'icon': Icons.business, 'km': false,
     'desc': 'شركة أو مؤسسة تجارية تستخدم خدمات التحليل'},
    {'id': 'accounting_firm', 'name': 'مكتب محاسبة', 'icon': Icons.calculate, 'km': true,
     'desc': 'مكتب محاسبة قانوني معتمد'},
    {'id': 'audit_firm', 'name': 'مكتب تدقيق', 'icon': Icons.fact_check, 'km': true,
     'desc': 'مكتب تدقيق ومراجعة'},
    {'id': 'financial_entity', 'name': 'جهة مالية', 'icon': Icons.account_balance, 'km': true,
     'desc': 'بنك أو مؤسسة مالية'},
    {'id': 'investment_entity', 'name': 'جهة استثمارية', 'icon': Icons.trending_up, 'km': true,
     'desc': 'شركة أو صندوق استثماري'},
    {'id': 'government_entity', 'name': 'جهة حكومية', 'icon': Icons.account_balance_wallet, 'km': true,
     'desc': 'جهة حكومية أو شبه حكومية'},
    {'id': 'legal_regulatory_entity', 'name': 'جهة قانونية/تنظيمية', 'icon': Icons.gavel, 'km': true,
     'desc': 'هيئة تنظيمية أو مكتب قانوني'},
    {'id': 'sector_consulting_entity', 'name': 'استشارات قطاعية', 'icon': Icons.lightbulb, 'km': true,
     'desc': 'شركة استشارات متخصصة'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('اختيار نوع العميل'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16), color: const Color(0xFFF0F4FF),
          child: const Text('اختر نوع المنشأة — هذا يحدد الخدمات والصلاحيات المتاحة',
            style: TextStyle(color: Color(0xFF1B2A4A), fontSize: 13), textAlign: TextAlign.center),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _types.length,
            itemBuilder: (ctx, i) {
              final t = _types[i];
              final selected = _selected == t['id'];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? AC.gold : const Color(0xFFE0E0E0), width: selected ? 2 : 1),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: selected ? AC.gold.withOpacity(0.15) : const Color(0xFFF5F5F5),
                    child: Icon(t['icon'] as IconData, color: selected ? AC.gold : AC.navy, size: 24),
                  ),
                  title: Text(t['name'] as String, style: TextStyle(
                    fontWeight: FontWeight.bold, color: selected ? AC.navy : Colors.black87)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 4),
                    Text(t['desc'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    if (t['km'] == true) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                        child: const Text('مؤهل للعقل المعرفي', style: TextStyle(fontSize: 10, color: Color(0xFF2E7D32))),
                      ),
                    ],
                  ]),
                  trailing: selected
                    ? const Icon(Icons.check_circle, color: Color(0xFFD4A843))
                    : const Icon(Icons.radio_button_unchecked, color: Color(0xFFBDBDBD)),
                  onTap: () => setState(() => _selected = t['id'] as String),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _selected != null ? () => widget.onSelected(_selected!) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _selected != null ? AC.gold : Colors.grey,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('تأكيد واستمرار', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// Provider Document Upload Screen (Execution Master §7)
// ============================================================
class ProviderDocumentUploadScreen extends StatefulWidget {
  const ProviderDocumentUploadScreen({Key? key}) : super(key: key);
  @override State<ProviderDocumentUploadScreen> createState() => _ProviderDocumentUploadScreenState();
}

class _ProviderDocumentUploadScreenState extends State<ProviderDocumentUploadScreen> {
  final _docs = [
    {'type': 'identity', 'name': 'إثبات الهوية', 'icon': Icons.badge, 'required': true, 'uploaded': false},
    {'type': 'professional_license', 'name': 'الرخصة المهنية', 'icon': Icons.card_membership, 'required': true, 'uploaded': false},
    {'type': 'academic_certificate', 'name': 'الشهادة الأكاديمية', 'icon': Icons.school, 'required': true, 'uploaded': false},
    {'type': 'experience_letter', 'name': 'خطاب الخبرة', 'icon': Icons.work_history, 'required': false, 'uploaded': false},
    {'type': 'portfolio', 'name': 'نماذج أعمال', 'icon': Icons.folder_special, 'required': false, 'uploaded': false},
  ];

  @override
  Widget build(BuildContext context) {
    final requiredCount = _docs.where((d) => d['required'] == true).length;
    final uploadedRequired = _docs.where((d) => d['required'] == true && d['uploaded'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('مستندات التحقق'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          color: uploadedRequired == requiredCount ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3CD),
          child: Row(children: [
            Icon(uploadedRequired == requiredCount ? Icons.check_circle : Icons.warning,
              color: uploadedRequired == requiredCount ? const Color(0xFF2E7D32) : const Color(0xFF856404)),
            const SizedBox(width: 12),
            Expanded(child: Text(
              uploadedRequired == requiredCount
                ? 'جميع المستندات الإلزامية مرفوعة — في انتظار المراجعة'
                : 'يجب رفع المستندات الإلزامية (*) للتحقق وتفعيل حسابك',
              style: TextStyle(fontSize: 13, color: uploadedRequired == requiredCount ? const Color(0xFF2E7D32) : const Color(0xFF856404)))),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _docs.length,
            itemBuilder: (ctx, i) {
              final doc = _docs[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : const Color(0xFFE0E0E0)),
                ),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: doc['uploaded'] == true ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                    child: Icon(doc['icon'] as IconData,
                      color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : AC.navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(doc['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (doc['required'] == true) const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ]),
                    Text(doc['uploaded'] == true ? 'تم الرفع — قيد المراجعة' : 'لم يتم الرفع',
                      style: TextStyle(fontSize: 12, color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : Colors.grey)),
                  ])),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _docs[i] = {...doc, 'uploaded': true}),
                    icon: Icon(doc['uploaded'] == true ? Icons.refresh : Icons.upload_file, size: 16),
                    label: Text(doc['uploaded'] == true ? 'تحديث' : 'رفع', style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: doc['uploaded'] == true ? Colors.grey[200] : AC.navy,
                      foregroundColor: doc['uploaded'] == true ? Colors.black87 : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: uploadedRequired == requiredCount ? () => Navigator.pop(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: uploadedRequired == requiredCount ? AC.gold : Colors.grey,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(uploadedRequired == requiredCount ? 'إرسال للمراجعة' : 'أكمل رفع المستندات الإلزامية',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// Task Document Management Screen (Zero Ambiguity §9)
// ============================================================
class TaskDocumentScreen extends StatefulWidget {
  final String requestId;
  final String taskType;
  const TaskDocumentScreen({Key? key, required this.requestId, this.taskType = 'bookkeeping'}) : super(key: key);
  @override State<TaskDocumentScreen> createState() => _TaskDocumentScreenState();
}

class _TaskDocumentScreenState extends State<TaskDocumentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  final _inputs = [
    {'name': 'مصادر القيود', 'uploaded': true, 'date': '2026-03-28'},
    {'name': 'كشف حساب بنكي', 'uploaded': true, 'date': '2026-03-29'},
    {'name': 'فواتير', 'uploaded': false, 'date': null},
  ];
  final _outputs = [
    {'name': 'ملف قيود منظم', 'uploaded': false, 'date': null},
    {'name': 'ملاحظات التسوية', 'uploaded': false, 'date': null},
  ];

  @override
  void initState() { super.initState(); _tabs = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final inputsDone = _inputs.where((d) => d['uploaded'] == true).length;
    final outputsDone = _outputs.where((d) => d['uploaded'] == true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('مستندات المهمة'),
        backgroundColor: AC.navy, foregroundColor: Colors.white,
        bottom: TabBar(controller: _tabs, indicatorColor: AC.gold, labelColor: Colors.white, tabs: [
          Tab(text: 'المدخلات ($inputsDone/${_inputs.length})'),
          Tab(text: 'المخرجات ($outputsDone/${_outputs.length})'),
        ]),
      ),
      body: Column(children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          color: inputsDone == _inputs.length && outputsDone == _outputs.length
            ? const Color(0xFFE8F5E9) : const Color(0xFFFCE4EC),
          child: Row(children: [
            const Icon(Icons.timer, size: 16, color: Color(0xFFD32F2F)),
            const SizedBox(width: 8),
            const Text('الموعد النهائي: 15 أبريل 2026', style: TextStyle(fontSize: 12, color: Color(0xFFD32F2F))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: inputsDone == _inputs.length ? const Color(0xFF2ECC8A) : const Color(0xFFFF9800),
                borderRadius: BorderRadius.circular(8)),
              child: Text(inputsDone == _inputs.length ? 'مكتمل' : 'ناقص',
                style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ]),
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            _buildDocList(_inputs, 'input'),
            _buildDocList(_outputs, 'output'),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDocList(List<Map<String, dynamic>> docs, String category) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final doc = docs[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : const Color(0xFFFFCDD2)),
          ),
          child: Row(children: [
            Icon(doc['uploaded'] == true ? Icons.check_circle : Icons.error_outline,
              color: doc['uploaded'] == true ? const Color(0xFF2ECC8A) : const Color(0xFFD32F2F)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(doc['uploaded'] == true ? 'تم الرفع: ${doc['date']}' : 'مطلوب — لم يتم الرفع',
                style: TextStyle(fontSize: 12, color: doc['uploaded'] == true ? Colors.green : Colors.red)),
            ])),
            if (doc['uploaded'] != true)
              ElevatedButton.icon(
                onPressed: () => setState(() => docs[i] = {...doc, 'uploaded': true, 'date': '2026-03-30'}),
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('رفع'),
                style: ElevatedButton.styleFrom(backgroundColor: AC.navy, foregroundColor: Colors.white),
              ),
          ]),
        );
      },
    );
  }
}

// ============================================================
// Provider Compliance Status Screen (Zero Ambiguity §9)
// ============================================================
class ProviderComplianceScreen extends StatelessWidget {
  const ProviderComplianceScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('حالة الامتثال'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B2A4A), Color(0xFF2C3E6B)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              const Icon(Icons.verified, color: Color(0xFF2ECC8A), size: 48),
              const SizedBox(height: 12),
              const Text('حالة الحساب: نشط', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF2ECC8A), borderRadius: BorderRadius.circular(20)),
                child: const Text('لا توجد مخالفات', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Compliance Metrics
          const Text('مؤشرات الامتثال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _metricCard('المهام المكتملة', '12', Icons.task_alt, const Color(0xFF2ECC8A)),
          _metricCard('المستندات المرفوعة', '8/8', Icons.description, const Color(0xFF2ECC8A)),
          _metricCard('المخالفات', '0', Icons.warning, const Color(0xFF2ECC8A)),
          _metricCard('التعليقات السابقة', '0', Icons.block, const Color(0xFF2ECC8A)),
          _metricCard('تقييم الأداء', '4.8/5', Icons.star, const Color(0xFFD4A843)),

          const SizedBox(height: 20),
          const Text('سجل الامتثال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              const Icon(Icons.check_circle, color: Color(0xFF2ECC8A), size: 40),
              const SizedBox(height: 8),
              const Text('سجل نظيف', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const Text('لا توجد مخالفات أو تعليقات سابقة', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        ]),
      ),
    );
  }

  static Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
      ]),
    );
  }
}

// ============================================================
// Activity History Screen (Execution Master §9)
// ============================================================
class ActivityHistoryScreen extends StatelessWidget {
  const ActivityHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activities = [
      {'action': 'تحليل مالي', 'detail': 'رفع ميزان مراجعة - retail', 'time': 'اليوم 11:30', 'icon': Icons.analytics, 'color': const Color(0xFF1B2A4A)},
      {'action': 'تحميل تقرير PDF', 'detail': 'تقرير التحليل المالي', 'time': 'اليوم 11:45', 'icon': Icons.picture_as_pdf, 'color': const Color(0xFF2ECC8A)},
      {'action': 'إنشاء عميل', 'detail': 'شركة التقنية المتقدمة', 'time': 'أمس 14:00', 'icon': Icons.person_add, 'color': const Color(0xFFD4A843)},
      {'action': 'طلب خدمة', 'detail': 'مسك دفاتر - شهري', 'time': 'أمس 15:30', 'icon': Icons.shopping_cart, 'color': const Color(0xFF9C27B0)},
      {'action': 'ملاحظة معرفية', 'detail': 'تحسين تبويب الإيرادات', 'time': '28 مارس', 'icon': Icons.lightbulb, 'color': const Color(0xFFFF9800)},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(title: const Text('سجل النشاط'), backgroundColor: AC.navy, foregroundColor: Colors.white),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activities.length,
        itemBuilder: (ctx, i) {
          final a = activities[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: (a['color'] as Color).withOpacity(0.1),
                radius: 20,
                child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a['action'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(a['detail'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ])),
              Text(a['time'] as String, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]),
          );
        },
      ),
    );
  }
}




// ═══════════════════════════════════════════════════════
// Result Detail Panel — ! icon explanation (Execution §6)
// ═══════════════════════════════════════════════════════
class ResultDetailPanel extends StatefulWidget {
  final String analysisId;
  final String resultKey;
  const ResultDetailPanel({super.key, required this.analysisId, required this.resultKey});
  @override State<ResultDetailPanel> createState() => _ResultDetailPanelS();
}
class _ResultDetailPanelS extends State<ResultDetailPanel> {
  Map<String, dynamic>? _detail;
  bool _loading = true;
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/results/${widget.analysisId}/details'),
        headers: S.h());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        final details = data['details'] as List? ?? [];
        for (var d in details) {
          if (d['result_key'] == widget.resultKey) {
            setState(() { _detail = d; _loading = false; });
            return;
          }
        }
      }
      setState(() => _loading = false);
    } catch (e) { setState(() => _loading = false); }
  }
  
  @override Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(12)),
    child: _loading 
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : _detail == null 
        ? const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u062a\u0641\u0627\u0635\u064a\u0644 \u0645\u062a\u0627\u062d\u0629', style: TextStyle(color: AC.tp))
        : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.info_outline, color: AC.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_detail!['summary_ar'] ?? _detail!['result_key'] ?? '',
                style: const TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 12),
            if (_detail!['source_rows'] != null) ...[
              const Text('\u0627\u0644\u0635\u0641\u0648\u0641 \u0627\u0644\u0645\u0635\u062f\u0631\u064a\u0629:', style: TextStyle(color: AC.cyan, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_detail!['source_rows'], style: const TextStyle(color: AC.tp, fontSize: 12)),
              const SizedBox(height: 8),
            ],
            if (_detail!['applied_rules'] != null) ...[
              const Text('\u0627\u0644\u0642\u0648\u0627\u0639\u062f \u0627\u0644\u0645\u0637\u0628\u0642\u0629:', style: TextStyle(color: AC.cyan, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_detail!['applied_rules'], style: const TextStyle(color: AC.tp, fontSize: 12)),
              const SizedBox(height: 8),
            ],
            Row(children: [
              _chip('\u0627\u0644\u062b\u0642\u0629: ${((_detail!['confidence'] ?? 0) * 100).toStringAsFixed(0)}%', AC.ok),
              const SizedBox(width: 8),
              if (_detail!['feedback_count'] != null && _detail!['feedback_count'] > 0)
                _chip('\u0645\u0644\u0627\u062d\u0638\u0627\u062a: ${_detail!['feedback_count']}', AC.cyan),
            ]),
            if (_detail!['warnings'] != null) ...[
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(
                color: const Color(0x33F39C12), borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.warning_amber, color: Color(0xFFF39C12), size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_detail!['warnings'], style: const TextStyle(color: Color(0xFFF39C12), fontSize: 12))),
                ])),
            ],
          ]),
  );
  
  Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
    child: Text(t, style: TextStyle(color: c, fontSize: 11)));
}

// Result Detail Dialog — triggered by ! icon
void showResultDetail(BuildContext context, String analysisId, String resultKey) {
  showModalBottomSheet(
    context: context, backgroundColor: AC.navy2,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (c) => Padding(
      padding: const EdgeInsets.all(16),
      child: ResultDetailPanel(analysisId: analysisId, resultKey: resultKey),
    ),
  );
}


// ═══════════════════════════════════════════════════════
// Task Document Management (Execution §8)
// ═══════════════════════════════════════════════════════
class TaskDocumentManagementScreen extends StatefulWidget {
  final String taskId;
  final String taskTypeCode;
  const TaskDocumentManagementScreen({super.key, required this.taskId, required this.taskTypeCode});
  @override State<TaskDocumentManagementScreen> createState() => _TaskDocMgmtS();
}
class _TaskDocMgmtS extends State<TaskDocumentManagementScreen> {
  Map<String, dynamic>? _taskType;
  List<dynamic> _submissions = [];
  bool _loading = true;
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Load task type requirements
      final r1 = await http.get(Uri.parse('$_api/task-types/${widget.taskTypeCode}'));
      if (r1.statusCode == 200) _taskType = jsonDecode(r1.body);
      
      // Load existing submissions
      final r2 = await http.get(Uri.parse('$_api/task-submissions/${widget.taskId}'),
        headers: S.h());
      if (r2.statusCode == 200) _submissions = jsonDecode(r2.body);
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  bool _isUploaded(String reqId) => _submissions.any((s) => s['requirement_id'] == reqId && s['status'] == 'uploaded');
  
  Future<void> _upload(String reqId, String docName) async {
    // Simulate upload — in production, use file picker
    try {
      final r = await http.post(Uri.parse('$_api/task-submissions'),
        headers: {...S.h(), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_task_id': widget.taskId,
          'requirement_id': reqId,
          'file_name': '$docName.pdf',
        }));
      if (r.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u062a\u0645 \u0631\u0641\u0639 $docName'), backgroundColor: const Color(0xFF2ECC8A)));
        _load();
      }
    } catch (e) { /* handle */ }
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: const Text('\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u0645\u0647\u0645\u0629', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: const IconThemeData(color: AC.gold)),
    body: _loading 
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : _taskType == null
        ? const Center(child: Text('\u0644\u0645 \u064a\u062a\u0645 \u0627\u0644\u0639\u062b\u0648\u0631 \u0639\u0644\u0649 \u0646\u0648\u0639 \u0627\u0644\u0645\u0647\u0645\u0629', style: TextStyle(color: AC.tp)))
        : ListView(padding: const EdgeInsets.all(16), children: [
            // Task type header
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
              color: AC.navy2, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_taskType!['name_ar'] ?? '', style: const TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_taskType!['code'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 12)),
              ])),
            const SizedBox(height: 16),
            
            // Input Requirements
            const Text('\u0627\u0644\u0645\u062f\u062e\u0644\u0627\u062a \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629', style: TextStyle(color: AC.cyan, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_taskType!['input_requirements'] as List? ?? []).map((req) => _docTile(req, true)),
            
            const SizedBox(height: 20),
            
            // Output Requirements
            const Text('\u0627\u0644\u0645\u062e\u0631\u062c\u0627\u062a \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629', style: TextStyle(color: Color(0xFFF39C12), fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(_taskType!['output_requirements'] as List? ?? []).map((req) => _docTile(req, false)),
            
            const SizedBox(height: 20),
            
            // Progress
            _progressCard(),
          ]),
  );
  
  Widget _docTile(dynamic req, bool isInput) {
    final uploaded = _isUploaded(req['id']);
    final mandatory = req['is_mandatory'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy3, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: uploaded ? const Color(0xFF2ECC8A) : (mandatory ? const Color(0x33F39C12) : AC.navy4))),
      child: Row(children: [
        Icon(uploaded ? Icons.check_circle : (isInput ? Icons.upload_file : Icons.download),
          color: uploaded ? const Color(0xFF2ECC8A) : AC.gold, size: 24),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(req['name_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 14)),
          if (mandatory) const Text('* \u0625\u0644\u0632\u0627\u0645\u064a', style: TextStyle(color: Color(0xFFF39C12), fontSize: 11)),
        ])),
        if (!uploaded)
          ElevatedButton(onPressed: () => _upload(req['id'], req['name_ar'] ?? 'doc'),
            style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
            child: const Text('\u0631\u0641\u0639', style: TextStyle(fontSize: 12)))
        else
          const Text('\u2713 \u062a\u0645', style: TextStyle(color: Color(0xFF2ECC8A), fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
    );
  }
  
  Widget _progressCard() {
    final totalInputs = (_taskType!['input_requirements'] as List? ?? []).where((r) => r['is_mandatory'] == true).length;
    final totalOutputs = (_taskType!['output_requirements'] as List? ?? []).where((r) => r['is_mandatory'] == true).length;
    final uploadedInputs = (_taskType!['input_requirements'] as List? ?? []).where((r) => _isUploaded(r['id']) && r['is_mandatory'] == true).length;
    final uploadedOutputs = (_taskType!['output_requirements'] as List? ?? []).where((r) => _isUploaded(r['id']) && r['is_mandatory'] == true).length;
    final total = totalInputs + totalOutputs;
    final done = uploadedInputs + uploadedOutputs;
    final progress = total > 0 ? done / total : 0.0;
    
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(
      color: AC.navy2, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text('\u0627\u0644\u062a\u0642\u062f\u0645: $done / $total \u0645\u0633\u062a\u0646\u062f \u0625\u0644\u0632\u0627\u0645\u064a',
          style: const TextStyle(color: AC.tp, fontSize: 14)),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress, backgroundColor: AC.navy4,
          valueColor: AlwaysStoppedAnimation(progress >= 1.0 ? const Color(0xFF2ECC8A) : AC.gold)),
        const SizedBox(height: 8),
        if (progress >= 1.0)
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('\u062c\u0645\u064a\u0639 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0645\u0643\u062a\u0645\u0644\u0629'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC8A), foregroundColor: Colors.white)),
      ]));
  }
}


// ═══════════════════════════════════════════════════════
// Task Types Browser (shows all task types + requirements)
// ═══════════════════════════════════════════════════════
class TaskTypesBrowserScreen extends StatefulWidget {
  const TaskTypesBrowserScreen({super.key});
  @override State<TaskTypesBrowserScreen> createState() => _TaskTypesBrowserS();
}
class _TaskTypesBrowserS extends State<TaskTypesBrowserScreen> {
  List<dynamic> _types = [];
  bool _loading = true;
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/task-types'));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data is List) { _types = data; }
        else if (data is Map && data['task_types'] != null) { _types = data['task_types']; }
        else { _types = []; }
      }
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: const Text('\u0623\u0646\u0648\u0627\u0639 \u0627\u0644\u0645\u0647\u0627\u0645', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: const IconThemeData(color: AC.gold)),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _types.length,
          itemBuilder: (c, i) {
            final tt = _types[i];
            final inputs = tt['input_requirements'] ?? tt['input_documents'] ?? [] as List? ?? [];
            final outputs = tt['output_requirements'] ?? tt['output_documents'] ?? [] as List? ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                iconColor: AC.gold, collapsedIconColor: AC.ts,
                title: Text(tt['name_ar'] ?? '', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
                subtitle: Text('${inputs.length} \u0645\u062f\u062e\u0644 \u2022 ${outputs.length} \u0645\u062e\u0631\u062c', style: const TextStyle(color: AC.ts, fontSize: 12)),
                children: [
                  Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (inputs.isNotEmpty) ...[
                      const Text('\u0627\u0644\u0645\u062f\u062e\u0644\u0627\u062a:', style: TextStyle(color: AC.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
                      ...inputs.map((r) => Padding(padding: const EdgeInsets.only(right: 16, top: 4),
                        child: Row(children: [
                          Icon(r['is_mandatory'] == true ? Icons.star : Icons.star_border, size: 14,
                            color: r['is_mandatory'] == true ? const Color(0xFFF39C12) : AC.ts),
                          const SizedBox(width: 6),
                          Text(r['name_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13)),
                        ]))),
                    ],
                    if (outputs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('\u0627\u0644\u0645\u062e\u0631\u062c\u0627\u062a:', style: TextStyle(color: Color(0xFFF39C12), fontSize: 13, fontWeight: FontWeight.bold)),
                      ...outputs.map((r) => Padding(padding: const EdgeInsets.only(right: 16, top: 4),
                        child: Row(children: [
                          Icon(r['is_mandatory'] == true ? Icons.star : Icons.star_border, size: 14,
                            color: r['is_mandatory'] == true ? const Color(0xFFF39C12) : AC.ts),
                          const SizedBox(width: 6),
                          Text(r['name_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13)),
                        ]))),
                    ],
                  ])),
                ],
              ),
            );
          }),
  );
}


// ═══════════════════════════════════════════════════════
// Knowledge Developer Console (Zero-Ambiguity §8)
// ═══════════════════════════════════════════════════════
class KnowledgeDeveloperConsole extends StatefulWidget {
  const KnowledgeDeveloperConsole({super.key});
  @override State<KnowledgeDeveloperConsole> createState() => _KnowledgeDevConsoleS();
}
class _KnowledgeDevConsoleS extends State<KnowledgeDeveloperConsole> {
  List<dynamic> _feedbacks = [];
  bool _loading = true;
  String _filter = 'all';
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    try {
      String url = '$_api/knowledge-feedback/review-queue?status=$_filter';
      if (_filter == 'all') url = '$_api/knowledge-feedback/review-queue';
      final r = await http.get(Uri.parse(url), headers: S.h());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        _feedbacks = data is List ? data : (data['items'] ?? []);
      }
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: const Text('\u0648\u062d\u062f\u0629 \u0627\u0644\u0639\u0642\u0644 \u0627\u0644\u0645\u0639\u0631\u0641\u064a', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: const IconThemeData(color: AC.gold),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list, color: AC.gold),
          onSelected: (v) { _filter = v; _load(); },
          itemBuilder: (c) => [
            const PopupMenuItem(value: 'all', child: Text('\u0627\u0644\u0643\u0644')),
            const PopupMenuItem(value: 'submitted', child: Text('\u0645\u0631\u0633\u0644\u0629')),
            const PopupMenuItem(value: 'under_review', child: Text('\u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629')),
            const PopupMenuItem(value: 'accepted', child: Text('\u0645\u0642\u0628\u0648\u0644\u0629')),
            const PopupMenuItem(value: 'rejected', child: Text('\u0645\u0631\u0641\u0648\u0636\u0629')),
          ],
        ),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : _feedbacks.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.psychology, color: AC.ts, size: 64),
            const SizedBox(height: 16),
            const Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.ts, fontSize: 16)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _feedbacks.length,
            itemBuilder: (c, i) {
              final fb = _feedbacks[i];
              final status = fb['status'] ?? 'submitted';
              final statusColor = status == 'accepted' ? const Color(0xFF2ECC8A)
                : status == 'rejected' ? const Color(0xFFE74C3C) 
                : status == 'under_review' ? AC.cyan : AC.ts;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(12),
                  border: Border(right: BorderSide(color: statusColor, width: 3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline, color: statusColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(fb['feedback_type'] ?? '\u0645\u0644\u0627\u062d\u0638\u0629',
                      style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(status, style: TextStyle(color: statusColor, fontSize: 11))),
                  ]),
                  const SizedBox(height: 8),
                  Text(fb['content'] ?? fb['description'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Text(fb['created_at'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 11)),
                ]),
              );
            }),
  );
}


// ═══════════════════════════════════════════════════════
// Audit Log Screen (Zero-Ambiguity §3)
// ═══════════════════════════════════════════════════════
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});
  @override State<AuditLogScreen> createState() => _AuditLogS();
}
class _AuditLogS extends State<AuditLogScreen> {
  List<dynamic> _events = [];
  bool _loading = true;
  
  @override void initState() { super.initState(); _load(); }
  
  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/audit/events?limit=100'), headers: S.h());
      if (r.statusCode == 200) _events = jsonDecode(r.body);
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  IconData _actionIcon(String action) {
    if (action.contains('upload')) return Icons.upload_file;
    if (action.contains('login')) return Icons.login;
    if (action.contains('suspend')) return Icons.block;
    if (action.contains('compliance')) return Icons.gavel;
    if (action.contains('promote')) return Icons.arrow_upward;
    return Icons.event_note;
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: const Text('\u0633\u062c\u0644 \u0627\u0644\u062a\u062f\u0642\u064a\u0642', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: const IconThemeData(color: AC.gold)),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : _events.isEmpty
        ? const Center(child: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0623\u062d\u062f\u0627\u062b', style: TextStyle(color: AC.ts)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _events.length,
            itemBuilder: (c, i) {
              final e = _events[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(_actionIcon(e['action'] ?? ''), color: AC.cyan, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e['action'] ?? '', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (e['details'] != null) Text(e['details'], style: const TextStyle(color: AC.ts, fontSize: 12), maxLines: 2),
                    Text(e['created_at'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 10)),
                  ])),
                ]),
              );
            }),
  );
}


// ═══════════════════════════════════════════════════════════
// SubscriptionScreen — عرض الخطة الحالية + الترقية
// Per Execution Master §4, §9 + Zero Ambiguity §5, §6
// ═══════════════════════════════════════════════════════════