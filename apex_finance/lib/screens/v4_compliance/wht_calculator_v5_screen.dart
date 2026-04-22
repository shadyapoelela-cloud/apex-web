/// APEX Wave 47 — Withholding Tax (WHT) Calculator.
/// Route: /app/compliance/tax/wht
///
/// KSA WHT rates per ZATCA tax treaty matrix.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class WhtCalculatorV5Screen extends StatefulWidget {
  const WhtCalculatorV5Screen({super.key});
  @override
  State<WhtCalculatorV5Screen> createState() => _WhtCalculatorV5ScreenState();
}

class _WhtCalculatorV5ScreenState extends State<WhtCalculatorV5Screen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  // Service category → [standard rate, treaty rate options]
  final _categories = const [
    _WhtCategory('management', 'أتعاب إدارية', 20, ['البحرين: 5%', 'فرنسا: 5%', 'الهند: 10%']),
    _WhtCategory('royalties', 'إتاوات', 15, ['المملكة المتحدة: 5%', 'سنغافورة: 8%']),
    _WhtCategory('technical', 'خدمات فنية', 5, ['معظم الاتفاقيات: 5%']),
    _WhtCategory('dividends', 'أرباح أسهم', 5, ['المملكة المتحدة: 5%']),
    _WhtCategory('interest', 'فوائد قروض', 5, ['تطبق على فوائد المقيمين']),
    _WhtCategory('rent', 'إيجار', 5, ['عقارات وأصول مستأجرة']),
    _WhtCategory('insurance', 'تأمين وإعادة تأمين', 5, ['على الأقساط المدفوعة للخارج']),
    _WhtCategory('telecom', 'اتصالات دولية', 15, ['على المدفوعات للمشغلين الدوليين']),
    _WhtCategory('air_freight', 'شحن جوي', 5, ['خدمات النقل الجوي الدولي']),
    _WhtCategory('other', 'أخرى', 15, ['التصنيف الافتراضي']),
  ];

  String _selectedCat = 'technical';
  final _amount = TextEditingController(text: '150000');
  final _vendor = TextEditingController(text: 'Oracle Middle East FZ-LLC');
  final _country = ValueNotifier<String>('AE');
  String _treatyApplied = 'standard';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _amount.dispose();
    _vendor.dispose();
    super.dispose();
  }

  _WhtCategory get _cat => _categories.firstWhere((c) => c.id == _selectedCat);
  double get _amountV => double.tryParse(_amount.text) ?? 0;
  double get _rate => _treatyApplied == 'treaty' ? 5 : _cat.standardRate.toDouble();
  double get _whtAmount => _amountV * _rate / 100;
  double get _netPayment => _amountV - _whtAmount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.calculate, size: 16), text: 'حاسبة'),
            Tab(icon: Icon(Icons.history, size: 16), text: 'السجل الشهري'),
            Tab(icon: Icon(Icons.library_books, size: 16), text: 'الاتفاقيات الضريبية'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildCalculatorTab(),
              _buildHistoryTab(),
              _buildTreatiesTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.money_off, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ضريبة الاستقطاع (WHT)',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('حساب تلقائي لضريبة الاستقطاع عند الدفع لغير المقيمين — ZATCA',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatorTab() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 20, right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _inputCard(
                  'بيانات الدفعة',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _labeled(
                        'اسم المورد / المستفيد',
                        TextField(
                          controller: _vendor,
                          decoration: _decor('اسم الشركة الأجنبية'),
                        ),
                      ),
                      _labeled(
                        'دولة الإقامة الضريبية للمستفيد',
                        Row(
                          children: [
                            Expanded(
                              child: ValueListenableBuilder(
                                valueListenable: _country,
                                builder: (_, value, __) => DropdownButtonFormField<String>(
                                  value: value,
                                  decoration: _decor(''),
                                  items: const [
                                    DropdownMenuItem(value: 'AE', child: Text('الإمارات 🇦🇪')),
                                    DropdownMenuItem(value: 'BH', child: Text('البحرين 🇧🇭')),
                                    DropdownMenuItem(value: 'GB', child: Text('المملكة المتحدة 🇬🇧')),
                                    DropdownMenuItem(value: 'FR', child: Text('فرنسا 🇫🇷')),
                                    DropdownMenuItem(value: 'IN', child: Text('الهند 🇮🇳')),
                                    DropdownMenuItem(value: 'US', child: Text('الولايات المتحدة 🇺🇸')),
                                    DropdownMenuItem(value: 'SG', child: Text('سنغافورة 🇸🇬')),
                                    DropdownMenuItem(value: 'OTHER', child: Text('أخرى')),
                                  ],
                                  onChanged: (v) => _country.value = v ?? 'AE',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _labeled(
                        'المبلغ الإجمالي للفاتورة',
                        TextField(
                          controller: _amount,
                          keyboardType: TextInputType.number,
                          decoration: _decor('').copyWith(suffixText: ' ر.س'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _inputCard(
                  'فئة الخدمة',
                  Column(
                    children: [
                      for (final c in _categories)
                        InkWell(
                          onTap: () => setState(() => _selectedCat = c.id),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _selectedCat == c.id ? core_theme.AC.gold.withOpacity(0.1) : core_theme.AC.navy3,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _selectedCat == c.id ? core_theme.AC.gold : core_theme.AC.bdr,
                                width: _selectedCat == c.id ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: c.id,
                                  groupValue: _selectedCat,
                                  onChanged: (v) => setState(() => _selectedCat = v ?? _selectedCat),
                                  activeColor: core_theme.AC.gold,
                                ),
                                Expanded(
                                  child: Text(c.nameAr,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: _selectedCat == c.id ? FontWeight.w800 : FontWeight.w500,
                                      )),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _selectedCat == c.id ? core_theme.AC.gold : core_theme.AC.bdr,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('${c.standardRate}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: _selectedCat == c.id ? Colors.white : core_theme.AC.tp,
                                      )),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _inputCard(
                  'تطبيق اتفاقية ضريبية',
                  Column(
                    children: [
                      RadioListTile(
                        value: 'standard',
                        groupValue: _treatyApplied,
                        onChanged: (v) => setState(() => _treatyApplied = v ?? 'standard'),
                        title: Text('المعدل القياسي (${_cat.standardRate}%)'),
                        subtitle: Text('بدون شهادة الإقامة الضريبية', style: TextStyle(fontSize: 11)),
                        activeColor: core_theme.AC.gold,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      RadioListTile(
                        value: 'treaty',
                        groupValue: _treatyApplied,
                        onChanged: (v) => setState(() => _treatyApplied = v ?? 'standard'),
                        title: Text('تطبيق الاتفاقية (5%)'),
                        subtitle: Text('يتطلب إرفاق شهادة الإقامة الضريبية الأصلية', style: TextStyle(fontSize: 11)),
                        activeColor: core_theme.AC.gold,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, bottom: 20, left: 10),
            child: _buildResultCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4A148C), Color(0xFF3D0F73)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الضريبة المستقطعة',
                  style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              const SizedBox(height: 4),
              Text('${_rate.toStringAsFixed(0)}%',
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(_fmt(_whtAmount),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              Text('ر.س تُستقطع من الدفعة', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            children: [
              _line('المبلغ الإجمالي', _fmt(_amountV), core_theme.AC.tp),
              _line('يُستقطع WHT (${_rate.toStringAsFixed(0)}%)', '- ${_fmt(_whtAmount)}', core_theme.AC.err),
              const Divider(),
              _line('الصافي للمستفيد', _fmt(_netPayment), core_theme.AC.gold, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: core_theme.AC.info, size: 16),
                  SizedBox(width: 6),
                  Text('إلتزامات الإقرار', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                ],
              ),
              SizedBox(height: 6),
              Text('• إقرار WHT شهري — آخر يوم من الشهر التالي للدفع',
                  style: TextStyle(fontSize: 11, height: 1.7)),
              Text('• إقرار WHT سنوي — خلال 120 يوم من نهاية السنة المالية',
                  style: TextStyle(fontSize: 11, height: 1.7)),
              Text('• تحويل المبلغ إلى ZATCA قبل أو مع تقديم الإقرار',
                  style: TextStyle(fontSize: 11, height: 1.7)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('أُضيفت إلى إقرار ${_currentMonthAr()} — ${_fmt(_whtAmount)} ر.س'),
                  backgroundColor: const Color(0xFF4A148C),
                ),
              );
            },
            icon: const Icon(Icons.add_circle),
            label: Text('إضافة إلى الإقرار الشهري'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          Text(value,
              style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                color: color,
              )),
        ],
      ),
    );
  }

  Widget _inputCard(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _labeled(String label, Widget input) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            const SizedBox(height: 4),
            input,
          ],
        ),
      );

  InputDecoration _decor(String hint) => InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      );

  Widget _buildHistoryTab() {
    final history = const [
      _WhtEntry('2026-04-15', 'Oracle ME', 'خدمات فنية', 150000, 5, 7500, 'مدفوع'),
      _WhtEntry('2026-04-10', 'SAP Arabia', 'إتاوات', 380000, 15, 57000, 'مدفوع'),
      _WhtEntry('2026-04-05', 'McKinsey & Co.', 'أتعاب إدارية', 625000, 20, 125000, 'معلّق'),
      _WhtEntry('2026-03-28', 'Cisco Systems', 'خدمات فنية', 98000, 5, 4900, 'مدفوع'),
      _WhtEntry('2026-03-20', 'Allianz Re', 'تأمين وإعادة تأمين', 420000, 5, 21000, 'مدفوع'),
    ];
    final totalWht = history.fold(0.0, (s, e) => s + e.whtAmount);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('إجمالي WHT للشهر الحالي',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(_fmt(totalWht),
                  style: const TextStyle(color: Color(0xFFFFD700), fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              Text(' ر.س', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                color: core_theme.AC.navy3,
                child: const Row(
                  children: [
                    Expanded(child: Text('التاريخ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('المورد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الفئة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('المبلغ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('النسبة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('WHT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF4A148C)))),
                    Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final e in history)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.date, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      Expanded(flex: 2, child: Text(e.vendor, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text(e.category, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
                      Expanded(child: Text(_fmt(e.amount), style: const TextStyle(fontSize: 12))),
                      Expanded(child: Text('${e.rate}%', style: const TextStyle(fontSize: 12))),
                      Expanded(
                        child: Text(_fmt(e.whtAmount),
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF4A148C))),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: (e.status == 'مدفوع' ? core_theme.AC.ok : core_theme.AC.warn).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(e.status,
                              style: TextStyle(
                                fontSize: 10,
                                color: e.status == 'مدفوع' ? core_theme.AC.ok : core_theme.AC.warn,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('جاري تحضير إقرار WHT الشهري — ${_fmt(totalWht)} ر.س'),
                  backgroundColor: const Color(0xFF4A148C),
                ),
              );
            },
            icon: const Icon(Icons.send),
            label: Text('تقديم الإقرار الشهري إلى ZATCA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A148C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTreatiesTab() {
    final treaties = const [
      _Treaty('AE', 'الإمارات', 5, 5, 5, 'جميع الفئات: 5%'),
      _Treaty('BH', 'البحرين', 5, 5, 5, 'جميع الفئات: 5%'),
      _Treaty('GB', 'المملكة المتحدة', 5, 5, 8, 'إتاوات: 8%، فوائد: 0%'),
      _Treaty('FR', 'فرنسا', 5, 0, 0, 'الأفضل: 0% فوائد وإتاوات'),
      _Treaty('IN', 'الهند', 10, 10, 10, 'جميع الفئات: 10%'),
      _Treaty('US', 'الولايات المتحدة', 15, 15, 15, 'بدون اتفاقية — المعدل القياسي'),
      _Treaty('SG', 'سنغافورة', 5, 5, 8, 'إتاوات: 8%'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: core_theme.AC.warn,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.warn),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber, color: core_theme.AC.warn),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'لتطبيق معدل الاتفاقية، يجب الحصول على "شهادة الإقامة الضريبية" (Tax Residency Certificate) من دولة المستفيد مختومة خلال آخر 12 شهر. بدونها، يُطبّق المعدل القياسي.',
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
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: core_theme.AC.navy3,
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('الدولة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('أرباح', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('فوائد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('إتاوات', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 3, child: Text('ملاحظات', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final t in treaties)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(t.country, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                      Expanded(child: _ratePill(t.dividends, core_theme.AC.info)),
                      Expanded(child: _ratePill(t.interest, core_theme.AC.warn)),
                      Expanded(child: _ratePill(t.royalties, core_theme.AC.purple)),
                      Expanded(flex: 3, child: Text(t.notes, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ratePill(int rate, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text('$rate%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color), textAlign: TextAlign.center),
    );
  }

  String _currentMonthAr() {
    const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return '${months[DateTime.now().month - 1]} 2026';
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _WhtCategory {
  final String id;
  final String nameAr;
  final int standardRate;
  final List<String> treatyExamples;
  const _WhtCategory(this.id, this.nameAr, this.standardRate, this.treatyExamples);
}

class _WhtEntry {
  final String date;
  final String vendor;
  final String category;
  final double amount;
  final int rate;
  final double whtAmount;
  final String status;
  const _WhtEntry(this.date, this.vendor, this.category, this.amount, this.rate, this.whtAmount, this.status);
}

class _Treaty {
  final String code;
  final String country;
  final int dividends;
  final int interest;
  final int royalties;
  final String notes;
  const _Treaty(this.code, this.country, this.dividends, this.interest, this.royalties, this.notes);
}
