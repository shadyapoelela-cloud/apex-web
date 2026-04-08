import 'package:flutter/material.dart';
import '../clients/client_detail_screen.dart';
import '../extracted/coa_screens.dart';
import '../../api_service.dart';

// ════════════════════════════════════════
// ENHANCED DASHBOARD v5.3 — Live API Integration
// ════════════════════════════════════════
// يقرأ العملاء الفعليين من API
// Quick actions + Client Pipeline + Recent Activity + Next Step

class EnhancedDashboard extends StatefulWidget {
  final VoidCallback? onSwitchToClients;
  final VoidCallback? onCreateClient;

  const EnhancedDashboard({super.key, this.onSwitchToClients, this.onCreateClient});
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
  static const borderColor = Color(0x1FC9A84C);
  static const greenC = Color(0xFF34D399);
  static const redC = Color(0xFFF87171);
  static const blueC = Color(0xFF60A5FA);
  static const orangeC = Color(0xFFFBBF24);
  static const purpleC = Color(0xFFA78BFA);

  List<dynamic> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    try {
      final res = await ApiService.listClients();
      if (mounted) {
        setState(() {
          _clients = res.success && res.data is List ? res.data as List : [];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: navy,
        body: _loading
            ? Center(child: CircularProgressIndicator(color: gold))
            : RefreshIndicator(
                color: gold,
                onRefresh: _loadClients,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }

  // ════════════════════════════════════════
  // KPI ROW — Live data
  // ════════════════════════════════════════
  Widget _buildKPIRow() {
    final totalClients = _clients.length;
    // Count by COA status
    int coaApproved = 0;
    int coaReview = 0;
    int coaReady = 0;
    for (final c in _clients) {
      final coaStatus = (c['coa_status'] ?? '').toString().toLowerCase();
      if (coaStatus == 'approved' || coaStatus == 'معتمد') coaApproved++;
      else if (coaStatus == 'review' || coaStatus == 'مراجعة' || coaStatus == 'in_progress') coaReview++;
      else if (coaStatus == 'ready' || coaStatus == 'جاهز') coaReady++;
    }

    final kpis = [
      _KPI('العملاء النشطون', '$totalClients', totalClients > 0 ? 'مسجلون في النظام' : 'لا يوجد عملاء', Icons.people_outline, blueC),
      _KPI('شجرة معتمدة', '$coaApproved', 'من أصل $totalClients', Icons.check_circle_outline, greenC),
      _KPI('قيد المراجعة', '$coaReview', coaReview > 0 ? 'بانتظار قرار' : 'لا يوجد', Icons.schedule, orangeC),
      _KPI('جاهز لـ TB', '$coaReady', coaReady > 0 ? '${coaReady == 1 ? "عميل واحد" : "$coaReady عملاء"}' : 'بعد COA', Icons.track_changes, gold),
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
              if (kpi.value != '0')
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
      _QAction('إنشاء عميل جديد', 'بدء معالج الإنشاء', Icons.add, gold, () {
        // Switch to Clients tab and trigger create
        if (widget.onCreateClient != null) {
          widget.onCreateClient!();
        } else if (widget.onSwitchToClients != null) {
          widget.onSwitchToClients!();
        }
      }),
      _QAction('رفع شجرة حسابات', 'COA Upload', Icons.upload_file, blueC, () {
        if (_clients.isNotEmpty) {
          final c = _clients.first;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CoaJourneyScreen(
              clientId: '${c['id'] ?? c['client_code'] ?? '1'}',
              clientName: c['name_ar'] ?? c['name'] ?? 'عميل',
            ),
          ));
        } else if (widget.onSwitchToClients != null) {
          widget.onSwitchToClients!();
        }
      }),
      _QAction('عرض العملاء', 'قائمة العملاء', Icons.visibility, greenC, () {
        if (widget.onSwitchToClients != null) widget.onSwitchToClients!();
      }),
      _QAction('تقارير الجودة', 'Quality Reports', Icons.bar_chart, orangeC, null),
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
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
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
      ),
    );
  }

  // ════════════════════════════════════════
  // CLIENT PIPELINE — Live data
  // ════════════════════════════════════════
  Widget _buildClientPipeline() {
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
              _badgeWidget('${_clients.length} عملاء', textDim),
            ],
          ),
          const SizedBox(height: 16),
          if (_clients.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.people_outline, color: textDim, size: 40),
                  const SizedBox(height: 12),
                  Text('لا يوجد عملاء بعد', style: TextStyle(color: textMid, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: widget.onCreateClient ?? widget.onSwitchToClients,
                    icon: Icon(Icons.add, color: gold, size: 16),
                    label: Text('إنشاء عميل جديد', style: TextStyle(color: gold, fontSize: 12)),
                  ),
                ],
              ),
            )
          else
            ...(_clients.length > 5 ? _clients.sublist(0, 5) : _clients).asMap().entries.map((e) {
              final c = e.value;
              final isLast = e.key == (_clients.length > 5 ? 4 : _clients.length - 1);
              final clientName = c['name_ar'] ?? c['name'] ?? 'عميل';
              final sector = c['industry'] ?? c['sector'] ?? '';
              final status = c['status'] ?? 'active';
              final coaStatus = c['coa_status'] ?? '';
              final clientId = c['id'] ?? c['client_code'] ?? 0;

              Color statusColor = status == 'active' ? greenC : orangeC;
              String statusLabel = status == 'active' ? 'نشط' : 'تهيئة';
              Color coaColor = textDim;
              String coaLabel = 'بدون COA';
              if (coaStatus == 'approved' || coaStatus == 'معتمد') { coaColor = greenC; coaLabel = 'COA معتمد'; }
              else if (coaStatus == 'review' || coaStatus == 'مراجعة' || coaStatus == 'in_progress') { coaColor = orangeC; coaLabel = 'COA مراجعة'; }
              else if (coaStatus == 'ready') { coaColor = blueC; coaLabel = 'جاهز لـ TB'; }

              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClientDetailScreen(
                      clientId: clientId is int ? clientId : int.tryParse('$clientId') ?? 0,
                      clientName: clientName,
                    ),
                  ));
                },
                child: Container(
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
                          child: Text(clientName.isNotEmpty ? clientName[0] : '?',
                              style: TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(clientName,
                                style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                            if (sector.isNotEmpty)
                              Text(sector, style: TextStyle(color: textDim, fontSize: 11)),
                          ],
                        ),
                      ),
                      _badgeWidget(statusLabel, statusColor),
                      const SizedBox(width: 6),
                      _badgeWidget(coaLabel, coaColor),
                    ],
                  ),
                ),
              );
            }),
          if (_clients.length > 5) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: widget.onSwitchToClients,
                child: Text('عرض جميع العملاء (${_clients.length})',
                    style: TextStyle(color: gold, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // RECENT ACTIVITY
  // ════════════════════════════════════════
  Widget _buildRecentActivity() {
    // Build dynamic activities based on actual clients
    final activities = <_Activity>[];

    for (final c in _clients.take(3)) {
      final name = c['name_ar'] ?? c['name'] ?? 'عميل';
      final coaStatus = (c['coa_status'] ?? '').toString();
      final createdAt = c['created_at'] ?? '';

      if (coaStatus == 'approved' || coaStatus == 'معتمد') {
        activities.add(_Activity('تم اعتماد شجرة حسابات $name', 'جميع الحسابات معتمدة', 'مؤخرًا', Icons.check_circle_outline, greenC));
      } else if (coaStatus == 'review' || coaStatus == 'مراجعة' || coaStatus == 'in_progress') {
        activities.add(_Activity('مراجعة مطلوبة: شجرة حسابات $name', 'بانتظار قرار المراجعة', 'مؤخرًا', Icons.error_outline, orangeC));
      } else {
        activities.add(_Activity('تم إنشاء عميل: $name', 'بانتظار رفع المستندات', _formatDate(createdAt), Icons.add, blueC));
      }
    }

    // Add default if no activities
    if (activities.isEmpty) {
      activities.add(_Activity('مرحبًا بك في APEX', 'ابدأ بإنشاء عميلك الأول', 'الآن', Icons.waving_hand, gold));
    }

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

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'مؤخرًا';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
      if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
      return dateStr.substring(0, 10);
    } catch (_) {
      return 'مؤخرًا';
    }
  }

  // ════════════════════════════════════════
  // NEXT STEP CARD — Dynamic based on clients
  // ════════════════════════════════════════
  Widget _buildNextStepCard() {
    String nextTitle = 'ابدأ الآن';
    String nextDesc = 'أنشئ عميلك الأول لبدء المسار المالي';
    String btnLabel = 'إنشاء عميل';
    VoidCallback? btnAction = widget.onCreateClient ?? widget.onSwitchToClients;

    // Find client that needs attention
    for (final c in _clients) {
      final coaStatus = (c['coa_status'] ?? '').toString().toLowerCase();
      final name = c['name_ar'] ?? c['name'] ?? 'عميل';

      if (coaStatus == 'review' || coaStatus == 'مراجعة' || coaStatus == 'in_progress') {
        nextTitle = 'الخطوة التالية المقترحة';
        nextDesc = '$name لديه شجرة حسابات بانتظار المراجعة — أكمل المراجعة واعتمد الشجرة';
        btnLabel = 'انتقل للمراجعة';
        final clientId = c['id'] ?? c['client_code'] ?? '1';
        btnAction = () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CoaJourneyScreen(
              clientId: '$clientId',
              clientName: name,
            ),
          ));
        };
        break;
      } else if (coaStatus.isEmpty || coaStatus == 'pending') {
        nextTitle = 'الخطوة التالية المقترحة';
        nextDesc = '$name بحاجة لرفع شجرة الحسابات لبدء المسار المالي';
        btnLabel = 'رفع COA';
        final clientId = c['id'] ?? c['client_code'] ?? '1';
        btnAction = () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CoaJourneyScreen(
              clientId: '$clientId',
              clientName: name,
            ),
          ));
        };
        break;
      }
    }

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
                Text(nextTitle,
                    style: TextStyle(color: gold, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(nextDesc, style: TextStyle(color: textMid, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: btnAction,
            icon: const Icon(Icons.arrow_back, size: 14),
            label: Text(btnLabel),
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
    int coaApproved = 0;
    for (final c in _clients) {
      final s = (c['coa_status'] ?? '').toString().toLowerCase();
      if (s == 'approved' || s == 'معتمد') coaApproved++;
    }

    final services = [
      _Service('شجرة الحسابات', 'COA', _clients.isNotEmpty ? 'نشط' : 'قريبًا', _clients.isNotEmpty ? greenC : textDim, '$coaApproved/${_clients.length} معتمد'),
      _Service('ميزان المراجعة', 'TB', coaApproved > 0 ? 'جاهز' : 'قريبًا', coaApproved > 0 ? blueC : textDim, 'بعد COA'),
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
                _badgeWidget(s.status, s.color),
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

  Widget _badgeWidget(String text, Color color) {
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
  final VoidCallback? onTap;
  _QAction(this.label, this.desc, this.icon, this.color, this.onTap);
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
