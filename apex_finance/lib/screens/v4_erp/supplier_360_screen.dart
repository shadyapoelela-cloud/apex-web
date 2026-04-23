/// APEX Wave 57 — Supplier 360.
/// Route: /app/erp/operations/suppliers
///
/// Unified supplier master — profile, purchases, payments,
/// performance, AML screening.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class Supplier360Screen extends StatefulWidget {
  const Supplier360Screen({super.key});
  @override
  State<Supplier360Screen> createState() => _Supplier360ScreenState();
}

class _Supplier360ScreenState extends State<Supplier360Screen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _selectedId = 'SUP-0042';

  final _suppliers = const [
    _Supplier('SUP-0042', 'شركة سابك للمواد الأساسية', 'KSA', 'مواد خام', 4.7, 'Platinum', 2450000, 35),
    _Supplier('SUP-0018', 'Oracle Middle East FZ-LLC', 'UAE', 'تقنية', 4.5, 'Gold', 850000, 24),
    _Supplier('SUP-0065', 'النسما للمقاولات', 'KSA', 'خدمات مقاولات', 4.2, 'Gold', 1250000, 18),
    _Supplier('SUP-0089', 'مكتبة جرير', 'KSA', 'مكتبية', 4.8, 'Silver', 84000, 142),
    _Supplier('SUP-0112', 'STC - الاتصالات السعودية', 'KSA', 'اتصالات', 4.3, 'Gold', 480000, 12),
    _Supplier('SUP-0204', 'Cisco Systems International', 'Singapore', 'شبكات', 4.6, 'Gold', 325000, 8),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  _Supplier get _selected => _suppliers.firstWhere((s) => s.id == _selectedId);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 340, child: _buildSidebar()),
        Expanded(
          child: Column(
            children: [
              _buildHero(),
              _buildKpiRow(),
              TabBar(
                controller: _tab,
                labelColor: core_theme.AC.gold,
                unselectedLabelColor: core_theme.AC.ts,
                indicatorColor: core_theme.AC.gold,
                tabs: const [
                  Tab(icon: Icon(Icons.info, size: 16), text: 'الملف'),
                  Tab(icon: Icon(Icons.shopping_cart, size: 16), text: 'المشتريات'),
                  Tab(icon: Icon(Icons.payment, size: 16), text: 'المدفوعات'),
                  Tab(icon: Icon(Icons.star, size: 16), text: 'الأداء'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildProfileTab(),
                    _buildPurchasesTab(),
                    _buildPaymentsTab(),
                    _buildPerformanceTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 20, bottom: 20, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: core_theme.AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: core_theme.AC.navy3,
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.business, color: core_theme.AC.gold, size: 16),
                    SizedBox(width: 6),
                    Text('الموردون', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'بحث بالاسم أو الرقم',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _suppliers.length,
              itemBuilder: (ctx, i) {
                final s = _suppliers[i];
                final selected = s.id == _selectedId;
                return InkWell(
                  onTap: () => setState(() => _selectedId = s.id),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? core_theme.AC.gold.withValues(alpha: 0.12) : null,
                      border: Border(
                        bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5)),
                        right: BorderSide(
                          color: selected ? core_theme.AC.gold : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _tierColor(s.tier).withValues(alpha: 0.15),
                          child: Icon(Icons.business, color: _tierColor(s.tier), size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                              Row(
                                children: [
                                  Text(s.id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _tierColor(s.tier).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Text(s.tier,
                                        style: TextStyle(fontSize: 9, color: _tierColor(s.tier), fontWeight: FontWeight.w800)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.only(left: 10, top: 20, right: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF263238), Color(0xFF455A64)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Text(_selected.name.substring(0, 1),
                style: const TextStyle(color: Color(0xFF263238), fontSize: 24, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_selected.name,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _tierColor(_selected.tier),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_selected.tier,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                Text('${_selected.id} · ${_selected.country} · ${_selected.category}',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12, fontFamily: 'monospace')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 4),
                  Text(_selected.rating.toStringAsFixed(1),
                      style: const TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
              Text('تقييم الأداء', style: TextStyle(color: core_theme.AC.ts, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 12, right: 20),
      child: Row(
        children: [
          _kpi('إجمالي المشتريات YTD', _fmt(_selected.ytdVolume.toDouble()), core_theme.AC.gold, Icons.shopping_cart),
          _kpi('عدد الطلبات', '${_selected.orderCount}', core_theme.AC.info, Icons.receipt_long),
          _kpi('متوسط الطلب', _fmt(_selected.ytdVolume / _selected.orderCount), core_theme.AC.purple, Icons.trending_up),
          _kpi('أيام الدفع المستحقة', '45 يوم', core_theme.AC.warn, Icons.schedule),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _section('البيانات الأساسية', Icons.business, [
                _kv('الاسم التجاري', _selected.name),
                _kv('رقم المورد', _selected.id),
                _kv('دولة التسجيل', _selected.country),
                _kv('السجل التجاري', 'CR-4030023456'),
                _kv('الرقم الضريبي', '300123456700003'),
                _kv('الفئة', _selected.category),
                _kv('العملة', 'ر.س (SAR)'),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _section('التواصل', Icons.contact_mail, [
                _kv('جهة الاتصال', 'عبدالرحمن السلمي'),
                _kv('المنصب', 'مدير المبيعات الإستراتيجية'),
                _kv('الهاتف', '+966-13-350-1900'),
                _kv('البريد الإلكتروني', 'a.salmi@sabic.com'),
                _kv('العنوان', 'طريق الملك فهد، الرياض 11422'),
                _kv('الموقع', 'www.sabic.com'),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _section('البنك وشروط الدفع', Icons.account_balance, [
                _kv('البنك', 'البنك السعودي الفرنسي'),
                _kv('الآيبان', 'SA03 8000 0000 6080 1016 7519'),
                _kv('شروط الدفع', 'صافي 45 يوم'),
                _kv('طريقة الدفع', 'تحويل بنكي'),
                _kv('حد الائتمان', '5,000,000 ر.س'),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _section('الامتثال', Icons.verified, [
                _checkRow('فحص العقوبات الدولية', true),
                _checkRow('العقوبات المحلية (OFAC/UN)', true),
                _checkRow('AML — تصنيف منخفض المخاطر', true),
                _checkRow('شهادة سعودة سارية', true),
                _checkRow('شهادة الزكاة والدخل سارية', true),
                _checkRow('شهادة GOSI سارية', true),
              ]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _checkRow(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(passed ? Icons.check_circle : Icons.error, size: 16, color: passed ? core_theme.AC.ok : core_theme.AC.err),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (passed ? core_theme.AC.ok : core_theme.AC.err).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(passed ? 'مطابق' : 'منتهي',
                style: TextStyle(
                  fontSize: 10,
                  color: passed ? core_theme.AC.ok : core_theme.AC.err,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasesTab() {
    final orders = const [
      _Order('PO-2026-0892', '2026-04-15', 485000, 'مستلم', 'بولي بروبلين — 240 طن'),
      _Order('PO-2026-0854', '2026-04-08', 325000, 'قيد التسليم', 'إيثيلين — 180 طن'),
      _Order('PO-2026-0812', '2026-03-28', 620000, 'مستلم', 'ميثانول — 320 طن'),
      _Order('PO-2026-0778', '2026-03-22', 195000, 'مستلم', 'MEG — 80 طن'),
      _Order('PO-2026-0745', '2026-03-15', 825000, 'مستلم', 'بولي إيثيلين — 410 طن'),
    ];
    return ListView.builder(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      itemCount: orders.length,
      itemBuilder: (ctx, i) {
        final o = orders[i];
        final statusColor = o.status == 'مستلم' ? core_theme.AC.ok : core_theme.AC.warn;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Row(
            children: [
              Text(o.number, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              Text(o.date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
              const SizedBox(width: 12),
              Expanded(child: Text(o.item, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              Text(_fmt(o.amount.toDouble()),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
              Text(' ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(o.status,
                    style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentsTab() {
    final payments = const [
      _Payment('2026-04-18', 'PAY-2026-0245', 485000, 'البنك السعودي الفرنسي', 'منفّذ'),
      _Payment('2026-04-12', 'PAY-2026-0238', 620000, 'الراجحي', 'منفّذ'),
      _Payment('2026-04-05', 'PAY-2026-0229', 195000, 'الراجحي', 'منفّذ'),
      _Payment('2026-03-29', 'PAY-2026-0218', 825000, 'البنك الأهلي', 'منفّذ'),
      _Payment('2026-03-20', 'PAY-2026-0205', 340000, 'الراجحي', 'منفّذ'),
    ];
    final totalPaid = payments.fold(0, (s, p) => s + p.amount);
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [core_theme.AC.gold, Color(0xFFE6C200)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.payments, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('إجمالي المدفوعات المنفّذة (YTD)',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(_fmt(totalPaid.toDouble()),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
              Text(' ر.س', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (final p in payments)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: core_theme.AC.bdr),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: core_theme.AC.ok.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.check_circle, color: core_theme.AC.ok, size: 16),
                ),
                const SizedBox(width: 10),
                Text(p.date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                const SizedBox(width: 10),
                Text(p.ref, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(p.bank, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                const SizedBox(width: 12),
                Text(_fmt(p.amount.toDouble()),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
                Text(' ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPerformanceTab() {
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      children: [
        Row(
          children: [
            _perfCard('التسليم في الموعد', 97, core_theme.AC.ok),
            _perfCard('جودة المنتج', 4.8, core_theme.AC.info, suffix: '/5'),
            _perfCard('الالتزام بالسعر', 99, core_theme.AC.gold),
            _perfCard('سرعة الاستجابة', 92, core_theme.AC.purple),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مراجعات فريق المشتريات (آخر 5)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              _reviewRow('2026-04-15', 'محمد القحطاني', 5.0, 'تسليم ممتاز في الوقت — جودة تطابق المواصفات'),
              _reviewRow('2026-04-02', 'سارة الدوسري', 4.5, 'أسعار تنافسية — بعض التأخير في الشحنة الأخيرة'),
              _reviewRow('2026-03-18', 'فهد الشمري', 5.0, 'تعاون ممتاز في حل مشكلة جودة في دفعة واحدة'),
              _reviewRow('2026-03-05', 'لينا البكري', 4.5, 'الشروط التجارية مرنة'),
              _reviewRow('2026-02-22', 'أحمد العتيبي', 4.8, 'شريك استراتيجي — موثوق جداً'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _perfCard(String label, double value, Color color, {String suffix = '%'}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value.toString(),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, right: 2),
                  child: Text(suffix, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _reviewRow(String date, String reviewer, double rating, String comment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: core_theme.AC.navy3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
              const SizedBox(width: 10),
              Text(reviewer, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const Spacer(),
              for (var i = 0; i < 5; i++)
                Icon(
                  i < rating ? Icons.star : Icons.star_border,
                  size: 14,
                  color: const Color(0xFFFFD700),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(comment, style: TextStyle(fontSize: 11, color: core_theme.AC.tp, height: 1.4)),
        ],
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) {
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
          Row(
            children: [
              Icon(icon, color: core_theme.AC.gold, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(k, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.5))),
        ],
      ),
    );
  }

  Color _tierColor(String tier) {
    switch (tier) {
      case 'Platinum':
        return const Color(0xFF455A64);
      case 'Gold':
        return core_theme.AC.gold;
      case 'Silver':
        return const Color(0xFF9E9E9E);
      default:
        return Colors.brown;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Supplier {
  final String id;
  final String name;
  final String country;
  final String category;
  final double rating;
  final String tier;
  final int ytdVolume;
  final int orderCount;
  const _Supplier(this.id, this.name, this.country, this.category, this.rating, this.tier, this.ytdVolume, this.orderCount);
}

class _Order {
  final String number;
  final String date;
  final int amount;
  final String status;
  final String item;
  const _Order(this.number, this.date, this.amount, this.status, this.item);
}

class _Payment {
  final String date;
  final String ref;
  final int amount;
  final String bank;
  final String status;
  const _Payment(this.date, this.ref, this.amount, this.bank, this.status);
}
