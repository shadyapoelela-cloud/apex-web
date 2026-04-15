import 'package:flutter/material.dart';
import 'api_service.dart';
import 'shared_widgets.dart';
import 'core/theme.dart';

class CoaReviewScreen extends StatefulWidget {
  final String uploadId, clientId, clientName;
  const CoaReviewScreen({super.key, required this.uploadId, required this.clientId, required this.clientName});
  @override State<CoaReviewScreen> createState() => _CoaReviewScreenState();
}

class _CoaReviewScreenState extends State<CoaReviewScreen> {
  bool _loading = true, _approving = false, _bulkApproving = false, _approved = false;
  int _page = 1, _total = 0;
  String _filter = 'all';
  Map<String,dynamic> _summary = {};
  List<Map<String,dynamic>> _accounts = [];
  String? _errorMsg;
  static Color get _bg => AC.navy;
  static Color get _surface => AC.navy2;
  static Color get _gold => AC.gold;
  static Color get _success => AC.ok;
  static Color get _danger => AC.err;
  static Color get _warning => AC.warn;
  static Color get _border => AC.bdr;
  static Color get _textPri => AC.tp;
  static Color get _textSec => AC.ts;
  @override void initState() { super.initState(); _loadSummary(); _loadAccounts(); }

  Future<void> _loadSummary() async {
    try {
      final r = await ApiService.getClassificationSummary(widget.uploadId);
      if (r.success) setState(() => _summary = r.data as Map<String,dynamic>);
    } catch (_) {}
  }

  Future<void> _loadAccounts({bool reset = false}) async {
    if (reset) setState(() { _page = 1; _accounts = []; });
    setState(() => _loading = true);
    try {
      final filterKey = _filter == 'manual' ? null : _filter;
      final r = await ApiService.getCoaMappingPreview(uploadId: widget.uploadId, page: _page, filter: filterKey);
      if (r.success) {
        final data = r.data as Map<String,dynamic>;
        final items = (data['accounts'] as List).cast<Map<String,dynamic>>();
        setState(() { _total = data['total'] ?? 0; if (reset || _page == 1) _accounts = items; else _accounts.addAll(items); });
      }
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  Future<void> _bulkApproveHigh() async {
    setState(() => _bulkApproving = true);
    try {
      final r = await ApiService.bulkApprove(uploadId: widget.uploadId);
      if (r.success) {
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم اعتماد ${r.data?["approved_count"]??0} حساب', style: const TextStyle(fontFamily:'Tajawal')), backgroundColor: _success)); _loadSummary(); _loadAccounts(reset: true); }
      }
    } catch (_) {} finally { setState(() => _bulkApproving = false); }
  }

  Future<void> _approveAll() async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AC.navy3,
      title: Text('اعتماد شجرة الحسابات', textDirection: TextDirection.rtl, style: TextStyle(fontFamily:'Tajawal', color:AC.tp, fontSize:15)),
      content: Text('سيتم اعتماد شجرة الحسابات كمرجع للتحليل. هل أنت متأكد؟', textDirection: TextDirection.rtl, style: TextStyle(fontFamily:'Tajawal', color:AC.ts, fontSize:13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: TextStyle(color:AC.ts, fontFamily:'Tajawal'))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('اعتماد', style: TextStyle(color:AC.ok, fontFamily:'Tajawal', fontWeight:FontWeight.w700))),
      ]));
    if (confirmed != true) return;
    setState(() => _approving = true);
    try {
      final r = await ApiService.approveCoa(widget.uploadId);
      if (r.success) {
        setState(() => _approved = true);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('✅ تم اعتماد شجرة الحسابات — جاهزة للتحليل', style: TextStyle(fontFamily:'Tajawal')), backgroundColor: AC.ok)); Navigator.of(context).pop({'approved': true, 'upload_id': widget.uploadId}); }
      } else { setState(() => _errorMsg = 'فشل الاعتماد'); }
    } catch (e) { setState(() => _errorMsg = 'خطأ: $e'); } finally { setState(() => _approving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _surface,
        title: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('مراجعة التبويب المقترح', style: TextStyle(fontFamily:'Tajawal', color:_textPri, fontSize:15, fontWeight:FontWeight.w700)),
          Text(widget.clientName, style: TextStyle(fontFamily:'Tajawal', color:_textSec, fontSize:12)),
        ]),
        actions: [if (!_approved) TextButton(onPressed: _bulkApproving ? null : _bulkApproveHigh, child: _bulkApproving ? SizedBox(width:16,height:16,child:CircularProgressIndicator(color:AC.gold,strokeWidth:2)) : Text('اعتماد عالي الثقة', style: TextStyle(color:AC.gold, fontSize:12, fontFamily:'Tajawal')))],
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Container(color:_border, height:1))),
      body: Column(children: [
        Expanded(child: Column(children: [
          Padding(padding: EdgeInsets.fromLTRB(16,14,16,0), child: StepIndicator(current: 3)),
          SizedBox(height:10),
          // ── ملخص ──
          Container(padding: EdgeInsets.symmetric(horizontal:14, vertical:10),
            decoration: BoxDecoration(color:AC.navy2, border: Border(bottom: BorderSide(color:AC.bdr))),
            child: Row(children: [
              _chip('ثقة عالية', '${_summary['high_confidence']??0}', _success),
              const SizedBox(width:6),
              _chip('ثقة متوسطة', '${_summary['low_confidence']??0}', _warning),
              SizedBox(width:6),
              _chip('غير مصنف', '${_summary['unclassified']??0}', _danger),
              Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${((((_summary['avg_confidence']??0.0) as num).toDouble())*100).toStringAsFixed(0)}% متوسط الثقة', style: TextStyle(fontSize:11, color:AC.gold, fontFamily:'Tajawal', fontWeight:FontWeight.w700)),
                Text('${_summary['total_accounts']??0} حساب', style: TextStyle(fontSize:10, color:AC.ts, fontFamily:'Tajawal')),
              ]),
            ])),
          // ── فلاتر ──
          Container(height:40, padding: EdgeInsets.symmetric(horizontal:12),
            decoration: BoxDecoration(color:AC.navy2, border: Border(bottom: BorderSide(color:AC.bdr))),
            child: Row(children: [
              for (final f in [('all','الكل'),('low','ثقة متوسطة'),('unclassified','غير مصنف'),('manual','معدّل')]) Padding(padding: EdgeInsets.only(left:8),
                child: GestureDetector(onTap: () { setState(() => _filter = f.$1); _loadAccounts(reset: true); },
                  child: AnimatedContainer(duration: Duration(milliseconds:150), padding: const EdgeInsets.symmetric(horizontal:10, vertical:4),
                    decoration: BoxDecoration(color: _filter==f.$1?_gold.withValues(alpha: 0.1):Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: _filter==f.$1?_gold:_border)),
                    child: Text(f.$2, style: TextStyle(fontSize:11, color:_filter==f.$1?_gold:_textSec, fontFamily:'Tajawal'))))),
            ])),
          // ── قائمة ──
          Expanded(child: _loading && _accounts.isEmpty
            ? Center(child: CircularProgressIndicator(color:AC.gold))
            : _accounts.isEmpty ? Center(child: Text('لا توجد نتائج', style: TextStyle(color:AC.ts, fontFamily:'Tajawal')))
            : ListView.builder(padding: EdgeInsets.all(12),
                itemCount: _accounts.length + (_accounts.length < _total ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _accounts.length) return Padding(padding: EdgeInsets.symmetric(vertical:16), child: Center(child: TextButton(onPressed: () { setState(() => _page++); _loadAccounts(); }, child: Text('تحميل المزيد', style: TextStyle(color:AC.gold, fontFamily:'Tajawal')))));
                  final acc = _accounts[i];
                  final conf = ((acc['mapping_confidence']??0.0) as num).toDouble();
                  final nc = acc['normalized_class']??'—'; final ss = acc['statement_section']??'';
                  final color = conf>=0.75?_success:conf>=0.40?_warning:_danger;
                  final approved = acc['record_status']=='approved';
                  return Container(margin: const EdgeInsets.only(bottom:8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: approved?_success.withValues(alpha: 0.2):color.withValues(alpha: 0.2))),
                    child: Column(children: [
                      Row(children: [
                        approved ? Icon(Icons.check_circle_rounded, color:_success, size:22)
                          : GestureDetector(onTap: () async {
                              await ApiService.approveAccount(acc['id']);
                              _loadAccounts(reset: true);
                            }, child: Container(width:28,height:28, decoration: BoxDecoration(shape:BoxShape.circle, border:Border.all(color:_success.withValues(alpha: 0.4))), child: Icon(Icons.check_rounded, color:_success, size:16))),
                        SizedBox(width:10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${(conf*100).toInt()}%', style: TextStyle(fontSize:12, fontWeight:FontWeight.w700, color:color, fontFamily:'Tajawal')),
                          SizedBox(width:36, child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value:conf.clamp(0.0,1.0), minHeight:3, backgroundColor:_border, valueColor:AlwaysStoppedAnimation(color)))),
                        ]),
                        Spacer(),
                        Expanded(flex:3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(acc['account_name_raw']??'—', textDirection:TextDirection.rtl, maxLines:1, overflow:TextOverflow.ellipsis, style: TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:AC.tp, fontFamily:'Tajawal')),
                          if ((acc['account_code']??'').isNotEmpty) Text(acc['account_code'], style: TextStyle(fontSize:10, color:AC.ts, fontFamily:'Tajawal')),
                        ])),
                      ]),
                      if (nc != '—' || ss.isNotEmpty) ...[
                        SizedBox(height:6),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (ss.isNotEmpty) Container(margin: EdgeInsets.only(right:6), padding: EdgeInsets.symmetric(horizontal:7,vertical:2), decoration: BoxDecoration(color:_gold.withValues(alpha: 0.06), borderRadius:BorderRadius.circular(4), border:Border.all(color:_gold.withValues(alpha: 0.15))), child: Text(ss, style: TextStyle(fontSize:10, color:AC.gold, fontFamily:'Tajawal'))),
                          Container(padding: const EdgeInsets.symmetric(horizontal:7,vertical:2), decoration: BoxDecoration(color:color.withValues(alpha: 0.08), borderRadius:BorderRadius.circular(4), border:Border.all(color:color.withValues(alpha: 0.2))), child: Text(nc, style: TextStyle(fontSize:10, color:color, fontFamily:'Tajawal', fontWeight:FontWeight.w600))),
                        ]),
                      ],
                    ]));
                })),
        ])),
        if (!_approved) Container(padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color:AC.navy2, border: Border(top: BorderSide(color:AC.bdr))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_errorMsg != null) Padding(padding: EdgeInsets.only(bottom:8), child: Text(_errorMsg!, style: TextStyle(color:_danger, fontSize:12, fontFamily:'Tajawal'))),
            Text('${((((_summary['high_confidence']??0) as num)/(((_summary['total_accounts']??1) as num)))*100).toStringAsFixed(0)}% من الحسابات بثقة عالية ≥ 75%', style: TextStyle(fontSize:11, color:AC.ts, fontFamily:'Tajawal')),
            const SizedBox(height:10),
            GestureDetector(onTap: _approving ? null : _approveAll,
              child: Container(width:double.infinity, height:54,
                decoration: BoxDecoration(gradient: LinearGradient(colors:[_success,_success.withValues(alpha: 0.7)]), borderRadius:BorderRadius.circular(14), boxShadow:[BoxShadow(color:_success.withValues(alpha: 0.3), blurRadius:12, offset:const Offset(0,4))]),
                child: Center(child: _approving ? SizedBox(width:22,height:22,child:CircularProgressIndicator(color:AC.btnFg,strokeWidth:2.5))
                  : Row(mainAxisAlignment:MainAxisAlignment.center, children:[Icon(Icons.verified_rounded,color:AC.btnFg,size:20),SizedBox(width:8),Text('اعتماد شجرة الحسابات',style:TextStyle(color:AC.btnFg,fontSize:15,fontWeight:FontWeight.w700,fontFamily:'Tajawal'))])))),
          ])),
      ]),
    );
  }

  Widget _chip(String label, String value, Color color) => Container(padding: EdgeInsets.symmetric(horizontal:8,vertical:4), decoration: BoxDecoration(color:color.withValues(alpha: 0.08), borderRadius:BorderRadius.circular(6), border:Border.all(color:color.withValues(alpha: 0.2))), child: Row(mainAxisSize:MainAxisSize.min, children:[Text(value,style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:color,fontFamily:'Tajawal')),SizedBox(width:4),Text(label,style:TextStyle(fontSize:9,color:AC.ts,fontFamily:'Tajawal'))]));
}

