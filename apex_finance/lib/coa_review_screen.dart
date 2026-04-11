import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'core/api_config.dart';
import 'shared_widgets.dart';

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
  static const _bg      = Color(0xFF050D1A);
  static const _surface = Color(0xFF080F1F);
  static const _gold    = Color(0xFFC9A84C);
  static const _success = Color(0xFF2ECC8A);
  static const _danger  = Color(0xFFE05050);
  static const _warning = Color(0xFFE8A838);
  static const _border  = Color(0x26C9A84C);
  static const _textPri = Color(0xFFF0EDE6);
  static const _textSec = Color(0xFF8A8880);
  static const _base    = apiBase;

  @override void initState() { super.initState(); _loadSummary(); _loadAccounts(); }

  Future<void> _loadSummary() async {
    try {
      final res = await http.get(Uri.parse('$_base/coa/classification-summary/${widget.uploadId}'));
      if (res.statusCode == 200) setState(() => _summary = jsonDecode(res.body));
    } catch (_) {}
  }

  Future<void> _loadAccounts({bool reset = false}) async {
    if (reset) setState(() { _page = 1; _accounts = []; });
    setState(() => _loading = true);
    try {
      final params = <String,String>{'page': _page.toString(), 'page_size': '40'};
      if (_filter == 'low')         params['confidence_max'] = '0.74';
      if (_filter == 'unclassified') params['confidence_max'] = '0.39';
      if (_filter == 'manual')      params['review_status'] = 'manually_edited';
      final uri = Uri.parse('$_base/coa/mapping/${widget.uploadId}').replace(queryParameters: params);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String,dynamic>;
        final items = (data['accounts'] as List).cast<Map<String,dynamic>>();
        setState(() { _total = data['total'] ?? 0; if (reset || _page == 1) _accounts = items; else _accounts.addAll(items); });
      }
    } catch (_) {} finally { setState(() => _loading = false); }
  }

  Future<void> _bulkApproveHigh() async {
    setState(() => _bulkApproving = true);
    try {
      final res = await http.post(Uri.parse('$_base/coa/bulk-approve/${widget.uploadId}'), headers: {'Content-Type':'application/json'}, body: jsonEncode({'min_confidence': 0.75}));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ تم اعتماد ${data["approved_count"]} حساب', style: const TextStyle(fontFamily:'Tajawal')), backgroundColor: _success)); _loadSummary(); _loadAccounts(reset: true); }
      }
    } catch (_) {} finally { setState(() => _bulkApproving = false); }
  }

  Future<void> _approveAll() async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF0D1829),
      title: const Text('اعتماد شجرة الحسابات', textDirection: TextDirection.rtl, style: TextStyle(fontFamily:'Tajawal', color:Color(0xFFF0EDE6), fontSize:15)),
      content: const Text('سيتم اعتماد شجرة الحسابات كمرجع للتحليل. هل أنت متأكد؟', textDirection: TextDirection.rtl, style: TextStyle(fontFamily:'Tajawal', color:Color(0xFF8A8880), fontSize:13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(color:Color(0xFF8A8880), fontFamily:'Tajawal'))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('اعتماد', style: TextStyle(color:Color(0xFF2ECC8A), fontFamily:'Tajawal', fontWeight:FontWeight.w700))),
      ]));
    if (confirmed != true) return;
    setState(() => _approving = true);
    try {
      final res = await http.post(Uri.parse('$_base/coa/uploads/${widget.uploadId}/approve'), headers: {'Content-Type':'application/json'}, body: jsonEncode({}));
      if (res.statusCode == 200) {
        setState(() => _approved = true);
        if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ تم اعتماد شجرة الحسابات — جاهزة للتحليل', style: TextStyle(fontFamily:'Tajawal')), backgroundColor: Color(0xFF2ECC8A))); Navigator.of(context).pop({'approved': true, 'upload_id': widget.uploadId}); }
      } else { setState(() => _errorMsg = 'فشل الاعتماد'); }
    } catch (e) { setState(() => _errorMsg = 'خطأ: $e'); } finally { setState(() => _approving = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _surface,
        title: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('مراجعة التبويب المقترح', style: TextStyle(fontFamily:'Tajawal', color:_textPri, fontSize:15, fontWeight:FontWeight.w700)),
          Text(widget.clientName, style: const TextStyle(fontFamily:'Tajawal', color:_textSec, fontSize:12)),
        ]),
        actions: [if (!_approved) TextButton(onPressed: _bulkApproving ? null : _bulkApproveHigh, child: _bulkApproving ? const SizedBox(width:16,height:16,child:CircularProgressIndicator(color:Color(0xFFC9A84C),strokeWidth:2)) : const Text('اعتماد عالي الثقة', style: TextStyle(color:Color(0xFFC9A84C), fontSize:12, fontFamily:'Tajawal')))],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color:_border, height:1))),
      body: Column(children: [
        Expanded(child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(16,14,16,0), child: StepIndicator(current: 3)),
          const SizedBox(height:10),
          // ── ملخص ──
          Container(padding: const EdgeInsets.symmetric(horizontal:14, vertical:10),
            decoration: const BoxDecoration(color:Color(0xFF080F1F), border: Border(bottom: BorderSide(color:Color(0x26C9A84C)))),
            child: Row(children: [
              _chip('ثقة عالية', '${_summary['high_confidence']??0}', _success),
              const SizedBox(width:6),
              _chip('ثقة متوسطة', '${_summary['low_confidence']??0}', _warning),
              const SizedBox(width:6),
              _chip('غير مصنف', '${_summary['unclassified']??0}', _danger),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${((((_summary['avg_confidence']??0.0) as num).toDouble())*100).toStringAsFixed(0)}% متوسط الثقة', style: const TextStyle(fontSize:11, color:Color(0xFFC9A84C), fontFamily:'Tajawal', fontWeight:FontWeight.w700)),
                Text('${_summary['total_accounts']??0} حساب', style: const TextStyle(fontSize:10, color:Color(0xFF8A8880), fontFamily:'Tajawal')),
              ]),
            ])),
          // ── فلاتر ──
          Container(height:40, padding: const EdgeInsets.symmetric(horizontal:12),
            decoration: const BoxDecoration(color:Color(0xFF080F1F), border: Border(bottom: BorderSide(color:Color(0x26C9A84C)))),
            child: Row(children: [
              for (final f in [('all','الكل'),('low','ثقة متوسطة'),('unclassified','غير مصنف'),('manual','معدّل')]) Padding(padding: const EdgeInsets.only(left:8),
                child: GestureDetector(onTap: () { setState(() => _filter = f.$1); _loadAccounts(reset: true); },
                  child: AnimatedContainer(duration: const Duration(milliseconds:150), padding: const EdgeInsets.symmetric(horizontal:10, vertical:4),
                    decoration: BoxDecoration(color: _filter==f.$1?_gold.withOpacity(0.1):Colors.transparent, borderRadius: BorderRadius.circular(6), border: Border.all(color: _filter==f.$1?_gold:_border)),
                    child: Text(f.$2, style: TextStyle(fontSize:11, color:_filter==f.$1?_gold:_textSec, fontFamily:'Tajawal'))))),
            ])),
          // ── قائمة ──
          Expanded(child: _loading && _accounts.isEmpty
            ? const Center(child: CircularProgressIndicator(color:Color(0xFFC9A84C)))
            : _accounts.isEmpty ? const Center(child: Text('لا توجد نتائج', style: TextStyle(color:Color(0xFF8A8880), fontFamily:'Tajawal')))
            : ListView.builder(padding: const EdgeInsets.all(12),
                itemCount: _accounts.length + (_accounts.length < _total ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _accounts.length) return Padding(padding: const EdgeInsets.symmetric(vertical:16), child: Center(child: TextButton(onPressed: () { setState(() => _page++); _loadAccounts(); }, child: const Text('تحميل المزيد', style: TextStyle(color:Color(0xFFC9A84C), fontFamily:'Tajawal')))));
                  final acc = _accounts[i];
                  final conf = ((acc['mapping_confidence']??0.0) as num).toDouble();
                  final nc = acc['normalized_class']??'—'; final ss = acc['statement_section']??'';
                  final color = conf>=0.75?_success:conf>=0.40?_warning:_danger;
                  final approved = acc['record_status']=='approved';
                  return Container(margin: const EdgeInsets.only(bottom:8), padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFF0D1829), borderRadius: BorderRadius.circular(12), border: Border.all(color: approved?_success.withOpacity(0.2):color.withOpacity(0.2))),
                    child: Column(children: [
                      Row(children: [
                        approved ? const Icon(Icons.check_circle_rounded, color:Color(0xFF2ECC8A), size:22)
                          : GestureDetector(onTap: () async {
                              await http.post(Uri.parse('$_base/coa/approve/${acc['id']}'), headers: {'Content-Type':'application/json'});
                              _loadAccounts(reset: true);
                            }, child: Container(width:28,height:28, decoration: BoxDecoration(shape:BoxShape.circle, border:Border.all(color:_success.withOpacity(0.4))), child: const Icon(Icons.check_rounded, color:Color(0xFF2ECC8A), size:16))),
                        const SizedBox(width:10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${(conf*100).toInt()}%', style: TextStyle(fontSize:12, fontWeight:FontWeight.w700, color:color, fontFamily:'Tajawal')),
                          SizedBox(width:36, child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value:conf.clamp(0.0,1.0), minHeight:3, backgroundColor:_border, valueColor:AlwaysStoppedAnimation(color)))),
                        ]),
                        const Spacer(),
                        Expanded(flex:3, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(acc['account_name_raw']??'—', textDirection:TextDirection.rtl, maxLines:1, overflow:TextOverflow.ellipsis, style: const TextStyle(fontSize:13, fontWeight:FontWeight.w600, color:Color(0xFFF0EDE6), fontFamily:'Tajawal')),
                          if ((acc['account_code']??'').isNotEmpty) Text(acc['account_code'], style: const TextStyle(fontSize:10, color:Color(0xFF8A8880), fontFamily:'Tajawal')),
                        ])),
                      ]),
                      if (nc != '—' || ss.isNotEmpty) ...[
                        const SizedBox(height:6),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          if (ss.isNotEmpty) Container(margin: const EdgeInsets.only(right:6), padding: const EdgeInsets.symmetric(horizontal:7,vertical:2), decoration: BoxDecoration(color:_gold.withOpacity(0.06), borderRadius:BorderRadius.circular(4), border:Border.all(color:_gold.withOpacity(0.15))), child: Text(ss, style: const TextStyle(fontSize:10, color:Color(0xFFC9A84C), fontFamily:'Tajawal'))),
                          Container(padding: const EdgeInsets.symmetric(horizontal:7,vertical:2), decoration: BoxDecoration(color:color.withOpacity(0.08), borderRadius:BorderRadius.circular(4), border:Border.all(color:color.withOpacity(0.2))), child: Text(nc, style: TextStyle(fontSize:10, color:color, fontFamily:'Tajawal', fontWeight:FontWeight.w600))),
                        ]),
                      ],
                    ]));
                })),
        ])),
        if (!_approved) Container(padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color:Color(0xFF080F1F), border: Border(top: BorderSide(color:Color(0x26C9A84C)))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_errorMsg != null) Padding(padding: const EdgeInsets.only(bottom:8), child: Text(_errorMsg!, style: const TextStyle(color:Color(0xFFE05050), fontSize:12, fontFamily:'Tajawal'))),
            Text('${((((_summary['high_confidence']??0) as num)/(((_summary['total_accounts']??1) as num)))*100).toStringAsFixed(0)}% من الحسابات بثقة عالية ≥ 75%', style: const TextStyle(fontSize:11, color:Color(0xFF8A8880), fontFamily:'Tajawal')),
            const SizedBox(height:10),
            GestureDetector(onTap: _approving ? null : _approveAll,
              child: Container(width:double.infinity, height:54,
                decoration: BoxDecoration(gradient: const LinearGradient(colors:[Color(0xFF2ECC8A),Color(0xFF1A8C5C)]), borderRadius:BorderRadius.circular(14), boxShadow:[BoxShadow(color:_success.withOpacity(0.3), blurRadius:12, offset:const Offset(0,4))]),
                child: Center(child: _approving ? const SizedBox(width:22,height:22,child:CircularProgressIndicator(color:Colors.white,strokeWidth:2.5))
                  : const Row(mainAxisAlignment:MainAxisAlignment.center, children:[Icon(Icons.verified_rounded,color:Colors.white,size:20),SizedBox(width:8),Text('اعتماد شجرة الحسابات',style:TextStyle(color:Colors.white,fontSize:15,fontWeight:FontWeight.w700,fontFamily:'Tajawal'))])))),
          ])),
      ]),
    );
  }

  Widget _chip(String label, String value, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal:8,vertical:4), decoration: BoxDecoration(color:color.withOpacity(0.08), borderRadius:BorderRadius.circular(6), border:Border.all(color:color.withOpacity(0.2))), child: Row(mainAxisSize:MainAxisSize.min, children:[Text(value,style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:color,fontFamily:'Tajawal')),const SizedBox(width:4),Text(label,style:const TextStyle(fontSize:9,color:Color(0xFF8A8880),fontFamily:'Tajawal'))]));
}

