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
  List<_LineState> _lines = [_LineState(), _LineState()];
  bool _submitting = false;
  // When the user clicks تعديل on a posted entry, we drop into edit
  // mode (a fresh draft) but remember the original posted entry id +
  // number. On submit, the original is auto-reversed first so the
  // posted ledger reflects the replacement: original + reversal of
  // original + new corrected entry. Standard accounting workflow for
  // correcting a posted entry without breaking the audit trail.
  String? _editingPostedJeId;
  String? _editingPostedJeNumber;

  // ─── Optional column visibility (Odoo-style ⚙️ toggle) ───
  // Default ON — accountants asked for the partner / cost-center / VAT
  // columns to be visible from the first interaction. Toggle remains
  // available via the column-settings popup in the lines table header.
  bool _showPartner = true;
  bool _showCostCenter = true;
  bool _showVat = true;

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
    if (parsedDate != null) {
      _date = parsedDate;
      _dateCtrl.text = _formatDate(parsedDate);
    }

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
    // ── Edit-of-posted workflow ──
    // If we entered this draft via the تعديل button on a posted
    // entry, reverse the original first so the ledger stays
    // consistent. Only do this on autoPost (final submit) — saving
    // as a draft shouldn't mutate the posted ledger yet.
    if (autoPost && _editingPostedJeId != null) {
      final reverseResp = await _client.reverseJournalEntry(
        _editingPostedJeId!,
        {
          'reversal_date': _formatDate(DateTime.now()),
          'memo_ar':
              'عكس قيد ${_editingPostedJeNumber ?? ""} للتعديل',
        },
      );
      if (!mounted) return;
      if (!reverseResp.success) {
        setState(() {
          _submitting = false;
          _error = 'فشل عكس القيد الأصلي: '
              '${reverseResp.error ?? "خطأ غير معروف"}';
        });
        return;
      }
    }
    final r = await _client.createJournalEntry(body);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (r.success) {
      final wasEdit = _editingPostedJeId != null && autoPost;
      _editingPostedJeId = null;
      _editingPostedJeNumber = null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _ok,
        content: Text(wasEdit
            ? 'تم عكس القيد الأصلي وترحيل القيد المُصحَّح ✓'
            : (autoPost
                ? 'تم إنشاء القيد وترحيله ✓'
                : 'تم حفظ القيد (مسودة) ✓')),
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

  // Backend uses `debit_amount` / `credit_amount` on saved lines but
  // the create-side payload posts `debit` / `credit`. Read both so
  // either shape parses correctly.
  double _lineDebit(Map<String, dynamic> l) =>
      double.tryParse('${l['debit_amount'] ?? l['debit'] ?? 0}') ?? 0;
  double _lineCredit(Map<String, dynamic> l) =>
      double.tryParse('${l['credit_amount'] ?? l['credit'] ?? 0}') ?? 0;

  double get _totalDebit {
    if (_je != null) {
      return _jeLines.fold(0.0, (t, l) => t + _lineDebit(l));
    }
    return _lines.fold(0.0, (t, l) => t + l.debit);
  }

  double get _totalCredit {
    if (_je != null) {
      return _jeLines.fold(0.0, (t, l) => t + _lineCredit(l));
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

    return ObjectPageTemplate(
      titleAr: _je != null
          ? 'قيد اليومية ${_je!['je_number'] ?? ""}'
          : 'قيد اليومية',
      subtitleAr: null,
      // Status pill removed — the chevron status flow above the lines
      // table now carries this info.
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
      // CREATE mode — keep all toolbar icons visually consistent: same
      // 36×36 footprint, same rounded-rect, same subtle hover state.
      return [
        _aiReadDocButton(),
        const SizedBox(width: 6),
        _toolbarIconButton(
          icon: Icons.save_outlined,
          tooltip: 'حفظ كمسودة',
          onPressed:
              _submitting ? null : () => _submit(autoPost: false),
        ),
        const SizedBox(width: 6),
        _toolbarIconButton(
          icon: Icons.replay_rounded,
          tooltip: 'إلغاء (إهمال)',
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(),
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
        // Posted-mode actions (تعديل + عكس القيد) now live in
        // _postedActionBar above the entry-number card so they sit
        // next to the data they affect rather than the global toolbar.
        return const [];
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
    final isCreateMode = _je == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // History timeline only carries useful info once the JE has
        // been saved — in create mode it would just say "لم يُحفظ بعد"
        // which the مسودة chevron already conveys. Skip the whole card.
        if (!isCreateMode) ...[
          const SizedBox(height: 18),
          _sectionCard(title: 'السجل', child: _buildHistoryTimeline()),
        ],
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

  // Generic toolbar icon — 36×36 rounded-rect, neutral muted icon
  // color, subtle hover. Use for save / undo / cancel etc. so all
  // top-bar icons share one footprint with the AI button.
  Widget _toolbarIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        style: IconButton.styleFrom(
          foregroundColor: _tp,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
      ),
    );
  }

  // ─── AI quick bar (create mode only) ───
  // AI document-read button — sized to match the surrounding toolbar
  // icons (⋮ / save / undo). Ghost style with a subtle purple tint
  // so it reads as an action-with-AI without shouting.
  Widget _aiReadDocButton() {
    final hasDoc = _aiDocFilename != null;
    final tooltip = hasDoc
        ? 'قُرئ من: $_aiDocFilename · ثقة ${((_aiDocConfidence ?? 0) * 100).toStringAsFixed(0)}% — اضغط لإعادة القراءة'
        : 'قراءة مستند بالذكاء الاصطناعي — ارفع فاتورة / إيصال / PDF';
    return Tooltip(
      message: tooltip,
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: _purple.withValues(alpha: 0.10),
          foregroundColor: _purple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          minimumSize: const Size(36, 36),
        ),
        onPressed: _aiDocLoading ? null : _aiReadDocument,
        icon: _aiDocLoading
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(_purple)),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 18),
      ),
    );
  }

  // Banner that appears at the top of the create form when the
  // user landed here via "تعديل" on a posted entry. Tells them
  // exactly what will happen on submit (reverse + new entry) and
  // gives them a cancel option to revert to viewing the original.
  Widget _editingPostedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _navy.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(Icons.edit_note_rounded, color: _navy, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'وضع التعديل: ${_editingPostedJeNumber ?? ""}',
                  style: TextStyle(
                      color: _navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                  'عند الترحيل سيُعكس القيد الأصلي تلقائياً ثم يُرحَّل القيد المُصحَّح في خطوة واحدة.',
                  style: TextStyle(
                      color: _td, fontSize: 11.5)),
            ],
          ),
        ),
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  setState(() {
                    _editingPostedJeId = null;
                    _editingPostedJeNumber = null;
                  });
                  Navigator.of(context).maybePop();
                },
          child: Text('إلغاء التعديل',
              style: TextStyle(
                  color: _td, fontWeight: FontWeight.w700)),
        ),
      ]),
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
        border: Border.all(color: _bdr.withValues(alpha: 0.55)),
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

  // Shared style for form-field labels (دفتر اليومية, تاريخ ...).
  TextStyle get _formLabelStyle => TextStyle(
        color: _td.withValues(alpha: 0.85),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      );

  // Shared form-field border — lighter than the table cell border so
  // the top form card feels airy rather than boxed-in.
  OutlineInputBorder get _formFieldBorder => OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: _bdr.withValues(alpha: 0.55)),
      );

  OutlineInputBorder get _formFieldFocusBorder => OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: _navy, width: 1.4),
      );

  Widget _journalDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('دفتر اليومية', style: _formLabelStyle),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr.withValues(alpha: 0.55)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _kind,
              isExpanded: true,
              style: TextStyle(color: _tp, fontSize: 13),
              icon: Icon(Icons.expand_more_rounded,
                  color: _ts.withValues(alpha: 0.8)),
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

  // Anchor key for the custom date popover — measured at tap-time
  // to position the popover under the field.
  final GlobalKey _dateFieldKey = GlobalKey();
  late final TextEditingController _dateCtrl =
      TextEditingController(text: _formatDate(_date));

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Try to parse `YYYY-MM-DD` from the text field. Silently no-op on
  // invalid input so the user can finish typing — only commits to
  // _date when the string is a complete, valid, in-range date.
  void _trySetDateFromText(String text) {
    final m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(text);
    if (m == null) return;
    try {
      final y = int.parse(m.group(1)!);
      final mo = int.parse(m.group(2)!);
      final d = int.parse(m.group(3)!);
      final parsed = DateTime(y, mo, d);
      // Reject if the components got rounded (e.g. month 13 → next year).
      if (parsed.year != y || parsed.month != mo || parsed.day != d) return;
      final firstDate =
          DateTime.now().subtract(const Duration(days: 365 * 3));
      final lastDate = DateTime.now().add(const Duration(days: 30));
      if (parsed.isBefore(firstDate) || parsed.isAfter(lastDate)) return;
      setState(() => _date = parsed);
    } catch (_) {}
  }

  Widget _dateField() {
    return Column(
      key: _dateFieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('تاريخ المحاسبة', style: _formLabelStyle),
        const SizedBox(height: 4),
        TextField(
          controller: _dateCtrl,
          style: TextStyle(
              color: _tp,
              fontSize: 13,
              fontFamily: 'monospace',
              letterSpacing: 0.4),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.start,
          keyboardType: TextInputType.datetime,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: _trySetDateFromText,
          decoration: InputDecoration(
            hintText: 'YYYY-MM-DD',
            hintStyle: TextStyle(
                color: _td.withValues(alpha: 0.45),
                fontSize: 12,
                fontFamily: 'monospace'),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            prefixIcon: IconButton(
              tooltip: 'افتح التقويم',
              icon: Icon(Icons.calendar_today_rounded,
                  color: _ts.withValues(alpha: 0.85), size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                  minWidth: 36, minHeight: 36),
              onPressed: () => _openDatePopover(),
            ),
            border: _formFieldBorder,
            enabledBorder: _formFieldBorder,
            focusedBorder: _formFieldFocusBorder,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Custom date popover — anchors directly under the date field
  // instead of the full-screen Material modal. Compact (~280px),
  // brand colors (navy selected, gold "today"), Arabic month nav,
  // quick-action chips (اليوم / أمس / بداية الشهر).
  // ─────────────────────────────────────────────────────────────────
  void _openDatePopover() {
    final ctx = _dateFieldKey.currentContext;
    if (ctx == null) return;
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(ctx);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final fieldOffset = renderBox.localToGlobal(Offset.zero,
        ancestor: overlayBox);
    final fieldSize = renderBox.size;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx2) => _DatePopover(
        anchorTopLeft: fieldOffset,
        anchorSize: fieldSize,
        overlaySize: overlayBox.size,
        initial: _date,
        firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        navy: _navy,
        gold: _gold,
        navy3: _navy3,
        bdr: _bdr,
        td: _td,
        ts: _ts,
        tp: _tp,
        onPicked: (d) {
          entry.remove();
          if (d != null) {
            setState(() => _date = d);
            _dateCtrl.text = _formatDate(d);
          }
        },
      ),
    );
    overlay.insert(entry);
  }

  Widget _referenceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('الرقم المرجعي', style: _formLabelStyle),
        const SizedBox(height: 4),
        TextField(
          controller: _reference,
          style: TextStyle(color: _tp, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'INV-123 (اختياري)',
            hintStyle: TextStyle(
                color: _td.withValues(alpha: 0.55), fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            border: _formFieldBorder,
            enabledBorder: _formFieldBorder,
            focusedBorder: _formFieldFocusBorder,
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
        Text('البيان *', style: _formLabelStyle),
        const SizedBox(height: 4),
        TextField(
          controller: _memo,
          style: TextStyle(color: _tp, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'مثال: إثبات فاتورة مشتريات من مورد X',
            hintStyle: TextStyle(
                color: _td.withValues(alpha: 0.55), fontSize: 12),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(12),
            suffixIcon: Tooltip(
              message: 'اقترح بياناً بالذكاء الاصطناعي',
              child: InkWell(
                onTap: _aiMemoLoading ? null : _aiSuggestMemo,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
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
                                  fontWeight: FontWeight.w700)),
                        ]),
                ),
              ),
            ),
            border: _formFieldBorder,
            enabledBorder: _formFieldBorder,
            focusedBorder: _formFieldFocusBorder,
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
  // Top section (post button row + chevron + header form card + tabs)
  // is always rendered the same way. Only the body container under the
  // tabs swaps based on _activeView ('lines' vs 'other_info').
  Widget _buildActiveViewBody() => _buildLinesTab();

  // ─────────────────────────────────────────────────────────────────
  // Local tabs strip — rectangular tabs with icon + label + count
  // badge, sitting on top of the body table. The active tab visually
  // connects to the table below it: white fill, no visible bottom
  // border, top corners rounded.
  // ─────────────────────────────────────────────────────────────────
  Widget _localTabsStrip() {
    final linesCount = _je != null ? _jeLines.length : _lines.length;
    final tabs = <(String id, String label, IconData icon, int? badge)>[
      ('lines', 'البنود', Icons.list_alt_rounded, linesCount),
      ('other_info', 'معلومات أخرى', Icons.info_outline_rounded, null),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: tabs.map((t) {
          final active = t.$1 == _activeView;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 4),
            child: InkWell(
              onTap: () => setState(() => _activeView = t.$1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? Colors.white : _navy3.withValues(alpha: 0.35),
                  border: Border(
                    top: BorderSide(color: active ? _bdr : Colors.transparent),
                    left: BorderSide(color: active ? _bdr : Colors.transparent),
                    right:
                        BorderSide(color: active ? _bdr : Colors.transparent),
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$3, size: 16, color: active ? _navy : _ts),
                    const SizedBox(width: 6),
                    Text(
                      t.$2,
                      style: TextStyle(
                        color: active ? _navy : _ts,
                        fontSize: 12,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    if (t.$4 != null && t.$4! > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: active ? _navy : _ts,
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
                    ],
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
  // Post button — moved out of the screen header into the content area,
  // sits above the basic-fields section card (RTL start) so it lives
  // right above the journal-book tab icon, outside the lines table.
  // ─────────────────────────────────────────────────────────────────
  Widget _postButton() {
    if (_submitting) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.black),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _balanced ? _gold : _navy3,
          foregroundColor: _balanced ? core_theme.AC.btnFg : _td,
        ),
        label: const Text('جاري الحفظ...'),
      );
    }
    return FilledButton(
      onPressed: !_balanced ? null : () => _submit(autoPost: true),
      style: FilledButton.styleFrom(
        backgroundColor: _balanced ? _gold : _navy3,
        foregroundColor: _balanced ? core_theme.AC.btnFg : _td,
      ),
      child: const Text('ترحيل'),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Odoo-style chevron status flow — sits at the top of the lines tab
  // on the LEFT (RTL end), opposite the ترحيل button which lives on
  // the right of the same row. Auto-post mode skips the approval steps.
  // ─────────────────────────────────────────────────────────────────
  Widget _statusFlowChevrons() {
    final isCreate = _je == null;
    final currentKey = isCreate
        ? 'draft'
        : (_je!['status']?.toString() ?? 'draft');
    final showApproval = isCreate ? !_autoPost : true;
    final steps = <(String key, String label)>[
      ('draft', 'مسودة'),
      if (showApproval) ('submitted', 'قيد الاعتماد'),
      if (showApproval) ('approved', 'معتمد'),
      ('posted', 'تم الترحيل'),
    ];
    final currentIdx = steps.indexWhere((s) => s.$1 == currentKey);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(steps.length, (i) {
        final isPassed = currentIdx >= 0 && i < currentIdx;
        final isCurrent = i == currentIdx;
        final isFirst = i == 0;
        final isLast = i == steps.length - 1;
        final Color bg;
        final Color fg;
        final FontWeight weight;
        if (isCurrent) {
          bg = _navy;
          fg = Colors.white;
          weight = FontWeight.w800;
        } else if (isPassed) {
          bg = _navy.withValues(alpha: 0.08);
          fg = _navy.withValues(alpha: 0.85);
          weight = FontWeight.w700;
        } else {
          bg = _navy3.withValues(alpha: 0.18);
          fg = _td.withValues(alpha: 0.7);
          weight = FontWeight.w600;
        }
        return ClipPath(
          clipper: _ChevronClipper(isFirst: isFirst, isLast: isLast),
          child: Container(
            margin: EdgeInsetsDirectional.only(start: isFirst ? 0 : -6),
            padding: EdgeInsets.fromLTRB(
                isLast ? 16 : 20, 8, isFirst ? 16 : 20, 8),
            decoration: BoxDecoration(color: bg),
            child: Text(
              steps[i].$2,
              style: TextStyle(
                color: fg,
                fontSize: 11.5,
                fontWeight: weight,
                letterSpacing: 0.1,
              ),
            ),
          ),
        );
      }),
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
    final status = (_je?['status'] as String?) ?? 'draft';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        if (status == 'posted') _postedActionBar(),
        if (status == 'posted') const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _statusFlowChevrons(),
        ),
        const SizedBox(height: 6),
        _sectionCard(
          child: _viewBasicFields(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _localTabsStrip(),
        ),
        _buildBodyContainer(isCreate: false),
        if (_activeView == 'lines') _buildSummaryAndTimelineSection(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Posted-entry inline action bar — sits above everything else on
  // the view screen so the two destructive-ish actions (تعديل + عكس
  // القيد) live on the same horizontal band as the entry-number
  // header. Brand colors: تعديل = navy filled (active intent),
  // عكس القيد = warn outlined (cautionary intent). Both have a
  // subtle scale-on-hover via _ActionPillButton.
  // ─────────────────────────────────────────────────────────────────
  Widget _postedActionBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _ActionPillButton(
            label: 'تعديل',
            icon: Icons.edit_note_rounded,
            background: _navy,
            foreground: Colors.white,
            onPressed: _submitting ? null : _editPostedEntry,
          ),
          const SizedBox(width: 8),
          _ActionPillButton(
            label: 'عكس القيد',
            icon: Icons.history_rounded,
            background: Colors.transparent,
            foreground: _warn,
            border: _warn.withValues(alpha: 0.5),
            onPressed: _submitting ? null : _reversePostedEntry,
          ),
        ],
      ),
    );
  }

  // Copy the posted entry's lines into the editable _lines list and
  // flip into create mode locally — no backend call. The original
  // posted entry stays untouched. The user gets a fresh draft they
  // can edit and post separately. Standard accounting practice is
  // never to mutate posted entries; this is the safe path.
  Future<void> _editPostedEntry() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل قيد مرحَّل',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text(
              'لا يُسمح بتعديل القيود المرحَّلة مباشرة لحماية سلامة دفتر الأستاذ.\n\n'
              'سيتم نسخ بنود هذا القيد إلى مسودة جديدة قابلة للتعديل. القيد الأصلي سيبقى كما هو.\n\n'
              'هل تريد المتابعة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _navy),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    // Hydrate _lines from _jeLines, then reset _je so the screen
    // re-renders in create mode with the data pre-filled.
    final hydrated = <_LineState>[];
    for (final l in _jeLines) {
      final ls = _LineState();
      ls.accountId = l['account_id'] as String?;
      final d = _lineDebit(l);
      final c = _lineCredit(l);
      ls.debit = d;
      ls.credit = c;
      if (d > 0) ls.debitCtrl.text = _fmt(d);
      if (c > 0) ls.creditCtrl.text = _fmt(c);
      ls.description = (l['description_ar'] ??
              l['description'] ??
              '')
          .toString();
      ls.descCtrl.text = ls.description;
      hydrated.add(ls);
    }
    final originalMemo =
        (_je?['memo_ar'] ?? _je?['memo'] ?? '').toString();
    final originalKind = (_je?['kind'] as String?) ?? 'manual';
    setState(() {
      // Dispose current edit lines (probably empty placeholders) and swap.
      for (final l in _lines) {
        l.dispose();
      }
      _lines = hydrated.isNotEmpty
          ? hydrated
          : [_LineState(), _LineState()];
      _memo.text = originalMemo;
      _kind = originalKind;
      // Remember the original so _submit can reverse it before
      // posting the corrected version (atomic edit-in-place).
      _editingPostedJeId = _je?['id'] as String?;
      _editingPostedJeNumber = _je?['je_number'] as String?;
      _je = null; // back to create mode
      _jeLines = [];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _navy,
        duration: const Duration(seconds: 5),
        content: Text(
            'وضع التعديل: عند الترحيل سيتم عكس القيد الأصلي ${_editingPostedJeNumber ?? ""} وإنشاء قيد مُصحَّح'),
      ));
    }
  }

  Future<void> _reversePostedEntry() async {
    final je = _je;
    if (je == null) return;
    final memoCtrl = TextEditingController(
        text: 'عكس قيد ${je['je_number'] ?? ''}');
    DateTime date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Row(children: [
              Icon(Icons.history_rounded, color: _warn, size: 18),
              const SizedBox(width: 8),
              const Text('عكس القيد',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ]),
            content: SizedBox(
              width: 380,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                    'سيتم إنشاء قيد مقابل بنفس المبالغ بعكس الطرفين.',
                    style: TextStyle(color: _td, fontSize: 12)),
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('تاريخ العكس',
                      style: _formLabelStyle),
                ),
                const SizedBox(height: 4),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setSt(() => date = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 11),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _bdr.withValues(alpha: 0.55)),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          color: _ts.withValues(alpha: 0.85),
                          size: 14),
                      const SizedBox(width: 8),
                      Text(_formatDate(date),
                          style: TextStyle(
                              color: _tp,
                              fontSize: 13,
                              fontFamily: 'monospace')),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('سبب العكس',
                      style: _formLabelStyle),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: memoCtrl,
                  style: TextStyle(color: _tp, fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    border: _formFieldBorder,
                    enabledBorder: _formFieldBorder,
                    focusedBorder: _formFieldFocusBorder,
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _warn,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('عكس القيد'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) {
      memoCtrl.dispose();
      return;
    }
    setState(() => _submitting = true);
    final resp = await _client.reverseJournalEntry(je['id'], {
      'reversal_date': _formatDate(date),
      'memo_ar': memoCtrl.text.trim(),
    });
    memoCtrl.dispose();
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: resp.success ? _ok : _err,
      content: Text(resp.success
          ? 'تم إنشاء القيد العكسي ✓'
          : (resp.error ?? 'فشل عكس القيد')),
    ));
    if (resp.success && mounted) {
      Navigator.of(context).maybePop(true);
    }
  }

  Widget _linesViewTableBody() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: _bdr.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          SizedBox(
              width: 30,
              child: Text('#',
                  style: _colHeaderStyle, textAlign: TextAlign.center)),
          Expanded(
              flex: 3, child: Text('الحساب', style: _colHeaderStyle)),
          Expanded(
              flex: 3, child: Text('البيان', style: _colHeaderStyle)),
          SizedBox(
              width: 110,
              child: Text('مدين',
                  style: _colHeaderStyle,
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 110,
              child: Text('دائن',
                  style: _colHeaderStyle,
                  textAlign: TextAlign.center)),
        ]),
      ),
      ..._jeLines.asMap().entries.map((e) {
        final l = e.value;
        final acc = _accounts.firstWhere(
            (a) => a['id'] == l['account_id'],
            orElse: () => {});
        final debit = _lineDebit(l);
        final credit = _lineCredit(l);
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: e.key.isOdd
                ? _navy3.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Row(children: [
            SizedBox(
                width: 30,
                child: Text('${e.key + 1}',
                    style: TextStyle(fontSize: 11, color: _td),
                    textAlign: TextAlign.center)),
            Expanded(
                flex: 3,
                child: Text(
                  acc.isEmpty
                      ? (l['account_id'] ?? '—').toString()
                      : '${acc['code']} — ${acc['name_ar']}',
                  style: const TextStyle(
                      fontFamily: 'monospace', fontSize: 12),
                )),
            Expanded(
                flex: 3,
                child: Text((l['description'] ?? '—').toString(),
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
                    textAlign: TextAlign.center)),
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
                    textAlign: TextAlign.center)),
          ]),
        );
      }),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: _bdr.withValues(alpha: 0.6), width: 1)),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      fontFamily: 'monospace'),
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 110,
              child: Text(_fmt(_totalCredit),
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      fontFamily: 'monospace'),
                  textAlign: TextAlign.center)),
        ]),
      ),
    ]);
  }

  Widget _buildLinesEditTable() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        if (_editingPostedJeId != null) _editingPostedBanner(),
        if (_editingPostedJeId != null) const SizedBox(height: 12),
        if (_aiWarnings.isNotEmpty) _aiWarningsStrip(),
        if (_aiWarnings.isNotEmpty) const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _postButton(),
            const Spacer(),
            _statusFlowChevrons(),
          ],
        ),
        const SizedBox(height: 6),
        _sectionCard(
          child: _createBasicFields(),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _localTabsStrip(),
        ),
        _buildBodyContainer(isCreate: true),
        if (_activeView == 'lines') _buildSummaryAndTimelineSection(),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Body container — sits under the local tabs and swaps content
  // between البنود (lines table) and معلومات أخرى (autopost +
  // internal-note form). Top-left corner stays square so the active
  // tab attaches; the other three corners are rounded.
  // ─────────────────────────────────────────────────────────────────
  Widget _buildBodyContainer({required bool isCreate}) {
    final isOtherInfo = _activeView == 'other_info';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border.all(color: _bdr.withValues(alpha: 0.55)),
      ),
      padding: isOtherInfo ? const EdgeInsets.all(16) : EdgeInsets.zero,
      child: isOtherInfo
          ? _otherInfoBody(isCreate: isCreate)
          : (isCreate ? _linesEditTableBody() : _linesViewTableBody()),
    );
  }

  // Header column-label style — small, muted, slight letter-spacing
  // for a cleaner spreadsheet look without shouting navy3 fills.
  TextStyle get _colHeaderStyle => TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: _td.withValues(alpha: 0.75),
        letterSpacing: 0.3,
      );

  // Spreadsheet-cell InputDecoration — explicitly strips every Material
  // default (filled fill, enabledBorder underline, etc.) so empty cells
  // render as pure text with no surrounding chrome. The colored
  // underline only appears on focus.
  InputDecoration _cellInputDecoration({
    required String hint,
    required Color focusColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
          color: _td.withValues(alpha: 0.5), fontSize: 10),
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: focusColor, width: 1.5),
      ),
    );
  }

  Widget _linesEditTableBody() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: _bdr.withValues(alpha: 0.6))),
        ),
        child: Row(children: [
          SizedBox(
              width: 30,
              child: Text('#',
                  style: _colHeaderStyle, textAlign: TextAlign.center)),
          Expanded(
              flex: 3, child: Text('الحساب', style: _colHeaderStyle)),
          if (_showPartner) ...[
            const SizedBox(width: 8),
            Expanded(
                flex: 2, child: Text('الشريك', style: _colHeaderStyle)),
          ],
          Expanded(
              flex: 3, child: Text('البيان', style: _colHeaderStyle)),
          if (_showCostCenter) ...[
            const SizedBox(width: 8),
            Expanded(
                flex: 2,
                child: Text('التوزيع التحليلي', style: _colHeaderStyle)),
          ],
          if (_showVat) ...[
            const SizedBox(width: 8),
            SizedBox(
                width: 100,
                child:
                    Text('شبكات الضرائب', style: _colHeaderStyle)),
          ],
          SizedBox(
              width: 110,
              child: Text('مدين',
                  style: _colHeaderStyle,
                  textAlign: TextAlign.center)),
          SizedBox(
              width: 110,
              child: Text('دائن',
                  style: _colHeaderStyle,
                  textAlign: TextAlign.center)),
          SizedBox(width: 30, child: _columnSettingsButton()),
        ]),
      ),
      ..._lines
          .asMap()
          .entries
          .map((e) => _lineEditRow(e.key, e.value)),
      _addLineFooterRow(),
      _totalsFooterRow(),
    ]);
  }

  Widget _lineEditRow(int i, _LineState l) {
    final acc = _accounts.firstWhere((a) => a['id'] == l.accountId,
        orElse: () => {});
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: i.isOdd
            ? _navy3.withValues(alpha: 0.18)
            : Colors.transparent,
      ),
      child: Row(children: [
        SizedBox(
            width: 30,
            child: Text('${i + 1}',
                style: TextStyle(fontSize: 11, color: _td),
                textAlign: TextAlign.center)),
        Expanded(
          flex: 3,
          child: _accountAutocomplete(i, l, acc),
        ),
        if (_showPartner) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () async {
                final pick = await showJePartnerPicker(
                  context,
                  currentLabel: l.partnerLabel.isEmpty ? null : l.partnerLabel,
                );
                if (pick == null) return;
                setState(() {
                  l.partnerLabel = pick;
                  l.partnerCtrl.text = pick;
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 9),
                decoration: BoxDecoration(
                  border: Border.all(color: _bdr),
                  borderRadius: BorderRadius.circular(4),
                  color: l.partnerLabel.isEmpty
                      ? Colors.white
                      : _gold.withValues(alpha: 0.05),
                ),
                child: Row(children: [
                  Icon(
                    l.partnerLabel.isEmpty
                        ? Icons.person_add_alt_rounded
                        : Icons.person_rounded,
                    size: 13,
                    color: l.partnerLabel.isEmpty ? _td : _gold,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l.partnerLabel.isEmpty
                          ? 'عميل / مورد / موظف'
                          : l.partnerLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: l.partnerLabel.isEmpty ? _td : _tp,
                          fontSize: 11,
                          fontWeight: l.partnerLabel.isEmpty
                              ? FontWeight.w400
                              : FontWeight.w600),
                    ),
                  ),
                  Icon(Icons.expand_more_rounded, size: 13, color: _td),
                ]),
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
            decoration: _cellInputDecoration(
                hint: 'اختياري', focusColor: _navy),
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
              decoration: _cellInputDecoration(
                  hint: 'مركز تكلفة', focusColor: _navy),
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
              hint: Text('VAT',
                  style: TextStyle(
                      color: _td.withValues(alpha: 0.5), fontSize: 10)),
              style: TextStyle(color: _tp, fontSize: 11),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _navy, width: 1.5),
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
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: false),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              _SingleDotFormatter(),
            ],
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
            onEditingComplete: () {
              if (l.debit > 0) {
                l.debitCtrl.text = l.debit.toStringAsFixed(2);
              }
              FocusScope.of(context).nextFocus();
            },
            style: TextStyle(
                color: l.debit > 0 ? _ok : _td,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0.00',
              hintStyle: TextStyle(
                  color: _td.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontFamily: 'monospace'),
              filled: l.debit > 0,
              fillColor: _ok.withValues(alpha: 0.08),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _ok, width: 1.5),
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 110,
          child: TextField(
            controller: l.creditCtrl,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: false),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              _SingleDotFormatter(),
            ],
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
            onEditingComplete: () {
              if (l.credit > 0) {
                l.creditCtrl.text = l.credit.toStringAsFixed(2);
              }
              FocusScope.of(context).nextFocus();
            },
            style: TextStyle(
                color: l.credit > 0 ? _gold : _td,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace'),
            decoration: InputDecoration(
              isDense: true,
              hintText: '0.00',
              hintStyle: TextStyle(
                  color: _td.withValues(alpha: 0.4),
                  fontSize: 12,
                  fontFamily: 'monospace'),
              filled: l.credit > 0,
              fillColor: _gold.withValues(alpha: 0.08),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: _gold, width: 1.5),
              ),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(
          width: 30,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'حذف',
            icon: Icon(Icons.delete_outline_rounded,
                color: _td.withValues(alpha: 0.55), size: 16),
            hoverColor: Colors.transparent,
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

  // ─────────────────────────────────────────────────────────────────
  // Inline account autocomplete — type-to-search dropdown anchored
  // to the cell. Filters by code OR Arabic name on every keystroke.
  // Empty input shows the first 30 detail accounts so the field still
  // feels useful before typing. Selecting an option commits the
  // accountId and replaces the text with `code — name`.
  // ─────────────────────────────────────────────────────────────────
  Widget _accountAutocomplete(
      int i, _LineState l, Map<String, dynamic> acc) {
    final initial = acc.isEmpty
        ? const TextEditingValue()
        : TextEditingValue(
            text: '${acc['code']} — ${acc['name_ar']}',
            selection: TextSelection.collapsed(
                offset: '${acc['code']} — ${acc['name_ar']}'.length));
    return RawAutocomplete<Map<String, dynamic>>(
      key: ValueKey('acct-${i}-${l.accountId ?? "empty"}'),
      initialValue: initial,
      displayStringForOption: (a) => '${a['code']} — ${a['name_ar']}',
      optionsBuilder: (text) {
        final detail =
            _accounts.where((a) => a['type'] == 'detail');
        final q = text.text.trim().toLowerCase();
        if (q.isEmpty) return detail.take(20);
        return detail.where((a) {
          final code = (a['code'] ?? '').toString().toLowerCase();
          final name = (a['name_ar'] ?? '').toString().toLowerCase();
          return code.contains(q) || name.contains(q);
        });
      },
      onSelected: (a) {
        setState(() => _lines[i].accountId = a['id']);
      },
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmit) {
        // If the user clears the field manually, drop the selection.
        ctrl.addListener(() {
          final txt = ctrl.text;
          if (txt.isEmpty && l.accountId != null) {
            setState(() => _lines[i].accountId = null);
          }
        });
        return TextField(
          controller: ctrl,
          focusNode: focusNode,
          style: TextStyle(
              color: _tp,
              fontSize: 11,
              fontFamily:
                  acc.isEmpty ? null : 'monospace'),
          decoration: InputDecoration(
            hintText: l.aiHint.isNotEmpty
                ? '⚠ ${l.aiHint}'
                : 'اختر حساباً',
            hintStyle: TextStyle(
                color: l.aiHint.isNotEmpty
                    ? _warn
                    : _td.withValues(alpha: 0.55),
                fontSize: 11),
            isDense: true,
            filled: false,
            prefixIcon: Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, end: 4),
              child: Icon(
                acc.isEmpty
                    ? (l.aiHint.isNotEmpty
                        ? Icons.auto_awesome_rounded
                        : Icons.search_rounded)
                    : Icons.check_circle_rounded,
                color: acc.isEmpty
                    ? (l.aiHint.isNotEmpty
                        ? _warn
                        : _td.withValues(alpha: 0.5))
                    : _ok,
                size: 14,
              ),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 22, minHeight: 22),
            contentPadding:
                const EdgeInsets.symmetric(vertical: 10),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _navy, width: 1.5),
            ),
          ),
          onSubmitted: (_) => onSubmit(),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        final list = options.toList();
        // Compute responsive dimensions: width adapts to the cell-
        // width range (240–360); maxHeight adapts to 60% of viewport
        // so very small windows or rows near the page bottom still
        // get a usable dropdown rather than getting clipped.
        final mq = MediaQuery.of(ctx);
        final maxHeight =
            (mq.size.height * 0.6).clamp(160.0, 320.0);
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: LayoutBuilder(builder: (ctx, parentConstraints) {
            final maxWidth = parentConstraints.maxWidth.isFinite
                ? parentConstraints.maxWidth
                : 360.0;
            final width = maxWidth.clamp(240.0, 360.0);
            return Material(
              elevation: 12,
              shadowColor: _navy.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: Container(
                width: width,
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _bdr.withValues(alpha: 0.55)),
                ),
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('لا توجد نتائج',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: _td, fontSize: 11)),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: list.length,
                        separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: _bdr.withValues(alpha: 0.25)),
                        itemBuilder: (ctx, idx) =>
                            _AccountOptionRow(
                          account: list[idx],
                          onTap: () => onSelected(list[idx]),
                          navy: _navy,
                          navy3: _navy3,
                          tp: _tp,
                          td: _td,
                        ),
                      ),
              ),
            );
          }),
        );
      },
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
                Icon(Icons.search_rounded, color: _navy, size: 18),
                const SizedBox(width: 8),
                const Text('اختر حساباً',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ]),
              titlePadding:
                  const EdgeInsets.fromLTRB(20, 18, 20, 8),
              contentPadding:
                  const EdgeInsets.fromLTRB(20, 0, 20, 16),
              content: SizedBox(
                width: 520,
                height: 500,
                child: Column(children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    onChanged: (_) => setSt(() {}),
                    style: TextStyle(color: _tp, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'ابحث بالكود أو الاسم...',
                      hintStyle: TextStyle(
                          color: _td.withValues(alpha: 0.55),
                          fontSize: 12),
                      prefixIcon: Icon(Icons.search_rounded,
                          size: 18,
                          color: _td.withValues(alpha: 0.7)),
                      border: _formFieldBorder,
                      enabledBorder: _formFieldBorder,
                      focusedBorder: _formFieldFocusBorder,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: _bdr.withValues(alpha: 0.35)),
                      itemBuilder: (_, i) {
                        final a = filtered[i];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _navy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(a['code'] ?? '',
                                style: TextStyle(
                                    color: _navy,
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800)),
                          ),
                          title: Text(a['name_ar'] ?? '',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: _tp,
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${a['category']} · ${a['normal_balance']}',
                              style: TextStyle(
                                  color: _td.withValues(alpha: 0.7),
                                  fontSize: 10,
                                  letterSpacing: 0.2)),
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
  Widget _otherInfoBody({required bool isCreate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('الترحيل التلقائي',
              style: TextStyle(
                  color: _tp, fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text(
              'عند الحفظ، يتم ترحيل القيد مباشرة إلى GL Postings.',
              style: TextStyle(color: _ts, fontSize: 11)),
          value: _autoPost,
          activeColor: _gold,
          onChanged:
              isCreate ? (v) => setState(() => _autoPost = v) : null,
        ),
        Divider(color: _bdr.withValues(alpha: 0.35), height: 1),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('للتحقق منه',
              style: TextStyle(
                  color: _tp, fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text(
              'تمييز القيد لمراجعة لاحقة قبل الترحيل.',
              style: TextStyle(color: _ts, fontSize: 11)),
          value: _toCheck,
          activeColor: _navy,
          onChanged:
              isCreate ? (v) => setState(() => _toCheck = v) : null,
        ),
        const SizedBox(height: 16),
        Text('ملاحظة داخلية',
            style: TextStyle(
                color: _td, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _internalNote,
          enabled: isCreate,
          minLines: 2,
          maxLines: 6,
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
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Totals footer — debit total under debit column, credit total under
  // credit column, smart balance assistant on the right. Numbers tween
  // smoothly between values; the balance widget either pulses green
  // when freshly balanced or offers a one-tap "موازنة تلقائية" action
  // that drops in a pre-filled offsetting line when there's a gap.
  // ─────────────────────────────────────────────────────────────────
  Widget _totalsFooterRow() {
    return Column(children: [
      _balanceProgressBar(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
              top: BorderSide(
                  color: _bdr.withValues(alpha: 0.6), width: 1)),
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
              _balanceAssistant(),
            ]),
          ),
          SizedBox(
              width: 110,
              child: _animatedAmount(_totalDebit,
                  align: TextAlign.center)),
          SizedBox(
              width: 110,
              child: _animatedAmount(_totalCredit,
                  align: TextAlign.center)),
          const SizedBox(width: 30),
        ]),
      ),
    ]);
  }

  // Smooth-tween number — animates from the previously-rendered value
  // to the current one over 280ms. TweenAnimationBuilder remembers
  // the prior `end` and tweens from there to the new `end` whenever
  // value changes, so the user sees digits roll up instead of snap.
  Widget _animatedAmount(double value,
      {TextAlign align = TextAlign.center}) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0, end: value),
      builder: (_, v, __) => Text(
        _fmt(v),
        textAlign: align,
        style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _navy,
            fontFamily: 'monospace'),
      ),
    );
  }

  // Thin horizontal bar above the totals row — visualizes how
  // debit and credit relate. When balanced both halves are equal-
  // length green segments meeting at center. When unbalanced the
  // larger side extends and a subtle gap shows the deficit.
  Widget _balanceProgressBar() {
    final total = _totalDebit + _totalCredit;
    final debitPct =
        total <= 0 ? 0.5 : (_totalDebit / total).clamp(0.0, 1.0);
    final creditPct = 1.0 - debitPct;
    final isBalanced = _balanced && total > 0;
    final restingColor = isBalanced
        ? _ok.withValues(alpha: 0.55)
        : _navy3.withValues(alpha: 0.5);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Row(children: [
          Expanded(
            flex: (debitPct * 1000).round().clamp(1, 1000),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              color: total <= 0
                  ? _bdr.withValues(alpha: 0.4)
                  : (isBalanced
                      ? restingColor
                      : _ok.withValues(alpha: 0.5)),
            ),
          ),
          if (!isBalanced && total > 0)
            const SizedBox(width: 2),
          Expanded(
            flex: (creditPct * 1000).round().clamp(1, 1000),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              color: total <= 0
                  ? _bdr.withValues(alpha: 0.4)
                  : (isBalanced
                      ? restingColor
                      : _gold.withValues(alpha: 0.5)),
            ),
          ),
        ]),
      ),
    );
  }

  // Smart balance widget — replaces the static chip. Two states:
  //  • balanced  → soft green chip with a celebratory pulse
  //  • imbalanced → outlined chip showing the gap + one-tap action
  //    that drops in a pre-filled offsetting line. The user just
  //    picks the account and the entry self-completes.
  Widget _balanceAssistant() {
    final diff = (_totalDebit - _totalCredit).abs();
    if (_balanced && (_totalDebit + _totalCredit) > 0) {
      return TweenAnimationBuilder<double>(
        // Pulse once whenever the balanced state mounts/refreshes.
        key: ValueKey('balanced-${_totalDebit.toStringAsFixed(2)}'),
        tween: Tween(begin: 0.85, end: 1.0),
        duration: const Duration(milliseconds: 360),
        curve: Curves.elasticOut,
        builder: (_, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _ok.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: _ok.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle, color: _ok, size: 12),
            const SizedBox(width: 4),
            Text('متوازن',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _ok)),
          ]),
        ),
      );
    }
    if ((_totalDebit + _totalCredit) <= 0) {
      // No data yet — neutral muted hint, no action.
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _navy3.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('في الانتظار',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _td.withValues(alpha: 0.7))),
      );
    }
    // Imbalanced — show the gap + one-tap auto-balance action.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _autoBalance(),
        borderRadius: BorderRadius.circular(10),
        hoverColor: _warn.withValues(alpha: 0.08),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _warn.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _warn.withValues(alpha: 0.4)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.balance_rounded, color: _warn, size: 12),
            const SizedBox(width: 4),
            Text('فرق ${_fmt(diff)}',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _warn)),
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 10,
              color: _warn.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 6),
            Text('موازنة تلقائية',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _navy)),
          ]),
        ),
      ),
    );
  }

  // Drop in a new line with the offsetting amount pre-filled on the
  // side that's short. The user only needs to pick the account.
  void _autoBalance() {
    final diff = _totalDebit - _totalCredit; // + → credit short, − → debit short
    if (diff.abs() < 0.005) return;
    final newLine = _LineState();
    if (diff > 0) {
      newLine.credit = diff;
      newLine.creditCtrl.text = _fmt(diff);
    } else {
      newLine.debit = -diff;
      newLine.debitCtrl.text = _fmt(-diff);
    }
    setState(() => _lines.add(newLine));
  }

  Widget _balanceChip() {
    // Kept for view-mode totals row (read-only) — shorter version
    // without the auto-balance affordance.
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(Icons.add_rounded, size: 14, color: _navy),
          const SizedBox(width: 6),
          Text('إضافة بند',
              style: TextStyle(
                  color: _navy,
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

// Chevron shape for the Odoo-style status flow strip. The pill points
// in the LTR-positive direction (right) and notches on its left to
// receive the previous chevron's tip. In RTL (this app's default), the
// visual flow reads right-to-left so the rightmost pill is the first
// status and each tip points toward the next status on its left.
class _ChevronClipper extends CustomClipper<Path> {
  final bool isFirst;
  final bool isLast;
  static const double _tip = 8;

  const _ChevronClipper({required this.isFirst, required this.isLast});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();
    // Top-left
    path.moveTo(0, 0);
    // Top edge to top-right
    path.lineTo(w - (isLast ? 0 : _tip), 0);
    // Right edge — tip out (or flat for last)
    if (!isLast) path.lineTo(w, h / 2);
    path.lineTo(w - (isLast ? 0 : _tip), h);
    // Bottom edge to bottom-left
    path.lineTo(0, h);
    // Left edge — notch in (or flat for first)
    if (!isFirst) {
      path.lineTo(_tip, h / 2);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _ChevronClipper old) =>
      old.isFirst != isFirst || old.isLast != isLast;
}

// ─────────────────────────────────────────────────────────────────────
// Brand-styled action pill — used by the posted-entry inline action
// bar (تعديل + عكس القيد). Tracks its own hover state so the surface
// brightens slightly + the icon nudges by 2px on hover. Disabled state
// dims the foreground and drops the cursor affordance.
// ─────────────────────────────────────────────────────────────────────
class _ActionPillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback? onPressed;

  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    this.border,
    required this.onPressed,
  });

  @override
  State<_ActionPillButton> createState() => _ActionPillButtonState();
}

class _ActionPillButtonState extends State<_ActionPillButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final isFilled = widget.background != Colors.transparent;
    final hoverBg = isFilled
        ? Color.lerp(widget.background, Colors.black, 0.08) ??
            widget.background
        : widget.foreground.withValues(alpha: 0.08);
    return MouseRegion(
      cursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (enabled) setState(() => _hover = true);
      },
      onExit: (_) {
        if (enabled) setState(() => _hover = false);
      },
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: !enabled
                ? widget.background.withValues(alpha: 0.4)
                : (_hover ? hoverBg : widget.background),
            borderRadius: BorderRadius.circular(8),
            border: widget.border != null
                ? Border.all(
                    color: _hover
                        ? widget.foreground.withValues(alpha: 0.7)
                        : widget.border!,
                    width: 1.2)
                : null,
            boxShadow: isFilled && _hover && enabled
                ? [
                    BoxShadow(
                      color: widget.background.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSlide(
                duration: const Duration(milliseconds: 140),
                offset:
                    _hover && enabled ? const Offset(-0.08, 0) : Offset.zero,
                child: Icon(widget.icon,
                    color: widget.foreground.withValues(
                        alpha: enabled ? 1 : 0.5),
                    size: 16),
              ),
              const SizedBox(width: 6),
              Text(widget.label,
                  style: TextStyle(
                      color: widget.foreground.withValues(
                          alpha: enabled ? 1 : 0.5),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// One option row inside the account autocomplete dropdown. Lives as
// its own StatefulWidget so each row tracks its own hover state and
// can render a clear navy-tinted highlight + a thin trailing accent
// bar that animates in. Replaces the bare InkWell hoverColor which
// was too subtle to read at a glance.
// ─────────────────────────────────────────────────────────────────────
class _AccountOptionRow extends StatefulWidget {
  final Map<String, dynamic> account;
  final VoidCallback onTap;
  final Color navy;
  final Color navy3;
  final Color tp;
  final Color td;

  const _AccountOptionRow({
    required this.account,
    required this.onTap,
    required this.navy,
    required this.navy3,
    required this.tp,
    required this.td,
  });

  @override
  State<_AccountOptionRow> createState() => _AccountOptionRowState();
}

class _AccountOptionRowState extends State<_AccountOptionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hover
                ? widget.navy3.withValues(alpha: 0.45)
                : Colors.transparent,
            border: Border(
              right: BorderSide(
                color: _hover ? widget.navy : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 5),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: _hover
                    ? widget.navy.withValues(alpha: 0.18)
                    : widget.navy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(a['code'] ?? '',
                  style: TextStyle(
                      color: widget.navy,
                      fontFamily: 'monospace',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(a['name_ar'] ?? '',
                  style: TextStyle(
                      fontSize: 11.5,
                      color: widget.tp,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 6),
            Text('${a['category']} · ${a['normal_balance']}',
                style: TextStyle(
                    color:
                        widget.td.withValues(alpha: 0.55),
                    fontSize: 8.5,
                    letterSpacing: 0.2)),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Compact, brand-styled date popover — anchored under the date field,
// dismisses on outside-tap, fades + slides in. ~280 px wide, designed
// to feel like a Notion / Linear inline picker rather than a Material
// modal. Quick-pick chips (اليوم / أمس / بداية الشهر) cover the most
// common JE dates in one tap.
// ─────────────────────────────────────────────────────────────────────
class _DatePopover extends StatefulWidget {
  final Offset anchorTopLeft;
  final Size anchorSize;
  final Size overlaySize;
  final DateTime initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final Color navy;
  final Color gold;
  final Color navy3;
  final Color bdr;
  final Color td;
  final Color ts;
  final Color tp;
  final ValueChanged<DateTime?> onPicked;

  const _DatePopover({
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.overlaySize,
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.navy,
    required this.gold,
    required this.navy3,
    required this.bdr,
    required this.td,
    required this.ts,
    required this.tp,
    required this.onPicked,
  });

  @override
  State<_DatePopover> createState() => _DatePopoverState();
}

class _DatePopoverState extends State<_DatePopover>
    with SingleTickerProviderStateMixin {
  late DateTime _viewMonth; // first day of the displayed month
  late DateTime _selected;
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const _arMonths = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  // Saturday-first week (matches the Material picker the user just saw).
  static const _arDayNames = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _viewMonth = DateTime(widget.initial.year, widget.initial.month, 1);
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
            begin: const Offset(0, -0.04), end: Offset.zero)
        .animate(_fade);
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _close([DateTime? d]) async {
    await _anim.reverse();
    if (mounted) widget.onPicked(d);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _viewMonth =
          DateTime(_viewMonth.year, _viewMonth.month + delta, 1);
    });
  }

  bool _inRange(DateTime d) =>
      !d.isBefore(DateTime(widget.firstDate.year, widget.firstDate.month,
          widget.firstDate.day)) &&
      !d.isAfter(DateTime(
          widget.lastDate.year, widget.lastDate.month, widget.lastDate.day));

  @override
  Widget build(BuildContext context) {
    const popWidth = 290.0;
    const popHeight = 348.0;
    // Position popover under the field; flip above if it would overflow.
    final spaceBelow = widget.overlaySize.height -
        (widget.anchorTopLeft.dy + widget.anchorSize.height);
    final placeAbove = spaceBelow < popHeight + 16 &&
        widget.anchorTopLeft.dy > popHeight + 16;
    final top = placeAbove
        ? widget.anchorTopLeft.dy - popHeight - 6
        : widget.anchorTopLeft.dy + widget.anchorSize.height + 6;
    // Right-align to the field (RTL layout) but clamp to viewport.
    var left = widget.anchorTopLeft.dx +
        widget.anchorSize.width -
        popWidth;
    left = left.clamp(8.0, widget.overlaySize.width - popWidth - 8);

    return Stack(children: [
      // Tap-outside barrier — fully transparent, just captures hits.
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _close(),
          child: const SizedBox.expand(),
        ),
      ),
      Positioned(
        top: top,
        left: left,
        width: popWidth,
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Material(
              elevation: 16,
              shadowColor: widget.navy.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: widget.bdr.withValues(alpha: 0.55)),
                ),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 10),
                      _buildQuickChips(),
                      const SizedBox(height: 10),
                      _buildWeekdayRow(),
                      const SizedBox(height: 4),
                      _buildGrid(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildHeader() {
    return Row(children: [
      _navIcon(Icons.chevron_right_rounded,
          tooltip: 'الشهر السابق', onTap: () => _shiftMonth(-1)),
      Expanded(
        child: Center(
          child: Text(
            '${_arMonths[_viewMonth.month - 1]} ${_viewMonth.year}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: widget.navy,
            ),
          ),
        ),
      ),
      _navIcon(Icons.chevron_left_rounded,
          tooltip: 'الشهر التالي', onTap: () => _shiftMonth(1)),
    ]);
  }

  Widget _navIcon(IconData icon,
      {required String tooltip, required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 18, color: widget.ts),
        ),
      ),
    );
  }

  Widget _buildQuickChips() {
    final today = DateTime.now();
    final yest = today.subtract(const Duration(days: 1));
    final monthStart = DateTime(today.year, today.month, 1);
    return Row(children: [
      _quickChip('اليوم', today),
      const SizedBox(width: 6),
      _quickChip('أمس', yest),
      const SizedBox(width: 6),
      _quickChip('بداية الشهر', monthStart),
    ]);
  }

  Widget _quickChip(String label, DateTime date) {
    final enabled = _inRange(date);
    return Expanded(
      child: InkWell(
        onTap: enabled
            ? () {
                setState(() {
                  _selected = date;
                  _viewMonth = DateTime(date.year, date.month, 1);
                });
                _close(date);
              }
            : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: enabled
                ? widget.navy3.withValues(alpha: 0.18)
                : widget.navy3.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: enabled
                  ? widget.tp
                  : widget.td.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeekdayRow() {
    return Row(
      children: _arDayNames
          .map((d) => Expanded(
                child: SizedBox(
                  height: 22,
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: widget.td.withValues(alpha: 0.6),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildGrid() {
    // Build the 6×7 grid for the displayed month, Saturday-first.
    final firstOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    // Dart weekday: Mon=1..Sun=7. Saturday=6, so offset (weekday-6) mod 7.
    final leading = (firstOfMonth.weekday - DateTime.saturday + 7) % 7;
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final today = DateTime.now();
    final cells = <Widget>[];
    for (var i = 0; i < 42; i++) {
      final dayNum = i - leading + 1;
      if (dayNum < 1 || dayNum > daysInMonth) {
        cells.add(const SizedBox(height: 32));
      } else {
        final date =
            DateTime(_viewMonth.year, _viewMonth.month, dayNum);
        final isSelected = _selected.year == date.year &&
            _selected.month == date.month &&
            _selected.day == date.day;
        final isToday = today.year == date.year &&
            today.month == date.month &&
            today.day == date.day;
        final inRange = _inRange(date);
        cells.add(_buildDayCell(date, dayNum, isSelected, isToday, inRange));
      }
    }
    return Column(
      children: List.generate(6, (rowIdx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: List.generate(7, (colIdx) {
              return Expanded(child: cells[rowIdx * 7 + colIdx]);
            }),
          ),
        );
      }),
    );
  }

  Widget _buildDayCell(
      DateTime date, int dayNum, bool isSelected, bool isToday, bool inRange) {
    final bg = isSelected
        ? widget.navy
        : (isToday
            ? widget.gold.withValues(alpha: 0.12)
            : Colors.transparent);
    final fg = isSelected
        ? Colors.white
        : (isToday
            ? widget.navy
            : (inRange
                ? widget.tp
                : widget.td.withValues(alpha: 0.35)));
    final border = isToday && !isSelected
        ? Border.all(color: widget.gold.withValues(alpha: 0.5), width: 1)
        : null;
    return InkWell(
      onTap: inRange ? () => _close(date) : null,
      borderRadius: BorderRadius.circular(6),
      hoverColor: widget.navy3.withValues(alpha: 0.3),
      child: Container(
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: border,
        ),
        alignment: Alignment.center,
        child: Text(
          '$dayNum',
          style: TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: isSelected
                ? FontWeight.w800
                : (isToday ? FontWeight.w700 : FontWeight.w500),
            color: fg,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// _SingleDotFormatter — keeps decimal inputs clean by rejecting more than
// one '.' character. Pairs with FilteringTextInputFormatter on the
// debit/credit fields.
// ─────────────────────────────────────────────────────────────────────────
class _SingleDotFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final dots = '.'.allMatches(newValue.text).length;
    if (dots > 1) return oldValue;
    return newValue;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Partner picker — opens a tabbed bottom sheet that lets the user choose a
// partner across three populations: Customers, Vendors, Employees. Mocked
// catalog so the picker works standalone; swap in real lookups when the
// list endpoints are wired.
// ─────────────────────────────────────────────────────────────────────────

class _PartnerOption {
  final String label;
  final String? subtitle;
  const _PartnerOption(this.label, [this.subtitle]);
}

const Map<String, List<_PartnerOption>> _kPartnerCatalog = {
  'عملاء': [
    _PartnerOption('شركة المعرفة المتقدمة', 'CUS-001 · الرياض'),
    _PartnerOption('مؤسسة الجودة الذهبية', 'CUS-002 · جدة'),
    _PartnerOption('مجموعة الإبداع التجارية', 'CUS-003 · الدمام'),
    _PartnerOption('شركة المستقبل للأنظمة', 'CUS-004 · الرياض'),
    _PartnerOption('عميل نقدي', 'CUS-Walk-in'),
  ],
  'موردون': [
    _PartnerOption('Amazon Web Services', 'VEN-101 · USD'),
    _PartnerOption('شركة تقنية المعدات', 'VEN-102 · ر.س'),
    _PartnerOption('مكتب المحاسب القانوني', 'VEN-103 · ر.س'),
    _PartnerOption('شركة الإمداد للوازم', 'VEN-104 · ر.س'),
    _PartnerOption('مزوّد الانترنت', 'VEN-105 · ر.س'),
  ],
  'موظفون': [
    _PartnerOption('أحمد العمري', 'EMP-001 · المالية'),
    _PartnerOption('سارة الحارثي', 'EMP-002 · المبيعات'),
    _PartnerOption('محمد الزهراني', 'EMP-003 · العمليات'),
    _PartnerOption('فاطمة العتيبي', 'EMP-004 · الموارد البشرية'),
    _PartnerOption('خالد القحطاني', 'EMP-005 · IT'),
  ],
};

/// Opens the partner picker and returns the selected label (or null on
/// dismiss). Public-API safe — hides the private [_PartnerOption] type by
/// only surfacing its display label.
Future<String?> showJePartnerPicker(BuildContext context,
    {String? currentLabel}) async {
  final pick = await showModalBottomSheet<_PartnerOption>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: _PartnerPickerSheet(currentLabel: currentLabel),
    ),
  );
  return pick?.label;
}

class _PartnerPickerSheet extends StatefulWidget {
  final String? currentLabel;
  const _PartnerPickerSheet({this.currentLabel});

  @override
  State<_PartnerPickerSheet> createState() => _PartnerPickerSheetState();
}

class _PartnerPickerSheetState extends State<_PartnerPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _kPartnerCatalog.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctl) => Container(
        decoration: BoxDecoration(
          color: core_theme.AC.navy2,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: core_theme.AC.bdr),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: core_theme.AC.navy4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(children: [
              Icon(Icons.handshake_rounded,
                  color: core_theme.AC.gold, size: 20),
              const SizedBox(width: 10),
              Text('اختر الشريك',
                  style: TextStyle(
                      color: core_theme.AC.tp,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, color: core_theme.AC.ts),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _searchCtl,
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim()),
              style: TextStyle(color: core_theme.AC.tp, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم الكود…',
                hintStyle: TextStyle(color: core_theme.AC.ts, fontSize: 12),
                isDense: true,
                filled: true,
                fillColor: core_theme.AC.navy3,
                prefixIcon: Icon(Icons.search_rounded,
                    color: core_theme.AC.ts, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabs,
            isScrollable: false,
            labelColor: core_theme.AC.gold,
            unselectedLabelColor: core_theme.AC.ts,
            indicatorColor: core_theme.AC.gold,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800),
            unselectedLabelStyle: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w500),
            tabs: [
              for (final group in _kPartnerCatalog.keys) Tab(text: group),
            ],
          ),
          Divider(height: 1, color: core_theme.AC.bdr),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final entry in _kPartnerCatalog.entries)
                  _buildList(entry.value, scroll: ctl),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildList(List<_PartnerOption> items,
      {required ScrollController scroll}) {
    final q = _q.toLowerCase();
    final filtered = q.isEmpty
        ? items
        : items
            .where((it) =>
                it.label.toLowerCase().contains(q) ||
                (it.subtitle?.toLowerCase().contains(q) ?? false))
            .toList();
    if (filtered.isEmpty) {
      return Center(
        child: Text('لا توجد نتائج',
            style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      );
    }
    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) {
        final it = filtered[i];
        final isCurrent = it.label == widget.currentLabel;
        return InkWell(
          onTap: () => Navigator.pop(context, it),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isCurrent
                  ? core_theme.AC.gold.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isCurrent
                  ? Border.all(
                      color: core_theme.AC.gold.withValues(alpha: 0.40),
                      width: 1)
                  : null,
            ),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: core_theme.AC.gold.withValues(alpha: 0.16),
                child: Text(
                  it.label.characters.first,
                  style: TextStyle(
                      color: core_theme.AC.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.label,
                          style: TextStyle(
                              color: core_theme.AC.tp,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      if (it.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(it.subtitle!,
                            style: TextStyle(
                                color: core_theme.AC.ts, fontSize: 11)),
                      ],
                    ]),
              ),
              if (isCurrent)
                Icon(Icons.check_circle_rounded,
                    color: core_theme.AC.gold, size: 18),
            ]),
          ),
        );
      },
    );
  }
}
