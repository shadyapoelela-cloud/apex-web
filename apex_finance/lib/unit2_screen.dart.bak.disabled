import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class Unit2Screen extends StatefulWidget {
  const Unit2Screen({super.key});
  @override
  State<Unit2Screen> createState() => _Unit2ScreenState();
}

class _Unit2ScreenState extends State<Unit2Screen> with SingleTickerProviderStateMixin {
  bool _fileSelected = false, _loading = false, _done = false;
  String _fileName = '';
  PlatformFile? _pickedFileData;
  Map<String, dynamic>? _result;
  String _error = '';
  int _currentStage = 0;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _fileSelected = true;
        _fileName = result.files.first.name;
        _pickedFileData = result.files.first;
        _done = false; _result = null; _error = '';
      });
    }
  }

  Future<void> _analyze() async {
    if (_pickedFileData == null) return;
    setState(() { _loading = true; _error = ''; _currentStage = 1; });

    try {
      final uri = Uri.parse('https://apex-api-ootk.onrender.com/unit2/analyze/multistage');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'file', _pickedFileData!.bytes!, filename: _pickedFileData!.name));

      // محاكاة المراحل
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _currentStage = 2);
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      setState(() => _currentStage = 3);
      
      final response = await http.Response.fromStream(streamedResponse);
      setState(() => _currentStage = 4);
      await Future.delayed(const Duration(milliseconds: 300));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() { _result = data; _done = true; _loading = false; });
        } else {
          setState(() { _error = data['detail'] ?? 'خطأ غير معروف'; _loading = false; });
        }
      } else {
        final err = json.decode(response.body);
        setState(() { _error = err['detail'] ?? 'خطأ: ${response.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    double n = (v is int) ? v.toDouble() : (v is double) ? v : 0.0;
    if (n.abs() >= 1e6) return '${(n/1e6).toStringAsFixed(2)}M';
    if (n.abs() >= 1e3) return '${(n/1e3).toStringAsFixed(1)}K';
    return n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2, elevation: 0,
        title: const Text('إرفاق القوائم المعتمدة', style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AC.textSecondary, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // بانر التعريف
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AC.cyan.withOpacity(0.1), AC.navy3]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AC.cyan.withOpacity(0.3))),
            child: Row(children: [
              Container(width: 48, height: 48,
                decoration: BoxDecoration(color: AC.cyan.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.upload_file_rounded, color: AC.cyan, size: 24)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
                Text('ارفع قوائمك المالية المعتمدة', textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.cyan, fontFamily: 'Tajawal')),
                SizedBox(height: 2),
                Text('قائمة دخل + ميزانية + تدفقات — تحليل 4 مراحل', textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
              ]),
            ])),
          const SizedBox(height: 16),

          // ─── منطقة رفع الملف ───
          GestureDetector(
            onTap: _pickFile,
            child: Container(
              width: double.infinity, height: 140,
              decoration: BoxDecoration(
                color: AC.navy3,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _fileSelected ? AC.cyan.withOpacity(0.5) : AC.border, width: _fileSelected ? 1.5 : 1)),
              child: _fileSelected
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.description_rounded, color: AC.cyan, size: 40),
                    const SizedBox(height: 8),
                    Text(_fileName, style: const TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal')),
                    const SizedBox(height: 4),
                    const Text('جاهز للتحليل — اضغط لتغيير الملف', style: TextStyle(color: AC.cyan, fontSize: 12, fontFamily: 'Tajawal')),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 56, height: 56,
                      decoration: BoxDecoration(color: AC.cyan.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.cloud_upload_rounded, color: AC.cyan, size: 28)),
                    const SizedBox(height: 10),
                    const Text('المطلوب: قائمة الدخل + الميزانية + التدفقات النقدية',
                    textDirection: TextDirection.rtl, style: TextStyle(color: AC.textSecondary, fontSize: 11, fontFamily: 'Tajawal')),
                    const SizedBox(height: 6),
                    const Text('اضغط لرفع القوائم المالية', style: TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal')),
                    const SizedBox(height: 4),
                    const Text('Excel (.xlsx) أو PDF', style: TextStyle(color: AC.textSecondary, fontSize: 12, fontFamily: 'Tajawal')),
                  ]))),
          const SizedBox(height: 6),
          const Text('يجب أن يحتوي الملف على: قائمة الدخل + الميزانية العمومية + التدفقات النقدية',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 11, color: AC.textHint, fontFamily: 'Tajawal')),
          const SizedBox(height: 16),

          // ─── خطأ ───
          if (_error.isNotEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Color(0xFFE24B4A).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFFE24B4A).withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFE24B4A), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error, textDirection: TextDirection.rtl, style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 12, fontFamily: 'Tajawal'))),
              ])),

          // ─── مراحل التحليل أثناء التحميل ───
          if (_loading)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
              child: Column(children: [
                for (int i = 1; i <= 4; i++) ...[
                  _StageRow(stage: i, currentStage: _currentStage, pulseCtrl: _pulseCtrl, labels: const [
                    'قراءة القوائم المعتمدة',
                    'تحليل أولي بالذكاء الاصطناعي',
                    'مراجعة شاملة ومقارنة',
                    'اعتماد النتيجة النهائية',
                  ]),
                  if (i < 4) Container(width: 2, height: 20, color: i < _currentStage ? AC.success.withOpacity(0.3) : AC.border),
                ],
              ])),

          // ─── زر التحليل ───
          if (!_done)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: GestureDetector(
                onTap: _fileSelected && !_loading ? _analyze : null,
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    gradient: _fileSelected && !_loading
                      ? const LinearGradient(colors: [AC.cyan, Color(0xFF006B7D)])
                      : null,
                    color: !_fileSelected || _loading ? AC.navy3 : null,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _fileSelected ? AC.cyan.withOpacity(0.5) : AC.border)),
                  child: Center(child: _loading
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('جاري التحليل...', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Tajawal')),
                      ])
                    : Text(_fileSelected ? 'بدء التحليل متعدد المراحل' : 'اختر ملف القوائم المالية',
                        style: TextStyle(color: _fileSelected ? Colors.white : AC.textHint, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')))))),

          // ═══ النتائج ═══
          if (_done && _result != null) ...[
            const SizedBox(height: 20),
            _buildConfidenceCard(),
            const SizedBox(height: 16),
            _buildSheetsInfo(),
            const SizedBox(height: 16),
            _buildStagesResult(),
            const SizedBox(height: 16),
            _buildIncomeStatement(),
            const SizedBox(height: 16),
            _buildBalanceSheet(),
            const SizedBox(height: 16),
            _buildCashFlow(),
            const SizedBox(height: 16),
            _buildRatios(),
            const SizedBox(height: 16),
            // زر تحليل ملف آخر
            GestureDetector(
              onTap: () => setState(() { _fileSelected = false; _done = false; _result = null; _fileName = ''; _pickedFileData = null; }),
              child: Container(
                width: double.infinity, height: 52,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.cyan, Color(0xFF006B7D)]), borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('تحليل ملف آخر', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))))),
            const SizedBox(height: 40),
          ],
        ]),
      ),
    );
  }

  Widget _buildConfidenceCard() {
    final fr = _result!['final_result'] ?? {};
    final conf = (fr['confidence_pct'] ?? 90).toDouble();
    final label = fr['quality_label'] ?? 'جيد';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy3, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: conf >= 95 ? AC.success.withOpacity(0.4) : AC.cyan.withOpacity(0.3))),
      child: Row(children: [
        SizedBox(width: 70, height: 70, child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(value: conf / 100, strokeWidth: 6, backgroundColor: AC.border, color: conf >= 95 ? AC.success : AC.cyan),
          Text('${conf.toInt()}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: conf >= 95 ? AC.success : AC.cyan, fontFamily: 'Tajawal')),
        ])),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('مؤشر الثقة النهائي', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
          Text('$conf%', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: conf >= 95 ? AC.success : AC.cyan, fontFamily: 'Tajawal')),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: (conf >= 95 ? AC.success : AC.cyan).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: TextStyle(fontSize: 12, color: conf >= 95 ? AC.success : AC.cyan, fontFamily: 'Tajawal', fontWeight: FontWeight.w600))),
        ]),
      ]));
  }

  Widget _buildSheetsInfo() {
    final sheets = _result!['sheets_found'] as List? ?? [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('الأوراق المكتشفة في الملف', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end,
          children: sheets.map<Widget>((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AC.cyan.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.cyan.withOpacity(0.2))),
            child: Text(s.toString(), style: const TextStyle(fontSize: 12, color: AC.cyan, fontFamily: 'Tajawal')),
          )).toList()),
      ]));
  }

  Widget _buildStagesResult() {
    final stages = _result!['stages'] as Map<String, dynamic>? ?? {};
    final items = [
      {'key': 'stage1_code', 'icon': Icons.code_rounded, 'label': 'قراءة الكود', 'color': AC.cyan},
      {'key': 'stage1_ai_initial', 'icon': Icons.psychology_rounded, 'label': 'تحليل AI', 'color': AC.gold},
      {'key': 'stage3_review', 'icon': Icons.rate_review_rounded, 'label': 'المراجعة', 'color': AC.warning},
      {'key': 'stage4_final', 'icon': Icons.verified_rounded, 'label': 'النهائي', 'color': AC.success},
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('نتائج المراحل', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items.map((item) {
            final stage = stages[item['key']] ?? {};
            final conf = stage['confidence_pct'] ?? stage['final_confidence_pct'] ?? 0;
            return Column(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: (item['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22)),
              const SizedBox(height: 6),
              Text('$conf%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: item['color'] as Color, fontFamily: 'Tajawal')),
              Text(item['label'] as String, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
            ]);
          }).toList()),
      ]));
  }

  Widget _buildIncomeStatement() {
    final fd = _result!['final_result']?['financial_data'] ?? _result!['stages']?['stage1_code']?['financial_data'] ?? {};
    final inc = fd['income_statement'] ?? {};
    return _buildSection('قائمة الدخل', [
      _row('الإيرادات', inc['revenue']),
      _row('تكلفة المبيعات', inc['cogs']),
      _row('مجمل الربح', inc['gross_profit'], bold: true, color: AC.success),
      _row('مصروفات إدارية', inc['admin_expenses']),
      _row('مصروفات بيع', inc['sales_expenses']),
      _row('EBIT', inc['ebit'], bold: true),
      _row('تكاليف تمويل', inc['interest']),
      _row('ضرائب وزكاة', inc['tax']),
      _row('صافي الربح', inc['net_profit'], bold: true, color: AC.gold),
    ]);
  }

  Widget _buildBalanceSheet() {
    final fd = _result!['final_result']?['financial_data'] ?? _result!['stages']?['stage1_code']?['financial_data'] ?? {};
    final bs = fd['balance_sheet'] ?? {};
    return _buildSection('الميزانية العمومية', [
      _row('النقدية', bs['cash']),
      _row('ذمم مدينة', bs['receivables']),
      _row('المخزون', bs['inventory']),
      _row('الأصول المتداولة', bs['current_assets'], bold: true, color: AC.cyan),
      _row('أصول ثابتة', bs['fixed_assets']),
      _row('إجمالي الأصول', bs['total_assets'], bold: true, color: AC.gold),
      const Divider(color: AC.border, height: 16),
      _row('التزامات متداولة', bs['current_liabilities']),
      _row('إجمالي الالتزامات', bs['total_liabilities'], bold: true, color: AC.warning),
      _row('حقوق الملكية', bs['equity'], bold: true, color: AC.success),
    ]);
  }

  Widget _buildCashFlow() {
    final fd = _result!['final_result']?['financial_data'] ?? _result!['stages']?['stage1_code']?['financial_data'] ?? {};
    final cf = fd['cash_flow'] ?? {};
    return _buildSection('التدفقات النقدية', [
      _row('تدفقات تشغيلية', cf['operating']),
      _row('تدفقات استثمارية', cf['investing']),
      _row('تدفقات تمويلية', cf['financing']),
    ]);
  }

  Widget _buildRatios() {
    final fd = _result!['final_result']?['financial_data'] ?? _result!['stages']?['stage1_code']?['financial_data'] ?? {};
    final r = fd['ratios'] ?? {};
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('النسب المالية', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 12),
        _ratioBar('هامش مجمل الربح', r['gross_margin_pct']),
        _ratioBar('هامش صافي الربح', r['net_margin_pct']),
        _ratioBar('نسبة التداول', r['current_ratio'], isRatio: true),
        _ratioBar('الدين / الأصول', r['debt_to_assets_pct']),
        _ratioBar('العائد على الأصول ROA', r['roa_pct']),
        _ratioBar('العائد على الملكية ROE', r['roe_pct']),
        _ratioBar('دوران الأصول', r['asset_turnover'], isRatio: true),
      ]));
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(title, textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 10),
        ...children,
      ]));
  }

  Widget _row(String label, dynamic value, {bool bold = false, Color? color}) {
    final v = (value is num) ? value.toDouble() : 0.0;
    final neg = v < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(neg ? '(${_fmt(v.abs())})' : _fmt(v),
          style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? (neg ? Color(0xFFE24B4A) : AC.textPrimary), fontFamily: 'Tajawal')),
        const Spacer(),
        Text(label, textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }

  Widget _ratioBar(String label, dynamic value, {bool isRatio = false}) {
    double v = (value is num) ? value.toDouble() : 0.0;
    double barVal = isRatio ? (v / 3.0).clamp(0, 1) : (v / 100.0).clamp(0, 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          Text(isRatio ? v.toStringAsFixed(2) : '${v.toStringAsFixed(2)}%',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
          const Spacer(),
          Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: barVal, minHeight: 6, backgroundColor: AC.border, color: AC.gold)),
      ]));
  }
}

class _StageRow extends StatelessWidget {
  final int stage, currentStage;
  final AnimationController pulseCtrl;
  final List<String> labels;
  const _StageRow({required this.stage, required this.currentStage, required this.pulseCtrl, required this.labels});
  @override
  Widget build(BuildContext context) {
    final isDone = currentStage > stage;
    final isActive = currentStage == stage;
    return Row(children: [
      if (isDone) const Icon(Icons.check_circle_rounded, color: AC.success, size: 22)
      else if (isActive)
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (context, child) => Icon(Icons.sync_rounded, color: AC.cyan.withOpacity(0.5 + pulseCtrl.value * 0.5), size: 22))
      else Icon(Icons.radio_button_unchecked, color: AC.textHint, size: 22),
      const SizedBox(width: 10),
      Expanded(child: Text(labels[stage - 1], textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 13, color: isDone ? AC.success : isActive ? AC.cyan : AC.textHint, fontFamily: 'Tajawal',
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400))),
    ]);
  }
}



