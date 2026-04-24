/// APEX — AI-assisted Bank Reconciliation
/// ═══════════════════════════════════════════════════════════
/// Two-column screen modeled on Xero's bank-rec. Left: unreconciled
/// bank transactions. Right: per-row AI-suggested journal entries
/// with confidence + Arabic rationale. Tap "مطابقة" to lock it in.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class BankRecAiScreen extends StatefulWidget {
  const BankRecAiScreen({super.key});

  @override
  State<BankRecAiScreen> createState() => _BankRecAiScreenState();
}

class _BankRecAiScreenState extends State<BankRecAiScreen> {
  bool _loading = true;
  bool _suggestionsLoading = false;
  String? _error;
  List<Map<String, dynamic>> _txns = [];
  List<Map<String, dynamic>> _suggestions = [];
  String? _selectedTxnId;

  @override
  void initState() {
    super.initState();
    _loadTxns();
  }

  Future<void> _loadTxns() async {
    setState(() => _loading = true);
    final res = await ApiService.listBankTransactions();
    if (!mounted) return;
    if (res.success && res.data != null) {
      final raw = res.data['data'] ?? res.data;
      final list = raw is List ? raw : <dynamic>[];
      setState(() {
        _txns = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } else {
      setState(() {
        _error = res.error;
        _loading = false;
      });
    }
  }

  Future<void> _selectTxn(String txnId) async {
    setState(() {
      _selectedTxnId = txnId;
      _suggestionsLoading = true;
      _suggestions = [];
    });
    final res = await ApiService.aiBankRecSuggestions(txnId);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final list = (res.data['data'] as List?) ?? [];
      setState(() {
        _suggestions = list.cast<Map<String, dynamic>>();
        _suggestionsLoading = false;
      });
    } else {
      setState(() => _suggestionsLoading = false);
    }
  }

  Future<void> _match(Map<String, dynamic> suggestion) async {
    if (_selectedTxnId == null) return;
    final res = await ApiService.markBankTxnReconciled(
      _selectedTxnId!,
      entityType: suggestion['candidate_type'] as String,
      entityId: suggestion['candidate_id'] as String,
    );
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمّت المطابقة')),
      );
      setState(() {
        _txns.removeWhere((t) => t['id'] == _selectedTxnId);
        _selectedTxnId = null;
        _suggestions = [];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'فشلت المطابقة')),
      );
    }
  }

  Future<void> _autoMatchAll() async {
    setState(() => _loading = true);
    final res = await ApiService.aiBankRecAutoMatch();
    if (!mounted) return;
    final out = res.data?['data'] ?? {};
    final matched = out['matched'] ?? 0;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('مطابقة تلقائية: $matched حركة')),
    );
    await _loadTxns();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text(
            'التسوية البنكية بالذكاء الاصطناعي',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
          ),
          actions: [
            TextButton.icon(
              onPressed: _loading ? null : _autoMatchAll,
              icon: Icon(Icons.auto_awesome, size: 18, color: AC.gold),
              label: Text(
                'مطابقة تلقائية',
                style: TextStyle(color: AC.gold, fontFamily: 'Tajawal'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _loadTxns,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: AC.err)))
                : _body(),
      ),
    );
  }

  Widget _body() {
    return Row(
      children: [
        Expanded(child: _leftColumn()),
        Expanded(child: _rightColumn()),
      ],
    );
  }

  Widget _leftColumn() {
    return Container(
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: AC.gold.withValues(alpha: 0.15))),
      ),
      child: Column(
        children: [
          _columnHeader(
            Icons.account_balance,
            'حركات بنكية لم تطابق (${_txns.length})',
          ),
          Expanded(
            child: _txns.isEmpty
                ? _emptyAllMatched()
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: _txns.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final t = _txns[i];
                      return _TxnTile(
                        txn: t,
                        selected: t['id'] == _selectedTxnId,
                        onTap: () => _selectTxn(t['id'] as String),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _rightColumn() {
    return Column(
      children: [
        _columnHeader(
          Icons.auto_awesome,
          _selectedTxnId == null ? 'اختر حركة من اليمين' : 'مطابقات مقترحة من AI',
        ),
        Expanded(child: _rightPane()),
      ],
    );
  }

  Widget _columnHeader(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AC.navy2,
      child: Row(
        children: [
          Icon(icon, color: AC.gold, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: AC.tp,
              fontFamily: 'Tajawal',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyAllMatched() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: AC.ok, size: 44),
          const SizedBox(height: 8),
          Text('كل الحركات مطابَقة',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
        ],
      ),
    );
  }

  Widget _rightPane() {
    if (_selectedTxnId == null) {
      return Center(child: Icon(Icons.arrow_forward, color: AC.ts, size: 32));
    }
    if (_suggestionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: AC.ts, size: 36),
            const SizedBox(height: 8),
            Text(
              'لم يُعثر على تطابقات مقترحة',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              'يمكنك إنشاء قيد يومية يدوي لهذه الحركة',
              style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 11),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(10),
      itemCount: _suggestions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _SuggestionTile(
        suggestion: _suggestions[i],
        onMatch: () => _match(_suggestions[i]),
      ),
    );
  }
}

class _TxnTile extends StatelessWidget {
  final Map<String, dynamic> txn;
  final bool selected;
  final VoidCallback onTap;
  const _TxnTile({required this.txn, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final amount = (txn['amount'] ?? '0').toString();
    final dir = (txn['direction'] ?? '') as String;
    final cp = (txn['counterparty'] ?? '') as String?;
    final desc = (txn['description'] ?? '') as String?;
    final date = (txn['txn_date'] ?? '') as String;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? AC.gold.withValues(alpha: 0.15) : AC.navy2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AC.gold : AC.gold.withValues(alpha: 0.12),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              dir == 'credit' ? Icons.arrow_downward : Icons.arrow_upward,
              color: dir == 'credit' ? AC.ok : AC.err,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cp != null && cp.isNotEmpty ? cp : (desc ?? '—'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AC.tp,
                      fontFamily: 'Tajawal',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    date.split('T').first,
                    style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 10.5),
                  ),
                ],
              ),
            ),
            Text(
              '$amount ${txn['currency'] ?? ''}',
              style: TextStyle(
                color: dir == 'credit' ? AC.ok : AC.err,
                fontFamily: 'Tajawal',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final VoidCallback onMatch;
  const _SuggestionTile({required this.suggestion, required this.onMatch});

  @override
  Widget build(BuildContext context) {
    final label = (suggestion['candidate_label'] ?? '') as String;
    final amount = (suggestion['candidate_amount'] ?? 0).toString();
    final confidence = (suggestion['confidence'] ?? 0) as num;
    final reasons = (suggestion['reasons'] as List?)?.cast<String>() ?? const [];
    final autoOK = (suggestion['auto_apply_recommended'] ?? false) as bool;
    final color = confidence >= 0.8 ? AC.ok : (confidence >= 0.5 ? AC.gold : AC.ts);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AC.tp,
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _confidenceBadge(confidence, color, autoOK),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'المبلغ: $amount SAR',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5),
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: reasons.map((r) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Text(
                  r,
                  style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 10.5),
                ),
              )).toList(),
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onMatch,
            icon: const Icon(Icons.check, size: 16),
            label: const Text('مطابقة', style: TextStyle(fontFamily: 'Tajawal')),
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confidenceBadge(num conf, Color color, bool autoOK) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (autoOK) Icon(Icons.verified, color: color, size: 12),
          if (autoOK) const SizedBox(width: 3),
          Text(
            '${(conf * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: color,
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
