/// APEX Platform — Invoice OCR Extraction
/// ═══════════════════════════════════════════════════════════════
/// Paste OCR'd invoice text (from Tesseract.js / Vision API / manual
/// keyboard input) and extract structured fields: invoice number,
/// date, seller/buyer VAT, subtotal, VAT, total. Validates VAT number
/// format and flags internal-consistency issues (subtotal + VAT ≠ total).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});
  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final _textC = TextEditingController();
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _textC.dispose();
    super.dispose();
  }

  static const _sample = """فاتورة رقم: INV-2026-00123
التاريخ: 2026-04-15
الرقم الضريبي للبائع: 300000000000003

المجموع قبل الضريبة: 1000.00 SAR
ضريبة VAT: 150.00 SAR
الإجمالي: 1150.00 SAR
""";

  Future<void> _extract() async {
    final text = _textC.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'الصق نص الفاتورة أولاً');
      return;
    }
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await ApiService.ocrExtractInvoice(text);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل الاستخراج');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: Text('استخراج بيانات الفاتورة (OCR)',
      style: TextStyle(color: AC.gold)), backgroundColor: AC.navy2),
    body: LayoutBuilder(builder: (ctx, cons) {
      final wide = cons.maxWidth > 960;
      if (!wide) return SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(children: [_inputPanel(), const SizedBox(height: 16), _results()]));
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _inputPanel())),
        Container(width: 1, color: AC.bdr),
        Expanded(flex: 5, child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), child: _results())),
      ]);
    }),
  );

  Widget _inputPanel() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.info.withValues(alpha: 0.08),
        border: Border.all(color: AC.info.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(Icons.info_outline, color: AC.info, size: 16),
        const SizedBox(width: 6),
        Expanded(child: Text(
          'هذه الأداة تستقبل نصاً مستخرجاً عبر OCR (مثل Tesseract.js أو Google Vision)، '
          'ثم تحلّله لاستخراج الحقول المالية بدقة.',
          style: TextStyle(color: AC.tp, fontSize: 11, height: 1.5),
        )),
      ]),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _textC,
      maxLines: 14,
      minLines: 10,
      style: TextStyle(color: AC.tp, fontSize: 13,
        fontFamily: 'monospace', height: 1.5),
      decoration: InputDecoration(
        labelText: 'نص الفاتورة (بعد OCR)',
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        hintText: 'الصق النص هنا...',
        hintStyle: TextStyle(color: AC.td),
        filled: true, fillColor: AC.navy3,
        alignLabelWithHint: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AC.goldText)),
      ),
    ),
    const SizedBox(height: 8),
    Row(children: [
      TextButton.icon(
        onPressed: () => setState(() => _textC.text = _sample),
        icon: Icon(Icons.content_paste, color: AC.gold, size: 14),
        label: Text('نص تجريبي', style: TextStyle(color: AC.gold, fontSize: 12)),
      ),
      const Spacer(),
      TextButton.icon(
        onPressed: () {
          Clipboard.getData('text/plain').then((d) {
            if (d?.text != null) setState(() => _textC.text = d!.text ?? '');
          });
        },
        icon: Icon(Icons.paste, color: AC.info, size: 14),
        label: Text('لصق من الحافظة',
          style: TextStyle(color: AC.info, fontSize: 12)),
      ),
    ]),
    const SizedBox(height: 8),
    if (_error != null) Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AC.err.withValues(alpha: 0.35))),
      child: Row(children: [
        Icon(Icons.error_outline, color: AC.err, size: 14),
        const SizedBox(width: 6),
        Expanded(child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12))),
      ]),
    ),
    const SizedBox(height: 10),
    SizedBox(height: 50, child: ElevatedButton.icon(
      onPressed: _loading ? null : _extract,
      icon: _loading
        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(
            strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.auto_awesome),
      label: const Text('استخرج الحقول', style: TextStyle(fontSize: 15)),
    )),
  ]);

  Widget _results() {
    if (_result == null) return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.bdr)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.document_scanner, color: AC.ts, size: 64),
        const SizedBox(height: 14),
        Text('الصق نص الفاتورة واضغط "استخرج"',
          style: TextStyle(color: AC.ts, fontSize: 14)),
        const SizedBox(height: 6),
        Text('الحقول المستخرجة تظهر هنا',
          style: TextStyle(color: AC.td, fontSize: 12)),
      ]),
    );
    final d = _result!;
    final fields = (d['fields'] ?? []) as List;
    final warnings = (d['warnings'] ?? []) as List;
    final vatValid = d['seller_vat_valid'];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // Summary
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.12), AC.navy3],
            begin: Alignment.topRight, end: Alignment.bottomLeft),
          border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.auto_awesome, color: AC.gold, size: 20),
            const SizedBox(width: 8),
            Text('تم استخراج ${fields.length} حقل',
              style: TextStyle(color: AC.gold, fontSize: 15, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AC.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6)),
              child: Text('${d['raw_text_length']} حرف',
                style: TextStyle(color: AC.info, fontSize: 10, fontFamily: 'monospace')),
            ),
          ]),
          Divider(color: AC.bdr, height: 16),
          if (d['seller_vat'] != null) Row(children: [
            Icon(vatValid == true ? Icons.verified : Icons.warning_amber_rounded,
              color: vatValid == true ? AC.ok : AC.err, size: 16),
            const SizedBox(width: 6),
            Text('VAT: ${d['seller_vat']}',
              style: TextStyle(color: AC.tp, fontSize: 13, fontFamily: 'monospace')),
          ]),
          if (d['total_amount'] != null) Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('الإجمالي: ${d['total_amount']} SAR',
              style: TextStyle(color: AC.gold, fontSize: 18,
                fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          ),
        ]),
      ),
      if (warnings.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AC.warn.withValues(alpha: 0.3))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: AC.warn, size: 14),
              const SizedBox(width: 6),
              Text('تنبيهات', style: TextStyle(color: AC.warn, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text('• $w',
                style: TextStyle(color: AC.tp, fontSize: 11, height: 1.5)),
            )),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      _fieldsTable(fields),
    ]);
  }

  Widget _fieldsTable(List fields) => Container(
    decoration: BoxDecoration(color: AC.navy2,
      borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
    child: Column(children: [
      Container(padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AC.navy3,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
        child: Row(children: [
          Text('الحقول المستخرجة',
            style: TextStyle(color: AC.gold, fontWeight: FontWeight.w800, fontSize: 13)),
        ])),
      ...fields.asMap().entries.map((e) {
        final f = e.value as Map;
        final isLast = e.key == fields.length - 1;
        final conf = f['confidence'] as String? ?? 'low';
        final confColor = conf == 'high' ? AC.ok
          : (conf == 'medium' ? AC.warn : AC.err);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: confColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3)),
                child: Text(conf.toUpperCase(),
                  style: TextStyle(color: confColor, fontSize: 8, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(f['label_ar']?.toString() ?? '',
                style: TextStyle(color: AC.tp, fontSize: 12, fontWeight: FontWeight.w600))),
              Text('${f['value']}',
                style: TextStyle(color: AC.gold, fontSize: 12,
                  fontFamily: 'monospace', fontWeight: FontWeight.w700)),
            ]),
          ),
          if (!isLast) Divider(color: AC.bdr, height: 1),
        ]);
      }),
    ]),
  );
}
