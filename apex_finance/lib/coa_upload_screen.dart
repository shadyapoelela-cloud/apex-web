import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'api_service.dart';
import 'core/theme.dart';

// ─────────────────────────────────────────────
// COA Upload Screen — World-Class Redesign v4.3
// ─────────────────────────────────────────────

class CoaUploadScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  const CoaUploadScreen({super.key, required this.clientId, required this.clientName});
  @override State<CoaUploadScreen> createState() => _CoaUploadScreenState();
}

class _CoaUploadScreenState extends State<CoaUploadScreen> with TickerProviderStateMixin {
  // ── State ──
  bool _fileSelected = false;
  bool _analyzing = false;
  String _fileName = '';
  String _fileSize = '';
  String _errorMsg = '';
  FilePickerResult? _picked;
  int _pipelineStep = 0; // 0=idle, 1-7=running, 8=done

  late AnimationController _shimmerCtrl;
  late AnimationController _pipelineCtrl;
  late Animation<double> _shimmerAnim;

  // ── Colors (from AC theme) ──
  static Color get _bg => AC.navy;
  static Color get _surface1 => AC.navy2;
  static Color get _surface2 => AC.navy3;
  static Color get _gold => AC.gold;
  static Color get _textPri => AC.tp;
  static Color get _textSec => AC.ts;
  static Color get _border => AC.bdr;
  static Color get _positive => AC.ok;
  static Color get _danger => AC.err;
  // ignore: unused_field
  static Color get _warning => AC.warn;
  static Color get _cyan => AC.cyan;
  static Color get _info => AC.info;
  static Color get _purple => AC.purple;

  static const _pipelineSteps = [
    'قراءة الملف وتحديد النمط',
    'تصنيف الحسابات — 6 طبقات',
    'فحص الأخطاء والتحقق المتبادل',
    'تحديد القطاع والشبكة المعرفية',
    'المحاكاة المالية والامتثال',
    'كشف الاحتيال والحوكمة',
    'إعداد التقرير النهائي',
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..repeat();
    _shimmerAnim = Tween<double>(begin: 0, end: 1).animate(_shimmerCtrl);
    _pipelineCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _pipelineCtrl.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv']);
    if (result != null && result.files.isNotEmpty) {
      final f = result.files.first;
      setState(() {
        _fileSelected = true;
        _fileName = f.name;
        _fileSize = _formatBytes(f.size);
        _picked = result;
        _errorMsg = '';
      });
    }
  }

  void _clearFile() => setState(() {
    _fileSelected = false;
    _fileName = '';
    _fileSize = '';
    _picked = null;
  });

  Future<void> _beginAnalysis() async {
    if (_picked == null || _analyzing) return;
    setState(() { _analyzing = true; _errorMsg = ''; _pipelineStep = 1; });

    try {
      final result = await ApiService.uploadCoa(
        clientId: widget.clientId,
        bytes: _picked!.files.first.bytes!,
        fileName: _picked!.files.first.name,
      );

      // Animate pipeline steps
      for (int i = 1; i <= 7; i++) {
        if (!mounted) return;
        setState(() => _pipelineStep = i);
        await Future.delayed(Duration(milliseconds: 200 + (math.Random().nextInt(300))));
      }

      if (!mounted) return;

      if (result.success) {
        final data = result.data as Map<String, dynamic>;
        setState(() => _pipelineStep = 8);
        await Future.delayed(const Duration(milliseconds: 400));
        if (!mounted) return;
        context.push('/coa/mapping', extra: {
          'uploadData': data,
          'clientId': widget.clientId,
          'clientName': widget.clientName,
          'pickedFile': _picked!.files.first,
        });
      } else {
        setState(() { _errorMsg = result.error ?? 'فشل الرفع'; _analyzing = false; _pipelineStep = 0; });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _errorMsg = 'خطأ: $e'; _analyzing = false; _pipelineStep = 0; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _analyzing ? _buildLoadingPhase() : _buildUploadPhase(),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _surface1,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, size: 20),
      color: _textSec,
      onPressed: () => context.pop(),
    ),
    title: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('تحليل شجرة الحسابات', style: TextStyle(fontFamily: 'Tajawal', color: _textPri, fontSize: 15, fontWeight: FontWeight.w700)),
      Text(widget.clientName, style: TextStyle(fontFamily: 'Tajawal', color: _textSec, fontSize: 12)),
    ]),
    actions: [
      Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withValues(alpha: 0.15)),
        ),
        child: Text('v4.3', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _gold)),
      ),
    ],
    bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: _border, height: 1)),
  );

  // ═══════════════════════════════════════════
  // UPLOAD PHASE
  // ═══════════════════════════════════════════
  Widget _buildUploadPhase() => Column(children: [
    Expanded(child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        const SizedBox(height: 12),
        _buildStepper(0),
        const SizedBox(height: 16),
        _buildUploadZone(),
        if (_fileSelected) _buildFileCard(),
        const SizedBox(height: 20),
        _buildCapabilitiesSection(),
        const SizedBox(height: 24),
        if (_errorMsg.isNotEmpty) _buildErrorBanner(),
        const SizedBox(height: 80),
      ]),
    )),
    _buildCTA(),
  ]);

  // ── Stepper (3-step) ──
  Widget _buildStepper(int current) {
    final steps = ['رفع وتحليل', 'المراجعة', 'الاعتماد'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = i ~/ 2 < current;
          return Expanded(child: Container(
            height: 2, margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(1),
              gradient: done ? LinearGradient(colors: [_positive, _cyan]) : null,
              color: done ? null : _border,
            ),
          ));
        }
        final idx = i ~/ 2;
        final done = idx < current;
        final active = idx == current;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? _positive.withValues(alpha: 0.12) : active ? _gold.withValues(alpha: 0.12) : _surface1,
              border: Border.all(color: done ? _positive : active ? _gold : _border, width: 2),
            ),
            child: Center(child: done
              ? Icon(Icons.check_rounded, size: 14, color: _positive)
              : Text('${idx + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? _gold : _textSec))),
          ),
          const SizedBox(height: 5),
          Text(steps[idx], style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: done ? _positive : active ? _gold : _textSec, fontFamily: 'Tajawal')),
        ]);
      })),
    );
  }

  // ── Upload Zone ──
  Widget _buildUploadZone() {
    if (_fileSelected) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
          color: _surface1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AC.tp.withValues(alpha: 0.07), width: 2),
        ),
        child: Column(children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [_gold.withValues(alpha: 0.12), _gold.withValues(alpha: 0.05)],
              ),
              border: Border.all(color: _gold.withValues(alpha: 0.15)),
            ),
            child: Icon(Icons.cloud_upload_outlined, color: _gold, size: 32),
          ),
          const SizedBox(height: 16),
          Text('ارفع ملف شجرة الحسابات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPri, fontFamily: 'Tajawal')),
          const SizedBox(height: 4),
          Text('اسحب الملف هنا أو اضغط للاختيار', style: TextStyle(fontSize: 12, color: _textSec, fontFamily: 'Tajawal')),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _formatChip('.xlsx'), const SizedBox(width: 6),
            _formatChip('.xls'), const SizedBox(width: 6),
            _formatChip('.csv'), const SizedBox(width: 6),
            _formatChip('15MB'),
          ]),
        ]),
      ),
    );
  }

  Widget _formatChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: _surface2, borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _border),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _textSec)),
  );

  // ── File Card ──
  Widget _buildFileCard() => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _surface1,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _positive.withValues(alpha: 0.2)),
    ),
    child: Row(children: [
      GestureDetector(
        onTap: _clearFile,
        child: Container(
          width: 32, height: 32,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _border)),
          child: Icon(Icons.close_rounded, size: 14, color: _textSec),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(_fileName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textPri, fontFamily: 'Tajawal'), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text('$_fileSize — Excel Workbook', style: TextStyle(fontSize: 11, color: _textSec, fontFamily: 'Tajawal')),
      ])),
      const SizedBox(width: 12),
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: _positive.withValues(alpha: 0.1)),
        child: Icon(Icons.description_rounded, color: _positive, size: 24),
      ),
    ]),
  );

  // ── 7 Analysis Capabilities ──
  Widget _buildCapabilitiesSection() => Column(children: [
    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      Text('تحليل شامل بـ 7 محاور', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPri, fontFamily: 'Tajawal')),
      const SizedBox(width: 8),
      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _gold)),
    ]),
    const SizedBox(height: 12),
    GridView.count(
      crossAxisCount: 3, shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8, crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: [
        _capCard(Icons.auto_awesome_rounded, 'تصنيف ذكي', '6 طبقات', 'AI', _positive),
        _capCard(Icons.search_rounded, 'كشف الأخطاء', '62 قاعدة', '62', _danger),
        _capCard(Icons.domain_rounded, 'تحديد القطاع', '45 نموذج', '45', _cyan),
        _capCard(Icons.show_chart_rounded, 'محاكاة مالية', 'BS / IS / CF', 'SIM', _gold),
        _capCard(Icons.verified_rounded, 'الامتثال', 'ZATCA / IFRS', '8', _info),
        _capCard(Icons.lock_outline_rounded, 'كشف الاحتيال', '8 أنماط', 'FP', _purple),
      ],
    ),
  ]);

  Widget _capCard(IconData icon, String label, String sub, String tag, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    decoration: BoxDecoration(
      color: _surface1,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 28),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(fontSize: 10, color: _textSec, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
      Text(sub, style: TextStyle(fontSize: 9, color: _textSec, fontFamily: 'Tajawal'), textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
        child: Text(tag, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
      ),
    ]),
  );

  // ── Error Banner ──
  Widget _buildErrorBanner() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _danger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _danger.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      Icon(Icons.error_outline_rounded, color: _danger, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(_errorMsg, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, color: _danger, fontFamily: 'Tajawal'))),
    ]),
  );

  // ── CTA Button ──
  Widget _buildCTA() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _bg,
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_bg.withValues(alpha: 0), _bg],
        stops: const [0, 0.3],
      ),
    ),
    child: GestureDetector(
      onTap: _fileSelected ? _beginAnalysis : _pickFile,
      child: AnimatedBuilder(
        animation: _shimmerAnim,
        builder: (_, __) => Container(
          width: double.infinity, height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: _fileSelected
              ? LinearGradient(
                  begin: Alignment(-1 + 2 * _shimmerAnim.value, 0),
                  end: Alignment(1 + 2 * _shimmerAnim.value, 0),
                  colors: [_gold, _gold.withValues(alpha: 0.7), _gold],
                )
              : null,
            color: _fileSelected ? null : _surface1,
            border: _fileSelected ? null : Border.all(color: _border),
            boxShadow: _fileSelected ? [BoxShadow(color: _gold.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 4))] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(_fileSelected ? Icons.rocket_launch_rounded : Icons.upload_rounded,
              color: _fileSelected ? _bg : _textSec, size: 18),
            const SizedBox(width: 8),
            Text(_fileSelected ? 'رفع وتحليل شامل' : 'اختر ملف شجرة الحسابات',
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, fontFamily: 'Tajawal',
                color: _fileSelected ? _bg : _textSec,
              )),
          ]),
        ),
      ),
    ),
  );

  // ═══════════════════════════════════════════
  // LOADING / PIPELINE PHASE
  // ═══════════════════════════════════════════
  Widget _buildLoadingPhase() => Column(children: [
    const SizedBox(height: 12),
    _buildStepper(0),
    Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _buildOrbitLoader(),
        const SizedBox(height: 24),
        Text('جارٍ التحليل الشامل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPri, fontFamily: 'Tajawal')),
        const SizedBox(height: 4),
        Text('APEX COA Engine v4.3', style: TextStyle(fontSize: 12, color: _textSec)),
        const SizedBox(height: 24),
        _buildPipelineList(),
      ]),
    )),
  ]);

  Widget _buildOrbitLoader() {
    final pct = ((_pipelineStep / 7) * 100).round();
    return SizedBox(
      width: 96, height: 96,
      child: Stack(alignment: Alignment.center, children: [
        _spinRing(0, _gold, 1.4),
        _spinRing(10, _positive, 1.8, reverse: true),
        _spinRing(20, _cyan, 2.2),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _surface2),
          child: Center(child: Text('$pct%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _gold, fontFamily: 'Consolas'))),
        ),
      ]),
    );
  }

  Widget _spinRing(double inset, Color color, double seconds, {bool reverse = false}) {
    return Positioned.fill(
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: AnimatedBuilder(
          animation: _shimmerCtrl,
          builder: (_, __) => Transform.rotate(
            angle: (reverse ? -1 : 1) * _shimmerCtrl.value * 2 * math.pi,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.transparent, width: 3),
              ),
              child: CustomPaint(painter: _ArcPainter(color)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPipelineList() => Column(
    children: List.generate(_pipelineSteps.length, (i) {
      final stepNum = i + 1;
      final done = _pipelineStep > stepNum;
      final active = _pipelineStep == stepNum;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _border, width: i < 6 ? 1 : 0))),
        child: Row(children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: done ? _positive : active ? _gold : _border,
                width: 2,
              ),
              color: done ? _positive.withValues(alpha: 0.1) : null,
            ),
            child: Center(child: done
              ? Icon(Icons.check_rounded, size: 12, color: _positive)
              : Text('$stepNum', style: TextStyle(fontSize: 10, color: active ? _gold : _textSec, fontWeight: FontWeight.w700))),
          ),
          const Spacer(),
          Text(_pipelineSteps[i], style: TextStyle(
            fontSize: 12, fontFamily: 'Tajawal',
            color: done ? _textPri : active ? _textPri : _textSec,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          )),
        ]),
      );
    }),
  );
}

// ── Arc Painter for orbit loader ──
class _ArcPainter extends CustomPainter {
  final Color color;
  const _ArcPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(
      rect.deflate(1.5), -math.pi / 4, math.pi / 2, false,
      Paint()..color = color..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}
