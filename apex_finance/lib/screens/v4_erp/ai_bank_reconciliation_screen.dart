/// APEX Wave 16 — AI Bank Reconciliation UI (production candidate).
///
/// Wires Wave 15 backend endpoints:
///   POST /bank-rec/propose     — scoring candidates for a bank txn
///   POST /bank-rec/auto-match  — guardrail-gated auto-reconcile
///
/// Designed to live under V5 chip path:
///   /app/erp/treasury/recon?t=ai
///
/// Pattern: AI Suggestions tab within the Reconciliation chip.
/// Each unmatched transaction shows:
///   - Transaction details (amount, vendor, date, description)
///   - Top AI candidate with confidence %
///   - Match reasons (Arabic via Wave 15 scoring reasons)
///   - Approve / Reject inline (Wave 7 guardrails pattern)
library;

import 'package:flutter/material.dart';

import '../../core/v5/apex_v5_undo_toast.dart';

class AiBankReconciliationScreen extends StatefulWidget {
  const AiBankReconciliationScreen({super.key});

  @override
  State<AiBankReconciliationScreen> createState() =>
      _AiBankReconciliationScreenState();
}

class _AiBankReconciliationScreenState
    extends State<AiBankReconciliationScreen> {
  // Mock data — in production fetched from /bank-feeds/transactions + /bank-rec/propose
  late List<_AiMatchSuggestion> _suggestions;

  @override
  void initState() {
    super.initState();
    _suggestions = _mockSuggestions();
  }

  List<_AiMatchSuggestion> _mockSuggestions() => [
        _AiMatchSuggestion(
          txnExternalId: 'BF-2026-04-18-001',
          txnAmount: 5000,
          txnDate: DateTime(2026, 4, 18),
          txnVendor: 'Marriott Hotels',
          txnDescription: 'Riyadh Marriott Conference',
          txnDirection: 'debit',
          candidateId: 'INV-501',
          candidateType: 'invoice',
          candidateAmount: 5000,
          candidateVendor: 'Marriott',
          score: 0.967,
          reasons: ['مطابقة تامة للمبلغ', 'نفس اليوم', 'اسم المورد متضمَّن'],
          verdict: 'auto_applied',
        ),
        _AiMatchSuggestion(
          txnExternalId: 'BF-2026-04-17-012',
          txnAmount: 1250,
          txnDate: DateTime(2026, 4, 17),
          txnVendor: 'STC Telecom',
          txnDescription: 'STC monthly bill',
          txnDirection: 'debit',
          candidateId: 'JE-4521',
          candidateType: 'journal_entry',
          candidateAmount: 1250,
          candidateVendor: 'STC Telecom',
          score: 0.95,
          reasons: ['مطابقة تامة للمبلغ', 'نفس اليوم', 'اسم المورد مطابق'],
          verdict: 'auto_applied',
        ),
        _AiMatchSuggestion(
          txnExternalId: 'BF-2026-04-15-047',
          txnAmount: 2350,
          txnDate: DateTime(2026, 4, 15),
          txnVendor: 'ABC Trading',
          txnDescription: 'Office supplies Q2',
          txnDirection: 'debit',
          candidateId: 'JE-4487',
          candidateType: 'journal_entry',
          candidateAmount: 2340,
          candidateVendor: 'ABC Trading Co',
          score: 0.82,
          reasons: [
            'مبلغ قريب (فارق 0.43%)',
            'نفس اليوم',
            'اسم المورد متضمَّن',
            'تشابه الوصف (2 كلمات)'
          ],
          verdict: 'needs_approval',
        ),
        _AiMatchSuggestion(
          txnExternalId: 'BF-2026-04-14-089',
          txnAmount: 18000,
          txnDate: DateTime(2026, 4, 14),
          txnVendor: 'ARAMCO',
          txnDescription: 'Fuel corporate account',
          txnDirection: 'debit',
          candidateId: 'INV-502',
          candidateType: 'invoice',
          candidateAmount: 18000,
          candidateVendor: 'Saudi Aramco',
          score: 0.88,
          reasons: ['مطابقة تامة للمبلغ', 'نفس اليوم', 'تطابق جزئي (1 كلمات)'],
          verdict: 'needs_approval',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats strip
        _buildStats(),
        const Divider(height: 1),
        // Suggestions list
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) => _SuggestionCard(
              suggestion: _suggestions[i],
              onApprove: () => _onApprove(i),
              onReject: () => _onReject(i),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final total = _suggestions.length;
    final autoApplied = _suggestions.where((s) => s.verdict == 'auto_applied').length;
    final needsApproval = _suggestions.where((s) => s.verdict == 'needs_approval').length;
    final avgScore = _suggestions.isEmpty
        ? 0.0
        : _suggestions.map((s) => s.score).reduce((a, b) => a + b) /
            _suggestions.length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFFF9FAFB),
      child: Row(
        children: [
          _StatPill(
            label: 'إجمالي الاقتراحات',
            value: '$total',
            icon: Icons.list_alt,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 12),
          _StatPill(
            label: 'تم التطبيق تلقائياً',
            value: '$autoApplied',
            icon: Icons.check_circle,
            color: const Color(0xFF059669),
          ),
          const SizedBox(width: 12),
          _StatPill(
            label: 'بحاجة مراجعة',
            value: '$needsApproval',
            icon: Icons.pending_actions,
            color: const Color(0xFFD97706),
          ),
          const SizedBox(width: 12),
          _StatPill(
            label: 'متوسط الثقة',
            value: '${(avgScore * 100).toStringAsFixed(0)}%',
            icon: Icons.insights,
            color: const Color(0xFF7C3AED),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => setState(() => _suggestions = _mockSuggestions()),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('تحديث'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _onApprove(int index) {
    final s = _suggestions[index];
    setState(() {
      _suggestions.removeAt(index);
    });
    ApexV5UndoToast.show(
      context,
      messageAr: 'تم اعتماد المطابقة: ${s.txnExternalId} ← ${s.candidateId}',
      onUndo: () {
        setState(() => _suggestions.insert(index, s));
      },
    );
  }

  void _onReject(int index) {
    final s = _suggestions[index];
    setState(() {
      _suggestions.removeAt(index);
    });
    ApexV5UndoToast.show(
      context,
      messageAr: 'تم رفض الاقتراح: ${s.txnExternalId}',
      icon: Icons.close,
      color: const Color(0xFFB91C1C),
      onUndo: () {
        setState(() => _suggestions.insert(index, s));
      },
    );
  }
}

class _AiMatchSuggestion {
  final String txnExternalId;
  final double txnAmount;
  final DateTime txnDate;
  final String txnVendor;
  final String txnDescription;
  final String txnDirection;
  final String candidateId;
  final String candidateType;
  final double candidateAmount;
  final String candidateVendor;
  final double score;
  final List<String> reasons;
  final String verdict; // auto_applied | needs_approval | rejected

  _AiMatchSuggestion({
    required this.txnExternalId,
    required this.txnAmount,
    required this.txnDate,
    required this.txnVendor,
    required this.txnDescription,
    required this.txnDirection,
    required this.candidateId,
    required this.candidateType,
    required this.candidateAmount,
    required this.candidateVendor,
    required this.score,
    required this.reasons,
    required this.verdict,
  });
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final _AiMatchSuggestion suggestion;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _SuggestionCard({
    required this.suggestion,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isAuto = suggestion.verdict == 'auto_applied';
    final confidenceColor = suggestion.score >= 0.95
        ? const Color(0xFF059669) // green
        : suggestion.score >= 0.80
            ? const Color(0xFFD97706) // amber
            : const Color(0xFFB91C1C); // red

    final dirColor = suggestion.txnDirection == 'credit'
        ? const Color(0xFF059669)
        : const Color(0xFFD97706);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: txn details
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: dirColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            suggestion.txnExternalId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: dirColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              suggestion.txnDirection == 'credit' ? 'دائن ↓' : 'مدين ↑',
                              style: TextStyle(
                                fontSize: 10,
                                color: dirColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            suggestion.txnVendor,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${suggestion.txnDescription}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${suggestion.txnAmount.toStringAsFixed(0)} ر.س',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: dirColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      '${suggestion.txnDate.toString().substring(0, 10)}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // AI Match section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AI icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        confidenceColor.withOpacity(0.8),
                        confidenceColor,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'اقتراح الذكاء:',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: confidenceColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: confidenceColor.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bar_chart,
                                  size: 12,
                                  color: confidenceColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(suggestion.score * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: confidenceColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (isAuto)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bolt, size: 10, color: Color(0xFF059669)),
                                  SizedBox(width: 2),
                                  Text(
                                    'تلقائي',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'بحاجة اعتماد',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFD97706),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            suggestion.candidateType == 'invoice'
                                ? Icons.receipt
                                : Icons.book,
                            size: 14,
                            color: Colors.black54,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            suggestion.candidateId,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• ${suggestion.candidateVendor}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const Spacer(),
                          Text(
                            '${suggestion.candidateAmount.toStringAsFixed(0)} ر.س',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final r in suggestion.reasons)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                r,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.02),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(
                top: BorderSide(color: Colors.black.withOpacity(0.06)),
              ),
            ),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.info_outline, size: 14),
                  label: const Text('عرض التفاصيل'),
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.close, size: 14),
                  label: const Text('رفض'),
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB91C1C),
                    side: const BorderSide(color: Color(0xFFB91C1C)),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check, size: 14),
                  label: Text(isAuto ? 'مؤكَّد' : 'اعتماد'),
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: confidenceColor,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
