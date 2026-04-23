import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../compliance/compliance_health_widget.dart';

// ════════════════════════════════════════
// ENHANCED DASHBOARD v5.3b — Live API (ApiService)
// ════════════════════════════════════════

class EnhancedDashboard extends StatefulWidget {
  final VoidCallback? onSwitchToClients;
  final VoidCallback? onCreateClient;
  final VoidCallback? onNavigateToCoa;

  const EnhancedDashboard({super.key, this.onSwitchToClients, this.onCreateClient, this.onNavigateToCoa});
  @override
  State<EnhancedDashboard> createState() => _EnhancedDashboardState();
}

class _EnhancedDashboardState extends State<EnhancedDashboard> {
  static Color get navy => AC.navy;
  static Color get navyMid => AC.navy4;
  static Color get gold => AC.gold;
  static Color get goldLight => AC.goldLight;
  static Color get iconGold => AC.iconAccent;
  static Color get textColor => AC.tp;
  static Color get textMid => AC.ts;
  static Color get textDim => AC.td;
  static Color get cardBg => AC.navy3;
  static Color get borderColor => AC.bdr;
  static Color get greenC => AC.ok;
  static Color get redC => AC.err;
  static Color get blueC => AC.info;
  static Color get orangeC => AC.warn;
  static Color get purpleC => AC.purple;

  List<dynamic> _clients = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final res = await ApiService.listClients();
    if (mounted) {
      if (res.success) {
        final data = res.data;
        final list = data is List ? data : (data['clients'] ?? data['data'] ?? []);
        setState(() {
          _clients = List<Map<String, dynamic>>.from(list);
          _loading = false;
        });
      } else {
        setState(() { _loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: navy,
        body: _loading
            ? Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: gold),
                  SizedBox(height: 16),
                  Text('جارٍ تحميل البيانات...', style: TextStyle(color: textMid, fontSize: 13)),
                ],
              ))
            : RefreshIndicator(
                color: gold,
                onRefresh: _loadClients,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      apexContextBar(
                        pills: ['العميل الحالي', 'المرحلة 1', 'الجاهزية: ${_clients.isEmpty ? 0 : ((_clients.where((c) => (c['coa_status'] ?? '').toString().toLowerCase() == 'approved' || (c['coa_status'] ?? '').toString().toLowerCase() == 'معتمد').length / _clients.length) * 100).toInt()}%'],
                      ),
                      ApexHeroSection(
                        title: 'مرحبًا بك في Apex',
                        description: 'لوحة القيادة الرئيسية — نظرة سريعة على حالة العمليات',
                        icon: Icons.dashboard_rounded,
                      ),
                      const SizedBox(height: 16),
                      _buildNoticeBanners(),
                      const SizedBox(height: 16),
                      // Compliance posture + quick links (Sprint 4)
                      const ComplianceHealthWidget(),
                      const SizedBox(height: 16),
                      _buildKPIRow(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildQuickActions()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildClientPipeline()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildRecentActivity(),
                      const SizedBox(height: 24),
                      _buildNextStepCard(),
                      const SizedBox(height: 24),
                      _buildServiceStatusRow(),
                      ApexTableLegend(items: [
                        MapEntry('نشط', greenC),
                        MapEntry('قيد المراجعة', orangeC),
                        MapEntry('جاهز', blueC),
                        MapEntry('قريبًا', textDim),
                      ]),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ════════════════════════════════════════
  // KPI ROW
  // ════════════════════════════════════════
  Widget _buildKPIRow() {
    final total = _clients.length;
    int coaApproved = 0, coaReview = 0, coaReady = 0;
    for (final c in _clients) {
      final s = (c['coa_status'] ?? '').toString().toLowerCase();
      if (s == 'approved' || s == 'معتمد') coaApproved++;
      else if (s == 'review' || s == 'مراجعة' || s == 'in_progress') coaReview++;
      else if (s == 'ready' || s == 'جاهز') coaReady++;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.7,
          children: [
            apexScoreCard(label: 'الشركات النشطة', value: '$total', subtitle: total > 0 ? 'مسجلة في النظام' : 'لا توجد شركات', tintColor: blueC, infoTip: 'عدد الشركات المسجلة والنشطة في المنصة حالياً'),
            apexScoreCard(label: 'شجرة معتمدة', value: '$coaApproved', subtitle: 'من أصل $total', tintColor: greenC, valueColor: greenC, infoTip: 'عدد الشركات التي تم اعتماد شجرة حساباتها بنجاح'),
            apexScoreCard(label: 'قيد المراجعة', value: '$coaReview', subtitle: coaReview > 0 ? 'بانتظار قرار' : 'لا يوجد', tintColor: orangeC, valueColor: orangeC, infoTip: 'شجرات حسابات بانتظار مراجعة واعتماد المراجع'),
            apexScoreCard(label: 'جاهز لـ TB', value: '$coaReady', subtitle: coaReady > 0 ? '$coaReady شركات' : 'بعد COA', tintColor: iconGold, valueColor: gold, infoTip: 'شركات جاهزة لرفع ميزان المراجعة بعد اعتماد الشجرة'),
          ],
        );
      },
    );
  }

  // ════════════════════════════════════════
  // QUICK ACTIONS
  // ════════════════════════════════════════
  Widget _buildQuickActions() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          apexSectionTitle('إجراءات سريعة', icon: Icons.flash_on, infoTip: 'اختصارات سريعة للعمليات الأكثر استخداماً'),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
            children: [
              ApexActionCard(
                label: 'إنشاء شركة جديدة',
                description: 'بدء معالج الإنشاء',
                icon: Icons.domain_add_rounded,
                color: iconGold,
                tooltip: 'فتح معالج إنشاء شركة جديدة وإضافتها للنظام',
                onTap: () {
                  if (widget.onCreateClient != null) widget.onCreateClient!();
                  else if (widget.onSwitchToClients != null) widget.onSwitchToClients!();
                },
              ),
              ApexActionCard(
                label: 'رفع شجرة حسابات',
                description: 'تحميل ملف COA',
                icon: Icons.upload_file_rounded,
                color: blueC,
                tooltip: 'رفع ملف شجرة الحسابات (CSV أو Excel) لشركة محددة',
                onTap: () {
                  if (widget.onNavigateToCoa != null) {
                    widget.onNavigateToCoa!();
                  } else if (_clients.isNotEmpty) {
                    _navigateToCoa(_clients.first);
                  } else if (widget.onSwitchToClients != null) {
                    widget.onSwitchToClients!();
                  }
                },
              ),
              ApexActionCard(
                label: 'عرض الشركات',
                description: 'قائمة الشركات المسجلة',
                icon: Icons.apartment_rounded,
                color: greenC,
                tooltip: 'الانتقال لصفحة الشركات لعرض وإدارة جميع الشركات',
                onTap: () {
                  if (widget.onSwitchToClients != null) widget.onSwitchToClients!();
                },
              ),
              ApexActionCard(
                label: 'سوق الخدمات',
                description: 'تصفح مقدمي الخدمات',
                icon: Icons.store_rounded,
                color: purpleC,
                tooltip: 'استعراض وطلب خدمات من مقدمي الخدمات المعتمدين',
                onTap: () => context.push('/provider-kanban'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // CLIENT PIPELINE — Live
  // ════════════════════════════════════════
  Widget _buildClientPipeline() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          apexSectionTitle('حالة الشركات',
            icon: Icons.timeline,
            infoTip: 'ملخص حالة شجرة الحسابات لكل شركة — اضغط على شركة لعرض التفاصيل',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              _badge('${_clients.length} شركات', textDim),
              const SizedBox(width: 6),
              ApexIconButton(
                icon: Icons.refresh_rounded,
                onPressed: _loadClients,
                tooltip: 'تحديث البيانات',
                size: 16,
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // Error state
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: redC.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.wifi_off, color: redC, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_error!, style: TextStyle(color: redC, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('اضغط تحديث أو أعد تسجيل الدخول', style: TextStyle(color: textDim, fontSize: 11)),
                  ],
                )),
                TextButton(onPressed: _loadClients, child: Text('تحديث', style: TextStyle(color: AC.goldText, fontSize: 12))),
              ]),
            ),
          ]
          // Empty state
          else if (_clients.isEmpty) ...[
            Container(
              padding: EdgeInsets.all(24),
              child: Column(children: [
                Icon(Icons.people_outline, color: textDim, size: 40),
                SizedBox(height: 12),
                Text('لا يوجد عملاء بعد', style: TextStyle(color: textMid, fontSize: 13)),
                const SizedBox(height: 4),
                Text('أنشئ عميلك الأول من "إجراءات سريعة"', style: TextStyle(color: textDim, fontSize: 11)),
              ]),
            ),
          ]
          // Client list
          else ...[
            ...(_clients.length > 5 ? _clients.sublist(0, 5) : _clients).asMap().entries.map((e) {
              final c = e.value;
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

              return _ClientRow(
                clientName: clientName,
                sector: sector,
                statusLabel: statusLabel,
                statusColor: statusColor,
                coaLabel: coaLabel,
                coaColor: coaColor,
                onTap: () async {
                  await context.push('/client-detail', extra: {'id': clientId.toString(), 'name': clientName});
                  if (mounted) _loadClients();
                },
              );
            }),
            if (_clients.length > 5) ...[
              SizedBox(height: 8),
              Center(child: TextButton(
                onPressed: widget.onSwitchToClients,
                child: Text('عرض جميع الشركات (${_clients.length})', style: TextStyle(color: AC.goldText, fontSize: 12)),
              )),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _navigateToCoa(dynamic client) async {
    final clientId = client['id'] ?? client['client_code'] ?? '1';
    final clientName = client['name_ar'] ?? client['name'] ?? 'شركة';
    await context.push('/coa/journey', extra: {'clientId': '$clientId', 'clientName': clientName});
    if (mounted) _loadClients();
}

  // ════════════════════════════════════════
  // RECENT ACTIVITY
  // ════════════════════════════════════════
  Widget _buildRecentActivity() {
    final activities = <_Activity>[];
    for (final c in _clients.take(3)) {
      final name = c['name_ar'] ?? c['name'] ?? 'شركة';
      final coaStatus = (c['coa_status'] ?? '').toString();
      if (coaStatus == 'approved' || coaStatus == 'معتمد') {
        activities.add(_Activity('تم اعتماد شجرة حسابات $name', 'جميع الحسابات معتمدة', 'مؤخرًا', Icons.check_circle_outline, greenC));
      } else if (coaStatus.isNotEmpty && coaStatus != 'pending') {
        activities.add(_Activity('مراجعة مطلوبة: شجرة حسابات $name', 'بانتظار قرار المراجعة', 'مؤخرًا', Icons.error_outline, orangeC));
      } else {
        activities.add(_Activity('تم إنشاء شركة: $name', 'بانتظار رفع المستندات', 'مؤخرًا', Icons.add, blueC));
      }
    }
    if (activities.isEmpty) {
      activities.add(_Activity('مرحبًا بك في APEX', 'ابدأ بإنشاء شركتك الأولى', 'الآن', Icons.waving_hand, iconGold));
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          apexSectionTitle('النشاط الأخير', icon: Icons.description, infoTip: 'آخر التحديثات والإجراءات على الشركات والمستندات'),
          const SizedBox(height: 12),
          ...activities.map((a) => apexFeedItem(
            title: a.title,
            subtitle: a.detail,
            icon: a.icon,
            accentColor: a.color,
            time: a.time,
          )),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // NEXT STEP CARD
  // ════════════════════════════════════════
  Widget _buildNextStepCard() {
    String title = 'ابدأ الآن';
    String desc = 'أنشئ شركتك الأولى لبدء المسار المالي';
    String btn = 'إنشاء شركة';
    VoidCallback? action = widget.onCreateClient ?? widget.onSwitchToClients;

    for (final c in _clients) {
      final coaStatus = (c['coa_status'] ?? '').toString().toLowerCase();
      final name = c['name_ar'] ?? c['name'] ?? 'شركة';
      if (coaStatus == 'review' || coaStatus == 'مراجعة' || coaStatus == 'in_progress') {
        title = 'الخطوة التالية المقترحة';
        desc = '$name لديه شجرة حسابات بانتظار المراجعة';
        btn = 'انتقل للمراجعة';
        action = widget.onNavigateToCoa ?? () => _navigateToCoa(c);
        break;
      } else if (coaStatus.isEmpty || coaStatus == 'pending') {
        title = 'الخطوة التالية المقترحة';
        desc = '$name بحاجة لرفع شجرة الحسابات';
        btn = 'رفع COA';
        action = widget.onNavigateToCoa ?? () => _navigateToCoa(c);
        break;
      }
    }

    return ApexNextStepCard(
      title: title,
      description: desc,
      buttonLabel: btn,
      onPressed: action,
      icon: Icons.auto_awesome,
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
    // Determine current step based on pipeline progress
    int currentStep = 0;
    if (_clients.isNotEmpty) currentStep = 1; // COA active
    if (coaApproved > 0) currentStep = 2; // TB ready
    return apexStepFlow(
      steps: ['شجرة الحسابات', 'ميزان المراجعة', 'القوائم المالية', 'التحليل المالي', 'الامتثال'],
      currentStep: currentStep,
    );
  }

  // ════════════════════════════════════════
  // NOTICE BANNERS
  // ════════════════════════════════════════
  Widget _buildNoticeBanners() {
    final banners = <Widget>[];
    if (_clients.isEmpty) {
      banners.add(apexNoticeBanner(
        title: 'لا توجد شركات',
        text: 'ابدأ بإنشاء شركتك الأولى لتفعيل المسار المالي الكامل.',
        tint: ApexTint.blue,
        icon: Icons.info_rounded,
        actionLabel: 'إنشاء شركة',
        onAction: widget.onCreateClient ?? widget.onSwitchToClients,
      ));
    } else {
      int reviewCount = 0;
      for (final c in _clients) {
        final s = (c['coa_status'] ?? '').toString().toLowerCase();
        if (s == 'review' || s == 'مراجعة' || s == 'in_progress') reviewCount++;
      }
      if (reviewCount > 0) {
        banners.add(apexNoticeBanner(
          title: '$reviewCount شجرة حسابات بانتظار المراجعة',
          text: 'يرجى مراجعة واعتماد شجرة الحسابات المعلقة للمتابعة.',
          tint: ApexTint.amber,
          actionLabel: 'انتقل للمراجعة',
          onAction: widget.onNavigateToCoa,
        ));
      }
      // Show readiness progress
      final total = _clients.length;
      int approved = 0;
      for (final c in _clients) {
        final s = (c['coa_status'] ?? '').toString().toLowerCase();
        if (s == 'approved' || s == 'معتمد') approved++;
      }
      final readiness = total > 0 ? approved / total : 0.0;
      banners.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: apexGradientProgress(
          value: readiness,
          label: 'جاهزية الشجرة المحاسبية',
          startColor: greenC,
          endColor: greenC,
        ),
      ));
    }
    if (_error != null) {
      banners.add(apexNoticeBanner(
        title: 'خطأ في الاتصال',
        text: _error!,
        tint: ApexTint.red,
        actionLabel: 'تحديث',
        onAction: _loadClients,
      ));
    }
    return Column(children: banners);
  }

  // ════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AC.navy2.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AC.bdr.withValues(alpha: 0.06)),
      boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.10), blurRadius: 20, offset: Offset(0, 4))],
    ),
    child: child,
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withValues(alpha: 0.2))),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _Activity { final String title, detail, time; final IconData icon; final Color color; _Activity(this.title, this.detail, this.time, this.icon, this.color); }

/// World-class client row with hover feedback
class _ClientRow extends StatefulWidget {
  final String clientName, sector, statusLabel, coaLabel;
  final Color statusColor, coaColor;
  final VoidCallback onTap;

  const _ClientRow({
    required this.clientName, required this.sector,
    required this.statusLabel, required this.statusColor,
    required this.coaLabel, required this.coaColor,
    required this.onTap,
  });

  @override
  State<_ClientRow> createState() => _ClientRowState();
}

class _ClientRowState extends State<_ClientRow> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: _hov ? AC.iconAccent.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _hov ? AC.iconAccent.withValues(alpha: 0.2) : Colors.transparent),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: AC.iconAccent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(widget.clientName.isNotEmpty ? widget.clientName[0] : '?',
                  style: TextStyle(color: AC.goldText, fontSize: 14, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.clientName, style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
                if (widget.sector.isNotEmpty) Text(widget.sector, style: TextStyle(color: AC.td, fontSize: 11)),
              ],
            )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: widget.statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: widget.statusColor.withValues(alpha: 0.2))),
              child: Text(widget.statusLabel, style: TextStyle(color: widget.statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(color: widget.coaColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: widget.coaColor.withValues(alpha: 0.2))),
              child: Text(widget.coaLabel, style: TextStyle(color: widget.coaColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 4),
            AnimatedOpacity(
              opacity: _hov ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.arrow_forward_ios, color: AC.iconAccent, size: 12),
            ),
          ]),
        ),
      ),
    );
  }
}
