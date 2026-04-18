/// APEX V4 ERP / Treasury — AI Bank Reconciliation screen (Wave 16).
///
/// UI for the Wave 15 backend (/bank-rec/propose + /bank-rec/auto-match).
///
/// Flow:
/// 1. Left pane: unreconciled bank_feed transactions from Wave 13.
/// 2. User selects one bank_tx.
/// 3. Right pane: candidate builder — user adds 1..N candidates
///    (id/amount/date/vendor/description). In a future wave this is
///    replaced by a picker over the journal-entry / invoice tables.
/// 4. Two actions:
///      "اقترح" → POST /bank-rec/propose; shows ranked proposals with
///                score badge + per-feature breakdown.
///      "طابق تلقائياً" → POST /bank-rec/auto-match; top proposal goes
///                through ai_guardrails.guard(). Verdict pill shows
///                AUTO_APPLIED / NEEDS_APPROVAL / REJECTED; a
///                NEEDS_APPROVAL row includes a "راجعها" chip linking
///                to the AI Guardrails screen.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/v4/apex_screen_host.dart';

class BankReconciliationScreen extends StatefulWidget {
  const BankReconciliationScreen({super.key});

  @override
  State<BankReconciliationScreen> createState() =>
      _BankReconciliationScreenState();
}

class _BankReconciliationScreenState extends State<BankReconciliationScreen> {
  ApexScreenState _state = ApexScreenState.loading;
  String? _errorDetail;

  List<Map<String, dynamic>> _unreconciled = const [];
  String? _selectedTxnId;
  final List<_Candidate> _candidates = [_Candidate.empty()];
  List<Map<String, dynamic>> _proposals = const [];
  Map<String, dynamic>? _autoMatchResult;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _candidates) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state = ApexScreenState.loading;
      _errorDetail = null;
    });
    try {
      final res = await ApiService.bankFeedsTransactions(
        unreconciledOnly: true,
        limit: 200,
      );
      if (!res.success) {
        setState(() {
          _state = ApexScreenState.error;
          _errorDetail = res.error ?? 'تعذّر تحميل الحركات.';
        });
        return;
      }
      final rows = (_unwrap(res.data)['rows'] as List? ?? const [])
          .cast<Map>()
          .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
          .toList();
      setState(() {
        _unreconciled = rows;
        _state = rows.isEmpty
            ? ApexScreenState.emptyFirstTime
            : ApexScreenState.ready;
      });
    } catch (e) {
      setState(() {
        _state = ApexScreenState.error;
        _errorDetail = e.toString();
      });
    }
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) return Map<String, dynamic>.from(data);
    return const {};
  }

  Map<String, dynamic>? _selectedTxn() {
    if (_selectedTxnId == null) return null;
    for (final r in _unreconciled) {
      if (r['id']?.toString() == _selectedTxnId) return r;
    }
    return null;
  }

  void _selectTxn(String id) {
    setState(() {
      _selectedTxnId = id;
      _proposals = const [];
      _autoMatchResult = null;
    });
  }

  void _addCandidate() => setState(() => _candidates.add(_Candidate.empty()));

  void _removeCandidate(int i) {
    if (_candidates.length <= 1) return;
    final removed = _candidates.removeAt(i);
    removed.dispose();
    setState(() {});
  }

  List<Map<String, dynamic>> _buildCandidatePayload() {
    return _candidates
        .where((c) => c.hasAny)
        .map((c) => c.toMap())
        .toList();
  }

  Map<String, dynamic>? _buildBankTxPayload() {
    final txn = _selectedTxn();
    if (txn == null) return null;
    return {
      'id': txn['id'],
      'amount': txn['amount'],
      'date': (txn['txn_date']?.toString() ?? '').split('T').first,
      'vendor': txn['counterparty'],
      'description': txn['description'],
    };
  }

  Future<void> _propose() async {
    final bankTx = _buildBankTxPayload();
    if (bankTx == null) {
      _toast('اختر حركة بنكية أولاً.', AC.warn);
      return;
    }
    final cands = _buildCandidatePayload();
    if (cands.isEmpty) {
      _toast('أضِف مرشحًا واحدًا على الأقل.', AC.warn);
      return;
    }
    setState(() {
      _running = true;
      _autoMatchResult = null;
    });
    final res = await ApiService.bankRecPropose({
      'bank_tx': bankTx,
      'candidates': cands,
      'min_score': 0.0,  // UI shows everything; score badges clarify.
      'top_k': 10,
    });
    if (!mounted) return;
    setState(() {
      _running = false;
      if (!res.success) {
        _toast(res.error ?? 'تعذّر تقييم المرشحين.', AC.err);
        _proposals = const [];
        return;
      }
      final data = _unwrap(res.data);
      _proposals = (data['proposals'] as List? ?? const [])
          .cast<Map>()
          .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
          .toList();
    });
  }

  Future<void> _autoMatch() async {
    final bankTx = _buildBankTxPayload();
    if (bankTx == null) {
      _toast('اختر حركة بنكية أولاً.', AC.warn);
      return;
    }
    final cands = _buildCandidatePayload();
    if (cands.isEmpty) {
      _toast('أضِف مرشحًا واحدًا على الأقل.', AC.warn);
      return;
    }
    setState(() {
      _running = true;
      _autoMatchResult = null;
    });
    final res = await ApiService.bankRecAutoMatch({
      'bank_tx': bankTx,
      'candidates': cands,
      'bank_tx_id': _selectedTxnId,
      'entity_type': 'journal_entry',
    });
    if (!mounted) return;
    setState(() {
      _running = false;
      if (!res.success) {
        _toast(res.error ?? 'تعذّرت المطابقة التلقائية.', AC.err);
        return;
      }
      _autoMatchResult = _unwrap(res.data);
    });

    final verdict = _autoMatchResult?['verdict']?.toString();
    if (verdict == 'auto_applied') {
      _toast('تمت المطابقة التلقائية ✅', AC.ok);
      // Row is now reconciled in the DB — refresh the left pane.
      _load();
    } else if (verdict == 'needs_approval') {
      _toast('تحتاج مراجعة بشرية — انتقل لقائمة ضوابط الذكاء.', AC.warn);
    } else if (verdict == 'rejected') {
      _toast('رفض الضابط الاقتراح.', AC.err);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_state == ApexScreenState.loading ||
        _state == ApexScreenState.error) {
      return ApexScreenHost(
        state: _state,
        errorDetail: _errorDetail,
        primaryAction: _state == ApexScreenState.error
            ? FilledButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة'),
              )
            : null,
      );
    }

    if (_state == ApexScreenState.emptyFirstTime) {
      return ApexScreenHost(
        state: ApexScreenState.emptyFirstTime,
        title: 'لا توجد حركات بنكية غير مطابقة',
        description:
            'اسحب معاملات من حساب بنكي مربوط في شاشة "الحركات" ثم ارجع هنا '
            'لاقتراح المطابقة أو التشغيل التلقائي عبر ضابط الذكاء.',
      );
    }

    return LayoutBuilder(
      builder: (ctx, c) {
        final wide = c.maxWidth >= 900;
        final left = _TxnList(
          rows: _unreconciled,
          selectedId: _selectedTxnId,
          onSelect: _selectTxn,
        );
        final right = _RightPane(
          selectedTxn: _selectedTxn(),
          candidates: _candidates,
          onAdd: _addCandidate,
          onRemove: _removeCandidate,
          onPropose: _running ? null : _propose,
          onAutoMatch: _running ? null : _autoMatch,
          running: _running,
          proposals: _proposals,
          autoMatchResult: _autoMatchResult,
        );

        if (!wide) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 280, child: left),
                const Divider(height: 1, thickness: 1),
                right,
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 380, child: left),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

// ── Left pane: unreconciled transactions list ─────────────────────────

class _TxnList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  const _TxnList({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AC.navy,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AC.navy2,
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: AC.gold, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'حركات غير مطابقة (${rows.length})',
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: AC.navy3.withValues(alpha: 0.5)),
              itemBuilder: (ctx, i) {
                final row = rows[i];
                final id = row['id']?.toString() ?? '';
                final isCredit = row['direction']?.toString() == 'credit';
                final color = isCredit ? AC.ok : AC.warn;
                final amount = row['amount']?.toString() ?? '0';
                final currency = row['currency']?.toString() ?? 'SAR';
                final desc = row['description']?.toString() ?? '—';
                final cp = row['counterparty']?.toString() ?? '';
                final date =
                    (row['txn_date']?.toString() ?? '').split('T').first;
                final selected = selectedId == id;

                return InkWell(
                  onTap: () => onSelect(id),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    color: selected
                        ? AC.gold.withValues(alpha: 0.12)
                        : Colors.transparent,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          color: color,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                desc,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AC.tp,
                                  fontSize: AppFontSize.sm,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (cp.isNotEmpty)
                                Text(
                                  cp,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AC.ts,
                                    fontSize: AppFontSize.xs,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  date,
                                  style: TextStyle(
                                    color: AC.ts,
                                    fontSize: AppFontSize.xs,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${isCredit ? "+" : "−"}$amount $currency',
                          style: TextStyle(
                            color: color,
                            fontSize: AppFontSize.sm,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Right pane: candidate builder + results ───────────────────────────

class _RightPane extends StatelessWidget {
  final Map<String, dynamic>? selectedTxn;
  final List<_Candidate> candidates;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final VoidCallback? onPropose;
  final VoidCallback? onAutoMatch;
  final bool running;
  final List<Map<String, dynamic>> proposals;
  final Map<String, dynamic>? autoMatchResult;

  const _RightPane({
    required this.selectedTxn,
    required this.candidates,
    required this.onAdd,
    required this.onRemove,
    required this.onPropose,
    required this.onAutoMatch,
    required this.running,
    required this.proposals,
    required this.autoMatchResult,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedTxn == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'اختر حركة بنكية من اليسار لبدء المطابقة الذكية.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AC.ts, height: 1.7),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SelectedBanner(txn: selectedTxn!),
        const SizedBox(height: AppSpacing.md),
        _SectionHeader(
          icon: Icons.list_alt,
          title: 'المرشحون للمطابقة',
          trailing: OutlinedButton.icon(
            onPressed: onAdd,
            icon: Icon(Icons.add, size: 16, color: AC.gold),
            label: Text(
              'مرشح جديد',
              style: TextStyle(color: AC.gold, fontSize: AppFontSize.sm),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.gold.withValues(alpha: 0.5)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (int i = 0; i < candidates.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _CandidateEditor(
              candidate: candidates[i],
              index: i,
              onRemove: candidates.length > 1 ? () => onRemove(i) : null,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onPropose,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: const Text('اقترح مطابقات'),
                style: FilledButton.styleFrom(
                  backgroundColor: AC.gold.withValues(alpha: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: onAutoMatch,
                icon: const Icon(Icons.shield_moon_outlined, size: 18),
                label: const Text('طابق تلقائياً'),
                style: FilledButton.styleFrom(
                  backgroundColor: AC.gold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
        if (running) ...[
          const SizedBox(height: AppSpacing.md),
          LinearProgressIndicator(color: AC.gold),
        ],
        if (autoMatchResult != null) ...[
          const SizedBox(height: AppSpacing.lg),
          _AutoMatchCard(result: autoMatchResult!),
        ],
        if (proposals.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _SectionHeader(icon: Icons.stacked_bar_chart, title: 'الاقتراحات'),
          const SizedBox(height: AppSpacing.sm),
          for (final p in proposals)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ProposalRow(proposal: p),
            ),
        ],
      ],
    );
  }
}

class _SelectedBanner extends StatelessWidget {
  final Map<String, dynamic> txn;
  const _SelectedBanner({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isCredit = txn['direction']?.toString() == 'credit';
    final color = isCredit ? AC.ok : AC.warn;
    final date = (txn['txn_date']?.toString() ?? '').split('T').first;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(right: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn['description']?.toString() ?? '—',
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((txn['counterparty']?.toString() ?? '').isNotEmpty)
                  Text(
                    txn['counterparty'].toString(),
                    style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$date · id: ${txn['id']}',
                    style: TextStyle(
                      color: AC.ts,
                      fontSize: AppFontSize.xs,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? "+" : "−"}${txn['amount']} ${txn['currency'] ?? "SAR"}',
            style: TextStyle(
              color: color,
              fontSize: AppFontSize.lg,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const _SectionHeader({
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AC.gold, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: TextStyle(
              color: AC.tp,
              fontSize: AppFontSize.base,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      );
}

class _CandidateEditor extends StatelessWidget {
  final _Candidate candidate;
  final int index;
  final VoidCallback? onRemove;

  const _CandidateEditor({
    required this.candidate,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AC.navy3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AC.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    color: AC.gold,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  tooltip: 'إزالة المرشح',
                  onPressed: onRemove,
                  icon: Icon(Icons.close, color: AC.err, size: 16),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _field(
                  candidate.idCtl,
                  hint: 'المعرّف (JE-042)',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _field(
                  candidate.amountCtl,
                  hint: 'المبلغ',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _field(
                  candidate.dateCtl,
                  hint: 'التاريخ (YYYY-MM-DD)',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _field(candidate.vendorCtl, hint: 'المورِّد'),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _field(candidate.descCtl, hint: 'الوصف'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, {required String hint}) {
    return TextField(
      controller: c,
      style: TextStyle(color: AC.tp, fontSize: AppFontSize.sm),
      cursorColor: AC.gold,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AC.ts, fontSize: AppFontSize.xs),
        filled: true,
        fillColor: AC.navy,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          borderSide: BorderSide(color: AC.navy3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          borderSide: BorderSide(color: AC.navy3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          borderSide: BorderSide(color: AC.gold),
        ),
      ),
    );
  }
}

class _AutoMatchCard extends StatelessWidget {
  final Map<String, dynamic> result;
  const _AutoMatchCard({required this.result});

  Color _colorFor(String verdict) {
    switch (verdict) {
      case 'auto_applied':
        return AC.ok;
      case 'needs_approval':
        return AC.warn;
      case 'rejected':
        return AC.err;
      default:
        return AC.info;
    }
  }

  String _labelFor(String verdict) {
    switch (verdict) {
      case 'auto_applied':
        return 'تمت المطابقة تلقائياً';
      case 'needs_approval':
        return 'بانتظار مراجعة بشرية';
      case 'rejected':
        return 'تم الرفض';
      case 'approved':
        return 'تمت الموافقة';
      default:
        return verdict;
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdict = result['verdict']?.toString() ?? '';
    final color = _colorFor(verdict);
    final score = (result['score'] as num?)?.toDouble() ?? 0.0;
    final pct = (score * 100).toStringAsFixed(1);
    final candidate = result['best_candidate_id']?.toString() ?? '—';
    final reason = result['reason']?.toString() ?? '';
    final rowId = result['row_id']?.toString();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_moon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _labelFor(verdict),
                  style: TextStyle(
                    color: color,
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'ثقة $pct%',
                  style: TextStyle(
                    color: color,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'أفضل مرشح: $candidate',
            style: TextStyle(color: AC.tp, fontSize: AppFontSize.sm),
          ),
          if (reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                reason,
                style: TextStyle(
                  color: AC.ts,
                  fontSize: AppFontSize.sm,
                  height: 1.6,
                ),
              ),
            ),
          if (verdict == 'needs_approval' && rowId != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.go('/app/compliance/gov/ai-oversight'),
                icon: Icon(Icons.open_in_new, size: 14, color: color),
                label: Text(
                  'راجعها في ضوابط الذكاء',
                  style: TextStyle(color: color, fontSize: AppFontSize.sm),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProposalRow extends StatelessWidget {
  final Map<String, dynamic> proposal;
  const _ProposalRow({required this.proposal});

  Color _scoreColor(double s) {
    if (s >= 0.95) return AC.ok;
    if (s >= 0.70) return AC.gold;
    if (s >= 0.40) return AC.warn;
    return AC.err;
  }

  @override
  Widget build(BuildContext context) {
    final score = (proposal['score'] as num?)?.toDouble() ?? 0.0;
    final color = _scoreColor(score);
    final pct = (score * 100).toStringAsFixed(1);
    final id = proposal['candidate_id']?.toString() ?? '—';
    final a = (proposal['amount_score'] as num?)?.toDouble() ?? 0;
    final d = (proposal['date_score'] as num?)?.toDouble() ?? 0;
    final v = (proposal['vendor_score'] as num?)?.toDouble() ?? 0;
    final desc = (proposal['desc_score'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(right: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  id,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _FeatureChip(label: 'مبلغ', value: a),
                    _FeatureChip(label: 'تاريخ', value: d),
                    _FeatureChip(label: 'مورِّد', value: v),
                    _FeatureChip(label: 'وصف', value: desc),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '$pct%',
              style: TextStyle(
                color: color,
                fontSize: AppFontSize.base,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final String label;
  final double value;
  const _FeatureChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AC.navy3.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        '$label $pct%',
        style: TextStyle(
          color: AC.ts,
          fontSize: AppFontSize.xs,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── Candidate value-holder ────────────────────────────────────────────

class _Candidate {
  final TextEditingController idCtl;
  final TextEditingController amountCtl;
  final TextEditingController dateCtl;
  final TextEditingController vendorCtl;
  final TextEditingController descCtl;

  _Candidate({
    required this.idCtl,
    required this.amountCtl,
    required this.dateCtl,
    required this.vendorCtl,
    required this.descCtl,
  });

  factory _Candidate.empty() => _Candidate(
        idCtl: TextEditingController(),
        amountCtl: TextEditingController(),
        dateCtl: TextEditingController(),
        vendorCtl: TextEditingController(),
        descCtl: TextEditingController(),
      );

  bool get hasAny =>
      idCtl.text.trim().isNotEmpty ||
      amountCtl.text.trim().isNotEmpty ||
      dateCtl.text.trim().isNotEmpty ||
      vendorCtl.text.trim().isNotEmpty ||
      descCtl.text.trim().isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': idCtl.text.trim(),
        'amount': amountCtl.text.trim(),
        'date': dateCtl.text.trim(),
        'vendor': vendorCtl.text.trim(),
        'description': descCtl.text.trim(),
      };

  void dispose() {
    idCtl.dispose();
    amountCtl.dispose();
    dateCtl.dispose();
    vendorCtl.dispose();
    descCtl.dispose();
  }
}
