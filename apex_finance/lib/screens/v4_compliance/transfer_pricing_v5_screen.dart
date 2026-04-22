/// APEX Wave 51 — Transfer Pricing (TP).
/// Route: /app/compliance/tax/tp
///
/// OECD BEPS / ZATCA / FTA — Master File, Local File,
/// Country-by-Country reporting, Arm's length testing.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class TransferPricingV5Screen extends StatefulWidget {
  const TransferPricingV5Screen({super.key});
  @override
  State<TransferPricingV5Screen> createState() => _TransferPricingV5ScreenState();
}

class _TransferPricingV5ScreenState extends State<TransferPricingV5Screen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildKpiRow(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.groups, size: 16), text: 'المعاملات بين الشركات'),
            Tab(icon: Icon(Icons.analytics, size: 16), text: 'اختبار السعر العادل'),
            Tab(icon: Icon(Icons.folder, size: 16), text: 'وثائق TP'),
            Tab(icon: Icon(Icons.public, size: 16), text: 'CbCR'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildRelatedPartiesTab(),
              _buildArmsLengthTab(),
              _buildDocumentsTab(),
              _buildCbcrTab(),
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
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('أسعار التحويل (Transfer Pricing)',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('OECD BEPS Actions 8-10/13 · ZATCA / FTA — مبدأ السعر العادل Arm\'s Length',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('معاملات بين الشركات', '34', core_theme.AC.info, Icons.groups),
          _kpi('قيمة المعاملات', '125M', core_theme.AC.gold, Icons.attach_money),
          _kpi('مطابق للسعر العادل', '28', core_theme.AC.ok, Icons.check_circle),
          _kpi('يحتاج مراجعة', '6', core_theme.AC.warn, Icons.warning),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRelatedPartiesTab() {
    final txns = const [
      _RpTxn('RP-2025-001', 'APEX Holding KSA', 'APEX Dubai LLC', 'خدمات إدارية', 8500000, 'CUP', true),
      _RpTxn('RP-2025-002', 'APEX Holding KSA', 'APEX Manufacturing India', 'شراء سلع نهائية', 24200000, 'RPM', true),
      _RpTxn('RP-2025-003', 'APEX Dubai LLC', 'APEX Singapore Pte', 'ترخيص علامة تجارية', 4800000, 'CUT', false),
      _RpTxn('RP-2025-004', 'APEX Holding KSA', 'APEX Technology UK', 'خدمات تقنية', 6200000, 'TNMM', true),
      _RpTxn('RP-2025-005', 'APEX Holding KSA', 'APEX Logistics Bahrain', 'خدمات لوجستية', 2100000, 'CP', true),
      _RpTxn('RP-2025-006', 'APEX Dubai LLC', 'APEX Holding KSA', 'قرض داخل المجموعة', 15000000, 'CUP', false),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: txns.length,
      itemBuilder: (ctx, i) {
        final t = txns[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: (t.armsLength ? core_theme.AC.ok : core_theme.AC.warn).withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(t.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: core_theme.AC.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(t.method,
                        style: TextStyle(fontSize: 11, color: core_theme.AC.purple, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (t.armsLength ? core_theme.AC.ok : core_theme.AC.warn).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.armsLength ? Icons.check_circle : Icons.warning,
                            size: 12, color: t.armsLength ? core_theme.AC.ok : core_theme.AC.warn),
                        const SizedBox(width: 4),
                        Text(
                          t.armsLength ? 'مطابق' : 'يحتاج مراجعة',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: t.armsLength ? core_theme.AC.ok : core_theme.AC.warn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(t.type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.north_east, size: 14, color: core_theme.AC.info),
                        const SizedBox(width: 4),
                        Expanded(child: Text(t.from, style: TextStyle(fontSize: 12, color: core_theme.AC.ts))),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward, size: 14, color: core_theme.AC.td),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Row(
                        children: [
                          Icon(Icons.south_west, size: 14, color: core_theme.AC.ok),
                          const SizedBox(width: 4),
                          Expanded(child: Text(t.to, style: TextStyle(fontSize: 12, color: core_theme.AC.ts))),
                        ],
                      ),
                    ),
                  ),
                  Text(_fmt(t.amount),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
                  const SizedBox(width: 4),
                  Text('ر.س', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArmsLengthTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
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
                  'اختيار الطريقة الأنسب وفقاً لـ OECD TP Guidelines: CUP (المقارن غير المرتبط)، RPM (سعر إعادة البيع)، CP (التكلفة زائد)، TNMM (صافي الهامش)، PSM (تجزئة الربح).',
                  style: TextStyle(fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('المعاملة قيد الفحص: RP-2025-003', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        Text('ترخيص علامة تجارية — APEX Dubai → APEX Singapore', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
        const SizedBox(height: 16),
        _benchmarkCard(),
        const SizedBox(height: 16),
        _conclusionCard(),
      ],
    );
  }

  Widget _benchmarkCard() {
    final comparables = const [
      _Comp('شركة A (أمريكية)', 4.2, 'ترخيص علامة FMCG'),
      _Comp('شركة B (أوروبية)', 5.1, 'ترخيص قطاع الأغذية'),
      _Comp('شركة C (آسيوية)', 3.8, 'ترخيص إقليمي'),
      _Comp('شركة D (أمريكية)', 5.5, 'ترخيص علامة عالمية'),
      _Comp('شركة E (شرق أوسط)', 4.8, 'ترخيص إقليمي'),
      _Comp('شركة F (أوروبية)', 4.5, 'ترخيص متعدد الفئات'),
    ];
    final rates = comparables.map((c) => c.rate).toList()..sort();
    final q1 = rates[1];
    final median = (rates[2] + rates[3]) / 2;
    final q3 = rates[4];
    const actualRate = 4.7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('دراسة المقارنات (Benchmarking Study)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          Text('6 شركات مقارنة من قاعدة بيانات Amadeus/Orbis', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 16),
          for (final c in comparables)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(c.name, style: const TextStyle(fontSize: 12))),
                  Expanded(child: Text(c.description, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: core_theme.AC.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${c.rate}%',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: core_theme.AC.info)),
                  ),
                ],
              ),
            ),
          const Divider(height: 24),
          Text('النطاق العادل (Arm\'s Length Range)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          _rangeChip('Q1 (25%)', q1, core_theme.AC.info),
          _rangeChip('الوسيط (Median)', median, core_theme.AC.gold),
          _rangeChip('Q3 (75%)', q3, core_theme.AC.info),
          const Divider(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: core_theme.AC.ok,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: core_theme.AC.ok),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: core_theme.AC.ok),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('السعر الفعلي: 4.7%', style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('داخل النطاق العادل — متوافق', style: TextStyle(fontSize: 11, color: core_theme.AC.ok)),
                    ],
                  ),
                ),
                Text('✓', style: TextStyle(fontSize: 24, color: core_theme.AC.ok, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeChip(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 12))),
          Expanded(
            child: LinearProgressIndicator(
              value: value / 10,
              backgroundColor: core_theme.AC.bdr,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 10),
          Text('${value.toStringAsFixed(2)}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _conclusionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: core_theme.AC.ok,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.ok),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: core_theme.AC.ok),
              SizedBox(width: 8),
              Text('الاستنتاج', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: core_theme.AC.ok)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'بناءً على اختبار CUT مع 6 شركات مقارنة من الصناعة نفسها، الرسوم المدفوعة (4.7%) تقع داخل النطاق العادل (3.8% - 5.5%) — المعاملة متوافقة مع مبدأ السعر العادل ولا تحتاج تعديل.',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    final docs = const [
      _Doc('Master File 2025', 'وثيقة رئيسية للمجموعة — هيكل، أنشطة، قيم، سياسات TP', 'مكتمل', 125, '2026-03-15'),
      _Doc('Local File — KSA 2025', 'ملف محلي — أنشطة APEX KSA + المعاملات المرتبطة', 'مكتمل', 245, '2026-03-20'),
      _Doc('Local File — UAE 2025', 'ملف محلي — أنشطة APEX Dubai + المعاملات', 'قيد الإعداد', 180, null),
      _Doc('CbCR Notification 2025', 'إشعار هيئة الزكاة عن جهة الإبلاغ', 'مكتمل', 3, '2026-02-28'),
      _Doc('TP Disclosure Form', 'نموذج إفصاح سنوي مرفق بإقرار ضريبة الدخل', 'مكتمل', 12, '2026-04-10'),
      _Doc('Benchmarking Study 2025', 'دراسات مقارنات لجميع المعاملات الرئيسية', 'قيد الإعداد', 95, null),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: docs.length,
      itemBuilder: (ctx, i) {
        final d = docs[i];
        final done = d.status == 'مكتمل';
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (done ? core_theme.AC.ok : core_theme.AC.warn).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  done ? Icons.description : Icons.edit_document,
                  color: done ? core_theme.AC.ok : core_theme.AC.warn,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(d.description, style: TextStyle(fontSize: 12, color: core_theme.AC.ts, height: 1.4)),
                    Row(
                      children: [
                        Icon(Icons.description, size: 12, color: core_theme.AC.td),
                        const SizedBox(width: 4),
                        Text('${d.pages} صفحة', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                        if (d.submittedAt != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.send, size: 12, color: core_theme.AC.ok),
                          const SizedBox(width: 4),
                          Text('قُدّم ${d.submittedAt}', style: TextStyle(fontSize: 10, color: core_theme.AC.ok)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (done ? core_theme.AC.ok : core_theme.AC.warn).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(d.status,
                        style: TextStyle(fontSize: 11, color: done ? core_theme.AC.ok : core_theme.AC.warn, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: const Icon(Icons.download, size: 18),
                    onPressed: () {},
                    tooltip: 'تحميل',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCbcrTab() {
    final countries = const [
      _CbcrRow('المملكة العربية السعودية 🇸🇦', 185_000_000, 48_200_000, 185, 'APEX Holding KSA'),
      _CbcrRow('الإمارات العربية المتحدة 🇦🇪', 72_000_000, 12_400_000, 42, 'APEX Dubai LLC'),
      _CbcrRow('الهند 🇮🇳', 48_500_000, 8_600_000, 256, 'APEX Manufacturing India'),
      _CbcrRow('سنغافورة 🇸🇬', 18_400_000, 3_200_000, 28, 'APEX Singapore Pte'),
      _CbcrRow('المملكة المتحدة 🇬🇧', 22_800_000, 4_100_000, 35, 'APEX Technology UK'),
      _CbcrRow('البحرين 🇧🇭', 8_500_000, 1_250_000, 18, 'APEX Logistics Bahrain'),
    ];
    final totalRevenue = countries.fold(0, (s, c) => s + c.revenue.toInt());
    final totalPbt = countries.fold(0, (s, c) => s + c.pbt.toInt());
    final totalEmp = countries.fold(0, (s, c) => s + c.employees);

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
                  'Country-by-Country Reporting إلزامي للمجموعات متعددة الجنسيات ذات الإيرادات المجمّعة ≥ 3.2 مليار ريال سعودي (750M EUR).',
                  style: TextStyle(fontSize: 12, height: 1.5),
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
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('الدولة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الكيان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الإيرادات', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(flex: 2, child: Text('الربح قبل الضريبة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('الموظفون', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                    Expanded(child: Text('هامش', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
              for (final c in countries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: core_theme.AC.bdr.withOpacity(0.5))),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(c.country, style: const TextStyle(fontSize: 12))),
                      Expanded(flex: 2, child: Text(c.entity, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      Expanded(flex: 2, child: Text(_fmtM(c.revenue), style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                      Expanded(flex: 2, child: Text(_fmtM(c.pbt),
                          style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: core_theme.AC.gold, fontWeight: FontWeight.w700))),
                      Expanded(child: Text('${c.employees}', style: const TextStyle(fontSize: 12))),
                      Expanded(
                        child: Text('${(c.pbt / c.revenue * 100).toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: core_theme.AC.info)),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(12),
                color: core_theme.AC.navy3,
                child: Row(
                  children: [
                    const Expanded(flex: 4, child: Text('الإجماليات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12))),
                    Expanded(flex: 2, child: Text(_fmtM(totalRevenue.toDouble()), style: const TextStyle(fontWeight: FontWeight.w900, fontFamily: 'monospace'))),
                    Expanded(flex: 2, child: Text(_fmtM(totalPbt.toDouble()), style: TextStyle(fontWeight: FontWeight.w900, fontFamily: 'monospace', color: core_theme.AC.gold))),
                    Expanded(child: Text('$totalEmp', style: const TextStyle(fontWeight: FontWeight.w900))),
                    Expanded(child: Text('${(totalPbt / totalRevenue * 100).toStringAsFixed(1)}%',
                        style: TextStyle(fontWeight: FontWeight.w900, color: core_theme.AC.info))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.send),
            label: Text('تقديم CbCR إلى ZATCA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K';
    return v.toStringAsFixed(0);
  }
}

class _RpTxn {
  final String id;
  final String from;
  final String to;
  final String type;
  final double amount;
  final String method;
  final bool armsLength;
  const _RpTxn(this.id, this.from, this.to, this.type, this.amount, this.method, this.armsLength);
}

class _Comp {
  final String name;
  final double rate;
  final String description;
  const _Comp(this.name, this.rate, this.description);
}

class _Doc {
  final String title;
  final String description;
  final String status;
  final int pages;
  final String? submittedAt;
  const _Doc(this.title, this.description, this.status, this.pages, this.submittedAt);
}

class _CbcrRow {
  final String country;
  final double revenue;
  final double pbt;
  final int employees;
  final String entity;
  const _CbcrRow(this.country, this.revenue, this.pbt, this.employees, this.entity);
}
