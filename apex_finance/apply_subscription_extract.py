"""
APEX V2 — تطبيق استخراج شاشات Subscription من main.dart
═══════════════════════════════════════════════════════════
شغّل من PowerShell:
  cd C:\apex_app\apex_finance
  py apply_subscription_extract.py

ما يفعله هذا السكربت:
1. ينسخ subscription_screens.dart إلى screens/subscription/
2. يضيف import في main.dart
3. يحوّل الاستدعاءات إلى sub.SubscriptionScreen() و sub.PlanComparisonScreen()
4. يحذف تعريفات الـ classes القديمة (سطر 2390-2628)
5. يحفظ بدون BOM
═══════════════════════════════════════════════════════════
"""
import os, shutil, re

BASE = r'C:\apex_app\apex_finance\lib'
MAIN = os.path.join(BASE, 'main.dart')

# ── Step 0: Backup ──
backup = MAIN + '.bak_sub_extract'
if not os.path.exists(backup):
    shutil.copy2(MAIN, backup)
    print(f'[✓] Backup → {backup}')
else:
    print(f'[i] Backup already exists')

# ── Step 1: Create screens/subscription/ folder ──
sub_dir = os.path.join(BASE, 'screens', 'subscription')
os.makedirs(sub_dir, exist_ok=True)
print(f'[✓] Created {sub_dir}')

# ── Step 2: Write subscription_screens.dart ──
sub_file = os.path.join(sub_dir, 'subscription_screens.dart')
SUB_CONTENT = r'''import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _api = 'https://apex-api-ootk.onrender.com';

// Import shared theme and session from core
import '../../core/theme.dart';
import '../../core/session.dart';

// ═══════════════════════════════════════════════════════════
// SubscriptionScreen — عرض الخطة الحالية + الترقية
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
      final token = S.token ?? '';
      final h = {'Authorization': 'Bearer $token'};

      // Load current subscription
      final r1 = await http.get(Uri.parse('$_api/subscriptions/me'), headers: h);
      if (r1.statusCode == 200) {
        _sub = jsonDecode(utf8.decode(r1.bodyBytes));
      }

      // Load available plans
      final r2 = await http.get(Uri.parse('$_api/subscriptions/plans'));
      if (r2.statusCode == 200) {
        _plans = jsonDecode(utf8.decode(r2.bodyBytes))['plans'] ?? [];
      }
    } catch (e) {
      _error = e.toString();
    }
    setState(() { _loading = false; });
  }

  Future<void> _upgrade(String planName) async {
    final token = S.token ?? '';
    final r = await http.post(
      Uri.parse('$_api/subscriptions/upgrade?plan_name=$planName'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode == 200) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم الترقية إلى $planName بنجاح!'), backgroundColor: AC.ok));
      _load();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الترقية: ${utf8.decode(r.bodyBytes)}'), backgroundColor: AC.err));
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
// EntitlementGate — يغلق الميزات حسب الخطة
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
    try {
      final r = await http.get(Uri.parse('$_api/plans/compare'));
      if (r.statusCode == 200) {
        final data = jsonDecode(utf8.decode(r.bodyBytes));
        _comparison = data['comparison'] ?? [];
        _planNames = List<String>.from(data['plans'] ?? []);
      }
    } catch (_) {}
    if (mounted) setState(() { _loading = false; });
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
'''

# Fix: subscription_screens.dart uses ../../core/ because it's in screens/subscription/
f = open(sub_file, 'w', encoding='utf-8')
f.write(SUB_CONTENT.strip() + '\n')
f.close()
print(f'[✓] Written subscription_screens.dart ({len(SUB_CONTENT.strip())} chars)')

# ── Step 3: Read main.dart ──
f = open(MAIN, 'r', encoding='utf-8-sig')  # utf-8-sig strips BOM
lines = f.readlines()
f.close()
original_count = len(lines)
print(f'[i] main.dart: {original_count} lines')

# ── Step 4: Add import after last screen import ──
# Find the line with last 'import.*screens/' and add after it
import_line = "import 'screens/subscription/subscription_screens.dart' as sub;\n"
inserted = False
for i, line in enumerate(lines):
    if "import 'screens/tasks/audit_service_screen.dart'" in line:
        lines.insert(i + 1, import_line)
        inserted = True
        print(f'[✓] Added import at line {i + 2}')
        break

if not inserted:
    # Fallback: add after last import
    for i in range(len(lines) - 1, -1, -1):
        if lines[i].strip().startswith('import '):
            lines.insert(i + 1, import_line)
            print(f'[✓] Added import at line {i + 2} (fallback)')
            break

# ── Step 5: Replace SubscriptionScreen() and PlanComparisonScreen() calls ──
replacements = 0
for i, line in enumerate(lines):
    # Skip the import line we just added
    if 'subscription_screens.dart' in line:
        continue
    # Skip class definitions (they'll be removed)
    if line.strip().startswith('class Subscription') or line.strip().startswith('class PlanComparison') or line.strip().startswith('class EntitlementGate'):
        continue

    new_line = line
    if 'SubscriptionScreen()' in new_line and 'class ' not in new_line:
        new_line = new_line.replace('SubscriptionScreen()', 'sub.SubscriptionScreen()')
        if new_line != line:
            replacements += 1
    if 'PlanComparisonScreen()' in new_line and 'class ' not in new_line:
        new_line = new_line.replace('PlanComparisonScreen()', 'sub.PlanComparisonScreen()')
        if new_line != line:
            replacements += 1
    if 'EntitlementGate(' in new_line and 'class ' not in new_line:
        new_line = new_line.replace('EntitlementGate(', 'sub.EntitlementGate(')
        if new_line != line:
            replacements += 1
    lines[i] = new_line

print(f'[✓] Replaced {replacements} class references → sub.*')

# ── Step 6: Remove old class definitions (lines 2390-2628 approx) ──
# Find the exact start: comment before SubscriptionScreen
# Find the exact end: empty line or comment before NotificationCenterScreenV2
start_del = None
end_del = None

for i, line in enumerate(lines):
    if '// SubscriptionScreen' in line and 'عرض الخطة' in line:
        # Go back to find the separator line
        start_del = i
        if i > 0 and '════' in lines[i - 1]:
            start_del = i - 1
        if i > 1 and '════' in lines[i - 2]:
            start_del = i - 2
        break

for i, line in enumerate(lines):
    if 'class NotificationCenterScreenV2' in line:
        # End just before the NotificationCenter comment block
        end_del = i
        # Go back to find separator comments
        while end_del > 0 and ('════' in lines[end_del - 1] or '// ' in lines[end_del - 1] and 'Notification' in lines[end_del - 1]):
            end_del -= 1
        break

if start_del is not None and end_del is not None:
    removed = end_del - start_del
    del lines[start_del:end_del]
    print(f'[✓] Removed {removed} lines (old Subscription classes) from line {start_del + 1}')
else:
    print(f'[!] Could not find exact boundaries. start={start_del}, end={end_del}')
    print(f'    Manual removal needed: delete Subscription/EntitlementGate/PlanComparison classes')

# ── Step 7: Write main.dart without BOM ──
f = open(MAIN, 'w', encoding='utf-8')
f.write(''.join(lines))
f.close()

final_count = len(lines)
print(f'\n{"="*50}')
print(f'[✓] DONE!')
print(f'    main.dart: {original_count} → {final_count} lines (removed {original_count - final_count})')
print(f'    New file: screens/subscription/subscription_screens.dart')
print(f'    Backup: {backup}')
print(f'{"="*50}')
print(f'\nNext: Run "flutter analyze" to verify no errors')
