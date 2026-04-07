import 'package:flutter/material.dart';

// ════════════════════════════════════════
// ENHANCED DASHBOARD — Phase 1 Visual Alignment
// ════════════════════════════════════════
// يطابق النموذج المرجعي apex-phase1.jsx (DashboardPage)
// 4 KPIs + إجراءات سريعة + حالة العملاء + نشاط حديث + الخطوة التالية

class EnhancedDashboard extends StatefulWidget {
  const EnhancedDashboard({super.key});
  @override
  State<EnhancedDashboard> createState() => _EnhancedDashboardState();
}

class _EnhancedDashboardState extends State<EnhancedDashboard> {
  // ─── Apex Colors ───
  static const navy = Color(0xFF050D1A);
  static const navyLight = Color(0xFF0A1628);
  static const navyMid = Color(0xFF111D2E);
  static const gold = Color(0xFFC9A84C);
  static const goldLight = Color(0xFFD4B96A);
  static const textColor = Color(0xFFE8E0D0);
  static const textMid = Color(0xFF9A917F);
  static const textDim = Color(0xFF6B6355);
  static const cardBg = Color(0xFF0D1825);
  static const borderColor = Color(0x1FC9A84C); // ~12% gold
  static const greenC = Color(0xFF34D399);
  static const redC = Color(0xFFF87171);
  static const blueC = Color(0xFF60A5FA);
  static const orangeC = Color(0xFFFBBF24);
  static const purpleC = Color(0xFFA78BFA);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: navy,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Welcome ───
              Text('مرحبًا بك في Apex',
                  style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('لوحة القيادة الرئيسية — نظرة سريعة على حالة العمليات',
                  style: TextStyle(color: textMid, fontSize: 13)),
              const SizedBox(height: 24),

              // ─── 4 KPI Cards ───
              _buildKPIRow(),
              const SizedBox(height: 24),

              // ─── Quick Actions + Client Pipeline ───
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildQuickActions()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildClientPipeline()),
                ],
              ),
              const SizedBox(height: 24),

              // ─── Recent Activity ───
              _buildRecentActivity(),
              const SizedBox(height: 24),

              // ─── Next Step Card ───
              _buildNextStepCard(),
              const SizedBox(height: 24),

              // ─── Service Status Row ───
              _buildServiceStatusRow(),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // KPI ROW
  // ════════════════════════════════════════
  Widget _buildKPIRow() {
    final kpis = [
      _KPI('العملاء النشطون', '3', '+1 هذا الأسبوع', Icons.people_outline, blueC),
      _KPI('شجرة معتمدة', '1', 'من أصل 3', Icons.check_circle_outline, greenC),
      _KPI('قيد المراجعة', '1', 'بانتظار قرار', Icons.schedule, orangeC),
      _KPI('جاهز لـ TB', '1', 'عميل واحد', Icons.track_changes, gold),
    ];
    return Row(
      children: kpis.map((k) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: _kpiCard(k),
        ),
      )).toList(),
    );
  }

  Widget _kpiCard(_KPI kpi) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: kpi.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(kpi.icon, color: kpi.color, size: 22),
              ),
              Icon(Icons.trending_up, color: greenC, size: 14),
            ],
          ),
          const SizedBox(height: 14),
          Text(kpi.value,
              style: TextStyle(color: kpi.color, fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(kpi.label,
              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(kpi.subtitle,
              style: TextStyle(color: textDim, fontSize: 11)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // QUICK ACTIONS
  // ════════════════════════════════════════
  Widget _buildQuickActions() {
    final actions = [
      _QAction('إنشاء عميل جديد', 'بدء معالج الإنشاء', Icons.add, gold),
      _QAction('رفع شجرة حسابات', 'COA Upload', Icons.upload_file, blueC),
      _QAction('عرض العملاء', 'قائمة العملاء', Icons.visibility, greenC),
      _QAction('تقارير الجودة', 'Quality Reports', Icons.bar_chart, orangeC),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.flash_on, color: gold, size: 18),
            const SizedBox(width: 8),
            Text('إجراءات سريعة',
                style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: actions.map((a) => _quickActionTile(a)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _quickActionTile(_QAction action) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: navyMid,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: action.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(action.icon, color: action.color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(action.label,
                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(action.desc,
                    style: TextStyle(color: textDim, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // CLIENT PIPELINE
  // ════════════════════════════════════════
  Widget _buildClientPipeline() {
    final clients = [
      _ClientRow('شركة النور للتجارة', 'التجزئة', 'نشط', greenC, 'COA معتمد', greenC),
      _ClientRow('مصنع الرياض للحديد', 'التصنيع', 'نشط', greenC, 'COA مراجعة', orangeC),
      _ClientRow('مؤسسة البناء الحديث', 'الإنشاءات', 'تهيئة', orangeC, 'بدون COA', textDim),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.timeline, color: gold, size: 18),
                const SizedBox(width: 8),
                Text('حالة العملاء',
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              _badge('${clients.length} عملاء', textDim),
            ],
          ),
          const SizedBox(height: 16),
          ...clients.asMap().entries.map((e) {
            final c = e.value;
            final isLast = e.key == clients.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: gold.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(c.name[0],
                          style: TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(c.sector, style: TextStyle(color: textDim, fontSize: 11)),
                      ],
                    ),
                  ),
                  _badge(c.statusLabel, c.statusColor),
                  const SizedBox(width: 6),
                  _badge(c.coaLabel, c.coaColor),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // RECENT ACTIVITY
  // ════════════════════════════════════════
  Widget _buildRecentActivity() {
    final activities = [
      _Activity('تم اعتماد شجرة حسابات شركة النور للتجارة', 'الجودة: 87% — جميع الحسابات معتمدة', 'قبل ساعتين', Icons.check_circle_outline, greenC),
      _Activity('مراجعة مطلوبة: شجرة حسابات مصنع الرياض', '4 حسابات بانتظار قرار المراجعة', 'قبل 4 ساعات', Icons.error_outline, orangeC),
      _Activity('تم إنشاء عميل جديد: مؤسسة البناء الحديث', 'بانتظار رفع المستندات الأساسية', 'أمس', Icons.add, blueC),
      _Activity('تحديث مستندات شركة النور للتجارة', 'السجل التجاري + الشهادة الضريبية', 'أمس', Icons.description, gold),
      _Activity('فحص الامتثال لشركة النور — ناجح', 'جميع المستندات سارية المفعول', 'قبل يومين', Icons.shield, greenC),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.description, color: gold, size: 18),
                const SizedBox(width: 8),
                Text('النشاط الأخير',
                    style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              TextButton(
                onPressed: () {},
                child: Text('عرض الكل', style: TextStyle(color: textMid, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activities.asMap().entries.map((e) {
            final a = e.value;
            final isLast = e.key == activities.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: a.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(a.icon, color: a.color, size: 16),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a.title,
                            style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(a.detail, style: TextStyle(color: textDim, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(a.time, style: TextStyle(color: textDim, fontSize: 11)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // NEXT STEP CARD
  // ════════════════════════════════════════
  Widget _buildNextStepCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gold.withOpacity(0.12), Colors.transparent],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome, color: gold, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الخطوة التالية المقترحة',
                    style: TextStyle(color: gold, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('مصنع الرياض للحديد لديه شجرة حسابات بانتظار المراجعة — أكمل المراجعة واعتمد الشجرة',
                    style: TextStyle(color: textMid, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.arrow_back, size: 14),
            label: const Text('انتقل للمراجعة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: navy,
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // SERVICE STATUS ROW
  // ════════════════════════════════════════
  Widget _buildServiceStatusRow() {
    final services = [
      _Service('شجرة الحسابات', 'COA', 'نشط', greenC, '1/3 معتمد'),
      _Service('ميزان المراجعة', 'TB', 'قريبًا', textDim, 'بعد COA'),
      _Service('القوائم المالية', 'Statements', 'قريبًا', textDim, 'بعد TB'),
      _Service('التحليل المالي', 'Analysis', 'قريبًا', textDim, 'بعد Statements'),
      _Service('الامتثال والجاهزية', 'Compliance', 'قريبًا', textDim, 'متوازي'),
    ];
    return Row(
      children: services.map((s) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              // Top colored border
            ),
            child: Column(
              children: [
                Container(height: 3, color: s.color,
                    margin: const EdgeInsets.only(bottom: 12)),
                Text(s.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(s.labelEn,
                    style: TextStyle(color: textDim, fontSize: 10)),
                const SizedBox(height: 10),
                _badge(s.status, s.color),
                const SizedBox(height: 6),
                Text(s.detail, style: TextStyle(color: textDim, fontSize: 10)),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  // ════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════
  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Data Classes ───
class _KPI {
  final String label, value, subtitle;
  final IconData icon;
  final Color color;
  _KPI(this.label, this.value, this.subtitle, this.icon, this.color);
}

class _QAction {
  final String label, desc;
  final IconData icon;
  final Color color;
  _QAction(this.label, this.desc, this.icon, this.color);
}

class _ClientRow {
  final String name, sector, statusLabel, coaLabel;
  final Color statusColor, coaColor;
  _ClientRow(this.name, this.sector, this.statusLabel, this.statusColor, this.coaLabel, this.coaColor);
}

class _Activity {
  final String title, detail, time;
  final IconData icon;
  final Color color;
  _Activity(this.title, this.detail, this.time, this.icon, this.color);
}

class _Service {
  final String label, labelEn, status, detail;
  final Color color;
  _Service(this.label, this.labelEn, this.status, this.color, this.detail);
}