import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // AC colors

// ═══════════════════════════════════════════════════════════
// شاشة التحليل — APEX v2
// ═══════════════════════════════════════════════════════════
class MultistageScreen extends StatefulWidget {
  const MultistageScreen({super.key});
  @override
  State<MultistageScreen> createState() => _MultistageScreenState();
}

class _MultistageScreenState extends State<MultistageScreen> with TickerProviderStateMixin {
  // ─── الحالة ───
  bool _fileSelected = false;
  bool _analyzing = false;
  bool _done = false;
  bool _error = false;
  String _fileName = '';
  String _errorMsg = '';
  PlatformFile? _pickedFileData;
  double _progress = 0;
  int _currentStage = 0;
  Map<String, dynamic>? _result;
  late AnimationController _pulseCtrl;

  static const _apiBase = 'https://apex-api-ootk.onrender.com';

  final _stageLabels = [
    'قراءة الملف وتصنيف الحسابات...',
    'بناء القوائم المالية...',
    'حساب النسب والتحقق...',
    'إعداد تقرير الذكاء الاصطناعي...',
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ═══ اختيار الملف ═══
  Future<void> _pickFile() async {
    if (_analyzing) return;
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (picked != null && picked.files.isNotEmpty) {
      setState(() {
        _fileSelected = true;
        _done = false;
        _error = false;
        _result = null;
        _pickedFileData = picked.files.first;
        _fileName = _pickedFileData!.name;
      });
    }
  }

  // ═══ التحليل ═══
  Future<void> _startAnalysis() async {
    if (_pickedFileData == null) return;
    setState(() {
      _analyzing = true;
      _error = false;
      _done = false;
      _progress = 0;
      _currentStage = 0;
    });

    try {
      // Stage progress simulation
      _animateProgress(0, 0.15, 1000);
      setState(() => _currentStage = 0);

      final uri = Uri.parse('$_apiBase/analyze/full?industry=retail&language=ar');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', _pickedFileData!.bytes!,
          filename: _pickedFileData!.name));

      _animateProgress(0.15, 0.40, 2000);
      setState(() => _currentStage = 1);

      final streamed = await request.send().timeout(const Duration(seconds: 300));
      
      _animateProgress(0.40, 0.70, 1000);
      setState(() => _currentStage = 2);

      final response = await http.Response.fromStream(streamed);

      _animateProgress(0.70, 0.90, 500);
      setState(() => _currentStage = 3);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true) {
          await Future.delayed(const Duration(milliseconds: 500));
          _animateProgress(0.90, 1.0, 300);
          setState(() => _currentStage = 4);
          setState(() {
            _result = data;
            _done = true;
            _analyzing = false;
            _progress = 1.0;
          });
        } else {
          throw Exception(data['error'] ?? 'فشل التحليل');
        }
      } else {
        throw Exception('خطأ من السيرفر: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = true;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
        _analyzing = false;
      });
    }
  }

  void _animateProgress(double from, double to, int ms) async {
    final steps = 10;
    final stepDur = ms ~/ steps;
    for (int i = 0; i <= steps; i++) {
      await Future.delayed(Duration(milliseconds: stepDur));
      if (mounted) {
        setState(() => _progress = from + (to - from) * (i / steps));
      }
    }
  }

  // ═══ الواجهة ═══
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: const Text('تحليل ميزان المراجعة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: AC.textPrimary)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AC.gold), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // رفع الملف
          _uploadArea(),
          const SizedBox(height: 16),

          // زر التحليل
          if (_fileSelected && !_done)
            _GoldBtn(label: 'بدء التحليل الشامل', onTap: _startAnalysis, isLoading: _analyzing),

          // شريط التقدم
          if (_analyzing) ...[
            const SizedBox(height: 16),
            _progressSection(),
          ],

          // خطأ
          if (_error) ...[
            const SizedBox(height: 16),
            _errorSection(),
          ],

          // النتائج
          if (_done && _result != null) ...[
            const SizedBox(height: 16),
            _resultSection(),
          ],
        ]),
      ),
    );
  }

  // ═══ منطقة رفع الملف ═══
  Widget _uploadArea() {
    return GestureDetector(
      onTap: _pickFile,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity, height: 150,
        decoration: BoxDecoration(
          color: _done ? AC.success.withOpacity(0.05) : _fileSelected ? AC.gold.withOpacity(0.05) : AC.navy3,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _done ? AC.success.withOpacity(0.4) : _fileSelected ? AC.gold.withOpacity(0.4) : AC.border, width: 1.5),
        ),
        child: _done
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.check_circle_rounded, color: AC.success, size: 44),
                const SizedBox(height: 8),
                const Text('اكتمل التحليل بنجاح!', style: TextStyle(color: AC.success, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
                const SizedBox(height: 2),
                Text(_fileName, style: const TextStyle(color: AC.textSecondary, fontSize: 12, fontFamily: 'Tajawal')),
              ])
            : _fileSelected
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.description_rounded, color: AC.gold, size: 44),
                    const SizedBox(height: 8),
                    Text(_fileName, style: const TextStyle(color: AC.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
                    const SizedBox(height: 4),
                    const Text('جاهز للتحليل — اضغط لتغيير الملف', style: TextStyle(color: AC.gold, fontSize: 12, fontFamily: 'Tajawal')),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: AC.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.cloud_upload_outlined, color: AC.gold, size: 28)),
                    const SizedBox(height: 10),
                    const Text('المطلوب: ميزان المراجعة (Excel) يحتوي على تبويب الحساب + الأرصدة',
                    textDirection: TextDirection.rtl, style: TextStyle(color: AC.textSecondary, fontSize: 11, fontFamily: 'Tajawal')),
                    const SizedBox(height: 6),
                    const Text('اضغط لرفع ميزان المراجعة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', color: AC.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Excel فقط (.xlsx, .xls)', style: TextStyle(color: AC.textSecondary, fontSize: 12, fontFamily: 'Tajawal')),
                  ]),
      ),
    );
  }

  // ═══ شريط التقدم والمراحل ═══
  Widget _progressSection() {
    return Column(children: [
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: _progress,
          minHeight: 8,
          backgroundColor: AC.navy3,
          valueColor: const AlwaysStoppedAnimation<Color>(AC.gold),
        ),
      ),
      const SizedBox(height: 8),
      Text('${(_progress * 100).toInt()}%', style: const TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      ...List.generate(4, (i) => _stageRow(i)),
      const SizedBox(height: 16),
    ]);
  }

  Widget _stageRow(int index) {
    final isActive = _currentStage == index;
    final isDone = _currentStage > index;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AC.gold.withOpacity(0.06) : AC.navy3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone ? AC.success.withOpacity(0.3) : isActive ? AC.gold.withOpacity(0.4) : AC.border),
        ),
        child: Row(children: [
          if (isDone)
            const Icon(Icons.check_circle_rounded, color: AC.success, size: 22)
          else if (isActive)
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) => Icon(Icons.sync_rounded, color: AC.gold.withOpacity(0.5 + _pulseCtrl.value * 0.5), size: 22),
            )
          else
            Icon(Icons.radio_button_unchecked, color: AC.textHint, size: 22),
          const SizedBox(width: 10),
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? AC.success.withOpacity(0.15) : isActive ? AC.gold.withOpacity(0.15) : AC.navy4,
            ),
            child: Center(child: Text('${index + 1}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: isDone ? AC.success : isActive ? AC.gold : AC.textHint))),
          ),
          const Spacer(),
          Text(
            isDone ? _stageLabels[index].replaceAll('...', ' ✓') : _stageLabels[index],
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 13, fontFamily: 'Tajawal',
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: isDone ? AC.success : isActive ? AC.gold : AC.textHint),
          ),
        ]),
      ),
    );
  }

  // ═══ رسالة الخطأ ═══
  Widget _errorSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.danger.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AC.danger.withOpacity(0.3)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('حدث خطأ أثناء التحليل', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.danger, fontFamily: 'Tajawal')),
          const SizedBox(height: 4),
          Text(_errorMsg, textDirection: TextDirection.rtl, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
        ])),
        const SizedBox(width: 12),
        const Icon(Icons.error_outline_rounded, color: AC.danger, size: 28),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  عرض النتائج — V2 Schema
  // ═══════════════════════════════════════════════════════════
  Widget _resultSection() {
    final r = _result!;
    final income = r['income_statement'] ?? {};
    final balance = r['balance_sheet'] ?? {};
    final ratios = r['ratios'] ?? {};
    final prof = ratios['profitability'] ?? {};
    final liq = ratios['liquidity'] ?? {};
    final lev = ratios['leverage'] ?? {};
    final eff = ratios['efficiency'] ?? {};
    final confidence = r['confidence'] ?? {};
    final narrative = r['narrative'] ?? {};
    final validationSummary = r['validation_summary'] ?? {};
    final meta = r['meta'] ?? {};
    final brain = r['knowledge_brain'] ?? {};

    final confOverall = ((confidence['overall'] ?? 0) * 100).toDouble();
    final confLabel = confidence['label'] ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // ─── مؤشر الثقة ───
      _confidenceCard(confOverall, confLabel),
      const SizedBox(height: 16),

      // ─── ملخص سريع ───
      _metaSummary(meta, validationSummary, confidence),
      const SizedBox(height: 16),

      // ─── العقل المعرفي ───
      if (brain.isNotEmpty && (brain['rules_triggered'] ?? 0) > 0) ...[
        _sectionTitle('العقل المعرفي'),
        const SizedBox(height: 8),
        _brainCard(brain),
        const SizedBox(height: 16),
      ],

      // ─── قائمة الدخل ───
      _sectionTitle('قائمة الدخل'),
      const SizedBox(height: 8),
      _incomeCard(income),
      const SizedBox(height: 16),

      // ─── الميزانية ───
      _sectionTitle('الميزانية العمومية'),
      const SizedBox(height: 8),
      _balanceCard(balance),
      const SizedBox(height: 16),

      // ─── النسب المالية ───
      _sectionTitle('النسب المالية'),
      const SizedBox(height: 8),
      _ratiosCard(prof, liq, lev, eff),
      const SizedBox(height: 16),

      // ─── تحليل الذكاء الاصطناعي ───
      if (narrative.isNotEmpty && narrative['executive_summary'] != null) ...[
        _sectionTitle('تحليل الذكاء الاصطناعي'),
        const SizedBox(height: 8),
        _aiCard(narrative),
        const SizedBox(height: 16),
      ],

      // ─── أزرار ───
      Row(children: [
        Expanded(child: _GoldBtn(label: 'تحليل ملف آخر', onTap: () {
          setState(() { _fileSelected = false; _done = false; _result = null; _fileName = ''; _pickedFileData = null; });
        })),
      ]),
    ]);
  }

  // ═══ ملخص سريع ═══
  Widget _metaSummary(Map<String, dynamic> meta, Map<String, dynamic> vs, Map<String, dynamic> conf) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (meta['company_name'] != null && (meta['company_name'] as String).isNotEmpty)
          Text(meta['company_name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _miniStat('الحسابات', '${meta['total_accounts'] ?? 0}', AC.cyan),
          _miniStat('أخطاء', '${vs['errors'] ?? 0}', (vs['errors'] ?? 0) > 0 ? AC.danger : AC.success),
          _miniStat('تحذيرات', '${vs['warnings'] ?? 0}', (vs['warnings'] ?? 0) > 0 ? AC.warning : AC.success),
          _miniStat('يمكن الاعتماد', vs['can_approve'] == true ? '✓' : '✗', vs['can_approve'] == true ? AC.success : AC.danger),
        ]),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color, fontFamily: 'Tajawal')),
      Text(label, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
    ]);
  }

  // ═══ بطاقة مؤشر الثقة ═══
  Widget _confidenceCard(double confidence, String label) {
    final color = confidence >= 90 ? AC.success : confidence >= 75 ? AC.gold : AC.warning;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(children: [
        SizedBox(width: 80, height: 80,
          child: CustomPaint(
            painter: _RingPainter(confidence / 100, color),
            child: Center(child: Text('${confidence.toInt()}', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900))),
          )),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('مؤشر الثقة النهائي', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
          Text('${confidence.toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: color, height: 1, fontFamily: 'Tajawal')),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(label, style: TextStyle(fontSize: 12, color: color, fontFamily: 'Tajawal')),
          ),
        ])),
      ]),
    );
  }

  // ═══ قائمة الدخل — v2 ═══
  Widget _incomeCard(Map<String, dynamic> data) {
    return _dataCard([
      _dataRow('الإيرادات', data['revenue']),
      _dataRow('إيرادات خدمات', data['service_revenue']),
      _dataRow('مردودات المبيعات', data['sales_returns'], negative: true),
      _divider(),
      _dataRow('صافي الإيرادات', data['net_revenue'], bold: true, color: AC.gold),
      _divider(),
      _dataRow('تكلفة البضاعة المباعة', data['cogs'], negative: true),
      _dataRow('مجمل الربح', data['gross_profit'], bold: true, color: AC.success),
      _divider(),
      _dataRow('م. إدارية وعمومية', data['admin_expenses'], negative: true),
      _dataRow('م. بيع وتسويق', data['selling_expenses'], negative: true),
      _dataRow('الربح التشغيلي', data['operating_profit'], bold: true),
      _dataRow('EBITDA', data['ebitda']),
      _divider(),
      _dataRow('إيرادات أخرى', data['other_income']),
      _dataRow('مصروفات أخرى', data['other_expenses'], negative: true),
      _dataRow('تكاليف تمويل', data['finance_cost'], negative: true),
      _dataRow('زكاة وضرائب', data['zakat_tax'], negative: true),
      _divider(),
      _dataRow('صافي الربح', data['net_profit'], bold: true, color: AC.gold),
    ]);
  }

  // ═══ الميزانية — v2 ═══
  Widget _balanceCard(Map<String, dynamic> data) {
    final ca = data['current_assets'] ?? {};
    final nca = data['non_current_assets'] ?? {};
    final cl = data['current_liabilities'] ?? {};
    final ncl = data['non_current_liabilities'] ?? {};
    final eq = data['equity'] ?? {};

    return _dataCard([
      _dataRow('الأصول المتداولة', ca['total'], bold: true, color: AC.cyan),
      _dataRow('الأصول غير المتداولة', nca['total']),
      _divider(),
      _dataRow('إجمالي الأصول', data['total_assets'], bold: true, color: AC.gold),
      _divider(),
      _dataRow('التزامات متداولة', cl['total']),
      _dataRow('التزامات غير متداولة', ncl['total']),
      _dataRow('إجمالي الالتزامات', data['total_liabilities'], bold: true, color: AC.warning),
      _divider(),
      _dataRow('حقوق الملكية', eq['total'], bold: true, color: AC.success),
      _divider(),
      _dataRow('فحص التوازن', data['balance_check'], bold: true,
          color: (data['balance_check'] ?? 0).abs() < 1 ? AC.success : AC.danger),
      _dataRow('الميزانية متوازنة', null, bold: true,
          color: data['is_balanced'] == true ? AC.success : AC.danger,
          customValue: data['is_balanced'] == true ? '✓ نعم' : '✗ لا'),
    ]);
  }

  // ═══ النسب المالية — v2 ═══
  Widget _ratiosCard(Map<String, dynamic> prof, Map<String, dynamic> liq, Map<String, dynamic> lev, Map<String, dynamic> eff) {
    return _dataCard([
      _ratioBar('هامش مجمل الربح', '${prof['gross_margin_pct'] ?? 0}%', ((prof['gross_margin_pct'] ?? 0) / 100).clamp(0.0, 1.0)),
      _ratioBar('هامش صافي الربح', '${prof['net_margin_pct'] ?? 0}%', ((prof['net_margin_pct'] ?? 0) / 100).clamp(0.0, 1.0)),
      _ratioBar('هامش EBITDA', '${prof['ebitda_margin_pct'] ?? 0}%', ((prof['ebitda_margin_pct'] ?? 0) / 100).clamp(0.0, 1.0)),
      _ratioBar('نسبة التداول', '${liq['current_ratio'] ?? 0}', ((liq['current_ratio'] ?? 0) / 3).clamp(0.0, 1.0)),
      _ratioBar('النسبة السريعة', '${liq['quick_ratio'] ?? 0}', ((liq['quick_ratio'] ?? 0) / 3).clamp(0.0, 1.0)),
      _ratioBar('الدين/الأصول', '${lev['debt_to_assets_pct'] ?? 0}%', ((lev['debt_to_assets_pct'] ?? 0) / 100).clamp(0.0, 1.0)),
      _ratioBar('ROA', '${prof['roa_pct'] ?? 0}%', ((prof['roa_pct'] ?? 0).abs() / 50).clamp(0.0, 1.0)),
      _ratioBar('ROE', '${prof['roe_pct'] ?? 0}%', ((prof['roe_pct'] ?? 0).abs() / 100).clamp(0.0, 1.0)),
      _ratioBar('دوران الأصول', '${eff['asset_turnover'] ?? 0}', ((eff['asset_turnover'] ?? 0) / 3).clamp(0.0, 1.0)),
      _ratioBar('DSO (أيام التحصيل)', '${eff['dso'] ?? "-"}', ((eff['dso'] ?? 0) / 90).clamp(0.0, 1.0)),
      _ratioBar('أيام المخزون', '${eff['days_in_inventory'] ?? "-"}', ((eff['days_in_inventory'] ?? 0) / 120).clamp(0.0, 1.0)),
    ]);
  }

  // ═══ بطاقة AI — v2 ═══
  Widget _aiCard(Map<String, dynamic> ai) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // المنصة المستخدمة
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AC.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('${ai['platform'] ?? ''}', style: const TextStyle(fontSize: 10, color: AC.cyan, fontFamily: 'Tajawal')),
          ),
        ]),
        const SizedBox(height: 8),

        // الملخص التنفيذي
        if (ai['executive_summary'] != null) ...[
          const Text('الملخص التنفيذي', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
          const SizedBox(height: 6),
          Text(ai['executive_summary'], textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.6)),
          const SizedBox(height: 14),
        ],

        // نقاط القوة
        if (ai['strengths'] != null) ...[
          _aiSubTitle('نقاط القوة', Icons.trending_up_rounded, AC.success),
          const SizedBox(height: 6),
          ...((ai['strengths'] as List).map((s) => _bulletItem(s.toString(), AC.success))),
          const SizedBox(height: 12),
        ],

        // نقاط الضعف
        if (ai['weaknesses'] != null) ...[
          _aiSubTitle('نقاط الضعف', Icons.trending_down_rounded, AC.danger),
          const SizedBox(height: 6),
          ...((ai['weaknesses'] as List).map((s) => _bulletItem(s.toString(), AC.danger))),
          const SizedBox(height: 12),
        ],

        // المخاطر
        if (ai['risks'] != null) ...[
          _aiSubTitle('المخاطر', Icons.warning_amber_rounded, AC.warning),
          const SizedBox(height: 6),
          ...((ai['risks'] as List).map((r) {
            if (r is Map) {
              return _bulletItem('[${r['severity']}] ${r['risk']} — ${r['impact']}', AC.warning);
            }
            return _bulletItem(r.toString(), AC.warning);
          })),
          const SizedBox(height: 12),
        ],

        // التوصيات
        if (ai['recommendations'] != null) ...[
          _aiSubTitle('التوصيات', Icons.lightbulb_outline_rounded, AC.cyan),
          const SizedBox(height: 6),
          ...((ai['recommendations'] as List).map((r) {
            if (r is Map) {
              return _bulletItem('[${r['priority']}] ${r['action']} — ${r['timeline']}', AC.cyan);
            }
            return _bulletItem(r.toString(), AC.cyan);
          })),
          const SizedBox(height: 12),
        ],

        // رسالة الإدارة
        if (ai['management_letter'] != null) ...[
          _aiSubTitle('رسالة الإدارة', Icons.mail_outline_rounded, AC.gold),
          const SizedBox(height: 6),
          Text(ai['management_letter'], textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5)),
        ],
      ]),
    );
  }

  // ═══ بطاقة العقل المعرفي ═══
  Widget _brainCard(Map<String, dynamic> brain) {
    final findings = (brain['brain_findings'] as List?) ?? [];
    final compliance = (brain['compliance_notes'] as List?) ?? [];
    final recommendations = (brain['brain_recommendations'] as List?) ?? [];
    final rulesEvaluated = brain['rules_evaluated'] ?? 0;
    final rulesTriggered = brain['rules_triggered'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AC.cyan.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Header
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AC.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('$rulesTriggered / $rulesEvaluated قاعدة', style: const TextStyle(fontSize: 10, color: AC.cyan, fontFamily: 'Tajawal')),
          ),
          Row(children: [
            const Text('العقل المعرفي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.cyan, fontFamily: 'Tajawal')),
            const SizedBox(width: 6),
            const Icon(Icons.psychology_rounded, color: AC.cyan, size: 18),
          ]),
        ]),
        const SizedBox(height: 12),

        // Critical findings first
        ...findings.where((f) => f['severity'] == 'critical').map((f) => _brainItem(
          f['message'] ?? '', AC.danger, Icons.error_rounded,
          reference: f['reference'], authority: f['authority'],
        )),

        // Warnings
        ...findings.where((f) => f['severity'] == 'warning').map((f) => _brainItem(
          f['message'] ?? '', AC.warning, Icons.warning_amber_rounded,
          reference: f['reference'], authority: f['authority'],
        )),

        // Compliance notes
        if (compliance.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('ملاحظات الامتثال', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
            const SizedBox(width: 4),
            const Icon(Icons.gavel_rounded, color: AC.gold, size: 14),
          ]),
          const SizedBox(height: 6),
          ...compliance.map((c) => _brainItem(
            c['message'] ?? '', 
            c['severity'] == 'warning' ? AC.warning : AC.gold,
            c['severity'] == 'warning' ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
            reference: c['reference'], authority: c['authority'],
          )),
        ],

        // Recommendations
        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('توصيات مبنية على الأنظمة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AC.success, fontFamily: 'Tajawal')),
            const SizedBox(width: 4),
            const Icon(Icons.tips_and_updates_rounded, color: AC.success, size: 14),
          ]),
          const SizedBox(height: 6),
          ...recommendations.map((r) => _brainItem(
            r['message'] ?? '', AC.success, Icons.lightbulb_outline_rounded,
            reference: r['reference'], authority: r['authority'],
          )),
        ],

        // Info findings
        ...findings.where((f) => f['severity'] == 'info').map((f) => _brainItem(
          f['message'] ?? '', AC.textSecondary, Icons.info_outline_rounded,
          reference: f['reference'], authority: f['authority'],
        )),
      ]),
    );
  }

  Widget _brainItem(String message, Color color, IconData icon, {String? reference, String? authority}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(message, textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 12, color: color, fontFamily: 'Tajawal', height: 1.5))),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, color: color, size: 16)),
          ]),
          if (reference != null && reference.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (authority != null && authority.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                  child: Text(authority, style: TextStyle(fontSize: 9, color: color.withOpacity(0.7), fontFamily: 'Tajawal')),
                ),
              Flexible(child: Text(reference, textDirection: TextDirection.rtl, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 9, color: color.withOpacity(0.5), fontFamily: 'Tajawal'))),
              const SizedBox(width: 4),
              Icon(Icons.menu_book_rounded, color: color.withOpacity(0.4), size: 10),
            ]),
          ],
        ]),
      ),
    );
  }

  // ═══ عناصر مساعدة ═══
  Widget _sectionTitle(String title) => Align(
    alignment: Alignment.centerRight,
    child: Text(title, textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
  );

  Widget _dataCard(List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
    child: Column(children: children),
  );

  Widget _dataRow(String label, dynamic value, {bool bold = false, bool negative = false, Color? color, String? customValue}) {
    final display = customValue ?? (value != null ? _formatNum((value).toDouble()) : '-');
    final num = value != null ? (value).toDouble() : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(display, style: TextStyle(
          fontSize: bold ? 14 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? (num < 0 ? AC.danger : AC.textPrimary),
          fontFamily: 'Tajawal')),
        Text(label, textDirection: TextDirection.rtl, style: TextStyle(
          fontSize: bold ? 14 : 13,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? AC.textSecondary,
          fontFamily: 'Tajawal')),
      ]),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Divider(color: AC.border, height: 1),
  );

  Widget _ratioBar(String label, String value, double pct) {
    final clampedPct = pct.clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(value, style: const TextStyle(fontSize: 13, color: AC.gold, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
          Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: clampedPct.toDouble(),
            minHeight: 4,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: const AlwaysStoppedAnimation<Color>(AC.gold)),
        ),
      ]),
    );
  }

  Widget _aiSubTitle(String title, IconData icon, Color color) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
      const SizedBox(width: 6),
      Icon(icon, color: color, size: 16),
    ],
  );

  Widget _bulletItem(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(text, textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5))),
      const SizedBox(width: 8),
      Padding(padding: const EdgeInsets.only(top: 6), child: Container(width: 5, height: 5,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color))),
    ]),
  );

  String _formatNum(double n) {
    if (n == 0) return '0';
    final abs = n.abs();
    String formatted;
    if (abs >= 1000000) {
      formatted = '${(abs / 1000000).toStringAsFixed(2)}M';
    } else if (abs >= 1000) {
      formatted = '${(abs / 1000).toStringAsFixed(1)}K';
    } else {
      formatted = abs.toStringAsFixed(2);
    }
    return n < 0 ? '($formatted)' : formatted;
  }
}

// ═══ زر ذهبي ═══
class _GoldBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  const _GoldBtn({required this.label, required this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AC.gold, AC.goldDim], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AC.gold.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))]),
        child: Center(child: isLoading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AC.navy, strokeWidth: 2.5))
          : Text(label, style: const TextStyle(color: AC.navy, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')))),
    );
  }
}

// ═══ رسام الحلقة ═══
class _RingPainter extends CustomPainter {
  final double v;
  final Color color;
  const _RingPainter(this.v, this.color);
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 - 6;
    c.drawCircle(center, r, Paint()..color = color.withOpacity(0.1)..strokeWidth = 8..style = PaintingStyle.stroke);
    c.drawArc(Rect.fromCircle(center: center, radius: r), -1.5707963, 2 * 3.14159 * v, false,
        Paint()..color = color..strokeWidth = 8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_) => false;
}
