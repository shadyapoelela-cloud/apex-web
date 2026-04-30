import 'package:flutter/material.dart';
import 'api_service.dart';
import 'core/theme.dart';
import 'core/ui_components.dart';
import 'core/session.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';
// Sprint-1 refactor: the root widget now lives in app/apex_app.dart.
// Re-exported so existing imports of `package:apex_finance/main.dart`
// that rely on `ApexApp` still resolve without source-level churn.
export 'app/apex_app.dart' show ApexApp;
import 'app/apex_app.dart' show ApexApp;
import 'widgets/apex_widgets.dart';
import 'widgets/main_nav.dart' show quickServiceBtn;

void main() {
  // Restore session from localStorage
  if (S.token == null) {
    final restored = S.restore();
    if (restored && S.token != null) {
      ApiService.setToken(S.token!);
    }
  }
  runApp(const ProviderScope(child: ApexApp()));
}

// AC imported from core/theme.dart
// S imported from core/session.dart



// ═══════════════════════════════════════════════════════════
// DASHBOARD
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class DashTab extends ConsumerStatefulWidget { const DashTab({super.key}); @override ConsumerState<DashTab> createState()=>_DashS(); }
class _DashS extends ConsumerState<DashTab> {
  Map<String,dynamic>? _sub; List _plans=[]; bool _ld=true; int _notifCount=0;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      ref.invalidate(currentPlanProvider);
      ref.invalidate(plansProvider);
      ref.invalidate(notificationsProvider);
      final sub = await ref.read(currentPlanProvider.future);
      final plans = await ref.read(plansProvider.future);
      final notifs = await ref.read(notificationsProvider.future);
      if(mounted) setState(() {
        _sub = sub; _plans = plans;
        _notifCount = notifs.where((n) => n['is_read'] != true).length;
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      title: Text('\u0645\u0631\u062d\u0628\u0627\u064b ${(S.dname != null && S.dname!.contains('?') ? S.uname : S.dname)??""} \u{1F44B}', style: TextStyle(color: AC.gold, fontSize: 18)),
      actions: [
        Stack(children: [
          ApexIconButton(icon: Icons.notifications_outlined, color: AC.tp,
            tooltip: 'الإشعارات', onPressed: ()=>context.go('/notifications')),
          if(_notifCount>0) Positioned(right:8,top:8, child: Container(padding: EdgeInsets.all(4),
            decoration: BoxDecoration(color: AC.err, shape: BoxShape.circle),
            child: Text('$_notifCount', style: TextStyle(color: AC.btnFg, fontSize: 10))))]),
      ]),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: EdgeInsets.all(16), children: [
        // Current Plan Card
        compactCard('\u062e\u0637\u062a\u0643 \u0627\u0644\u062d\u0627\u0644\u064a\u0629', [
          Row(children: [Icon(Icons.workspace_premium, color: AC.gold, size: 28), SizedBox(width: 10),
            Text(_sub?['plan_name_ar'] ?? S.planAr(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AC.tp)),
            Spacer(), compactBadge(_sub?['status']??'active', AC.ok)]),
          const SizedBox(height: 14),
          ...(_sub?['entitlements'] as Map<String,dynamic>? ?? {}).entries.take(6).map((e) => Padding(
            padding: EdgeInsets.only(bottom: 4), child: Row(children: [
              Icon(e.value['value']=='true'||e.value['value']=='unlimited' ? Icons.check_circle : e.value['value']=='false' ? Icons.cancel : Icons.info_outline,
                color: e.value['value']=='true'||e.value['value']=='unlimited' ? AC.ok : e.value['value']=='false' ? AC.err : AC.cyan, size: 15),
              SizedBox(width: 8),
              Expanded(child: Text('${e.key}: ${e.value['value']}', style: TextStyle(color: AC.ts, fontSize: 11)))]))),
          SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: ()=>context.push('/upgrade-plan', extra: {'plans': _plans, 'currentPlan': _sub?['plan']}),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
            icon: Icon(Icons.upgrade, color: AC.gold, size: 18),
            label: Text('\u062a\u0631\u0642\u064a\u0629 \u0627\u0644\u062e\u0637\u0629', style: TextStyle(color: AC.gold)))),
        ]),

        // ── Copilot Quick Access Card ──
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AC.gold.withValues(alpha: 0.12), AC.navy3],
              begin: Alignment.topRight, end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
          ),
          child: InkWell(
            onTap: () => context.go('/copilot'),
            borderRadius: BorderRadius.circular(14),
            child: Row(children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.smart_toy, color: AC.gold, size: 28),
              ),
              SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text('AI', style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ]),
                SizedBox(height: 4),
                Text('\u0627\u0633\u0623\u0644 \u0639\u0646 \u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a\u060c \u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644\u060c \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629\u060c \u0648\u0623\u0643\u062b\u0631', style: TextStyle(color: AC.ts, fontSize: 12)),
              ])),
              Icon(Icons.arrow_forward_ios, color: AC.gold, size: 16),
            ]),
          ),
        ),
        // ── Quick Services Row ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(children: [
              quickServiceBtn(c, '\u062a\u062d\u0644\u064a\u0644 \u0645\u0627\u0644\u064a', Icons.analytics, 2),
              quickServiceBtn(c, '\u0634\u062c\u0631\u0629 \u062d\u0633\u0627\u0628\u0627\u062a', Icons.account_tree, 1),
              quickServiceBtn(c, '\u0627\u0644\u0642\u0648\u0627\u0626\u0645 \u0627\u0644\u0645\u0627\u0644\u064a\u0629', Icons.receipt_long, 2),
              quickServiceBtn(c, '\u0633\u0648\u0642 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', Icons.store, 3),
              quickServiceBtn(c, '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', Icons.checklist, 3),
            ]),
          ),
        ),
        // Plans Grid
        Text('\u0627\u0644\u062e\u0637\u0637 \u0627\u0644\u0645\u062a\u0627\u062d\u0629', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AC.tp)),
        SizedBox(height: 8),
        ..._plans.map((p) => Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(14),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p['code']==_sub?['plan'] ? AC.gold : AC.bdr, width: p['code']==_sub?['plan'] ? 2 : 1)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text(p['name_ar']??'', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold,
                color: p['code']==_sub?['plan'] ? AC.gold : AC.tp)),
                if(p['code']==_sub?['plan']) ...[SizedBox(width:8), compactBadge('\u0627\u0644\u062d\u0627\u0644\u064a\u0629', AC.gold)]]),
              SizedBox(height: 4),
              Text(p['target_user_ar']??'', style: TextStyle(color: AC.ts, fontSize: 11))])),
            Text(p['price_monthly_sar']==0 ? '\u0645\u062c\u0627\u0646\u064a' : '${p['price_monthly_sar']} \u0631.\u0633/\u0634\u0647\u0631',
              style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold))]))),
      ])));
}



// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// CLIENTS TAB
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class ClientsTab extends ConsumerStatefulWidget { const ClientsTab({super.key}); @override ConsumerState<ClientsTab> createState()=>_ClientsS(); }
class _ClientsS extends ConsumerState<ClientsTab> {
  List _cl=[]; bool _ld=true; String _search='';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _ld = true);
    try {
      final r = await ApiService.listClients();
      if (mounted) setState(() { final d = r.data; _cl = d is List ? d : []; _ld = false; });
    } catch(e) {
      if (mounted) setState(() { _cl = []; _ld = false; });
    }
  }
  final _cName = TextEditingController();
  final _cNameAr = TextEditingController();
  final _cEmail = TextEditingController();
  final _cPhone = TextEditingController();
  final _cCR = TextEditingController();
  final _cVAT = TextEditingController();
  final _cAddress = TextEditingController();
  String _cType = '';
  String _cSector = '';
  @override void dispose() {
    _cName.dispose(); _cNameAr.dispose(); _cEmail.dispose();
    _cPhone.dispose(); _cCR.dispose(); _cVAT.dispose(); _cAddress.dispose();
    super.dispose();
  }

  Future<void> _doCreateClient(BuildContext dc) async {
    Navigator.pop(dc);
    final code = 'CL${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final name = _cNameAr.text.isNotEmpty ? _cNameAr.text : (_cName.text.isNotEmpty ? _cName.text : 'New Client');
    final typeMap = {
      '\u0643\u064a\u0627\u0646 \u0633\u0639\u0648\u062f\u064a': 'standard_business',
      '\u0627\u0633\u062a\u062b\u0645\u0627\u0631 \u0623\u062c\u0646\u0628\u064a': 'investment_entity',
      '\u0641\u0631\u0639 \u0634\u0631\u0643\u0629 \u0623\u062c\u0646\u0628\u064a\u0629': 'financial_entity',
    };
    final type = typeMap[_cType] ?? 'standard_business';
    final res = await ApiService.createClient(clientCode: code, name: _cName.text.isNotEmpty ? _cName.text : name, nameAr: _cNameAr.text.isNotEmpty ? _cNameAr.text : name, clientType: type, industry: _cSector.isNotEmpty ? _cSector : null);
    if (res.success) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0639\u0645\u064a\u0644'), backgroundColor: AC.ok));
      _load();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error ?? '\u062e\u0637\u0623'), backgroundColor: AC.err));
    }
    _cName.clear(); _cNameAr.clear(); _cEmail.clear(); _cPhone.clear(); _cCR.clear(); _cVAT.clear(); _cAddress.clear(); _cType = ''; _cSector = '';
  }


  Widget _wf(String label, TextEditingController ctrl, {bool ltr = false}) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: TextField(controller: ctrl, textDirection: ltr ? TextDirection.ltr : null,
      style: TextStyle(color: AC.tp, fontSize: 13),
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        filled: true, fillColor: AC.navy3, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AC.gold)))),
  );

  Widget _wc(String label, List<String> opts, String sel, void Function(void Function()) ss, void Function(String) onSel) => Column(
    crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: TextStyle(color: AC.ts, fontSize: 12)),
      SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: opts.map((o) =>
        ChoiceChip(label: Text(o, style: TextStyle(color: sel == o ? AC.navy : AC.tp, fontSize: 11)),
          selected: sel == o, selectedColor: AC.gold, backgroundColor: AC.navy3,
          side: BorderSide(color: sel == o ? AC.gold : AC.bdr),
          onSelected: (s) { if (s) { onSel(o); ss(() {}); } },
        )).toList()),
    ],
  );

  Widget _buildWizardStep(int step, void Function(void Function()) ss) {
    switch (step) {
      case 0:
        // Step 1: Entity Origin
        return _wc('\u0646\u0648\u0639 \u0627\u0644\u0643\u064a\u0627\u0646', [
          '\u0643\u064a\u0627\u0646 \u0633\u0639\u0648\u062f\u064a',
          '\u0627\u0633\u062a\u062b\u0645\u0627\u0631 \u0623\u062c\u0646\u0628\u064a',
          '\u0641\u0631\u0639 \u0634\u0631\u0643\u0629 \u0623\u062c\u0646\u0628\u064a\u0629',
        ], _cType, ss, (v) { _cType = v; _cSector = ''; });
      case 1:
        // Step 2: Entity Type (based on MoC + SAGIA)
        final saudiTypes = [
          '\u0634\u0631\u0643\u0629 \u0645\u0633\u0627\u0647\u0645\u0629 \u0645\u063a\u0644\u0642\u0629',
          '\u0634\u0631\u0643\u0629 \u0645\u0633\u0627\u0647\u0645\u0629 \u0645\u0641\u062a\u0648\u062d\u0629',
          '\u0634\u0631\u0643\u0629 \u0630\u0627\u062a \u0645\u0633\u0624\u0648\u0644\u064a\u0629 \u0645\u062d\u062f\u0648\u062f\u0629',
          '\u0634\u0631\u0643\u0629 \u062a\u0636\u0627\u0645\u0646\u064a\u0629',
          '\u0634\u0631\u0643\u0629 \u062a\u0648\u0635\u064a\u0629 \u0628\u0633\u064a\u0637\u0629',
          '\u0645\u0624\u0633\u0633\u0629 \u0641\u0631\u062f\u064a\u0629',
          '\u0634\u0631\u0643\u0629 \u0645\u0647\u0646\u064a\u0629',
        ];
        final foreignTypes = [
          '\u0634\u0631\u0643\u0629 \u0630\u0627\u062a \u0645\u0633\u0624\u0648\u0644\u064a\u0629 \u0645\u062d\u062f\u0648\u062f\u0629 (\u0623\u062c\u0646\u0628\u064a)',
          '\u0641\u0631\u0639 \u0634\u0631\u0643\u0629 \u0623\u062c\u0646\u0628\u064a\u0629',
          '\u0645\u0643\u062a\u0628 \u062a\u0645\u062b\u064a\u0644\u064a',
          '\u0645\u0634\u0631\u0648\u0639 \u0645\u0634\u062a\u0631\u0643',
        ];
        final types = _cType.contains('\u0623\u062c\u0646\u0628') ? foreignTypes : saudiTypes;
        return _wc('\u0627\u0644\u0634\u0643\u0644 \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a', types, _cSector, ss, (v) => _cSector = v);
      case 2:
        // Step 3: Basic Info
        return Column(children: [
          _wf('\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629 (\u0639\u0631\u0628\u064a)', _cNameAr),
          _wf('\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629 (\u0625\u0646\u062c\u0644\u064a\u0632\u064a)', _cName, ltr: true),
          _wf('\u0631\u0642\u0645 \u0627\u0644\u0633\u062c\u0644 \u0627\u0644\u062a\u062c\u0627\u0631\u064a (CR)', _cCR, ltr: true),
          _wf('\u0631\u0642\u0645 \u0627\u0644\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0636\u0631\u064a\u0628\u064a (VAT)', _cVAT, ltr: true),
        ]);
      case 3:
        // Step 4: Contact Info
        return Column(children: [
          _wf('\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a', _cEmail, ltr: true),
          _wf('\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641', _cPhone, ltr: true),
          _wf('\u0627\u0644\u0645\u062f\u064a\u0646\u0629', _cAddress),
        ]);
      case 4:
        // Step 5: Activity Sector (ISIC aligned)
        return _wc('\u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u0627\u0642\u062a\u0635\u0627\u062f\u064a (ISIC)', [
          '\u062a\u062c\u0627\u0631\u0629 \u062a\u062c\u0632\u0626\u0629',
          '\u062a\u062c\u0627\u0631\u0629 \u062c\u0645\u0644\u0629',
          '\u0645\u0642\u0627\u0648\u0644\u0627\u062a \u0648\u062a\u0634\u064a\u064a\u062f',
          '\u0635\u0646\u0627\u0639\u0629 \u0648\u062a\u062d\u0648\u064a\u0644',
          '\u062e\u062f\u0645\u0627\u062a \u0645\u0647\u0646\u064a\u0629',
          '\u062a\u0642\u0646\u064a\u0629 \u0645\u0639\u0644\u0648\u0645\u0627\u062a',
          '\u0639\u0642\u0627\u0631\u0627\u062a',
          '\u0646\u0642\u0644 \u0648\u0644\u0648\u062c\u0633\u062a\u064a\u0643',
          '\u0635\u062d\u0629 \u0648\u0631\u0639\u0627\u064a\u0629 \u0637\u0628\u064a\u0629',
          '\u062a\u0639\u0644\u064a\u0645 \u0648\u062a\u062f\u0631\u064a\u0628',
          '\u0633\u064a\u0627\u062d\u0629 \u0648\u0636\u064a\u0627\u0641\u0629',
          '\u0632\u0631\u0627\u0639\u0629 \u0648\u0623\u063a\u0630\u064a\u0629',
        ], _cSector.contains('\u0634\u0631\u0643\u0629') ? '' : _cSector, ss, (v) => _cSector = _cSector.contains('\u0634\u0631\u0643\u0629') ? _cSector : v);
      case 5:
        // Step 6: Documents
        return Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629', style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _docRow('\u0635\u0648\u0631\u0629 \u0627\u0644\u0633\u062c\u0644 \u0627\u0644\u062a\u062c\u0627\u0631\u064a', Icons.description),
            _docRow('\u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u0632\u0643\u0627\u0629 \u0648\u0627\u0644\u062f\u062e\u0644', Icons.receipt_long),
            _docRow('\u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u062a\u0623\u0645\u064a\u0646\u0627\u062a \u0627\u0644\u0627\u062c\u062a\u0645\u0627\u0639\u064a\u0629', Icons.security),
            _docRow('\u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u0636\u0631\u064a\u0628\u0629 \u0627\u0644\u0645\u0636\u0627\u0641\u0629 (VAT)', Icons.paid),
            _docRow('\u0639\u0642\u062f \u0627\u0644\u062a\u0623\u0633\u064a\u0633 / \u0627\u0644\u0646\u0638\u0627\u0645 \u0627\u0644\u0623\u0633\u0627\u0633\u064a', Icons.gavel),
          ]),
        );
      case 6:
        // Step 7: Review
        return Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a', style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _rv('\u0646\u0648\u0639 \u0627\u0644\u0643\u064a\u0627\u0646', _cType),
            _rv('\u0627\u0644\u0634\u0643\u0644 \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a', _cSector),
            _rv('\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629', _cNameAr.text),
            _rv('\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0625\u0646\u062c\u0644\u064a\u0632\u064a', _cName.text),
            _rv('\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0648\u0627\u0635\u0644', _cCR.text),
            _rv('\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0636\u0631\u064a\u0628\u064a', _cVAT.text),
            _rv('\u0627\u0644\u0628\u0631\u064a\u062f', _cEmail.text),
            _rv('\u0627\u0644\u0647\u0627\u062a\u0641', _cPhone.text),
          ]));
      default: return const SizedBox();
    }
  }

  Widget _docRow(String label, IconData icon) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      OutlinedButton(style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
        onPressed: () {}, child: Text('\u0631\u0641\u0639', style: TextStyle(color: AC.gold, fontSize: 10))),
      SizedBox(width: 8),
      Expanded(child: Text(label, textAlign: TextAlign.right, style: TextStyle(color: AC.tp, fontSize: 12))),
      SizedBox(width: 8),
      Icon(icon, color: AC.gold, size: 18),
    ]),
  );

  Widget _rv(String l, String v) => Padding(padding: EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    Text(v.isEmpty ? '-' : v, style: TextStyle(color: AC.tp, fontSize: 12)), SizedBox(width: 8), Text(l, style: TextStyle(color: AC.ts, fontSize: 11))]));

  void _showNewClientWizard(BuildContext ctx) {
    int _step = 0;
    final steps = [
      '\u0646\u0648\u0639 \u0627\u0644\u0643\u064a\u0627\u0646',
      '\u0627\u0644\u0634\u0643\u0644 \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a',
      '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0645\u0646\u0634\u0623\u0629',
      '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0648\u0627\u0635\u0644',
      '\u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u0627\u0642\u062a\u0635\u0627\u062f\u064a',
      '\u0631\u0641\u0639 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a',
      '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0648\u0627\u0644\u062a\u0623\u0643\u064a\u062f',
    ];
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (bc, setSt) =>
      Dialog(backgroundColor: Colors.transparent, insetPadding: EdgeInsets.all(24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: 550),
          decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.gold.withValues(alpha: 0.3))),
          padding: EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Text('\u062a\u0633\u062c\u064a\u0644 \u0639\u0645\u064a\u0644 \u062c\u062f\u064a\u062f', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold)),
              Spacer(),
              ApexIconButton(icon: Icons.close, color: AC.ts, size: 20, tooltip: 'إغلاق', onPressed: () => Navigator.pop(dc)),
            ]),
            const SizedBox(height: 16),
            SizedBox(height: 50, child: Row(children: List.generate(7, (idx) =>
              Expanded(child: GestureDetector(
                onTap: () => setSt(() => _step = idx),
                child: Column(children: [
                  Container(width: 28, height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: idx <= _step ? AC.gold : AC.navy3,
                      border: Border.all(color: idx == _step ? AC.gold : AC.bdr)),
                    child: Center(child: idx < _step
                      ? Icon(Icons.check, color: AC.navy, size: 14)
                      : Text('${idx + 1}', style: TextStyle(color: idx == _step ? AC.navy : AC.ts, fontSize: 11, fontWeight: FontWeight.bold)))),
                  SizedBox(height: 4),
                  if (idx == _step) Text(steps[idx], style: TextStyle(color: AC.gold, fontSize: 7), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                ]),
              )),
            ))),
            Divider(color: AC.bdr),
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildWizardStep(_step, setSt),
              SizedBox(height: 12),
              Text(steps[_step], style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('\u0627\u0644\u062e\u0637\u0648\u0629 ${_step + 1} \u0645\u0646 7', style: TextStyle(color: AC.ts, fontSize: 12)),
            ]))),
            Row(children: [
              if (_step > 0) Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr), padding: EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => setSt(() => _step--),
                child: Text('\u0627\u0644\u0633\u0627\u0628\u0642', style: TextStyle(color: AC.ts)))),
              if (_step > 0) SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AC.gold, padding: EdgeInsets.symmetric(vertical: 12)),
                onPressed: () { if (_step < 6) { setSt(() => _step++); } else { _doCreateClient(dc); } },
                child: Text(_step < 6 ? '\u0627\u0644\u062a\u0627\u0644\u064a' : '\u062a\u0623\u0643\u064a\u062f', style: TextStyle(color: AC.navy, fontWeight: FontWeight.bold)))),
            ]),
          ]),
        ),
      ),
    ));
  }
  @override Widget build(BuildContext c) {
    final filtered = _search.isEmpty ? _cl : _cl.where((c2) {
      final name = (c2['name_ar'] ?? c2['name'] ?? '').toString().toLowerCase();
      final type = (c2['client_type'] ?? '').toString().toLowerCase();
      return name.contains(_search.toLowerCase()) || type.contains(_search.toLowerCase());
    }).toList();
    return Scaffold(
      backgroundColor: AC.navy,
      floatingActionButton: ApexGlowFAB(icon: Icons.add, color: AC.gold,
        onPressed: () => _showNewClientWizard(c), tooltip: 'شركة جديدة'),
      body: Column(children: [
        // Header with title + search
        Container(padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('الشركات', style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Text('${_cl.length} عميل', style: TextStyle(color: AC.ts, fontSize: 12)),
            ]),
            SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(color: AC.tp, fontSize: 13),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'بحث عن عميل...',
                hintStyle: TextStyle(color: AC.ts, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: AC.ts, size: 20),
                filled: true, fillColor: AC.navy3, isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AC.gold)),
              ),
            ),
          ]),
        ),
        // Client list
        Expanded(child: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
          filtered.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.business_outlined, color: AC.ts, size: 60), SizedBox(height: 12),
            Text(_cl.isEmpty ? 'لا يوجد عملاء بعد' : 'لا نتائج', style: TextStyle(color: AC.ts, fontSize: 14)),
          ])) :
          RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), itemCount: filtered.length, itemBuilder: (_, i) {
              final c2 = filtered[i];
              final name = c2['name_ar'] ?? c2['name'] ?? '';
              final type = c2['client_type'] ?? '';
              final role = c2['your_role'] ?? '';
              return InkWell(
                onTap: () => context.push('/client-detail', extra: {'id': (c2['id'] ?? '').toString(), 'name': name}),
                child: Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AC.bdr)),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: AC.gold.withValues(alpha: 0.15), radius: 24,
                      child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 16))),
                    SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: AC.tp, fontSize: 15)),
                      SizedBox(height: 4),
                      Row(children: [
                        if (type.isNotEmpty) Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(type, style: TextStyle(color: AC.gold, fontSize: 10))),
                        if (type.isNotEmpty && role.isNotEmpty) SizedBox(width: 8),
                        if (role.isNotEmpty) Text(role, style: TextStyle(color: AC.ts, fontSize: 11)),
                      ]),
                    ])),
                    Icon(Icons.chevron_left, color: AC.ts, size: 20),
                  ])));
            }))),
      ]),
    );
  }
}


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// ANALYSIS TAB â€” with Result Details Panel (!)
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class AnalysisTab extends ConsumerStatefulWidget { const AnalysisTab({super.key}); @override ConsumerState<AnalysisTab> createState()=>_AnalysisS(); }
class _AnalysisS extends ConsumerState<AnalysisTab> {
  PlatformFile? _f; List<int>? _fb; bool _a=false; Map<String,dynamic>? _r; String? _e;
  Future<void> _pick() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions:['xlsx','xls'], withData:true);
    if(r!=null && r.files.isNotEmpty) setState((){  _f=r.files.first; _fb=r.files.first.bytes?.toList(); _r=null; _e=null; });
  }
  Future<void> _run() async {
    if(_fb==null) return; setState((){ _a=true; _e=null; });
    try {
      final result = await ApiService.analyzeQuick(bytes: _fb!, fileName: 'tb.xlsx');
      setState((){ _r = result.data; _a=false; if(!result.success) _e = result.error; });
    } catch(e){ setState((){ _e='$e'; _a=false; }); }
  }
  String _fmt(dynamic v) { if(v==null) return '-'; final d=(v is int)?v.toDouble():(v is double)?v:0.0;
    if(d.abs()>=1e6) return '${(d/1e6).toStringAsFixed(2)}M'; if(d.abs()>=1e3) return '${(d/1e3).toStringAsFixed(1)}K'; return d.toStringAsFixed(2); }

  void _showDetail(BuildContext c, String title, Map<String,dynamic> data) {
    showModalBottomSheet(context: c, backgroundColor: AC.navy2, isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: 0.6, maxChildSize: 0.9,
        builder: (_, sc) => ListView(controller: sc, padding: EdgeInsets.all(20), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AC.ts, borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: 16),
          Text(title, style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
          Divider(color: AC.bdr, height: 24),
          ...data.entries.map((e) => compactKv(e.key, '${e.value}')),
          if(_r?['knowledge_brain']?['rules_applied']!=null) ...[
            SizedBox(height: 12),
            Text('\u0627\u0644\u0642\u0648\u0627\u0639\u062f \u0627\u0644\u0645\u0637\u0628\u0642\u0629', style: TextStyle(color: AC.cyan, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            ...(_r!['knowledge_brain']['rules_applied'] as List? ?? []).map((r) =>
              Padding(padding: EdgeInsets.only(bottom: 4), child: Row(children: [
                Icon(Icons.rule, color: AC.cyan, size: 14), SizedBox(width: 8),
                Expanded(child: Text('$r', style: TextStyle(color: AC.ts, fontSize: 11)))])))],
          if(_r?['warnings']!=null && (_r!['warnings'] as List).isNotEmpty) ...[
            SizedBox(height: 12),
            Text('\u062a\u062d\u0630\u064a\u0631\u0627\u062a', style: TextStyle(color: AC.warn, fontWeight: FontWeight.bold)),
            ...(_r!['warnings'] as List).map((w) => Padding(padding: EdgeInsets.only(bottom: 4),
              child: Row(children: [Icon(Icons.warning_amber, color: AC.warn, size: 14), SizedBox(width: 8),
                Expanded(child: Text('$w', style: TextStyle(color: AC.ts, fontSize: 11)))])))],
        ])));
  }

  Widget _resultRow(BuildContext c, String label, String value, Map<String,dynamic> detailData) =>
    InkWell(onTap: ()=> _showDetail(c, label, detailData),
      child: Padding(padding: EdgeInsets.only(bottom: 7), child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: AC.ts, fontSize: 13))),
        Text(value, style: TextStyle(color: AC.tp, fontSize: 14)),
        SizedBox(width: 6),
        Container(width: 22, height: 22, decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(Icons.info_outline, color: AC.gold, size: 14))])));

  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0627\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a', style: TextStyle(color: AC.gold))),
    body: SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(children: [
      GestureDetector(onTap: _pick, child: Container(width: double.infinity, height: 110,
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _f!=null ? AC.gold : AC.bdr)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(_f!=null ? Icons.check_circle : Icons.cloud_upload_outlined, color: _f!=null ? AC.ok : AC.gold, size: 34),
          SizedBox(height: 6),
          Text(_f?.name ?? '\u0627\u0636\u063a\u0637 \u0644\u0631\u0641\u0639 \u0645\u064a\u0632\u0627\u0646 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', style: TextStyle(color: _f!=null?AC.tp:AC.ts, fontSize: 13))]))),
      SizedBox(height: 14),
      if(_f!=null && _r==null) SizedBox(width: double.infinity, child: ElevatedButton.icon(
        onPressed: _a?null:_run, icon: _a ? SizedBox(height:18,width:18, child: CircularProgressIndicator(strokeWidth:2,color:AC.navy)) : Icon(Icons.play_arrow),
        label: Text(_a ? '\u062c\u0627\u0631\u064a \u0627\u0644\u062a\u062d\u0644\u064a\u0644...' : '\u0628\u062f\u0621 \u0627\u0644\u062a\u062d\u0644\u064a\u0644'))),
      if(_e!=null) Padding(padding:EdgeInsets.only(top:10), child:Text(_e!, style:TextStyle(color:AC.err))),
      // RESULTS with ! icon
      if(_r!=null && _r!['success']==true) ...[
        SizedBox(height: 18),
        compactCard('\u0627\u0644\u062b\u0642\u0629', [
          _resultRow(c, '\u0627\u0644\u0646\u0633\u0628\u0629', '${((_r!['confidence']?['overall']??0)*100).toStringAsFixed(1)}%',
            _r!['confidence'] is Map ? Map<String,dynamic>.from(_r!['confidence']) : {}),
          _resultRow(c, '\u0627\u0644\u062a\u0642\u064a\u064a\u0645', _r!['confidence']?['label']??'',
            {'overall': _r!['confidence']?['overall'], 'label': _r!['confidence']?['label']}),
        ], accent: _getConfidenceColor(_r!['confidence']?['overall'])),
        compactCard('\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u062f\u062e\u0644', [
          _resultRow(c, '\u0635\u0627\u0641\u064a \u0627\u0644\u0625\u064a\u0631\u0627\u062f\u0627\u062a', _fmt(_r!['income_statement']?['net_revenue']),
            _r!['income_statement'] is Map ? Map<String,dynamic>.from(_r!['income_statement']) : {}),
          _resultRow(c, '\u062a\u0643\u0644\u0641\u0629 \u0627\u0644\u0645\u0628\u064a\u0639\u0627\u062a', _fmt(_r!['income_statement']?['cogs']),
            {'cogs': _r!['income_statement']?['cogs'], 'method': _r!['income_statement']?['cogs_method']??'N/A'}),
          _resultRow(c, '\u0645\u062c\u0645\u0644 \u0627\u0644\u0631\u0628\u062d', _fmt(_r!['income_statement']?['gross_profit']),
            {'gross_profit': _r!['income_statement']?['gross_profit'], 'margin': _r!['income_statement']?['gross_margin']}),
          _resultRow(c, '\u0635\u0627\u0641\u064a \u0627\u0644\u0631\u0628\u062d', _fmt(_r!['income_statement']?['net_profit']),
            {'net_profit': _r!['income_statement']?['net_profit'], 'margin': _r!['income_statement']?['net_margin']}),
        ]),
        compactCard('\u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629 \u0627\u0644\u0639\u0645\u0648\u0645\u064a\u0629', [
          _resultRow(c, '\u0627\u0644\u0623\u0635\u0648\u0644', _fmt(_r!['balance_sheet']?['total_assets']),
            _r!['balance_sheet'] is Map ? Map<String,dynamic>.from(_r!['balance_sheet']) : {}),
          _resultRow(c, '\u0627\u0644\u0627\u0644\u062a\u0632\u0627\u0645\u0627\u062a', _fmt(_r!['balance_sheet']?['total_liabilities']),
            {'total_liabilities': _r!['balance_sheet']?['total_liabilities']}),
          _resultRow(c, '\u0645\u062a\u0648\u0627\u0632\u0646\u0629', _r!['balance_sheet']?['is_balanced']==true?'\u0646\u0639\u0645 \u2713':'\u0644\u0627 \u2717',
            {'is_balanced': _r!['balance_sheet']?['is_balanced'], 'difference': _r!['balance_sheet']?['difference']}),
        ]),
        if(_r!['knowledge_brain']!=null) compactCard('\u0627\u0644\u0639\u0642\u0644 \u0627\u0644\u0645\u0639\u0631\u0641\u064a', [
          _resultRow(c, '\u0627\u0644\u0642\u0648\u0627\u0639\u062f', '${_r!['knowledge_brain']?['rules_triggered']??0}/${_r!['knowledge_brain']?['rules_evaluated']??0}',
            _r!['knowledge_brain'] is Map ? Map<String,dynamic>.from(_r!['knowledge_brain']) : {}),
        ], accent: AC.cyan),
        SizedBox(height: 14),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: ()=>setState((){ _f=null; _fb=null; _r=null; }),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
            icon: Icon(Icons.refresh, color: AC.gold, size: 18),
            label: Text('\u062a\u062d\u0644\u064a\u0644 \u0622\u062e\u0631', style: TextStyle(color: AC.gold)))),
          SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: ()=>context.push('/knowledge/feedback-form', extra: {'resultId': _r?['result_id']}),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AC.cyan)),
            icon: Icon(Icons.feedback_outlined, color: AC.cyan, size: 18),
            label: Text('\u0645\u0644\u0627\u062d\u0638\u0629 \u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.cyan)))),
        ]),
        SizedBox(height: 10),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: AC.ok, padding: EdgeInsets.symmetric(vertical: 14)),
          onPressed: () async {
            try {
              final result = await ApiService.analyzeReport(bytes: _fb!, fileName: 'tb.xlsx');
              if (result.success) {
                ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('\u062a\u0645 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u0642\u0631\u064a\u0631 \u0628\u0646\u062c\u0627\u062d'), backgroundColor: AC.ok));
              }
            } catch (e) {
              ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('\u062e\u0637\u0623: $e'), backgroundColor: AC.navy3));
            }
          },
          icon: Icon(Icons.picture_as_pdf, color: AC.btnFg),
          label: Text('\u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u062a\u0642\u0631\u064a\u0631 PDF', style: TextStyle(color: AC.btnFg, fontWeight: FontWeight.bold)))),
      ]])));

  Color _getConfidenceColor(dynamic v) {
    if(v==null) return AC.ts; final d = (v is num) ? v.toDouble() : 0.0;
    if(d >= 0.85) return AC.ok; if(d >= 0.65) return AC.warn; return AC.err;
  }
}


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// MARKETPLACE TAB
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class MarketTab extends ConsumerStatefulWidget { const MarketTab({super.key}); @override ConsumerState<MarketTab> createState()=>_MarketS(); }
class _MarketS extends ConsumerState<MarketTab> {
  List _provs=[], _reqs=[]; bool _ld=true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await ApiService.listMarketplaceProviders();
      final r2 = await ApiService.listMyRequests();
      if(mounted) setState(() {
        final d1 = r1.data; _provs = d1 is List ? d1 : [];
        final d2 = r2.data; _reqs = d2 is List ? d2 : [];
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0627\u0644\u0645\u0639\u0631\u0636', style: TextStyle(color: AC.gold))),
    floatingActionButton: FloatingActionButton.extended(backgroundColor: AC.gold,
      onPressed: ()=> context.push('/marketplace/new-request'),
      icon: Icon(Icons.add, color: AC.navy), label: Text('\u0637\u0644\u0628 \u062e\u062f\u0645\u0629', style: TextStyle(color: AC.navy))),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      ListView(padding: EdgeInsets.all(14), children: [
        Container(margin: EdgeInsets.only(bottom: 14), padding: EdgeInsets.all(14), decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold)), child: Column(children: [Icon(Icons.store_mall_directory, color: AC.gold, size: 36), SizedBox(height: 8), Text("كتالوج الخدمات المهنية", style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 16)), SizedBox(height: 4), Text("تصفح 6 خدمات: تحليل مالي، مراجعة، ضرائب، تمويل، دعم، تراخيص", style: TextStyle(color: AC.ts, fontSize: 12), textAlign: TextAlign.center), SizedBox(height: 12), SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => context.push('/service-catalog', extra: {'clientId': '', 'token': S.token}), icon: Icon(Icons.arrow_forward), label: Text("فتح الكتالوج")))])),
        compactCard('\u0645\u0642\u062f\u0645\u0648 \u0627\u0644\u062e\u062f\u0645\u0627\u062a \u0627\u0644\u0645\u0639\u062a\u0645\u062f\u0648\u0646', [
          if(_provs.isEmpty) Text('\u0644\u0627 \u064a\u0648\u062c\u062f \u0645\u0642\u062f\u0645\u0648 \u062e\u062f\u0645\u0627\u062a \u0628\u0639\u062f', style: TextStyle(color: AC.ts, fontSize: 13))
          else ..._provs.take(5).map((p) => Padding(padding: EdgeInsets.only(bottom: 8),
            child: Row(children: [CircleAvatar(backgroundColor: AC.navy4, radius: 18,
              child: Text((p['display_name']??'?')[0], style: TextStyle(color: AC.gold))),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p['display_name']??'', style: TextStyle(color: AC.tp, fontSize: 13)),
                Text(p['category']??'', style: TextStyle(color: AC.ts, fontSize: 11))])),
              if(p['rating']!=null) Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star, color: AC.gold, size: 14),
                Text('${p['rating']}', style: TextStyle(color: AC.gold, fontSize: 12))])]))),
        ]),
        compactCard('\u0637\u0644\u0628\u0627\u062a \u0627\u0644\u062e\u062f\u0645\u0629', [
          if(_reqs.isEmpty) Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0637\u0644\u0628\u0627\u062a \u0628\u0639\u062f', style: TextStyle(color: AC.ts, fontSize: 13))
          else ..._reqs.take(5).map((r) => Padding(padding: EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r['title']??'', style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${r['urgency']??''} \u2022 ${r['budget_sar']??0} \u0631.\u0633', style: TextStyle(color: AC.ts, fontSize: 11))])),
              compactBadge(r['status']??'open', r['status']=='completed'?AC.ok:r['status']=='matched'?AC.cyan:AC.warn)]))),
        ]),
      ]));
}


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// PROVIDER TAB
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class ProviderTab extends StatefulWidget { const ProviderTab({super.key}); @override State<ProviderTab> createState()=>_ProvS(); }
class _ProvS extends State<ProviderTab> {
  Map<String,dynamic>? _p; bool _ld=true; bool _notProvider=false;
  final _cats = [
    {'code':'accountant','ar':'\u0645\u062d\u0627\u0633\u0628'},{'code':'tax_consultant','ar':'\u0645\u0633\u062a\u0634\u0627\u0631 \u0636\u0631\u0627\u0626\u0628'},
    {'code':'auditor','ar':'\u0645\u062f\u0642\u0642'},{'code':'financial_controller','ar':'\u0645\u0631\u0627\u0642\u0628 \u0645\u0627\u0644\u064a'},
    {'code':'bookkeeping_specialist','ar':'\u0623\u062e\u0635\u0627\u0626\u064a \u0645\u0633\u0643 \u062f\u0641\u0627\u062a\u0631'},
    {'code':'hr_consultant','ar':'\u0645\u0633\u062a\u0634\u0627\u0631 \u0645\u0648\u0627\u0631\u062f \u0628\u0634\u0631\u064a\u0629'},
    {'code':'legal_consultant','ar':'\u0645\u0633\u062a\u0634\u0627\u0631 \u0642\u0627\u0646\u0648\u0646\u064a'},
    {'code':'marketing_consultant','ar':'\u0645\u0633\u062a\u0634\u0627\u0631 \u062a\u0633\u0648\u064a\u0642'},
  ];
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await ApiService.getProviderMe();
      if(r.success) { if(mounted) setState((){ _p=r.data; _ld=false; }); }
      else { if(mounted) setState((){ _notProvider=true; _ld=false; }); }
    } catch(_) { if(mounted) setState((){ _notProvider=true; _ld=false; }); }
  }
  String? _sel;
  Future<void> _register() async {
    if(_sel==null) return;
    final r = await ApiService.registerProvider({'category':_sel});
    if(r.success) _load();
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629', style: TextStyle(color: AC.gold))),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      _notProvider ? SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(children: [
        Icon(Icons.verified_user_outlined, color: AC.gold, size: 60), SizedBox(height: 16),
        Text('\u0643\u0646 \u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629 \u0645\u0639\u062a\u0645\u062f', style: TextStyle(color: AC.tp, fontSize: 20, fontWeight: FontWeight.bold)),
        SizedBox(height: 20),
        ..._cats.map((cat) => GestureDetector(onTap: ()=>setState(()=>_sel=cat['code']),
          child: Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: _sel==cat['code']?AC.gold.withValues(alpha: 0.1):AC.navy3,
              borderRadius: BorderRadius.circular(10), border: Border.all(color: _sel==cat['code']?AC.gold:AC.bdr)),
            child: Row(children: [
              Icon(_sel==cat['code']?Icons.radio_button_checked:Icons.radio_button_off, color: _sel==cat['code']?AC.gold:AC.ts, size: 18),
              SizedBox(width: 10), Text(cat['ar']!, style: TextStyle(color: _sel==cat['code']?AC.gold:AC.tp, fontSize: 13))])))),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _sel!=null?_register:null,
          child: Text('\u0627\u0644\u062a\u0633\u062c\u064a\u0644 \u0643\u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629')))])) :
      ListView(padding: EdgeInsets.all(16), children: [
        compactCard('\u0645\u0644\u0641 \u0645\u0642\u062f\u0645 \u0627\u0644\u062e\u062f\u0645\u0629', [
          compactKv('\u0627\u0644\u062a\u062e\u0635\u0635', _p?['category']??''),
          compactKv('\u0627\u0644\u062d\u0627\u0644\u0629', _p?['verification_status']??'',
            vc: _p?['verification_status']=='approved'?AC.ok:AC.warn),
          compactKv('\u0627\u0644\u0639\u0645\u0648\u0644\u0629', '20% \u0645\u0646\u0635\u0629 / 80% \u0645\u0642\u062f\u0645 \u062e\u062f\u0645\u0629'),
        ]),
        if(_p?['service_scopes']!=null) compactCard('\u0646\u0637\u0627\u0642\u0627\u062a \u0627\u0644\u062e\u062f\u0645\u0629', [
          ...(_p!['service_scopes'] as List).map((s) => Padding(padding: EdgeInsets.only(bottom: 4),
            child: Row(children: [Icon(Icons.check, color: AC.ok, size: 14), SizedBox(width: 8),
              Text(s['name_ar']??s['code']??'', style: TextStyle(color: AC.tp, fontSize: 12))])))]),
        if(_p?['required_documents']!=null) compactCard('\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a', [
          ...(_p!['required_documents'] as List).map((d) => Padding(padding: EdgeInsets.only(bottom: 4),
            child: Row(children: [Icon(Icons.description_outlined, color: AC.warn, size: 14), SizedBox(width: 8),
              Text('$d', style: TextStyle(color: AC.tp, fontSize: 12)),
              Spacer(), compactBadge('\u0645\u0637\u0644\u0648\u0628', AC.warn)])))]),
      ]));
}

// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// ACCOUNT TAB â€” with Profile Editing
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class AccountTab extends ConsumerStatefulWidget { const AccountTab({super.key}); @override ConsumerState<AccountTab> createState()=>_AccS(); }
class _AccS extends ConsumerState<AccountTab> {
  Map<String,dynamic>? _p, _s; bool _ld=true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await ApiService.getProfile();
      final r2 = await ApiService.getSecuritySettings();
      if(mounted) setState((){ _p=r1.data is Map ? r1.data : null; _s=r2.data is Map ? r2.data : null; _ld=false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  void _logout() { ApiService.logout(); S.clear();
    ApiService.clearToken(); context.go('/login'); }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u062d\u0633\u0627\u0628\u064a', style: TextStyle(color: AC.gold)),
      actions: [ApexIconButton(onPressed: _logout, icon: Icons.logout, color: AC.err, tooltip: 'تسجيل الخروج')]),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: EdgeInsets.all(16), children: [
        // Profile Card
        Container(padding: EdgeInsets.all(20), decoration: BoxDecoration(color: AC.navy3,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
          child: Column(children: [
            CircleAvatar(radius: 36, backgroundColor: AC.navy4,
              child: Text((_p?['user']?['display_name']??'?')[0], style: TextStyle(fontSize: 28, color: AC.gold))),
            SizedBox(height: 12),
            Text(_p?['user']?['display_name']??'', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AC.tp)),
            Text('@${_p?['user']?['username']??''}', style: TextStyle(color: AC.ts)),
            SizedBox(height: 4),
            Text(_p?['user']?['email']??'', style: TextStyle(color: AC.ts, fontSize: 12)),
            SizedBox(height: 12),
            OutlinedButton.icon(onPressed: ()=> context.push('/profile/edit', extra: _p),
              style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
              icon: Icon(Icons.edit, color: AC.gold, size: 16),
              label: Text('\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0644\u0641 \u0627\u0644\u0634\u062e\u0635\u064a', style: TextStyle(color: AC.gold, fontSize: 12)))])),
        SizedBox(height: 14),
        // Security
        compactCard('\u0627\u0644\u0623\u0645\u0627\u0646', [
          InkWell(onTap:(){context.push('/account/sessions');},child:compactKv('\u0627\u0644\u062c\u0644\u0633\u0627\u062a \u0627\u0644\u0646\u0634\u0637\u0629', '${_s?['active_sessions']??0}')),
          compactKv('\u0639\u062f\u062f \u0645\u0631\u0627\u062a \u0627\u0644\u062f\u062e\u0648\u0644', '${_s?['login_count']??0}'),
          compactKv('\u0622\u062e\u0631 \u062f\u062e\u0648\u0644', _s?['last_login']?.toString().substring(0,16)??'-'),
        ]),
        // Menu Items
                _mi(Icons.account_tree, 'شجرة الحسابات COA', AC.cyan,
          ()=>context.go('/clients')),
        _mi(Icons.workspace_premium, '\u062e\u0637\u062a\u064a \u0648\u0627\u0644\u0627\u0634\u062a\u0631\u0627\u0643', AC.gold,
          ()=>context.go('/subscription')),
        _mi(Icons.notifications_outlined, '\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a', AC.cyan,
          ()=>context.go('/notifications')),
        _mi(Icons.lock_outlined, '\u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', AC.warn,
          ()=>context.go('/password/change')),
        _mi(Icons.delete_outline, '\u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u062d\u0633\u0627\u0628', AC.err,
          ()=>context.go('/account/close')),
          _mi(Icons.archive, 'الأرشيف', AC.cyan, () => context.push('/archive')),
            _mi(Icons.history, 'سجل النشاط', AC.purple,
            ()=>context.go('/account/activity')),
          _mi(Icons.compare_arrows, 'مقارنة الخطط', AC.cyan,
            ()=>context.go('/plans/compare')),
          _mi(Icons.assignment, 'أنواع المهام', AC.cyan,
            ()=>context.go('/tasks/types')),
          _mi(Icons.description, 'الشروط والأحكام', AC.ts,
            ()=>context.go('/legal')),
          _mi(Icons.devices, 'الجلسات النشطة', AC.cyan,
            ()=>context.go('/account/sessions')),
      ])));
  Widget _mi(IconData i, String l, Color cl, VoidCallback onTap) =>
    ApexMenuItem(icon: i, label: l, color: cl, onTap: onTap);
}


// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
// ADMIN TAB â€” Platform Dashboard
// â•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گâ•گ
class AdminTab extends ConsumerStatefulWidget { const AdminTab({super.key}); @override ConsumerState<AdminTab> createState()=>_AdminS(); }
class _AdminS extends ConsumerState<AdminTab> {
  Map<String,dynamic> _stats = {}; List _users = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await ApiService.adminStats();
      final r2 = await ApiService.adminUsers();
      if(mounted) setState(() {
        _stats = r1.data is Map ? Map<String,dynamic>.from(r1.data) : {};
        final d2 = r2.data; _users = d2 is List ? d2 : [];
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0644\u0648\u062d\u0629 \u0627\u0644\u0625\u062f\u0627\u0631\u0629', style: TextStyle(color: AC.gold)),
      actions: [
        ApexIconButton(icon: Icons.rate_review, color: AC.cyan,
          tooltip: 'المراجع', onPressed: ()=>context.go('/admin/reviewer')),
        ApexIconButton(icon: Icons.verified_user, color: AC.ok,
          tooltip: 'التحقق من مقدمي الخدمات', onPressed: ()=>context.go('/admin/providers/verify')),
        ApexIconButton(icon: Icons.upload_file, color: AC.gold,
          tooltip: 'مستندات مقدمي الخدمات', onPressed: ()=>context.go('/admin/providers/documents')),
        ApexIconButton(icon: Icons.shield, color: AC.gold,
          tooltip: 'الامتثال', onPressed: ()=>context.go('/admin/providers/compliance')),
        ApexIconButton(icon: Icons.psychology, color: AC.gold,
          tooltip: 'قاعدة المعرفة', onPressed: ()=>context.go('/knowledge/console')),
        ApexIconButton(icon: Icons.security, color: AC.gold,
          tooltip: 'سجل التدقيق', onPressed: ()=>context.go('/admin/audit')),
      ]),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: EdgeInsets.all(14), children: [
        // Stats Grid
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
          children: [
            _statCard('\u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u0648\u0646', '${_stats['total_users']??_users.length}', Icons.people, AC.gold),
            _statCard('\u0627\u0644\u0639\u0645\u0644\u0627\u0621', '${_stats['total_clients']??0}', Icons.business, AC.cyan),
            _statCard('\u0645\u0642\u062f\u0645\u0648 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', '${_stats['total_providers']??0}', Icons.work, AC.ok),
            _statCard('\u0627\u0644\u0637\u0644\u0628\u0627\u062a', '${_stats['total_requests']??0}', Icons.assignment, AC.warn),
            _statCard('\u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a', '${_stats['total_feedback']??0}', Icons.feedback, AC.purple),
            _statCard('\u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a', '${_stats['total_analyses']??0}', Icons.analytics, AC.info),
          ]),
        SizedBox(height: 16),
        // Quick Actions
        compactCard('\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u0633\u0631\u064a\u0639\u0629', [
          _actionTile('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u0644\u0645\u0639\u0631\u0641\u064a\u0629', Icons.rate_review, AC.cyan,
            ()=>context.go('/admin/reviewer')),
          _actionTile('\u062a\u062d\u0642\u0642 \u0645\u0642\u062f\u0645\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a', Icons.verified_user, AC.ok,
            ()=>context.go('/admin/providers/verify')),
          _actionTile('\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a', Icons.policy, AC.warn,
            ()=>context.go('/admin/policies')),
        ]),
        SizedBox(height: 16),
        // Users List
        compactCard('\u0622\u062e\u0631 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u064a\u0646', [
          if(_users.isEmpty) Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0628\u064a\u0627\u0646\u0627\u062a', style: TextStyle(color: AC.ts))
          else ..._users.take(10).map((u) => Padding(padding: EdgeInsets.only(bottom: 8),
            child: Row(children: [
              CircleAvatar(backgroundColor: AC.navy4, radius: 16,
                child: Text((u['display_name']??u['username']??'?')[0], style: TextStyle(color: AC.gold, fontSize: 12))),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['display_name']??u['username']??'', style: TextStyle(color: AC.tp, fontSize: 13)),
                Text('${u['email']??''} \u2022 ${u['plan']??'free'}', style: TextStyle(color: AC.ts, fontSize: 10))])),
              compactBadge(u['status']??'active', u['status']=='active'?AC.ok:AC.err)])))
        ]),
      ])));

  Widget _statCard(String label, String value, IconData icon, Color color) => Container(
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [Icon(icon, color: color, size: 22), Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold))]),
      SizedBox(height: 6),
      Text(label, style: TextStyle(color: AC.ts, fontSize: 11))]));

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) =>
    ApexActionTile(label: label, icon: icon, color: color, onTap: onTap);
}

