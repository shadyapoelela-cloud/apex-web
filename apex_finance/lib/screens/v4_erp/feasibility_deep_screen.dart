/// APEX Wave 25 — Feasibility Deep (Market Analysis + Sensitivity).
///
/// Route: /app/advisory/feasibility/market + /sensitivity
library;

import 'package:flutter/material.dart';

import '../../core/v5/apex_v5_undo_toast.dart';

class FeasibilityMarketScreen extends StatefulWidget {
  const FeasibilityMarketScreen({super.key});

  @override
  State<FeasibilityMarketScreen> createState() => _FeasibilityMarketScreenState();
}

class _FeasibilityMarketScreenState extends State<FeasibilityMarketScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          _tabBtn(0, 'TAM/SAM/SOM', Icons.public),
          _tabBtn(1, 'المنافسون', Icons.groups),
          _tabBtn(2, 'نموذج الطلب', Icons.trending_up),
          _tabBtn(3, 'PESTEL', Icons.account_tree),
          _tabBtn(4, 'Porter 5 قوى', Icons.scatter_plot),
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0).withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFF1565C0).withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF1565C0) : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? const Color(0xFF1565C0) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _buildTamSamSom();
      case 1: return _buildCompetitors();
      case 2: return _buildDemandModel();
      case 3: return _buildPestel();
      case 4: return _buildPorter();
      default: return const SizedBox();
    }
  }

  Widget _buildTamSamSom() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.public, color: Colors.white, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تحليل السوق — TAM / SAM / SOM', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('حجم السوق الإجمالي · القابل للعنونة · المستهدف', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Concentric circles visualization
          Center(
            child: Container(
              width: 480,
              height: 480,
              padding: const EdgeInsets.all(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _circle(480, const Color(0xFF1565C0).withOpacity(0.12), const Color(0xFF1565C0)),
                  _circle(320, const Color(0xFF7C3AED).withOpacity(0.18), const Color(0xFF7C3AED)),
                  _circle(160, const Color(0xFF059669).withOpacity(0.25), const Color(0xFF059669)),
                  Positioned(
                    top: 20,
                    child: _circleLabel('TAM', '12 مليار ر.س', 'الإمارات + السعودية', const Color(0xFF1565C0)),
                  ),
                  Positioned(
                    top: 120,
                    child: _circleLabel('SAM', '3.8 مليار ر.س', 'SMB في KSA', const Color(0xFF7C3AED)),
                  ),
                  _circleLabel('SOM', '420 مليون ر.س', 'استهدافنا خلال 3 سنوات', const Color(0xFF059669), center: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _tamRow('TAM', 'Total Addressable Market', 'كل شركات المحاسبة في الخليج', '12,000M ر.س', const Color(0xFF1565C0)),
                _tamRow('SAM', 'Serviceable Addressable Market', 'SMBs في KSA بميزانية >50K/yr', '3,800M ر.س', const Color(0xFF7C3AED)),
                _tamRow('SOM', 'Serviceable Obtainable Market', 'حصّتنا المستهدفة بعد 3 سنوات', '420M ر.س (11%)', const Color(0xFF059669)),
                const Divider(),
                _tamRow('CAGR', 'معدل النمو السنوي المركّب', 'السوق ينمو 18% سنوياً', '18%', const Color(0xFFD4AF37)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color fill, Color border) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fill, border: Border.all(color: border, width: 2)),
    );
  }

  Widget _circleLabel(String label, String value, String desc, Color color, {bool center = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          Text(desc, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _tamRow(String abbr, String full, String desc, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(abbr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(full, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildCompetitors() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('تحليل المنافسين', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 1000 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 1.4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _compCard('Wafeq', 'SaaS سحابي', 'KSA + UAE', 'متوسط', 'ZATCA + Arabic', 'أسعار مرتفعة · محدود في Audit'),
                  _compCard('Qoyod', 'SaaS سحابي', 'KSA فقط', 'متوسط', 'بسيط للمحاسبة الصغيرة', 'قيود محاسبية فقط · لا ERP'),
                  _compCard('Odoo', 'مفتوح المصدر', 'عالمي', 'عالي', 'شامل ERP', 'تخصيص مكلف · ليس عربي أصيل'),
                  _compCard('SAP S/4HANA', 'Enterprise', 'عالمي', 'عالي جداً', 'قوي للشركات الكبيرة', 'تكلفة ضخمة · لا SMB'),
                  _compCard('QuickBooks', 'SaaS SMB', 'US + UAE', 'متوسط', 'UX بسيط', 'لا دعم ZATCA · لا عربي كامل'),
                  _compCard('APEX', '⭐ نحن', 'GCC + MENA', 'شامل', 'ZATCA + GCC Tax + Arabic-first', 'منصّتنا الجديدة', self: true),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _compCard(String name, String type, String region, String strength, String goodAt, String weakness, {bool self = false}) {
    final color = self ? const Color(0xFFD4AF37) : const Color(0xFF1565C0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: self ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
              const Spacer(),
              if (self) const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
            ],
          ),
          const SizedBox(height: 4),
          Text(type, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 8),
          _compMeta('المنطقة', region),
          _compMeta('القوة', strength),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                const Icon(Icons.add_circle, size: 11, color: Color(0xFF059669)),
                const SizedBox(width: 4),
                Expanded(child: Text(goodAt, style: const TextStyle(fontSize: 10, color: Color(0xFF059669)))),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFFB91C1C).withOpacity(0.06), borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                const Icon(Icons.remove_circle, size: 11, color: Color(0xFFB91C1C)),
                const SizedBox(width: 4),
                Expanded(child: Text(weakness, style: const TextStyle(fontSize: 10, color: Color(0xFFB91C1C)))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compMeta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54))),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildDemandModel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('نموذج توقّع الطلب — 5 سنوات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
            child: Column(
              children: [
                _demandHeader(),
                _demandRow('2026', 2500, 12000000, 'نمو أوّلي · تسويق'),
                _demandRow('2027', 5800, 29000000, 'توسّع في UAE'),
                _demandRow('2028', 11200, 58000000, 'شراكة مع البنوك'),
                _demandRow('2029', 18500, 96000000, 'BH + OM + QA'),
                _demandRow('2030', 28000, 151000000, 'قيادة السوق'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF1565C0)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.trending_up, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('CAGR 5-Year: 83%', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                      Text('نمو متسارع — 11× خلال 5 سنوات', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _demandHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06)))),
      child: const Row(
        children: [
          Expanded(child: Text('السنة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text('العملاء', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(flex: 2, child: Text('الإيرادات (ر.س)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(flex: 2, child: Text('المحرّك', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _demandRow(String year, int customers, double revenue, String driver) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04)))),
      child: Row(
        children: [
          Expanded(child: Text(year, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
          Expanded(child: Text('$customers', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Expanded(flex: 2, child: Text('${(revenue / 1000000).toStringAsFixed(0)}M', style: const TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: Color(0xFF059669)))),
          Expanded(flex: 2, child: Text(driver, style: const TextStyle(fontSize: 11, color: Colors.black54))),
        ],
      ),
    );
  }

  Widget _buildPestel() {
    final factors = [
      _Factor('P', 'سياسي (Political)', 'دعم حكومي للتحوّل الرقمي', 'positive', const Color(0xFF2563EB)),
      _Factor('E', 'اقتصادي (Economic)', 'تنوّع الاقتصاد السعودي (رؤية 2030)', 'positive', const Color(0xFF059669)),
      _Factor('S', 'اجتماعي (Social)', 'ارتفاع نسبة الشباب والسعودة', 'positive', const Color(0xFFD4AF37)),
      _Factor('T', 'تكنولوجي (Technological)', 'بنية تحتية رقمية متقدّمة', 'positive', const Color(0xFF7C3AED)),
      _Factor('E', 'بيئي (Environmental)', 'توجّه نحو ESG والاستدامة', 'neutral', const Color(0xFFD97706)),
      _Factor('L', 'قانوني (Legal)', 'ZATCA + جديد FTA — تغييرات متسارعة', 'opportunity', const Color(0xFFB91C1C)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PESTEL Analysis', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final f in factors)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: f.color.withOpacity(0.3))),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: f.color, borderRadius: BorderRadius.circular(8)),
                    child: Text(f.letter, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        Text(f.factor, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: f.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      f.impact == 'positive' ? 'إيجابي' : f.impact == 'opportunity' ? 'فرصة' : 'محايد',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: f.color),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPorter() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('قوى بورتر الخمس', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final force in [
            _Force('تهديد الداخلين الجدد', 'متوسط', 0.5, 'حواجز دخول معتدلة · رؤوس أموال متوفّرة', const Color(0xFFD97706)),
            _Force('قوة المشترين', 'عالية', 0.8, 'عملاء يقارنون بين عدة خيارات · حساسية للسعر', const Color(0xFFB91C1C)),
            _Force('قوة الموردين', 'منخفضة', 0.2, 'مزوّدو الـ cloud متنافسون · قليلة الاحتكار', const Color(0xFF059669)),
            _Force('تهديد البدائل', 'متوسط', 0.5, 'Excel + المحاسب التقليدي لا يزالان بديلاً', const Color(0xFFD97706)),
            _Force('كثافة المنافسة', 'عالية', 0.9, '5+ منصّات إقليمية نشطة + عالميين', const Color(0xFFB91C1C)),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(force.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: force.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                        child: Text(force.level, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: force.color)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: force.value, backgroundColor: Colors.black.withOpacity(0.06), valueColor: AlwaysStoppedAnimation(force.color), minHeight: 6),
                  const SizedBox(height: 6),
                  Text(force.note, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2))),
            child: const Row(
              children: [
                Icon(Icons.insights, color: Color(0xFF1565C0), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'الخلاصة: السوق جذّاب لكن تنافسي — النجاح يتطلّب تمييز واضح (APEX: Arabic-first + ZATCA عميق)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Factor {
  final String letter, category, factor, impact;
  final Color color;
  _Factor(this.letter, this.category, this.factor, this.impact, this.color);
}

class _Force {
  final String name, level, note;
  final double value;
  final Color color;
  _Force(this.name, this.level, this.value, this.note, this.color);
}

/// Wave 26 — External Analysis (Benchmarking + Credit).
class ExternalAnalysisScreen extends StatefulWidget {
  const ExternalAnalysisScreen({super.key});

  @override
  State<ExternalAnalysisScreen> createState() => _ExternalAnalysisScreenState();
}

class _ExternalAnalysisScreenState extends State<ExternalAnalysisScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08))),
          ),
          child: Row(
            children: [
              _tabBtn(0, 'القطاع', Icons.business),
              _tabBtn(1, 'مجموعة النظراء', Icons.groups),
              _tabBtn(2, 'رسم Quartile', Icons.bar_chart),
              _tabBtn(3, 'Z-Score / Altman', Icons.psychology),
              _tabBtn(4, 'التصنيف الائتماني', Icons.credit_score),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1565C0).withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFF1565C0).withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF1565C0) : Colors.black54),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? const Color(0xFF1565C0) : Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _sector();
      case 1: return _peerSet();
      case 2: return _quartile();
      case 3: return _zScore();
      case 4: return _creditRating();
      default: return const SizedBox();
    }
  }

  Widget _sector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('اختر القطاع للمقارنة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 1.3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _sectorCard('التجزئة', Icons.shopping_bag, 47, true),
                  _sectorCard('التصنيع', Icons.precision_manufacturing, 32, false),
                  _sectorCard('الخدمات المالية', Icons.account_balance, 28, false),
                  _sectorCard('التقنية', Icons.computer, 65, false),
                  _sectorCard('الضيافة', Icons.hotel, 19, false),
                  _sectorCard('الرعاية الصحية', Icons.medical_services, 23, false),
                  _sectorCard('اللوجستيات', Icons.local_shipping, 41, false),
                  _sectorCard('البناء', Icons.construction, 58, false),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _sectorCard(String name, IconData icon, int count, bool selected) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1565C0).withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? const Color(0xFF1565C0) : Colors.black.withOpacity(0.08), width: selected ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: selected ? const Color(0xFF1565C0) : Colors.black54),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          Text('$count شركة متاحة', style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const Spacer(),
          if (selected)
            const Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Color(0xFF1565C0)),
                SizedBox(width: 4),
                Text('محدّد', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w700)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _peerSet() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('مجموعة النظراء — التجزئة السعودية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 14),
                label: const Text('إضافة نظير'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final p in [
            _Peer('Jarir Marketing', 'مكتبة Jarir', 3400, 14.2, 8.5),
            _Peer('Extra', 'eXtra Stores', 2800, 11.8, 7.2),
            _Peer('SACO', 'SACO Hardware', 1900, 10.5, 6.1),
            _Peer('Panda Retail', 'بنده', 6200, 9.8, 5.4),
            _Peer('Target Co — شركة التحليل', 'الهدف', 1250, 13.1, 7.8, self: true),
          ])
            _peerRow(p),
        ],
      ),
    );
  }

  Widget _peerRow(_Peer p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.self ? const Color(0xFFD4AF37).withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: p.self ? const Color(0xFFD4AF37) : Colors.black.withOpacity(0.08), width: p.self ? 2 : 1),
      ),
      child: Row(
        children: [
          if (p.self) const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18),
          if (p.self) const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(p.brand, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الإيرادات', style: TextStyle(fontSize: 9, color: Colors.black54)),
                Text('${p.revenue}M', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('هامش Gross', style: TextStyle(fontSize: 9, color: Colors.black54)),
                Text('${p.grossMargin}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF059669), fontFamily: 'monospace')),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('EBITDA %', style: TextStyle(fontSize: 9, color: Colors.black54)),
                Text('${p.ebitda}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1565C0), fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quartile() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('المقارنة المرجعية — Quartile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final m in [
            _Metric('هامش إجمالي الربح', 13.1, 9.8, 11.8, 14.2, '%'),
            _Metric('هامش EBITDA', 7.8, 5.4, 7.2, 8.5, '%'),
            _Metric('العائد على الأصول (ROA)', 12.3, 8.5, 11.1, 14.8, '%'),
            _Metric('نسبة التداول', 1.9, 1.4, 1.7, 2.2, 'x'),
            _Metric('DSO', 42, 28, 38, 55, 'يوم'),
          ])
            _metricRow(m),
        ],
      ),
    );
  }

  Widget _metricRow(_Metric m) {
    final isBetter = m.value >= m.q2;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                '${m.value} ${m.unit}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isBetter ? const Color(0xFF059669) : const Color(0xFFD97706), fontFamily: 'monospace'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Quartile bar
          Stack(
            children: [
              Container(height: 12, decoration: BoxDecoration(color: Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(6))),
              Row(
                children: [
                  Expanded(child: Container(height: 12, color: const Color(0xFFB91C1C).withOpacity(0.3))),
                  Expanded(child: Container(height: 12, color: const Color(0xFFD97706).withOpacity(0.3))),
                  Expanded(child: Container(height: 12, color: const Color(0xFF059669).withOpacity(0.3))),
                  Expanded(child: Container(height: 12, color: const Color(0xFF2563EB).withOpacity(0.3))),
                ],
              ),
              // Marker
              Positioned(
                left: _markerPos(m.value, m.q1, m.q3) * 0.9 + 0.05,
                child: Container(
                  width: 3,
                  height: 16,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Q1: ${m.q1}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
              const Spacer(),
              Text('Median: ${m.q2}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
              const Spacer(),
              Text('Q3: ${m.q3}', style: const TextStyle(fontSize: 10, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  double _markerPos(double value, double q1, double q3) {
    final range = q3 - q1;
    if (range == 0) return 0.5;
    return ((value - q1) / range).clamp(0.0, 1.0);
  }

  Widget _zScore() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF1565C0)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.psychology, color: Colors.white, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Altman Z-Score', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('نموذج التنبّؤ بالإفلاس', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('3.42', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
                    Text('آمنة ✓', style: TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('مكوّنات Z-Score', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _zFactor('X1', 'رأس المال العامل / إجمالي الأصول', 0.18, 0.85),
          _zFactor('X2', 'الأرباح المحتجزة / إجمالي الأصول', 0.22, 0.75),
          _zFactor('X3', 'EBIT / إجمالي الأصول', 0.15, 0.92),
          _zFactor('X4', 'القيمة السوقية لحقوق الملكية / الديون', 0.8, 0.68),
          _zFactor('X5', 'المبيعات / إجمالي الأصول', 1.2, 0.55),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('التفسير', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _zRange('Z > 2.99', 'آمن — احتمال الإفلاس منخفض', const Color(0xFF059669), active: true),
                _zRange('1.81 < Z < 2.99', 'منطقة رمادية — يحتاج تحليل أعمق', const Color(0xFFD97706)),
                _zRange('Z < 1.81', 'خطر عالي على الاستمرارية', const Color(0xFFB91C1C)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zFactor(String code, String desc, double weight, double progress) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black.withOpacity(0.08))),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(3)),
            child: Text(code, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(desc, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: progress, backgroundColor: Colors.black.withOpacity(0.06), valueColor: const AlwaysStoppedAnimation(Color(0xFF1565C0)), minHeight: 4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('× ${weight.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _zRange(String range, String desc, Color color, {bool active = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: active ? color.withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(4),
        border: active ? Border.all(color: color) : null,
      ),
      child: Row(
        children: [
          Icon(active ? Icons.check_circle : Icons.circle_outlined, color: color, size: 14),
          const SizedBox(width: 8),
          Text(range, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _creditRating() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFFD4AF37)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: const Text('A', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF059669))),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تصنيف ائتماني ممتاز', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('احتمال التخلّف عن السداد < 2% خلال 12 شهر', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('مقياس التصنيف', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final r in [
            _Rating('AAA', 'ممتاز جداً', '<0.01%', const Color(0xFF059669)),
            _Rating('AA', 'ممتاز', '<0.05%', const Color(0xFF059669)),
            _Rating('A', 'جيد جداً', '<0.10%', const Color(0xFF059669), active: true),
            _Rating('BBB', 'جيد', '<0.50%', const Color(0xFF1565C0)),
            _Rating('BB', 'مقبول — مضاربي', '<2.00%', const Color(0xFFD97706)),
            _Rating('B', 'ضعيف', '<5.00%', const Color(0xFFD97706)),
            _Rating('CCC', 'ضعيف جداً', '<15.00%', const Color(0xFFB91C1C)),
            _Rating('D', 'متعثّر', '100%', const Color(0xFFB91C1C)),
          ])
            _ratingRow(r),
        ],
      ),
    );
  }

  Widget _ratingRow(_Rating r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: r.active ? r.color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: r.active ? r.color : Colors.black.withOpacity(0.08), width: r.active ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: r.color, borderRadius: BorderRadius.circular(4)),
            child: Text(r.code, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(r.desc, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Text('PD: ${r.pd}', style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace')),
          if (r.active) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle, color: r.color, size: 16),
          ],
        ],
      ),
    );
  }
}

class _Peer {
  final String name, brand;
  final int revenue;
  final double grossMargin, ebitda;
  final bool self;
  _Peer(this.name, this.brand, this.revenue, this.grossMargin, this.ebitda, {this.self = false});
}

class _Metric {
  final String name;
  final double value, q1, q2, q3;
  final String unit;
  _Metric(this.name, this.value, this.q1, this.q2, this.q3, this.unit);
}

class _Rating {
  final String code, desc, pd;
  final Color color;
  final bool active;
  _Rating(this.code, this.desc, this.pd, this.color, {this.active = false});
}
