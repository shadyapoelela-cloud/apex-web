import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;
import '../../core/api_config.dart';
import '../clients/client_detail_screen.dart';
import '../extracted/coa_screens.dart';

// ════════════════════════════════════════
// ENHANCED DASHBOARD v5.3b — Live API (localStorage token)
// ════════════════════════════════════════
// يستخدم نفس طريقة ClientsTab لجلب العملاء
// localStorage['apex_token'] + http.get مباشرة

const String _api = apiBase;

class EnhancedDashboard extends StatefulWidget {
  final VoidCallback? onSwitchToClients;
  final VoidCallback? onCreateClient;
  final VoidCallback? onNavigateToCoa;

  const EnhancedDashboard({super.key, this.onSwitchToClients, this.onCreateClient, this.onNavigateToCoa});
  @override
  State<EnhancedDashboard> createState() => _EnhancedDashboardState();
}

class _EnhancedDashboardState extends State<EnhancedDashboard> {
  static const navy = Color(0xFF050D1A);
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final token = html.window.localStorage['apex_token'] ?? '';
    if (token.isEmpty) {
      if (mounted) setState(() { _loading = false; });
      return;
    }

    // Retry logic for Render cold starts (up to 3 attempts)
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final resp = await http.get(
          Uri.parse('$_api/clients'),
          headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        ).timeout(Duration(seconds: attempt == 1 ? 10 : 20));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final list = data is List ? data : (data['clients'] ?? data['data'] ?? []);
          if (mounted) {
            setState(() {
              _clients = List<Map<String, dynamic>>.from(list);
              _loading = false;
            });
          }
          return; // Success — exit retry loop
        } else if (resp.statusCode == 401) {
          // Token expired — clear and stop
          html.window.localStorage.remove('apex_token');
          if (mounted) setState(() { _loading = false; });
          return;
        }
      } catch (e) {
        if (attempt < 3) {
          // Wait before retry (Render cold start)
          await Future.delayed(Duration(seconds: attempt * 3));
          continue;
        }
      }
    }
    // All retries failed
    if (mounted) setState(() { _loading = false; });
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
                  const SizedBox(height: 16),
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
                      Text('مرحبًا بك في Apex',
                          style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('لوحة القيادة الرئيسية — نظرة سريعة على حالة العمليات',
                          style: TextStyle(color: textMid, fontSize: 13)),
                      const SizedBox(height: 24),
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
    final kpis = [
      _KPI('العملاء النشطون', '$total', total > 0 ? 'مسجلون في النظام' : 'لا يوجد عملاء', Icons.people_outline, blueC),
      _KPI('شجرة معتمدة', '$coaApproved', 'من أصل $total', Icons.check_circle_outline, greenC),
      _KPI('قيد المراجعة', '$coaReview', coaReview > 0 ? 'بانتظار قرار' : 'لا يوجد', Icons.schedule, orangeC),
      _KPI('جاهز لـ TB', '$coaReady', coaReady > 0 ? '$coaReady عملاء' : 'بعد COA', Icons.track_changes, gold),
    ];
    return Row(
      children: kpis.map((k) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: k.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(k.icon, color: k.color, size: 22),
                ),
                const SizedBox(height: 14),
                Text(k.value, style: TextStyle(color: k.color, fontSize: 32, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(k.label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(k.subtitle, style: TextStyle(color: textDim, fontSize: 11)),
              ],
            ),
          ),
        ),
      )).toList(),
    );
  }

  // ════════════════════════════════════════
  // QUICK ACTIONS
  // ════════════════════════════════════════
  Widget _buildQuickActions() {
    final actions = [
      _QAction('إنشاء عميل جديد', 'بدء معالج الإنشاء', Icons.add, gold, () {
        if (widget.onCreateClient != null) widget.onCreateClient!();
        else if (widget.onSwitchToClients != null) widget.onSwitchToClients!();
      }),
      _QAction('رفع شجرة حسابات', 'COA Upload', Icons.upload_file, blueC, () {
        // v6.6: Use parent callback (checks top-bar client selection)
        if (widget.onNavigateToCoa != null) {
          widget.onNavigateToCoa!();
        } else if (_clients.isNotEmpty) {
          _navigateToCoa(_clients.first);
        } else if (widget.onSwitchToClients != null) {
          widget.onSwitchToClients!();
        }
      }),
      _QAction('عرض العملاء', 'قائمة العملاء', Icons.visibility, greenC, () {
        if (widget.onSwitchToClients != null) widget.onSwitchToClients!();
      }),
      _QAction('تحديث البيانات', 'إعادة تحميل', Icons.refresh, orangeC, _loadClients),
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.flash_on, color: gold, size: 18),
            const SizedBox(width: 8),
            Text('إجراءات سريعة', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
            children: actions.map((a) => GestureDetector(
              onTap: a.onTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: navyMid, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: a.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(a.icon, color: a.color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(a.label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(a.desc, style: TextStyle(color: textDim, fontSize: 10)),
                    ],
                  )),
                ]),
              ),
            )).toList(),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.timeline, color: gold, size: 18),
                const SizedBox(width: 8),
                Text('حالة العملاء', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              Row(children: [
                _badge('${_clients.length} عملاء', textDim),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _loadClients,
                  child: Icon(Icons.refresh, color: textDim, size: 16),
                ),
              ]),
            ],
          ),
          const SizedBox(height: 16),

          // Error state
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: redC.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
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
                TextButton(onPressed: _loadClients, child: Text('تحديث', style: TextStyle(color: gold, fontSize: 12))),
              ]),
            ),
          ]
          // Empty state
          else if (_clients.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Icon(Icons.people_outline, color: textDim, size: 40),
                const SizedBox(height: 12),
                Text('لا يوجد عملاء بعد', style: TextStyle(color: textMid, fontSize: 13)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: widget.onCreateClient ?? widget.onSwitchToClients,
                  icon: Icon(Icons.add, size: 16),
                  label: Text('إنشاء عميل جديد'),
                  style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: navy, textStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ]
          // Client list
          else ...[
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
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ClientDetailScreen(
                      clientId: clientId.toString(),
                      clientName: clientName,
                    ),
                  ));
                  if (mounted) _loadClients();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: borderColor))),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: gold.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text(clientName.isNotEmpty ? clientName[0] : '?',
                          style: TextStyle(color: gold, fontSize: 14, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(clientName, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                        if (sector.isNotEmpty) Text(sector, style: TextStyle(color: textDim, fontSize: 11)),
                      ],
                    )),
                    _badge(statusLabel, statusColor),
                    const SizedBox(width: 6),
                    _badge(coaLabel, coaColor),
                  ]),
                ),
              );
            }),
            if (_clients.length > 5) ...[
              const SizedBox(height: 8),
              Center(child: TextButton(
                onPressed: widget.onSwitchToClients,
                child: Text('عرض جميع العملاء (${_clients.length})', style: TextStyle(color: gold, fontSize: 12)),
              )),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _navigateToCoa(dynamic client) async {
    final clientId = client['id'] ?? client['client_code'] ?? '1';
    final clientName = client['name_ar'] ?? client['name'] ?? 'عميل';
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => CoaJourneyScreen(clientId: '$clientId', clientName: clientName),
    ));
    if (mounted) _loadClients();
}

  // ════════════════════════════════════════
  // RECENT ACTIVITY
  // ════════════════════════════════════════
  Widget _buildRecentActivity() {
    final activities = <_Activity>[];
    for (final c in _clients.take(3)) {
      final name = c['name_ar'] ?? c['name'] ?? 'عميل';
      final coaStatus = (c['coa_status'] ?? '').toString();
      if (coaStatus == 'approved' || coaStatus == 'معتمد') {
        activities.add(_Activity('تم اعتماد شجرة حسابات $name', 'جميع الحسابات معتمدة', 'مؤخرًا', Icons.check_circle_outline, greenC));
      } else if (coaStatus.isNotEmpty && coaStatus != 'pending') {
        activities.add(_Activity('مراجعة مطلوبة: شجرة حسابات $name', 'بانتظار قرار المراجعة', 'مؤخرًا', Icons.error_outline, orangeC));
      } else {
        activities.add(_Activity('تم إنشاء عميل: $name', 'بانتظار رفع المستندات', 'مؤخرًا', Icons.add, blueC));
      }
    }
    if (activities.isEmpty) {
      activities.add(_Activity('مرحبًا بك في APEX', 'ابدأ بإنشاء عميلك الأول', 'الآن', Icons.waving_hand, gold));
    }
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.description, color: gold, size: 18),
            const SizedBox(width: 8),
            Text('النشاط الأخير', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 12),
          ...activities.asMap().entries.map((e) {
            final a = e.value;
            final isLast = e.key == activities.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(border: isLast ? null : Border(bottom: BorderSide(color: borderColor))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: a.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(a.icon, color: a.color, size: 16),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.title, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(a.detail, style: TextStyle(color: textDim, fontSize: 11)),
                ])),
                Text(a.time, style: TextStyle(color: textDim, fontSize: 11)),
              ]),
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
    String title = 'ابدأ الآن';
    String desc = 'أنشئ عميلك الأول لبدء المسار المالي';
    String btn = 'إنشاء عميل';
    VoidCallback? action = widget.onCreateClient ?? widget.onSwitchToClients;

    for (final c in _clients) {
      final coaStatus = (c['coa_status'] ?? '').toString().toLowerCase();
      final name = c['name_ar'] ?? c['name'] ?? 'عميل';
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [gold.withOpacity(0.12), Colors.transparent], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.auto_awesome, color: gold, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: gold, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(desc, style: TextStyle(color: textMid, fontSize: 12)),
        ])),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: action,
          icon: const Icon(Icons.arrow_back, size: 14),
          label: Text(btn),
          style: ElevatedButton.styleFrom(
            backgroundColor: gold, foregroundColor: navy,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        ),
      ]),
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
      _Service('شجرة الحسابات', 'COA', _clients.isNotEmpty ? 'نشط' : 'قريبًا', _clients.isNotEmpty ? greenC : textDim, '$coaApproved/${_clients.length}'),
      _Service('ميزان المراجعة', 'TB', coaApproved > 0 ? 'جاهز' : 'قريبًا', coaApproved > 0 ? blueC : textDim, 'بعد COA'),
      _Service('القوائم المالية', 'FS', 'قريبًا', textDim, 'بعد TB'),
      _Service('التحليل المالي', 'FA', 'قريبًا', textDim, 'بعد FS'),
      _Service('الامتثال', 'Comp', 'قريبًا', textDim, 'متوازي'),
    ];
    return Row(
      children: services.map((s) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Column(children: [
              Container(height: 3, color: s.color, margin: const EdgeInsets.only(bottom: 12)),
              Text(s.label, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(s.labelEn, style: TextStyle(color: textDim, fontSize: 10)),
              const SizedBox(height: 10),
              _badge(s.status, s.color),
              const SizedBox(height: 6),
              Text(s.detail, style: TextStyle(color: textDim, fontSize: 10)),
            ]),
          ),
        ),
      )).toList(),
    );
  }

  // ════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
    child: child,
  );

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withOpacity(0.2))),
    child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

class _KPI { final String label, value, subtitle; final IconData icon; final Color color; _KPI(this.label, this.value, this.subtitle, this.icon, this.color); }
class _QAction { final String label, desc; final IconData icon; final Color color; final VoidCallback? onTap; _QAction(this.label, this.desc, this.icon, this.color, this.onTap); }
class _Activity { final String title, detail, time; final IconData icon; final Color color; _Activity(this.title, this.detail, this.time, this.icon, this.color); }
class _Service { final String label, labelEn, status, detail; final Color color; _Service(this.label, this.labelEn, this.status, this.color, this.detail); }
