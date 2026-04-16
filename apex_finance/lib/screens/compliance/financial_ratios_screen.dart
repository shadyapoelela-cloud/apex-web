/// APEX Platform — Financial Ratios Screen
/// ═══════════════════════════════════════════════════════════════
/// 18 ratios across 5 categories, each with health status and
/// interpretation. Accepts a partial input set; missing values
/// gracefully skip the dependent ratios.
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class FinancialRatiosScreen extends StatefulWidget {
  const FinancialRatiosScreen({super.key});
  @override
  State<FinancialRatiosScreen> createState() => _FinancialRatiosScreenState();
}

class _FinancialRatiosScreenState extends State<FinancialRatiosScreen> {
  // Balance sheet
  final _currentAssetsC = TextEditingController();
  final _cashC = TextEditingController();
  final _inventoryC = TextEditingController();
  final _receivablesC = TextEditingController();
  final _currentLiabC = TextEditingController();
  final _totalAssetsC = TextEditingController();
  final _totalLiabC = TextEditingController();
  final _totalEquityC = TextEditingController();
  final _longTermDebtC = TextEditingController();
  // Income statement
  final _revenueC = TextEditingController();
  final _cogsC = TextEditingController();
  final _grossProfitC = TextEditingController();
  final _operIncomeC = TextEditingController();
  final _interestExpC = TextEditingController();
  final _netIncomeC = TextEditingController();
  // Cash flow + market
  final _ocfC = TextEditingController();
  final _sharesC = TextEditingController();
  final _priceC = TextEditingController();
  final _dpsC = TextEditingController();
  final _periodC = TextEditingController(text: '${DateTime.now().year}-FY');

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    for (final c in [_currentAssetsC, _cashC, _inventoryC, _receivablesC,
        _currentLiabC, _totalAssetsC, _totalLiabC, _totalEquityC, _longTermDebtC,
        _revenueC, _cogsC, _grossProfitC, _operIncomeC, _interestExpC, _netIncomeC,
        _ocfC, _sharesC, _priceC, _dpsC, _periodC]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _compute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final body = <String, dynamic>{
        'period_label': _periodC.text.trim().isEmpty ? 'FY' : _periodC.text.trim(),
        if (_v(_currentAssetsC) != null) 'current_assets': _v(_currentAssetsC),
        if (_v(_cashC) != null) 'cash_and_equivalents': _v(_cashC),
        if (_v(_inventoryC) != null) 'inventory': _v(_inventoryC),
        if (_v(_receivablesC) != null) 'receivables': _v(_receivablesC),
        if (_v(_currentLiabC) != null) 'current_liabilities': _v(_currentLiabC),
        if (_v(_totalAssetsC) != null) 'total_assets': _v(_totalAssetsC),
        if (_v(_totalLiabC) != null) 'total_liabilities': _v(_totalLiabC),
        if (_v(_totalEquityC) != null) 'total_equity': _v(_totalEquityC),
        if (_v(_longTermDebtC) != null) 'long_term_debt': _v(_longTermDebtC),
        if (_v(_revenueC) != null) 'revenue': _v(_revenueC),
        if (_v(_cogsC) != null) 'cogs': _v(_cogsC),
        if (_v(_grossProfitC) != null) 'gross_profit': _v(_grossProfitC),
        if (_v(_operIncomeC) != null) 'operating_income': _v(_operIncomeC),
        if (_v(_interestExpC) != null) 'interest_expense': _v(_interestExpC),
        if (_v(_netIncomeC) != null) 'net_income': _v(_netIncomeC),
        if (_v(_ocfC) != null) 'operating_cash_flow': _v(_ocfC),
        if (_v(_sharesC) != null) 'shares_outstanding': _v(_sharesC),
        if (_v(_priceC) != null) 'share_price': _v(_priceC),
        if (_v(_dpsC) != null) 'dividends_per_share': _v(_dpsC),
      };
      final r = await ApiService.ratiosCompute(body);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل الحساب');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: Text('المؤشرات المالية', style: TextStyle(color: AC.gold)),
        backgroundColor: AC.navy2,
      ),
      body: LayoutBuilder(builder: (ctx, cons) {
        final wide = cons.maxWidth > 1000;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [_form(), const SizedBox(height: 16), _results()]),
          );
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4,
            child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _form())),
          Container(width: 1, color: AC.bdr),
          Expanded(flex: 6,
            child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _results())),
        ]);
      }),
    );
  }

  Widget _form() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _section('الفترة'),
    _numField(_periodC, 'الفترة', Icons.calendar_today, numeric: false),
    _section('الميزانية العمومية (Balance Sheet)'),
    _numField(_currentAssetsC, 'الأصول المتداولة', Icons.inventory),
    _numField(_cashC, 'النقد وما يعادله', Icons.account_balance_wallet),
    _numField(_inventoryC, 'المخزون', Icons.inventory_2),
    _numField(_receivablesC, 'المدينون', Icons.receipt),
    _numField(_currentLiabC, 'الخصوم المتداولة', Icons.payments),
    _numField(_totalAssetsC, 'إجمالي الأصول', Icons.account_balance),
    _numField(_totalLiabC, 'إجمالي الخصوم', Icons.balance),
    _numField(_totalEquityC, 'حقوق الملكية', Icons.group),
    _numField(_longTermDebtC, 'ديون طويلة الأجل', Icons.history),
    _section('قائمة الدخل (Income Statement)'),
    _numField(_revenueC, 'الإيرادات', Icons.trending_up),
    _numField(_cogsC, 'تكلفة البضاعة المباعة', Icons.shopping_cart),
    _numField(_grossProfitC, 'الربح الإجمالي', Icons.summarize),
    _numField(_operIncomeC, 'الربح التشغيلي (EBIT)', Icons.business),
    _numField(_interestExpC, 'مصروف الفائدة', Icons.percent),
    _numField(_netIncomeC, 'صافي الربح', Icons.check_circle_outline),
    _section('التدفق النقدي + السوق (اختياري)'),
    _numField(_ocfC, 'التدفق النقدي التشغيلي', Icons.waves),
    _numField(_sharesC, 'عدد الأسهم', Icons.pie_chart),
    _numField(_priceC, 'سعر السهم', Icons.monetization_on),
    _numField(_dpsC, 'توزيعات السهم (DPS)', Icons.card_giftcard),
    const SizedBox(height: 12),
    if (_error != null) _errorBanner(_error!),
    const SizedBox(height: 8),
    SizedBox(height: 54,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _compute,
        icon: _loading
          ? const SizedBox(height: 18, width: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.analytics),
        label: const Text('احسب المؤشرات', style: TextStyle(fontSize: 16)),
      ),
    ),
  ]);

  Widget _results() {
    if (_result == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AC.navy2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.analytics, color: AC.ts, size: 64),
          const SizedBox(height: 14),
          Text('املأ ما تعرفه من بيانات ثم اضغط "احسب"',
            style: TextStyle(color: AC.ts, fontSize: 14)),
          const SizedBox(height: 6),
          Text('الخانات غير المعبأة ستُستثنى تلقائياً',
            style: TextStyle(color: AC.td, fontSize: 12)),
        ]),
      );
    }
    final d = _result!;
    final cats = (d['categories'] ?? {}) as Map;
    final total = d['total_ratios'] ?? 0;
    final warnings = (d['warnings'] ?? []) as List;

    const catMeta = {
      'liquidity':      {'label': 'السيولة', 'color': 'info',    'icon': Icons.water_drop},
      'solvency':       {'label': 'الملاءة', 'color': 'ok',      'icon': Icons.shield},
      'profitability':  {'label': 'الربحية', 'color': 'gold',    'icon': Icons.trending_up},
      'efficiency':     {'label': 'الكفاءة', 'color': 'purple',  'icon': Icons.speed},
      'valuation':      {'label': 'التقييم', 'color': 'warn',    'icon': Icons.insights},
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _summaryHeader(total, d['period_label']),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        _warnCard(warnings),
      ],
      const SizedBox(height: 14),
      ...catMeta.entries.map((e) {
        final list = (cats[e.key] ?? []) as List;
        if (list.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _categoryCard(
            e.value['label'] as String,
            e.value['icon'] as IconData,
            e.value['color'] as String,
            list,
          ),
        );
      }),
    ]);
  }

  Widget _summaryHeader(int total, dynamic period) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [AC.gold.withValues(alpha: 0.12), AC.navy3],
        begin: Alignment.topRight, end: Alignment.bottomLeft),
      border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(children: [
      Icon(Icons.assessment, color: AC.gold, size: 32),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('التقرير المالي', style: TextStyle(
          color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
        Text('$total مؤشر · $period',
          style: TextStyle(color: AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _categoryCard(String label, IconData icon, String colorKey, List ratios) {
    final color = _colorOf(colorKey);
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(
              color: color, fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text('${ratios.length}', style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
        ),
        ...ratios.asMap().entries.map((entry) {
          final r = entry.value as Map;
          final isLast = entry.key == ratios.length - 1;
          return _ratioRow(r, color, !isLast);
        }),
      ]),
    );
  }

  Widget _ratioRow(Map r, Color catColor, bool withDivider) {
    final value = r['value']?.toString() ?? '—';
    final unit = r['unit'] as String? ?? '';
    final health = r['health'] as String? ?? 'n/a';
    final healthColor = _healthColor(health);
    final healthLabel = _healthLabel(health);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(r['name_ar']?.toString() ?? '',
              style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700, fontSize: 13))),
            if (health != 'n/a') Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: healthColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(healthLabel, style: TextStyle(
                color: healthColor, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: TextStyle(
              color: healthColor, fontSize: 20,
              fontWeight: FontWeight.w900, fontFamily: 'monospace')),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(_unitLabel(unit), style: TextStyle(color: AC.ts, fontSize: 11)),
            ),
            const Spacer(),
            if (r['healthy_range'] != null)
              Text('المثالي: ${r['healthy_range']}',
                style: TextStyle(color: AC.td, fontSize: 10, fontFamily: 'monospace')),
          ]),
          const SizedBox(height: 4),
          Text(r['formula_ar']?.toString() ?? '',
            style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace')),
          if ((r['interpretation_ar'] ?? '').toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(r['interpretation_ar'].toString(),
                style: TextStyle(color: AC.td, fontSize: 11, height: 1.5)),
            ),
        ]),
      ),
      if (withDivider) Divider(color: AC.bdr, height: 1),
    ]);
  }

  Color _colorOf(String key) {
    switch (key) {
      case 'gold': return AC.gold;
      case 'ok': return AC.ok;
      case 'info': return AC.info;
      case 'warn': return AC.warn;
      case 'purple': return AC.purple;
      default: return AC.gold;
    }
  }

  Color _healthColor(String health) {
    switch (health) {
      case 'healthy': return AC.ok;
      case 'watch':   return AC.warn;
      case 'risk':    return AC.err;
      default: return AC.ts;
    }
  }

  String _healthLabel(String health) {
    switch (health) {
      case 'healthy': return 'ممتاز';
      case 'watch':   return 'مقبول';
      case 'risk':    return 'خطر';
      default: return '—';
    }
  }

  String _unitLabel(String unit) {
    switch (unit) {
      case 'percent': return '%';
      case 'times':   return 'مرة';
      case 'days':    return 'يوم';
      case 'ratio':   return '';
      case 'sar':     return 'SAR';
      default: return '';
    }
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 6),
    child: Row(children: [
      Container(width: 3, height: 18, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _numField(TextEditingController c, String label, IconData icon, {bool numeric = true}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(color: AC.tp, fontFamily: numeric ? 'monospace' : null),
        decoration: _inpDec(label, icon).copyWith(
          hintText: numeric ? '—' : null,
          hintStyle: TextStyle(color: AC.td, fontFamily: 'monospace'),
        ),
      ),
    );

  InputDecoration _inpDec(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AC.goldText, size: 18),
    filled: true,
    fillColor: AC.navy3,
    labelStyle: TextStyle(color: AC.ts, fontSize: 12),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AC.goldText)),
  );

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AC.err.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AC.err.withValues(alpha: 0.35)),
    ),
    child: Row(children: [
      Icon(Icons.error_outline, color: AC.err, size: 16),
      const SizedBox(width: 6),
      Expanded(child: Text(msg, style: TextStyle(color: AC.err, fontSize: 12))),
    ]),
  );

  Widget _warnCard(List warnings) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AC.warn.withValues(alpha: 0.08),
      border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.warning_amber_rounded, color: AC.warn, size: 14),
        const SizedBox(width: 6),
        Text('تنبيهات', style: TextStyle(color: AC.warn, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
      const SizedBox(height: 4),
      ...warnings.map((w) => Text('• $w',
        style: TextStyle(color: AC.tp, fontSize: 11))),
    ]),
  );
}
