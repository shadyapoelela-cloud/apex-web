/// APEX — Document Flow (SAP bidirectional trace pattern)
/// ═══════════════════════════════════════════════════════════
/// A one-line widget that renders the **document flow** for any
/// source document (PO / GRN / Invoice / Payment / JE) as a modal
/// dialog. Given `sourceType + sourceId`, it calls
/// /api/v1/ai/universal-journal/document-flow/{type}/{id} and shows
/// all related documents with their statuses and links.
///
/// Usage:
///
///   ApexDocumentFlowButton(
///     sourceType: 'sales_invoice',
///     sourceId: invoice.id,
///   )
///
/// Drop-in to any row's action menu, any document detail screen's
/// header, or any JE's smart-button row.
library;

import 'package:flutter/material.dart';

import '../api_service.dart';
import 'theme.dart';

class ApexDocumentFlowButton extends StatelessWidget {
  final String sourceType;
  final String sourceId;
  final String? labelAr;
  const ApexDocumentFlowButton({
    super.key,
    required this.sourceType,
    required this.sourceId,
    this.labelAr,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => showApexDocumentFlow(
        context,
        sourceType: sourceType,
        sourceId: sourceId,
      ),
      icon: Icon(Icons.account_tree_outlined, size: 16, color: AC.gold),
      label: Text(
        labelAr ?? 'مسار المستند',
        style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 12),
      ),
    );
  }
}

Future<void> showApexDocumentFlow(
  BuildContext context, {
  required String sourceType,
  required String sourceId,
}) async {
  await showDialog(
    context: context,
    builder: (c) => Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: AC.navy2,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
          child: _DocumentFlowDialog(sourceType: sourceType, sourceId: sourceId),
        ),
      ),
    ),
  );
}

class _DocumentFlowDialog extends StatefulWidget {
  final String sourceType;
  final String sourceId;
  const _DocumentFlowDialog({required this.sourceType, required this.sourceId});

  @override
  State<_DocumentFlowDialog> createState() => _DocumentFlowDialogState();
}

class _DocumentFlowDialogState extends State<_DocumentFlowDialog> {
  bool _loading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await ApiService.documentFlow(widget.sourceType, widget.sourceId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data != null) {
        _data = (res.data['data'] as Map).cast<String, dynamic>();
      } else {
        _error = res.error ?? 'تعذر تحميل مسار المستند';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AC.gold.withValues(alpha: 0.2), AC.gold.withValues(alpha: 0.05)]),
      ),
      child: Row(
        children: [
          Icon(Icons.account_tree, color: AC.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مسار المستند — Document Flow',
                    style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${_typeLabel(widget.sourceType)} — ${widget.sourceId.substring(0, 8)}...',
                    style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: AC.err)));
    if (_data == null) return const SizedBox.shrink();

    final self = _data!['self'] as Map?;
    final flow = (_data!['flow'] as List?) ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (self != null) _docTile(self.cast<String, dynamic>(), isSelf: true),
          if (flow.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('لا توجد مستندات مرتبطة',
                  style: TextStyle(color: AC.ts, fontFamily: 'Tajawal'))),
            )
          else ...[
            const SizedBox(height: 10),
            Text('المستندات المرتبطة (${flow.length})',
                style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ...flow.map((f) => _docTile((f as Map).cast<String, dynamic>())),
          ],
        ],
      ),
    );
  }

  Widget _docTile(Map<String, dynamic> doc, {bool isSelf = false}) {
    final type = doc['document_type'] ?? '';
    final num = doc['document_number'] ?? '';
    final date = doc['date'] ?? '';
    final status = doc['status'] ?? '';
    final total = doc['total'] ?? doc['total_debit'];
    final currency = doc['currency'] ?? '';
    final color = isSelf ? AC.gold : _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSelf ? AC.gold.withValues(alpha: 0.08) : AC.navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_typeLabel(type),
                          style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Text('$num',
                        style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600)),
                    if (isSelf) ...[
                      const SizedBox(width: 6),
                      Text('(المصدر)',
                          style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 10)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('$date · $status${total != null ? ' · $total $currency' : ''}',
                    style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'posted':
      case 'paid':
      case 'issued':
        return AC.ok;
      case 'draft':
      case 'pending':
        return AC.ts;
      case 'cancelled':
      case 'failed':
      case 'rejected':
        return AC.err;
      default:
        return AC.gold;
    }
  }

  String _typeLabel(String t) {
    const map = {
      'journal_entry': 'قيد',
      'sales_invoice': 'فاتورة بيع',
      'purchase_invoice': 'فاتورة مشتريات',
      'purchase_order': 'أمر شراء',
      'goods_receipt': 'محضر استلام',
      'vendor_payment': 'سند صرف',
      'customer_payment': 'سند قبض',
      'pos_transaction': 'حركة POS',
    };
    return map[t] ?? t;
  }
}
