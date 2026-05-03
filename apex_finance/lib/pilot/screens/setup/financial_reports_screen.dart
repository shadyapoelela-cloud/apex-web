/// Financial Reports — الأستاذ العام والقوائم المالية.
///
/// مستقلة — تعتمد على PilotSession.entityId.
///
/// التبويبات:
///   1) ميزان المراجعة (Trial Balance) — as_of date
///   2) قائمة الدخل (Income Statement) — period range
///   3) قائمة المركز المالي (Balance Sheet) — as_of date
library;

import 'package:flutter/material.dart';
import '../../../core/theme.dart' as core_theme;

import '../../api/pilot_client.dart';
import '../../export_utils.dart';
import '../../num_utils.dart';
import '../../services/entity_resolver.dart';
import '../../session.dart';

Color get _gold => core_theme.AC.gold;
Color get _navy => core_theme.AC.navy;
Color get _navy2 => core_theme.AC.navy2;
Color get _navy3 => core_theme.AC.navy3;
Color get _bdr => core_theme.AC.bdr;
final _tp = Color(0xFFFFFFFF);
Color get _ts => core_theme.AC.ts;
Color get _td => core_theme.AC.td;
Color get _ok => core_theme.AC.ok;
Color get _err => core_theme.AC.err;
Color get _warn => core_theme.AC.warn;
final _indigo = core_theme.AC.purple;

class FinancialReportsScreen extends StatefulWidget {
  const FinancialReportsScreen({super.key});
  @override
  State<FinancialReportsScreen> createState() => _FinancialReportsScreenState();
}

class _FinancialReportsScreenState extends State<FinancialReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final PilotClient _client = pilotClient;

  Map<String, dynamic>? _trialBalance;
  Map<String, dynamic>? _incomeStatement;
  Map<String, dynamic>? _balanceSheet;
  Map<String, dynamic>? _cashFlow;
  // للـ P&L و BS نحتاج تفاصيل الحسابات من TB (backend لا يُرجعها مع BS/IS)
  List<Map<String, dynamic>> _tbRowsForDetails = [];
  bool _loading = true;
  String? _error;

  DateTime _asOfDate = DateTime.now();
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(_onTabChange);
    _load();
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChange);
    _tab.dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (_tab.indexIsChanging) return;
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    // G-UX-2 (Sprint 13): replace dead-end error with smart resolver
    // (auto-select singleton entity / picker for multi / onboarding for none).
    // See lib/pilot/services/entity_resolver.dart.
    if (!PilotSession.hasEntity) {
      final resolved = await EntityResolver.ensureEntitySelected(context);
      if (!resolved) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }
    }
    final eid = PilotSession.entityId!;
    try {
      // نستدعي TB دائماً — مصدر تفاصيل الحسابات لكل التبويبات
      // (backend BS/IS يُرجعان إجماليات فقط، لا قوائم حسابات)
      final tbDate = _tab.index == 1
          ? _endDate.toIso8601String().substring(0, 10)
          : _asOfDate.toIso8601String().substring(0, 10);
      final tbR = await _client.trialBalance(eid,
          asOf: tbDate, includeZero: false);
      if (tbR.success && tbR.data is Map) {
        final tbMap = Map<String, dynamic>.from(tbR.data);
        final rows = tbMap['rows'];
        _tbRowsForDetails = rows is List
            ? List<Map<String, dynamic>>.from(rows)
            : [];
        if (_tab.index == 0) {
          _trialBalance = tbMap;
        }
      }

      if (_tab.index == 1) {
        final r = await _client.incomeStatement(
            eid,
            _startDate.toIso8601String().substring(0, 10),
            _endDate.toIso8601String().substring(0, 10));
        if (r.success && r.data is Map) {
          _incomeStatement = Map<String, dynamic>.from(r.data);
        } else {
          _error = r.error;
        }
      } else if (_tab.index == 2) {
        final r = await _client.balanceSheet(eid,
            asOf: _asOfDate.toIso8601String().substring(0, 10));
        if (r.success && r.data is Map) {
          _balanceSheet = Map<String, dynamic>.from(r.data);
        } else {
          _error = r.error;
        }
      } else if (_tab.index == 3) {
        final r = await _client.cashFlow(
            eid,
            _startDate.toIso8601String().substring(0, 10),
            _endDate.toIso8601String().substring(0, 10));
        if (r.success && r.data is Map) {
          _cashFlow = Map<String, dynamic>.from(r.data);
        } else {
          _error = r.error;
        }
      }
      // ignore: avoid_print
      print('[FinReports] _load success, tab=${_tab.index}');
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e, st) {
      // ignore: avoid_print
      print('[FinReports] _load caught exception: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: Column(children: [
          _header(),
          Container(
            color: _navy2,
            child: TabBar(
              controller: _tab,
              indicatorColor: _gold,
              labelColor: _gold,
              unselectedLabelColor: _ts,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              tabs: const [
                Tab(icon: Icon(Icons.balance, size: 16), text: 'ميزان المراجعة'),
                Tab(icon: Icon(Icons.trending_up, size: 16), text: 'قائمة الدخل'),
                Tab(icon: Icon(Icons.account_balance, size: 16), text: 'المركز المالي'),
                Tab(icon: Icon(Icons.waves, size: 16), text: 'التدفقات النقدية'),
              ],
            ),
          ),
          _dateControls(),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _gold))
                : _error != null
                    ? _errorView()
                    : TabBarView(controller: _tab, children: [
                        _trialBalanceTab(),
                        _incomeStatementTab(),
                        _balanceSheetTab(),
                        _cashFlowTab(),
                      ]),
          ),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
          color: _navy2, border: Border(bottom: BorderSide(color: _bdr))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.assessment, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التقارير المالية',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('ميزان المراجعة · قائمة الدخل · قائمة المركز المالي',
                style: TextStyle(color: _ts, fontSize: 12)),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _tp, side: BorderSide(color: _bdr)),
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('تحديث'),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _ok,
              side: BorderSide(color: _ok.withValues(alpha: 0.5))),
          onPressed: _exportExcel,
          icon: const Icon(Icons.table_chart, size: 16),
          label: const Text('Excel'),
        ),
        const SizedBox(width: 6),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _err,
              side: BorderSide(color: _err.withValues(alpha: 0.5))),
          onPressed: _exportPdf,
          icon: const Icon(Icons.picture_as_pdf, size: 16),
          label: const Text('PDF'),
        ),
      ]),
    );
  }

  // Helper: label للـ tab الحالي
  String _currentTabLabel() {
    switch (_tab.index) {
      case 0:
        return 'ميزان المراجعة';
      case 1:
        return 'قائمة الدخل';
      case 2:
        return 'قائمة المركز المالي';
      case 3:
        return 'قائمة التدفقات النقدية';
    }
    return 'تقرير مالي';
  }

  /// بناء الـ headers + rows للتصدير حسب التبويب الحالي
  Map<String, dynamic> _buildExportData() {
    if (_tab.index == 0 && _trialBalance != null) {
      final rows = (_trialBalance!['rows'] as List?) ?? [];
      return {
        'headers': [
          'الكود', 'الاسم العربي', 'الاسم الإنجليزي', 'الفئة',
          'مدين', 'دائن', 'الرصيد'
        ],
        'rows': rows.map((r) {
          final m = Map<String, dynamic>.from(r);
          return [
            m['code'] ?? '',
            m['name_ar'] ?? '',
            m['name_en'] ?? '',
            _categoryAr(m['category']),
            asDouble(m['total_debit']),
            asDouble(m['total_credit']),
            asDouble(m['balance']),
          ];
        }).toList(),
        'meta': {
          'كما في': _asOfDate.toIso8601String().substring(0, 10),
          'إجمالي مدين':
              asDouble(_trialBalance!['total_debits']).toStringAsFixed(2),
          'إجمالي دائن':
              asDouble(_trialBalance!['total_credits']).toStringAsFixed(2),
        },
      };
    } else if (_tab.index == 1 && _incomeStatement != null) {
      final rev = _tbRowsForDetails.where((r) => r['category'] == 'revenue');
      final exp = _tbRowsForDetails.where((r) => r['category'] == 'expense');
      final allRows = [
        ['--- الإيرادات ---', '', '', ''],
        ...rev.map((r) =>
            [r['code'] ?? '', r['name_ar'] ?? '', 'إيراد', asDouble(r['balance'])]),
        [
          'إجمالي الإيرادات', '', '',
          asDouble(_incomeStatement!['revenue_total'])
        ],
        ['', '', '', ''],
        ['--- المصروفات ---', '', '', ''],
        ...exp.map((r) =>
            [r['code'] ?? '', r['name_ar'] ?? '', 'مصروف', asDouble(r['balance'])]),
        [
          'إجمالي المصروفات', '', '',
          asDouble(_incomeStatement!['expense_total'])
        ],
        ['', '', '', ''],
        ['صافي الدخل', '', '', asDouble(_incomeStatement!['net_income'])],
      ];
      return {
        'headers': ['الكود', 'البيان', 'النوع', 'المبلغ'],
        'rows': allRows,
        'meta': {
          'من': _startDate.toIso8601String().substring(0, 10),
          'إلى': _endDate.toIso8601String().substring(0, 10),
        },
      };
    } else if (_tab.index == 2 && _balanceSheet != null) {
      final bs = _balanceSheet!;
      final assets = _tbRowsForDetails.where((r) => r['category'] == 'asset');
      final liabs = _tbRowsForDetails.where((r) => r['category'] == 'liability');
      final eq = _tbRowsForDetails.where((r) => r['category'] == 'equity');
      final allRows = [
        ['--- الأصول ---', '', ''],
        ...assets.map((r) =>
            [r['code'] ?? '', r['name_ar'] ?? '', asDouble(r['balance'])]),
        ['إجمالي الأصول', '', asDouble(bs['assets'])],
        ['', '', ''],
        ['--- الخصوم ---', '', ''],
        ...liabs.map((r) =>
            [r['code'] ?? '', r['name_ar'] ?? '', asDouble(r['balance'])]),
        ['إجمالي الخصوم', '', asDouble(bs['liabilities'])],
        ['', '', ''],
        ['--- حقوق الملكية ---', '', ''],
        ...eq.map((r) =>
            [r['code'] ?? '', r['name_ar'] ?? '', asDouble(r['balance'])]),
        [
          'صافي دخل السنة (غير مقفل)', '',
          asDouble(bs['current_earnings'])
        ],
        ['إجمالي حقوق الملكية', '', asDouble(bs['total_equity'])],
        ['', '', ''],
        [
          'إجمالي الخصوم + حقوق الملكية', '',
          asDouble(bs['liabilities']) + asDouble(bs['total_equity'])
        ],
      ];
      return {
        'headers': ['الكود', 'البيان', 'الرصيد'],
        'rows': allRows,
        'meta': {
          'كما في': _asOfDate.toIso8601String().substring(0, 10),
          'متوازن؟': bs['balanced'] == true ? 'نعم ✓' : 'لا',
        },
      };
    } else if (_tab.index == 3 && _cashFlow != null) {
      final cf = _cashFlow!;
      return {
        'headers': ['البند', 'المبلغ'],
        'rows': [
          ['صافي الدخل', asDouble(cf['net_income'])],
          ['التغيّر في الأصول المتداولة', asDouble(cf['ar_change'])],
          ['التغيّر في الخصوم المتداولة', asDouble(cf['ap_change'])],
          ['صافي التدفق التشغيلي', asDouble(cf['operating_cf'])],
          ['التدفق الاستثماري', asDouble(cf['investing_cf'])],
          ['التدفق التمويلي', asDouble(cf['financing_cf'])],
          ['', ''],
          ['النقدية أول الفترة', asDouble(cf['cash_beginning'])],
          ['النقدية نهاية الفترة', asDouble(cf['cash_ending'])],
          ['التغيّر الفعلي', asDouble(cf['actual_cash_change'])],
          ['الفرق', asDouble(cf['variance'])],
        ],
        'meta': {
          'من': _startDate.toIso8601String().substring(0, 10),
          'إلى': _endDate.toIso8601String().substring(0, 10),
        },
      };
    }
    return {'headers': <String>[], 'rows': <List<dynamic>>[], 'meta': {}};
  }

  void _exportExcel() {
    final data = _buildExportData();
    final headers = List<String>.from(data['headers'] as List);
    final rows = List<List<dynamic>>.from(data['rows'] as List);
    if (headers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _warn,
          content: Text('حمّل التقرير أولاً قبل التصدير')));
      return;
    }
    final filename =
        '${_currentTabLabel()}_${DateTime.now().toIso8601String().substring(0, 10)}';
    exportXlsx(
      headers: headers,
      rows: rows,
      filename: filename,
      sheetName: _currentTabLabel(),
      title: _currentTabLabel(),
      meta: Map<String, dynamic>.from(data['meta'] as Map),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _ok,
        content: Text('تم تصدير $filename.xlsx ✓')));
  }

  void _exportPdf() {
    final data = _buildExportData();
    final headers = List<String>.from(data['headers'] as List);
    final rows = List<List<dynamic>>.from(data['rows'] as List);
    if (headers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _warn,
          content: Text('حمّل التقرير أولاً قبل التصدير')));
      return;
    }
    // تحويل الصفوف إلى نصوص للعرض
    final stringRows = rows
        .map((r) => r.map((cell) {
              if (cell == null) return '';
              if (cell is num) return cell == 0 ? '—' : cell.toStringAsFixed(2);
              return cell.toString();
            }).toList())
        .toList();
    final meta = Map<String, dynamic>.from(data['meta'] as Map);
    final metaStr = meta.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
    printHtmlTable(
      title: _currentTabLabel(),
      companyName: 'APEX Pilot',
      companyMeta: metaStr,
      headers: headers,
      rows: stringRows,
      footer: 'تقرير تلقائي — APEX Pilot ERP',
    );
  }


  Widget _dateControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: _navy2.withValues(alpha: 0.5),
      child: Row(children: [
        if (_tab.index == 1) ...[
          Text('من:', style: TextStyle(color: _td, fontSize: 12)),
          const SizedBox(width: 6),
          _datePill(_startDate, (d) {
            setState(() => _startDate = d);
            _load();
          }),
          const SizedBox(width: 10),
          Text('إلى:', style: TextStyle(color: _td, fontSize: 12)),
          const SizedBox(width: 6),
          _datePill(_endDate, (d) {
            setState(() => _endDate = d);
            _load();
          }),
          const SizedBox(width: 16),
          _quickPeriod('هذا الشهر', () {
            final now = DateTime.now();
            setState(() {
              _startDate = DateTime(now.year, now.month, 1);
              _endDate = now;
            });
            _load();
          }),
          const SizedBox(width: 6),
          _quickPeriod('YTD', () {
            final now = DateTime.now();
            setState(() {
              _startDate = DateTime(now.year, 1, 1);
              _endDate = now;
            });
            _load();
          }),
        ] else ...[
          Text('كما في:', style: TextStyle(color: _td, fontSize: 12)),
          const SizedBox(width: 6),
          _datePill(_asOfDate, (d) {
            setState(() => _asOfDate = d);
            _load();
          }),
          const SizedBox(width: 16),
          _quickPeriod('اليوم', () {
            setState(() => _asOfDate = DateTime.now());
            _load();
          }),
          const SizedBox(width: 6),
          _quickPeriod('نهاية الشهر', () {
            final now = DateTime.now();
            setState(() => _asOfDate = DateTime(now.year, now.month + 1, 0));
            _load();
          }),
        ],
      ]),
    );
  }

  Widget _datePill(DateTime date, ValueChanged<DateTime> onChanged) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (d != null) onChanged(d);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today, color: _gold, size: 12),
          const SizedBox(width: 4),
          Text(
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                  color: _tp, fontSize: 11, fontFamily: 'monospace')),
        ]),
      ),
    );
  }

  Widget _quickPeriod(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: 0.3))),
        child: Text(label,
            style: TextStyle(
                color: _gold, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 1: Trial Balance
  // ════════════════════════════════════════════════════════════════════

  Widget _trialBalanceTab() {
    final tb = _trialBalance;
    if (tb == null) {
      return Center(
          child: Text('لا توجد بيانات',
              style: TextStyle(color: _ts, fontSize: 13)));
    }
    final rows = (tb['rows'] as List?) ?? [];
    final totalDebit = asDouble(tb['total_debits']);
    final totalCredit = asDouble(tb['total_credits']);
    final balanced = (totalDebit - totalCredit).abs() < 0.01;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Balance check banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (balanced ? _ok : _err).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: (balanced ? _ok : _err).withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(balanced ? Icons.check_circle : Icons.warning,
                color: balanced ? _ok : _err, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  balanced
                      ? 'الميزان متوازن ✓ مجموع المدين = مجموع الدائن'
                      : 'الميزان غير متوازن! الفرق: ${_fmt((totalDebit - totalCredit).abs())}',
                  style: TextStyle(
                      color: balanced ? _ok : _err,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('مدين: ${_fmt(totalDebit)}',
                    style: TextStyle(
                        color: _ok,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace')),
                Text('دائن: ${_fmt(totalCredit)}',
                    style: TextStyle(
                        color: _indigo,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace')),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr),
          ),
          child: Row(children: [
            SizedBox(width: 90, child: Text('الكود', style: _th)),
            Expanded(flex: 3, child: Text('اسم الحساب', style: _th)),
            SizedBox(width: 90, child: Text('الفئة', style: _th)),
            SizedBox(
                width: 140,
                child: Text('مدين', style: _th, textAlign: TextAlign.end)),
            SizedBox(
                width: 140,
                child: Text('دائن', style: _th, textAlign: TextAlign.end)),
            SizedBox(
                width: 140,
                child: Text('الرصيد', style: _th, textAlign: TextAlign.end)),
          ]),
        ),
        const SizedBox(height: 6),
        ...rows.map((r) => _tbRow(Map<String, dynamic>.from(r))),
      ],
    );
  }

  Widget _tbRow(Map<String, dynamic> r) {
    final debit = asDouble(r['total_debit']);
    final credit = asDouble(r['total_credit']);
    final balance = asDouble(r['balance']);
    return InkWell(
      onTap: () => _showAccountLedger(r),
      borderRadius: BorderRadius.circular(5),
      child: Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text(r['code'] ?? '',
              style: TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r['name_ar'] ?? '',
                  style: TextStyle(color: _tp, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              if ((r['name_en'] ?? '').toString().isNotEmpty)
                Text(r['name_en'],
                    style: TextStyle(color: _td, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(_categoryAr(r['category']),
              style: TextStyle(color: _ts, fontSize: 11)),
        ),
        SizedBox(
          width: 140,
          child: Text(debit > 0 ? _fmt(debit) : '—',
              style: TextStyle(
                  color: debit > 0 ? _ok : _td,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 140,
          child: Text(credit > 0 ? _fmt(credit) : '—',
              style: TextStyle(
                  color: credit > 0 ? _indigo : _td,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 140,
          child: Text(_fmt(balance.abs()),
              style: TextStyle(
                  color: balance > 0 ? _ok : balance < 0 ? _err : _td,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        const SizedBox(width: 6),
        Icon(Icons.arrow_back_ios, color: _td, size: 10),
      ]),
    ),  // close Container
    );  // close InkWell
  }

  /// Drill-down: اضغط صف TB → افتح Account Ledger كامل.
  Future<void> _showAccountLedger(Map<String, dynamic> row) async {
    final accountId = row['account_id']?.toString();
    if (accountId == null) return;
    await showDialog(
      context: context,
      builder: (_) => _AccountLedgerDialog(
        accountId: accountId,
        startDate: _startDate,
        endDate: _asOfDate,
        accountCode: row['code']?.toString() ?? '',
        accountName: row['name_ar']?.toString() ?? '',
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 2: Income Statement
  // ════════════════════════════════════════════════════════════════════

  Widget _incomeStatementTab() {
    final is_ = _incomeStatement;
    if (is_ == null) {
      return Center(
          child: Text('لا توجد بيانات',
              style: TextStyle(color: _ts, fontSize: 13)));
    }
    // Backend IS uses: revenue_total, expense_total, net_income (not total_*)
    final revenue = asDouble(is_['revenue_total']);
    final expenses = asDouble(is_['expense_total']);
    final netIncome = is_['net_income'] != null
        ? asDouble(is_['net_income'])
        : (revenue - expenses);
    // تفاصيل الحسابات من TB — backend IS لا يُرجعها
    final revenueAccts =
        _tbRowsForDetails.where((r) => r['category'] == 'revenue').toList();
    final expenseAccts =
        _tbRowsForDetails.where((r) => r['category'] == 'expense').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top summary
        Row(children: [
          Expanded(child: _summaryCard('الإيرادات', revenue, _ok)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('المصروفات', expenses, _err)),
          const SizedBox(width: 10),
          Expanded(
              child: _summaryCard(
                  netIncome >= 0 ? 'صافي الربح' : 'صافي الخسارة',
                  netIncome.abs(),
                  netIncome >= 0 ? _gold : _err)),
        ]),
        const SizedBox(height: 16),
        _sectionHeader('الإيرادات', Icons.trending_up, _ok),
        const SizedBox(height: 6),
        ...revenueAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _ok)),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _ok.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _ok.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Text('إجمالي الإيرادات',
                style: TextStyle(
                    color: _ok,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_fmt(revenue),
                style: TextStyle(
                    color: _ok,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace')),
          ]),
        ),
        const SizedBox(height: 16),
        _sectionHeader('المصروفات', Icons.trending_down, _err),
        const SizedBox(height: 6),
        ...expenseAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _err)),
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _err.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _err.withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Text('إجمالي المصروفات',
                style: TextStyle(
                    color: _err,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_fmt(expenses),
                style: TextStyle(
                    color: _err,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace')),
          ]),
        ),
        const SizedBox(height: 16),
        // Net income bold box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
          ),
          child: Row(children: [
            Icon(netIncome >= 0 ? Icons.celebration : Icons.warning,
                color: netIncome >= 0 ? _gold : _err, size: 28),
            const SizedBox(width: 12),
            Text(netIncome >= 0 ? 'صافي الربح' : 'صافي الخسارة',
                style: TextStyle(
                    color: _tp,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_fmt(netIncome.abs()),
                style: TextStyle(
                    color: netIncome >= 0 ? _gold : _err,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace')),
          ]),
        ),
      ],
    );
  }

  Widget _isRow(Map<String, dynamic> a, Color color) {
    final bal = asDouble(a['balance']);
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        SizedBox(
          width: 90,
          child: Text(a['code'] ?? '',
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        Expanded(
          child: Text(a['name_ar'] ?? '',
              style: TextStyle(color: _tp, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        Text(_fmt(bal.abs()),
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace')),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 3: Balance Sheet
  // ════════════════════════════════════════════════════════════════════

  Widget _balanceSheetTab() {
    final bs = _balanceSheet;
    if (bs == null) {
      return Center(
          child: Text('لا توجد بيانات',
              style: TextStyle(color: _ts, fontSize: 13)));
    }
    // Backend BS: assets, liabilities, equity (base), current_earnings, total_equity
    final assets = asDouble(bs['assets']);
    final liabs = asDouble(bs['liabilities']);
    final equityBase = asDouble(bs['equity']);
    final currentEarnings = asDouble(bs['current_earnings']);
    // total_equity = equity base + YTD net income (حتى يقفل المحاسب السنة يدوياً)
    final equity = asDouble(bs['total_equity']);
    // backend يعطي balanced + difference جاهزة — استخدمها بدل الحساب المزدوج
    final balanced = bs['balanced'] == true ||
        ((assets - (liabs + equity)).abs() < 0.01);
    // تفاصيل الحسابات من TB — backend BS لا يُرجعها
    final assetAccts =
        _tbRowsForDetails.where((r) => r['category'] == 'asset').toList();
    final liabAccts =
        _tbRowsForDetails.where((r) => r['category'] == 'liability').toList();
    final equityAccts =
        _tbRowsForDetails.where((r) => r['category'] == 'equity').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Equation banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (balanced ? _ok : _err).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: (balanced ? _ok : _err).withValues(alpha: 0.4)),
          ),
          child: Row(children: [
            Icon(balanced ? Icons.check_circle : Icons.warning,
                color: balanced ? _ok : _err, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  balanced
                      ? 'المعادلة المحاسبية متوازنة ✓ (أصول = خصوم + حقوق ملكية)'
                      : 'غير متوازنة! الفرق: ${_fmt((assets - (liabs + equity)).abs())}',
                  style: TextStyle(
                      color: balanced ? _ok : _err,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _summaryCard('الأصول', assets, _ok)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('الخصوم', liabs, _warn)),
          const SizedBox(width: 10),
          Expanded(child: _summaryCard('حقوق الملكية', equity, _indigo)),
        ]),
        // لو في صافي دخل من السنة الحالية، وضّح للمستخدم
        if (currentEarnings.abs() > 0.01) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _indigo.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _indigo.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.info_outline, color: _indigo, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'حقوق الملكية تشمل: رأس مال ${_fmt(equityBase)} + صافي الدخل اليتيم ${_fmt(currentEarnings)} (قبل إقفال السنة)',
                    style: TextStyle(color: _indigo, fontSize: 11)),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        _sectionHeader('الأصول', Icons.account_balance_wallet, _ok),
        ...assetAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _ok)),
        _totalLine('إجمالي الأصول', assets, _ok),
        const SizedBox(height: 16),
        _sectionHeader('الخصوم', Icons.credit_card, _warn),
        ...liabAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _warn)),
        _totalLine('إجمالي الخصوم', liabs, _warn),
        const SizedBox(height: 16),
        _sectionHeader('حقوق الملكية', Icons.person, _indigo),
        ...equityAccts.map((a) => _isRow(Map<String, dynamic>.from(a), _indigo)),
        _totalLine('إجمالي حقوق الملكية', equity, _indigo),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 2),
          ),
          child: Row(children: [
            Icon(Icons.account_balance, color: _gold, size: 24),
            const SizedBox(width: 10),
            Text('إجمالي الخصوم + حقوق الملكية',
                style: TextStyle(
                    color: _tp,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(_fmt(liabs + equity),
                style: TextStyle(
                    color: _gold,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace')),
          ]),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Tab 4: Cash Flow (Indirect Method)
  // ════════════════════════════════════════════════════════════════════

  Widget _cashFlowTab() {
    final cf = _cashFlow;
    if (cf == null) {
      return Center(
          child: Text('لا توجد بيانات',
              style: TextStyle(color: _ts, fontSize: 13)));
    }
    final netIncome = asDouble(cf['net_income']);
    final wcChange = asDouble(cf['working_capital_change']);
    final operatingCF = asDouble(cf['operating_cf']);
    final cashBegin = asDouble(cf['cash_beginning']);
    final cashEnd = asDouble(cf['cash_ending']);
    final variance = asDouble(cf['variance']);
    final arChange = asDouble(cf['ar_change']);
    final apChange = asDouble(cf['ap_change']);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary KPIs
        Row(children: [
          Expanded(
              child: _summaryCard('نقدية بداية', cashBegin,
                  core_theme.AC.purple)),
          const SizedBox(width: 10),
          Expanded(
              child: _summaryCard(
                  'تدفق تشغيلي صافي',
                  operatingCF,
                  operatingCF >= 0 ? _ok : _err)),
          const SizedBox(width: 10),
          Expanded(
              child: _summaryCard('نقدية نهاية', cashEnd, _gold)),
        ]),
        const SizedBox(height: 16),
        _sectionHeader('التدفقات من الأنشطة التشغيلية', Icons.sync, _ok),
        _cfLine('صافي الدخل', netIncome, _indigo),
        _cfLine(' ± التغيّر في الأصول المتداولة (AR, مخزون)',
            -arChange, arChange > 0 ? _err : _ok),
        _cfLine(' ± التغيّر في الخصوم المتداولة (AP)',
            apChange, apChange > 0 ? _ok : _err),
        const SizedBox(height: 4),
        _totalLine('صافي التدفق التشغيلي', operatingCF,
            operatingCF >= 0 ? _ok : _err),
        const SizedBox(height: 16),
        _sectionHeader('التدفقات من الأنشطة الاستثمارية', Icons.home_work, _warn),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _warn.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _warn.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: _warn, size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'سيُحسب تلقائياً بعد تصنيف الأصول الثابتة في v2 (شراء/بيع معدات وممتلكات)',
                style: TextStyle(color: _ts, fontSize: 11),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        _sectionHeader('التدفقات من الأنشطة التمويلية', Icons.account_balance, _indigo),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _indigo.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _indigo.withValues(alpha: 0.2)),
          ),
          child: Row(children: [
            Icon(Icons.info_outline, color: _indigo, size: 14),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'سيُحسب تلقائياً بعد تصنيف حسابات القروض والتوزيعات في v2',
                style: TextStyle(color: _ts, fontSize: 11),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        // Reconciliation
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _gold.withValues(alpha: 0.4), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تسوية النقدية',
                  style: TextStyle(
                      color: _gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _reconciliationRow('نقدية أول الفترة', cashBegin),
              _reconciliationRow('+ التدفق التشغيلي', operatingCF),
              _reconciliationRow('= النقدية المتوقعة',
                  cashBegin + operatingCF, bold: true),
              Divider(color: _bdr),
              _reconciliationRow('النقدية الفعلية (من الميزان)', cashEnd),
              _reconciliationRow(
                  'الفارق',
                  variance,
                  color: variance.abs() < 0.01 ? _ok : _err,
                  bold: true),
              if (variance.abs() > 0.01) ...[
                const SizedBox(height: 6),
                Text(
                  '⚠ الفارق قد يعود لعدم تصنيف أنشطة الاستثمار/التمويل في v2، أو حركات غير نقدية (إهلاك/تعديلات).',
                  style: TextStyle(color: _warn, fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        // WC details
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _navy2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr)),
          child: Column(children: [
            _reconciliationRow('تغيّر رأس المال العامل', wcChange),
            _reconciliationRow('تغيّر إجمالي الأصول', arChange),
            _reconciliationRow('تغيّر إجمالي الخصوم', apChange),
          ]),
        ),
      ],
    );
  }

  Widget _cfLine(String label, double value, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: _tp, fontSize: 12)),
        ),
        Text(
          '${value >= 0 ? "+" : ""}${_fmt(value.abs())}',
          style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace'),
        ),
      ]),
    );
  }

  Widget _reconciliationRow(String label, double value,
      {bool bold = false, Color? color}) {
    final c = color ?? _tp;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(
                  color: bold ? c : _ts,
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ),
        Text(_fmt(value),
            style: TextStyle(
                color: c,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontFamily: 'monospace')),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // Helpers
  // ════════════════════════════════════════════════════════════════════

  Widget _summaryCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _td, fontSize: 11)),
          const SizedBox(height: 6),
          Text(_fmt(value),
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, color: color, size: 14),
      ),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800)),
    ]);
  }

  Widget _totalLine(String label, double value, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
        const Spacer(),
        Text(_fmt(value),
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, color: _err, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: _ts)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _tp, side: BorderSide(color: _bdr)),
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );

  String _categoryAr(String? c) {
    switch (c) {
      case 'asset':
        return 'أصول';
      case 'liability':
        return 'خصوم';
      case 'equity':
        return 'حقوق ملكية';
      case 'revenue':
        return 'إيرادات';
      case 'expense':
        return 'مصروفات';
    }
    return c ?? '—';
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}

TextStyle get _th => TextStyle(
    color: _td, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);

// ══════════════════════════════════════════════════════════════════════════
// Account Ledger Dialog — drill-down من TB صف → حركات الحساب التفصيلية
// ══════════════════════════════════════════════════════════════════════════

class _AccountLedgerDialog extends StatefulWidget {
  final String accountId;
  final String accountCode;
  final String accountName;
  final DateTime startDate;
  final DateTime endDate;
  const _AccountLedgerDialog({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    required this.startDate,
    required this.endDate,
  });
  @override
  State<_AccountLedgerDialog> createState() => _AccountLedgerDialogState();
}

class _AccountLedgerDialogState extends State<_AccountLedgerDialog> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await pilotClient.accountLedger(
      widget.accountId,
      startDate: widget.startDate.toIso8601String().substring(0, 10),
      endDate: widget.endDate.toIso8601String().substring(0, 10),
      limit: 1000,
    );
    if (!mounted) return;
    if (r.success && r.data is Map) {
      setState(() {
        _data = Map<String, dynamic>.from(r.data);
        _loading = false;
      });
    } else {
      setState(() {
        _error = r.error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: _navy,
        insetPadding: const EdgeInsets.all(40),
        child: Container(
          width: 900,
          height: 700,
          decoration: BoxDecoration(
            border: Border.all(color: _gold.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(
                color: _navy2,
                border: Border(bottom: BorderSide(color: _bdr)),
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _gold.withValues(alpha: 0.4)),
                  ),
                  child: Icon(Icons.receipt_long, color: _gold, size: 18),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(widget.accountCode,
                            style: TextStyle(
                                color: _gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace')),
                      ),
                      const SizedBox(width: 8),
                      Text(widget.accountName,
                          style: TextStyle(
                              color: _tp,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 3),
                    Text(
                        'دفتر الأستاذ التفصيلي · من ${widget.startDate.toIso8601String().substring(0, 10)} إلى ${widget.endDate.toIso8601String().substring(0, 10)}',
                        style: TextStyle(color: _ts, fontSize: 11)),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: _ts),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            // Body
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: _gold))
                  : _error != null
                      ? Center(
                          child: Text(_error!,
                              style: TextStyle(color: _err)))
                      : _buildLedger(),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildLedger() {
    final d = _data!;
    final rows = (d['rows'] as List?) ?? [];
    final opening = asDouble(d['opening_balance']);
    final closing = asDouble(d['closing_balance']);
    final totalDebit = asDouble(d['total_debit']);
    final totalCredit = asDouble(d['total_credit']);
    return Column(children: [
      // Summary
      Container(
        padding: const EdgeInsets.all(14),
        color: _navy2.withValues(alpha: 0.5),
        child: Row(children: [
          Expanded(child: _kpi('رصيد افتتاحي', opening,
              core_theme.AC.purple)),
          const SizedBox(width: 10),
          Expanded(child: _kpi('إجمالي مدين', totalDebit, _ok)),
          const SizedBox(width: 10),
          Expanded(child: _kpi('إجمالي دائن', totalCredit, _indigo)),
          const SizedBox(width: 10),
          Expanded(child: _kpi('رصيد ختامي', closing, _gold)),
        ]),
      ),
      // Table header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        color: _navy3,
        child: Row(children: [
          SizedBox(width: 90, child: Text('التاريخ', style: _th)),
          SizedBox(width: 110, child: Text('رقم القيد', style: _th)),
          Expanded(flex: 3, child: Text('البيان', style: _th)),
          SizedBox(
              width: 120,
              child: Text('مدين', style: _th, textAlign: TextAlign.end)),
          SizedBox(
              width: 120,
              child: Text('دائن', style: _th, textAlign: TextAlign.end)),
          SizedBox(
              width: 130,
              child: Text('الرصيد الجاري',
                  style: _th, textAlign: TextAlign.end)),
        ]),
      ),
      // Rows
      Expanded(
        child: rows.isEmpty
            ? Center(
                child: Text('لا توجد حركات على هذا الحساب في الفترة',
                    style: TextStyle(color: _ts, fontSize: 12)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                itemBuilder: (_, i) =>
                    _ledgerRow(Map<String, dynamic>.from(rows[i])),
              ),
      ),
      // Footer with close button
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _navy2,
          border: Border(top: BorderSide(color: _bdr)),
        ),
        child: Row(children: [
          Text('${rows.length} حركة',
              style: TextStyle(color: _td, fontSize: 11)),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ]),
      ),
    ]);
  }

  Widget _kpi(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: _td, fontSize: 10)),
          const SizedBox(height: 3),
          Text(_fmt(value),
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _ledgerRow(Map<String, dynamic> r) {
    final debit = asDouble(r['debit']);
    final credit = asDouble(r['credit']);
    final running = asDouble(r['running_balance']);
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _navy2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        SizedBox(
            width: 90,
            child: Text(
                (r['posting_date'] ?? '').toString().substring(
                    0, (r['posting_date'] ?? '').toString().length.clamp(0, 10)),
                style: TextStyle(
                    color: _ts, fontSize: 11, fontFamily: 'monospace'))),
        SizedBox(
          width: 110,
          child: Text(r['je_number'] ?? '—',
              style: TextStyle(
                  color: _gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r['je_memo_ar'] ?? '',
                  style: TextStyle(color: _tp, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
              if ((r['description'] ?? '').toString().isNotEmpty &&
                  r['description'] != r['je_memo_ar'])
                Text(r['description'],
                    style: TextStyle(color: _td, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        SizedBox(
          width: 120,
          child: Text(debit > 0 ? _fmt(debit) : '—',
              style: TextStyle(
                  color: debit > 0 ? _ok : _td,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 120,
          child: Text(credit > 0 ? _fmt(credit) : '—',
              style: TextStyle(
                  color: credit > 0 ? _indigo : _td,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 130,
          child: Text(_fmt(running),
              style: TextStyle(
                  color: running >= 0 ? _gold : _err,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
      ]),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}
