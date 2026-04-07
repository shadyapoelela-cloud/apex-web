import '../../api_service.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';
import '../../core/session.dart';
import '../../core/shared_constants.dart';

final _api = apiBase;

// ── 3. COA Upload Screen ──
class CoaUploadScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  const CoaUploadScreen({super.key, required this.clientId, required this.clientName});
  @override State<CoaUploadScreen> createState() => _CoaUploadS();
}
class _CoaUploadS extends State<CoaUploadScreen> {
  bool _uploading = false;
  Map<String, dynamic>? _uploadResult;
  String? _err;

  Future<void> _pickAndUpload() async {
    setState(() { _uploading = true; _err = null; });
    try {
      final input = html.FileUploadInputElement()..accept = '.csv,.xlsx,.xls';
      input.click();
      await input.onChange.first;
      if (input.files == null || input.files!.isEmpty) { setState(() => _uploading = false); return; }
      final file = input.files!.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoadEnd.first;
      final bytes = reader.result as List<int>;

      final uri = Uri.parse('$_api/clients/${widget.clientId}/coa/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final d = jsonDecode(body);

      if (response.statusCode == 200) {
        setState(() { _uploadResult = d; _uploading = false; });
      } else {
        setState(() { _err = d['detail']?.toString() ?? d['message'] ?? 'فشل الرفع'; _uploading = false; });
      }
    } catch (e) { setState(() { _err = 'خطأ: $e'; _uploading = false; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: Text('رفع شجرة الحسابات — ${widget.clientName}', style: const TextStyle(color: AC.gold, fontSize: 14))),
    body: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Step indicator
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _stepDot('رفع', 1, true), _stepLine(), _stepDot('أعمدة', 2, _uploadResult != null),
          _stepLine(), _stepDot('تحليل', 3, false), _stepLine(), _stepDot('معاينة', 4, false),
        ]),
        const SizedBox(height: 32),
        if (_err != null) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center)),

        if (_uploadResult == null) ...[
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AC.gold.withOpacity(0.3), width: 2, style: BorderStyle.solid)),
            child: Column(children: [
              Icon(_uploading ? Icons.hourglass_top : Icons.cloud_upload_outlined, size: 72, color: AC.gold),
              const SizedBox(height: 16),
              Text(_uploading ? 'جاري رفع الملف...' : 'اختر ملف شجرة الحسابات',
                style: const TextStyle(color: AC.tp, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('CSV / Excel (.xlsx / .xls)', style: TextStyle(color: AC.ts, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('الحد الأقصى: 15 ميجابايت', style: TextStyle(color: AC.ts, fontSize: 12)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.file_upload),
                label: Text(_uploading ? 'جاري الرفع...' : 'اختيار ملف'),
                onPressed: _uploading ? null : _pickAndUpload,
                style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14))),
            ])),
        ] else ...[
          // Upload success — show detection results
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent.withOpacity(0.15)), child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('تم رفع: ${_uploadResult!['file_name']}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                Text('الأعمدة المكتشفة: ${(_uploadResult!['detected_columns'] as List?)?.length ?? 0}',
                  style: const TextStyle(color: AC.ts, fontSize: 12)),
              ])),
            ])),
          const SizedBox(height: 16),
          if ((_uploadResult!['warnings'] as List?)?.isNotEmpty == true)
            ...(_uploadResult!['warnings'] as List).map((w) => Container(
              padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: AC.warn.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: Text(w.toString(), style: const TextStyle(color: AC.warn, fontSize: 12)))),
          const SizedBox(height: 16),
          SizedBox(height: 52, child: ElevatedButton.icon(
            icon: const Icon(Icons.table_chart),
            label: const Text('مراجعة الأعمدة المكتشفة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: () => Navigator.push(c, MaterialPageRoute(
              builder: (_) => CoaColumnMappingScreen(
                uploadId: _uploadResult!['upload_id'],
                clientId: widget.clientId,
                clientName: widget.clientName,
                detectedColumns: List<String>.from(_uploadResult!['detected_columns'] ?? []),
                suggestedMapping: Map<String, dynamic>.from(_uploadResult!['suggested_column_mapping'] ?? {}),
                sampleRows: List<Map<String, dynamic>>.from(
                  (_uploadResult!['sample_rows'] as List?)?.map((r) => Map<String, dynamic>.from(r)) ?? []),
              ))),
            style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy))),
        ],
      ])),
  );

  Widget _stepDot(String label, int num, bool active) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 36, height: 36,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: active ? AC.gold : AC.navy4,
        border: Border.all(color: active ? AC.gold : AC.ts.withOpacity(0.4), width: 2),
        boxShadow: active ? [BoxShadow(color: AC.gold.withOpacity(0.3), blurRadius: 8)] : []),
      child: Center(child: Text('$num', style: TextStyle(color: active ? AC.navy : AC.ts, fontWeight: FontWeight.bold, fontSize: 13)))),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(color: active ? AC.gold : AC.ts, fontSize: 11)),
  ]);
  Widget _stepLine() => Container(width: 40, height: 2, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(1), color: AC.ts.withOpacity(0.3)));
}

// ── 4. Column Mapping Screen ──
class CoaColumnMappingScreen extends StatefulWidget {
  final String uploadId, clientId, clientName;
  final List<String> detectedColumns;
  final Map<String, dynamic> suggestedMapping;
  final List<Map<String, dynamic>> sampleRows;
  const CoaColumnMappingScreen({super.key, required this.uploadId, required this.clientId, required this.clientName,
    required this.detectedColumns, required this.suggestedMapping, required this.sampleRows});
  @override State<CoaColumnMappingScreen> createState() => _CoaColMapS();
}
class _CoaColMapS extends State<CoaColumnMappingScreen> {
  late Map<String, String?> _mapping;
  bool _parsing = false;
  String? _err;

  static const _fieldLabels = {
    'account_code': 'رقم الحساب',
    'account_name': 'اسم الحساب ✱',
    'parent_code': 'رقم الأب',
    'parent_name': 'اسم الأب',
    'level': 'المستوى',
    'account_type': 'نوع الحساب',
    'normal_balance': 'طبيعة الرصيد',
    'active_flag': 'مفعل',
    'notes': 'ملاحظات',
  };

  @override void initState() {
    super.initState();
    _mapping = {};
    widget.suggestedMapping.forEach((k, v) { _mapping[k] = v?.toString(); });
  }

  Future<void> _parse() async {
    if (_mapping['account_name'] == null || _mapping['account_name']!.isEmpty) {
      setState(() => _err = 'حقل "اسم الحساب" إلزامي!');
      return;
    }
    setState(() { _parsing = true; _err = null; });
    try {
      final cleanMapping = <String, String>{};
      _mapping.forEach((k, v) { if (v != null && v.isNotEmpty) cleanMapping[k] = v; });

      final r = await http.post(Uri.parse('$_api/coa/uploads/${widget.uploadId}/parse'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'column_mapping': cleanMapping}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200) {
        if (mounted) Navigator.push(context, MaterialPageRoute(
          builder: (_) => CoaParsedPreviewScreen(
            uploadId: widget.uploadId, clientId: widget.clientId, clientName: widget.clientName, parseResult: d)));
      } else {
        setState(() { _err = d['detail']?.toString() ?? d['message'] ?? 'فشل التحليل'; _parsing = false; });
      }
    } catch (e) { setState(() { _err = 'خطأ: $e'; _parsing = false; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: const Text('ربط الأعمدة', style: TextStyle(color: AC.gold))),
    body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _stepDot('رفع', 1, true), _stepLine(), _stepDot('أعمدة', 2, true),
          _stepLine(), _stepDot('تحليل', 3, false), _stepLine(), _stepDot('معاينة', 4, false),
        ]),
        const SizedBox(height: 20),
        if (_err != null) Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
          child: Text(_err!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center)),
        const Text('اربط كل عمود في ملفك بالحقل المناسب:', style: TextStyle(color: AC.ts, fontSize: 13)),
        const SizedBox(height: 12),
        ..._fieldLabels.entries.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            SizedBox(width: 110, child: Text(e.value, style: TextStyle(color: e.key == 'account_name' ? AC.gold : AC.tp, fontSize: 13, fontWeight: FontWeight.bold))),
            const Icon(Icons.arrow_back, color: AC.ts, size: 16),
            const SizedBox(width: 8),
            Expanded(child: DropdownButtonFormField<String>(
              value: _mapping[e.key],
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
              dropdownColor: AC.navy3,
              style: const TextStyle(color: AC.tp, fontSize: 13),
              hint: const Text('— غير محدد —', style: TextStyle(color: AC.ts, fontSize: 12)),
              items: [
                const DropdownMenuItem(value: '', child: Text('— غير محدد —', style: TextStyle(color: AC.ts, fontSize: 12))),
                ...widget.detectedColumns.map((col) => DropdownMenuItem(value: col, child: Text(col, style: const TextStyle(fontSize: 13)))),
              ],
              onChanged: (v) => setState(() => _mapping[e.key] = (v == '') ? null : v),
            )),
          ]))),
        if (widget.sampleRows.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('عينة من البيانات:', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(8)),
            child: SingleChildScrollView(scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(AC.navy4),
                columns: widget.detectedColumns.map((col) => DataColumn(
                  label: Text(col, style: const TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                rows: widget.sampleRows.take(3).map((row) => DataRow(
                  cells: widget.detectedColumns.map((col) => DataCell(
                    Text((row[col] ?? '').toString(), style: const TextStyle(color: AC.tp, fontSize: 11)))).toList())).toList(),
              ))),
        ],
        const SizedBox(height: 24),
        SizedBox(height: 52, child: ElevatedButton.icon(
          icon: Icon(_parsing ? Icons.hourglass_top : Icons.analytics),
          label: Text(_parsing ? 'جاري التحليل...' : 'تحليل شجرة الحسابات', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          onPressed: _parsing ? null : _parse,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white))),
      ])),
  );

  Widget _stepDot(String label, int num, bool active) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 36, height: 36,
      decoration: BoxDecoration(shape: BoxShape.circle,
        color: active ? AC.gold : AC.navy4,
        border: Border.all(color: active ? AC.gold : AC.ts.withOpacity(0.4), width: 2),
        boxShadow: active ? [BoxShadow(color: AC.gold.withOpacity(0.3), blurRadius: 8)] : []),
      child: Center(child: Text('$num', style: TextStyle(color: active ? AC.navy : AC.ts, fontWeight: FontWeight.bold, fontSize: 13)))),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(color: active ? AC.gold : AC.ts, fontSize: 11)),
  ]);
  Widget _stepLine() => Container(width: 40, height: 2, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(borderRadius: BorderRadius.circular(1), color: AC.ts.withOpacity(0.3)));
}

// ── 5. COA Parsed Preview Screen ──
class CoaParsedPreviewScreen extends StatefulWidget {
  final String uploadId, clientId, clientName;
  final Map<String, dynamic> parseResult;
  const CoaParsedPreviewScreen({super.key, required this.uploadId, required this.clientId, required this.clientName, required this.parseResult});
  @override State<CoaParsedPreviewScreen> createState() => _CoaParsedS();
}
class _CoaParsedS extends State<CoaParsedPreviewScreen> {
  List<dynamic> _accounts = [];
  int _total = 0, _page = 1;
  String _filter = 'all';
  bool _ld = false;

  @override void initState() { super.initState(); _accounts = widget.parseResult['preview_rows'] ?? []; _total = widget.parseResult['total_rows_parsed'] ?? 0; }

  Future<void> _loadPage({String? filter}) async {
    setState(() { _ld = true; if (filter != null) _filter = filter; });
    try {
      String url = '$_api/coa/uploads/${widget.uploadId}/accounts?page=$_page&page_size=30';
      if (_filter == 'issues') url += '&has_issues=true';
      if (_filter == 'rejected') url += '&record_status=rejected';
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        setState(() { _accounts = d['accounts'] ?? []; _total = d['total'] ?? 0; _ld = false; });
      } else { setState(() => _ld = false); }
    } catch (_) { setState(() => _ld = false); }
  }

  @override
  Widget build(BuildContext c) {
    final pr = widget.parseResult;
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(title: const Text('نتائج التحليل', style: TextStyle(color: AC.gold)),
        actions: [IconButton(icon: const Icon(Icons.feedback_outlined, color: AC.gold),
          tooltip: 'ملاحظات معرفية',
          onPressed: () => Navigator.push(c, MaterialPageRoute(
            builder: (_) => CoaKnowledgeFeedbackScreen(clientId: widget.clientId, uploadId: widget.uploadId))))]),
      body: Column(children: [
        // Summary cards
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          _card('المكتشفة', '${pr['total_rows_detected'] ?? 0}', AC.cyan),
          const SizedBox(width: 8),
          _card('المقبولة', '${pr['total_rows_parsed'] ?? 0}', Colors.greenAccent),
          const SizedBox(width: 8),
          _card('المرفوضة', '${pr['total_rows_rejected'] ?? 0}', AC.err),
        ])),
        // Warnings
        if ((pr['warnings'] as List?)?.isNotEmpty == true)
          Container(margin: const EdgeInsets.symmetric(horizontal: 12), padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AC.warn.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Column(children: (pr['warnings'] as List).map((w) =>
              Text(w.toString(), style: const TextStyle(color: AC.warn, fontSize: 12))).toList())),
        // Filter tabs
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          _filterChip('الكل', 'all'), const SizedBox(width: 8),
          _filterChip('بها مشاكل', 'issues'), const SizedBox(width: 8),
          _filterChip('مرفوضة', 'rejected'),
        ])),
        // Accounts list
        Expanded(child: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold))
          : _accounts.isEmpty ? const Center(child: Text('لا توجد نتائج', style: TextStyle(color: AC.ts)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _accounts.length,
              itemBuilder: (_, i) {
                final a = _accounts[i];
                final issues = (a['issues'] as List?) ?? [];
                final hasIssue = issues.isNotEmpty;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10),
                    border: hasIssue ? Border.all(color: AC.warn.withOpacity(0.5)) : null),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (a['account_code'] != null) Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AC.cyan.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                        child: Text(a['account_code'], style: const TextStyle(color: AC.cyan, fontSize: 12, fontFamily: 'monospace'))),
                      if (a['account_code'] != null) const SizedBox(width: 8),
                      Expanded(child: Text(a['account_name_raw'] ?? '', style: const TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14))),
                      if (a['account_level'] != null)
                        Text('L${a['account_level']}', style: const TextStyle(color: AC.ts, fontSize: 11)),
                    ]),
                    if (a['normal_balance'] != null || a['account_type_raw'] != null)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [
                        if (a['normal_balance'] != null) Text(a['normal_balance'] == 'debit' ? 'مدين' : 'دائن',
                          style: TextStyle(color: a['normal_balance'] == 'debit' ? AC.cyan : AC.gold, fontSize: 11)),
                        if (a['account_type_raw'] != null) ...[const SizedBox(width: 8),
                          Text(a['account_type_raw'], style: const TextStyle(color: AC.ts, fontSize: 11))],
                      ])),
                    if (hasIssue)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Wrap(spacing: 4,
                        children: issues.map((iss) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AC.warn.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                          child: Text(iss.toString(), style: const TextStyle(color: AC.warn, fontSize: 10)))).toList())),
                  ]),
                );
              })),
        // Pagination
        Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.chevron_right, color: AC.ts),
            onPressed: _page > 1 ? () { setState(() => _page--); _loadPage(); } : null),
          Text('صفحة $_page', style: const TextStyle(color: AC.ts)),
          IconButton(icon: const Icon(Icons.chevron_left, color: AC.ts),
            onPressed: _total > _page * 30 ? () { setState(() => _page++); _loadPage(); } : null),
        ])),
      ]),
    );
  }

  Widget _card(String label, String value, Color color) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: AC.ts, fontSize: 11)),
    ])));

  Widget _filterChip(String label, String value) => GestureDetector(
    onTap: () { setState(() { _filter = value; _page = 1; }); _loadPage(); },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _filter == value ? AC.gold.withOpacity(0.2) : AC.navy3,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _filter == value ? AC.gold : Colors.transparent)),
      child: Text(label, style: TextStyle(color: _filter == value ? AC.gold : AC.ts, fontSize: 12))));
}

// ── 6. Knowledge Feedback Screen ──
class CoaKnowledgeFeedbackScreen extends StatefulWidget {
  final String clientId;
  final String? uploadId;
  const CoaKnowledgeFeedbackScreen({super.key, required this.clientId, this.uploadId});
  @override State<CoaKnowledgeFeedbackScreen> createState() => _KnowledgeFBS();
}
class _KnowledgeFBS extends State<CoaKnowledgeFeedbackScreen> {
  final _textC = TextEditingController();
  String _category = 'data_quality_note';
  String? _severity;
  List<dynamic> _feedbacks = [];
  bool _ld = true, _sending = false;
  String? _err, _ok;

  static const _categories = {
    'data_quality_note': 'ملاحظة جودة بيانات',
    'taxonomy_note': 'ملاحظة تصنيفية',
    'regulatory_note': 'ملاحظة تنظيمية',
    'accounting_note': 'ملاحظة محاسبية',
    'legal_note': 'ملاحظة قانونية',
    'parsing_issue': 'مشكلة في القراءة',
    'column_mapping_issue': 'مشكلة في ربط الأعمدة',
    'suggested_classification': 'اقتراح تصنيف',
  };

  @override void initState() { super.initState(); _loadFeedbacks(); }

  Future<void> _loadFeedbacks() async {
    try {
      String url = '$_api/coa/knowledge-feedback?client_id=${widget.clientId}';
      if (widget.uploadId != null) url += '&coa_upload_id=${widget.uploadId}';
      final r = await http.get(Uri.parse(url));
      if (r.statusCode == 200) {
        setState(() { _feedbacks = jsonDecode(r.body)['feedback'] ?? []; _ld = false; });
      } else { setState(() => _ld = false); }
    } catch (_) { setState(() => _ld = false); }
  }

  Future<void> _send() async {
    if (_textC.text.trim().isEmpty) { setState(() => _err = 'أدخل نص الملاحظة'); return; }
    setState(() { _sending = true; _err = null; _ok = null; });
    try {
      final r = await http.post(Uri.parse('$_api/coa/knowledge-feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client_id': widget.clientId,
          'coa_upload_id': widget.uploadId,
          'feedback_category': _category,
          'feedback_severity': _severity,
          'feedback_text': _textC.text.trim(),
        }));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200) {
        setState(() { _ok = 'تم حفظ الملاحظة بنجاح'; _textC.clear(); _sending = false; });
        _loadFeedbacks();
      } else { setState(() { _err = d['detail']?.toString() ?? 'فشل الإرسال'; _sending = false; }); }
    } catch (e) { setState(() { _err = 'خطأ: $e'; _sending = false; }); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: const Text('لوحة المعرفة', style: TextStyle(color: AC.gold))),
    body: _ld ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.psychology, size: 48, color: AC.gold),
          const SizedBox(height: 8),
          const Text('أضف ملاحظة معرفية', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          if (_ok != null) Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text(_ok!, style: const TextStyle(color: Colors.greenAccent), textAlign: TextAlign.center)),
          if (_err != null) Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Text(_err!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center)),
          DropdownButtonFormField<String>(
            value: _category, dropdownColor: AC.navy3,
            decoration: InputDecoration(labelText: 'نوع الملاحظة', labelStyle: const TextStyle(color: AC.ts),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AC.gold), borderRadius: BorderRadius.circular(12))),
            style: const TextStyle(color: AC.tp, fontSize: 14),
            items: _categories.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _category = v!)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _severity, dropdownColor: AC.navy3,
            decoration: InputDecoration(labelText: 'الأهمية (اختياري)', labelStyle: const TextStyle(color: AC.ts),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AC.gold), borderRadius: BorderRadius.circular(12))),
            style: const TextStyle(color: AC.tp, fontSize: 14),
            items: const [
              DropdownMenuItem(value: null, child: Text('— غير محدد —', style: TextStyle(color: AC.ts))),
              DropdownMenuItem(value: 'low', child: Text('منخفضة')),
              DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
              DropdownMenuItem(value: 'high', child: Text('عالية')),
              DropdownMenuItem(value: 'critical', child: Text('حرجة')),
            ],
            onChanged: (v) => setState(() => _severity = v)),
          const SizedBox(height: 12),
          TextField(controller: _textC, maxLines: 4, style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(labelText: 'نص الملاحظة', labelStyle: const TextStyle(color: AC.ts),
              hintText: 'اشرح الملاحظة أو التصحيح المقترح...', hintStyle: TextStyle(color: AC.ts.withOpacity(0.5)),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: AC.gold), borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 16),
          SizedBox(height: 48, child: ElevatedButton.icon(
            icon: Icon(_sending ? Icons.hourglass_top : Icons.send),
            label: Text(_sending ? 'جاري الإرسال...' : 'إرسال الملاحظة'),
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy))),
          const SizedBox(height: 24),
          if (_feedbacks.isNotEmpty) ...[
            const Text('الملاحظات السابقة', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._feedbacks.map((f) => Container(
              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AC.cyan.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                    child: Text(_categories[f['feedback_category']] ?? f['feedback_category'], style: const TextStyle(color: AC.cyan, fontSize: 10))),
                  const Spacer(),
                  Text(f['status'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 10)),
                ]),
                const SizedBox(height: 6),
                Text(f['feedback_text'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13)),
                Text(f['created_at']?.toString().substring(0, 16) ?? '', style: const TextStyle(color: AC.ts, fontSize: 10)),
              ]))),
          ],
        ])),
  );
}


// ========================================================
// Sprint 3: COA Quality Report Screen
// ========================================================
class CoaQualityReportScreen extends StatefulWidget {
  final String uploadId;
  final String clientId;
  const CoaQualityReportScreen({super.key, required this.uploadId, required this.clientId});
  @override
  State<CoaQualityReportScreen> createState() => _CoaQualityReportS();
}

class _CoaQualityReportS extends State<CoaQualityReportScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      var r = await http.get(Uri.parse('$_api/coa/uploads/${widget.uploadId}/assessment'), headers: S.h());
      var d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['data'] != null) { setState(() { _data = d['data']; _loading = false; }); return; }
      r = await http.post(Uri.parse('$_api/coa/uploads/${widget.uploadId}/assess'), headers: S.h());
      d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['success'] == true) { setState(() { _data = d['data']; _loading = false; }); }
      else { setState(() { _error = d['detail'] ?? 'فشل التقييم'; _loading = false; }); }
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AC.navy,
      appBar: AppBar(title: const Text('تقرير الجودة', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)), backgroundColor: AC.navy2),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AC.gold))
          : _error != null ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
          : _buildReport());
  }

  Widget _buildReport() {
    if (_data == null) return const SizedBox();
    final overall = (_data!['overall_score'] ?? 0).toDouble();
    final recs = List<String>.from(_data!['recommendations'] ?? []);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AC.gold.withOpacity(0.2), AC.navy3]),
          borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.gold.withOpacity(0.3))),
        child: Column(children: [
          Text('التقييم العام', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('${overall.toStringAsFixed(0)}%', style: TextStyle(
            color: overall >= 70 ? Colors.greenAccent : overall >= 40 ? Colors.orangeAccent : Colors.redAccent,
            fontSize: 48, fontWeight: FontWeight.bold)),
          Text('${_data!['total_accounts'] ?? 0} حساب', style: TextStyle(color: AC.ts, fontSize: 13)),
        ])),
      const SizedBox(height: 16),
      _sc('الاكتمال', (_data!['completeness_score'] ?? 0).toDouble(), Icons.check_circle_outline),
      _sc('التناسق', (_data!['consistency_score'] ?? 0).toDouble(), Icons.compare_arrows),
      _sc('وضوح الاسماء', (_data!['naming_clarity_score'] ?? 0).toDouble(), Icons.text_fields),
      _sc('خطر التكرار', (_data!['duplication_risk_score'] ?? 0).toDouble(), Icons.copy_all),
      _sc('جاهزية التقارير', (_data!['reporting_readiness_score'] ?? 0).toDouble(), Icons.assessment),
      const SizedBox(height: 20),
      if (recs.isNotEmpty) ...[
        Text('التوصيات', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...recs.map((r) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline, color: AC.gold, size: 18), const SizedBox(width: 10),
            Expanded(child: Text(r, style: TextStyle(color: AC.tp, fontSize: 13)))]))),
      ],
      const SizedBox(height: 24),
      ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => CoaReviewApprovalScreen(uploadId: widget.uploadId, clientId: widget.clientId))),
        icon: const Icon(Icons.rate_review), label: const Text('مراجعة واعتماد'),
        style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy,
          padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ]);
  }

  Widget _sc(String label, double score, IconData icon) {
    final color = score >= 70 ? Colors.greenAccent : score >= 40 ? Colors.orangeAccent : Colors.redAccent;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
      child: Row(children: [Icon(icon, color: color, size: 22), const SizedBox(width: 14),
        Expanded(child: Text(label, style: TextStyle(color: AC.tp, fontSize: 14))),
        Text('${score.toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold))]));
  }
}

// ========================================================
// Sprint 3: COA Review & Approval Screen
// ========================================================
class CoaReviewApprovalScreen extends StatefulWidget {
  final String uploadId;
  final String clientId;
  const CoaReviewApprovalScreen({super.key, required this.uploadId, required this.clientId});
  @override
  State<CoaReviewApprovalScreen> createState() => _CoaReviewApprovalS();
}

class _CoaReviewApprovalS extends State<CoaReviewApprovalScreen> {
  Map<String, dynamic>? _gate;
  bool _gateLoading = false;
  List<dynamic> _accounts = [];
  bool _loading = true;
  String? _error;
  final Set<String> _selected = {};
  String _filter = 'all';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await http.get(Uri.parse('$_api/coa/uploads/${widget.uploadId}/accounts?page_size=500'), headers: S.h());
      final d = jsonDecode(r.body);
      if (r.statusCode == 200) { setState(() { _accounts = d['data'] ?? d['accounts'] ?? d['rows'] ?? []; _loading = false; }); }
      else { setState(() { _error = d['detail'] ?? 'فشل'; _loading = false; }); }
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _bulkApprove() async {
    if (_selected.isEmpty) return;
    try {
      final r = await http.post(Uri.parse('$_api/coa/uploads/${widget.uploadId}/bulk-approve'),
        headers: {...S.h(), 'Content-Type': 'application/json'},
        body: jsonEncode({'account_ids': _selected.toList(), 'review_status': 'approved'}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['success'] == true) {
        setState(() => _selected.clear());
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم اعتماد ${d["data"]?["count"] ?? 0} حساب')));
        _load();
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _approveAll() async {
    try {
      final r = await http.post(Uri.parse('$_api/coa/uploads/${widget.uploadId}/approve'),
        headers: {...S.h(), 'Content-Type': 'application/json'},
        body: jsonEncode({'approval_status': 'approved'}));
      final d = jsonDecode(r.body);
      if (r.statusCode == 200 && d['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد الشجرة')));
        Navigator.pop(context, true);
      }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Future<void> _loadGate() async {
    setState(() => _gateLoading = true);
    final res = await ApiService.checkApprovalGates(widget.uploadId);
    setState(() {
      _gate = res.success ? (res.data is Map ? res.data as Map<String, dynamic> : {}) : {};
      _gateLoading = false;
    });
  }

  List<dynamic> get _filtered {
    if (_filter == 'has_issues') return _accounts.where((a) { final i = a['issues'] ?? a['issues_json'] ?? []; return i is List && i.isNotEmpty; }).toList();
    return _accounts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AC.navy,
      appBar: AppBar(title: const Text('مراجعة واعتماد', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)), backgroundColor: AC.navy2,
        actions: [if (_selected.isNotEmpty) TextButton.icon(onPressed: _bulkApprove,
          icon: Container(width: 36, height: 36, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent.withOpacity(0.15)), child: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 22)),
          label: Text('اعتماد ${_selected.length}', style: const TextStyle(color: Colors.greenAccent)))]),
      body: _loading ? const Center(child: CircularProgressIndicator(color: AC.gold))
          : _error != null ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
          : Column(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: AC.navy3,
                child: Row(children: [Text('${_filtered.length} حساب', style: TextStyle(color: AC.ts, fontSize: 12)),
                  const Spacer(), _chip('الكل', 'all'), const SizedBox(width: 8), _chip('فيها مشاكل', 'has_issues')])),
              Expanded(child: ListView.builder(padding: const EdgeInsets.all(8), itemCount: _filtered.length,
                itemBuilder: (ctx, i) => _tile(_filtered[i]))),
              Container(padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AC.navy3, border: Border(top: BorderSide(color: Colors.white12))),
                child: Row(children: [
                                    Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          if (_selected.length == _filtered.length) {
                            _selected.clear();
                          } else {
                            _selected.clear();
                            for (var a in _filtered) {
                              final id = a['id']?.toString() ?? '';
                              if (id.isNotEmpty) _selected.add(id);
                            }
                          }
                        });
                      },
                      style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold), padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(_selected.length == _filtered.length ? 'الغاء' : 'تحديد الكل', style: TextStyle(color: AC.gold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (_gate == null && !_gateLoading)
                        TextButton(onPressed: _loadGate, child: Text('فحص شروط الاعتماد', style: TextStyle(color: AC.cyan))),
                      if (_gateLoading)
                        const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AC.gold, strokeWidth: 2)),
                      if (_gate != null && _gate!['can_approve'] == true)
                        ElevatedButton(
                          onPressed: _approveAll,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent.shade700, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          child: const Text('اعتماد الشجرة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      if (_gate != null && _gate!['can_approve'] != true)
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(
                          color: Colors.orange.withAlpha(20), borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.orange.withAlpha(60))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Icon(Icons.lock, color: Colors.orange, size: 16), const SizedBox(width: 6),
                              Text('لا يمكن الاعتماد بعد', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))]),
                            const SizedBox(height: 6),
                            ...(_gate!['blockers'] as List? ?? []).map((b) =>
                              Padding(padding: const EdgeInsets.only(bottom: 3), child: Row(children: [
                                Icon(Icons.close, color: Colors.orange, size: 12), const SizedBox(width: 4),
                                Expanded(child: Text(b.toString(), style: const TextStyle(color: AC.tp, fontSize: 11)))]))),
                          ])),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Widget _chip(String label, String value) {
    final active = _filter == value;
    return GestureDetector(onTap: () => setState(() => _filter = value),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: active ? AC.gold.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? AC.gold : Colors.white24)),
        child: Text(label, style: TextStyle(color: active ? AC.gold : AC.ts, fontSize: 12))));
  }

  Widget _tile(dynamic a) {
    final code = a['account_code'] ?? '';
    final name = a['account_name_raw'] ?? '';
    final issues = a['issues'] ?? a['issues_json'] ?? [];
    final hasIssues = issues is List && issues.isNotEmpty;
    final id = a['id']?.toString() ?? '';
    final sel = _selected.contains(id);
    return Container(margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(color: sel ? AC.gold.withOpacity(0.1) : AC.navy3,
        borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? AC.gold : Colors.white12)),
      child: ListTile(dense: true,
        leading: GestureDetector(onTap: () { setState(() { if (sel) _selected.remove(id); else if (id.isNotEmpty) _selected.add(id); }); },
          child: Icon(sel ? Icons.check_box : Icons.check_box_outline_blank, color: sel ? AC.gold : Colors.white38, size: 22)),
        title: Text('$code - $name', style: TextStyle(color: AC.tp, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: hasIssues ? Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 18) : Icon(Icons.check_circle_outline, color: Colors.greenAccent.shade400, size: 18)));
  }
}













