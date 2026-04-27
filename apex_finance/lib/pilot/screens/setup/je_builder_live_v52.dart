/// APEX V5.2 + Pilot — Journal Entry Builder (Live, AI-enabled).
///
/// Merges the beautiful V5.2 ObjectPage UI (stepper + chatter + tabs +
/// smart buttons) with real pilot backend connectivity and AI integrations:
///   • Real accounts from /pilot/entities/{eid}/accounts
///   • Real save → /pilot/journal-entries (draft or auto-post)
///   • Real post/reverse/approve workflows via pilot APIs
///   • AI read-document → /pilot/entities/{eid}/ai/read-document
///   • AI suggest-memo → /pilot/ai/suggest-memo
///
/// Route: /app/erp/finance/je-builder/new (create)
/// Route: /app/erp/finance/je-builder/{id}  (view/edit)
library;

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart' as core_theme;
import '../../../core/v5/templates/object_page_template.dart';
import '../../api/pilot_client.dart';
import '../../session.dart';

// ─────────────────────────────────────────────────────────────────────
// Single line in the entry (editable state + controllers).
// ─────────────────────────────────────────────────────────────────────
class _LineState {
  String? accountId;
  double debit = 0;
  double credit = 0;
  String description = '';
  String aiHint = '';
  double aiMatchConfidence = 0;
  // Odoo-style optional columns (Phase 1) — backend already supports them.
  String partnerLabel = '';   // posted as `partner_id` (free-text label)
  String costCenterLabel = ''; // posted as `cost_center_id` (free-text label)
  String vatCode = '';         // standard / zero_rated / exempt
  final TextEditingController debitCtrl = TextEditingController();
  final TextEditingController creditCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  final TextEditingController partnerCtrl = TextEditingController();
  final TextEditingController costCenterCtrl = TextEditingController();

  void dispose() {
    debitCtrl.dispose();
    creditCtrl.dispose();
    descCtrl.dispose();
    partnerCtrl.dispose();
    costCenterCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Main screen.
// ─────────────────────────────────────────────────────────────────────
class JeBuilderLiveV52Screen extends StatefulWidget {
  /// Existing JE id — null for create mode.
  final String? jeId;
  const JeBuilderLiveV52Screen({super.key, this.jeId});

  @override
  State<JeBuilderLiveV52Screen> createState() => _JeBuilderLiveV52ScreenState();
}

class _JeBuilderLiveV52ScreenState extends State<JeBuilderLiveV52Screen> {
  // ─── Live data from backend ───
  final PilotClient _client = pilotClient;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _accounts = [];
  Map<String, dynamic>? _je;           // null = create mode
  List<Map<String, dynamic>> _jeLines = []; // loaded lines (view mode)

  // ─── Create-mode form state ───
  final _memo = TextEditingController();
  final _reference = TextEditingController();
  final _internalNote = TextEditingController();
  DateTime _date = DateTime.now();
  String _kind = 'manual';
  bool _autoPost = true;
  bool _toCheck = false;
  final List<_LineState> _lines = [_LineState(), _LineState()];
  bool _submitting = false;

  // ─── Optional column visibility (Odoo-style ⚙️ toggle) ───
  // All default OFF — keep first impression simple. User toggles via
  // the column-settings popup in the lines table header.
  bool _showPartner = false;
  bool _showCostCenter = false;
  bool _showVat = false;

  // ─── AI state ───
  bool _aiDocLoading = false;
  bool _aiMemoLoading = false;
  String? _aiDocFilename;
  double? _aiDocConfidence;
  List<String> _aiWarnings = const [];

  // ─── Local tab state (shell's tab bar is hidden; we render our own
  // strip at the top of the content area where the البيانات الأساسية
  // title used to sit) ───
  String _activeView = 'lines';

  // ─── Theme shortcuts ───
  Color get _gold => core_theme.AC.gold;
  Color get _navy => const Color(0xFF1A237E);
  Color get _ok => core_theme.AC.ok;
  Color get _warn => core_theme.AC.warn;
  Color get _err => core_theme.AC.err;
  Color get _purple => core_theme.AC.purple;
  Color get _bdr => core_theme.AC.bdr;
  Color get _ts => core_theme.AC.ts;
  Color get _td => core_theme.AC.td;
  Color get _tp => core_theme.AC.tp;
  Color get _navy3 => core_theme.AC.navy3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _memo.dispose();
    _reference.dispose();
    _internalNote.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────
  // LOAD — accounts (+ JE if id provided)
  // ─────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    if (!PilotSession.hasEntity) {
      setState(() {
        _loading = false;
        _error = 'اختر الكيان من شريط العنوان أولاً';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final eid = PilotSession.entityId!;
    try {
      final futures = <Future>[
        _client.listAccounts(eid),
      ];
      if (widget.jeId != null) {
        futures.add(_client.getJournalEntry(widget.jeId!));
      }
      final results = await Future.wait(futures);
      final accRes = results[0];
      if (accRes.success && accRes.data is List) {
        _accounts = List<Map<String, dynamic>>.from(accRes.data as List);
      }
      if (widget.jeId != null && results.length > 1) {
        final jeRes = results[1];
        if (jeRes.success && jeRes.data is Map) {
          _je = Map<String, dynamic>.from(jeRes.data as Map);
          _jeLines = List<Map<String, dynamic>>.from(
            (_je!['lines'] as List?) ?? const [],
          );
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // AI — قراءة مستند (يملأ النموذج تلقائياً)
  // ─────────────────────────────────────────────────────────────────
  Future<void> _aiReadDocument() async {
    if (!PilotSession.hasEntity) return;
    final input = html.FileUploadInputElement()
      ..accept = '.pdf,.png,.jpg,.jpeg,.webp';
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return;
    final file = input.files!.first;

    setState(() {
      _aiDocLoading = true;
      _aiDocFilename = file.name;
      _error = null;
      _aiWarnings = const [];
    });
    final r = await _client.aiReadDocument(PilotSession.entityId!, file);
    if (!mounted) return;
    setState(() => _aiDocLoading = false);

    if (!r.success) {
      setState(() {
        _error = r.error ?? 'فشل استخراج القيد';
        _aiDocFilename = null;
      });
      return;
    }
    final data = r.data as Map? ?? {};
    final inner = data['data'] as Map? ?? {};
    final extracted = inner['extracted'] as Map? ?? {};
    final pje = inner['proposed_je'] as Map? ?? {};
    final confidence = (inner['confidence'] as num?)?.toDouble() ?? 0.0;
    final warnings = ((inner['warnings'] as List?) ?? const [])
        .map((w) => w.toString())
        .toList();

    _memo.text = (pje['memo_ar'] ?? extracted['description'] ?? '').toString();
    final docNum = (extracted['document_number'] ?? '').toString();
    if (docNum.isNotEmpty) _reference.text = docNum;
    final parsedDate = DateTime.tryParse((extracted['date'] ?? '').toString());
    if (parsedDate != null) _date = parsedDate;

    // Rebuild lines
    for (final l in _lines) {
      l.dispose();
    }
    _lines.clear();
    final aiLines = (pje['lines'] as List?) ?? const [];
    for (final raw in aiLines) {
      if (raw is! Map) continue;
      final ln = _LineState();
      final accId = raw['account_id'];
      if (accId is String && accId.isNotEmpty) ln.accountId = accId;
      ln.debit = double.tryParse('${raw['debit'] ?? 0}') ?? 0;
      ln.credit = double.tryParse('${raw['credit'] ?? 0}') ?? 0;
      ln.description = (raw['description'] as String?) ?? '';
      ln.aiHint = (raw['account_name'] as String?) ?? '';
      ln.aiMatchConfidence =
          (raw['match_confidence'] as num?)?.toDouble() ?? 0;
      if (ln.debit > 0) ln.debitCtrl.text = ln.debit.toStringAsFixed(2);
      if (ln.credit > 0) ln.creditCtrl.text = ln.credit.toStringAsFixed(2);
      if (ln.description.isNotEmpty) ln.descCtrl.text = ln.description;
      _lines.add(ln);
    }
    while (_lines.length < 2) {
      _lines.add(_LineState());
    }

    setState(() {
      _aiDocConfidence = confidence;
      _aiWarnings = warnings;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: confidence >= 0.7 ? _ok : _warn,
        content: Text(
          'تم استخراج القيد من "${file.name}" — ثقة ${(confidence * 100).toStringAsFixed(0)}% · راجع قبل الحفظ',
        ),
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // AI — اقتراح بيان من السطور
  // ─────────────────────────────────────────────────────────────────
  Future<void> _aiSuggestMemo() async {
    final valid = _lines
        .where((l) => l.accountId != null && (l.debit > 0 || l.credit > 0))
        .toList();
    if (valid.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _warn,
        content: const Text('أدخل سطرين على الأقل بحسابات ومبالغ'),
      ));
      return;
    }
    setState(() => _aiMemoLoading = true);
    final payload = valid.map((l) {
      final acc = _accounts.firstWhere((a) => a['id'] == l.accountId,
          orElse: () => {});
      return {
        'account_id': l.accountId,
        if (acc.isNotEmpty) 'account_code': acc['code'],
        if (acc.isNotEmpty) 'account_name': acc['name_ar'],
        'debit': l.debit,
        'credit': l.credit,
        if (l.description.isNotEmpty) 'description': l.description,
      };
    }).toList();

    final r = await _client.aiSuggestMemo(
      lines: payload,
      kind: _kind,
      reference: _reference.text.trim(),
      date: _date.toIso8601String().substring(0, 10),
    );
    if (!mounted) return;
    setState(() => _aiMemoLoading = false);
    if (!r.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _err,
        content: Text(r.error ?? 'فشل اقتراح البيان'),
      ));
      return;
    }
    final data = r.data as Map? ?? {};
    final suggested = (data['suggested_memo'] ?? '').toString().trim();
    if (suggested.isEmpty) return;
    final conf = (data['confidence'] as num?)?.toDouble() ?? 0.7;
    setState(() => _memo.text = suggested);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: _ok,
      content: Text(
          'اقتراح بثقة ${(conf * 100).toStringAsFixed(0)}% — عدّله إن أردت'),
    ));
  }

  // ─────────────────────────────────────────────────────────────────
  // SUBMIT — حفظ قيد جديد (draft أو auto-post)
  // ─────────────────────────────────────────────────────────────────
  Future<void> _submit({required bool autoPost}) async {
    if (_memo.text.trim().isEmpty) {
      setState(() => _error = 'أدخل بياناً للقيد');
      return;
    }
    final valid = _lines
        .where((l) => l.accountId != null && (l.debit > 0 || l.credit > 0))
        .toList();
    if (valid.length < 2) {
      setState(() => _error = 'يلزم سطران على الأقل');
      return;
    }
    final diff = (_totalDebit - _totalCredit).abs();
    if (diff > 0.01) {
      setState(() => _error = 'القيد غير متوازن — فرق ${diff.toStringAsFixed(2)}');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _autoPost = autoPost;
    });
    final body = <String, dynamic>{
      'entity_id': PilotSession.entityId,
      'kind': _kind,
      'je_date': _date.toIso8601String().substring(0, 10),
      'memo_ar': _memo.text.trim(),
      'auto_post': autoPost,
      if (_reference.text.trim().isNotEmpty)
        'source_reference': _reference.text.trim(),
      if (_internalNote.text.trim().isNotEmpty)
        'internal_note': _internalNote.text.trim(),
      'to_check': _toCheck,
      'lines': valid
          .map((l) => {
                'account_id': l.accountId,
                'debit': l.debit.toString(),
                'credit': l.credit.toString(),
                if (l.description.trim().isNotEmpty)
                  'description': l.description.trim(),
                if (l.partnerLabel.trim().isNotEmpty)
                  'partner_id': l.partnerLabel.trim(),
                if (l.costCenterLabel.trim().isNotEmpty)
                  'cost_center_id': l.costCenterLabel.trim(),
                if (l.vatCode.isNotEmpty) 'vat_code': l.vatCode,
              })
          .toList(),
    };
    final r = await _client.createJournalEntry(body);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _ok,
        content: Text(
            autoPost ? 'تم إنشاء القيد وترحيله ✓' : 'تم حفظ القيد (مسودة) ✓'),
      ));
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = r.error ?? 'فشل الإنشاء');
    }
  }

  // ─── Post existing draft ───
  Future<void> _postEntry() async {
    if (_je == null) return;
    setState(() => _submitting = true);
    final r = await _client.postJournalEntry(_je!['id'] as String);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _ok,
        content: const Text('تم ترحيل القيد ✓'),
      ));
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = r.error ?? 'فشل الترحيل');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // COMPUTED
  // ─────────────────────────────────────────────────────────────────
  double get _totalDebit {
    if (_je != null) {
      return _jeLines.fold(0.0,
          (t, l) => t + (double.tryParse('${l['debit'] ?? 0}') ?? 0));
    }
    return _lines.fold(0.0, (t, l) => t + l.debit);
  }

  double get _totalCredit {
    if (_je != null) {
      return _jeLines.fold(0.0,
          (t, l) => t + (double.tryParse('${l['credit'] ?? 0}') ?? 0));
    }
    return _lines.fold(0.0, (t, l) => t + l.credit);
  }

  bool get _balanced => (_totalDebit - _totalCredit).abs() < 0.01;

  String _fmt(double v) {
    final s = v.toStringAsFixed(2);
    final p = s.split('.');
    final intP =
        p[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${p[1]}';
  }

  // ─────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: _gold),
              const SizedBox(height: 12),
              Text('جارٍ التحميل...', style: TextStyle(color: _ts)),
            ]),
          ),
        ),
      );
    }
    if (_error != null && _accounts.isEmpty) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline, color: _err, size: 48),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    final status = (_je?['status'] as String?) ?? 'draft';
    final stageInfo = _stageInfo(status);

    return ObjectPageTemplate(
      titleAr: _je != null
          ? 'قيد يومية ${_je!['je_number'] ?? ""}'
          : 'قيد يومية جديد',
      subtitleAr: _je != null
          ? '${_kindLabel(_je!['kind'] as String? ?? 'manual')} · ${_fmt(_totalDebit)} ر.س · ${_balanced ? "متوازن" : "غير متوازن"}'
          : 'وضع الإنشاء · ${_accounts.length} حساب · ${_balanced ? "متوازن" : "غير متوازن"}',
      statusLabelAr: _statusLabel(status),
      statusColor: stageInfo.color,
      // Stepper (4-stage) and smart-buttons strip removed — they took ~200px
      // for info already conveyed via the status pill + summary card +
      // new timeline section in the overview tab.
      tabsAtTop: true,
      hideTabsBar: true,
      primaryActions: _buildPrimaryActions(status),
      tabs: [
        ObjectPageTab(
          id: 'main',
          labelAr: '',
          icon: Icons.list_alt_rounded,
          builder: (_) => _buildActiveViewBody(),
        ),
      ],
      onBack: () => Navigator.of(context).maybePop(),
    );
  }

  ({int index, Color color}) _stageInfo(String status) {
    switch (status) {
      case 'draft':
        return (index: 0, color: _td);
      case 'submitted':
        return (index: 1, color: _warn);
      case 'approved':
        return (index: 2, color: _gold);
      case 'posted':
        return (index: 3, color: _ok);
      case 'reversed':
        return (index: 3, color: _err);
      default:
        return (index: 0, color: _td);
    }
  }

  String _statusLabel(String s) => const {
        'draft': 'مسودة',
        'submitted': 'قيد الاعتماد',
        'approved': 'معتمد',
        'posted': 'مرحّل',
        'reversed': 'معكوس',
        'cancelled': 'ملغى',
      }[s] ?? s;

  String _kindLabel(String k) => const {
        'manual': 'يدوي',
        'adjusting': 'تسوية',
        'opening': 'افتتاحي',
        'closing': 'إقفال',
        'auto_pos': 'من POS',
        'auto_po': 'من مشتريات',
        'reversal': 'عكسي',
      }[k] ?? k;

  // ─────────────────────────────────────────────────────────────────
  // PRIMARY ACTIONS (depends on status)
  // ─────────────────────────────────────────────────────────────────
  List<Widget> _buildPrimaryActions(String status) {
    if (_je == null) {
      // CREATE mode
      return [
        _aiReadDocButton(),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded, size: 16),
          label: const Text('إلغاء'),
          style: OutlinedButton.styleFrom(foregroundColor: _ts),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _submitting ? null : () => _submit(autoPost: false),
          icon: const Icon(Icons.save_outlined, size: 16),
          label: const Text('حفظ كمسودة'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _tp,
            side: BorderSide(color: _bdr),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: (_submitting || !_balanced)
              ? null
              : () => _submit(autoPost: true),
          icon: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : const Icon(Icons.rocket_launch_rounded, size: 16),
          style: FilledButton.styleFrom(
            backgroundColor: _balanced ? _gold : _navy3,
            foregroundColor:
                _balanced ? core_theme.AC.btnFg : _td,
          ),
          label: Text(_submitting ? 'جاري الحفظ...' : 'حفظ + ترحيل'),
        ),
      ];
    }
    // VIEW mode — based on status
    switch (status) {
      case 'draft':
        return [
          FilledButton.icon(
            onPressed: _submitting ? null : _postEntry,
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: core_theme.AC.btnFg,
            ),
            icon: const Icon(Icons.rocket_launch_rounded, size: 16),
            label: const Text('ترحيل'),
          ),
        ];
      case 'submitted':
        return [
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('رفض'),
            style: OutlinedButton.styleFrom(foregroundColor: _err),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.check_rounded, size: 16),
            style: FilledButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: core_theme.AC.btnFg,
            ),
            label: const Text('اعتماد وترحيل'),
          ),
        ];
      case 'posted':
        return [
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.history_rounded, size: 16),
            label: const Text('عكس القيد'),
            style: OutlinedButton.styleFrom(foregroundColor: _warn),
          ),
        ];
      default:
        return const [];
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB: OVERVIEW — AI quick bar + form inputs (create) OR details (view)
  // ─────────────────────────────────────────────────────────────────
  // ملاحظات عامة tab removed — its contents (ملخّص القيد + السجل) now
  // render at the bottom of the البنود tab so the full JE lives on one
  // scrollable surface.
  Widget _buildSummaryAndTimelineSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        _sectionCard(title: 'السجل', child: _buildHistoryTimeline()),
        if (_error != null) ...[
          const SizedBox(height: 14),
          _errorStrip(),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // History timeline — replaces the 4-stage stepper at the top.
  // Shows lifecycle events from creation through approval to posting,
  // each with timestamp + actor. In create mode renders a single
  // placeholder row.
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHistoryTimeline() {
    final events = <(String ts, String who, String what, IconData icon, Color color)>[];
    String fmtTs(dynamic v) {
      if (v == null) return '';
      final s = v.toString();
      if (s.length < 16) return s;
      return s.substring(0, 16).replaceAll('T', ' ');
    }

    if (_je == null) {
      events.add((
        DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' '),
        'أنت',
        'قيد قيد الإنشاء — لم يُحفظ بعد',
        Icons.edit_note_rounded,
        _td,
      ));
    } else {
      final j = _je!;
      if (j['created_at'] != null) {
        events.add((
          fmtTs(j['created_at']),
          (j['created_by_user_id'] as String?) ?? 'النظام',
          'تم إنشاء القيد',
          Icons.add_circle_rounded,
          _td,
        ));
      }
      if (j['submitted_at'] != null) {
        events.add((
          fmtTs(j['submitted_at']),
          (j['submitted_by_user_id'] as String?) ?? 'النظام',
          'تم رفع القيد للاعتماد',
          Icons.hourglass_top_rounded,
          _warn,
        ));
      }
      if (j['approved_at'] != null) {
        events.add((
          fmtTs(j['approved_at']),
          (j['approved_by_user_id'] as String?) ?? 'النظام',
          'تم اعتماد القيد',
          Icons.verified_rounded,
          _gold,
        ));
      }
      if (j['posted_at'] != null) {
        events.add((
          fmtTs(j['posted_at']),
          (j['posted_by_user_id'] as String?) ?? 'النظام',
          'تم ترحيل القيد إلى GL',
          Icons.check_circle_rounded,
          _ok,
        ));
      }
      if (j['reversed_by_je_id'] != null) {
        events.add((
          '',
          'النظام',
          'تم عكس القيد بقيد مقابل',
          Icons.undo_rounded,
          _err,
        ));
      }
      if (j['rejection_reason'] != null &&
          (j['rejection_reason'] as String).isNotEmpty) {
        events.add((
          '',
          'المعتمد',
          'رُفض الاعتماد — ${j['rejection_reason']}',
          Icons.cancel_rounded,
          _err,
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < events.length; i++) ...[
          _timelineRow(events[i], isLast: i == events.length - 1),
        ],
      ],
    );
  }

  Widget _timelineRow(
      (String, String, String, IconData, Color) ev,
      {required bool isLast}) {
    final (ts, who, what, icon, color) = ev;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical rail with dot
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: _bdr,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(what,
                      style: TextStyle(
                          color: _tp,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    [if (ts.isNotEmpty) ts, who].join(' · '),
                    style: TextStyle(color: _ts, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── AI quick bar (create mode only) ───
  // Violet AI document-read button — lives in the top action bar.
  Widget _aiReadDocButton() {
    final hasDoc = _aiDocFilename != null;
    final tooltip = hasDoc
        ? 'قُرئ من: $_aiDocFilename · ثقة ${((_aiDocConfidence ?? 0) * 100).toStringAsFixed(0)}%'
        : 'ارفع فاتورة / إيصال / PDF — Claude يستخرج الحقول والسطور تلقائياً';
    return Tooltip(
      message: tooltip,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
        ),
        onPressed: _aiDocLoading ? null : _aiReadDocument,
        icon: _aiDocLoading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(
                hasDoc ? Icons.refresh_rounded : Icons.upload_file_rounded,
                size: 16),
        label: Text(_aiDocLoading
            ? 'جاري...'
            : (hasDoc ? 'إعادة القراءة' : 'قراءة مستند')),
      ),
    );
  }

  Widget _aiWarningsStrip() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _warn.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _warn.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _aiWarnings
            .map((w) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: _warn, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(w,
                            style: TextStyle(
                                color: _warn, fontSize: 11, height: 1.4)),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _errorStrip() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _err.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _err.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: _err, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_error!,
              style: TextStyle(color: _err, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _sectionCard({String? title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bdr),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: _navy)),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }

  // ─── Create-mode basic fields (inputs) ───
  Widget _createBasicFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _journalDropdown()),
          const SizedBox(width: 12),
          Expanded(child: _dateField()),
          const SizedBox(width: 12),
          Expanded(child: _referenceField()),
        ]),
        const SizedBox(height: 14),
        _memoField(),
      ],
    );
  }

  Widget _journalDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('دفتر اليومية',
            style: TextStyle(color: _td, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _kind,
              isExpanded: true,
              style: TextStyle(color: _tp, fontSize: 13),
              icon: Icon(Icons.expand_more_rounded, color: _ts),
              items: const [
                DropdownMenuItem(value: 'manual', child: Text('يدوي عام')),
                DropdownMenuItem(
                    value: 'adjusting', child: Text('قيد تسوية')),
                DropdownMenuItem(value: 'opening', child: Text('قيد افتتاحي')),
                DropdownMenuItem(value: 'closing', child: Text('قيد إقفال')),
              ],
              onChanged: (v) => setState(() => _kind = v ?? 'manual'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('تاريخ المحاسبة',
            style: TextStyle(color: _td, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: _date,
              firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (d != null) setState(() => _date = d);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr),
            ),
            child: Row(children: [
              Icon(Icons.calendar_today_rounded, color: _gold, size: 14),
              const SizedBox(width: 8),
              Text(
                '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                    color: _tp, fontSize: 13, fontFamily: 'monospace'),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _referenceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('الرقم المرجعي',
            style: TextStyle(color: _td, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: _reference,
          style: TextStyle(color: _tp, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'INV-123 (اختياري)',
            hintStyle: TextStyle(color: _td, fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _bdr),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _bdr),
            ),
          ),
        ),
      ],
    );
  }

  Widget _memoField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('البيان *',
            style: TextStyle(color: _td, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: _memo,
          style: TextStyle(color: _tp, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'مثال: إثبات فاتورة مشتريات من مورد X',
            hintStyle: TextStyle(color: _td, fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(12),
            suffixIcon: Tooltip(
              message: 'اقترح بياناً بالذكاء الاصطناعي',
              child: InkWell(
                onTap: _aiMemoLoading ? null : _aiSuggestMemo,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  margin: const EdgeInsets.all(5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _purple.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _purple.withValues(alpha: 0.4)),
                  ),
                  child: _aiMemoLoading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(_purple),
                          ),
                        )
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.auto_awesome_rounded,
                              size: 14, color: _purple),
                          const SizedBox(width: 4),
                          Text('اكتب',
                              style: TextStyle(
                                  color: _purple,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                        ]),
                ),
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _bdr),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: _bdr),
            ),
          ),
        ),
      ],
    );
  }

  // ─── View-mode basic fields (read-only) ───
  Widget _viewBasicFields() {
    return Wrap(
      spacing: 32,
      runSpacing: 16,
      children: [
        _kv('رقم القيد', _je!['je_number']?.toString() ?? '—'),
        _kv('التاريخ', _je!['je_date']?.toString() ?? '—'),
        _kv('النوع', _kindLabel(_je!['kind']?.toString() ?? 'manual')),
        _kv('الحالة', _statusLabel(_je!['status']?.toString() ?? 'draft')),
        _kv('البيان', _je!['memo_ar']?.toString() ?? '—'),
        if (_je!['source_reference'] != null)
          _kv('المرجع', _je!['source_reference'].toString()),
      ],
    );
  }

  Widget _kv(String label, String value) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: _ts)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Local tabs — moved out of the shell into the content area where the
  // البيانات الأساسية title used to sit. The tab strip is rendered as
  // the heading of the first section card on every view.
  // ─────────────────────────────────────────────────────────────────
  Widget _buildActiveViewBody() {
    switch (_activeView) {
      case 'other_info':
        return _buildOtherInfoTab();
      case 'lines':
      default:
        return _buildLinesTab();
    }
  }

  Widget _localTabsStrip() {
    final linesCount = _je != null ? _jeLines.length : _lines.length;
    final tabs = <(String id, String tooltip, IconData icon, int? badge)>[
      ('lines', 'البنود', Icons.list_alt_rounded, linesCount),
      ('other_info', 'معلومات أخرى', Icons.info_outline_rounded, null),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final active = t.$1 == _activeView;
          return Tooltip(
            message: t.$2,
            child: InkWell(
              onTap: () => setState(() => _activeView = t.$1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? _gold : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(t.$3,
                        size: 20, color: active ? _gold : _ts),
                    if (t.$4 != null && t.$4! > 0)
                      PositionedDirectional(
                        top: -4,
                        end: -8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: active ? _gold : _ts,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          child: Text(
                            '${t.$4}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB: LINES — also hosts the AI quick bar + البيانات الأساسية at
  // the top so the user can fill the header and rows on a single tab.
  // ─────────────────────────────────────────────────────────────────
  Widget _buildLinesTab() {
    if (_je != null) return _buildLinesViewTable();
    return _buildLinesEditTable();
  }

  Widget _buildLinesViewTable() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _localTabsStrip(),
              const SizedBox(height: 14),
              _viewBasicFields(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _sectionCard(
          title: 'بنود القيد',
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _bdr),
            ),
            child: Column(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _navy3.withValues(alpha: 0.4),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Row(children: [
                  SizedBox(
                      width: 30,
                      child: Text('#',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _td))),
                  Expanded(
                      flex: 3,
                      child: Text('الحساب',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _td))),
                  Expanded(
                      flex: 3,
                      child: Text('البيان',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _td))),
                  SizedBox(
                      width: 110,
                      child: Text('مدين',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _td),
                          textAlign: TextAlign.end)),
                  SizedBox(
                      width: 110,
                      child: Text('دائن',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _td),
                          textAlign: TextAlign.end)),
                ]),
              ),
              ..._jeLines.asMap().entries.map((e) {
                final l = e.value;
                final acc = _accounts.firstWhere(
                    (a) => a['id'] == l['account_id'],
                    orElse: () => {});
                final debit = double.tryParse('${l['debit'] ?? 0}') ?? 0;
                final credit = double.tryParse('${l['credit'] ?? 0}') ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border:
                        Border(top: BorderSide(color: _bdr.withValues(alpha: 0.5))),
                  ),
                  child: Row(children: [
                    SizedBox(width: 30, child: Text('${e.key + 1}')),
                    Expanded(
                        flex: 3,
                        child: Text(
                          acc.isEmpty
                              ? (l['account_id'] ?? '—').toString()
                              : '${acc['code']} — ${acc['name_ar']}',
                          style:
                              const TextStyle(fontFamily: 'monospace', fontSize: 12),
                        )),
                    Expanded(
                        flex: 3,
                        child: Text(
                            (l['description'] ?? '—').toString(),
                            style: const TextStyle(fontSize: 12))),
                    SizedBox(
                        width: 110,
                        child: Text(debit > 0 ? _fmt(debit) : '—',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: debit > 0
                                    ? FontWeight.w800
                                    : FontWeight.w400,
                                color: debit > 0 ? _ok : _td,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.end)),
                    SizedBox(
                        width: 110,
                        child: Text(credit > 0 ? _fmt(credit) : '—',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: credit > 0
                                    ? FontWeight.w800
                                    : FontWeight.w400,
                                color: credit > 0 ? _gold : _td,
                                fontFamily: 'monospace'),
                            textAlign: TextAlign.end)),
                  ]),
                );
              }),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _navy3.withValues(alpha: 0.3),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(7)),
                ),
                child: Row(children: [
                  Expanded(
                    child: Row(children: [
                      Text('الإجمالي',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _navy)),
                      const SizedBox(width: 10),
                      _balanceChip(),
                    ]),
                  ),
                  SizedBox(
                      width: 110,
                      child: Text(_fmt(_totalDebit),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                              fontFamily: 'monospace'),
                          textAlign: TextAlign.end)),
                  SizedBox(
                      width: 110,
                      child: Text(_fmt(_totalCredit),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                              fontFamily: 'monospace'),
                          textAlign: TextAlign.end)),
                ]),
              ),
            ]),
          ),
        ),
        _buildSummaryAndTimelineSection(),
      ],
    );
  }

  Widget _buildLinesEditTable() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (_aiWarnings.isNotEmpty) _aiWarningsStrip(),
        if (_aiWarnings.isNotEmpty) const SizedBox(height: 18),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _localTabsStrip(),
              const SizedBox(height: 14),
              _createBasicFields(),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr),
          ),
          child: Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _navy3.withValues(alpha: 0.4),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(7)),
                  ),
                  child: Row(children: [
                    SizedBox(
                        width: 30,
                        child: Text('#',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _td))),
                    Expanded(
                        flex: 3,
                        child: Text('الحساب',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _td))),
                    if (_showPartner) ...[
                      const SizedBox(width: 8),
                      Expanded(
                          flex: 2,
                          child: Text('الشريك',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _td))),
                    ],
                    Expanded(
                        flex: 3,
                        child: Text('البيان',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _td))),
                    if (_showCostCenter) ...[
                      const SizedBox(width: 8),
                      Expanded(
                          flex: 2,
                          child: Text('التوزيع التحليلي',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _td))),
                    ],
                    if (_showVat) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                          width: 100,
                          child: Text('شبكات الضرائب',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _td))),
                    ],
                    SizedBox(
                        width: 110,
                        child: Text('مدين',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _td),
                            textAlign: TextAlign.end)),
                    SizedBox(
                        width: 110,
                        child: Text('دائن',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _td),
                            textAlign: TextAlign.end)),
                    SizedBox(width: 30, child: _columnSettingsButton()),
                  ]),
                ),
                ..._lines
                    .asMap()
                    .entries
                    .map((e) => _lineEditRow(e.key, e.value)),
                _addLineFooterRow(),
                _totalsFooterRow(),
              ]),
        ),
        _buildSummaryAndTimelineSection(),
      ],
    );
  }

  Widget _lineEditRow(int i, _LineState l) {
    final acc = _accounts.firstWhere((a) => a['id'] == l.accountId,
        orElse: () => {});
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _bdr.withValues(alpha: 0.5))),
      ),
      child: Row(children: [
        SizedBox(
            width: 30,
            child: Text('${i + 1}',
                style: TextStyle(fontSize: 11, color: _td),
                textAlign: TextAlign.center)),
        Expanded(
          flex: 3,
          child: InkWell(
            onTap: () => _pickAccount(i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _bdr),
              ),
              child: Row(children: [
                Icon(
                  acc.isEmpty
                      ? (l.aiHint.isNotEmpty
                          ? Icons.auto_awesome_rounded
                          : Icons.search_rounded)
                      : Icons.check_circle_rounded,
                  color: acc.isEmpty
                      ? (l.aiHint.isNotEmpty ? _warn : _gold)
                      : _ok,
                  size: 12,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    acc.isEmpty
                        ? (l.aiHint.isNotEmpty
                            ? '⚠ ${l.aiHint}'
                            : 'اختر حساباً')
                        : '${acc['code']} — ${acc['name_ar']}',
                    style: TextStyle(
                        color:
                            acc.isEmpty ? (l.aiHint.isNotEmpty ? _warn : _td) : _tp,
                        fontSize: 11,
                        fontFamily: acc.isEmpty ? null : 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
        ),
        if (_showPartner) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: l.partnerCtrl,
              onChanged: (v) => l.partnerLabel = v,
              style: TextStyle(color: _tp, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'مورد / عميل',
                hintStyle: TextStyle(color: _td, fontSize: 10),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            controller: l.descCtrl,
            onChanged: (v) => l.description = v,
            style: TextStyle(color: _tp, fontSize: 11),
            decoration: InputDecoration(
              hintText: 'اختياري',
              hintStyle: TextStyle(color: _td, fontSize: 10),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
        if (_showCostCenter) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: l.costCenterCtrl,
              onChanged: (v) => l.costCenterLabel = v,
              style: TextStyle(color: _tp, fontSize: 11),
              decoration: InputDecoration(
                hintText: 'مركز تكلفة',
                hintStyle: TextStyle(color: _td, fontSize: 10),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
        if (_showVat) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: DropdownButtonFormField<String>(
              value: l.vatCode.isEmpty ? null : l.vatCode,
              isDense: true,
              isExpanded: true,
              hint: Text('VAT', style: TextStyle(color: _td, fontSize: 10)),
              style: TextStyle(color: _tp, fontSize: 11),
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: _bdr),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(color: _bdr),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'standard', child: Text('قياسي 15%')),
                DropdownMenuItem(value: 'zero_rated', child: Text('صفري')),
                DropdownMenuItem(value: 'exempt', child: Text('معفى')),
              ],
              onChanged: (v) => setState(() => l.vatCode = v ?? ''),
            ),
          ),
        ],
        SizedBox(
          width: 110,
          child: TextField(
            controller: l.debitCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final p = double.tryParse(v) ?? 0;
              setState(() {
                l.debit = p;
                if (p > 0 && l.credit > 0) {
                  l.credit = 0;
                  l.creditCtrl.text = '';
                }
              });
            },
            style: TextStyle(
                color: _ok,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: l.debit > 0
                  ? _ok.withValues(alpha: 0.08)
                  : Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _bdr),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _bdr),
              ),
            ),
            textAlign: TextAlign.end,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 110,
          child: TextField(
            controller: l.creditCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              final p = double.tryParse(v) ?? 0;
              setState(() {
                l.credit = p;
                if (p > 0 && l.debit > 0) {
                  l.debit = 0;
                  l.debitCtrl.text = '';
                }
              });
            },
            style: TextStyle(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: l.credit > 0
                  ? _gold.withValues(alpha: 0.08)
                  : Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _bdr),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: _bdr),
              ),
            ),
            textAlign: TextAlign.end,
          ),
        ),
        SizedBox(
          width: 30,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'حذف',
            icon: Icon(Icons.delete_outline_rounded, color: _err, size: 16),
            onPressed: _lines.length > 2
                ? () => setState(() {
                      _lines[i].dispose();
                      _lines.removeAt(i);
                    })
                : null,
          ),
        ),
      ]),
    );
  }

  Future<void> _pickAccount(int idx) async {
    final search = TextEditingController();
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setSt) {
            final q = search.text.toLowerCase();
            final filtered = _accounts.where((a) {
              if (a['type'] != 'detail') return false;
              if (q.isEmpty) return true;
              return (a['code'] ?? '').toString().toLowerCase().contains(q) ||
                  (a['name_ar'] ?? '').toString().toLowerCase().contains(q);
            }).toList();
            return AlertDialog(
              title: Row(children: [
                Icon(Icons.search_rounded, color: _gold),
                const SizedBox(width: 8),
                const Text('اختر حساباً'),
              ]),
              content: SizedBox(
                width: 520,
                height: 500,
                child: Column(children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    onChanged: (_) => setSt(() {}),
                    decoration: const InputDecoration(
                      hintText: 'ابحث بالكود أو الاسم...',
                      prefixIcon: Icon(Icons.search_rounded),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final a = filtered[i];
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(a['code'] ?? '',
                                style: TextStyle(
                                    color: _gold,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ),
                          title: Text(a['name_ar'] ?? '',
                              style: const TextStyle(fontSize: 13)),
                          subtitle: Text(
                              '${a['category']} · ${a['normal_balance']}',
                              style: TextStyle(color: _td, fontSize: 10)),
                          onTap: () => Navigator.pop(ctx, a),
                        );
                      },
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
    search.dispose();
    if (selected != null) {
      setState(() => _lines[idx].accountId = selected['id']);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB: OTHER INFO — Odoo "Other Information" parity
  // Auto-post toggle, To-check flag, internal note. Read-only when
  // viewing an existing entry; editable in create mode.
  // ─────────────────────────────────────────────────────────────────
  Widget _buildOtherInfoTab() {
    final isCreateMode = _je == null;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _localTabsStrip(),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('الترحيل التلقائي',
                    style: TextStyle(
                        color: _tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                subtitle: Text(
                    'عند الحفظ، يتم ترحيل القيد مباشرة إلى GL Postings.',
                    style: TextStyle(color: _ts, fontSize: 11)),
                value: _autoPost,
                activeColor: _gold,
                onChanged: isCreateMode
                    ? (v) => setState(() => _autoPost = v)
                    : null,
              ),
              Divider(color: _bdr.withValues(alpha: 0.5)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('للتحقق منه',
                    style: TextStyle(
                        color: _tp,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                subtitle: Text(
                    'تمييز القيد لمراجعة لاحقة قبل الترحيل.',
                    style: TextStyle(color: _ts, fontSize: 11)),
                value: _toCheck,
                activeColor: _warn,
                onChanged: isCreateMode
                    ? (v) => setState(() => _toCheck = v)
                    : null,
              ),
              Divider(color: _bdr.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('ملاحظة داخلية',
                  style: TextStyle(
                      color: _td,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              TextField(
                controller: _internalNote,
                enabled: isCreateMode,
                maxLines: 4,
                style: TextStyle(color: _tp, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'ملاحظة لا تظهر للعميل — للسجل الداخلي فقط…',
                  hintStyle: TextStyle(color: _td, fontSize: 11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: _bdr),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: _bdr),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Column-settings button (⚙️) — Odoo-style toggle for optional
  // line-item columns: partner / cost-center / VAT.
  // ─────────────────────────────────────────────────────────────────
  // Totals footer — debit total under debit column, credit total under credit
  // column, balance chip on the right. Mirrors the view-mode totals row.
  Widget _totalsFooterRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _navy3.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(7)),
      ),
      child: Row(children: [
        Expanded(
          child: Row(children: [
            Text('الإجمالي',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _navy)),
            const SizedBox(width: 10),
            _balanceChip(),
          ]),
        ),
        SizedBox(
            width: 110,
            child: Text(_fmt(_totalDebit),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    fontFamily: 'monospace'),
                textAlign: TextAlign.end)),
        SizedBox(
            width: 110,
            child: Text(_fmt(_totalCredit),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    fontFamily: 'monospace'),
                textAlign: TextAlign.end)),
        const SizedBox(width: 30),
      ]),
    );
  }

  Widget _balanceChip() {
    final diff = (_totalDebit - _totalCredit).abs();
    final color = _balanced ? _ok : _err;
    final icon = _balanced ? Icons.check_circle : Icons.warning_amber_rounded;
    final label = _balanced ? 'متوازن' : 'فرق ${_fmt(diff)} ر.س';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  // Odoo-style "Add a line" affordance — sits as the last row inside the table.
  Widget _addLineFooterRow() {
    return InkWell(
      onTap: () => setState(() => _lines.add(_LineState())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _bdr.withValues(alpha: 0.5))),
        ),
        child: Row(children: [
          Icon(Icons.add_rounded, size: 14, color: _gold),
          const SizedBox(width: 6),
          Text('إضافة سطر',
              style: TextStyle(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _columnSettingsButton() {
    return PopupMenuButton<String>(
      tooltip: 'إعدادات الأعمدة',
      position: PopupMenuPosition.under,
      padding: EdgeInsets.zero,
      iconSize: 16,
      icon: Icon(Icons.tune_rounded, size: 16, color: _ts),
      itemBuilder: (_) => [
        CheckedPopupMenuItem<String>(
          value: 'partner',
          checked: _showPartner,
          child: const Text('الشريك'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'cost_center',
          checked: _showCostCenter,
          child: const Text('التوزيع التحليلي'),
        ),
        CheckedPopupMenuItem<String>(
          value: 'vat',
          checked: _showVat,
          child: const Text('شبكات الضرائب'),
        ),
      ],
      onSelected: (v) => setState(() {
        switch (v) {
          case 'partner':
            _showPartner = !_showPartner;
            break;
          case 'cost_center':
            _showCostCenter = !_showCostCenter;
            break;
          case 'vat':
            _showVat = !_showVat;
            break;
        }
      }),
    );
  }

}
