import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

class TrialBalanceCheckScreen extends StatefulWidget {
  final String uploadId;
  final String clientId;
  final String clientName;

  const TrialBalanceCheckScreen({
    super.key,
    required this.uploadId,
    this.clientId = '',
    this.clientName = '',
  });

  @override
  State<TrialBalanceCheckScreen> createState() => _TrialBalanceCheckScreenState();
}

class _TrialBalanceCheckScreenState extends State<TrialBalanceCheckScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  bool _hasResult = false;
  Map<String, dynamic> _data = {};
  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final res = await ApiService.postTrialBalanceCheck(widget.uploadId, {});
    if (!mounted) return;
    setState(() {
      _loading = false;
      _hasResult = res.success;
      _data = res.success ? (res.data as Map<String, dynamic>? ?? {}) : {};
    });
    if (res.success) _animCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('فحص ميزان المراجعة', style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700, fontSize: 18)),
            if (widget.clientName.isNotEmpty) Text(widget.clientName, style: TextStyle(color: AC.ts, fontSize: 12)),
          ]),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(2), child: Container(height: 2, color: AC.gold.withValues(alpha: 0.3))),
          iconTheme: IconThemeData(color: AC.tp),
          actions: [
            IconButton(icon: Icon(Icons.refresh_rounded, color: AC.gold), onPressed: () { setState(() => _loading = true); _animCtrl.reset(); _load(); }),
          ],
        ),
        body: _loading ? _buildLoading() : !_hasResult ? _buildNoData() : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(children: [
      const SizedBox(height: 40),
      SizedBox(width: 60, height: 60, child: CircularProgressIndicator(color: AC.gold, strokeWidth: 3)),
      const SizedBox(height: 20),
      Text('جارٍ فحص التوازن...', style: TextStyle(color: AC.ts, fontSize: 14)),
    ]),
  );

  Widget _buildNoData() => apexEmptyState(
    icon: Icons.balance_rounded,
    title: 'لا توجد بيانات ميزان مراجعة',
    subtitle: 'يرجى رفع ميزان المراجعة أولاً لإجراء الفحص',
    action: apexPrimaryButton('العودة', () => Navigator.of(context).pop()),
  );

  Widget _buildContent() {
    final balanceCheck = _data['balance_check'] as Map<String, dynamic>? ?? {};
    final fp08 = _data['fp08_alert'] as Map<String, dynamic>?;

    final totalDebit = (balanceCheck['total_debit'] ?? 0).toDouble();
    final totalCredit = (balanceCheck['total_credit'] ?? 0).toDouble();
    final difference = (balanceCheck['difference'] ?? (totalDebit - totalCredit)).toDouble();
    final isBalanced = difference.abs() < 0.01;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ApexStaggeredList(children: [
        _buildBalanceHero(isBalanced, totalDebit, totalCredit, difference),
        const SizedBox(height: 16),
        _buildTotalsCard(totalDebit, totalCredit, difference, isBalanced),
        const SizedBox(height: 8),
        _buildFraudAlert(fp08),
        if (balanceCheck.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildDetailsCard(balanceCheck),
        ],
      ]),
    );
  }

  Widget _buildBalanceHero(bool isBalanced, double debit, double credit, double diff) {
    final color = isBalanced ? AC.ok : AC.err;
    return ApexFadeIn(
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.08), AC.navy2],
            begin: Alignment.topRight, end: Alignment.bottomLeft,
          ),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          SizedBox(
            width: 100, height: 100,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => CustomPaint(
                painter: _BalanceRingPainter(progress: _anim.value, color: color, bgColor: AC.navy3),
                child: Center(child: Icon(
                  isBalanced ? Icons.check_rounded : Icons.warning_rounded,
                  color: color, size: 36,
                )),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isBalanced ? 'ميزان متوازن' : 'ميزان غير متوازن', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(isBalanced ? 'مجموع المدين يساوي مجموع الدائن' : 'يوجد فرق ${_formatNum(diff.abs())}', style: TextStyle(color: AC.ts, fontSize: 13)),
          ])),
        ]),
      ),
    );
  }

  Widget _buildTotalsCard(double debit, double credit, double diff, bool isBalanced) {
    return apexSoftCard(title: 'ملخص الأرصدة', children: [
      _totalRow('مجموع المدين', debit, AC.info),
      const SizedBox(height: 10),
      _totalRow('مجموع الدائن', credit, AC.purple),
      Divider(color: AC.bdr, height: 20),
      _totalRow('الفرق', diff.abs(), isBalanced ? AC.ok : AC.err),
    ]);
  }

  Widget _totalRow(String label, double amount, Color color) {
    return Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(color: AC.tp, fontSize: 14))),
      Text(_formatNum(amount), style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _buildFraudAlert(Map<String, dynamic>? fp08) {
    if (fp08 == null) {
      return apexTintedCard(
        tint: ApexTint.green,
        children: [
          Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AC.ok.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.shield_rounded, color: AC.ok, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('لم يتم رصد أنماط مشبوهة', style: TextStyle(color: AC.ok, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('لا توجد تحذيرات FP08 — سحوبات الشركاء', style: TextStyle(color: AC.ts, fontSize: 12)),
            ])),
          ]),
        ],
      );
    }

    return apexTintedCard(
      tint: ApexTint.red,
      title: 'تنبيه احتيال — FP08',
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.gpp_bad_rounded, color: AC.err, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (fp08['pattern_id'] != null) Text('النمط: ${fp08['pattern_id']}', style: TextStyle(color: AC.err, fontSize: 13, fontWeight: FontWeight.w600)),
            if (fp08['risk'] != null) ...[
              const SizedBox(height: 4),
              Text('المخاطرة: ${fp08['risk']}', style: TextStyle(color: AC.warn, fontSize: 12)),
            ],
            if (fp08['account_code'] != null) ...[
              const SizedBox(height: 4),
              Text('الحساب: ${fp08['account_code']}', style: TextStyle(color: AC.ts, fontSize: 12)),
            ],
            if (fp08['message'] != null) ...[
              const SizedBox(height: 8),
              Text(fp08['message'], style: TextStyle(color: AC.tp, fontSize: 13, height: 1.5)),
            ],
          ])),
        ]),
      ],
    );
  }

  Widget _buildDetailsCard(Map<String, dynamic> check) {
    final entries = check.entries.where((e) => e.key != 'total_debit' && e.key != 'total_credit' && e.key != 'difference').toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return apexSoftCard(
      title: 'تفاصيل إضافية',
      children: entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Expanded(child: Text(e.key, style: TextStyle(color: AC.ts, fontSize: 12))),
          Text('${e.value}', style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      )).toList(),
    );
  }

  String _formatNum(double n) => n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _BalanceRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _BalanceRingPainter({required this.progress, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    canvas.drawCircle(center, radius, Paint()..color = bgColor..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, progress * 2 * math.pi, false,
      Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _BalanceRingPainter old) => old.progress != progress;
}
