/// APEX — Today Dashboard
/// ═══════════════════════════════════════════════════════════════════════
/// First screen the user sees after onboarding. Five KPI cards (Stripe-
/// pattern + Linear-pattern):
///
///   1. النقد المتاح        ← BS.assets[1110+1120]
///   2. صافي الدخل اليوم    ← IS revenue − expense (today)
///   3. AR (الذمم المدينة)  ← BS or TB account 1130
///   4. الفواتير غير المُحصّلة ← invoices.status='issued' SUM(total)
///   5. عدد الفواتير اليوم   ← invoices count where issue_date == today
///
/// Plus an "AI Pulse" line of running commentary in Arabic.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_anomaly_feed.dart';
import '../../core/hijri_date.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class TodayDashboardScreen extends StatefulWidget {
  const TodayDashboardScreen({super.key});
  @override
  State<TodayDashboardScreen> createState() => _TodayDashboardScreenState();
}

class _TodayDashboardScreenState extends State<TodayDashboardScreen> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _bs;
  Map<String, dynamic>? _is;
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _customers = [];
  String? _aiPulseRemote;
  bool _aiPulseLoading = false;

  // Express Invoice
  final _expressAmountCtrl = TextEditingController(text: '5000');
  bool _expressSubmitting = false;
  String? get _firstCustomerId =>
      _customers.isEmpty ? null : _customers.first['id'] as String?;
  String? get _firstCustomerName =>
      _customers.isEmpty ? null : _customers.first['name_ar'] as String?;

  @override
  void dispose() {
    _expressAmountCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final entityId = S.savedEntityId;
    if (entityId == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _aiPulseRemote = null;
    });
    final today = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final tenantId = S.savedTenantId ?? '';
    final results = await Future.wait([
      ApiService.pilotBalanceSheet(entityId, asOf: fmt(today)),
      ApiService.pilotIncomeStatement(entityId,
          startDate: '${today.year}-01-01', endDate: fmt(today)),
      ApiService.pilotListSalesInvoices(entityId, limit: 50),
      ApiService.pilotListCustomers(tenantId),
    ]);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (results[0].success && results[0].data is Map) _bs = results[0].data as Map<String, dynamic>;
      if (results[1].success && results[1].data is Map) _is = results[1].data as Map<String, dynamic>;
      if (results[2].success && results[2].data is List) {
        _invoices = (results[2].data as List).cast<Map<String, dynamic>>();
      }
      if (results[3].success && results[3].data is List) {
        _customers = (results[3].data as List).cast<Map<String, dynamic>>();
      }
    });
    // Fire-and-forget: ask Claude for an Arabic 1-line variance commentary.
    _fetchAiPulse();
  }

  Future<void> _confirmResetDemo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إعادة تحميل البيانات التجريبية؟',
            style: TextStyle(color: AC.gold, fontSize: 15)),
        content: Text(
          'سيتم إنشاء 5 عملاء تجريبيين و3 قيود يومية إضافية لكيانك. لن تُحذف بياناتك الحالية.',
          style: TextStyle(color: AC.tp, fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    if (tenantId == null || entityId == null) return;
    final res = await ApiService.aiOnboardingSeedDemo(tenantId: tenantId, entityId: entityId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: res.success ? AC.ok : AC.err,
      content: Text(res.success ? 'تم تحميل بيانات تجريبية إضافية' : 'فشل: ${res.error ?? '-'}'),
    ));
    if (res.success) _loadAll();
  }

  Future<void> _expressIssue() async {
    final tenantId = S.savedTenantId;
    final entityId = S.savedEntityId;
    final custId = _firstCustomerId;
    if (tenantId == null || entityId == null || custId == null) return;
    final amount = double.tryParse(_expressAmountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('المبلغ غير صحيح')));
      return;
    }
    setState(() => _expressSubmitting = true);
    final today = DateTime.now();
    final due = today.add(const Duration(days: 30));
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final create = await ApiService.pilotCreateSalesInvoice({
      'tenant_id': tenantId,
      'entity_id': entityId,
      'customer_id': custId,
      'issue_date': fmt(today),
      'due_date': fmt(due),
      'currency': 'SAR',
      'lines': [
        {'description': 'فاتورة سريعة', 'quantity': 1, 'unit_price': amount, 'vat_rate': 15},
      ],
    });
    if (!mounted) return;
    if (!create.success) {
      setState(() => _expressSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.err,
        content: Text('فشل: ${create.error ?? '-'}'),
      ));
      return;
    }
    final invId = (create.data as Map?)?['id'] as String?;
    if (invId == null) {
      setState(() => _expressSubmitting = false);
      return;
    }
    final issue = await ApiService.pilotIssueSalesInvoice(invId);
    if (!mounted) return;
    setState(() => _expressSubmitting = false);
    if (!issue.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AC.err,
        content: Text('الإصدار فشل: ${issue.error ?? '-'}'),
      ));
      return;
    }
    final jeId = (issue.data as Map?)?['journal_entry_id'] as String?;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.ok,
      content: Text('تمت الفاتورة! JE: ${jeId?.substring(0, 8) ?? ""}…'),
      action: jeId == null
          ? null
          : SnackBarAction(
              label: 'عرض',
              textColor: AC.navy,
              onPressed: () => context.go('/app/erp/finance/je-builder/$jeId'),
            ),
    ));
    _expressAmountCtrl.clear();
    _loadAll();
  }

  /// Calls /api/v1/ai/ask with a structured prompt feeding the live KPIs.
  /// No tool calls needed — Claude just composes a single-line summary.
  /// Falls back silently to the local heuristic if the call errors out.
  Future<void> _fetchAiPulse() async {
    if (_aiPulseLoading) return;
    setState(() => _aiPulseLoading = true);
    final prompt = '''بناءً على هذه المؤشرات:
- النقد + الأصول: ${_cash.toStringAsFixed(0)} ريال
- صافي الدخل (السنة حتى الآن): ${_netIncome.toStringAsFixed(0)} ريال
- إجمالي الإيرادات: ${_revenue.toStringAsFixed(0)} ريال
- إجمالي المصاريف: ${_expense.toStringAsFixed(0)} ريال
- الذمم غير المُحصّلة: ${_outstandingAR.toStringAsFixed(0)} ريال
- عدد فواتير اليوم: $_todayInvoicesCount
- إجمالي الفواتير: ${_invoices.length}

اكتب جملة عربية واحدة (≤25 كلمة) تلخّص الأداء وتقترح إجراءً واحداً ملموساً. لا مقدمات، لا قوائم، فقط جملة واحدة مباشرة.''';
    final res = await ApiService.aiAsk(prompt, maxTurns: 1);
    if (!mounted) return;
    setState(() {
      _aiPulseLoading = false;
      if (res.success && res.data is Map) {
        final answer = (res.data as Map)['answer'] ?? (res.data as Map)['response'] ?? (res.data as Map)['text'];
        if (answer is String && answer.trim().isNotEmpty) {
          _aiPulseRemote = answer.trim();
        }
      }
    });
  }

  double get _cash => (_bs?['assets'] as num?)?.toDouble() ?? 0;
  double get _revenue => (_is?['revenue_total'] as num?)?.toDouble() ?? 0;
  double get _expense => (_is?['expense_total'] as num?)?.toDouble() ?? 0;
  double get _netIncome => (_is?['net_income'] as num?)?.toDouble() ?? 0;
  double get _outstandingAR =>
      _invoices.where((i) => i['status'] == 'issued').fold<double>(
            0,
            (acc, i) => acc + ((i['total'] as num?)?.toDouble() ?? 0) - ((i['paid_amount'] as num?)?.toDouble() ?? 0),
          );
  int get _todayInvoicesCount {
    final today = DateTime.now();
    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final t = fmt(today);
    return _invoices.where((i) => i['issue_date'] == t).length;
  }

  /// Generates an Arabic narrative about the current state — local heuristic.
  /// (Will be swapped for the AI Copilot endpoint in a later wave.)
  String _aiPulse() {
    if (_invoices.isEmpty) {
      return 'ابدأ بإصدار أول فاتورة لتظهر مؤشراتك المالية.';
    }
    if (_netIncome > 0) {
      return 'أداء جيد — صافي الدخل ${_netIncome.toStringAsFixed(0)} ريال هذه السنة. حافظ على الزخم.';
    }
    if (_outstandingAR > 0) {
      return 'لديك ${_outstandingAR.toStringAsFixed(0)} ريال في الذمم. ضع خطة تحصيل.';
    }
    return 'كيانك جاهز للنشاط — أصدر فاتورتك الأولى.';
  }

  @override
  Widget build(BuildContext context) {
    final entityId = S.savedEntityId;
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('اليوم — APEX', style: TextStyle(color: AC.gold)),
        actions: [
          IconButton(
            icon: Icon(Icons.apps, color: AC.gold),
            tooltip: 'كل التطبيقات (Launchpad)',
            onPressed: () => context.go('/launchpad'),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AC.gold),
            onPressed: _loading ? null : _loadAll,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AC.gold),
            color: AC.navy2,
            onSelected: (v) {
              if (v == 'reset') _confirmResetDemo();
              if (v == 'switch') context.go('/onboarding');
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reset',
                child: Row(children: [
                  Icon(Icons.refresh, color: AC.warn, size: 16),
                  const SizedBox(width: 8),
                  Text('إعادة تحميل البيانات التجريبية',
                      style: TextStyle(color: AC.tp, fontSize: 12)),
                ]),
              ),
              PopupMenuItem(
                value: 'switch',
                child: Row(children: [
                  Icon(Icons.swap_horiz, color: AC.gold, size: 16),
                  const SizedBox(width: 8),
                  Text('إنشاء كيان جديد',
                      style: TextStyle(color: AC.tp, fontSize: 12)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: entityId == null
          ? _emptyState()
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _dateHeader(),
                  const SizedBox(height: 12),
                  _aiPulseCard(),
                  const SizedBox(height: 16),
                  _kpiGrid(),
                  const SizedBox(height: 16),
                  ApexAnomalyFeedCard(
                    onSeeAll: () => context.go('/audit'),
                  ),
                  const SizedBox(height: 16),
                  _expressInvoiceCard(),
                  const SizedBox(height: 12),
                  _quickActions(),
                  const SizedBox(height: 16),
                  _recentInvoices(),
                ]),
              ),
            ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.dashboard_outlined, color: AC.ts, size: 64),
            const SizedBox(height: 12),
            Text('لا يوجد كيان نشط', style: TextStyle(color: AC.tp, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.rocket_launch),
              label: const Text('بدء التسجيل'),
              onPressed: () => context.go('/onboarding'),
              style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy),
            ),
          ]),
        ),
      );

  Widget _dateHeader() {
    final now = DateTime.now();
    final hijri = HijriDate.fromGregorian(now);
    const arabicWeekdays = [
      'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس',
      'الجمعة', 'السبت', 'الأحد',
    ];
    final weekday = arabicWeekdays[(now.weekday - 1).clamp(0, 6)];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AC.bdr),
      ),
      child: Row(children: [
        Icon(Icons.calendar_today_outlined, color: AC.gold, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(weekday, style: TextStyle(color: AC.ts, fontSize: 11)),
            Text(
              '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')} م · ${hijri.formatLong()}',
              style: TextStyle(color: AC.tp, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _aiPulseCard() {
    final text = _aiPulseRemote ?? (_loading ? 'جارٍ تحديث المؤشرات…' : _aiPulse());
    final isLive = _aiPulseRemote != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AC.gold.withValues(alpha: 0.18), AC.navy3],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.auto_awesome, color: AC.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Text(isLive ? 'تعليق الذكاء الاصطناعي' : 'مؤشر سريع',
                    style: TextStyle(
                        color: AC.gold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3)),
                if (_aiPulseLoading) ...[
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 9, height: 9,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AC.gold),
                  ),
                ],
              ]),
              const SizedBox(height: 3),
              Text(
                text,
                style: TextStyle(color: AC.tp, fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _kpiGrid() {
    final cards = [
      _KpiCard(
        title: 'النقد + الأصول',
        value: _cash.toStringAsFixed(0),
        unit: 'ريال',
        icon: Icons.account_balance,
        color: AC.gold,
        onTap: () => context.go('/app/erp/finance/statements'),
      ),
      _KpiCard(
        title: 'صافي الدخل (السنة)',
        value: _netIncome.toStringAsFixed(0),
        unit: 'ريال',
        icon: _netIncome >= 0 ? Icons.trending_up : Icons.trending_down,
        color: _netIncome >= 0 ? AC.ok : AC.err,
        onTap: () => context.go('/app/erp/finance/statements'),
      ),
      _KpiCard(
        title: 'الذمم غير المُحصّلة',
        value: _outstandingAR.toStringAsFixed(0),
        unit: 'ريال',
        icon: Icons.pending_actions,
        color: AC.warn,
        onTap: () => context.go('/operations/live-sales-cycle'),
      ),
      _KpiCard(
        title: 'فواتير اليوم',
        value: '$_todayInvoicesCount',
        unit: 'فاتورة',
        icon: Icons.receipt_long,
        color: AC.info,
        onTap: () => context.go('/operations/live-sales-cycle'),
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
      childAspectRatio: 1.35,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: cards,
    );
  }

  /// Express Invoice — one-line quick create on the home screen.
  /// Picks the first customer; user just types amount + tap.
  /// Goal: ≤90s from login to first invoice (FreshBooks benchmark).
  Widget _expressInvoiceCard() {
    final hasCustomer = _firstCustomerId != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.flash_on, color: AC.gold, size: 18),
          const SizedBox(width: 8),
          Text('فاتورة سريعة',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (_firstCustomerName != null)
            Text(_firstCustomerName!,
                style: TextStyle(color: AC.ts, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _expressAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: AC.tp, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'المبلغ (قبل VAT)',
                labelStyle: TextStyle(color: AC.ts, fontSize: 11),
                isDense: true,
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: !hasCustomer || _expressSubmitting ? null : _expressIssue,
            icon: _expressSubmitting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 16),
            label: Text(_expressSubmitting ? '…' : 'أصدر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AC.gold, foregroundColor: AC.navy,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ]),
        if (!hasCustomer) Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('لا يوجد عملاء — أضف أحدهم من شاشة دورة المبيعات',
              style: TextStyle(color: AC.warn, fontSize: 10.5)),
        ),
      ]),
    );
  }

  Widget _quickActions() => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(child: _actionBtn(Icons.receipt_long, 'فاتورة',
              () => context.go('/sales'))),
          const SizedBox(width: 6),
          Expanded(child: _actionBtn(Icons.shopping_cart, 'مشتريات',
              () => context.go('/purchase'))),
          const SizedBox(width: 6),
          Expanded(child: _actionBtn(Icons.assessment, 'التقارير',
              () => context.go('/reports'))),
          const SizedBox(width: 6),
          Expanded(child: _actionBtn(Icons.verified_user, 'مراجعة',
              () => context.go('/audit'))),
          const SizedBox(width: 6),
          Expanded(child: _actionBtn(Icons.receipt, 'إيصال',
              () => context.go('/receipt/capture'))),
          const SizedBox(width: 6),
          Expanded(child: _actionBtn(Icons.smart_toy, 'AI',
              () => context.go('/copilot'))),
        ]),
      );

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) =>
      InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AC.navy3,
            border: Border.all(color: AC.bdr),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(children: [
            Icon(icon, color: AC.gold, size: 22),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: AC.tp, fontSize: 11.5)),
          ]),
        ),
      );

  Widget _recentInvoices() => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(children: [
              Icon(Icons.list_alt, color: AC.gold, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text('آخر الفواتير',
                    style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              if (_invoices.length > 5)
                TextButton(
                  onPressed: () => context.go('/operations/live-sales-cycle'),
                  child: Text('عرض الكل', style: TextStyle(color: AC.gold, fontSize: 11)),
                ),
            ]),
          ),
          if (_invoices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('لا توجد فواتير بعد — أنشئ أول فاتورة',
                    style: TextStyle(color: AC.ts, fontSize: 12.5)),
              ),
            )
          else
            ..._invoices.take(5).map((inv) {
              final isIssued = inv['status'] == 'issued';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5))),
                ),
                child: Row(children: [
                  Icon(isIssued ? Icons.check_circle : Icons.edit_note,
                      size: 14, color: isIssued ? AC.ok : AC.warn),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${inv['invoice_number']}',
                          style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('${inv['issue_date']} — ${isIssued ? "صادرة" : "مسودة"}',
                          style: TextStyle(color: AC.ts, fontSize: 10)),
                    ]),
                  ),
                  Text('${inv['total']} SAR',
                      style: TextStyle(
                          color: AC.gold, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                ]),
              );
            }),
        ]),
      );
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _KpiCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AC.navy2,
            border: Border.all(color: color.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              Icon(Icons.chevron_left, color: AC.ts, size: 14),
            ]),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(color: AC.ts, fontSize: 11)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace')),
            ),
            Text(unit, style: TextStyle(color: AC.ts, fontSize: 10)),
          ]),
        ),
      );
}
