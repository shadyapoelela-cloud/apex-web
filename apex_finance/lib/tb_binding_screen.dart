import 'package:flutter/material.dart';
import 'api_service.dart';

class TbBindingScreen extends StatefulWidget {
  final String tbUploadId;
  final String? coaUploadId;
  const TbBindingScreen({super.key, required this.tbUploadId, this.coaUploadId});
  @override State<TbBindingScreen> createState() => _TbBindingScreenState();
}

class _TbBindingScreenState extends State<TbBindingScreen> {
  bool _loadingBind = false, _loadingResults = false, _approving = false, _bound = false, _approved = false;
  String _filter = 'all';
  int _page = 1, _total = 0;
  Map<String,dynamic> _summary = {};
  List<Map<String,dynamic>> _results = [];
  String? _errorMsg;
  static const _bg      = Color(0xFF050D1A);
  static const _surface = Color(0xFF080F1F);
  static const _card    = Color(0xFF0D1829);
  static const _gold    = Color(0xFFC9A84C);
  static const _cyan    = Color(0xFF00C2E0);
  static const _success = Color(0xFF2ECC8A);
  static const _danger  = Color(0xFFE05050);
  static const _warning = Color(0xFFE8A838);
  static const _border  = Color(0x26C9A84C);
  static const _textPri = Color(0xFFF0EDE6);
  static const _textSec = Color(0xFF8A8880);
  @override void initState() { super.initState(); _checkExisting(); }

  Future<void> _checkExisting() async {
    setState(() => _loadingResults = true);
    try {
      final r = await ApiService.getBindingSummary(widget.tbUploadId);
      if (r.success) { setState(() { _summary = r.data as Map<String,dynamic>; _bound = true; }); await _loadResults(); }
    } catch (_) {} finally { setState(() => _loadingResults = false); }
  }

  Future<void> _runBinding() async {
    setState(() { _loadingBind = true; _errorMsg = null; });
    try {
      final r = await ApiService.bindTb(tbUploadId: widget.tbUploadId, coaUploadId: widget.coaUploadId);
      if (r.success) {
        setState(() => _bound = true);
        await _loadSummary(); await _loadResults();
      } else { setState(() => _errorMsg = r.error ?? 'فشل الـ Binding'); }
    } catch (e) { setState(() => _errorMsg = 'خطأ: $e'); } finally { setState(() => _loadingBind = false); }
  }

  Future<void> _loadSummary() async {
    try { final r = await ApiService.getBindingSummary(widget.tbUploadId); if (r.success) setState(() => _summary = r.data as Map<String,dynamic>); } catch (_) {}
  }

  Future<void> _loadResults({bool reset = false}) async {
    if (reset) setState(() { _page = 1; _results = []; });
    setState(() => _loadingResults = true);
    try {
      final r = await ApiService.getBindingResults(tbUploadId: widget.tbUploadId, page: _page, filter: _filter);
      if (r.success) {
        final data = r.data as Map<String,dynamic>;
        final items = (data['results'] as List).cast<Map<String,dynamic>>();
        setState(() { _total = data['total'] ?? 0; if (reset || _page == 1) _results = items; else _results.addAll(items); });
      }
    } catch (_) {} finally { setState(() => _loadingResults = false); }
  }

  Future<void> _approveBinding() async {
    setState(() => _approving = true);
    try {
      final r = await ApiService.approveBinding(widget.tbUploadId);
      if (r.success) {
        setState(() => _approved = true);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم اعتماد الربط — جاهز للتحليل', style: TextStyle(fontFamily:'Tajawal')), backgroundColor: _success)); Navigator.of(context).pop({'approved': true}); }
      } else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل الاعتماد'), backgroundColor: _danger)); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: _danger)); }
    finally { setState(() => _approving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _surface,
        title: const Text('ربط ميزان المراجعة', style: TextStyle(fontFamily:'Tajawal', color:Color(0xFFF0EDE6), fontSize:15, fontWeight:FontWeight.w700)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color:_border, height:1))),
      body: Column(children: [
        Expanded(child: _bound ? _buildResults() : _buildPrompt()),
        if (_bound && !_approved) _buildApproveBar(),
      ]),
    );
  }

  Widget _buildPrompt() => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width:72,height:72, decoration: BoxDecoration(color:_gold.withOpacity(0.08), shape:BoxShape.circle, border:Border.all(color:_gold.withOpacity(0.3))), child: const Icon(Icons.link_rounded, color:Color(0xFFC9A84C), size:34)),
    const SizedBox(height:20),
    const Text('ربط ميزان المراجعة بشجرة الحسابات', textDirection:TextDirection.rtl, textAlign:TextAlign.center, style:TextStyle(fontSize:17, fontWeight:FontWeight.w700, color:Color(0xFFF0EDE6), fontFamily:'Tajawal')),
    const SizedBox(height:10),
    const Text('سيتم مطابقة كل حساب في الميزان بالحسابات المعتمدة في شجرة الحسابات تلقائياً', textDirection:TextDirection.rtl, textAlign:TextAlign.center, style:TextStyle(fontSize:13, color:Color(0xFF8A8880), fontFamily:'Tajawal', height:1.6)),
    if (_errorMsg != null) ...[const SizedBox(height:16), Container(padding:const EdgeInsets.all(12), decoration:BoxDecoration(color:_danger.withOpacity(0.08), borderRadius:BorderRadius.circular(10), border:Border.all(color:_danger.withOpacity(0.3))), child:Row(children:[const Icon(Icons.error_outline_rounded,color:Color(0xFFE05050),size:16),const SizedBox(width:8),Expanded(child:Text(_errorMsg!,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:12,color:Color(0xFFE05050),fontFamily:'Tajawal')))]))],
    const SizedBox(height:28),
    GestureDetector(onTap: _loadingBind ? null : _runBinding,
      child: Container(width:double.infinity, height:54,
        decoration: BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFC9A84C),Color(0xFF8B6F35)]), borderRadius:BorderRadius.circular(14), boxShadow:[BoxShadow(color:_gold.withOpacity(0.3),blurRadius:16,offset:const Offset(0,4))]),
        child: Center(child: _loadingBind ? const SizedBox(width:22,height:22,child:CircularProgressIndicator(color:Color(0xFF050D1A),strokeWidth:2.5))
          : const Row(mainAxisAlignment:MainAxisAlignment.center, children:[Icon(Icons.link_rounded,color:Color(0xFF050D1A),size:20),SizedBox(width:8),Text('تشغيل الربط الآن',style:TextStyle(color:Color(0xFF050D1A),fontSize:15,fontWeight:FontWeight.w700,fontFamily:'Tajawal'))])))),
  ])));

  Widget _buildResults() {
    final matched = _summary['matched'] ?? 0;
    final unmatched = _summary['unmatched'] ?? 0;
    final total = _summary['total_rows'] ?? 0;
    final review = _summary['requires_review'] ?? 0;
    final pct = ((_summary['match_percentage'] ?? 0.0) as num).toDouble();
    final avgConf = ((_summary['avg_confidence'] ?? 0.0) as num).toDouble();
    final pctColor = pct >= 90 ? _success : pct >= 70 ? _warning : _danger;
    return Column(children: [
      Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color:Color(0xFF080F1F), border:Border(bottom:BorderSide(color:Color(0x26C9A84C)))),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${pct.toStringAsFixed(1)}% نسبة الربط', style: TextStyle(fontSize:13, fontWeight:FontWeight.w700, color:pctColor, fontFamily:'Tajawal')),
            Text('إجمالي: $total حساب', style: const TextStyle(fontSize:12, color:Color(0xFF8A8880), fontFamily:'Tajawal')),
          ]),
          const SizedBox(height:8),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value:(pct/100).clamp(0.0,1.0), minHeight:6, backgroundColor:_border, valueColor:AlwaysStoppedAnimation(pctColor))),
          const SizedBox(height:10),
          Row(children: [
            _sChip('مطابق','$matched',_success), const SizedBox(width:8),
            _sChip('غير مطابق','$unmatched',_danger), const SizedBox(width:8),
            _sChip('مراجعة','$review',_warning), const SizedBox(width:8),
            _sChip('متوسط الثقة','${(avgConf*100).toStringAsFixed(0)}%',_cyan),
          ]),
        ])),
      Container(height:40, padding:const EdgeInsets.symmetric(horizontal:12), decoration:const BoxDecoration(color:Color(0xFF080F1F),border:Border(bottom:BorderSide(color:Color(0x26C9A84C)))),
        child:Row(children:[
          for(final f in [('all','الكل'),('matched','مطابق'),('unmatched','غير مطابق'),('review','مراجعة')]) Padding(padding:const EdgeInsets.only(left:8),
            child:GestureDetector(onTap:(){setState(()=>_filter=f.$1);_loadResults(reset:true);},
              child:AnimatedContainer(duration:const Duration(milliseconds:150),padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),
                decoration:BoxDecoration(color:_filter==f.$1?_gold.withOpacity(0.1):Colors.transparent,borderRadius:BorderRadius.circular(6),border:Border.all(color:_filter==f.$1?_gold:_border)),
                child:Text(f.$2,style:TextStyle(fontSize:11,color:_filter==f.$1?_gold:_textSec,fontFamily:'Tajawal'))))),
        ])),
      Expanded(child: _loadingResults && _results.isEmpty ? const Center(child:CircularProgressIndicator(color:Color(0xFFC9A84C)))
        : _results.isEmpty ? const Center(child:Text('لا توجد نتائج',style:TextStyle(color:Color(0xFF8A8880),fontFamily:'Tajawal')))
        : ListView.builder(padding:const EdgeInsets.all(12), itemCount:_results.length+(_results.length<_total?1:0),
            itemBuilder:(_,i){
              if(i==_results.length) return Padding(padding:const EdgeInsets.symmetric(vertical:16),child:Center(child:TextButton(onPressed:(){setState(()=>_page++);_loadResults();},child:const Text('تحميل المزيد',style:TextStyle(color:Color(0xFFC9A84C),fontFamily:'Tajawal')))));
              final r=_results[i];
              final matched=r['matched']==true;
              final conf=((r['confidence']??0.0)as num).toDouble();
              final review=r['requires_review']==true;
              final color=matched?(conf>=0.9?_success:_warning):_danger;
              final mt=r['match_type']??'';
              final label=matched?(mt=='exact'?'مطابقة تامة':mt=='normalized'?'مطابقة بعد التطبيع':'مطابقة تقريبية'):'غير مطابق';
              final net=((r['tb_net']??0.0)as num).toDouble();
              return Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),
                decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(12),border:Border.all(color:review?_warning.withOpacity(0.3):color.withOpacity(0.2))),
                child:Column(children:[
                  Row(children:[
                    Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:2),decoration:BoxDecoration(color:color.withOpacity(0.1),borderRadius:BorderRadius.circular(4),border:Border.all(color:color.withOpacity(0.3))),child:Text(label,style:TextStyle(fontSize:10,color:color,fontFamily:'Tajawal',fontWeight:FontWeight.w600))),
                    if(review)...[const SizedBox(width:6),Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),decoration:BoxDecoration(color:_warning.withOpacity(0.08),borderRadius:BorderRadius.circular(4)),child:const Text('يحتاج مراجعة',style:TextStyle(fontSize:9,color:Color(0xFFE8A838),fontFamily:'Tajawal')))],
                    const Spacer(),
                    Expanded(flex:3,child:Text(r['tb_account_name']??'—',textDirection:TextDirection.rtl,textAlign:TextAlign.end,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w600,color:Color(0xFFF0EDE6),fontFamily:'Tajawal'))),
                  ]),
                  const SizedBox(height:8),
                  Row(children:[
                    Text(net>=1e6?'${(net/1e6).toStringAsFixed(1)}M':net>=1e3?'${(net/1e3).toStringAsFixed(1)}K':net.toStringAsFixed(0),style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:net>=0?_success:_danger,fontFamily:'Tajawal')),
                    const SizedBox(width:4),const Text('صافي',style:TextStyle(fontSize:10,color:Color(0xFF8A8880),fontFamily:'Tajawal')),
                    const Spacer(),
                    SizedBox(width:60,child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text('${(conf*100).toInt()}%',style:TextStyle(fontSize:10,color:color,fontFamily:'Tajawal')),const SizedBox(height:2),ClipRRect(borderRadius:BorderRadius.circular(2),child:LinearProgressIndicator(value:conf.clamp(0.0,1.0),minHeight:3,backgroundColor:_border,valueColor:AlwaysStoppedAnimation(color)))])),
                  ]),
                  if(matched&&r['coa_class']!=null)...[const SizedBox(height:5),Align(alignment:Alignment.centerRight,child:Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:2),decoration:BoxDecoration(color:_gold.withOpacity(0.06),borderRadius:BorderRadius.circular(4),border:Border.all(color:_gold.withOpacity(0.15))),child:Text('${r["coa_class"]} — ${r["coa_section"]??""}',style:const TextStyle(fontSize:10,color:Color(0xFFC9A84C),fontFamily:'Tajawal'))))],
                ]));
            })),
    ]);
  }

  Widget _buildApproveBar() {
    final pct = ((_summary['match_percentage'] ?? 0.0) as num).toDouble();
    final canApprove = pct >= 70;
    return Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(color:Color(0xFF080F1F), border:Border(top:BorderSide(color:Color(0x26C9A84C)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!canApprove) Padding(padding: const EdgeInsets.only(bottom:10), child: Row(children: [const Icon(Icons.info_outline_rounded,color:Color(0xFFE8A838),size:14),const SizedBox(width:6),const Expanded(child:Text('نسبة الربط أقل من 70% — يُنصح بمراجعة الحسابات غير المطابقة',textDirection:TextDirection.rtl,style:TextStyle(fontSize:11,color:Color(0xFFE8A838),fontFamily:'Tajawal')))])),
        GestureDetector(onTap: _approving ? null : _approveBinding,
          child: Container(width:double.infinity, height:52,
            decoration: BoxDecoration(
              gradient: canApprove ? const LinearGradient(colors:[Color(0xFF2ECC8A),Color(0xFF1A8C5C)]) : const LinearGradient(colors:[Color(0xFF444444),Color(0xFF333333)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: canApprove ? [BoxShadow(color:const Color(0xFF2ECC8A).withOpacity(0.3),blurRadius:12,offset:const Offset(0,4))] : []),
            child: Center(child: _approving ? const SizedBox(width:22,height:22,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2.5))
              : Row(mainAxisAlignment:MainAxisAlignment.center, children:[Icon(Icons.check_circle_rounded,color:canApprove?Colors.white:Colors.white38,size:20),const SizedBox(width:8),Text('اعتماد الربط والمتابعة للتحليل',style:TextStyle(color:canApprove?Colors.white:Colors.white38,fontSize:15,fontWeight:FontWeight.w700,fontFamily:'Tajawal'))])))),
      ]));
  }

  Widget _sChip(String label, String value, Color color) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical:7), decoration: BoxDecoration(color:color.withOpacity(0.06), borderRadius:BorderRadius.circular(8), border:Border.all(color:color.withOpacity(0.2))), child: Column(children: [Text(value,style:TextStyle(fontSize:14,fontWeight:FontWeight.w800,color:color,fontFamily:'Tajawal')),const SizedBox(height:2),Text(label,textAlign:TextAlign.center,style:const TextStyle(fontSize:9,color:Color(0xFF8A8880),fontFamily:'Tajawal'))])));
}
