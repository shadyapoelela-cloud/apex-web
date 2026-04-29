import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

// _inp, _card, _kv helpers removed Stage 5d-3 (2026-04-29) — only used by
// the 4 orphan classes removed in this commit. Restore from git history if
// reintroducing any of those screens.

Widget _badge(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
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
      final res = await ApiService.adminKnowledgeFeedback();
      if(mounted) setState(() { _items = res.data is List ? res.data : []; _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  Future<void> _review(String id, String decision) async {
    await ApiService.adminReviewFeedback(id, {'decision': decision});
    _load();
  }
  List get _filtered => _filter == 'all' ? _items : _items.where((i) => i['status'] == _filter).toList();
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u0644\u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.gold))),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      Column(children: [
        // Filter chips
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12),
          child: Row(children: ['all','submitted','under_review','accepted','rejected'].map((f) =>
            Padding(padding: EdgeInsets.only(left: 6), child: FilterChip(
              selected: _filter == f, onSelected: (_) => setState(()=> _filter = f),
              label: Text(f == 'all' ? '\u0627\u0644\u0643\u0644' : f == 'submitted' ? '\u0645\u0642\u062f\u0645\u0629' : f == 'under_review' ? '\u0642\u064a\u062f \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629' : f == 'accepted' ? '\u0645\u0642\u0628\u0648\u0644\u0629' : '\u0645\u0631\u0641\u0648\u0636\u0629',
                style: TextStyle(color: _filter == f ? AC.navy : AC.tp, fontSize: 12)),
              selectedColor: AC.gold, backgroundColor: AC.navy2,
              side: BorderSide(color: _filter == f ? AC.gold : AC.bdr)))).toList())),
        // Items list
        Expanded(child: _filtered.isEmpty ?
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined, color: AC.ts, size: 50), SizedBox(height: 10),
            Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0644\u0627\u062d\u0638\u0627\u062a', style: TextStyle(color: AC.ts))])) :
          RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: _filtered.length,
            itemBuilder: (_, i) {
              final item = _filtered[i];
              final status = item['status'] ?? 'submitted';
              return Container(margin: EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(item['title']??'', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14))),
                    _badge(status == 'submitted' ? '\u0645\u0642\u062f\u0645\u0629' : status == 'accepted' ? '\u0645\u0642\u0628\u0648\u0644\u0629' : status == 'rejected' ? '\u0645\u0631\u0641\u0648\u0636\u0629' : status,
                      status == 'accepted' ? AC.ok : status == 'rejected' ? AC.err : AC.warn)]),
                  SizedBox(height: 6),
                  Text(item['feedback_type']??'', style: TextStyle(color: AC.cyan, fontSize: 11)),
                  if(item['description']!=null && item['description'].toString().isNotEmpty)
                    Padding(padding: EdgeInsets.only(top: 6),
                      child: Text(item['description'], style: TextStyle(color: AC.ts, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis)),
                  Text('\u0628\u0648\u0627\u0633\u0637\u0629: ${item['submitted_by_name']??item['submitted_by']??''}', style: TextStyle(color: AC.ts, fontSize: 10)),
                  if(status == 'submitted') ...[
                    SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AC.ok, padding: EdgeInsets.symmetric(vertical: 8)),
                        onPressed: ()=> _review(item['id']??item['feedback_id']??'', 'accepted'),
                        icon: Icon(Icons.check, size: 16), label: const Text('\u0642\u0628\u0648\u0644', style: TextStyle(fontSize: 12)))),
                      SizedBox(width: 8),
                      Expanded(child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AC.err, padding: EdgeInsets.symmetric(vertical: 8)),
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
      final res = await ApiService.adminProviders();
      if(mounted) setState(() { _provs = res.data is List ? res.data : []; _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  Future<void> _action(String id, String action) async {
    await ApiService.adminProviderAction(id, action);
    _load();
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u062a\u062d\u0642\u0642 \u0645\u0642\u062f\u0645\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a', style: TextStyle(color: AC.gold))),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      _provs.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_user_outlined, color: AC.ts, size: 50), SizedBox(height: 10),
        Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u062a\u062d\u0642\u0642', style: TextStyle(color: AC.ts))])) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
        padding: const EdgeInsets.all(12), itemCount: _provs.length,
        itemBuilder: (_, i) {
          final p = _provs[i];
          final vStatus = p['verification_status'] ?? 'pending';
          return Container(margin: EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(backgroundColor: AC.navy4, radius: 20,
                  child: Text((p['display_name']??p['username']??'?')[0], style: TextStyle(color: AC.gold, fontSize: 16))),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['display_name']??p['username']??'', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(p['category']??'', style: TextStyle(color: AC.cyan, fontSize: 11))])),
                _badge(vStatus == 'approved' ? '\u0645\u0639\u062a\u0645\u062f' : vStatus == 'pending' ? '\u0642\u064a\u062f \u0627\u0644\u0627\u0646\u062a\u0638\u0627\u0631' : vStatus,
                  vStatus == 'approved' ? AC.ok : vStatus == 'rejected' ? AC.err : AC.warn)]),
              if(p['service_scopes']!=null) ...[
                SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: (p['service_scopes'] as List).map((s) =>
                  Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AC.cyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(s['name_ar']??s['code']??'', style: TextStyle(color: AC.cyan, fontSize: 10)))).toList())],
              if(p['required_documents']!=null) ...[
                SizedBox(height: 6),
                Text('\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a: ${(p['required_documents'] as List).join(", ")}', style: TextStyle(color: AC.ts, fontSize: 10))],
              if(vStatus == 'pending') ...[
                SizedBox(height: 10),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AC.ok, padding: EdgeInsets.symmetric(vertical: 8)),
                    onPressed: ()=> _action(p['provider_id']??p['id']??'', 'approve'),
                    icon: Icon(Icons.check, size: 16), label: const Text('\u0627\u0639\u062a\u0645\u0627\u062f', style: TextStyle(fontSize: 12)))),
                  SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AC.err, padding: EdgeInsets.symmetric(vertical: 8)),
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
      final res = await ApiService.getLegalPolicies();
      if(mounted) setState(() { _policies = res.data is List ? res.data : []; _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a', style: TextStyle(color: AC.gold))),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      _policies.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.policy_outlined, color: AC.ts, size: 50), SizedBox(height: 10),
        Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0633\u064a\u0627\u0633\u0627\u062a', style: TextStyle(color: AC.ts))])) :
      ListView.builder(padding: const EdgeInsets.all(14), itemCount: _policies.length,
        itemBuilder: (_, i) {
          final p = _policies[i];
          return Container(margin: EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))]),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_policyIcon(p['policy_type']??''), color: AC.gold, size: 24),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p['title_ar']??p['title']??p['policy_type']??'', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('\u0627\u0644\u0625\u0635\u062f\u0627\u0631: ${p['version']??'1.0'}', style: TextStyle(color: AC.ts, fontSize: 11))])),
                _badge(p['is_active']==true?'\u0641\u0639\u0627\u0644':'\u063a\u064a\u0631 \u0641\u0639\u0627\u0644', p['is_active']==true?AC.ok:AC.ts)]),
              if(p['summary_ar']!=null || p['content_preview']!=null) ...[
                SizedBox(height: 8),
                Text(p['summary_ar']??p['content_preview']??'', style: TextStyle(color: AC.ts, fontSize: 12), maxLines: 3, overflow: TextOverflow.ellipsis)],
              SizedBox(height: 8),
              Row(children: [
                Icon(Icons.calendar_today, color: AC.ts, size: 12), SizedBox(width: 4),
                Text(p['effective_date']?.toString().substring(0,10)??p['created_at']?.toString().substring(0,10)??'', style: TextStyle(color: AC.ts, fontSize: 10)),
                Spacer(),
                if(p['acceptance_count']!=null) Text('\u0645\u0648\u0627\u0641\u0642\u0627\u062a: ${p['acceptance_count']}', style: TextStyle(color: AC.ts, fontSize: 10)),
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
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(title: Text('مستندات التحقق'), backgroundColor: AC.navy, foregroundColor: AC.tp),
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
                  color: AC.navy2, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: doc['uploaded'] == true ? AC.ok : const Color(0xFFE0E0E0)),
                  boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))],
                ),
                child: Row(children: [
                  CircleAvatar(
                    backgroundColor: doc['uploaded'] == true ? Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                    child: Icon(doc['icon'] as IconData,
                      color: doc['uploaded'] == true ? Color(0xFF2ECC8A) : AC.navy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(doc['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (doc['required'] == true) Text(' *', style: TextStyle(color: AC.err, fontWeight: FontWeight.bold)),
                    ]),
                    Text(doc['uploaded'] == true ? 'تم الرفع — قيد المراجعة' : 'لم يتم الرفع',
                      style: TextStyle(fontSize: 12, color: doc['uploaded'] == true ? AC.ok : AC.ts)),
                  ])),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _docs[i] = {...doc, 'uploaded': true}),
                    icon: Icon(doc['uploaded'] == true ? Icons.refresh : Icons.upload_file, size: 16),
                    label: Text(doc['uploaded'] == true ? 'تحديث' : 'رفع', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: doc['uploaded'] == true ? AC.navy4 : AC.navy,
                      foregroundColor: doc['uploaded'] == true ? AC.tp : AC.tp,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ApexTableLegend(items: [
            MapEntry('تم الرفع', AC.ok),
            MapEntry('لم يتم الرفع', AC.ts),
            MapEntry('إلزامي', AC.err),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: uploadedRequired == requiredCount ? () => Navigator.pop(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: uploadedRequired == requiredCount ? AC.gold : AC.ts,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(uploadedRequired == requiredCount ? 'إرسال للمراجعة' : 'أكمل رفع المستندات الإلزامية',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AC.btnFg)),
          ),
        ),
      ]),
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
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(title: Text('حالة الامتثال'), backgroundColor: AC.navy, foregroundColor: AC.tp),
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
              Text('حالة الحساب: نشط', style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: AC.ok, borderRadius: BorderRadius.circular(20)),
                child: Text('لا توجد مخالفات', style: TextStyle(color: AC.tp, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Compliance Metrics
          const Text('مؤشرات الامتثال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          _metricCard('المهام المكتملة', '12', Icons.task_alt, AC.ok),
          _metricCard('المستندات المرفوعة', '8/8', Icons.description, AC.ok),
          _metricCard('المخالفات', '0', Icons.warning, AC.ok),
          _metricCard('التعليقات السابقة', '0', Icons.block, AC.ok),
          _metricCard('تقييم الأداء', '4.8/5', Icons.star, const Color(0xFFD4A843)),

          const SizedBox(height: 20),
          const Text('سجل الامتثال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AC.tp, borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              const Icon(Icons.check_circle, color: Color(0xFF2ECC8A), size: 40),
              const SizedBox(height: 8),
              Text('سجل نظيف', style: TextStyle(fontSize: 14, color: AC.ts)),
              Text('لا توجد مخالفات أو تعليقات سابقة', style: TextStyle(fontSize: 12, color: AC.ts)),
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
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.15), blurRadius: 10, offset: Offset(0, 2))]),
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
      {'action': 'تحميل تقرير PDF', 'detail': 'تقرير التحليل المالي', 'time': 'اليوم 11:45', 'icon': Icons.picture_as_pdf, 'color': AC.ok},
      {'action': 'إنشاء عميل', 'detail': 'شركة التقنية المتقدمة', 'time': 'أمس 14:00', 'icon': Icons.person_add, 'color': const Color(0xFFD4A843)},
      {'action': 'طلب خدمة', 'detail': 'مسك دفاتر - شهري', 'time': 'أمس 15:30', 'icon': Icons.shopping_cart, 'color': const Color(0xFF9C27B0)},
      {'action': 'ملاحظة معرفية', 'detail': 'تحسين تبويب الإيرادات', 'time': '28 مارس', 'icon': Icons.lightbulb, 'color': const Color(0xFFFF9800)},
    ];

    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      appBar: AppBar(title: Text('سجل النشاط'), backgroundColor: AC.navy, foregroundColor: AC.tp),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: activities.length,
        itemBuilder: (ctx, i) {
          final a = activities[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.15), blurRadius: 10, offset: Offset(0, 2))]),
            child: Row(children: [
              CircleAvatar(
                backgroundColor: (a['color'] as Color).withValues(alpha: 0.1),
                radius: 20,
                child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a['action'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(a['detail'] as String, style: TextStyle(fontSize: 12, color: AC.ts)),
              ])),
              Text(a['time'] as String, style: TextStyle(fontSize: 11, color: AC.td)),
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
      final res = await ApiService.getResultDetails(widget.analysisId);
      if (res.success) {
        final details = res.data['details'] as List? ?? [];
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
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))]),
    child: _loading 
      ? Center(child: CircularProgressIndicator(color: AC.gold))
      : _detail == null 
        ? Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u062a\u0641\u0627\u0635\u064a\u0644 \u0645\u062a\u0627\u062d\u0629', style: TextStyle(color: AC.tp))
        : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Icon(Icons.info_outline, color: AC.gold, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text(_detail!['summary_ar'] ?? _detail!['result_key'] ?? '',
                style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold))),
            ]),
            SizedBox(height: 12),
            if (_detail!['source_rows'] != null) ...[
              Text('\u0627\u0644\u0635\u0641\u0648\u0641 \u0627\u0644\u0645\u0635\u062f\u0631\u064a\u0629:', style: TextStyle(color: AC.cyan, fontSize: 13)),
              SizedBox(height: 4),
              Text(_detail!['source_rows'], style: TextStyle(color: AC.tp, fontSize: 12)),
              SizedBox(height: 8),
            ],
            if (_detail!['applied_rules'] != null) ...[
              Text('\u0627\u0644\u0642\u0648\u0627\u0639\u062f \u0627\u0644\u0645\u0637\u0628\u0642\u0629:', style: TextStyle(color: AC.cyan, fontSize: 13)),
              SizedBox(height: 4),
              Text(_detail!['applied_rules'], style: TextStyle(color: AC.tp, fontSize: 12)),
              SizedBox(height: 8),
            ],
            Row(children: [
              _chip('\u0627\u0644\u062b\u0642\u0629: ${((_detail!['confidence'] ?? 0) * 100).toStringAsFixed(0)}%', AC.ok),
              SizedBox(width: 8),
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
    decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
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
      final res = await ApiService.getTaskTypes();
      if (res.success) {
        final data = res.data;
        if (data is List) { _types = data; }
        else if (data is Map && data['task_types'] != null) { _types = data['task_types']; }
        else { _types = []; }
      }
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: Text('\u0623\u0646\u0648\u0627\u0639 \u0627\u0644\u0645\u0647\u0627\u0645', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: IconThemeData(color: AC.gold)),
    body: _loading
      ? Center(child: CircularProgressIndicator(color: AC.gold))
      : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _types.length,
          itemBuilder: (c, i) {
            final tt = _types[i];
            final inputs = tt['input_requirements'] ?? tt['input_documents'] ?? [] as List? ?? [];
            final outputs = tt['output_requirements'] ?? tt['output_documents'] ?? [] as List? ?? [];
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.15), blurRadius: 10, offset: Offset(0, 2))]),
              child: ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                iconColor: AC.gold, collapsedIconColor: AC.ts,
                title: Text(tt['name_ar'] ?? '', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
                subtitle: Text('${inputs.length} \u0645\u062f\u062e\u0644 \u2022 ${outputs.length} \u0645\u062e\u0631\u062c', style: TextStyle(color: AC.ts, fontSize: 12)),
                children: [
                  Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (inputs.isNotEmpty) ...[
                      Text('\u0627\u0644\u0645\u062f\u062e\u0644\u0627\u062a:', style: TextStyle(color: AC.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
                      ...inputs.map((r) => Padding(padding: EdgeInsets.only(right: 16, top: 4),
                        child: Row(children: [
                          Icon(r['is_mandatory'] == true ? Icons.star : Icons.star_border, size: 14,
                            color: r['is_mandatory'] == true ? Color(0xFFF39C12) : AC.ts),
                          SizedBox(width: 6),
                          Text(r['name_ar'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13)),
                        ]))),
                    ],
                    if (outputs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('\u0627\u0644\u0645\u062e\u0631\u062c\u0627\u062a:', style: TextStyle(color: Color(0xFFF39C12), fontSize: 13, fontWeight: FontWeight.bold)),
                      ...outputs.map((r) => Padding(padding: EdgeInsets.only(right: 16, top: 4),
                        child: Row(children: [
                          Icon(r['is_mandatory'] == true ? Icons.star : Icons.star_border, size: 14,
                            color: r['is_mandatory'] == true ? Color(0xFFF39C12) : AC.ts),
                          SizedBox(width: 6),
                          Text(r['name_ar'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13)),
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
      final res = await ApiService.getReviewQueue(status: _filter == 'all' ? 'submitted' : _filter);
      if (res.success) {
        final data = res.data;
        _feedbacks = data is List ? data : (data is Map ? (data['items'] ?? []) : []);
      }
    } catch (e) { /* handle */ }
    setState(() => _loading = false);
  }
  
  @override Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: Text('\u0648\u062d\u062f\u0629 \u0627\u0644\u0639\u0642\u0644 \u0627\u0644\u0645\u0639\u0631\u0641\u064a', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: IconThemeData(color: AC.gold),
      actions: [
        PopupMenuButton<String>(
          icon: Icon(Icons.filter_list, color: AC.gold),
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
      ? Center(child: CircularProgressIndicator(color: AC.gold))
      : _feedbacks.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.psychology, color: AC.ts, size: 64),
            SizedBox(height: 16),
            Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.ts, fontSize: 16)),
          ]))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _feedbacks.length,
            itemBuilder: (c, i) {
              final fb = _feedbacks[i];
              final status = fb['status'] ?? 'submitted';
              final statusColor = status == 'accepted' ? Color(0xFF2ECC8A)
                : status == 'rejected' ? core_theme.AC.err 
                : status == 'under_review' ? AC.cyan : AC.ts;
              
              return Container(
                margin: EdgeInsets.only(bottom: 10),
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18),
                  border: Border(right: BorderSide(color: statusColor, width: 3)),
                  boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.15), blurRadius: 10, offset: Offset(0, 2))]),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.lightbulb_outline, color: statusColor, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text(fb['feedback_type'] ?? '\u0645\u0644\u0627\u062d\u0638\u0629',
                      style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text(status, style: TextStyle(color: statusColor, fontSize: 11))),
                  ]),
                  SizedBox(height: 8),
                  Text(fb['content'] ?? fb['description'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 6),
                  Text(fb['created_at'] ?? '', style: TextStyle(color: AC.ts, fontSize: 11)),
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
      final res = await ApiService.adminAuditEvents();
      if (res.success) _events = res.data is List ? res.data : [];
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
    appBar: AppBar(title: Text('\u0633\u062c\u0644 \u0627\u0644\u062a\u062f\u0642\u064a\u0642', style: TextStyle(color: AC.tp)),
      backgroundColor: AC.navy2, iconTheme: IconThemeData(color: AC.gold)),
    body: _loading
      ? Center(child: CircularProgressIndicator(color: AC.gold))
      : _events.isEmpty
        ? Center(child: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0623\u062d\u062f\u0627\u062b', style: TextStyle(color: AC.ts)))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _events.length,
            itemBuilder: (c, i) {
              final e = _events[i];
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.15), blurRadius: 10, offset: Offset(0, 2))]),
                child: Row(children: [
                  Icon(_actionIcon(e['action'] ?? ''), color: AC.cyan, size: 20),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e['action'] ?? '', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13)),
                    if (e['details'] != null) Text(e['details'], style: TextStyle(color: AC.ts, fontSize: 12), maxLines: 2),
                    Text(e['created_at'] ?? '', style: TextStyle(color: AC.ts, fontSize: 10)),
                  ])),
                ]),
              );
            }),
  );
}

// ─────────────────────────────────────────────────────────────────
// REMOVED Stage 5d-3 (2026-04-29) — never instantiated:
//   • LegalAcceptanceScreen (Execution Master §15)
//   • ClientTypeSelectionScreen (Execution Master §5)
//   • TaskDocumentScreen (Zero Ambiguity §9)
//   • TaskDocumentManagementScreen (Execution §8)
// Plus dangling SubscriptionScreen header comment (no class).
// Restore from git history if any of these are wired back into a route.
// ─────────────────────────────────────────────────────────────────
