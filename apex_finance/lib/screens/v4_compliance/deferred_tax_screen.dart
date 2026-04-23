/// APEX Wave 71 — Deferred Tax (IAS 12).
/// Route: /app/compliance/tax/deferred
///
/// Temporary differences, DTA/DTL calculation, and tax reconciliation.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class DeferredTaxScreen extends StatefulWidget {
  const DeferredTaxScreen({super.key});
  @override
  State<DeferredTaxScreen> createState() => _DeferredTaxScreenState();
}

class _DeferredTaxScreenState extends State<DeferredTaxScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final double _taxRate = 20.0; // KSA CT rate

  final _differences = <_TempDiff>[
    _TempDiff('الأصول الثابتة', 2_450_000, 2_680_000, 230_000, 'taxable', 'إهلاك محاسبي أسرع من الضريبي'),
    _TempDiff('مخصص الديون المشكوك بها', 185_000, 0, 185_000, 'deductible', 'غير مسموح ضريبياً'),
    _TempDiff('مخصص نهاية الخدمة', 425_000, 0, 425_000, 'deductible', 'يُحتسب عند الصرف فقط'),
    _TempDiff('مخصص مخزون بطيء الحركة', 68_000, 0, 68_000, 'deductible', 'غير مسموح ضريبياً'),
    _TempDiff('خسائر متراكمة مرحّلة', 0, 340_000, 340_000, 'deductible', 'يمكن خصمها من أرباح قادمة'),
    _TempDiff('إعادة تقييم الاستثمارات', 180_000, 150_000, 30_000, 'taxable', 'الربح المحاسبي قبل البيع'),
    _TempDiff('إيرادات مؤجلة', 95_000, 0, 95_000, 'deductible', 'تُخضع عند التحقق الضريبي'),
    _TempDiff('مصروفات مؤجلة (مقدمة)', 240_000, 0, 240_000, 'taxable', 'تم خصمها ضريبياً مقدماً'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  double get _taxable => _differences.where((d) => d.type == 'taxable').fold(0.0, (s, d) => s + d.difference);
  double get _deductible => _differences.where((d) => d.type == 'deductible').fold(0.0, (s, d) => s + d.difference);
  double get _dtl => _taxable * _taxRate / 100;
  double get _dta => _deductible * _taxRate / 100;
  double get _net => _dtl - _dta;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFF4A148C),
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: const Color(0xFF4A148C),
          tabs: const [
            Tab(icon: Icon(Icons.compare_arrows, size: 16), text: 'الفروقات المؤقتة'),
            Tab(icon: Icon(Icons.calculate, size: 16), text: 'المخصّصات الضريبية'),
            Tab(icon: Icon(Icons.receipt_long, size: 16), text: 'تسوية الضريبة'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildDifferencesTab(),
              _buildProvisionsTab(),
              _buildReconciliationTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الضريبة المؤجلة — IAS 12',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('Deferred Tax · DTA / DTL · الفروقات المؤقتة بين الأرباح المحاسبية والضريبية',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('معدل الضريبة', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
              Text('${_taxRate.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDifferencesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Row(
            children: [
              Icon(Icons.info, color: core_theme.AC.info),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الفروقات المؤقتة (Temporary Differences) = القيمة الدفترية − القاعدة الضريبية. الضريبة المؤجلة = الفرق × معدل الضريبة المستقبلي.',
                  style: TextStyle(fontSize: 12, height: 1.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: core_theme.AC.navy3,
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text('البند', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('القيمة الدفترية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('القاعدة الضريبية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الفرق المؤقت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('النوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('DTA/DTL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.gold))),
                  ],
                ),
              ),
              for (final d in _differences) _diffRow(d),
              Container(
                padding: const EdgeInsets.all(12),
                color: core_theme.AC.navy3,
                child: Row(
                  children: [
                    const Expanded(flex: 7, child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
                    Expanded(
                      flex: 2,
                      child: Text(_fmt(_taxable - _deductible),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    ),
                    const Expanded(child: SizedBox()),
                    Expanded(
                      flex: 2,
                      child: Text(_fmt(_net),
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                              color: _net >= 0 ? core_theme.AC.warn : core_theme.AC.ok)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _diffRow(_TempDiff d) {
    final isTaxable = d.type == 'taxable';
    final deferredTax = d.difference * _taxRate / 100;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.account, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(d.reason, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(_fmt(d.bookValue), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Expanded(flex: 2, child: Text(_fmt(d.taxBase), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Expanded(
            flex: 2,
            child: Text(_fmt(d.difference),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (isTaxable ? core_theme.AC.warn : core_theme.AC.ok).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(isTaxable ? 'خاضع' : 'قابل للخصم',
                  style: TextStyle(
                    fontSize: 9,
                    color: isTaxable ? core_theme.AC.warn : core_theme.AC.ok,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${isTaxable ? '+' : '-'}${_fmt(deferredTax)}',
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                color: isTaxable ? core_theme.AC.warn : core_theme.AC.ok,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvisionsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [core_theme.AC.warn, Color(0xFFFF7043)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.arrow_upward, color: Colors.white),
                        SizedBox(width: 8),
                        Text('الضريبة المؤجلة — التزام (DTL)',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_fmt(_dtl),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    Text('ر.س', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                    const SizedBox(height: 8),
                    Text('من فروقات خاضعة للضريبة: ${_fmt(_taxable)} × ${_taxRate.toStringAsFixed(0)}%',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [core_theme.AC.ok, core_theme.AC.ok]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.arrow_downward, color: Colors.white),
                        SizedBox(width: 8),
                        Text('الضريبة المؤجلة — أصل (DTA)',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_fmt(_dta),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    Text('ر.س', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                    const SizedBox(height: 8),
                    Text('من فروقات قابلة للخصم: ${_fmt(_deductible)} × ${_taxRate.toStringAsFixed(0)}%',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.compare, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('الصافي المؤجل — بعد الموازنة',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text(
                _net >= 0 ? '+${_fmt(_net)}' : _fmt(_net),
                style: const TextStyle(color: Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace'),
              ),
              Text(' ر.س', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: core_theme.AC.warn,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.warn),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rule, color: core_theme.AC.warn),
                  SizedBox(width: 8),
                  Text('قيد الاعتراف المقترح',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              _jeLine(_net >= 0 ? 'مدين: مصروف الضريبة المؤجلة' : 'مدين: أصل ضريبي مؤجل (DTA)', _net.abs(), true),
              _jeLine(_net >= 0 ? 'دائن: التزام ضريبي مؤجل (DTL)' : 'دائن: مخصّص ضريبي مؤجل', _net.abs(), false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _jeLine(String label, double value, bool debit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(debit ? 'Dr' : 'Cr',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: debit ? core_theme.AC.ok : core_theme.AC.warn,
                fontFamily: 'monospace',
              )),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(_fmt(value),
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace', color: core_theme.AC.gold)),
        ],
      ),
    );
  }

  Widget _buildReconciliationTab() {
    const accountingProfit = 4_850_000.0;
    const permanentDifferences = 125_000.0;
    final taxableProfit = accountingProfit + permanentDifferences - (_taxable - _deductible);
    final currentTax = taxableProfit * _taxRate / 100;
    final effectiveRate = (currentTax + _net) / accountingProfit * 100;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.receipt_long, color: Color(0xFF4A148C)),
                  SizedBox(width: 8),
                  Text('تسوية الضريبة (Tax Reconciliation)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 16),
              _reconRow('الربح المحاسبي قبل الضريبة', accountingProfit, core_theme.AC.tp),
              _reconRow('+ فروقات دائمة (مصروفات غير معترف بها)', permanentDifferences, core_theme.AC.warn),
              _reconRow('- فروقات مؤقتة خاضعة', _taxable, core_theme.AC.warn, subtract: true),
              _reconRow('+ فروقات مؤقتة قابلة للخصم', _deductible, core_theme.AC.ok),
              const Divider(),
              _reconRow('الربح الخاضع للضريبة', taxableProfit, core_theme.AC.gold, bold: true),
              const SizedBox(height: 16),
              _reconRow('الضريبة الحالية (${_taxRate.toStringAsFixed(0)}%)', currentTax, core_theme.AC.info, bold: true),
              _reconRow('+ الضريبة المؤجلة', _net, _net >= 0 ? core_theme.AC.warn : core_theme.AC.ok),
              const Divider(),
              _reconRow('إجمالي مصروف الضريبة', currentTax + _net, const Color(0xFF4A148C), bold: true),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: core_theme.AC.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('المعدل الفعلي للضريبة',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    Text('${effectiveRate.toStringAsFixed(2)}%',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900, color: core_theme.AC.gold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reconRow(String label, double value, Color color, {bool bold = false, bool subtract = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: bold ? 14 : 12,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
                color: core_theme.AC.tp,
              )),
          Text(
            '${subtract ? '-' : ''}${_fmt(value)}',
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    final s = v.abs().toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _TempDiff {
  final String account;
  final double bookValue;
  final double taxBase;
  final double difference;
  final String type; // 'taxable' or 'deductible'
  final String reason;
  const _TempDiff(this.account, this.bookValue, this.taxBase, this.difference, this.type, this.reason);
}
