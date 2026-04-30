import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../form_helpers.dart';

class NewServiceRequestScreen extends StatefulWidget {
  const NewServiceRequestScreen({super.key});
  @override State<NewServiceRequestScreen> createState() => _NSRS();
}
class _NSRS extends State<NewServiceRequestScreen> {
  final _title=TextEditingController(), _desc=TextEditingController(), _budget=TextEditingController();
  String _urgency='medium'; List _clients=[]; String? _clientId, _e; bool _l=false, _done=false;
  @override void initState() { super.initState();
    ApiService.listClients().then((r){ if(r.success && mounted) { final d = r.data; setState((){ _clients = d is List ? d : []; }); } }); }
  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _budget.dispose();
    super.dispose();
  }
  Future<void> _go() async {
    if(_title.text.isEmpty||_clientId==null) { setState(()=> _e='\u0627\u0644\u0639\u0646\u0648\u0627\u0646 \u0648\u0627\u0644\u0639\u0645\u064a\u0644 \u0645\u0637\u0644\u0648\u0628\u0627\u0646'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final r = await ApiService.createServiceRequest({'client_id':_clientId,'title':_title.text.trim(),'description':_desc.text.trim(),
        'urgency':_urgency,'budget_sar':double.tryParse(_budget.text)??0,'deadline_days':14});
      if(r.success) setState(()=> _done=true);
      else setState(()=> _e=r.error);
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0637\u0644\u0628 \u062e\u062f\u0645\u0629 \u062c\u062f\u064a\u062f', style: TextStyle(color: AC.gold))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle, color: AC.ok, size: 60), SizedBox(height: 16),
      Text('\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0637\u0644\u0628 \u0627\u0644\u062e\u062f\u0645\u0629', style: TextStyle(color: AC.tp, fontSize: 18)),
      const SizedBox(height: 20),
      ElevatedButton(onPressed: ()=>Navigator.pop(c), child: Text('\u0631\u062c\u0648\u0639'))])) :
    SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if(_clients.isNotEmpty) ...[
        Text('\u0627\u062e\u062a\u0631 \u0627\u0644\u0639\u0645\u064a\u0644', style: TextStyle(color: AC.ts, fontSize: 13)),
        SizedBox(height: 6),
        ..._clients.map((cl) => GestureDetector(onTap: ()=>setState(()=>_clientId=cl['id']),
          child: Container(margin: EdgeInsets.only(bottom: 6), padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: _clientId==cl['id']?AC.gold.withValues(alpha: 0.1):AC.navy3,
              borderRadius: BorderRadius.circular(8), border: Border.all(color: _clientId==cl['id']?AC.gold:AC.bdr)),
            child: Text(cl['name_ar']??'', style: TextStyle(color: _clientId==cl['id']?AC.gold:AC.tp, fontSize: 13))))),
        const SizedBox(height: 12)],
      TextField(controller: _title, decoration: apexInputDecoration('\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0637\u0644\u0628 *')),
      const SizedBox(height: 12),
      TextField(controller: _desc, maxLines: 3, decoration: apexInputDecoration('\u0648\u0635\u0641 \u0627\u0644\u0637\u0644\u0628')),
      SizedBox(height: 12),
      TextField(controller: _budget, keyboardType: TextInputType.number, decoration: apexInputDecoration('\u0627\u0644\u0645\u064a\u0632\u0627\u0646\u064a\u0629 (\u0631.\u0633)', ic: Icons.attach_money)),
      SizedBox(height: 12),
      Text('\u0627\u0644\u0623\u0648\u0644\u0648\u064a\u0629', style: TextStyle(color: AC.ts, fontSize: 13)),
      SizedBox(height: 6),
      Row(children: ['low','medium','high'].map((u) => Expanded(child: GestureDetector(onTap: ()=>setState(()=>_urgency=u),
        child: Container(margin: EdgeInsets.symmetric(horizontal: 3), padding: EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: _urgency==u ? (u=='high'?AC.err:u=='medium'?AC.warn:AC.ok).withValues(alpha: 0.15) : AC.navy3,
            borderRadius: BorderRadius.circular(8), border: Border.all(color: _urgency==u ? (u=='high'?AC.err:u=='medium'?AC.warn:AC.ok) : AC.bdr)),
          child: Center(child: Text(u=='high'?'\u0639\u0627\u0644\u064a\u0629':u=='medium'?'\u0645\u062a\u0648\u0633\u0637\u0629':'\u0645\u0646\u062e\u0641\u0636\u0629',
            style: TextStyle(color: _urgency==u ? AC.tp : AC.ts, fontSize: 12))))))).toList()),
      if(_e!=null) Padding(padding: EdgeInsets.only(top: 10), child: Text(_e!, style: TextStyle(color: AC.err))),
      const SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l?null:_go,
        child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('\u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0637\u0644\u0628')))])));
}
