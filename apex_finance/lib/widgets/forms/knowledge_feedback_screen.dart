import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../form_helpers.dart';

class KnowledgeFeedbackScreen extends StatefulWidget {
  final String? resultId;
  const KnowledgeFeedbackScreen({super.key, this.resultId});
  @override State<KnowledgeFeedbackScreen> createState() => _KFS();
}
class _KFS extends State<KnowledgeFeedbackScreen> {
  final _title = TextEditingController(), _desc = TextEditingController();
  String _type = 'classification_correction'; bool _l = false; String? _e; bool _done = false;
  final _types = [
    {'code':'classification_correction','ar':'\u062a\u0635\u062d\u064a\u062d \u062a\u0628\u0648\u064a\u0628'},
    {'code':'new_rule_suggestion','ar':'\u0627\u0642\u062a\u0631\u0627\u062d \u0642\u0627\u0639\u062f\u0629 \u062c\u062f\u064a\u062f\u0629'},
    {'code':'data_quality_issue','ar':'\u0645\u0634\u0643\u0644\u0629 \u062c\u0648\u062f\u0629 \u0628\u064a\u0627\u0646\u0627\u062a'},
    {'code':'explanation_improvement','ar':'\u062a\u062d\u0633\u064a\u0646 \u0627\u0644\u0634\u0631\u062d'},
  ];
  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }
  Future<void> _submit() async {
    if(_title.text.trim().isEmpty) { setState(()=> _e='\u0627\u0644\u0639\u0646\u0648\u0627\u0646 \u0645\u0637\u0644\u0648\u0628'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final r = await ApiService.submitKnowledgeFeedback({'feedback_type':_type,'title':_title.text.trim(),'description':_desc.text.trim()});
      if(r.success) setState(()=> _done=true);
      else setState(()=> _e=r.error);
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0645\u0644\u0627\u062d\u0638\u0629 \u0645\u0639\u0631\u0641\u064a\u0629', style: TextStyle(color: AC.gold))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle, color: AC.ok, size: 60), SizedBox(height: 16),
      Text('\u062a\u0645 \u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0629 \u0628\u0646\u062c\u0627\u062d', style: TextStyle(color: AC.tp, fontSize: 18)),
      SizedBox(height: 8),
      Text('\u0633\u062a\u062e\u0636\u0639 \u0644\u0644\u0645\u0631\u0627\u062c\u0639\u0629', style: TextStyle(color: AC.ts)),
      SizedBox(height: 20),
      ElevatedButton(onPressed: ()=>Navigator.pop(c), child: Text('\u0631\u062c\u0648\u0639'))])) :
    SingleChildScrollView(padding: EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('\u0646\u0648\u0639 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0629', style: TextStyle(color: AC.ts, fontSize: 14)),
      SizedBox(height: 8),
      ..._types.map((t) => GestureDetector(onTap: ()=>setState(()=>_type=t['code']!),
        child: Container(margin: EdgeInsets.only(bottom: 6), padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _type==t['code'] ? AC.gold.withValues(alpha: 0.1) : AC.navy3,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _type==t['code'] ? AC.gold : AC.bdr)),
          child: Row(children: [
            Icon(_type==t['code'] ? Icons.radio_button_checked : Icons.radio_button_off, color: _type==t['code'] ? AC.gold : AC.ts, size: 18),
            SizedBox(width: 10), Text(t['ar']!, style: TextStyle(color: _type==t['code'] ? AC.gold : AC.tp, fontSize: 13))])))),
      const SizedBox(height: 16),
      TextField(controller: _title, decoration: apexInputDecoration('\u0627\u0644\u0639\u0646\u0648\u0627\u0646 *', ic: Icons.title)),
      SizedBox(height: 12),
      TextField(controller: _desc, maxLines: 4, decoration: apexInputDecoration('\u0627\u0644\u0648\u0635\u0641 \u0627\u0644\u062a\u0641\u0635\u064a\u0644\u064a')),
      if(_e!=null) Padding(padding:EdgeInsets.only(top:10), child:Text(_e!, style:TextStyle(color:AC.err))),
      SizedBox(height: 20),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: _l?null:_submit,
        icon: _l ? SizedBox(height:18,width:18,child:CircularProgressIndicator(strokeWidth:2,color:AC.navy)) : Icon(Icons.send),
        label: Text(_l ? '\u062c\u0627\u0631\u064a \u0627\u0644\u0625\u0631\u0633\u0627\u0644...' : '\u0625\u0631\u0633\u0627\u0644 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0629')))])));
}
