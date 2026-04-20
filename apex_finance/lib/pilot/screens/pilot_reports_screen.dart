/// Pilot Reports — ميزان مراجعة، قائمة دخل، مركز مالي مباشرة من API.
/// ═════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/pilot_session_provider.dart';
import '../providers/pilot_data_providers.dart';

class PilotReportsScreen extends ConsumerStatefulWidget {
  const PilotReportsScreen({super.key});
  @override
  ConsumerState<PilotReportsScreen> createState() =>
      _PilotReportsScreenState();
}

class _PilotReportsScreenState extends ConsumerState<PilotReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _t;

  @override
  void initState() {
    super.initState();
    _t = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(pilotSessionProvider);
    if (!selection.hasEntity) {
      return Center(
          child: Text('اختر كياناً أولاً', style: TextStyle(color: AC.ts)));
    }
    return Column(children: [
      Container(
        color: AC.navy2,
        child: TabBar(
          controller: _t,
          isScrollable: true,
          indicatorColor: AC.gold,
          labelColor: AC.gold,
          unselectedLabelColor: AC.ts,
          tabs: const [
            Tab(icon: Icon(Icons.balance), text: 'ميزان المراجعة'),
            Tab(icon: Icon(Icons.trending_up), text: 'قائمة الدخل'),
            Tab(icon: Icon(Icons.account_balance), text: 'المركز المالي'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _t,
          children: [
            _TrialBalanceTab(entityId: selection.entityId!),
            _IncomeStatementTab(entityId: selection.entityId!),
            _BalanceSheetTab(entityId: selection.entityId!),
          ],
        ),
      ),
    ]);
  }
}

class _TrialBalanceTab extends ConsumerWidget {
  final String entityId;
  const _TrialBalanceTab({required this.entityId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final q = TrialBalanceQuery(entityId: entityId, asOf: today);
    final tb = ref.watch(trialBalanceProvider(q));
    return tb.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e', style: TextStyle(color: AC.err))),
      data: (d) {
        if (d == null) {
          return Center(child: Text('لا توجد بيانات', style: TextStyle(color: AC.td)));
        }
        final rows = (d['rows'] as List?) ?? [];
        final balanced = d['balanced'] == true;
        return Column(children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AC.navy3,
            child: Row(children: [
              Text('كما في: $today',
                  style: TextStyle(color: AC.tp, fontWeight: FontWeight.w500)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: balanced ? AC.ok.withValues(alpha: 0.15) : AC.err.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(balanced ? '✓ متوازن' : '⚠ غير متوازن',
                    style: TextStyle(
                        color: balanced ? AC.ok : AC.err,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Text('Σ د: ${d['total_debit']}  |  Σ د: ${d['total_credit']}',
                  style: TextStyle(color: AC.ts, fontSize: 13)),
            ]),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(color: AC.bdr, height: 1),
              itemBuilder: (_, i) {
                final r = rows[i] as Map;
                final dr = double.tryParse('${r['total_debit']}') ?? 0;
                final cr = double.tryParse('${r['total_credit']}') ?? 0;
                final bal = double.tryParse('${r['balance']}') ?? 0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    SizedBox(
                      width: 60,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AC.navy3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(r['code'] ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AC.gold, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['name_ar'] ?? '',
                              style: TextStyle(color: AC.tp, fontSize: 14)),
                          Text('${r['category']}',
                              style: TextStyle(color: AC.td, fontSize: 11)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(dr.toStringAsFixed(2),
                          textAlign: TextAlign.end,
                          style: TextStyle(color: AC.ts)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(cr.toStringAsFixed(2),
                          textAlign: TextAlign.end,
                          style: TextStyle(color: AC.ts)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(bal.toStringAsFixed(2),
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              color: AC.tp, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                );
              },
            ),
          ),
        ]);
      },
    );
  }
}

class _IncomeStatementTab extends ConsumerWidget {
  final String entityId;
  const _IncomeStatementTab({required this.entityId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthStart = '${now.year}-${now.month.toString().padLeft(2, '0')}-01';
    final today = now.toIso8601String().substring(0, 10);
    final q = DateRange(entityId: entityId, start: monthStart, end: today);
    final inc = ref.watch(incomeStatementProvider(q));
    return inc.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e', style: TextStyle(color: AC.err))),
      data: (d) {
        if (d == null) return Center(child: Text('لا توجد بيانات', style: TextStyle(color: AC.td)));
        final net = (d['net_income'] ?? 0) as num;
        final revenueSub = (d['revenue_by_subcat'] as Map?) ?? {};
        final expenseSub = (d['expense_by_subcat'] as Map?) ?? {};
        return ListView(padding: const EdgeInsets.all(16), children: [
          Text('الفترة: $monthStart → $today',
              style: TextStyle(color: AC.ts)),
          const SizedBox(height: 20),
          _section('الإيرادات', revenueSub, AC.ok, d['revenue_total']),
          const SizedBox(height: 20),
          _section('المصروفات', expenseSub, AC.err, d['expense_total']),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: (net >= 0 ? AC.ok : AC.err).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: net >= 0 ? AC.ok : AC.err),
            ),
            child: Row(children: [
              Icon(net >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: net >= 0 ? AC.ok : AC.err, size: 32),
              const SizedBox(width: 12),
              Expanded(
                  child: Text('صافي الدخل',
                      style: TextStyle(color: AC.tp, fontSize: 18, fontWeight: FontWeight.bold))),
              Text('${net.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: net >= 0 ? AC.ok : AC.err,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _section(String title, Map data, Color color, dynamic total) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(),
          ...data.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(
                      child: Text('${e.key}',
                          style: TextStyle(color: AC.ts))),
                  Text('${(e.value as num).toStringAsFixed(2)}',
                      style: TextStyle(color: AC.tp)),
                ]),
              )),
          const Divider(),
          Row(children: [
            Expanded(
                child: Text('المجموع',
                    style: TextStyle(color: AC.tp, fontWeight: FontWeight.w600))),
            Text('${(total as num).toStringAsFixed(2)}',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ]),
      );
}

class _BalanceSheetTab extends ConsumerWidget {
  final String entityId;
  const _BalanceSheetTab({required this.entityId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final q = TrialBalanceQuery(entityId: entityId, asOf: today);
    final bs = ref.watch(balanceSheetProvider(q));
    return bs.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e', style: TextStyle(color: AC.err))),
      data: (d) {
        if (d == null) return Center(child: Text('لا توجد بيانات', style: TextStyle(color: AC.td)));
        final assets = (d['assets'] ?? 0) as num;
        final liabilities = (d['liabilities'] ?? 0) as num;
        final equity = (d['total_equity'] ?? 0) as num;
        final balanced = d['balanced'] == true;
        final diff = (d['difference'] ?? 0) as num;

        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Text('كما في: $today', style: TextStyle(color: AC.ts)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: balanced ? AC.ok.withValues(alpha: 0.15) : AC.err.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                  balanced
                      ? '✓ الميزانية متوازنة'
                      : '⚠ فرق: ${diff.toStringAsFixed(2)}',
                  style: TextStyle(
                      color: balanced ? AC.ok : AC.err,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 24),
          _bsCard('الأصول', assets, AC.info, Icons.account_balance_wallet),
          const SizedBox(height: 12),
          _bsCard('الالتزامات', liabilities, AC.warn, Icons.credit_card),
          const SizedBox(height: 12),
          _bsCard('حقوق الملكية', equity, AC.gold, Icons.savings),
          const SizedBox(height: 24),
          Text('المعادلة: الأصول = الالتزامات + حقوق الملكية',
              textAlign: TextAlign.center,
              style: TextStyle(color: AC.ts)),
          const SizedBox(height: 8),
          Text(
              '${assets.toStringAsFixed(2)} = ${liabilities.toStringAsFixed(2)} + ${equity.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AC.tp, fontWeight: FontWeight.bold, fontSize: 16)),
        ]);
      },
    );
  }

  Widget _bsCard(String label, num val, Color color, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.bdr),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: AC.tp, fontSize: 18, fontWeight: FontWeight.w500))),
          Text(val.toStringAsFixed(2),
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      );
}
