/// APEX Wave 49 — FX / Currency Management.
/// Route: /app/erp/treasury/fx
///
/// Multi-currency balances, live rates, exposure.
library;

import 'package:flutter/material.dart';

class FxManagementScreen extends StatefulWidget {
  const FxManagementScreen({super.key});
  @override
  State<FxManagementScreen> createState() => _FxManagementScreenState();
}

class _FxManagementScreenState extends State<FxManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _fromCurrency = 'USD';
  String _toCurrency = 'SAR';
  final _amount = TextEditingController(text: '10000');

  final _rates = <String, double>{
    'SAR': 1.00,
    'USD': 3.7508,
    'EUR': 4.0620,
    'GBP': 4.7821,
    'AED': 1.0213,
    'KWD': 12.2318,
    'BHD': 9.9489,
    'OMR': 9.7424,
    'QAR': 1.0304,
    'JPY': 0.0251,
    'CHF': 4.2055,
    'CNY': 0.5173,
    'INR': 0.0447,
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _amount.dispose();
    super.dispose();
  }

  double _convert(double amount, String from, String to) {
    final fromRate = _rates[from] ?? 1;
    final toRate = _rates[to] ?? 1;
    return amount * fromRate / toRate;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        TabBar(
          controller: _tab,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.black54,
          indicatorColor: const Color(0xFFD4AF37),
          tabs: const [
            Tab(icon: Icon(Icons.currency_exchange, size: 16), text: 'محوّل العملات'),
            Tab(icon: Icon(Icons.account_balance_wallet, size: 16), text: 'الأرصدة متعددة العملات'),
            Tab(icon: Icon(Icons.trending_up, size: 16), text: 'أسعار الصرف اليومية'),
            Tab(icon: Icon(Icons.shield, size: 16), text: 'التعرّض والتحوّط'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildConverterTab(),
              _buildBalancesTab(),
              _buildRatesTab(),
              _buildExposureTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00796B)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.currency_exchange, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إدارة العملات الأجنبية',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('أسعار لحظية من البنك المركزي + تحويل + تحليل التعرّض',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 14),
              SizedBox(width: 6),
              Text('محدّث الآن', style: TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConverterTab() {
    final converted = _convert(double.tryParse(_amount.text) ?? 0, _fromCurrency, _toCurrency);
    final inverseRate = _convert(1, _toCurrency, _fromCurrency);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
            boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('من العملة', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _fromCurrency,
                          decoration: _decor(),
                          items: _rates.keys.map((c) => DropdownMenuItem(value: c, child: Text(_currencyLabel(c)))).toList(),
                          onChanged: (v) => setState(() => _fromCurrency = v ?? _fromCurrency),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                          decoration: _decor(),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            final tmp = _fromCurrency;
                            _fromCurrency = _toCurrency;
                            _toCurrency = tmp;
                          });
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: const Icon(Icons.swap_horiz, color: Color(0xFFD4AF37), size: 28),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إلى العملة', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _toCurrency,
                          decoration: _decor(),
                          items: _rates.keys.map((c) => DropdownMenuItem(value: c, child: Text(_currencyLabel(c)))).toList(),
                          onChanged: (v) => setState(() => _toCurrency = v ?? _toCurrency),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF004D40), Color(0xFF00796B)]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_fmt(converted),
                                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                              Text(_toCurrency, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _rateInfo('السعر الحالي', '1 $_fromCurrency = ${_convert(1, _fromCurrency, _toCurrency).toStringAsFixed(4)} $_toCurrency'),
                  _rateInfo('السعر العكسي', '1 $_toCurrency = ${inverseRate.toStringAsFixed(4)} $_fromCurrency'),
                  _rateInfo('آخر تحديث', '2026-04-18 15:30 — SAMA'),
                  _rateInfo('تغيّر خلال 24 ساعة', '+0.12%', color: Colors.green),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rateInfo(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: color ?? Colors.black87, fontFamily: 'monospace')),
      ],
    );
  }

  Widget _buildBalancesTab() {
    final balances = const [
      _Balance('SAR', 'ر.س', 485200, 485200, 0),
      _Balance('USD', '\$', 145000, 543866, 2.4),
      _Balance('EUR', '€', 78500, 318867, -1.2),
      _Balance('AED', 'د.إ', 220000, 224686, 0.3),
      _Balance('GBP', '£', 42000, 200848, 1.8),
      _Balance('JPY', '¥', 3500000, 87850, -0.6),
    ];
    final totalInSar = balances.fold(0.0, (s, b) => s + b.sarValue);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFE6C200)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('إجمالي السيولة النقدية (بالريال)',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              Text(_fmt(totalInSar),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              const Text(' ر.س', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.grey.shade100,
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('العملة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الرصيد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('ما يعادل (ر.س)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('نسبة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('24س', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final b in balances)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _currencyColor(b.code).withOpacity(0.15),
                              child: Text(b.symbol, style: TextStyle(color: _currencyColor(b.code), fontWeight: FontWeight.w900, fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            Text(b.code, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text('${_fmt(b.balance)} ${b.symbol}', style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(_fmt(b.sarValue),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
                      ),
                      Expanded(
                        child: Text('${(b.sarValue / totalInSar * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Expanded(
                        child: Text(
                          '${b.change >= 0 ? '+' : ''}${b.change.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: b.change == 0 ? Colors.black54 : b.change > 0 ? Colors.green : Colors.red,
                          ),
                        ),
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

  Widget _buildRatesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _rates.length - 1, // skip SAR
      itemBuilder: (ctx, i) {
        final currencies = _rates.keys.where((c) => c != 'SAR').toList();
        final code = currencies[i];
        final rate = _rates[code] ?? 0;
        final change = (i % 3 == 0) ? -0.3 : (i % 2 == 0) ? 0.8 : 0.2;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _currencyColor(code).withOpacity(0.12),
                child: Text(_currencySymbol(code), style: TextStyle(color: _currencyColor(code), fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_currencyLabel(code), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('1 $code = ${rate.toStringAsFixed(4)} ر.س',
                        style: const TextStyle(fontSize: 12, color: Colors.black54, fontFamily: 'monospace')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: change > 0 ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(change > 0 ? Icons.trending_up : Icons.trending_down,
                        size: 12, color: change > 0 ? Colors.green : Colors.red),
                    const SizedBox(width: 4),
                    Text('${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: change > 0 ? Colors.green : Colors.red,
                        )),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExposureTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.red, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('التعرّض الصافي',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.red)),
                    SizedBox(height: 4),
                    Text('انخفاض 1% في الدولار يؤثر على الربح بمقدار 45,250 ر.س',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('التعرّض حسب العملة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        _exposureRow('USD', 4525000, 125000, 1250000, Colors.blue),
        _exposureRow('EUR', 1860000, 85000, 680000, Colors.indigo),
        _exposureRow('GBP', 820000, 42000, 210000, Colors.purple),
        _exposureRow('AED', 560000, 0, 340000, Colors.green),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield, color: Color(0xFFD4AF37)),
                  SizedBox(width: 8),
                  Text('أدوات التحوّط المتاحة',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ],
              ),
              SizedBox(height: 10),
              Text('• عقود آجلة (Forward Contracts) — لتثبيت السعر لتاريخ مستقبلي',
                  style: TextStyle(fontSize: 12, height: 1.7)),
              Text('• عقود خيار (FX Options) — حق (لا التزام) التحويل عند سعر محدد',
                  style: TextStyle(fontSize: 12, height: 1.7)),
              Text('• مبادلات العملات (Currency Swaps) — تبادل مدفوعات بعملتين',
                  style: TextStyle(fontSize: 12, height: 1.7)),
              Text('• طبيعي — مطابقة المدفوعات بالمقبوضات في نفس العملة',
                  style: TextStyle(fontSize: 12, height: 1.7)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _exposureRow(String code, double receivables, double payables, double hedged, Color color) {
    final net = receivables - payables;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withOpacity(0.12),
                child: Text(code, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              const Text('تفصيل التعرّض', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('صافي: ${_fmt(net)} ر.س', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _exposureCell('مدينون', receivables, Colors.green),
              _exposureCell('دائنون', payables, Colors.red),
              _exposureCell('متحوّط', hedged, Colors.blue),
              _exposureCell('غير محوّط', net - hedged, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exposureCell(String label, double value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
            Text(_fmt(value),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFamily: 'monospace',
                )),
          ],
        ),
      ),
    );
  }

  InputDecoration _decor() => InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      );

  String _currencyLabel(String code) {
    final names = {
      'SAR': 'ريال سعودي',
      'USD': 'دولار أمريكي',
      'EUR': 'يورو',
      'GBP': 'جنيه إسترليني',
      'AED': 'درهم إماراتي',
      'KWD': 'دينار كويتي',
      'BHD': 'دينار بحريني',
      'OMR': 'ريال عُماني',
      'QAR': 'ريال قطري',
      'JPY': 'ين ياباني',
      'CHF': 'فرنك سويسري',
      'CNY': 'يوان صيني',
      'INR': 'روبية هندية',
    };
    return '$code — ${names[code] ?? code}';
  }

  String _currencySymbol(String code) {
    const symbols = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'AED': 'د.إ',
      'KWD': 'د.ك',
      'BHD': 'د.ب',
      'OMR': 'ر.ع',
      'QAR': 'ر.ق',
      'JPY': '¥',
      'CHF': 'Fr',
      'CNY': '¥',
      'INR': '₹',
    };
    return symbols[code] ?? code;
  }

  Color _currencyColor(String code) {
    const colors = {
      'USD': Colors.blue,
      'EUR': Colors.indigo,
      'GBP': Colors.purple,
      'AED': Colors.green,
      'KWD': Colors.teal,
      'JPY': Colors.red,
      'SAR': Color(0xFFD4AF37),
    };
    return colors[code] ?? Colors.grey;
  }

  String _fmt(double v) {
    final s = v.abs() >= 10000 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Balance {
  final String code;
  final String symbol;
  final double balance;
  final double sarValue;
  final double change;
  const _Balance(this.code, this.symbol, this.balance, this.sarValue, this.change);
}
