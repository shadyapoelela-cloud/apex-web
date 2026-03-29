import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class Unit1FullScreen extends StatefulWidget {
  const Unit1FullScreen({super.key});
  @override
  State<Unit1FullScreen> createState() => _Unit1FullScreenState();
}

class _Unit1FullScreenState extends State<Unit1FullScreen> {
  int _step = 0; // 0=notes, 1=upload, 2=evaluating, 3=eval_result, 4=analyzing, 5=done
  String _fileName = '', _error = '';
  PlatformFile? _pickedFile;
  Map<String, dynamic>? _evalResult;
  Map<String, dynamic>? _analysisResult;
  bool _loading = false;

  final _notes = [
    {'text': 'استخدم نموذج ميزان المراجعة المعتمد من المنصة', 'important': true},
    {'text': 'عمود B: تبويب الحساب (مثل: أصول متداولة - نقد)', 'important': true},
    {'text': 'عمود C: اسم الحساب كما هو في دفاترك', 'important': true},
    {'text': 'عمود D: رصيد أول المدة مدين', 'important': false},
    {'text': 'عمود E: رصيد أول المدة دائن', 'important': false},
    {'text': 'عمود F-G: حركة المدين والدائن خلال الفترة', 'important': false},
    {'text': 'تأكد من توازن المدين والدائن في كل عمود', 'important': true},
    {'text': 'أدخل بيانات 12 شهراً كاملة للحصول على نتائج دقيقة', 'important': false},
    {'text': 'راجع التبويبات مع المعايير السعودية (SOCPA) و IFRS', 'important': true},
    {'text': 'لا تترك خلايا فارغة — ضع صفر بدلاً منها', 'important': false},
  ];

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) { await launchUrl(uri, mode: LaunchMode.externalApplication); }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() { _fileName = result.files.first.name; _pickedFile = result.files.first; _step = 1; _error = ''; _evalResult = null; _analysisResult = null; });
    }
  }

  Future<void> _evaluateTabs() async {
    if (_pickedFile == null) return;
    setState(() { _step = 2; _loading = true; _error = ''; });
    try {
      final uri = Uri.parse('https://apex-api-ootk.onrender.com/unit1/evaluate-tabs');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', _pickedFile!.bytes!, filename: _pickedFile!.name));
      final streamed = await request.send().timeout(const Duration(seconds: 180));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() { _evalResult = data; _step = 3; _loading = false; });
      } else {
        setState(() { _error = json.decode(response.body)['detail'] ?? 'خطأ'; _step = 1; _loading = false; });
      }
    } catch (e) { setState(() { _error = e.toString(); _step = 1; _loading = false; }); }
  }

  Future<void> _runAnalysis() async {
    if (_pickedFile == null) return;
    setState(() { _step = 4; _loading = true; _error = ''; });
    try {
      final uri = Uri.parse('https://apex-api-ootk.onrender.com/unit1/analyze/multistage');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', _pickedFile!.bytes!, filename: _pickedFile!.name));
      final streamed = await request.send().timeout(const Duration(seconds: 180));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) { setState(() { _analysisResult = data; _step = 5; _loading = false; }); }
        else { setState(() { _error = data['detail'] ?? 'خطأ'; _step = 3; _loading = false; }); }
      } else {
        setState(() { _error = json.decode(response.body)['detail'] ?? 'خطأ'; _step = 3; _loading = false; });
      }
    } catch (e) { setState(() { _error = e.toString(); _step = 3; _loading = false; }); }
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
      appBar: AppBar(backgroundColor: AC.navy2, elevation: 0,
        title: const Text('إعداد القوائم المالية', style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AC.textSecondary, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // شريط التقدم
          _buildProgressBar(),
          const SizedBox(height: 16),

          // الخطأ
          if (_error.isNotEmpty)
            Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFE24B4A).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE24B4A).withOpacity(0.3))),
              child: Text(_error, textDirection: TextDirection.rtl, style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 12, fontFamily: 'Tajawal'))),

          // المحتوى حسب الخطوة
          if (_step == 0) _buildNotesStep(),
          if (_step == 1) _buildUploadStep(),
          if (_step == 2) _buildEvaluatingStep(),
          if (_step == 3) _buildEvalResultStep(),
          if (_step == 4) _buildAnalyzingStep(),
          if (_step == 5) _buildResultsStep(),
        ])));
  }

  Widget _buildProgressBar() {
    final steps = ['الإرشادات', 'رفع الملف', 'تقييم التبويب', 'التحليل', 'النتائج'];
    final activeStep = _step >= 5 ? 4 : _step >= 3 ? 2 : _step >= 1 ? 1 : 0;
    return Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(steps.length, (i) {
          final done = i <= activeStep && _step > 0;
          final active = i == activeStep + 1 || (i == 0 && _step == 0);
          return Column(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: done ? AC.gold : active ? AC.gold.withOpacity(0.2) : AC.navy3,
                border: Border.all(color: done ? AC.gold : active ? AC.gold : AC.border)),
              child: Center(child: done ? const Icon(Icons.check, color: AC.navy, size: 16) :
                Text('${i+1}', style: TextStyle(fontSize: 11, color: active ? AC.gold : AC.textHint, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')))),
            const SizedBox(height: 4),
            Text(steps[i], style: TextStyle(fontSize: 9, color: done ? AC.gold : active ? AC.textPrimary : AC.textHint, fontFamily: 'Tajawal')),
          ]);
        })));
  }

  // ─── الخطوة 0: الملاحظات ───
  Widget _buildNotesStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // بانر الخطوة الأولى
      Container(width: double.infinity, padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [AC.gold.withOpacity(0.1), AC.navy3]), borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.gold.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('إعداد القوائم المالية', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
          const SizedBox(height: 8),
          const Text('قائمة الدخل + الميزانية العمومية + التدفقات النقدية + 16 نسبة مالية\\nتحليل متعدد المراحل بدقة 95%+ باستخدام GPT-4 و Gemini',
            textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.6)),
        ])),
      const SizedBox(height: 16),
      // أزرار التحميل
      GestureDetector(
        onTap: () { _launchUrl('https://apex-api-ootk.onrender.com/unit1/notes-pdf'); },
        child: Container(width: double.infinity, height: 48, margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: AC.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.gold.withOpacity(0.3))),
          child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.picture_as_pdf_rounded, color: AC.gold, size: 20),
            SizedBox(width: 8),
            Text('تحميل إرشادات التعبئة (PDF)', style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
          ])))),
      GestureDetector(
        onTap: () {},
        child: Container(width: double.infinity, height: 48,
          decoration: BoxDecoration(color: AC.cyan.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.cyan.withOpacity(0.3))),
          child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.download_rounded, color: AC.cyan, size: 20),
            SizedBox(width: 8),
            Text('تحميل نموذج ميزان المراجعة المعتمد', style: TextStyle(color: AC.cyan, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
          ])))),
      const SizedBox(height: 12),
      GestureDetector(
        onTap: _pickFile,
        child: Container(width: double.infinity, height: 52,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]), borderRadius: BorderRadius.circular(14)),
          child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.upload_file_rounded, color: AC.navy, size: 20),
            SizedBox(width: 8),
            Text('رفع ميزان المراجعة', style: TextStyle(color: AC.navy, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
          ])))),
    ]);
  }

  // ─── الخطوة 1: الملف مرفوع ───
  Widget _buildUploadStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
        child: Column(children: [
          const Icon(Icons.description_rounded, color: AC.gold, size: 40),
          const SizedBox(height: 8),
          Text(_fileName, style: const TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal')),
          const SizedBox(height: 4),
          GestureDetector(onTap: _pickFile,
            child: const Text('تغيير الملف', style: TextStyle(color: AC.cyan, fontSize: 12, fontFamily: 'Tajawal', decoration: TextDecoration.underline))),
        ])),
      const SizedBox(height: 16),
      GestureDetector(onTap: _evaluateTabs,
        child: Container(width: double.infinity, height: 52,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]), borderRadius: BorderRadius.circular(14)),
          child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.fact_check_rounded, color: AC.navy, size: 20),
            SizedBox(width: 8),
            Text('تقييم التبويب المحاسبي', style: TextStyle(color: AC.navy, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
          ])))),
    ]);
  }

  // ─── الخطوة 2: جاري التقييم ───
  Widget _buildEvaluatingStep() {
    return Container(width: double.infinity, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(children: [
        const SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 3, color: AC.gold)),
        const SizedBox(height: 16),
        const Text('جاري تقييم التبويب المحاسبي...', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        const Text('مراجعة التوافق مع المعايير المحاسبية الدولية "IFRS" والمعايير المحاسبية السعودية "SOCPA"', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }

  // ─── الخطوة 3: نتيجة التقييم ───
  Widget _buildEvalResultStep() {
    final ai = _evalResult?['ai_evaluation'] ?? {};
    final score = _evalResult?['overall_score'] ?? ai['overall_score'] ?? 0;
    final rating = _evalResult?['overall_rating'] ?? ai['overall_rating'] ?? '';
    final ifrs = ai['ifrs_compliance_pct'] ?? 0;
    final socpa = ai['socpa_compliance_pct'] ?? 0;
    final canProceed = ai['can_proceed'] ?? true;
    final correct = ai['correct_tabs'] ?? 0;
    final needsReview = ai['needs_review_tabs'] ?? 0;
    final incorrect = ai['incorrect_tabs'] ?? 0;
    final misclassified = (ai['misclassified_accounts'] as List?) ?? [];
    final recommendations = (ai['recommendations'] as List?) ?? [];
    final summary = ai['summary'] ?? '';
    final scoreColor = score >= 85 ? AC.success : score >= 70 ? AC.warning : const Color(0xFFE24B4A);

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // درجة التقييم
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: scoreColor.withOpacity(0.4))),
        child: Row(children: [
          SizedBox(width: 70, height: 70, child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: score / 100, strokeWidth: 6, backgroundColor: AC.border, color: scoreColor),
            Text('$score', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: scoreColor, fontFamily: 'Tajawal'))])),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('تقييم التبويب المحاسبي', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
            Text('$score / 100', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scoreColor, fontFamily: 'Tajawal')),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: scoreColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(rating.toString(), style: TextStyle(fontSize: 12, color: scoreColor, fontFamily: 'Tajawal', fontWeight: FontWeight.w600))),
          ])])),
      const SizedBox(height: 12),

      // IFRS + SOCPA
      Row(children: [
        Expanded(child: _scoreCard('IFRS', ifrs, AC.cyan)),
        const SizedBox(width: 8),
        Expanded(child: _scoreCard('SOCPA', socpa, const Color(0xFF6C5CE7))),
        const SizedBox(width: 8),
        Expanded(child: _scoreCard('صحيح', correct, AC.success)),
        const SizedBox(width: 8),
        Expanded(child: _scoreCard('خطأ', incorrect, const Color(0xFFE24B4A))),
      ]),
      const SizedBox(height: 12),

      // الملخص
      if (summary.toString().isNotEmpty)
        Container(width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
          child: Text(summary.toString(), textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5))),
      const SizedBox(height: 12),

      // حسابات مصنفة خطأ
      if (misclassified.isNotEmpty)
        Container(width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFE24B4A).withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE24B4A).withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('حسابات تحتاج تصحيح', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFE24B4A), fontFamily: 'Tajawal')),
            const SizedBox(height: 8),
            ...misclassified.take(5).map((m) {
              final acc = m is Map ? m : {};
              return Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${acc['account_name'] ?? ''}', textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.textPrimary, fontFamily: 'Tajawal')),
                  Text('الحالي: ${acc['current_tab'] ?? ''} → الصحيح: ${acc['correct_tab'] ?? ''}', textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal')),
                ]));
            }),
          ])),
      const SizedBox(height: 12),

      // التوصيات
      if (recommendations.isNotEmpty)
        Container(width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('التوصيات', textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.cyan, fontFamily: 'Tajawal')),
            const SizedBox(height: 6),
            ...recommendations.map((r) => Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Flexible(child: Text(r.toString(), textDirection: TextDirection.rtl,
                  style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal'))),
                const SizedBox(width: 6),
                const Icon(Icons.lightbulb_outline_rounded, color: AC.cyan, size: 14),
              ]))),
          ])),
      const SizedBox(height: 16),

      // أزرار
      if (!canProceed)
        Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AC.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.warning.withOpacity(0.3))),
          child: const Text('يوصى بتصحيح التبويبات الخاطئة قبل التحليل للحصول على نتائج أدق. يمكنك المتابعة على مسؤوليتك.',
            textDirection: TextDirection.rtl, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AC.warning, fontFamily: 'Tajawal'))),

      Row(children: [
        Expanded(child: GestureDetector(onTap: () => setState(() { _step = 0; _pickedFile = null; _fileName = ''; }),
          child: Container(height: 48,
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
            child: const Center(child: Text('تصحيح وإعادة الرفع', style: TextStyle(color: AC.textSecondary, fontSize: 13, fontFamily: 'Tajawal')))))),
        const SizedBox(width: 10),
        Expanded(flex: 2, child: GestureDetector(onTap: _runAnalysis,
          child: Container(height: 48,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(canProceed ? 'بدء التحليل المالي' : 'متابعة رغم التحذيرات',
              style: const TextStyle(color: AC.navy, fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')))))),
      ]),
    ]);
  }

  // ─── الخطوة 4: جاري التحليل ───
  Widget _buildAnalyzingStep() {
    return Container(width: double.infinity, padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
      child: Column(children: const [
        SizedBox(width: 50, height: 50, child: CircularProgressIndicator(strokeWidth: 3, color: AC.gold)),
        SizedBox(height: 16),
        Text('جاري التحليل متعدد المراحل...', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AC.gold, fontFamily: 'Tajawal')),
        SizedBox(height: 8),
        Text('كود + GPT-4 + Gemini + مراجعة + اعتماد نهائي', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }

  // ─── الخطوة 5: النتائج ───
  Widget _buildResultsStep() {
    final fr = _analysisResult?['final_result'] ?? {};
    final fd = fr['financial_data'] ?? {};
    final inc = fd['income_statement'] ?? {};
    final bs = fd['balance_sheet'] ?? {};
    final ratios = fd['ratios'] ?? {};
    final conf = (fr['confidence_pct'] ?? 90).toDouble();
    final label = fr['quality_label'] ?? 'جيد';

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // مؤشر الثقة
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
        child: Row(children: [
          SizedBox(width: 70, height: 70, child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: conf / 100, strokeWidth: 6, backgroundColor: AC.border, color: AC.gold),
            Text('${conf.toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AC.gold, fontFamily: 'Tajawal'))])),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('مؤشر الثقة النهائي', style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
            Text('$conf%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AC.gold, fontFamily: 'Tajawal')),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: AC.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(label, style: const TextStyle(fontSize: 12, color: AC.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.w600))),
          ])])),
      const SizedBox(height: 14),

      // قائمة الدخل
      _section('قائمة الدخل', [
        _row('الإيرادات', inc['revenue']), _row('صافي الإيرادات', inc['net_revenue'], bold: true, color: AC.gold),
        _row('تكلفة البضاعة', inc['cogs']), _row('مجمل الربح', inc['gross_profit'], bold: true, color: AC.success),
        _row('مصروفات إدارية', inc['admin_expenses']), _row('مصروفات بيع', inc['sales_expenses']),
        _row('EBIT', inc['ebit'], bold: true), _row('صافي الربح', inc['net_profit'], bold: true, color: AC.gold),
      ]),
      const SizedBox(height: 14),

      // الميزانية
      _section('الميزانية العمومية', [
        _row('النقدية', bs['cash']), _row('الأصول المتداولة', bs['current_assets'], bold: true, color: AC.cyan),
        _row('إجمالي الأصول', bs['total_assets'], bold: true, color: AC.gold),
        _row('إجمالي الالتزامات', bs['total_liabilities'], bold: true, color: AC.warning),
        _row('حقوق الملكية', bs['total_equity'], bold: true, color: AC.success),
      ]),
      const SizedBox(height: 14),

      // النسب
      _section('النسب المالية', [
        _ratioBar('هامش مجمل الربح', ratios['gross_margin_pct']),
        _ratioBar('هامش صافي الربح', ratios['net_margin_pct']),
        _ratioBar('نسبة التداول', ratios['current_ratio'], isRatio: true),
        _ratioBar('الدين / الأصول', ratios['debt_to_assets_pct']),
        _ratioBar('ROA', ratios['roa_pct']),
        _ratioBar('ROE', ratios['roe_pct']),
      ]),
      const SizedBox(height: 16),

      // زر إعادة التحليل
      GestureDetector(onTap: () => setState(() { _step = 0; _pickedFile = null; _fileName = ''; _evalResult = null; _analysisResult = null; }),
        child: Container(width: double.infinity, height: 52,
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]), borderRadius: BorderRadius.circular(14)),
          child: const Center(child: Text('تحليل ملف آخر', style: TextStyle(color: AC.navy, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))))),
      const SizedBox(height: 40),
    ]);
  }

  Widget _scoreCard(String label, dynamic value, Color color) {
    return Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.15))),
      child: Column(children: [
        Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, fontFamily: 'Tajawal')),
        Text(label, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }

  Widget _section(String title, List<Widget> children) {
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 10), ...children]));
  }

  Widget _row(String label, dynamic value, {bool bold = false, Color? color}) {
    final v = (value is num) ? value.toDouble() : 0.0;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(v < 0 ? '(${_fmt(v.abs())})' : _fmt(v),
          style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: color ?? (v < 0 ? const Color(0xFFE24B4A) : AC.textPrimary), fontFamily: 'Tajawal')),
        const Spacer(),
        Text(label, textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color ?? AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }

  Widget _ratioBar(String label, dynamic value, {bool isRatio = false}) {
    double v = (value is num) ? value.toDouble() : 0.0;
    double barVal = isRatio ? (v / 3.0).clamp(0, 1) : (v / 100.0).clamp(0, 1);
    return Padding(padding: const EdgeInsets.only(bottom: 10),
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






