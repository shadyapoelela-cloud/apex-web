import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

class MultistageScreen extends StatefulWidget {
  const MultistageScreen({super.key});
  @override
  State<MultistageScreen> createState() => _MultistageScreenState();
}

class _MultistageScreenState extends State<MultistageScreen> with TickerProviderStateMixin {
  // ─── الحالة ───
  int _step = 0; // 0=upload, 1=tab_review, 2=questions, 3=analyzing, 4=results
  bool _loading = false;
  bool _error = false;
  String _errorMsg = '';
  String _fileName = '';
  PlatformFile? _pickedFile;
  List<int>? _fileBytes;  // bytes stored as Uint8List copy
  Map<String, dynamic>? _tabReview;
  Map<String, dynamic>? _result;
  late AnimationController _pulseCtrl;

  // أسئلة ما قبل التحليل
  String _inventorySystem = ''; // periodic / perpetual
  bool _inventoryClosed = true; // هل تم إقفال الجرد في الميزان
  bool _accountsClosed = true; // هل تم إقفال الحسابات
  final _closingInvCtrl = TextEditingController();
  double _progress = 0;
  int _currentStage = 0;

  static const _api = 'https://apex-api-ootk.onrender.com';

  final _analyzeStages = ['تصنيف الحسابات...', 'بناء القوائم المالية...', 'حساب النسب والتحقق...', 'تقرير الذكاء الاصطناعي...'];

  @override
  void initState() { super.initState(); _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true); }
  @override
  void dispose() { _pulseCtrl.dispose(); _closingInvCtrl.dispose(); super.dispose(); }

  // ═══════════════════════════════════════
  //  الخطوة 1: رفع الملف
  // ═══════════════════════════════════════
  Future<void> _pickFile() async {
    if (_loading) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls'], withData: true);
    if (picked != null && picked.files.isNotEmpty) {
      final pf = picked.files.first;
      if (pf.bytes != null) {
        final bytesCopy = Uint8List.fromList(pf.bytes!);
        setState(() { _pickedFile = pf; _fileBytes = bytesCopy; _fileName = pf.name; _step = 0; _tabReview = null; _result = null; _error = false; });
      }
    }
  }

  // ═══════════════════════════════════════
  //  الخطوة 2: مراجعة التبويب
  // ═══════════════════════════════════════
  Future<void> _reviewTabs() async {
    if (_pickedFile == null || _fileBytes == null) return;
    setState(() { _loading = true; _error = false; });
    try {
      final uri = Uri.parse('$_api/analyze?industry=retail');
      final req = http.MultipartRequest('POST', uri);
      req.files.add(http.MultipartFile.fromBytes('file', _fileBytes!, filename: _fileName));
      final streamed = await req.send().timeout(const Duration(seconds: 180));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        if (data['success'] == true) {
          final inv = data['meta']?['inventory_system'] ?? 'unknown';
          setState(() { _tabReview = data; _step = 1; _loading = false;
            if (inv == 'periodic') _inventorySystem = 'periodic';
            else if (inv == 'perpetual') _inventorySystem = 'perpetual';
          });
          return;
        }
      }
      throw Exception('فشل في مراجعة التبويب');
    } catch (e) {
      setState(() { _error = true; _errorMsg = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  // ═══════════════════════════════════════
  //  الخطوة 4: التحليل الشامل
  // ═══════════════════════════════════════
  Future<void> _startFullAnalysis() async {
    if (_pickedFile == null || _fileBytes == null) return;
    setState(() { _step = 3; _loading = true; _progress = 0; _currentStage = 0; });
    try {
      _animateProgress(0, 0.2, 1000); setState(() => _currentStage = 0);
      var url = '$_api/analyze/full';
      final invText = _closingInvCtrl.text.trim().replaceAll(',', '').replaceAll(' ', '');
      final invClean = invText.contains('.') ? invText.split('.')[0] : invText;
      print('DEBUG invClean: [$invClean]');
      print('DEBUG fileBytes length: ${_fileBytes?.length ?? 0}');
      final uri = Uri.parse(url);
      final req = http.MultipartRequest('POST', uri);
      req.files.add(http.MultipartFile.fromBytes('file', _fileBytes!, filename: 'trial_balance.xlsx'));
      req.fields['industry'] = 'retail';
      req.fields['language'] = 'ar';
      if (invClean.isNotEmpty) req.fields['closing_inventory'] = invClean;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('inv: $invClean | bytes: ${_fileBytes?.length ?? 0}'), duration: const Duration(seconds: 5)));
      _animateProgress(0.2, 0.5, 2000); setState(() => _currentStage = 1);
      final streamed = await req.send().timeout(const Duration(seconds: 300));
      _animateProgress(0.5, 0.8, 1000); setState(() => _currentStage = 2);
      final resp = await http.Response.fromStream(streamed);
      final rawBody = utf8.decode(resp.bodyBytes);
      print('DEBUG status: ${resp.statusCode} size: ${resp.bodyBytes.length}');
      print('DEBUG RAW[0:300]: ${rawBody.substring(0, 300.clamp(0, rawBody.length))}');
      final cogsIdx = rawBody.indexOf('"cogs"');
      if (cogsIdx > 0) {
        print('DEBUG COGS_RAW: ${rawBody.substring(cogsIdx, (cogsIdx + 60).clamp(0, rawBody.length))}');
      } else {
        print('DEBUG: NO cogs FOUND in response!');
        // Search for income_statement
        final isIdx = rawBody.indexOf('income_statement');
        if (isIdx > 0) print('DEBUG IS_RAW: ${rawBody.substring(isIdx, (isIdx + 100).clamp(0, rawBody.length))}');
        else print('DEBUG: NO income_statement in response!');
      }
      _animateProgress(0.8, 0.95, 500); setState(() => _currentStage = 3);
      if (resp.statusCode == 200) {
        final data = json.decode(utf8.decode(resp.bodyBytes));
        if (data['success'] == true) {
          _animateProgress(0.95, 1.0, 300);
          setState(() { _result = data; _step = 4; _loading = false; _progress = 1.0; _currentStage = 4; });
          print('DEBUG COGS: ${data['income_statement']?['cogs']}');
          print('DEBUG METHOD: ${data['income_statement']?['cogs_method']}');
          print('DEBUG PURCHASES: ${data['income_statement']?['purchases']}');
          return;
        }
      }
      throw Exception('فشل التحليل: ${resp.statusCode}');
    } catch (e) {
      setState(() { _error = true; _errorMsg = e.toString().replaceAll('Exception: ', ''); _loading = false; _step = 2; });
    }
  }

  void _animateProgress(double from, double to, int ms) async {
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(Duration(milliseconds: ms ~/ 10));
      if (mounted) setState(() => _progress = from + (to - from) * (i / 10));
    }
  }

  // ═══════════════════════════════════════
  //  الواجهة الرئيسية
  // ═══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, centerTitle: true,
        title: const Text('تحليل ميزان المراجعة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700, color: AC.textPrimary)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: AC.gold), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // شريط الخطوات
          _stepIndicator(),
          const SizedBox(height: 16),

          // المحتوى حسب الخطوة
          if (_step == 0) _buildStep0Upload(),
          if (_step == 1) _buildStep1TabReview(),
          if (_step == 2) _buildStep2Questions(),
          if (_step == 3) _buildStep3Analyzing(),
          if (_step == 4 && _result != null) _buildStep4Results(),

          if (_error) ...[const SizedBox(height: 12), _errorCard()],
        ]),
      ),
    );
  }

  // ═══ شريط الخطوات ═══
  Widget _stepIndicator() {
    final steps = ['رفع الملف', 'مراجعة التبويب', 'إعدادات', 'التحليل', 'النتائج'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: List.generate(steps.length, (i) {
        final done = _step > i; final active = _step == i;
        final color = done ? AC.success : active ? AC.gold : AC.textHint;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 28, height: 28,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(done ? 0.2 : active ? 0.15 : 0.05), border: Border.all(color: color.withOpacity(0.5))),
            child: Center(child: done ? Icon(Icons.check, color: color, size: 16) : Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color))),
          ),
          const SizedBox(height: 4),
          Text(steps[i], style: TextStyle(fontSize: 9, color: color, fontFamily: 'Tajawal', fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]);
      })),
    );
  }

  // ═══ الخطوة 0: رفع الملف ═══
  Widget _buildStep0Upload() {
    return Column(children: [
      _uploadBox(),
      if (_pickedFile != null) ...[
        const SizedBox(height: 16),
        _GoldBtn(label: 'مراجعة التبويب المحاسبي', onTap: _reviewTabs, isLoading: _loading),
      ],
    ]);
  }

  Widget _uploadBox() {
    return GestureDetector(onTap: _pickFile,
      child: Container(width: double.infinity, height: 140,
        decoration: BoxDecoration(color: _pickedFile != null ? AC.gold.withOpacity(0.05) : AC.navy3, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _pickedFile != null ? AC.gold.withOpacity(0.4) : AC.border, width: 1.5)),
        child: _pickedFile != null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.description_rounded, color: AC.gold, size: 40),
              const SizedBox(height: 8),
              Text(_fileName, style: const TextStyle(color: AC.textPrimary, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
              const SizedBox(height: 4),
              const Text('اضغط لتغيير الملف', style: TextStyle(color: AC.gold, fontSize: 11, fontFamily: 'Tajawal')),
            ])
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 52, height: 52, decoration: BoxDecoration(color: AC.gold.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.cloud_upload_outlined, color: AC.gold, size: 26)),
              const SizedBox(height: 10),
              const Text('اضغط لرفع ميزان المراجعة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Tajawal', color: AC.textPrimary)),
              const SizedBox(height: 4),
              const Text('Excel فقط (.xlsx, .xls)', style: TextStyle(color: AC.textSecondary, fontSize: 12, fontFamily: 'Tajawal')),
            ]),
      ),
    );
  }

  // ═══ الخطوة 1: مراجعة التبويب ═══
  Widget _buildStep1TabReview() {
    final tr = _tabReview?['tab_review'] ?? {};
    final score = (tr['consistency_score'] ?? 0).toDouble();
    final mismatches = (tr['mismatches'] as List?) ?? [];
    final ifrs = (tr['ifrs_notes'] as List?) ?? [];
    final socpa = (tr['socpa_notes'] as List?) ?? [];
    final invSystem = tr['inventory_system'] ?? 'unknown';
    final scoreColor = score >= 90 ? AC.success : score >= 70 ? AC.gold : AC.warning;

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // Score card
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16), border: Border.all(color: scoreColor.withOpacity(0.4), width: 1.5)),
        child: Row(children: [
          SizedBox(width: 70, height: 70, child: CustomPaint(painter: _RingPainter(score / 100, scoreColor),
            child: Center(child: Text('${score.toInt()}', style: TextStyle(color: scoreColor, fontSize: 18, fontWeight: FontWeight.w900))))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('درجة اتساق التبويب', style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
            Text('${score.toStringAsFixed(1)}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: scoreColor, fontFamily: 'Tajawal')),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AC.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(invSystem == 'periodic' ? 'جرد دوري' : invSystem == 'perpetual' ? 'جرد مستمر' : 'غير محدد',
                style: const TextStyle(fontSize: 10, color: AC.cyan, fontFamily: 'Tajawal'))),
          ])),
        ]),
      ),
      const SizedBox(height: 12),

      // Mismatches
      if (mismatches.isNotEmpty) ...[
        _sectionTitle('أخطاء التبويب (${mismatches.length})'),
        const SizedBox(height: 6),
        ...mismatches.take(10).map((m) => _mismatchItem(m)),
      ],

      // IFRS
      if (ifrs.isNotEmpty) ...[
        const SizedBox(height: 12),
        _sectionTitle('ملاحظات IFRS (${ifrs.length})'),
        const SizedBox(height: 6),
        ...ifrs.map((n) => _noteItem('${n['standard']}: ${n['issue']}', n['severity'] == 'WARNING' ? AC.warning : AC.textSecondary, n['recommendation'] ?? '')),
      ],

      // SOCPA
      if (socpa.isNotEmpty) ...[
        const SizedBox(height: 12),
        _sectionTitle('ملاحظات SOCPA / الأنظمة السعودية (${socpa.length})'),
        const SizedBox(height: 6),
        ...socpa.map((n) => _noteItem('${n['standard']}: ${n['issue']}', n['severity'] == 'WARNING' ? AC.warning : AC.textSecondary, n['recommendation'] ?? '')),
      ],

      const SizedBox(height: 20),

      // اختيار
      Row(children: [
        Expanded(child: GestureDetector(onTap: () => setState(() { _step = 0; _tabReview = null; }),
          child: Container(height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.gold.withOpacity(0.5))),
            child: const Center(child: Text('إعادة رفع الملف', style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal')))))),
        const SizedBox(width: 12),
        Expanded(child: _GoldBtn(label: 'الاستمرار بالتحليل', onTap: () => setState(() => _step = 2))),
      ]),
    ]);
  }

  Widget _mismatchItem(Map<String, dynamic> m) {
    final isErr = m['severity'] == 'error';
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: (isErr ? AC.danger : AC.warning).withOpacity(0.04), borderRadius: BorderRadius.circular(8),
          border: Border.all(color: (isErr ? AC.danger : AC.warning).withOpacity(0.15))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(m['issue_ar'] ?? m['account'] ?? '', textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 11, color: isErr ? AC.danger : AC.warning, fontFamily: 'Tajawal'))),
          const SizedBox(width: 6),
          Icon(isErr ? Icons.error_rounded : Icons.warning_amber_rounded, color: isErr ? AC.danger : AC.warning, size: 14),
        ]),
      ),
    );
  }

  Widget _noteItem(String text, Color color, String recommendation) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(text, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 11, color: color, fontFamily: 'Tajawal')),
          if (recommendation.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(recommendation, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
          ],
        ]),
      ),
    );
  }

  // ═══ الخطوة 2: أسئلة ما قبل التحليل ═══
  Widget _buildStep2Questions() {
    final detectedSystem = _tabReview?['meta']?['inventory_system'] ?? 'unknown';
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      const Text('إعدادات التحليل', textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
      const SizedBox(height: 16),

      // Q1: نظام الجرد
      _questionCard(
        icon: Icons.inventory_2_rounded, color: AC.cyan,
        title: 'نظام الجرد المعتمد',
        subtitle: detectedSystem != 'unknown' ? 'تم اكتشاف: ${detectedSystem == "periodic" ? "جرد دوري" : "جرد مستمر"}' : null,
        child: Row(children: [
          Expanded(child: _choiceBtn('جرد مستمر', _inventorySystem == 'perpetual', () => setState(() => _inventorySystem = 'perpetual'))),
          const SizedBox(width: 10),
          Expanded(child: _choiceBtn('جرد دوري', _inventorySystem == 'periodic', () => setState(() => _inventorySystem = 'periodic'))),
        ]),
      ),
      const SizedBox(height: 12),

      // Q2: إقفال الجرد (فقط للجرد الدوري)
      if (_inventorySystem == 'periodic') ...[
        _questionCard(
          icon: Icons.checklist_rounded, color: AC.gold,
          title: 'هل تم إقفال نتيجة الجرد الدوري في الميزان المرفوع؟',
          child: Row(children: [
            Expanded(child: _choiceBtn('لا', !_inventoryClosed, () => setState(() => _inventoryClosed = false))),
            const SizedBox(width: 10),
            Expanded(child: _choiceBtn('نعم', _inventoryClosed, () => setState(() => _inventoryClosed = true))),
          ]),
        ),
        const SizedBox(height: 12),

        // Q2b: مخزون آخر المدة (إذا لم يُقفل)
        if (!_inventoryClosed)
          _questionCard(
            icon: Icons.edit_note_rounded, color: AC.warning,
            title: 'قيمة مخزون آخر المدة (من الجرد الفعلي)',
            child: TextField(
              controller: _closingInvCtrl, keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr, textAlign: TextAlign.left,
              style: const TextStyle(color: AC.textPrimary, fontSize: 16, fontFamily: 'Tajawal'),
              decoration: InputDecoration(
                hintText: 'مثال: 11373005', hintStyle: TextStyle(color: AC.textHint.withOpacity(0.4)),
                prefixText: 'SAR  ', prefixStyle: const TextStyle(color: AC.textSecondary, fontSize: 12),
                filled: true, fillColor: AC.navy4,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AC.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AC.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AC.cyan)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        const SizedBox(height: 12),
      ],

      // Q3: إقفال الحسابات
      _questionCard(
        icon: Icons.lock_clock_rounded, color: AC.success,
        title: 'هل تم إقفال الحسابات نهاية الفترة؟',
        child: Row(children: [
          Expanded(child: _choiceBtn('لا', !_accountsClosed, () => setState(() => _accountsClosed = false))),
          const SizedBox(width: 10),
          Expanded(child: _choiceBtn('نعم', _accountsClosed, () => setState(() => _accountsClosed = true))),
        ]),
      ),
      const SizedBox(height: 20),

      // ملاحظة
      if (!_accountsClosed)
        Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AC.warning.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: AC.warning.withOpacity(0.2))),
          child: const Text('ملاحظة: عدم إقفال الحسابات قد يؤثر على دقة القوائم المالية. سيتم الإشارة لذلك في التقرير.',
            textDirection: TextDirection.rtl, style: TextStyle(fontSize: 11, color: AC.warning, fontFamily: 'Tajawal'))),

      _GoldBtn(label: 'بدء التحليل الشامل', onTap: _inventorySystem.isEmpty ? null : _startFullAnalysis,
        isLoading: _loading),
    ]);
  }

  Widget _questionCard({required IconData icon, required Color color, required String title, String? subtitle, required Widget child}) {
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Expanded(child: Text(title, textDirection: TextDirection.rtl,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal'))),
          const SizedBox(width: 8),
          Icon(icon, color: color, size: 20),
        ]),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
        ],
        const SizedBox(height: 10),
        child,
      ]),
    );
  }

  Widget _choiceBtn(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(onTap: onTap,
      child: Container(height: 42,
        decoration: BoxDecoration(
          color: selected ? AC.gold.withOpacity(0.1) : AC.navy4,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AC.gold : AC.border, width: selected ? 1.5 : 1)),
        child: Center(child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? AC.gold : AC.textSecondary, fontFamily: 'Tajawal'))),
      ),
    );
  }

  // ═══ الخطوة 3: التحليل ═══
  Widget _buildStep3Analyzing() {
    return Column(children: [
      const SizedBox(height: 20),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: _progress, minHeight: 8, backgroundColor: AC.navy3, valueColor: const AlwaysStoppedAnimation<Color>(AC.gold))),
      const SizedBox(height: 8),
      Text('${(_progress * 100).toInt()}%', style: const TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      ...List.generate(4, (i) {
        final done = _currentStage > i; final active = _currentStage == i;
        return Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: active ? AC.gold.withOpacity(0.06) : AC.navy3, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: done ? AC.success.withOpacity(0.3) : active ? AC.gold.withOpacity(0.4) : AC.border)),
            child: Row(children: [
              if (done) const Icon(Icons.check_circle_rounded, color: AC.success, size: 20)
              else if (active) AnimatedBuilder(animation: _pulseCtrl, builder: (c, _) => Icon(Icons.sync_rounded, color: AC.gold.withOpacity(0.5 + _pulseCtrl.value * 0.5), size: 20))
              else Icon(Icons.radio_button_unchecked, color: AC.textHint, size: 20),
              const Spacer(),
              Text(done ? _analyzeStages[i].replaceAll('...', ' ✓') : _analyzeStages[i], textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 13, fontFamily: 'Tajawal', fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: done ? AC.success : active ? AC.gold : AC.textHint)),
            ])),
        );
      }),
    ]);
  }

  // ═══ الخطوة 4: النتائج ═══
  Widget _buildStep4Results() {
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
    final vs = r['validation_summary'] ?? {};
    final meta = r['meta'] ?? {};
    final brain = r['knowledge_brain'] ?? {};
    final confPct = ((confidence['overall'] ?? 0) * 100).toDouble();
    final confLabel = confidence['label'] ?? '';

    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      // ✅ نجاح
      Container(width: double.infinity, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AC.success.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.success.withOpacity(0.3))),
        child: Column(children: [
          const Icon(Icons.check_circle_rounded, color: AC.success, size: 44),
          const SizedBox(height: 8),
          const Text('اكتمل التحليل بنجاح!', style: TextStyle(color: AC.success, fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
          Text(_fileName, style: const TextStyle(color: AC.textSecondary, fontSize: 12, fontFamily: 'Tajawal')),
        ])),
      const SizedBox(height: 16),

      _confidenceCard(confPct, confLabel),
      const SizedBox(height: 16),

      _metaSummary(meta, vs, confidence),
      const SizedBox(height: 16),

      // العقل المعرفي
      if (brain.isNotEmpty && (brain['rules_triggered'] ?? 0) > 0) ...[
        _sectionTitle('العقل المعرفي'), const SizedBox(height: 8), _brainCard(brain), const SizedBox(height: 16),
      ],

      _sectionTitle('قائمة الدخل'), const SizedBox(height: 8), _incomeCard(income), const SizedBox(height: 16),
      _sectionTitle('الميزانية العمومية'), const SizedBox(height: 8), _balanceCard(balance), const SizedBox(height: 16),
      _sectionTitle('النسب المالية'), const SizedBox(height: 8), _ratiosCard(prof, liq, lev, eff), const SizedBox(height: 16),

      if (narrative.isNotEmpty && narrative['executive_summary'] != null) ...[
        _sectionTitle('تحليل الذكاء الاصطناعي'), const SizedBox(height: 8), _aiCard(narrative), const SizedBox(height: 16),
      ],

      _GoldBtn(label: 'تحليل ملف آخر', onTap: () => setState(() { _step = 0; _result = null; _tabReview = null; _pickedFile = null; _fileBytes = null; _fileName = ''; _closingInvCtrl.clear(); _inventorySystem = ''; })),
    ]);
  }


  // ═══════════════════════════════════════════════════════════════
  //  Helper Widgets
  // ═══════════════════════════════════════════════════════════════

  Widget _errorCard() => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.danger.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.danger.withOpacity(0.3))),
    child: Row(children: [
      Expanded(child: Text(_errorMsg, textDirection: TextDirection.rtl, maxLines: 3, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: AC.danger, fontFamily: 'Tajawal'))),
      const SizedBox(width: 8),
      const Icon(Icons.error_outline, color: AC.danger, size: 20),
    ]));

  Widget _sectionTitle(String t) => Align(alignment: Alignment.centerRight,
    child: Text(t, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')));

  Widget _confidenceCard(double pct, String label) {
    final c = pct >= 90 ? AC.success : pct >= 75 ? AC.gold : AC.warning;
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.withOpacity(0.4))),
      child: Row(children: [
        SizedBox(width: 70, height: 70, child: CustomPaint(painter: _RingPainter(pct / 100, c),
          child: Center(child: Text('${pct.toInt()}', style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w900))))),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('مؤشر الثقة النهائي', style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
          Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: c)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(label, style: TextStyle(fontSize: 11, color: c, fontFamily: 'Tajawal'))),
        ]),
      ]));
  }

  Widget _metaSummary(Map<String, dynamic> meta, Map<String, dynamic> vs, Map<String, dynamic> conf) {
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(meta['company_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _metaItem('${meta['total_accounts'] ?? 0}', 'الحسابات'),
          _metaItem('${vs['errors'] ?? 0}', 'أخطاء'),
          _metaItem('${vs['warnings'] ?? 0}', 'تحذيرات'),
          _metaItem(vs['can_approve'] == true ? '✓' : '✗', 'يمكن الاعتماد'),
        ]),
      ]));
  }

  Widget _metaItem(String val, String label) => Column(children: [
    Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: val == '✗' ? AC.danger : AC.textPrimary)),
    Text(label, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
  ]);

  // ─── العقل المعرفي ───
  Widget _brainCard(Map<String, dynamic> brain) {
    final findings = (brain['brain_findings'] as List?) ?? [];
    final compliance = (brain['compliance_notes'] as List?) ?? [];
    final recs = (brain['brain_recommendations'] as List?) ?? [];
    final rulesEval = brain['rules_evaluated'] ?? 0;
    final rulesTrig = brain['rules_triggered'] ?? 0;

    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.cyan.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AC.cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('$rulesTrig / $rulesEval قاعدة', style: const TextStyle(fontSize: 10, color: AC.cyan, fontFamily: 'Tajawal'))),
          Row(children: [
            const Text('العقل المعرفي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.cyan, fontFamily: 'Tajawal')),
            const SizedBox(width: 6), const Icon(Icons.psychology_rounded, color: AC.cyan, size: 18),
          ]),
        ]),
        const SizedBox(height: 10),
        ...findings.where((f) => f['severity'] == 'critical').map((f) => _brainItem(f['message'] ?? '', AC.danger, Icons.error_rounded, reference: f['reference'], authority: f['authority'])),
        ...findings.where((f) => f['severity'] == 'warning').map((f) => _brainItem(f['message'] ?? '', AC.warning, Icons.warning_amber_rounded, reference: f['reference'], authority: f['authority'])),
        if (compliance.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('ملاحظات الامتثال', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
            const SizedBox(width: 4), const Icon(Icons.gavel_rounded, color: AC.gold, size: 14),
          ]),
          const SizedBox(height: 4),
          ...compliance.map((c) => _brainItem(c['message'] ?? '', c['severity'] == 'warning' ? AC.warning : AC.gold, c['severity'] == 'warning' ? Icons.warning_amber_rounded : Icons.info_outline_rounded, reference: c['reference'], authority: c['authority'])),
        ],
        if (recs.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Text('توصيات مبنية على الأنظمة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AC.success, fontFamily: 'Tajawal')),
            const SizedBox(width: 4), const Icon(Icons.tips_and_updates_rounded, color: AC.success, size: 14),
          ]),
          const SizedBox(height: 4),
          ...recs.map((r) => _brainItem(r['message'] ?? '', AC.success, Icons.lightbulb_outline_rounded, reference: r['reference'], authority: r['authority'])),
        ],
        ...findings.where((f) => f['severity'] == 'info').map((f) => _brainItem(f['message'] ?? '', AC.textSecondary, Icons.info_outline_rounded, reference: f['reference'], authority: f['authority'])),
      ]));
  }

  Widget _brainItem(String msg, Color c, IconData icon, {String? reference, String? authority}) {
    return Padding(padding: const EdgeInsets.only(bottom: 6),
      child: Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.withOpacity(0.04), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withOpacity(0.15))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(msg, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 11, color: c, fontFamily: 'Tajawal', height: 1.4))),
            const SizedBox(width: 6), Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, color: c, size: 14)),
          ]),
          if (reference != null && reference.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (authority != null && authority.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1), margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(color: c.withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                child: Text(authority, style: TextStyle(fontSize: 8, color: c.withOpacity(0.7), fontFamily: 'Tajawal'))),
              Flexible(child: Text(reference, textDirection: TextDirection.rtl, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: c.withOpacity(0.5), fontFamily: 'Tajawal'))),
              Icon(Icons.menu_book_rounded, color: c.withOpacity(0.3), size: 9),
            ]),
          ],
        ])));
  }

  // ─── قائمة الدخل ───
  Widget _incomeCard(Map<String, dynamic> inc) {
    return _dataCard([
      _row('الإيرادات', inc['gross_revenue'], bold: false),
      _row('إيرادات خدمات', inc['service_revenue'], bold: false),
      _row('مردودات المبيعات', inc['sales_returns'], bold: false, negative: true),
      _rowDivider(),
      _row('صافي الإيرادات', inc['net_revenue'], bold: true, color: AC.gold),
      const SizedBox(height: 6),
      _row('تكلفة البضاعة المباعة', inc['cogs'], bold: false, negative: true),
      _rowDivider(),
      _row('مجمل الربح', inc['gross_profit'], bold: true, color: AC.success),
      const SizedBox(height: 6),
      _row('م. إدارية وعمومية', inc['admin_expenses'], bold: false),
      _row('م. بيع وتسويق', inc['selling_expenses'], bold: false),
      _row('الربح التشغيلي', inc['operating_profit'], bold: true),
      _row('EBITDA', inc['ebitda'], bold: false),
      const SizedBox(height: 6),
      _row('إيرادات أخرى', inc['other_revenue'], bold: false),
      _row('مصروفات أخرى', inc['other_expenses'], bold: false),
      _row('تكاليف تمويل', inc['finance_cost'], bold: false),
      _row('زكاة وضرائب', inc['zakat_tax'], bold: false),
      _rowDivider(),
      _row('صافي الربح', inc['net_profit'], bold: true, color: AC.gold),
    ]);
  }

  // ─── الميزانية ───
  Widget _balanceCard(Map<String, dynamic> bs) {
    final ca = bs['current_assets'] ?? {};
    final nca = bs['non_current_assets'] ?? {};
    final cl = bs['current_liabilities'] ?? {};
    final ncl = bs['non_current_liabilities'] ?? {};
    final eq = bs['equity'] ?? {};
    return _dataCard([
      _row('الأصول المتداولة', ca['total'], bold: true, color: AC.gold),
      _row('الأصول غير المتداولة', nca['total'], bold: false),
      _rowDivider(),
      _row('إجمالي الأصول', bs['total_assets'], bold: true, color: AC.gold),
      const SizedBox(height: 6),
      _row('الالتزامات المتداولة', cl['total'], bold: false),
      _row('الالتزامات غير المتداولة', ncl['total'], bold: false),
      _row('إجمالي الالتزامات', (cl['total'] ?? 0) + (ncl['total'] ?? 0), bold: true),
      const SizedBox(height: 6),
      _row('حقوق الملكية', eq['total'], bold: true, color: AC.gold),
      _rowDivider(),
      _row('فحص التوازن', bs['balance_check'], bold: false, color: bs['is_balanced'] == true ? AC.success : AC.danger),
      _row('الميزانية متوازنة', null, bold: false, suffix: bs['is_balanced'] == true ? 'نعم ✓' : 'لا ✗',
        color: bs['is_balanced'] == true ? AC.success : AC.danger),
    ]);
  }

  // ─── النسب ───
  Widget _ratiosCard(Map<String, dynamic> prof, Map<String, dynamic> liq, Map<String, dynamic> lev, Map<String, dynamic> eff) {
    return _dataCard([
      _ratioBar('هامش مجمل الربح', prof['gross_margin_pct'], '%'),
      _ratioBar('هامش صافي الربح', prof['net_margin_pct'], '%'),
      _ratioBar('هامش EBITDA', prof['ebitda_margin_pct'], '%'),
      _ratioBar('نسبة التداول', liq['current_ratio'], ''),
      _ratioBar('النسبة السريعة', liq['quick_ratio'], ''),
      _ratioBar('الدين/الأصول', lev['debt_to_assets_pct'], '%'),
      _ratioBar('ROA', prof['roa_pct'], '%'),
      _ratioBar('ROE', prof['roe_pct'], '%'),
      _ratioBar('دوران الأصول', eff['asset_turnover'], ''),
      _ratioBar('DSO (أيام التحصيل)', eff['dso'], ''),
      _ratioBar('أيام المخزون', eff['dio'], ''),
    ]);
  }

  // ─── تحليل AI ───
  Widget _aiCard(Map<String, dynamic> ai) {
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Align(alignment: Alignment.centerLeft,
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AC.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(ai['platform'] ?? 'ai', style: const TextStyle(fontSize: 9, color: AC.success)))),
        const SizedBox(height: 8),
        _aiSub('الملخص التنفيذي', Icons.summarize_rounded, AC.gold),
        const SizedBox(height: 4),
        Text(ai['executive_summary'] ?? '', textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5)),
        if (ai['strengths'] != null) ...[
          const SizedBox(height: 10), _aiSub('نقاط القوة', Icons.trending_up_rounded, AC.success), const SizedBox(height: 4),
          ...((ai['strengths'] as List).map((s) => _bullet(s.toString(), AC.success))),
        ],
        if (ai['weaknesses'] != null) ...[
          const SizedBox(height: 10), _aiSub('نقاط الضعف', Icons.trending_down_rounded, AC.warning), const SizedBox(height: 4),
          ...((ai['weaknesses'] as List).map((w) => _bullet(w.toString(), AC.warning))),
        ],
        if (ai['risks'] != null) ...[
          const SizedBox(height: 10), _aiSub('المخاطر', Icons.shield_outlined, AC.danger), const SizedBox(height: 4),
          ...((ai['risks'] as List).map((r) => _bullet(r is Map ? '[${r['severity']}] ${r['risk']}' : r.toString(), AC.danger))),
        ],
        if (ai['recommendations'] != null) ...[
          const SizedBox(height: 10), _aiSub('التوصيات', Icons.lightbulb_outline_rounded, AC.cyan), const SizedBox(height: 4),
          ...((ai['recommendations'] as List).map((r) => _bullet(r is Map ? '[${r['priority']}] ${r['action']} — ${r['timeline']}' : r.toString(), AC.cyan))),
        ],
        if (ai['management_letter'] != null) ...[
          const SizedBox(height: 10), _aiSub('رسالة الإدارة', Icons.mail_outline_rounded, AC.gold), const SizedBox(height: 4),
          Text(ai['management_letter'], textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5)),
        ],
      ]));
  }

  Widget _aiSub(String t, IconData i, Color c) => Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c, fontFamily: 'Tajawal')),
    const SizedBox(width: 6), Icon(i, color: c, size: 16),
  ]);

  Widget _bullet(String t, Color c) => Padding(padding: const EdgeInsets.only(bottom: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Text(t, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 11, color: c.withOpacity(0.8), fontFamily: 'Tajawal', height: 1.4))),
      Padding(padding: const EdgeInsets.only(top: 4, left: 6), child: Icon(Icons.circle, color: c, size: 5)),
    ]));

  Widget _dataCard(List<Widget> c) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
    child: Column(children: c));

  Widget _row(String label, dynamic value, {bool bold = false, bool negative = false, Color? color, String? suffix}) {
    String display = suffix ?? '';
    if (suffix == null && value != null) {
      double v = 0;
      if (value is num) v = value.toDouble();
      else if (value is String) v = double.tryParse(value) ?? 0;
      if (v.abs() >= 1e6) display = '${(v / 1e6).toStringAsFixed(2)}M';
      else if (v.abs() >= 1e3) display = '${(v / 1e3).toStringAsFixed(1)}K';
      else display = v.toStringAsFixed(0);
    }
    final c = color ?? (negative ? AC.danger : AC.textPrimary);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(display, style: TextStyle(fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w400, color: c, fontFamily: 'Tajawal')),
        const Spacer(),
        Text(label, textDirection: TextDirection.rtl, style: TextStyle(fontSize: bold ? 14 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: bold ? c : AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }

  Widget _rowDivider() => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Divider(color: AC.border.withOpacity(0.3), height: 1));

  Widget _ratioBar(String label, dynamic value, String suffix) {
    if (value == null) return const SizedBox.shrink();
    double v = 0;
    if (value is num) v = value.toDouble();
    else if (value is String) v = double.tryParse(value) ?? 0;
    String display = suffix == '%' ? '${v.toStringAsFixed(2)}%' : v.toStringAsFixed(2);
    double barPct = (v.abs() / 100).clamp(0, 1);
    if (suffix != '%') barPct = (v.abs() / 3).clamp(0, 1);
    final c = AC.gold;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        Row(children: [
          Text(display, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
          const Spacer(),
          Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
        ]),
        const SizedBox(height: 3),
        ClipRRect(borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(value: barPct, minHeight: 4, backgroundColor: AC.navy4, valueColor: AlwaysStoppedAnimation<Color>(c))),
      ]));
  }
}

// ═══ Ring Painter ═══
class _RingPainter extends CustomPainter {
  final double pct; final Color color;
  _RingPainter(this.pct, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = color.withOpacity(0.1)..style = PaintingStyle.stroke..strokeWidth = 6);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -1.5708, pct * 6.2832, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

// ═══ Gold Button ═══
class _GoldBtn extends StatelessWidget {
  final String label; final VoidCallback? onTap; final bool isLoading;
  const _GoldBtn({required this.label, this.onTap, this.isLoading = false});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: isLoading ? null : onTap,
    child: Container(width: double.infinity, height: 50,
      decoration: BoxDecoration(
        gradient: onTap != null ? const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFF5D670)]) : null,
        color: onTap == null ? AC.navy4 : null,
        borderRadius: BorderRadius.circular(14)),
      child: Center(child: isLoading
        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
        : Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Tajawal',
            color: onTap != null ? Colors.black : AC.textHint)))));
}
