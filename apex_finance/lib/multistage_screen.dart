import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // AC colors

// ═══════════════════════════════════════════════════════════
// شاشة التحليل متعدد المراحل — Unit 1
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
    'حساب القوائم المالية بالكود...',
    'تحليل أولي بالذكاء الاصطناعي...',
    'مراجعة شاملة وتحديد التوافق...',
    'إعداد النتيجة النهائية المعتمدة...',
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

  // ─── اختيار ملف ───
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _fileSelected = true;
        _fileName = result.files.first.name;
        _pickedFileData = result.files.first;
        _done = false;
        _error = false;
        _result = null;
      });
    }
  }

  // ─── بدء التحليل ───
  Future<void> _startAnalysis() async {
    if (_pickedFileData == null) return;
    setState(() {
      _analyzing = true;
      _progress = 0;
      _currentStage = 0;
      _error = false;
      _errorMsg = '';
    });

    // محاكاة تقدم المراحل
    _animateProgress();

    try {
      final uri = Uri.parse('$_apiBase/unit1/analyze/multistage');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', _pickedFileData!.bytes!, filename: _pickedFileData!.name));

      final streamed = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _analyzing = false;
            _done = true;
            _progress = 1.0;
            _currentStage = 4;
            _result = data;
          });
        }
      } else {
        final body = json.decode(response.body);
        throw Exception(body['detail'] ?? 'خطأ ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _analyzing = false;
          _error = true;
          _errorMsg = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  void _animateProgress() async {
    for (int i = 0; i < 4; i++) {
      if (!_analyzing || !mounted) return;
      setState(() => _currentStage = i);
      for (int j = 0; j < 20; j++) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!_analyzing || !mounted) return;
        setState(() => _progress = (i * 25 + (j + 1) * 1.25) / 100);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        elevation: 0,
        title: const Text('التحليل متعدد المراحل',
            style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AC.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // ─── بانر النظام ───
          _systemBanner(),
          const SizedBox(height: 16),

          // ─── منطقة رفع الملف ───
          _uploadZone(),
          const SizedBox(height: 16),

          // ─── شريط التقدم والمراحل ───
          if (_analyzing) _progressSection(),

          // ─── رسالة الخطأ ───
          if (_error) _errorSection(),

          // ─── زر التحليل ───
          if (!_analyzing && !_done) ...[
            const SizedBox(height: 8),
            _GoldBtn(
              label: _fileSelected ? 'بدء التحليل المتعدد المراحل' : 'اختر ملف ميزان المراجعة',
              onTap: _fileSelected ? _startAnalysis : _pickFile,
            ),
          ],

          // ─── النتائج ───
          if (_done && _result != null) ...[
            const SizedBox(height: 16),
            _resultSection(),
          ],

          const SizedBox(height: 40),
        ]),
      ),
    );
  }

  // ═══ بانر وصف النظام ═══
  Widget _systemBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AC.navy4, AC.navy3]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AC.gold.withOpacity(0.3)),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
            Text('نظام 4 مراحل — دقة 95%+', textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', color: AC.gold)),
            SizedBox(height: 4),
            Text('كود + ذكاء اصطناعي + مراجعة + اعتماد نهائي', textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
          ]),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]),
            borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.auto_awesome_rounded, color: AC.navy, size: 22),
        ),
      ]),
    );
  }

  // ═══ منطقة رفع الملف ═══
  Widget _uploadZone() {
    return GestureDetector(
      onTap: _analyzing ? null : _pickFile,
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
      // شريط التقدم
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

      // المراحل الأربع
      ...List.generate(4, (i) => _stageRow(i)),
      const SizedBox(height: 16),
    ]);
  }

  Widget _stageRow(int index) {
    final isActive = _currentStage == index;
    final isDone = _currentStage > index;
    final isPending = _currentStage < index;

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
          // الأيقونة
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

          // رقم المرحلة
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

          // النص
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

  // ═══ عرض النتائج ═══
  Widget _resultSection() {
    final finalResult = _result!['final_result'] ?? {};
    final financialData = finalResult['financial_data'] ?? {};
    final incomeStatement = financialData['income_statement'] ?? {};
    final balanceSheet = financialData['balance_sheet'] ?? {};
    final ratios = financialData['ratios'] ?? {};
    final aiAnalysis = finalResult['ai_analysis'] ?? {};
    final confidence = (finalResult['confidence_pct'] ?? 0).toDouble();
    final qualityLabel = finalResult['quality_label'] ?? '';
    final stages = _result!['stages'] ?? {};

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // ─── مؤشر الثقة ───
      _confidenceCard(confidence, qualityLabel),
      const SizedBox(height: 16),

      // ─── ملخص المراحل ───
      _sectionTitle('نتائج المراحل'),
      const SizedBox(height: 8),
      _stagesSummary(stages),
      const SizedBox(height: 16),

      // ─── قائمة الدخل ───
      _sectionTitle('قائمة الدخل'),
      const SizedBox(height: 8),
      _incomeCard(incomeStatement),
      const SizedBox(height: 16),

      // ─── الميزانية ───
      _sectionTitle('الميزانية العمومية'),
      const SizedBox(height: 8),
      _balanceCard(balanceSheet),
      const SizedBox(height: 16),

      // ─── النسب المالية ───
      _sectionTitle('النسب المالية'),
      const SizedBox(height: 8),
      _ratiosCard(ratios),
      const SizedBox(height: 16),

      // ─── تحليل الذكاء الاصطناعي ───
      if (aiAnalysis.isNotEmpty) ...[
        _sectionTitle('تحليل الذكاء الاصطناعي'),
        const SizedBox(height: 8),
        _aiCard(aiAnalysis),
        const SizedBox(height: 16),
      ],

      // ─── أزرار التصدير ───
      Row(children: [
        Expanded(child: _GoldBtn(label: 'تحليل ملف آخر', onTap: () {
          setState(() { _fileSelected = false; _done = false; _result = null; _fileName = ''; _pickedFileData = null; });
        })),
      ]),
    ]);
  }

  // ═══ بطاقة مؤشر الثقة ═══
  Widget _confidenceCard(double confidence, String label) {
    final color = confidence >= 95 ? AC.success : confidence >= 85 ? AC.gold : AC.warning;
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

  // ═══ ملخص المراحل ═══
  Widget _stagesSummary(Map<String, dynamic> stages) {
    final items = [
      {'key': 'stage1_code', 'icon': Icons.code_rounded, 'color': AC.cyan, 'label': 'حساب الكود'},
      {'key': 'stage1_ai_initial', 'icon': Icons.psychology_rounded, 'color': AC.gold, 'label': 'تحليل AI'},
      {'key': 'stage3_review', 'icon': Icons.rate_review_rounded, 'color': AC.warning, 'label': 'المراجعة'},
      {'key': 'stage4_final', 'icon': Icons.verified_rounded, 'color': AC.success, 'label': 'النهائي'},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final stage = stages[item['key']] ?? {};
          final conf = (stage['confidence_pct'] ?? stage['final_confidence_pct'] ?? 0);
          return Column(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: (item['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
              child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 20)),
            const SizedBox(height: 6),
            Text('$conf%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: item['color'] as Color, fontFamily: 'Tajawal')),
            Text(item['label'] as String, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
          ]);
        }).toList(),
      ),
    );
  }

  // ═══ قائمة الدخل ═══
  Widget _incomeCard(Map<String, dynamic> data) {
    return _dataCard([
      _dataRow('الإيرادات', data['revenue']),
      _dataRow('إيرادات أخرى', data['other_revenue']),
      _dataRow('مردودات المبيعات', data['sales_returns'], negative: true),
      _divider(),
      _dataRow('صافي الإيرادات', data['net_revenue'], bold: true, color: AC.gold),
      _divider(),
      _dataRow('مخزون أول المدة', data['opening_inventory']),
      _dataRow('المشتريات', data['purchases_net']),
      _dataRow('مخزون آخر المدة', data['closing_inventory'], negative: true),
      _dataRow('تكلفة البضاعة المباعة', data['cogs'], bold: true),
      _divider(),
      _dataRow('مجمل الربح', data['gross_profit'], bold: true, color: AC.success),
      _dataRow('مصروفات إدارية', data['admin_expenses'], negative: true),
      _dataRow('مصروفات بيع وتوزيع', data['sales_expenses'], negative: true),
      _dataRow('EBIT', data['ebit'], bold: true),
      _dataRow('EBITDA', data['ebitda']),
      _dataRow('تكاليف تمويل', data['interest'], negative: true),
      _dataRow('زكاة وضرائب', data['tax'], negative: true),
      _divider(),
      _dataRow('صافي الربح', data['net_profit'], bold: true, color: AC.gold),
    ]);
  }

  // ═══ الميزانية ═══
  Widget _balanceCard(Map<String, dynamic> data) {
    return _dataCard([
      _dataRow('النقدية', data['cash']),
      _dataRow('ذمم مدينة تجارية', data['trade_receivables']),
      _dataRow('ذمم مدينة أخرى', data['other_receivables']),
      _dataRow('المخزون', data['closing_inventory']),
      _dataRow('مصروفات مدفوعة مقدماً', data['prepaid']),
      _dataRow('الأصول المتداولة', data['current_assets'], bold: true, color: AC.cyan),
      _divider(),
      _dataRow('أصول ثابتة (إجمالي)', data['fixed_assets_gross']),
      _dataRow('مجمع الإهلاك', data['depreciation'], negative: true),
      _dataRow('صافي الأصول الثابتة', data['fixed_assets_net'], bold: true),
      _divider(),
      _dataRow('إجمالي الأصول', data['total_assets'], bold: true, color: AC.gold),
      _divider(),
      _dataRow('ذمم دائنة تجارية', data['trade_payables']),
      _dataRow('قروض متداولة', data['loans_current']),
      _dataRow('رواتب مستحقة', data['wages_payable']),
      _dataRow('ضريبة مستحقة', data['tax_payable']),
      _dataRow('مستحقات أخرى', data['accrued']),
      _dataRow('إجمالي الالتزامات', data['total_liabilities'], bold: true, color: AC.warning),
      _divider(),
      _dataRow('رأس المال', data['equity_capital']),
      _dataRow('الاحتياطي', data['equity_reserve']),
      _dataRow('أرباح مبقاة', data['retained_earnings']),
      _dataRow('ربح العام', data['net_profit_year']),
      _dataRow('إجمالي حقوق الملكية', data['total_equity'], bold: true, color: AC.success),
      _divider(),
      _dataRow('فحص التوازن', data['balance_check'], bold: true,
          color: (data['balance_check'] ?? 0).abs() < 1 ? AC.success : AC.danger),
    ]);
  }

  // ═══ النسب المالية ═══
  Widget _ratiosCard(Map<String, dynamic> data) {
    return _dataCard([
      _ratioBar('هامش مجمل الربح', '${data['gross_margin_pct'] ?? 0}%', (data['gross_margin_pct'] ?? 0) / 100),
      _ratioBar('هامش صافي الربح', '${data['net_margin_pct'] ?? 0}%', (data['net_margin_pct'] ?? 0) / 100),
      _ratioBar('هامش EBITDA', '${data['ebitda_margin_pct'] ?? 0}%', (data['ebitda_margin_pct'] ?? 0) / 100),
      _ratioBar('نسبة التداول', '${data['current_ratio'] ?? 0}', ((data['current_ratio'] ?? 0) / 3).clamp(0.0, 1.0)),
      _ratioBar('نسبة السيولة السريعة', '${data['quick_ratio'] ?? 0}', ((data['quick_ratio'] ?? 0) / 3).clamp(0.0, 1.0)),
      _ratioBar('الدين / الأصول', '${data['debt_to_assets_pct'] ?? 0}%', (data['debt_to_assets_pct'] ?? 0) / 100),
      _ratioBar('العائد على الأصول ROA', '${data['roa_pct'] ?? 0}%', (data['roa_pct'] ?? 0).abs() / 50),
      _ratioBar('العائد على الملكية ROE', '${data['roe_pct'] ?? 0}%', (data['roe_pct'] ?? 0).abs() / 50),
      _ratioBar('دوران الأصول', '${data['asset_turnover'] ?? 0}', ((data['asset_turnover'] ?? 0) / 3).clamp(0.0, 1.0)),
      _ratioBar('دوران المخزون', '${data['inventory_turnover'] ?? 0}', ((data['inventory_turnover'] ?? 0) / 15).clamp(0.0, 1.0)),
    ]);
  }

  // ═══ بطاقة AI ═══
  Widget _aiCard(Map<String, dynamic> ai) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
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

        // المخاطر
        if (ai['risks'] != null) ...[
          _aiSubTitle('المخاطر', Icons.warning_amber_rounded, AC.warning),
          const SizedBox(height: 6),
          ...((ai['risks'] as List).map((r) {
            if (r is Map) {
              return _bulletItem('${r['risk']} (${r['severity']}) — ${r['action']}', AC.warning);
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
              return _bulletItem('${r['action']} (${r['priority']}) — ${r['timeline']}', AC.cyan);
            }
            return _bulletItem(r.toString(), AC.cyan);
          })),
          const SizedBox(height: 12),
        ],

        // خطة التحسين
        if (ai['improvement_plan'] != null) ...[
          _aiSubTitle('خطة التحسين', Icons.rocket_launch_rounded, AC.gold),
          const SizedBox(height: 6),
          ...((ai['improvement_plan'] as List).map((s) => _bulletItem(s.toString(), AC.gold))),
        ],
      ]),
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

  Widget _dataRow(String label, dynamic value, {bool bold = false, bool negative = false, Color? color}) {
    final num = (value ?? 0).toDouble();
    final formatted = _formatNum(num);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(formatted, style: TextStyle(
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



