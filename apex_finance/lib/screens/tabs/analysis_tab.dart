import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../widgets/apex_widgets.dart';

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
