import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'package:file_picker/file_picker.dart';

class AnalysisFullScreen extends StatefulWidget {
  final Map<String, dynamic>? apiData;
  final PlatformFile? pickedFile;
  const AnalysisFullScreen({super.key, this.apiData, this.pickedFile});
  @override
  State<AnalysisFullScreen> createState() => _AnalysisFullScreenState();
}

class _AnalysisFullScreenState extends State<AnalysisFullScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;

  static Color get _navy => AC.navy;
  static Color get _navy2 => AC.navy2;
  static Color get _navy3 => AC.navy3;
  static Color get _gold => AC.gold;
  static Color get _border => AC.bdr;
  static Color get _textPrimary => AC.tp;
  static Color get _textSecondary => AC.ts;
  static const _success = Color(0xFF2ECC8A);
  static const _warning = Color(0xFFF0A500);
  static const _danger = Color(0xFFE05050);
  static const _cyan = Color(0xFF00C2E0);

  final _tabs = ['الربحية', 'السيولة', 'الكفاءة', 'الرفع المالي', 'التدفقات'];

  Map<String, dynamic> get _data => widget.apiData?['data'] ?? {};
  List<dynamic> get _ratios => _data['ratios'] ?? [];
  double get _score => ((_data['readiness_score']) ?? 0).toDouble();
  String get _label => _data['readiness_label'] ?? '';
  List<dynamic> get _insights => _data['ai_insights'] ?? [];

  // حسابات للنسب الإضافية
  double _v(String key) => (_data[key] ?? 0).toDouble();
  double get revenue => _v('revenue');
  double get cogs => _v('cost_of_goods_sold');
  double get grossProfit => revenue - cogs;
  double get opex => _v('operating_expenses');
  double get netProfit => grossProfit - opex - _v('interest_expense');
  double get totalAssets => _v('total_assets');
  double get currentAssets => _v('current_assets');
  double get currentLiabilities => _v('current_liabilities');
  double get totalLiabilities => _v('total_liabilities');
  double get equity => totalAssets - totalLiabilities;
  double get cash => _v('cash');
  double get inventory => _v('inventory');
  double get ebit => grossProfit - opex;
  double get interestExp => _v('interest_expense');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _selectedTab = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _statusColor(String? status) {
    if (status == 'good') return _success;
    if (status == 'warning') return _warning;
    return _danger;
  }

  List<Map<String, dynamic>> _getRatiosForTab(int tab) {
    final categories = {
      0: ['Gross Profit Margin','Net Profit Margin','EBITDA Margin','Return on Equity','Return on Assets'],
      1: ['Current Ratio','Quick Ratio','Cash Ratio'],
      2: ['Asset Turnover','Days Sales Outstanding','Inventory Days','Working Capital to Assets'],
      3: ['Debt to Equity','Debt to Assets','Interest Coverage','Revenue Growth Rate'],
    };

    if (tab == 4) {
      // نسب التدفقات النقدية المحسوبة
      double operatingCF = netProfit + (opex * 0.1);
      double investingCF = -(_v('total_assets') - _v('current_assets')) * 0.05;
      double freeCF = operatingCF + investingCF;
      double cfToDebt = totalLiabilities != 0 ? (operatingCF / totalLiabilities * 100) : 0;
      double cfToRevenue = revenue != 0 ? (operatingCF / revenue * 100) : 0;

      return [
        {'name_ar': 'التدفق النقدي التشغيلي', 'name_en': 'Operating CF',
          'value': operatingCF.toStringAsFixed(0), 'unit': ' ريال',
          'benchmark': 0, 'score': operatingCF > 0 ? 75.0 : 25.0,
          'status': operatingCF > 0 ? 'good' : 'danger',
          'interpretation': operatingCF > 0
            ? 'التدفق التشغيلي إيجابي — الشركة تولد نقداً من عملياتها'
            : 'التدفق التشغيلي سلبي — يحتاج مراجعة عاجلة',
          'explanation': 'يقيس قدرة الشركة على توليد النقد من عملياتها الأساسية'},
        {'name_ar': 'التدفق النقدي الحر', 'name_en': 'Free CF',
          'value': freeCF.toStringAsFixed(0), 'unit': ' ريال',
          'benchmark': 0, 'score': freeCF > 0 ? 70.0 : 30.0,
          'status': freeCF > 0 ? 'good' : 'warning',
          'interpretation': 'النقد المتاح بعد الاستثمارات الرأسمالية',
          'explanation': 'التدفق النقدي التشغيلي مطروحاً منه النفقات الرأسمالية'},
        {'name_ar': 'نسبة التدفق للديون', 'name_en': 'CF to Debt',
          'value': cfToDebt.toStringAsFixed(1), 'unit': '%',
          'benchmark': 20.0, 'score': cfToDebt > 20 ? 70.0 : 40.0,
          'status': cfToDebt > 20 ? 'good' : 'warning',
          'interpretation': 'قدرة التدفقات على تغطية الديون',
          'explanation': 'كلما ارتفعت النسبة كلما كانت الشركة أقدر على سداد ديونها'},
        {'name_ar': 'نسبة التدفق للإيرادات', 'name_en': 'CF to Revenue',
          'value': cfToRevenue.toStringAsFixed(1), 'unit': '%',
          'benchmark': 10.0, 'score': cfToRevenue > 10 ? 70.0 : 40.0,
          'status': cfToRevenue > 10 ? 'good' : 'warning',
          'interpretation': 'جودة تحويل الإيرادات إلى نقد',
          'explanation': 'نسبة عالية تعني كفاءة في تحصيل المستحقات'},
      ];
    }

    final filtered = _ratios.where((r) =>
      (categories[tab] ?? []).contains(r['name_en'])).toList();
    return filtered.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  String _getExplanation(String nameEn) {
    const explanations = {
      'Gross Profit Margin': 'يقيس نسبة الربح بعد خصم تكلفة المبيعات — كلما ارتفع كلما كانت كفاءة الإنتاج أفضل',
      'Net Profit Margin': 'يقيس نسبة الربح الصافي من كل ريال مبيعات — مؤشر شامل للربحية',
      'EBITDA Margin': 'يقيس الأرباح قبل الفوائد والضرائب والاستهلاك — أفضل مقياس للتدفق النقدي التشغيلي',
      'Return on Equity': 'العائد على استثمارات المساهمين — مؤشر رئيسي لجاذبية الاستثمار',
      'Return on Assets': 'كفاءة الشركة في استخدام أصولها لتوليد الأرباح',
      'Current Ratio': 'قدرة الشركة على سداد التزاماتها قصيرة الأجل — المعيار المقبول 1.5x',
      'Quick Ratio': 'السيولة السريعة بعد استبعاد المخزون — أكثر دقة من السيولة الجارية',
      'Cash Ratio': 'النقد المتاح فوراً لتغطية الالتزامات — المعيار المقبول 0.3x',
      'Asset Turnover': 'كفاءة توظيف الأصول في توليد المبيعات',
      'Days Sales Outstanding': 'متوسط الأيام اللازمة لتحصيل الديون — كلما قل كان أفضل',
      'Inventory Days': 'عدد أيام دوران المخزون — كلما قل كانت الكفاءة أعلى',
      'Working Capital to Assets': 'نسبة رأس المال العامل إلى الأصول — مقياس المرونة التشغيلية',
      'Debt to Equity': 'مدى اعتماد الشركة على الديون مقارنة بحقوق الملكية',
      'Debt to Assets': 'نسبة الأصول الممولة بالديون — كلما انخفضت كان الوضع أفضل',
      'Interest Coverage': 'قدرة الأرباح على تغطية مدفوعات الفوائد — المعيار الآمن 3x',
      'Revenue Growth Rate': 'معدل نمو الإيرادات مقارنة بالفترة السابقة',
    };
    return explanations[nameEn] ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy2,
        title: Text('التحليل المالي الكامل',
          style: TextStyle(fontFamily: 'Tajawal', color: _textPrimary)),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(color: _border, height: 1)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _buildScoreCard(),
          const SizedBox(height: 20),
          if (_insights.isNotEmpty) _buildInsights(),
          const SizedBox(height: 20),
          _buildRatiosTabs(),
          const SizedBox(height: 40),
        ])),
    );
  }

  Widget _buildScoreCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: 0.4))),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 90, height: 90,
            child: CustomPaint(
              painter: _RingPainter(_score / 100),
              child: Center(child: Text('${_score.toInt()}',
                style: TextStyle(color: _gold, fontSize: 22,
                  fontWeight: FontWeight.w900))))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('درجة الجاهزية الاستثمارية',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 13, color: _textSecondary, fontFamily: 'Tajawal')),
            Text('${_score.toInt()} / 100',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900,
                color: _gold, fontFamily: 'Tajawal')),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _success.withValues(alpha: 0.3))),
              child: Text(_label,
                style: const TextStyle(fontSize: 12, color: _success, fontFamily: 'Tajawal'))),
          ])),
        ]),
        SizedBox(height: 16),
        Divider(color: _border),
        const SizedBox(height: 12),
        // ملخص سريع
        Row(children: [
          _miniStat('هامش الربح', grossProfit != 0 && revenue != 0
            ? '${(grossProfit/revenue*100).toStringAsFixed(1)}%' : 'N/A', _gold),
          _miniStat('السيولة', currentLiabilities != 0
            ? '${(currentAssets/currentLiabilities).toStringAsFixed(2)}x' : 'N/A', _cyan),
          _miniStat('الرفع المالي', equity != 0
            ? '${(totalLiabilities/equity).toStringAsFixed(2)}x' : 'N/A', _warning),
          _miniStat('ROE', equity != 0
            ? '${(netProfit/equity*100).toStringAsFixed(1)}%' : 'N/A',
            netProfit >= 0 ? _success : _danger),
        ]),
      ]));
  }

  Widget _miniStat(String label, String value, Color color) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
        color: color, fontFamily: 'Tajawal')),
      Text(label, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: _textSecondary, fontFamily: 'Tajawal')),
    ]));

  Widget _buildInsights() {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('توصيات الذكاء الاصطناعي', textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
          color: _textPrimary, fontFamily: 'Tajawal')),
      const SizedBox(height: 10),
      ..._insights.map((ins) {
        final type = ins['type'] ?? '';
        final color = type == 'strength' ? _success
          : type == 'opportunity' ? _cyan : _warning;
        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(color: _navy3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(ins['title'] ?? '', textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: color, fontFamily: 'Tajawal')),
                SizedBox(height: 4),
                Text(ins['text'] ?? '', textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 12, color: _textSecondary,
                    fontFamily: 'Tajawal', height: 1.5)),
              ])),
              const SizedBox(width: 10),
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(
                  type == 'strength' ? Icons.trending_up_rounded
                    : type == 'opportunity' ? Icons.auto_graph_rounded
                    : Icons.warning_amber_rounded,
                  color: color, size: 18)),
            ])));
      }),
    ]);
  }

  Widget _buildRatiosTabs() {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('النسب المالية التفصيلية', textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
          color: _textPrimary, fontFamily: 'Tajawal')),
      const SizedBox(height: 12),
      // تبويبات
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(_tabs.length, (i) {
          return GestureDetector(
            onTap: () {
              setState(() => _selectedTab = i);
              _tabController.animateTo(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(left: 8),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedTab == i ? _gold.withValues(alpha: 0.1) : _navy3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedTab == i ? _gold : _border)),
              child: Text(_tabs[i],
                style: TextStyle(fontSize: 13,
                  color: _selectedTab == i ? _gold : _textSecondary,
                  fontFamily: 'Tajawal'))));
        }))),
      const SizedBox(height: 12),
      // النسب
      ..._getRatiosForTab(_selectedTab).map((r) {
        final score = ((r['score']) ?? 0).toDouble();
        final status = r['status']?.toString() ?? '';
        final color = _statusColor(status);
        final explanation = _getExplanation(r['name_en']?.toString() ?? '');
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            // اسم النسبة والقيمة
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('${r['value']}${r['unit']}',
                  style: TextStyle(fontSize: 15, color: color,
                    fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))),
              Text(r['name_ar']?.toString() ?? '',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: _textPrimary, fontFamily: 'Tajawal')),
            ]),
            const SizedBox(height: 8),
            // شريط التقدم
            Row(children: [
              Text('${score.toInt()}/100',
                style: TextStyle(fontSize: 11, color: color, fontFamily: 'Tajawal')),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: score / 100, minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  valueColor: AlwaysStoppedAnimation(color)))),
            ]),
            const SizedBox(height: 8),
            // التفسير
            Text(r['interpretation']?.toString() ?? '',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 12, color: _textSecondary,
                fontFamily: 'Tajawal', height: 1.4)),
            // الشرح
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(explanation,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(fontSize: 11, color: _textSecondary,
                      fontFamily: 'Tajawal', height: 1.5))),
                  const SizedBox(width: 6),
                  const Icon(Icons.info_outline, color: _cyan, size: 14),
                ])),
            ],
          ]));
      }),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double v;
  const _RingPainter(this.v);
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final r = s.width / 2 - 6;
    c.drawCircle(center, r,
      Paint()..color = const Color(0xFFC9A84C).withValues(alpha: 0.1)
        ..strokeWidth = 8..style = PaintingStyle.stroke);
    c.drawArc(Rect.fromCircle(center: center, radius: r),
      -1.5707963, 2 * 3.14159 * v, false,
      Paint()..color = const Color(0xFFC9A84C)..strokeWidth = 8
        ..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);
  }
  @override
  bool shouldRepaint(_) => false;
}
