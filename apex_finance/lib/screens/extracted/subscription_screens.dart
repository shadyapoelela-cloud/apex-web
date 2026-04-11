import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/shared_constants.dart';

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
        _plans = r2.data['plans'] ?? [];
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
      appBar: AppBar(title: const Text('خطتي والاشتراك'), backgroundColor: const Color(0xFF1E1E2E),
        iconTheme: const IconThemeData(color: AC.gold)),
      backgroundColor: const Color(0xFF0D0D1A),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AC.err)))
          : RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: const EdgeInsets.all(16), children: [
              // Current Plan Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AC.gold.withOpacity(0.3)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.workspace_premium, color: AC.gold, size: 32),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('الخطة الحالية', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(currentPlan, style: const TextStyle(color: AC.gold, fontSize: 24, fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),
                  const Text('الميزات المتاحة:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...features.map<Widget>((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(children: [
                      Icon(f['is_available'] == true ? Icons.check_circle : Icons.cancel,
                        color: f['is_available'] == true ? AC.ok : AC.err, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f['name_ar'] ?? f['key'],
                        style: const TextStyle(color: Colors.white, fontSize: 13))),
                      Text(f['display_value'] ?? f['value'],
                        style: TextStyle(color: f['is_available'] == true ? AC.ok : Colors.grey, fontSize: 12)),
                    ]),
                  )),
                ]),
              ),

              const SizedBox(height: 24),
              const Text('ترقية خطتك', style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Available Plans
              ..._plans.map<Widget>((plan) {
                final name = plan['name'];
                final isCurrent = name == currentPlan;
                final price = plan['pricing']?['monthly'] ?? 0;
                final featureCount = plan['feature_count'] ?? 0;
                final note = plan['pricing']?['note'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isCurrent ? AC.gold.withOpacity(0.1) : const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isCurrent ? AC.gold : Colors.white12),
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(name, style: TextStyle(
                          color: isCurrent ? AC.gold : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(8)),
                            child: const Text('الحالية', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))),
                        ],
                      ]),
                      const SizedBox(height: 4),
                      Text(price > 0 ? '$price ر.س/شهرياً' : (note ?? 'مجاني'),
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('$featureCount ميزة متاحة', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    ])),
                    if (!isCurrent)
                      ElevatedButton(
                        onPressed: () => _upgrade(name),
                        style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: Colors.black),
                        child: Text(name == 'Enterprise' ? 'تواصل معنا' : 'ترقية'),
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
      appBar: AppBar(title: const Text('مقارنة الخطط'), backgroundColor: const Color(0xFF1E1E2E),
        iconTheme: const IconThemeData(color: AC.gold)),
      backgroundColor: const Color(0xFF0D0D1A),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: SingleChildScrollView(child:
            DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFF1E1E2E)),
              columns: [
                const DataColumn(label: Text('الميزة', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold))),
                ..._planNames.map((p) => DataColumn(
                  label: Text(p, style: const TextStyle(color: AC.gold, fontWeight: FontWeight.bold)))),
              ],
              rows: _comparison.map<DataRow>((row) => DataRow(cells: [
                DataCell(Text(row['name_ar'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 12))),
                ..._planNames.map((p) => DataCell(
                  Text(_formatCellValue(row[p] ?? 'N/A'),
                    style: TextStyle(color: _cellColor(row[p] ?? ''), fontSize: 11)))),
              ])).toList(),
            ),
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
    return Colors.white;
  }
}

// ═══════════════════════════════════════════════════════════
// Phase 9 Account Center §6
// ═══════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════
// NotificationCenterScreen — مركز الإشعارات (API-driven)
// Phase 10 Notification System §13
// ═══════════════════════════════════════════════════════════
