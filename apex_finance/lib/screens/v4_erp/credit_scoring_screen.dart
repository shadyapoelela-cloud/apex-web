/// APEX Wave 101 — Customer Credit Scoring & Limits.
/// Route: /app/erp/finance/credit
///
/// Credit risk assessment per customer — score, limit, exposure.
library;

import 'package:flutter/material.dart';

class CreditScoringScreen extends StatefulWidget {
  const CreditScoringScreen({super.key});
  @override
  State<CreditScoringScreen> createState() => _CreditScoringScreenState();
}

class _CreditScoringScreenState extends State<CreditScoringScreen> {
  String _selectedId = 'CUS-0145';

  final _customers = const [
    _CreditCustomer('CUS-0145', 'أرامكو السعودية', 92, 'AA', 50_000_000, 4_800_000, 32, 0, 0, Colors.green, 'سجل ممتاز — لا متأخرات'),
    _CreditCustomer('CUS-0089', 'سابك', 88, 'A+', 25_000_000, 3_200_000, 28, 0, 0, Colors.green, 'عميل استراتيجي — دفع منتظم'),
    _CreditCustomer('CUS-0213', 'STC', 85, 'A', 8_000_000, 1_450_000, 35, 0, 0, Colors.green, 'دفع ضمن الشروط'),
    _CreditCustomer('CUS-0178', 'مجموعة بن لادن', 72, 'BBB', 3_000_000, 820_000, 48, 125_000, 1, Colors.amber, 'متأخرات طفيفة 15-30 يوم'),
    _CreditCustomer('CUS-0298', 'دبي القابضة', 78, 'A-', 5_000_000, 560_000, 42, 0, 0, Colors.green, 'سجل جيد'),
    _CreditCustomer('CUS-0412', 'مركز التدريب الوطني', 68, 'BBB-', 1_000_000, 180_000, 58, 45_000, 2, Colors.amber, 'عميل جديد — تحت المراقبة'),
    _CreditCustomer('CUS-0498', 'شركة XYZ القابضة', 52, 'BB', 500_000, 680_000, 92, 340_000, 4, Colors.orange, '⚠ تجاوز الحد — متابعة'),
    _CreditCustomer('CUS-0521', 'شركة ABC للمقاولات', 38, 'B', 200_000, 420_000, 145, 420_000, 8, Colors.red, '🚨 تعثّر في السداد'),
  ];

  _CreditCustomer get _selected => _customers.firstWhere((c) => c.id == _selectedId);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 340, child: _buildSidebar()),
        Expanded(child: _buildDetail()),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 20, bottom: 20, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.grey.shade50,
            child: const Row(
              children: [
                Icon(Icons.credit_score, color: Color(0xFFD4AF37), size: 18),
                SizedBox(width: 8),
                Text('ترتيب حسب المخاطر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
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
                      color: selected ? const Color(0xFFD4AF37).withOpacity(0.12) : null,
                      border: Border(
                        bottom: BorderSide(color: Colors.black12.withOpacity(0.5)),
                        right: BorderSide(
                          color: selected ? const Color(0xFFD4AF37) : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                          child: Center(
                            child: Text('${c.score}',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(color: c.color.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                                    child: Text(c.rating,
                                        style: TextStyle(fontSize: 9, color: c.color, fontWeight: FontWeight.w800)),
                                  ),
                                  const SizedBox(width: 4),
                                  if (c.overdue > 0)
                                    Text('• ${c.overdueInvoices} متأخر',
                                        style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w700)),
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

  Widget _buildDetail() {
    final c = _selected;
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 20, right: 20, bottom: 20),
      children: [
        _buildScoreCard(c),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildLimitCard(c)),
            const SizedBox(width: 12),
            Expanded(child: _buildFactorsCard(c)),
          ],
        ),
        const SizedBox(height: 16),
        _buildHistoryCard(c),
        const SizedBox(height: 16),
        _buildRecommendations(c),
      ],
    );
  }

  Widget _buildScoreCard(_CreditCustomer c) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.color, c.color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: c.score / 100,
                      strokeWidth: 10,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  Column(
                    children: [
                      Text('${c.score}',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                      const Text('من 100', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                Text(c.id, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Text(c.rating,
                              style: TextStyle(color: c.color, fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(width: 6),
                          const Text('تصنيف',
                              style: TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                      child: Text(c.commentary,
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitCard(_CreditCustomer c) {
    final utilization = c.exposure / c.creditLimit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, color: Color(0xFFD4AF37)),
              SizedBox(width: 8),
              Text('الحد الائتماني والتعرّض', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الحد الائتماني', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    Text(_fmtM(c.creditLimit),
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFD4AF37), fontFamily: 'monospace')),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('التعرّض الحالي', style: TextStyle(fontSize: 11, color: Colors.black54)),
                    Text(_fmtM(c.exposure),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: utilization > 1 ? Colors.red : utilization > 0.8 ? Colors.orange : Colors.green,
                            fontFamily: 'monospace')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('نسبة الاستخدام', style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: utilization.clamp(0.0, 1.2),
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                      utilization > 1 ? Colors.red : utilization > 0.8 ? Colors.orange : Colors.green),
                  minHeight: 12,
                ),
              ),
              const SizedBox(width: 10),
              Text('${(utilization * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: utilization > 1 ? Colors.red : utilization > 0.8 ? Colors.orange : Colors.green)),
            ],
          ),
          const SizedBox(height: 10),
          if (utilization > 1)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('تجاوز الحد الائتماني — مطلوب مراجعة فورية',
                        style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFactorsCard(_CreditCustomer c) {
    final factors = <_Factor>[
      _Factor('سجل الدفع', c.overdueInvoices == 0 ? 95 : c.overdueInvoices <= 2 ? 72 : 45, c.overdueInvoices == 0 ? Colors.green : Colors.orange),
      _Factor('متوسط مدة السداد', c.avgDays <= 45 ? 90 : c.avgDays <= 60 ? 72 : 45, c.avgDays <= 45 ? Colors.green : Colors.orange),
      _Factor('الحجم والتركّز', 85, Colors.blue),
      _Factor('سنوات التعامل', 88, Colors.purple),
      _Factor('الصناعة والمخاطر', 78, Colors.teal),
      _Factor('المصادقات الخارجية (Simah)', 82, const Color(0xFFD4AF37)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Colors.purple),
              SizedBox(width: 8),
              Text('العوامل المكوّنة للنتيجة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          for (final f in factors)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 140, child: Text(f.name, style: const TextStyle(fontSize: 12))),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: f.score / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation(f.color),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${f.score}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: f.color)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(_CreditCustomer c) {
    final events = <_CreditEvent>[
      _CreditEvent('2026-04-18', 'review', 'مراجعة تلقائية — التقييم انخفض من 94 إلى ${c.score}', c.color),
      _CreditEvent('2026-03-15', 'payment', 'دفعة مستلمة 1.2M ر.س — INV-2026-0412', Colors.green),
      _CreditEvent('2026-02-28', 'invoice', 'إصدار فاتورة 2.4M ر.س — INV-2026-0398', Colors.blue),
      _CreditEvent('2026-01-20', 'limit-change', 'رفع الحد الائتماني من ${_fmtM(c.creditLimit * 0.8)} إلى ${_fmtM(c.creditLimit)}', Colors.purple),
      _CreditEvent('2025-12-05', 'simah', 'تحديث تصنيف Simah: ${c.rating}', const Color(0xFFD4AF37)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Colors.blue),
              SizedBox(width: 8),
              Text('سجل التعاملات الائتمانية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: e.color, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  SizedBox(width: 100, child: Text(e.date, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace'))),
                  Expanded(child: Text(e.description, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(_CreditCustomer c) {
    final recs = <String>[];
    if (c.score >= 85) {
      recs.add('✅ عميل ممتاز — يمكن رفع الحد الائتماني أو منح شروط أفضل');
      recs.add('🎯 فرصة بيع إضافي (Upsell) — اعرض خدمات متقدمة');
    } else if (c.score >= 70) {
      recs.add('⚖️ وضع جيد — حافظ على الشروط الحالية');
      recs.add('📊 راقب نسبة الاستخدام شهرياً');
    } else if (c.score >= 50) {
      recs.add('⚠️ عميل تحت المراقبة — اطلب ضمانات للمعاملات الكبيرة');
      recs.add('💰 قلّل شروط السداد من 60 إلى 30 يوم');
    } else {
      recs.add('🚨 عميل متعثّر — أوقف الائتمان فوراً');
      recs.add('📞 اتصل بفريق التحصيل لخطة سداد');
      recs.add('⚖️ راجع المستشار القانوني لاتخاذ إجراءات');
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: c.color),
              const SizedBox(width: 8),
              Text('توصيات AI', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.color)),
            ],
          ),
          const SizedBox(height: 12),
          for (final r in recs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(r, style: const TextStyle(fontSize: 13, height: 1.6)),
            ),
        ],
      ),
    );
  }

  String _fmtM(double v) {
    if (v.abs() >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M ر.س';
    if (v.abs() >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K ر.س';
    return '${v.toStringAsFixed(0)} ر.س';
  }
}

class _CreditCustomer {
  final String id;
  final String name;
  final int score;
  final String rating;
  final double creditLimit;
  final double exposure;
  final int avgDays;
  final double overdue;
  final int overdueInvoices;
  final Color color;
  final String commentary;
  const _CreditCustomer(this.id, this.name, this.score, this.rating, this.creditLimit, this.exposure, this.avgDays, this.overdue, this.overdueInvoices, this.color, this.commentary);
}

class _Factor {
  final String name;
  final int score;
  final Color color;
  const _Factor(this.name, this.score, this.color);
}

class _CreditEvent {
  final String date;
  final String type;
  final String description;
  final Color color;
  const _CreditEvent(this.date, this.type, this.description, this.color);
}
