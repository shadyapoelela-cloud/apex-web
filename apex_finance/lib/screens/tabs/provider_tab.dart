import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../widgets/apex_widgets.dart';

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
