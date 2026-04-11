import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/shared_constants.dart';

// Phase 11 Legal Acceptance §12
// ═══════════════════════════════════════════════════════════
class LegalDocumentsScreenV2 extends StatefulWidget {
  const LegalDocumentsScreenV2({super.key});
  @override State<LegalDocumentsScreenV2> createState() => _LegalDocsV2State();
}
class _LegalDocsV2State extends State<LegalDocumentsScreenV2> {
  List<dynamic> _docs = [];
  List<dynamic> _pending = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r1 = await ApiService.getLegalDocuments();
      final r2 = await ApiService.getLegalPending();
      if (r1.success) setState(() => _docs = r1.data['documents'] ?? []);
      if (r2.success) setState(() => _pending = r2.data['pending'] ?? []);
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _acceptOne(String docId) async {
    final r = await ApiService.acceptLegalDoc(docId);
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u062a\u0645 \u0627\u0644\u0642\u0628\u0648\u0644'), backgroundColor: Colors.green));
      _load();
    }
  }

  Future<void> _acceptAll() async {
    final r = await ApiService.acceptAllLegal();
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u062a\u0645 \u0642\u0628\u0648\u0644 \u062c\u0645\u064a\u0639 \u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a'), backgroundColor: Colors.green));
      _load();
    }
  }

  bool _isPending(String docId) => _pending.any((p) => p['id'] == docId);

  IconData _iconFor(String type) {
    switch (type) {
      case 'terms_of_service': return Icons.gavel;
      case 'privacy_policy': return Icons.privacy_tip;
      case 'acceptable_use_policy': return Icons.rule;
      case 'provider_policy': return Icons.handshake;
      default: return Icons.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: const Text('\u0627\u0644\u0634\u0631\u0648\u0637 \u0648\u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a'),
        backgroundColor: AC.navy2,
        actions: [
          if (_pending.isNotEmpty)
            TextButton(
              onPressed: _acceptAll,
              child: const Text('\u0642\u0628\u0648\u0644 \u0627\u0644\u0643\u0644', style: TextStyle(color: AC.gold, fontSize: 12)),
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.gold))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _docs.length,
            itemBuilder: (_, i) {
              final d = _docs[i];
              final pending = _isPending(d['id']);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AC.navy3, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pending ? AC.warn.withOpacity(0.5) : AC.bdr),
                ),
                child: ExpansionTile(
                  leading: Icon(_iconFor(d['type']), color: pending ? AC.warn : AC.gold),
                  title: Text(d['title_ar'] ?? '', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Row(children: [
                    Text('v${d['version']}', style: TextStyle(color: AC.ts, fontSize: 11)),
                    const SizedBox(width: 8),
                    if (pending)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AC.warn.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('\u0628\u0627\u0646\u062a\u0638\u0627\u0631 \u0627\u0644\u0642\u0628\u0648\u0644', style: TextStyle(color: AC.warn, fontSize: 10)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: AC.ok.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Text('\u0645\u0642\u0628\u0648\u0644', style: TextStyle(color: AC.ok, fontSize: 10)),
                      ),
                  ]),
                  iconColor: AC.ts, collapsedIconColor: AC.ts,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['content_ar'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13, height: 1.6)),
                        if (pending) ...[
                          const SizedBox(height: 16),
                          SizedBox(width: double.infinity, child: ElevatedButton(
                            onPressed: () => _acceptOne(d['id']),
                            style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy),
                            child: const Text('\u0623\u0648\u0627\u0641\u0642 \u0639\u0644\u0649 \u0647\u0630\u0647 \u0627\u0644\u0633\u064a\u0627\u0633\u0629', style: TextStyle(fontWeight: FontWeight.bold)),
                          )),
                        ],
                      ]),
                    ),
                  ],
                ),
              );
            },
          ),
    ));
  }
}
