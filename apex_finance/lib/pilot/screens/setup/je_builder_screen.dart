/// Journal Entries — بناء وإدارة قيود اليومية.
///
/// مستقلة — تعتمد على PilotSession.entityId.
///
/// الميزات:
///   • قائمة القيود (Draft/Submitted/Approved/Posted/Reversed)
///   • إنشاء قيد جديد (multi-line debit/credit — يجب أن يتساوى المجموع)
///   • ترحيل القيد (post) — يُسجَّل في GL Postings
///   • عكس القيد (reverse) — يُنشِئ قيداً مقابلاً
///   • عرض تفاصيل القيد مع السطور
library;

import 'package:flutter/material.dart';

import '../../api/pilot_client.dart';
import '../../session.dart';

const _gold = Color(0xFFD4AF37);
const _navy = Color(0xFF0A1628);
const _navy2 = Color(0xFF132339);
const _navy3 = Color(0xFF1D3150);
const _bdr = Color(0x33FFFFFF);
const _tp = Color(0xFFFFFFFF);
const _ts = Color(0xFFBCC5D3);
const _td = Color(0xFF6B7A90);
const _ok = Color(0xFF10B981);
const _err = Color(0xFFEF4444);
const _warn = Color(0xFFF59E0B);
const _blue = Color(0xFF3B82F6);
const _indigo = Color(0xFF6366F1);

const _kStatuses = <String, Map<String, dynamic>>{
  'draft': {'ar': 'مسودّة', 'color': _td},
  'submitted': {'ar': 'مُقدَّم', 'color': _warn},
  'approved': {'ar': 'معتمد', 'color': _blue},
  'posted': {'ar': 'مُرحَّل', 'color': _ok},
  'reversed': {'ar': 'معكوس', 'color': _err},
  'cancelled': {'ar': 'ملغى', 'color': _td},
};

const _kKinds = <String, String>{
  'manual': 'يدوي',
  'auto_pos': 'تلقائي (POS)',
  'auto_po': 'تلقائي (مشتريات)',
  'auto_payroll': 'تلقائي (رواتب)',
  'auto_depreciation': 'تلقائي (إهلاك)',
  'auto_fx_reval': 'تلقائي (تقييم عملات)',
  'adjusting': 'تسوية',
  'closing': 'إقفال',
  'reversal': 'عكس',
  'opening': 'افتتاحي',
};

class JeBuilderScreen extends StatefulWidget {
  const JeBuilderScreen({super.key});
  @override
  State<JeBuilderScreen> createState() => _JeBuilderScreenState();
}

class _JeBuilderScreenState extends State<JeBuilderScreen> {
  final PilotClient _client = pilotClient;

  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _accounts = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';
  String _kindFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // ignore: avoid_print
    print('[JeBuilder] _load start — hasTenant=${PilotSession.hasTenant}, hasEntity=${PilotSession.hasEntity}, entityId=${PilotSession.entityId}');
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!PilotSession.hasEntity) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'يجب اختيار الكيان من شريط العنوان أولاً.';
      });
      return;
    }
    final eid = PilotSession.entityId!;
    try {
      final results = await Future.wait([
        _client.listJournalEntries(eid,
            status: _statusFilter == 'all' ? null : _statusFilter,
            kind: _kindFilter == 'all' ? null : _kindFilter,
            limit: 200),
        _client.listAccounts(eid),
      ]);
      // ignore: avoid_print
      print('[JeBuilder] API results: entries.success=${results[0].success}, accounts.success=${results[1].success}');
      if (!mounted) return;
      // Defensive: handle null/non-list data gracefully
      try {
        _entries = results[0].success && results[0].data is List
            ? List<Map<String, dynamic>>.from(results[0].data as List)
            : [];
      } catch (e) {
        // ignore: avoid_print
        print('[JeBuilder] entries parse error: $e');
        _entries = [];
      }
      try {
        _accounts = results[1].success && results[1].data is List
            ? List<Map<String, dynamic>>.from(results[1].data as List)
            : [];
      } catch (e) {
        // ignore: avoid_print
        print('[JeBuilder] accounts parse error: $e');
        _accounts = [];
      }
      setState(() => _loading = false);
    } catch (e, st) {
      // ignore: avoid_print
      print('[JeBuilder] _load caught exception: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _create() async {
    if (_accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _warn,
          content: Text('ابذر شجرة الحسابات أولاً')));
      return;
    }
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => _JeDialog(accounts: _accounts),
    );
    if (r == true) _load();
  }

  Future<void> _post(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: const Text('ترحيل القيد', style: TextStyle(color: _tp)),
          content: const Text(
              'سيتم ترحيل القيد إلى GL Postings. هذا الإجراء لا يمكن التراجع عنه — يمكن فقط عكس القيد.',
              style: TextStyle(color: _ts, height: 1.5)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء', style: TextStyle(color: _ts))),
            FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: Colors.black),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ترحيل')),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    final r = await _client.postJournalEntry(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: r.success ? _ok : _err,
        content: Text(r.success ? 'تم الترحيل ✓' : r.error ?? 'فشل الترحيل')));
    if (r.success) _load();
  }

  Future<void> _reverse(Map<String, dynamic> je) async {
    final memoCtrl = TextEditingController(text: 'عكس قيد ${je['je_number']}');
    DateTime date = DateTime.now();
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _navy2,
            title: const Text('عكس القيد', style: TextStyle(color: _tp)),
            content: SizedBox(
              width: 400,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate:
                          DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setSt(() => date = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _navy3,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _bdr)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today,
                          color: _td, size: 14),
                      const SizedBox(width: 6),
                      Text(
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(
                              color: _tp,
                              fontSize: 12,
                              fontFamily: 'monospace')),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: memoCtrl,
                  style: const TextStyle(color: _tp),
                  decoration: InputDecoration(
                    labelText: 'سبب العكس',
                    labelStyle: const TextStyle(color: _td),
                    filled: true,
                    fillColor: _navy3,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _bdr)),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء', style: TextStyle(color: _ts))),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _err, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('عكس'),
              ),
            ],
          ),
        ),
      ),
    );
    if (r != true) return;
    final resp = await _client.reverseJournalEntry(je['id'], {
      'reversal_date': date.toIso8601String().substring(0, 10),
      'memo_ar': memoCtrl.text.trim(),
    });
    memoCtrl.dispose();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: resp.success ? _ok : _err,
        content:
            Text(resp.success ? 'تم إنشاء القيد العكسي ✓' : resp.error ?? 'فشل')));
    if (resp.success) _load();
  }

  Future<void> _showDetail(String id) async {
    final r = await _client.getJournalEntry(id);
    if (!r.success || !mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _JeDetailDialog(
          data: Map<String, dynamic>.from(r.data), accounts: _accounts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: Column(children: [
          _header(),
          _toolbar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _gold))
                : _error != null
                    ? _errorView()
                    : _entries.isEmpty
                        ? _emptyView()
                        : _list(),
          ),
        ]),
      ),
    );
  }

  Widget _header() {
    final totalDebit =
        _entries.fold(0.0, (t, e) => t + ((e['total_debit'] ?? 0) as num).toDouble());
    final totalCredit = _entries.fold(
        0.0, (t, e) => t + ((e['total_credit'] ?? 0) as num).toDouble());
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
        color: _navy2,
        border: Border(bottom: BorderSide(color: _bdr)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.book, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('قيود اليومية',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(
                '${_entries.length} قيد · مدين ${_fmt(totalDebit)} · دائن ${_fmt(totalCredit)}',
                style: const TextStyle(color: _ts, fontSize: 12)),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _tp, side: const BorderSide(color: _bdr)),
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('تحديث'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: _gold, foregroundColor: Colors.black),
          onPressed: _create,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('قيد جديد'),
        ),
      ]),
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: _navy2.withValues(alpha: 0.5),
      child: Row(children: [
        const Text('الحالة:', style: TextStyle(color: _td, fontSize: 12)),
        const SizedBox(width: 6),
        _chip('all', 'الكل', _statusFilter == 'all', () {
          setState(() => _statusFilter = 'all');
          _load();
        }),
        const SizedBox(width: 6),
        ..._kStatuses.entries.map((e) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _chip(e.key, e.value['ar'] as String,
                  _statusFilter == e.key, () {
                setState(() => _statusFilter = e.key);
                _load();
              }),
            )),
        const SizedBox(width: 16),
        const Text('النوع:', style: TextStyle(color: _td, fontSize: 12)),
        const SizedBox(width: 6),
        _chip('all-k', 'الكل', _kindFilter == 'all', () {
          setState(() => _kindFilter = 'all');
          _load();
        }),
        const SizedBox(width: 6),
        _chip('manual-k', 'يدوي', _kindFilter == 'manual', () {
          setState(() => _kindFilter = 'manual');
          _load();
        }),
      ]),
    );
  }

  Widget _chip(String k, String label, bool sel, VoidCallback tap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _gold : _navy3,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: sel ? _gold : _bdr, width: sel ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.black : _ts,
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _list() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr),
          ),
          child: Row(children: const [
            SizedBox(width: 130, child: Text('رقم القيد', style: _th)),
            SizedBox(width: 95, child: Text('التاريخ', style: _th)),
            SizedBox(width: 110, child: Text('النوع', style: _th)),
            SizedBox(width: 110, child: Text('الحالة', style: _th)),
            Expanded(child: Text('البيان', style: _th)),
            SizedBox(
                width: 120,
                child: Text('مدين', style: _th, textAlign: TextAlign.end)),
            SizedBox(
                width: 120,
                child: Text('دائن', style: _th, textAlign: TextAlign.end)),
            SizedBox(width: 120, child: Text('إجراءات', style: _th)),
          ]),
        ),
        const SizedBox(height: 6),
        ..._entries.map(_row),
      ],
    );
  }

  Widget _row(Map<String, dynamic> e) {
    final status = e['status'] ?? 'draft';
    final info = _kStatuses[status] ?? {'ar': status, 'color': _td};
    final debit = (e['total_debit'] ?? 0).toDouble();
    final credit = (e['total_credit'] ?? 0).toDouble();
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
          width: 130,
          child: Text(e['je_number'] ?? '',
              style: const TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        SizedBox(
          width: 95,
          child: Text(e['je_date'] ?? '',
              style: const TextStyle(
                  color: _ts, fontSize: 11, fontFamily: 'monospace')),
        ),
        SizedBox(
          width: 110,
          child: Text(_kKinds[e['kind']] ?? e['kind'] ?? '—',
              style: const TextStyle(color: _ts, fontSize: 11)),
        ),
        SizedBox(
            width: 110,
            child: _tag(info['ar'] as String, info['color'] as Color)),
        Expanded(
          child: Text(e['memo_ar'] ?? '',
              style: const TextStyle(color: _tp, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        SizedBox(
          width: 120,
          child: Text(_fmt(debit),
              style: const TextStyle(
                  color: _ok,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 120,
          child: Text(_fmt(credit),
              style: const TextStyle(
                  color: _indigo,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              textAlign: TextAlign.end),
        ),
        SizedBox(
          width: 120,
          child: Row(children: [
            if (status == 'draft' || status == 'submitted' || status == 'approved')
              IconButton(
                tooltip: 'ترحيل',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.check_circle, color: _ok, size: 16),
                onPressed: () => _post(e['id']),
              ),
            if (status == 'posted')
              IconButton(
                tooltip: 'عكس',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.undo, color: _err, size: 16),
                onPressed: () => _reverse(e),
              ),
            IconButton(
              tooltip: 'عرض',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.visibility, color: _ts, size: 16),
              onPressed: () => _showDetail(e['id']),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center),
      );

  Widget _errorView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _err, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _ts)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _tp, side: const BorderSide(color: _bdr)),
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );

  Widget _emptyView() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.book_outlined,
              color: _gold.withValues(alpha: 0.4), size: 72),
          const SizedBox(height: 14),
          const Text('لا توجد قيود بعد',
              style: TextStyle(color: _tp, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('ابدأ بإنشاء قيد يومية يدوي',
              style: TextStyle(color: _ts, fontSize: 12)),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _create,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('قيد جديد'),
          ),
        ]),
      );

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}

const _th = TextStyle(
    color: _td, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);

// ══════════════════════════════════════════════════════════════════════════
// JE Create Dialog
// ══════════════════════════════════════════════════════════════════════════

class _JeLine {
  String? accountId;
  double debit = 0;
  double credit = 0;
  String description = '';
  _JeLine();
}

class _JeDialog extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  const _JeDialog({required this.accounts});
  @override
  State<_JeDialog> createState() => _JeDialogState();
}

class _JeDialogState extends State<_JeDialog> {
  DateTime _date = DateTime.now();
  final _memo = TextEditingController();
  String _kind = 'manual';
  bool _autoPost = true;  // ترحيل مباشر كافتراضي — حتى يظهر في التقارير المالية فوراً
  final List<_JeLine> _lines = [_JeLine(), _JeLine()];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _memo.dispose();
    super.dispose();
  }

  double get _totalDebit => _lines.fold(0.0, (t, l) => t + l.debit);
  double get _totalCredit => _lines.fold(0.0, (t, l) => t + l.credit);
  double get _difference => _totalDebit - _totalCredit;

  Future<void> _pickAccount(int i) async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: const Text('اختر حساباً', style: TextStyle(color: _tp)),
          content: SizedBox(
            width: 500,
            height: 500,
            child: ListView(
              children: widget.accounts
                  .where((a) => a['type'] == 'detail')
                  .map((a) => ListTile(
                        dense: true,
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(a['code'] ?? '',
                              style: const TextStyle(
                                  color: _gold,
                                  fontSize: 10,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700)),
                        ),
                        title: Text(a['name_ar'] ?? '',
                            style: const TextStyle(
                                color: _tp, fontSize: 12)),
                        subtitle: Text(
                            '${a['category']} · ${a['normal_balance']}',
                            style: const TextStyle(
                                color: _td, fontSize: 10)),
                        onTap: () => Navigator.pop(context, a),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
    if (selected == null) return;
    setState(() => _lines[i].accountId = selected['id']);
  }

  Future<void> _submit() async {
    if (_memo.text.trim().isEmpty) {
      setState(() => _error = 'أدخل بياناً للقيد');
      return;
    }
    final validLines = _lines
        .where((l) => l.accountId != null && (l.debit > 0 || l.credit > 0))
        .toList();
    if (validLines.length < 2) {
      setState(() => _error = 'يلزم سطران على الأقل');
      return;
    }
    if ((_difference).abs() > 0.01) {
      setState(() =>
          _error = 'المدين لا يساوي الدائن (الفرق: ${_difference.toStringAsFixed(2)})');
      return;
    }
    for (final l in validLines) {
      if (l.debit > 0 && l.credit > 0) {
        setState(() =>
            _error = 'كل سطر يجب أن يكون إما مدين أو دائن (ليس كلاهما)');
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'entity_id': PilotSession.entityId,
      'kind': _kind,
      'je_date': _date.toIso8601String().substring(0, 10),
      'memo_ar': _memo.text.trim(),
      'auto_post': _autoPost,
      'lines': validLines
          .map((l) => {
                'account_id': l.accountId,
                'debit': l.debit.toString(),
                'credit': l.credit.toString(),
                if (l.description.trim().isNotEmpty)
                  'description': l.description.trim(),
              })
          .toList(),
    };
    final r = await pilotClient.createJournalEntry(body);
    setState(() => _loading = false);
    if (!mounted) return;
    if (r.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _ok,
          content: Text(_autoPost
              ? 'تم إنشاء القيد وترحيله ✓'
              : 'تم إنشاء القيد (مسودّة) ✓')));
    } else {
      setState(() => _error = r.error ?? 'فشل الإنشاء');
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanced = _difference.abs() < 0.01 && _totalDebit > 0;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: const Row(children: [
          Icon(Icons.book, color: _gold),
          SizedBox(width: 8),
          Text('قيد يومية جديد', style: TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 820,
          height: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('البيان *',
                            style: TextStyle(color: _td, fontSize: 11)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _memo,
                          style: const TextStyle(color: _tp, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'مثال: رسوم بنكية شهرية',
                            hintStyle: const TextStyle(color: _td),
                            isDense: true,
                            filled: true,
                            fillColor: _navy3,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: const BorderSide(color: _bdr)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('التاريخ',
                            style: TextStyle(color: _td, fontSize: 11)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final d = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDate: DateTime.now(),
                            );
                            if (d != null) setState(() => _date = d);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                                color: _navy3,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _bdr)),
                            child: Row(children: [
                              const Icon(Icons.calendar_today,
                                  color: _td, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                    color: _tp,
                                    fontSize: 12,
                                    fontFamily: 'monospace'),
                              ),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('النوع',
                            style: TextStyle(color: _td, fontSize: 11)),
                        const SizedBox(height: 4),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                              color: _navy3,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _bdr)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _kind,
                              isExpanded: true,
                              dropdownColor: _navy2,
                              style: const TextStyle(
                                  color: _tp, fontSize: 12),
                              icon: const Icon(Icons.arrow_drop_down,
                                  color: _ts),
                              items: const [
                                DropdownMenuItem(
                                    value: 'manual', child: Text('يدوي')),
                                DropdownMenuItem(
                                    value: 'adjusting', child: Text('تسوية')),
                                DropdownMenuItem(
                                    value: 'opening', child: Text('افتتاحي')),
                                DropdownMenuItem(
                                    value: 'closing', child: Text('إقفال')),
                              ],
                              onChanged: (v) => setState(() => _kind = v!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  const Icon(Icons.list, color: _gold, size: 16),
                  const SizedBox(width: 6),
                  const Text('السطور',
                      style: TextStyle(
                          color: _tp,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: _gold),
                    onPressed: () => setState(() => _lines.add(_JeLine())),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('سطر جديد'),
                  ),
                ]),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(children: const [
                    SizedBox(width: 30, child: Text('#', style: _th)),
                    Expanded(flex: 3, child: Text('الحساب', style: _th)),
                    Expanded(flex: 3, child: Text('البيان', style: _th)),
                    SizedBox(
                        width: 110,
                        child: Text('مدين', style: _th, textAlign: TextAlign.end)),
                    SizedBox(
                        width: 110,
                        child: Text('دائن', style: _th, textAlign: TextAlign.end)),
                    SizedBox(width: 30, child: Text('', style: _th)),
                  ]),
                ),
                ..._lines.asMap().entries.map((e) => _lineRow(e.key, e.value)),
                const SizedBox(height: 14),
                // Totals + balance check
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (balanced ? _ok : _err).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color:
                            (balanced ? _ok : _err).withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(balanced ? Icons.check_circle : Icons.warning,
                        color: balanced ? _ok : _err, size: 20),
                    const SizedBox(width: 8),
                    Text(
                        balanced
                            ? 'القيد متوازن'
                            : 'القيد غير متوازن — الفرق: ${_difference.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: balanced ? _ok : _err,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('مدين: ${_fmt(_totalDebit)}',
                            style: const TextStyle(
                                color: _ok,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace')),
                        Text('دائن: ${_fmt(_totalCredit)}',
                            style: const TextStyle(
                                color: _indigo,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'monospace')),
                      ],
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _autoPost
                        ? _ok.withValues(alpha: 0.08)
                        : _warn.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: (_autoPost ? _ok : _warn).withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Checkbox(
                      value: _autoPost,
                      onChanged: (v) => setState(() => _autoPost = v ?? false),
                      checkColor: Colors.black,
                      fillColor: WidgetStateProperty.resolveWith<Color?>((s) =>
                          s.contains(WidgetState.selected) ? _gold : _navy3),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              _autoPost
                                  ? '✓ ترحيل مباشر إلى GL'
                                  : '⚠ حفظ كمسودّة فقط',
                              style: TextStyle(
                                  color: _autoPost ? _ok : _warn,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                              _autoPost
                                  ? 'القيد سيظهر فوراً في ميزان المراجعة والتقارير المالية.'
                                  : 'القيد لن يظهر في التقارير المالية (Trial Balance / P&L / Balance Sheet) حتى تضغط زر الترحيل يدوياً.',
                              style: const TextStyle(
                                  color: _ts, fontSize: 11, height: 1.4)),
                        ],
                      ),
                    ),
                  ]),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: _err.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: _err, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  color: _err, fontSize: 12))),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء', style: TextStyle(color: _ts))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_autoPost ? 'إنشاء + ترحيل' : 'إنشاء'),
          ),
        ],
      ),
    );
  }

  Widget _lineRow(int i, _JeLine l) {
    final acc = widget.accounts.firstWhere((a) => a['id'] == l.accountId,
        orElse: () => {});
    return Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: _navy3.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _bdr)),
      child: Row(children: [
        SizedBox(
            width: 30,
            child: Text('${i + 1}',
                style: const TextStyle(color: _ts, fontSize: 11))),
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () => _pickAccount(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                  color: _navy2,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _bdr)),
              child: Row(children: [
                const Icon(Icons.search, color: _gold, size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                      acc.isEmpty
                          ? 'اختر حساباً'
                          : '${acc['code']} — ${acc['name_ar']}',
                      style: TextStyle(
                          color: acc.isEmpty ? _td : _tp,
                          fontSize: 11,
                          fontFamily: acc.isEmpty ? null : 'monospace'),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: TextField(
            onChanged: (v) => l.description = v,
            style: const TextStyle(color: _tp, fontSize: 11),
            decoration: const InputDecoration(
              hintText: 'اختياري',
              hintStyle: TextStyle(color: _td),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: InputBorder.none,
            ),
          ),
        ),
        SizedBox(
          width: 110,
          child: TextField(
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() {
              l.debit = double.tryParse(v) ?? 0;
              if (l.debit > 0) l.credit = 0;
            }),
            style: const TextStyle(
                color: _ok,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: l.debit > 0 ? _ok.withValues(alpha: 0.08) : _navy2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: _bdr)),
            ),
            textAlign: TextAlign.end,
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 110,
          child: TextField(
            keyboardType: TextInputType.number,
            onChanged: (v) => setState(() {
              l.credit = double.tryParse(v) ?? 0;
              if (l.credit > 0) l.debit = 0;
            }),
            style: const TextStyle(
                color: _indigo,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor:
                  l.credit > 0 ? _indigo.withValues(alpha: 0.08) : _navy2,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: const BorderSide(color: _bdr)),
            ),
            textAlign: TextAlign.end,
          ),
        ),
        SizedBox(
          width: 30,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.delete, color: _err, size: 14),
            onPressed: _lines.length > 2
                ? () => setState(() => _lines.removeAt(i))
                : null,
          ),
        ),
      ]),
    );
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}

// ══════════════════════════════════════════════════════════════════════════
// JE Detail Dialog
// ══════════════════════════════════════════════════════════════════════════

class _JeDetailDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> accounts;
  const _JeDetailDialog({required this.data, required this.accounts});

  String _accountLabel(String? id) {
    if (id == null) return '—';
    final a = accounts.firstWhere((x) => x['id'] == id, orElse: () => {});
    if (a.isEmpty) return id;
    return '${a['code']} — ${a['name_ar']}';
  }

  @override
  Widget build(BuildContext context) {
    final lines = (data['lines'] as List?) ?? [];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          const Icon(Icons.book, color: _gold),
          const SizedBox(width: 8),
          Text('قيد يومية #${data['je_number'] ?? ""}',
              style: const TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: _kv('التاريخ', data['je_date'] ?? '—')),
                  Expanded(
                      child: _kv('النوع',
                          _kKinds[data['kind']] ?? data['kind'] ?? '—')),
                  Expanded(child: _kv('الحالة', data['status'] ?? '—')),
                  Expanded(
                      child: _kv(
                          'تاريخ الترحيل', data['posting_date'] ?? '—')),
                ]),
                _kv('البيان', data['memo_ar'] ?? '—'),
                const SizedBox(height: 14),
                const Text('السطور:',
                    style: TextStyle(
                        color: _tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: BorderRadius.circular(4)),
                  child: Row(children: const [
                    SizedBox(width: 30, child: Text('#', style: _th)),
                    Expanded(flex: 3, child: Text('الحساب', style: _th)),
                    Expanded(flex: 2, child: Text('البيان', style: _th)),
                    SizedBox(
                        width: 110,
                        child: Text('مدين',
                            style: _th, textAlign: TextAlign.end)),
                    SizedBox(
                        width: 110,
                        child: Text('دائن',
                            style: _th, textAlign: TextAlign.end)),
                  ]),
                ),
                ...lines.map((l) {
                  final dr = (l['debit_amount'] ?? 0).toDouble();
                  final cr = (l['credit_amount'] ?? 0).toDouble();
                  return Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                        color: _navy3.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4)),
                    child: Row(children: [
                      SizedBox(
                          width: 30,
                          child: Text('${l['line_number']}',
                              style: const TextStyle(
                                  color: _ts, fontSize: 11))),
                      Expanded(
                        flex: 3,
                        child: Text(_accountLabel(l['account_id']),
                            style: const TextStyle(
                                color: _tp,
                                fontSize: 11,
                                fontFamily: 'monospace'),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(l['description'] ?? '—',
                            style: const TextStyle(
                                color: _ts, fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                            dr > 0 ? dr.toStringAsFixed(2) : '—',
                            style: TextStyle(
                                color: dr > 0 ? _ok : _td,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.end),
                      ),
                      SizedBox(
                        width: 110,
                        child: Text(
                            cr > 0 ? cr.toStringAsFixed(2) : '—',
                            style: TextStyle(
                                color: cr > 0 ? _indigo : _td,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.end),
                      ),
                    ]),
                  );
                }),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _gold.withValues(alpha: 0.3))),
                  child: Row(children: [
                    Expanded(
                        child: _kv('إجمالي المدين',
                            (data['total_debit'] ?? 0).toString(), mono: true)),
                    Expanded(
                        child: _kv('إجمالي الدائن',
                            (data['total_credit'] ?? 0).toString(), mono: true)),
                  ]),
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: _td, fontSize: 10)),
          const SizedBox(height: 2),
          Text(v,
              style: TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: mono ? 'monospace' : null),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
