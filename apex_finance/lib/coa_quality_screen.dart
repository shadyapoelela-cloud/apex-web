import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'shared_widgets.dart';
import 'coa_review_screen.dart';

class CoaQualityScreen extends StatefulWidget {
  final String uploadId, clientId, clientName;
  final Map<String,dynamic> assessData;
  const CoaQualityScreen({super.key, required this.uploadId, required this.clientId, required this.clientName, required this.assessData});
  @override State<CoaQualityScreen> createState() => _CoaQualityScreenState();
}

class _CoaQualityScreenState extends State<CoaQualityScreen> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _progress;
  static const _bg      = Color(0xFF050D1A);
  static const _surface = Color(0xFF080F1F);
  static const _gold    = Color(0xFFC9A84C);
  static const _success = Color(0xFF2ECC8A);
  static const _danger  = Color(0xFFE05050);
  static const _warning = Color(0xFFE8A838);
  static const _border  = Color(0x26C9A84C);
  static const _textPri = Color(0xFFF0EDE6);
  static const _textSec = Color(0xFF8A8880);

  double get _overall => ((widget.assessData['overall_score'] ?? 0.0) as num).toDouble();

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _progress = Tween<double>(begin: 0, end: _overall).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () => _anim.forward());
  }

  @override void dispose() { _anim.dispose(); super.dispose(); }

  Color _scoreColor(double v) { if (v >= 0.75) return _success; if (v >= 0.50) return _warning; return _danger; }

  @override
  Widget build(BuildContext context) {
    final readiness = (widget.assessData['reporting_readiness']?['readiness'] as Map? ?? {});
    final recs = (widget.assessData['recommendations'] as List? ?? []).cast<String>();
    final ambiguous = (widget.assessData['naming_clarity']?['ambiguous_accounts'] as List? ?? []).take(10).map((e) => e['account_name']?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    final dupSuspects = (widget.assessData['duplication_risk']?['duplicate_suspects'] as List? ?? []).take(8).map((e) => '${e['account_a']?['name'] ?? ''} ↔ ${e['account_b']?['name'] ?? ''}').where((s) => s != ' ↔ ').toList();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _surface,
        title: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('تقرير جودة شجرة الحسابات', style: TextStyle(fontFamily:'Tajawal', color:_textPri, fontSize:15, fontWeight:FontWeight.w700)),
          Text(widget.clientName, style: const TextStyle(fontFamily:'Tajawal', color:_textSec, fontSize:12)),
        ]),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color:_border, height:1))),
      body: Column(children: [
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: [
          StepIndicator(current: 2),
          const SizedBox(height: 16),
          // ── درجة كاملة ──
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF0D1829), borderRadius: BorderRadius.circular(18), border: Border.all(color: _gold.withOpacity(0.35))),
            child: Row(children: [
              AnimatedBuilder(animation: _progress, builder: (_, __) => SizedBox(width: 86, height: 86,
                child: CustomPaint(painter: _RingPainter(_progress.value, _scoreColor(_overall)),
                  child: Center(child: Text('${(_progress.value * 100).toInt()}', style: TextStyle(color: _scoreColor(_overall), fontSize:22, fontWeight:FontWeight.w900, fontFamily:'Tajawal')))))),
              const SizedBox(width:16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('درجة جودة شجرة الحسابات', textDirection: TextDirection.rtl, style: TextStyle(fontSize:11, color:Color(0xFF8A8880), fontFamily:'Tajawal')),
                const SizedBox(height:4),
                Text('${(_overall * 100).toInt()} / 100', style: TextStyle(fontSize:28, fontWeight:FontWeight.w900, color:_scoreColor(_overall), fontFamily:'Tajawal')),
                const SizedBox(height:6),
                Container(padding: const EdgeInsets.symmetric(horizontal:10, vertical:3),
                  decoration: BoxDecoration(color: _scoreColor(_overall).withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _scoreColor(_overall).withOpacity(0.3))),
                  child: Text(_overall >= 0.75 ? 'جودة مرتفعة — جاهز للتحليل' : _overall >= 0.50 ? 'جودة متوسطة — يُنصح بالمراجعة' : 'جودة منخفضة — مراجعة مطلوبة',
                    style: TextStyle(fontSize:11, color:_scoreColor(_overall), fontFamily:'Tajawal'))),
                const SizedBox(height:4),
                Text('${widget.assessData['total_accounts'] ?? 0} حساب', style: const TextStyle(fontSize:11, color:Color(0xFF8A8880), fontFamily:'Tajawal')),
              ])),
            ])),
          const SizedBox(height:14),
          // ── 5 بطاقات نقاط ──
          _buildScoreRow([
            ('completeness_score','الاكتمال',Icons.check_circle_outline_rounded),
            ('consistency_score','الاتساق',Icons.rule_rounded),
            ('naming_clarity_score','وضوح الأسماء',Icons.text_fields_rounded),
          ]),
          const SizedBox(height:8),
          _buildScoreRow([
            ('duplication_risk_score','خطر التكرار',Icons.content_copy_outlined),
            ('reporting_readiness_score','جاهزية التقارير',Icons.assessment_rounded),
          ]),
          const SizedBox(height:14),
          // ── جاهزية القوائم ──
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFF0D1829), borderRadius: BorderRadius.circular(14), border: Border.all(color:_border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('جاهزية إعداد القوائم المالية', textDirection: TextDirection.rtl, style: TextStyle(fontSize:13, fontWeight:FontWeight.w700, color:Color(0xFFF0EDE6), fontFamily:'Tajawal')),
                SizedBox(width:6), Icon(Icons.assessment_rounded, color:Color(0xFFC9A84C), size:16),
              ]),
              const SizedBox(height:12),
              Row(children: [
                ('income_statement','قائمة الدخل',Icons.show_chart_rounded),
                ('balance_sheet','الميزانية',Icons.account_balance_rounded),
                ('cash_flow','التدفقات',Icons.water_rounded),
                ('ratio_analysis','النسب',Icons.percent_rounded),
              ].map((item) {
                final ready = readiness[item.$1] == true;
                final color = ready ? _success : _danger;
                return Expanded(child: Container(margin: const EdgeInsets.only(left:6), padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
                  child: Column(children: [
                    Icon(item.$3, color:color, size:18),
                    const SizedBox(height:4),
                    Text(item.$2, textAlign: TextAlign.center, style: TextStyle(fontSize:9, color:color, fontFamily:'Tajawal')),
                    const SizedBox(height:2),
                    Icon(ready ? Icons.check_rounded : Icons.close_rounded, color:color, size:12),
                  ])));
              }).toList()),
            ])),
          if (recs.isNotEmpty) ...[
            const SizedBox(height:12),
            Container(padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _warning.withOpacity(0.05), borderRadius: BorderRadius.circular(14), border: Border.all(color: _warning.withOpacity(0.25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('توصيات التحسين', textDirection: TextDirection.rtl, style: TextStyle(fontSize:13, fontWeight:FontWeight.w700, color:Color(0xFFE8A838), fontFamily:'Tajawal')),
                  SizedBox(width:6), Icon(Icons.lightbulb_outline_rounded, color:Color(0xFFE8A838), size:16),
                ]),
                const SizedBox(height:10),
                ...recs.map((r) => Padding(padding: const EdgeInsets.only(bottom:6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(width:8),
                    Expanded(child: Text(r, textDirection: TextDirection.rtl, style: const TextStyle(fontSize:12, color:Color(0xFFF0EDE6), fontFamily:'Tajawal', height:1.5))),
                    const SizedBox(width:6), const Icon(Icons.chevron_left_rounded, color:Color(0xFFE8A838), size:14),
                  ]))),
              ])),
          ],
          if (ambiguous.isNotEmpty) ...[
            const SizedBox(height:8),
            _buildIssueList('حسابات بأسماء غامضة', Icons.help_outline_rounded, _warning, ambiguous),
          ],
          if (dupSuspects.isNotEmpty) ...[
            const SizedBox(height:8),
            _buildIssueList('حسابات مشتبه بتكرارها', Icons.content_copy_rounded, _danger, dupSuspects),
          ],
          const SizedBox(height:80),
        ]))),
        Container(padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Color(0xFF080F1F), border: Border(top: BorderSide(color: Color(0x26C9A84C)))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_overall < 0.5) Padding(padding: const EdgeInsets.only(bottom:10),
              child: Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:8),
                decoration: BoxDecoration(color: _warning.withOpacity(0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: _warning.withOpacity(0.3))),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, color:Color(0xFFE8A838), size:14), SizedBox(width:6),
                  Expanded(child: Text('درجة الجودة منخفضة — يُنصح بمراجعة شجرة الحسابات', textDirection: TextDirection.rtl, style: TextStyle(fontSize:11, color:Color(0xFFE8A838), fontFamily:'Tajawal'))),
                ]))),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CoaReviewScreen(uploadId: widget.uploadId, clientId: widget.clientId, clientName: widget.clientName))),
              child: Container(width: double.infinity, height:54,
                decoration: BoxDecoration(gradient: const LinearGradient(colors:[Color(0xFF2ECC8A),Color(0xFF1A8C5C)]), borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: _success.withOpacity(0.3), blurRadius:12, offset: const Offset(0,4))]),
                child: const Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.arrow_forward_rounded, color:Colors.white, size:20), SizedBox(width:8),
                  Text('متابعة لمراجعة التبويب', style: TextStyle(color:Colors.white, fontSize:15, fontWeight:FontWeight.w700, fontFamily:'Tajawal')),
                ])))),
          ])),
      ]),
    );
  }

  Widget _buildScoreRow(List<(String,String,IconData)> items) => Row(children: items.map((s) {
    final val = ((widget.assessData[s.$1] ?? 0.0) as num).toDouble();
    final color = _scoreColor(val);
    return Expanded(child: Container(margin: const EdgeInsets.only(left:8), padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF0D1829), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.25))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${(val*100).toInt()}%', style: TextStyle(fontSize:15, fontWeight:FontWeight.w800, color:color, fontFamily:'Tajawal')),
          Icon(s.$3, color:color, size:15),
        ]),
        const SizedBox(height:4),
        ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: val.clamp(0.0,1.0), minHeight:3, backgroundColor: const Color(0x26C9A84C), valueColor: AlwaysStoppedAnimation(color))),
        const SizedBox(height:4),
        Text(s.$2, textDirection: TextDirection.rtl, style: const TextStyle(fontSize:9, color:Color(0xFF8A8880), fontFamily:'Tajawal')),
      ])));
  }).toList());

  Widget _buildIssueList(String title, IconData icon, Color color, List<String> items) => Container(padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF0D1829), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(title, textDirection: TextDirection.rtl, style: TextStyle(fontSize:12, fontWeight:FontWeight.w700, color:color, fontFamily:'Tajawal')),
        const SizedBox(width:6), Icon(icon, color:color, size:14),
      ]),
      const SizedBox(height:8),
      ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom:4),
        child: Row(children: [
          Container(width:4, height:4, margin: const EdgeInsets.only(left:8), decoration: BoxDecoration(shape: BoxShape.circle, color:color)),
          Expanded(child: Text(item, textDirection: TextDirection.rtl, style: const TextStyle(fontSize:11, color:Color(0xFF8A8880), fontFamily:'Tajawal'), overflow: TextOverflow.ellipsis)),
        ]))),
    ]));
}

class _RingPainter extends CustomPainter {
  final double value; final Color color;
  const _RingPainter(this.value, this.color);
  @override void paint(Canvas canvas, Size size) {
    final center = Offset(size.width/2, size.height/2); final r = size.width/2-6;
    canvas.drawCircle(center, r, Paint()..color=color.withOpacity(0.1)..strokeWidth=8..style=PaintingStyle.stroke);
    canvas.drawArc(Rect.fromCircle(center:center,radius:r), -math.pi/2, 2*math.pi*value.clamp(0.0,1.0), false, Paint()..color=color..strokeWidth=8..style=PaintingStyle.stroke..strokeCap=StrokeCap.round);
  }
  @override bool shouldRepaint(_RingPainter old) => old.value != value;
}

