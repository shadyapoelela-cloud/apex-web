import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'api_service.dart';
import 'shared_widgets.dart';
import 'core/theme.dart';

class CoaMappingScreen extends StatefulWidget {
  final Map<String,dynamic> uploadData;
  final String clientId, clientName;
  final PlatformFile pickedFile;
  const CoaMappingScreen({super.key, required this.uploadData, required this.clientId, required this.clientName, required this.pickedFile});
  @override State<CoaMappingScreen> createState() => _CoaMappingScreenState();
}

class _CoaMappingScreenState extends State<CoaMappingScreen> {
  bool _parsing = false;
  String _errorMsg = '';
  static Color get _bg => AC.navy;
  static Color get _surface => AC.navy2;
  static Color get _gold => AC.gold;
  static Color get _danger => AC.err;
  static Color get _border => AC.bdr;
  static Color get _textPri => AC.tp;
  static Color get _textSec => AC.ts;
  static const _fields  = ['account_code','account_name','parent_code','parent_name','level','account_type','normal_balance','active_flag','notes'];
  static const _labels  = {'account_code':'رقم الحساب','account_name':'اسم الحساب ★','parent_code':'رقم الأب','parent_name':'اسم الأب','level':'المستوى','account_type':'نوع الحساب','normal_balance':'طبيعة الرصيد','active_flag':'فعّال؟','notes':'ملاحظات'};

  late Map<String,String?> _mapping;
  List<String> get _cols => (widget.uploadData['detected_columns'] as List? ?? []).cast<String>();
  Map<String,String?> get _suggested => (widget.uploadData['suggested_column_mapping'] as Map? ?? {}).map((k,v) => MapEntry(k.toString(), v?.toString()));
  List<Map> get _samples => (widget.uploadData['sample_rows'] as List? ?? []).cast<Map>();
  bool get _canParse => _mapping['account_name'] != null && _mapping['account_name']!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _mapping = Map<String,String?>.from(_suggested);
    for (final f in _fields) _mapping.putIfAbsent(f, () => null);
  }

  Future<void> _runParse() async {
    if (!_canParse) { setState(() => _errorMsg = 'يجب ربط عمود اسم الحساب أولاً'); return; }
    setState(() { _parsing = true; _errorMsg = ''; });
    try {
      final uploadId = widget.uploadData['upload_id'];
      final cleanMapping = Map<String,String>.fromEntries(_mapping.entries.where((e) => e.value != null && e.value!.isNotEmpty).map((e) => MapEntry(e.key, e.value!)));
      final parseResult = await ApiService.parseCoa(uploadId: uploadId, columnMapping: cleanMapping);
      if (parseResult.success) {
        await ApiService.classifyCoa(uploadId);
        final assessResult = await ApiService.assessCoa(uploadId);
        final ad = assessResult.success ? assessResult.data as Map<String,dynamic> : <String,dynamic>{};
        if (!mounted) return;
        context.pushReplacement('/coa/quality', extra: {'uploadId': uploadId, 'clientId': widget.clientId, 'clientName': widget.clientName, 'assessData': ad});
      } else {
        setState(() => _errorMsg = parseResult.error ?? 'فشل الـ Parse');
      }
    } catch (e) { setState(() => _errorMsg = 'خطأ: $e'); }
    finally { setState(() => _parsing = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _surface,
        title: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('تأكيد الأعمدة', style: TextStyle(fontFamily:'Tajawal', color:_textPri, fontSize:15, fontWeight:FontWeight.w700)),
          Text(widget.clientName, style: TextStyle(fontFamily:'Tajawal', color:_textSec, fontSize:12)),
        ]),
        bottom: PreferredSize(preferredSize: Size.fromHeight(1), child: Container(color:_border, height:1))),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          StepIndicator(current: 1),
          const SizedBox(height: 16),
          HelpCard(icon: Icons.swap_horiz_rounded, title: 'ماذا يعني ربط الأعمدة؟', body: 'النظام اقترح ربط أعمدة ملفك بالحقول القياسية. راجع وعدّل أي ربط غير صحيح قبل المتابعة.'),
          SizedBox(height: 14),
          Container(padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color:_border)),
            child: Row(children: [
              SizedBox(width:8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(widget.pickedFile.name, textDirection: TextDirection.rtl, style: TextStyle(fontSize:12, fontWeight:FontWeight.w600, color:_textPri, fontFamily:'Tajawal'), overflow: TextOverflow.ellipsis),
                Text('${_cols.length} عمود مكتشف', style: TextStyle(fontSize:10, color:_textSec, fontFamily:'Tajawal')),
              ])),
              SizedBox(width:8),
              Icon(Icons.table_chart_rounded, color:_gold, size:22),
            ])),
          SizedBox(height: 14),
          Container(decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color:_border)),
            child: Column(children: _fields.asMap().entries.map((e) {
              final idx = e.key; final field = e.value;
              final label = (_labels as Map)[field] ?? field;
              final cur = _mapping[field];
              final isReq = field == 'account_name';
              final isLast = idx == _fields.length - 1;
              return Column(children: [
                Padding(padding: EdgeInsets.symmetric(horizontal:12, vertical:8), child: Row(children: [
                  Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String?>(
                    value: cur, dropdownColor: AC.navy3,
                    style: TextStyle(color:_textPri, fontFamily:'Tajawal', fontSize:12),
                    hint: Text('— لا يوجد —', style: TextStyle(color:AC.ts, fontFamily:'Tajawal', fontSize:12)),
                    isExpanded: true,
                    items: [DropdownMenuItem<String?>(value: null, child: Text('— لا يوجد —', style: TextStyle(color:AC.ts, fontFamily:'Tajawal', fontSize:12))), ..._cols.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c, style: TextStyle(fontFamily:'Tajawal', fontSize:12))))],
                    onChanged: (v) => setState(() => _mapping[field] = v)))),
                  SizedBox(width:10),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (cur != null) Container(width:7, height:7, margin: EdgeInsets.only(left:5), decoration: BoxDecoration(shape: BoxShape.circle, color: AC.ok)),
                    Text(label, textDirection: TextDirection.rtl, style: TextStyle(fontSize:12, color: isReq ? _gold : _textPri, fontWeight: isReq ? FontWeight.w700 : FontWeight.w400, fontFamily:'Tajawal')),
                  ]),
                ])),
                if (!isLast) Divider(color:_border, height:1, indent:12, endIndent:12),
              ]);
            }).toList())),
          if (_samples.isNotEmpty) ...[
            SizedBox(height: 14),
            Container(decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color:_border)),
              child: Column(children: _samples.take(5).toList().asMap().entries.map((e) {
                final row = e.value; final isLast = e.key == (_samples.length > 5 ? 4 : _samples.length - 1);
                final nc = _mapping['account_name']; final cc = _mapping['account_code'];
                final name = nc != null ? (row[nc] ?? '—').toString() : '—';
                final code = cc != null ? (row[cc] ?? '').toString() : '';
                return Column(children: [
                  Padding(padding: EdgeInsets.symmetric(horizontal:12, vertical:8), child: Row(children: [
                    if (code.isNotEmpty) Container(padding: EdgeInsets.symmetric(horizontal:7, vertical:2), decoration: BoxDecoration(color:_gold.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(4)), child: Text(code, style: TextStyle(fontSize:10, color:_gold, fontFamily:'Tajawal'))),
                    Spacer(),
                    Expanded(flex:3, child: Text(name, textDirection: TextDirection.rtl, style: TextStyle(fontSize:12, color:_textPri, fontFamily:'Tajawal'), overflow: TextOverflow.ellipsis)),
                  ])),
                  if (!isLast) Divider(color:_border, height:1, indent:12, endIndent:12),
                ]);
              }).toList())),
          ],
          if (_errorMsg.isNotEmpty) ...[
            const SizedBox(height:12),
            Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color:_danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color:_danger.withValues(alpha: 0.3))),
              child: Row(children: [Icon(Icons.error_outline_rounded, color:_danger, size:16), SizedBox(width:8), Expanded(child: Text(_errorMsg, textDirection: TextDirection.rtl, style: TextStyle(fontSize:12, color:_danger, fontFamily:'Tajawal')))])),
          ],
          SizedBox(height: 80),
        ]))),
        Container(padding: EdgeInsets.all(16),
          decoration: BoxDecoration(color: AC.navy2, border: Border(top: BorderSide(color: AC.bdr))),
          child: GestureDetector(onTap: (_canParse && !_parsing) ? _runParse : null,
            child: Container(height: 54,
              decoration: BoxDecoration(
                gradient: (_canParse && !_parsing) ? LinearGradient(colors:[AC.gold, AC.gold.withValues(alpha: 0.7)]) : null,
                color: (!_canParse || _parsing) ? AC.tp.withValues(alpha: 0.05) : null,
                borderRadius: BorderRadius.circular(14),
                border: (!_canParse || _parsing) ? Border.all(color: AC.tp.withValues(alpha: 0.1)) : null),
              child: Center(child: _parsing
                ? SizedBox(width:22, height:22, child: CircularProgressIndicator(color: AC.navy, strokeWidth:2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.play_arrow_rounded, color: _canParse ? AC.navy : AC.td, size:20),
                    SizedBox(width:8),
                    Text('تأكيد وتحليل الأعمدة', style: TextStyle(color: _canParse ? AC.navy : AC.td, fontSize:15, fontWeight:FontWeight.w700, fontFamily:'Tajawal')),
                  ])))),
        ),
      ]),
    );
  }
}

