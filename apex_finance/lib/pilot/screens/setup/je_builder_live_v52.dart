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
  // Default ON — accountants asked for the partner / cost-center / VAT
  // columns to be visible from the first interaction so they do not have
  // to discover the column-settings popup. Toggle still available there.
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
      // CREATE mode
      return [
        _aiReadDocButton(),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.replay_rounded, size: 20),
          color: _ts,
          tooltip: 'إلغاء (إهمال)',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _submitting ? null : () => _submit(autoPost: false),
          icon: const Icon(Icons.save_outlined, size: 20),
          color: _tp,
          tooltip: 'حفظ كمسودة',
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
  // Icon-only: AI sparkle icon on a violet circular background.
  Widget _aiReadDocButton() {
    final hasDoc = _aiDocFilename != null;
    final tooltip = hasDoc
        ? 'قُرئ من: $_aiDocFilename · ثقة ${((_aiDocConfidence ?? 0) * 100).toStringAsFixed(0)}% — اضغط لإعادة القراءة'
        : 'قراءة مستند بالذكاء الاصطناعي — ارفع فاتورة / إيصال / PDF';
    return Tooltip(
      message: tooltip,
      child: IconButton(
        style: IconButton.styleFrom(
          backgroundColor: _purple,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(10),
        ),
        onPressed: _aiDocLoading ? null : _aiReadDocument,
        icon: _aiDocLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 20),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
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

  Widget _linesViewTableBody() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: _bdr.withValues(alpha: 0.5))),
          ),
          child: Row(children: [
            SizedBox(width: 30, child: Text('${e.key + 1}')),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    ]);
  }

  Widget _buildLinesEditTable() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
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
        border: Border.all(color: _bdr),
      ),
      padding: isOtherInfo ? const EdgeInsets.all(16) : EdgeInsets.zero,
      child: isOtherInfo
          ? _otherInfoBody(isCreate: isCreate)
          : (isCreate ? _linesEditTableBody() : _linesViewTableBody()),
    );
  }

  Widget _linesEditTableBody() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    ]);
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
                    color:
                        l.partnerLabel.isEmpty ? _td : _gold,
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
                  Icon(Icons.expand_more_rounded,
                      size: 13, color: _td),
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
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: false),
            // Allow only digits + a single decimal point. Reject letters,
            // commas (UI shows English digits), or a second dot.
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
            // When the user leaves the field, render the value with 2
            // decimal places so amounts always read like 1,200.00.
            onEditingComplete: () {
              if (l.debit > 0) {
                l.debitCtrl.text = l.debit.toStringAsFixed(2);
              }
              FocusScope.of(context).nextFocus();
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
              hintText: '0.00',
              hintStyle: TextStyle(color: _td, fontSize: 11),
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
              hintText: '0.00',
              hintStyle: TextStyle(color: _td, fontSize: 11),
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
  Widget _otherInfoBody({required bool isCreate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
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
        Divider(color: _bdr.withValues(alpha: 0.5)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('للتحقق منه',
              style: TextStyle(
                  color: _tp, fontSize: 13, fontWeight: FontWeight.w700)),
          subtitle: Text(
              'تمييز القيد لمراجعة لاحقة قبل الترحيل.',
              style: TextStyle(color: _ts, fontSize: 11)),
          value: _toCheck,
          activeColor: _warn,
          onChanged:
              isCreate ? (v) => setState(() => _toCheck = v) : null,
        ),
        Divider(color: _bdr.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text('ملاحظة داخلية',
            style: TextStyle(
                color: _td, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: _internalNote,
          enabled: isCreate,
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
          Text('إضافة بند',
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

// ─────────────────────────────────────────────────────────────────────────
// _SingleDotFormatter — keeps decimal inputs clean by rejecting any input
// that contains more than one '.' character. Pairs with FilteringTextInput
// Formatter(allow digits + dot) on the debit/credit fields.
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
// Partner picker — opens a tabbed bottom sheet that lets the user choose
// a partner across three populations: Customers, Vendors, Employees. The
// data is mocked here so the picker works without backend wiring; swap in
// real lookups once the customer / vendor / employee endpoints expose a
// list method that returns names + ids.
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
/// dismiss). Public-API safe: hides the private [_PartnerOption] type by
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
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: core_theme.AC.navy4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
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
          // Search
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
          // Tabs
          TabBar(
            controller: _tabs,
            isScrollable: false,
            labelColor: core_theme.AC.gold,
            unselectedLabelColor: core_theme.AC.ts,
            indicatorColor: core_theme.AC.gold,
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            unselectedLabelStyle:
                const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            tabs: [
              for (final group in _kPartnerCatalog.keys) Tab(text: group),
            ],
          ),
          Divider(height: 1, color: core_theme.AC.bdr),
          // Lists
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

  Widget _buildList(List<_PartnerOption> items, {required ScrollController scroll}) {
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
            margin:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                backgroundColor:
                    core_theme.AC.gold.withValues(alpha: 0.16),
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
                                color: core_theme.AC.ts,
                                fontSize: 11)),
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
