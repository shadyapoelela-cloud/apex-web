/// APEX Wave 58 — Customer 360.
/// Route: /app/erp/operations/customers-360
///
/// Unified customer view: sales, AR, activities, health.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class Customer360Screen extends StatefulWidget {
  const Customer360Screen({super.key});
  @override
  State<Customer360Screen> createState() => _Customer360ScreenState();
}

class _Customer360ScreenState extends State<Customer360Screen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  String _selectedId = 'CUS-0145';

  final _customers = const [
    _Cust('CUS-0145', 'أرامكو السعودية', 'KSA', 'طاقة', 4850000, 85, 'strategic'),
    _Cust('CUS-0089', 'سابك', 'KSA', 'بتروكيماويات', 3200000, 62, 'strategic'),
    _Cust('CUS-0213', 'شركة الاتصالات السعودية (STC)', 'KSA', 'اتصالات', 1450000, 38, 'enterprise'),
    _Cust('CUS-0178', 'مجموعة بن لادن السعودية', 'KSA', 'مقاولات', 820000, 22, 'enterprise'),
    _Cust('CUS-0298', 'دبي القابضة', 'UAE', 'استثمار', 560000, 15, 'enterprise'),
    _Cust('CUS-0342', 'معهد الإدارة العامة', 'KSA', 'حكومي', 180000, 8, 'government'),
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

  _Cust get _selected => _customers.firstWhere((c) => c.id == _selectedId);

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
                  Tab(icon: Icon(Icons.timeline, size: 16), text: 'النشاط'),
                  Tab(icon: Icon(Icons.receipt_long, size: 16), text: 'المبيعات والفواتير'),
                  Tab(icon: Icon(Icons.account_balance, size: 16), text: 'الذمم المدينة'),
                  Tab(icon: Icon(Icons.health_and_safety, size: 16), text: 'صحة العلاقة'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _buildActivityTab(),
                    _buildSalesTab(),
                    _buildARTab(),
                    _buildHealthTab(),
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
            child: Row(
              children: [
                Icon(Icons.groups, color: core_theme.AC.gold, size: 16),
                SizedBox(width: 6),
                Text('العملاء', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _customers.length,
              itemBuilder: (ctx, i) {
                final c = _customers[i];
                final selected = c.id == _selectedId;
                return InkWell(
                  onTap: () => setState(() => _selectedId = c.id),
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
                          radius: 16,
                          backgroundColor: _segmentColor(c.segment).withValues(alpha: 0.15),
                          child: Text(c.name.substring(0, 1),
                              style: TextStyle(color: _segmentColor(c.segment), fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Row(
                                children: [
                                  Text(c.id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
                                  const SizedBox(width: 6),
                                  Text('• ${c.country}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('${_fmtM(c.ytdRevenue.toDouble())} · ${c.invoiceCount} فاتورة',
                                  style: TextStyle(fontSize: 10, color: core_theme.AC.gold, fontWeight: FontWeight.w700)),
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
        gradient: LinearGradient(
          colors: [_segmentColor(_selected.segment), _segmentColor(_selected.segment).withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(_selected.name.substring(0, 2),
                style: TextStyle(color: _segmentColor(_selected.segment), fontSize: 20, fontWeight: FontWeight.w900)),
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
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_segmentLabel(_selected.segment),
                          style: TextStyle(
                              color: _segmentColor(_selected.segment),
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                Text('${_selected.id} · ${_selected.country} · ${_selected.industry}',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12, fontFamily: 'monospace')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('عميل منذ', style: TextStyle(color: core_theme.AC.ts, fontSize: 10)),
              Text('2019',
                  style: TextStyle(color: Color(0xFFFFD700), fontSize: 20, fontWeight: FontWeight.w900)),
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
          _kpi('الإيرادات YTD', _fmt(_selected.ytdRevenue.toDouble()), core_theme.AC.gold, Icons.trending_up),
          _kpi('عدد الفواتير', '${_selected.invoiceCount}', core_theme.AC.info, Icons.receipt),
          _kpi('متأخرات', '85,000', core_theme.AC.warn, Icons.warning_amber),
          _kpi('NPS', '82', core_theme.AC.ok, Icons.thumb_up),
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

  Widget _buildActivityTab() {
    final activities = const [
      _Act('meeting', '2026-04-18', 'اجتماع مراجعة فصلية', 'QBR — ناقشنا خطة الربع الثاني وفرص التوسع', 'سارة الدوسري'),
      _Act('email', '2026-04-15', 'بريد: عرض فني لمشروع جديد', 'أرسلت عرض SAP Integration بقيمة 1.8M ر.س', 'محمد القحطاني'),
      _Act('invoice', '2026-04-12', 'فاتورة INV-2026-0512', 'صدرت فاتورة بقيمة 485,000 ر.س — خدمات التوريد', 'النظام'),
      _Act('call', '2026-04-10', 'مكالمة متابعة مع CFO', 'مناقشة شروط الدفع والتمديد — استجابة إيجابية', 'أحمد العتيبي'),
      _Act('payment', '2026-04-05', 'تحصيل دفعة كبيرة', 'تم استلام 2.1M ر.س عن فواتير مارس — شكر من محاسبتهم', 'النظام'),
      _Act('proposal', '2026-03-28', 'تقديم عرض مشروع Smart City', 'عرض شامل لتكامل النظم — بقيمة 4.2M ر.س (قيد الدراسة)', 'فريق المبيعات'),
    ];
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      children: [
        for (final a in activities) _activityCard(a),
      ],
    );
  }

  Widget _activityCard(_Act a) {
    final color = _actColor(a.type);
    final icon = _actIcon(a.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(a.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text(a.date, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(a.detail, style: TextStyle(fontSize: 12, height: 1.5, color: core_theme.AC.tp)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 11, color: core_theme.AC.ts),
                    const SizedBox(width: 4),
                    Text(a.by, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    final invoices = const [
      _Inv('INV-2026-0512', '2026-04-12', 485000, 'مدفوع', 'خدمات توريد مواد'),
      _Inv('INV-2026-0488', '2026-04-05', 620000, 'مدفوع', 'عقود صيانة سنوية'),
      _Inv('INV-2026-0465', '2026-03-28', 825000, 'مدفوع', 'مشروع SAP Phase 2'),
      _Inv('INV-2026-0432', '2026-03-18', 340000, 'مدفوع', 'تدريب فرق تقنية'),
      _Inv('INV-2026-0412', '2026-03-12', 195000, 'قيد التحصيل', 'خدمات استشارية'),
      _Inv('INV-2026-0398', '2026-03-05', 85000, 'متأخر', 'رسوم إضافية لعقد'),
    ];
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      children: [
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
                    Expanded(flex: 2, child: Text('رقم الفاتورة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('التاريخ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 3, child: Text('الوصف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('المبلغ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.gold))),
                    Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final inv in invoices)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withValues(alpha: 0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(inv.number,
                            style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                      ),
                      Expanded(child: Text(inv.date, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts))),
                      Expanded(flex: 3, child: Text(inv.description, style: const TextStyle(fontSize: 12))),
                      Expanded(
                        flex: 2,
                        child: Text(_fmt(inv.amount.toDouble()),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: core_theme.AC.gold, fontFamily: 'monospace')),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: _invStatusColor(inv.status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(inv.status,
                              style: TextStyle(
                                fontSize: 10,
                                color: _invStatusColor(inv.status),
                                fontWeight: FontWeight.w800,
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
      ],
    );
  }

  Widget _buildARTab() {
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      children: [
        Row(
          children: [
            _arBucket('حالية', 0, 420000, core_theme.AC.ok),
            _arBucket('1-30 يوم', 1, 280000, core_theme.AC.info),
            _arBucket('31-60 يوم', 2, 125000, core_theme.AC.warn),
            _arBucket('61-90 يوم', 3, 60000, core_theme.AC.warn),
            _arBucket('> 90 يوم', 4, 25000, core_theme.AC.err),
          ],
        ),
        const SizedBox(height: 20),
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
                  Icon(Icons.schedule, color: core_theme.AC.warn),
                  SizedBox(width: 8),
                  Text('DSO — متوسط فترة التحصيل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text('الحالي:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 10),
                  Text('32 يوم',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: core_theme.AC.warn)),
                  const SizedBox(width: 20),
                  Text('الشروط المتفق عليها:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 10),
                  Text('45 يوم',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: core_theme.AC.ok)),
                ],
              ),
              const SizedBox(height: 8),
              Text('أداء التحصيل ممتاز — أسرع من المتفق عليه بـ 13 يوم',
                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الفواتير المتأخرة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              _overdueRow('INV-2026-0398', '85,000', 45),
              _overdueRow('INV-2025-2814', '60,000', 72),
              _overdueRow('INV-2025-2705', '25,000', 98),
            ],
          ),
        ),
      ],
    );
  }

  Widget _arBucket(String label, int bucket, double value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 8),
            Text(_fmt(value),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
            Text('ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _overdueRow(String inv, String amount, int days) {
    final severity = days > 90 ? core_theme.AC.err : days > 60 ? core_theme.AC.warn : core_theme.AC.warn;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: severity.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: severity.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 16, color: severity),
          const SizedBox(width: 8),
          Expanded(child: Text(inv, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700))),
          Text('$amount ر.س', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: severity,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('متأخر $days يوم',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: severity,
              side: BorderSide(color: severity),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              minimumSize: const Size(40, 26),
            ),
            child: Text('متابعة', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthTab() {
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 16, right: 20, bottom: 20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [core_theme.AC.ok, core_theme.AC.ok]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.sentiment_very_satisfied, color: Colors.white, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('علاقة صحيّة ومتنامية',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                    Text('نمو 24% في الإيرادات، NPS 82، تحصيل أسرع من المتفق عليه',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Text('A+',
                    style: TextStyle(color: core_theme.AC.ok, fontSize: 32, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _healthCard(
                'مؤشرات إيجابية',
                Icons.trending_up,
                core_theme.AC.ok,
                const [
                  'نمو 24% سنوياً في قيمة العقود',
                  'تحصيل أسرع من الشروط المتفق عليها (32 يوم مقابل 45)',
                  'لا شكاوى في آخر 18 شهر',
                  'تقييم NPS عالي (82)',
                  'اجتماعات فصلية منتظمة',
                  'المرجعية الأولى لعملاء محتملين',
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _healthCard(
                'مؤشرات تحذيرية',
                Icons.warning_amber,
                core_theme.AC.warn,
                const [
                  '3 فواتير متأخرة بإجمالي 170,000 ر.س',
                  'انخفاض نسبي في عروض الأسعار الجديدة (آخر 30 يوم)',
                  'تغيير CFO متوقع في Q2 2026',
                  'فرصة مشروع منافس مع PwC',
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
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
              Row(
                children: [
                  Icon(Icons.lightbulb, color: core_theme.AC.gold),
                  SizedBox(width: 8),
                  Text('توصيات AI للاحتفاظ بالعميل',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              _recommendation('جدولة اجتماع مع CFO الجديد خلال أسبوع من تعيينه',
                  'لتعزيز العلاقة مع الإدارة الجديدة'),
              _recommendation('تقديم عرض توسعة عقد الصيانة مع خصم ولاء 8%',
                  'الوقت المثالي — قبل بدء تقديم PwC لعروضهم'),
              _recommendation('متابعة الفواتير المتأخرة مع فريق حساباتهم',
                  'متابعة لطيفة — العلاقة إيجابية ولن يُشكّلوا مشكلة'),
              _recommendation('دعوة ممثل أرامكو لمؤتمر "APEX Insights 2026"',
                  'لتعزيز Brand loyalty وعرض Thought leadership'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _healthCard(String title, IconData icon, Color color, List<String> items) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 12, height: 1.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _recommendation(String title, String reason) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: core_theme.AC.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: core_theme.AC.gold.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: core_theme.AC.gold, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                Text(reason, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, height: 1.4)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child: Text('تنفيذ', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Color _segmentColor(String segment) {
    switch (segment) {
      case 'strategic':
        return core_theme.AC.gold;
      case 'enterprise':
        return core_theme.AC.info;
      case 'government':
        return core_theme.AC.info;
      default:
        return core_theme.AC.td;
    }
  }

  String _segmentLabel(String segment) {
    switch (segment) {
      case 'strategic':
        return 'إستراتيجي';
      case 'enterprise':
        return 'مؤسسي';
      case 'government':
        return 'حكومي';
      default:
        return segment;
    }
  }

  IconData _actIcon(String type) {
    switch (type) {
      case 'meeting':
        return Icons.event;
      case 'email':
        return Icons.email;
      case 'invoice':
        return Icons.receipt;
      case 'call':
        return Icons.phone;
      case 'payment':
        return Icons.payments;
      case 'proposal':
        return Icons.description;
      default:
        return Icons.circle;
    }
  }

  Color _actColor(String type) {
    switch (type) {
      case 'meeting':
        return core_theme.AC.purple;
      case 'email':
        return core_theme.AC.info;
      case 'invoice':
        return core_theme.AC.warn;
      case 'call':
        return core_theme.AC.info;
      case 'payment':
        return core_theme.AC.ok;
      case 'proposal':
        return core_theme.AC.gold;
      default:
        return core_theme.AC.td;
    }
  }

  Color _invStatusColor(String status) {
    switch (status) {
      case 'مدفوع':
        return core_theme.AC.ok;
      case 'قيد التحصيل':
        return core_theme.AC.info;
      case 'متأخر':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M ر.س';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K ر.س';
    return '${v.toStringAsFixed(0)} ر.س';
  }
}

class _Cust {
  final String id;
  final String name;
  final String country;
  final String industry;
  final int ytdRevenue;
  final int invoiceCount;
  final String segment;
  const _Cust(this.id, this.name, this.country, this.industry, this.ytdRevenue, this.invoiceCount, this.segment);
}

class _Act {
  final String type;
  final String date;
  final String title;
  final String detail;
  final String by;
  const _Act(this.type, this.date, this.title, this.detail, this.by);
}

class _Inv {
  final String number;
  final String date;
  final int amount;
  final String status;
  final String description;
  const _Inv(this.number, this.date, this.amount, this.status, this.description);
}
