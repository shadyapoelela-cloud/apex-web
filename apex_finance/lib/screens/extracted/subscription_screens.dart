import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/shared_constants.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

// Per Execution Master §4, §9 + Zero Ambiguity §5, §6
// ═══════════════════════════════════════════════════════════
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});
  @override State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}
class _SubscriptionScreenState extends State<SubscriptionScreen> {
  Map<String, dynamic>? _sub;
  List<dynamic> _plans = [];
  bool _loading = true;
  String? _error;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Load current subscription
      final r1 = await ApiService.getCurrentPlan();
      if (r1.success) {
        _sub = r1.data;
      }

      // Load available plans
      final r2 = await ApiService.getPlans();
      if (r2.success) {
        _plans = r2.data is List ? r2.data : (r2.data['plans'] ?? []);
      }
    } catch (e) {
      _error = e.toString();
    }
    setState(() { _loading = false; });
  }

  Future<void> _upgrade(String planName) async {
    final r = await ApiService.upgradePlanByName(planName);
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم الترقية إلى $planName بنجاح!'), backgroundColor: AC.ok));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الترقية: ${r.error}'), backgroundColor: AC.err));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlan = _sub?['subscription']?['plan_name'] ?? 'Free';
    final features = _sub?['plan_features'] as List<dynamic>? ?? [];

    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: Text('خطتي والاشتراك'), backgroundColor: AC.navy3,
        iconTheme: IconThemeData(color: AC.gold)),
      backgroundColor: AC.navy,
      body: _loading
        ? Center(child: CircularProgressIndicator(color: AC.gold))
        : _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: AC.err)))
          : RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: EdgeInsets.all(16), children: [
              // Hero Section
              ApexHeroSection(
                title: '\u062e\u0637\u062a\u064a \u0648\u0627\u0644\u0627\u0634\u062a\u0631\u0627\u0643',
                description: '\u0625\u062f\u0627\u0631\u0629 \u062e\u0637\u062a\u0643 \u0627\u0644\u062d\u0627\u0644\u064a\u0629 \u0648\u0627\u0644\u062a\u0631\u0642\u064a\u0629 \u0644\u0644\u062d\u0635\u0648\u0644 \u0639\u0644\u0649 \u0645\u064a\u0632\u0627\u062a \u0623\u0643\u062b\u0631',
                icon: Icons.workspace_premium_rounded,
              ),
              // Current Plan Card
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AC.gold.withValues(alpha: 0.10), AC.navy2],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: AC.gold.withValues(alpha: 0.08), blurRadius: 20, offset: Offset(0, 4))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.workspace_premium, color: AC.gold, size: 32),
                    SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('الخطة الحالية', style: TextStyle(color: AC.ts, fontSize: 12)),
                      Text(currentPlan, style: TextStyle(color: AC.gold, fontSize: 24, fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  Divider(color: AC.bdr),
                  const SizedBox(height: 12),
                  Text('الميزات المتاحة:', style: TextStyle(color: AC.ts, fontSize: 13)),
                  SizedBox(height: 8),
                  ...features.map<Widget>((f) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Icon(f['is_available'] == true ? Icons.check_circle : Icons.cancel,
                        color: f['is_available'] == true ? AC.ok : AC.err, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text(f['name_ar'] ?? f['key'],
                        style: TextStyle(color: AC.tp, fontSize: 13))),
                      Text('${f['display_value'] ?? f['value'] ?? ''}',
                        style: TextStyle(color: f['is_available'] == true ? AC.ok : AC.ts, fontSize: 12)),
                    ]),
                  )),
                ]),
              ),

              SizedBox(height: 24),
              Text('ترقية خطتك', style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Available Plans
              ..._plans.map<Widget>((plan) {
                final name = plan['name_ar'] ?? plan['name_en'] ?? plan['name'] ?? plan['code'] ?? '';
                final code = plan['code'] ?? '';
                final isCurrent = name == currentPlan || code == currentPlan;
                final price = plan['price_monthly_sar'] ?? plan['pricing']?['monthly'] ?? 0;
                final featuresMap = plan['features'] as Map<String, dynamic>? ?? {};
                final featureCount = featuresMap.length;
                final desc = plan['description_ar'] ?? '';

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.all(16),
                  decoration: apexSelectableDecoration(isSelected: isCurrent, activeColor: AC.gold),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(name, style: TextStyle(
                          color: isCurrent ? AC.gold : AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
                        if (isCurrent) ...[
                          SizedBox(width: 8),
                          Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(8)),
                            child: Text('الحالية', style: TextStyle(color: AC.btnFg, fontSize: 10, fontWeight: FontWeight.bold))),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(price is num && price > 0 ? '$price ر.س/شهرياً' : (desc.isNotEmpty ? desc : 'مجاني'),
                        style: TextStyle(color: AC.ts, fontSize: 12)),
                      Text('$featureCount ميزة متاحة', style: TextStyle(color: AC.ts, fontSize: 11)),
                    ])),
                    if (!isCurrent)
                      apexPrimaryButton(
                        code == 'enterprise' ? '\u062a\u0648\u0627\u0635\u0644 \u0645\u0639\u0646\u0627' : '\u062a\u0631\u0642\u064a\u0629',
                        () => _upgrade(code.isNotEmpty ? code : name),
                        icon: code == 'enterprise' ? Icons.chat_rounded : Icons.upgrade_rounded,
                      ),
                  ]),
                );
              }),
            ])),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// EntitlementGateWidget — يغلق الميزات حسب الخطة
// ═══════════════════════════════════════════════════════════
class EntitlementGate extends StatelessWidget {
  final String feature;
  final Widget child;
  final Widget? lockedWidget;

  const EntitlementGate({super.key, required this.feature, required this.child, this.lockedWidget});

  @override
  Widget build(BuildContext context) {
    // This would check entitlements from cached user data
    // For now, show child always — entitlement check happens on API side
    return child;
  }
}

// ═══════════════════════════════════════════════════════════
// PlanComparisonScreen — مقارنة الخطط
// ═══════════════════════════════════════════════════════════
class PlanComparisonScreen extends StatefulWidget {
  const PlanComparisonScreen({super.key});
  @override State<PlanComparisonScreen> createState() => _PlanComparisonScreenState();
}
class _PlanComparisonScreenState extends State<PlanComparisonScreen> {
  List<dynamic> _comparison = [];
  List<String> _planNames = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final r = await ApiService.comparePlans();
    if (r.success) {
      _comparison = r.data['comparison'] ?? [];
      _planNames = List<String>.from(r.data['plans'] ?? []);
    }
    setState(() { _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(title: Text('مقارنة الخطط'), backgroundColor: AC.navy3,
        iconTheme: IconThemeData(color: AC.gold)),
      backgroundColor: AC.navy,
      body: _loading
        ? Center(child: CircularProgressIndicator(color: AC.gold))
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DataTable(
                headingRowColor: WidgetStateProperty.all(AC.navy3),
                columns: [
                  DataColumn(label: Text('\u0627\u0644\u0645\u064a\u0632\u0629', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold))),
                  ..._planNames.map((p) => DataColumn(
                    label: Text(p, style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)))),
                ],
                rows: _comparison.map<DataRow>((row) => DataRow(cells: [
                  DataCell(Text(row['name_ar'] ?? '', style: TextStyle(color: AC.tp, fontSize: 12))),
                  ..._planNames.map((p) => DataCell(
                    Text(_formatCellValue(row[p] ?? 'N/A'),
                      style: TextStyle(color: _cellColor(row[p] ?? ''), fontSize: 11)))),
                ])).toList(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ApexTableLegend(items: [
                  MapEntry('\u0645\u062a\u0627\u062d', AC.ok),
                  MapEntry('\u063a\u064a\u0631 \u0645\u062a\u0627\u062d', AC.err),
                  MapEntry('\u063a\u064a\u0631 \u0645\u062d\u062f\u0648\u062f', AC.gold),
                ]),
              ),
            ]),
          )),
    ));
  }

  String _formatCellValue(String v) {
    if (v == 'true') return '✅';
    if (v == 'false') return '❌';
    if (v == 'unlimited') return '♾️';
    if (v == 'none') return '—';
    return v;
  }

  Color _cellColor(String v) {
    if (v == 'true' || v == 'unlimited') return AC.ok;
    if (v == 'false' || v == 'none') return AC.err;
    return AC.tp;
  }
}

// ═══════════════════════════════════════════════════════════
// Phase 9 Account Center §6
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// NotificationCenterScreen — مركز الإشعارات (API-driven)
// Phase 10 Notification System §13
// ═══════════════════════════════════════════════════════════
