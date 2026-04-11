import 'package:flutter/material.dart';
import '../../core/theme.dart';

class CopilotFileHelper extends StatelessWidget {
  final Function(String) onSend;
  const CopilotFileHelper({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('\u0631\u0641\u0639 \u0645\u0644\u0641 \u0644\u0644\u062a\u062d\u0644\u064a\u0644', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Row(children: [
          _fileBtn('\u0634\u062c\u0631\u0629 \u062d\u0633\u0627\u0628\u0627\u062a', Icons.account_tree, () => onSend('\u0623\u0631\u064a\u062f \u0631\u0641\u0639 \u0634\u062c\u0631\u0629 \u062d\u0633\u0627\u0628\u0627\u062a')),
          const SizedBox(width: 8),
          _fileBtn('\u0645\u064a\u0632\u0627\u0646 \u0645\u0631\u0627\u062c\u0639\u0629', Icons.balance, () => onSend('\u0623\u0631\u064a\u062f \u0631\u0641\u0639 \u0645\u064a\u0632\u0627\u0646 \u0645\u0631\u0627\u062c\u0639\u0629')),
          const SizedBox(width: 8),
          _fileBtn('\u0645\u0633\u062a\u0646\u062f', Icons.upload_file, () => onSend('\u0623\u0631\u064a\u062f \u0631\u0641\u0639 \u0645\u0633\u062a\u0646\u062f')),
        ]),
      ]),
    );
  }

  Widget _fileBtn(String label, IconData icon, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: AC.navy4, borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Icon(icon, color: AC.cyan, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AC.tp, fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    ),
  );
}

class EscalationBanner extends StatelessWidget {
  final Map<String, dynamic> escalation;
  final VoidCallback? onRequestReview;
  const EscalationBanner({super.key, required this.escalation, this.onRequestReview});

  @override
  Widget build(BuildContext context) {
    if (escalation['needed'] != true) return const SizedBox();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.warn.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.warn.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AC.warn, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('\u064a\u0646\u0635\u062d \u0628\u0645\u0631\u0627\u062c\u0639\u0629 \u0628\u0634\u0631\u064a\u0629', style: TextStyle(color: AC.warn, fontWeight: FontWeight.bold, fontSize: 13))),
        ]),
        const SizedBox(height: 6),
        Text(escalation['reason'] ?? '', style: const TextStyle(color: AC.ts, fontSize: 11)),
        if (onRequestReview != null) ...[
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: onRequestReview,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.warn)),
            icon: const Icon(Icons.person_search, color: AC.warn, size: 16),
            label: const Text('\u0637\u0644\u0628 \u0645\u0631\u0627\u062c\u0639\u0629 \u0628\u0634\u0631\u064a\u0629', style: TextStyle(color: AC.warn, fontSize: 12)),
          )),
        ],
      ]),
    );
  }
}
