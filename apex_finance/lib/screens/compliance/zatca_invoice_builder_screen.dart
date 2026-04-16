/// APEX Platform — ZATCA Invoice Builder
/// ═══════════════════════════════════════════════════════════════
/// End-to-end UI for building a ZATCA Phase 2 compliant simplified
/// (B2C) e-invoice. Calls /zatca/invoice/build and renders:
///   - invoice number + ICV
///   - UBL 2.1 XML preview (expandable)
///   - SHA-256 hash
///   - Scannable QR code (TLV base64)
///   - Totals (subtotal / VAT / grand total)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class ZatcaInvoiceBuilderScreen extends StatefulWidget {
  const ZatcaInvoiceBuilderScreen({super.key});
  @override
  State<ZatcaInvoiceBuilderScreen> createState() => _ZatcaInvoiceBuilderScreenState();
}

class _ZatcaLine {
  final nameC = TextEditingController();
  final qtyC = TextEditingController(text: '1');
  final priceC = TextEditingController();
  String vatRate = '15';

  void dispose() {
    nameC.dispose();
    qtyC.dispose();
    priceC.dispose();
  }
}

class _ZatcaInvoiceBuilderScreenState extends State<ZatcaInvoiceBuilderScreen> {
  // Seller
  final _sellerNameC = TextEditingController();
  final _sellerVatC = TextEditingController();
  final _sellerCrC = TextEditingController();
  final _sellerCityC = TextEditingController();

  // Invoice context
  final _clientIdC = TextEditingController();
  final _fiscalYearC = TextEditingController(text: DateTime.now().year.toString());
  String _currency = 'SAR';

  // Lines
  final List<_ZatcaLine> _lines = [_ZatcaLine()];

  // State
  bool _loading = false;
  bool _vatTouched = false;
  bool? _vatValid;
  String? _vatValidReason;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _sellerNameC.dispose();
    _sellerVatC.dispose();
    _sellerCrC.dispose();
    _sellerCityC.dispose();
    _clientIdC.dispose();
    _fiscalYearC.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  // ── Live VAT check (debounced on blur)
  Future<void> _checkVat() async {
    final v = _sellerVatC.text.trim();
    if (v.isEmpty) {
      setState(() { _vatValid = null; _vatValidReason = null; });
      return;
    }
    final r = await ApiService.zatcaValidateVat(v);
    if (!mounted) return;
    if (r.success && r.data is Map) {
      final d = (r.data['data'] ?? r.data) as Map<String, dynamic>;
      setState(() {
        _vatValid = d['valid'] == true;
        _vatValidReason = (d['reason'] ?? '').toString();
      });
    }
  }

  void _addLine() {
    setState(() => _lines.add(_ZatcaLine()));
  }

  void _removeLine(int idx) {
    if (_lines.length <= 1) return;
    setState(() {
      _lines[idx].dispose();
      _lines.removeAt(idx);
    });
  }

  String? _validate() {
    if (_sellerNameC.text.trim().isEmpty) return 'اسم البائع مطلوب';
    if (_sellerVatC.text.trim().length != 15) return 'رقم التسجيل الضريبي 15 رقم';
    if (_vatValid == false) return 'رقم التسجيل الضريبي غير صالح';
    if (_clientIdC.text.trim().isEmpty) return 'معرّف العميل مطلوب';
    if (_fiscalYearC.text.trim().length != 4) return 'السنة المالية (4 أرقام)';
    for (var i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.nameC.text.trim().isEmpty) return 'سطر ${i + 1}: الاسم مطلوب';
      if ((double.tryParse(l.qtyC.text.trim()) ?? 0) <= 0) {
        return 'سطر ${i + 1}: الكمية يجب أن تكون أكبر من صفر';
      }
      if ((double.tryParse(l.priceC.text.trim()) ?? -1) < 0) {
        return 'سطر ${i + 1}: السعر غير صحيح';
      }
    }
    return null;
  }

  Future<void> _build() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final body = {
        'seller': {
          'name': _sellerNameC.text.trim(),
          'vat_number': _sellerVatC.text.trim(),
          if (_sellerCrC.text.trim().isNotEmpty) 'cr_number': _sellerCrC.text.trim(),
          if (_sellerCityC.text.trim().isNotEmpty) 'address_city': _sellerCityC.text.trim(),
          'country_code': 'SA',
        },
        'lines': _lines.map((l) => {
          'name': l.nameC.text.trim(),
          'quantity': l.qtyC.text.trim(),
          'unit_price': l.priceC.text.trim(),
          'vat_rate': l.vatRate,
          'discount': '0',
        }).toList(),
        'client_id': _clientIdC.text.trim(),
        'fiscal_year': _fiscalYearC.text.trim(),
        'currency': _currency,
      };
      final r = await ApiService.zatcaBuildInvoice(body);
      if (!mounted) return;
      if (r.success && r.data is Map) {
        setState(() => _result = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل بناء الفاتورة');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: Text('منشئ الفاتورة (ZATCA)', style: TextStyle(color: AC.gold)),
        backgroundColor: AC.navy2,
      ),
      body: LayoutBuilder(builder: (ctx, cons) {
        final wide = cons.maxWidth > 960;
        final form = _buildForm();
        final result = _buildResult();
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [form, const SizedBox(height: 16), result]),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: form,
              ),
            ),
            Container(width: 1, color: AC.bdr),
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: result,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ── Left column: form ──────────────────────────────────────────

  Widget _buildForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section('بيانات البائع'),
      _field(_sellerNameC, 'اسم البائع *', Icons.business),
      _vatField(),
      _field(_sellerCrC, 'رقم السجل التجاري', Icons.description),
      _field(_sellerCityC, 'المدينة', Icons.location_city),
      const SizedBox(height: 16),
      _section('سياق الفاتورة'),
      _field(_clientIdC, 'معرّف العميل *', Icons.person),
      Row(children: [
        Expanded(
          child: _field(_fiscalYearC, 'السنة المالية', Icons.calendar_today,
            keyboard: TextInputType.number, maxLength: 4),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: _currency,
              decoration: _inpDec('العملة', Icons.payments),
              dropdownColor: AC.navy2,
              style: TextStyle(color: AC.tp, fontSize: 14),
              items: const ['SAR', 'AED', 'KWD', 'BHD', 'QAR', 'OMR', 'EGP', 'USD']
                .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) { if (v != null) setState(() => _currency = v); },
            ),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      _section('بنود الفاتورة'),
      ..._lines.asMap().entries.map((e) => _buildLine(e.key, e.value)),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _addLine,
        icon: const Icon(Icons.add),
        label: const Text('إضافة سطر'),
      ),
      const SizedBox(height: 16),
      if (_error != null) _errorBanner(_error!),
      const SizedBox(height: 8),
      SizedBox(
        height: 54,
        child: ElevatedButton.icon(
          onPressed: _loading ? null : _build,
          icon: _loading
            ? const SizedBox(height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.receipt_long),
          label: const Text('بناء الفاتورة + QR', style: TextStyle(fontSize: 16)),
        ),
      ),
    ],
  );

  Widget _buildLine(int idx, _ZatcaLine line) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(children: [
      Row(children: [
        Text('سطر ${idx + 1}',
          style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700)),
        const Spacer(),
        if (_lines.length > 1)
          IconButton(
            icon: Icon(Icons.delete_outline, color: AC.err, size: 20),
            onPressed: () => _removeLine(idx),
            tooltip: 'حذف',
          ),
      ]),
      _field(line.nameC, 'اسم الصنف *', Icons.label),
      Row(children: [
        Expanded(
          child: _field(line.qtyC, 'الكمية', Icons.numbers,
            keyboard: TextInputType.number),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _field(line.priceC, 'سعر الوحدة (دون VAT)', Icons.attach_money,
            keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: line.vatRate,
              decoration: _inpDec('VAT%', null),
              dropdownColor: AC.navy2,
              style: TextStyle(color: AC.tp, fontSize: 13),
              items: const ['0', '5', '15'].map((v) =>
                DropdownMenuItem(value: v, child: Text('$v%'))).toList(),
              onChanged: (v) { if (v != null) setState(() => line.vatRate = v); },
            ),
          ),
        ),
      ]),
    ]),
  );

  Widget _vatField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: _sellerVatC,
      keyboardType: TextInputType.number,
      maxLength: 15,
      style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
      onChanged: (v) {
        if (v.length == 15 && !_vatTouched) _vatTouched = true;
        if (v.length == 15) _checkVat();
        else if (_vatValid != null) setState(() { _vatValid = null; _vatValidReason = null; });
      },
      decoration: _inpDec('رقم التسجيل الضريبي (VAT) — 15 رقم *', Icons.qr_code_2).copyWith(
        counterText: '',
        suffixIcon: _vatValid == true
            ? Icon(Icons.check_circle, color: AC.ok, size: 22)
            : _vatValid == false
                ? Icon(Icons.error_outline, color: AC.err, size: 22)
                : null,
        helperText: _vatValidReason?.isNotEmpty == true
            ? _vatValidReason
            : 'يجب أن يبدأ وينتهي بالرقم 3',
        helperStyle: TextStyle(
          color: _vatValid == false ? AC.err : AC.ts,
          fontSize: 11,
        ),
      ),
    ),
  );

  // ── Right column: result ───────────────────────────────────────

  Widget _buildResult() {
    if (_result == null) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AC.navy2.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AC.bdr, style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, color: AC.ts, size: 64),
            const SizedBox(height: 16),
            Text('املأ النموذج ثم اضغط "بناء الفاتورة"',
              style: TextStyle(color: AC.ts, fontSize: 14)),
            const SizedBox(height: 8),
            Text('سترى QR والـ XML والهاش هنا',
              style: TextStyle(color: AC.td, fontSize: 12)),
          ],
        ),
      );
    }
    final d = _result!;
    final totals = (d['totals'] ?? {}) as Map;
    final warnings = (d['warnings'] ?? []) as List;
    final qrB64 = (d['qr_base64'] ?? '').toString();
    final hashB64 = (d['invoice_hash_b64'] ?? '').toString();
    final xml = (d['xml'] ?? '').toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _successBanner(d),
        const SizedBox(height: 14),
        _qrCard(qrB64),
        const SizedBox(height: 14),
        _totalsCard(totals),
        const SizedBox(height: 14),
        _hashCard(hashB64),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 14),
          _warningsCard(warnings),
        ],
        const SizedBox(height: 14),
        _xmlCard(xml),
      ],
    );
  }

  Widget _successBanner(Map<String, dynamic> d) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.ok.withValues(alpha: 0.10),
      border: Border.all(color: AC.ok.withValues(alpha: 0.4), width: 1.5),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(children: [
      Icon(Icons.verified, color: AC.ok, size: 30),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تم بناء الفاتورة',
            style: TextStyle(color: AC.ok, fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 2),
          Text('${d['invoice_number']}  ·  ICV=${d['icv']}',
            style: TextStyle(color: AC.tp, fontSize: 13, fontFamily: 'monospace')),
        ],
      )),
    ]),
  );

  Widget _qrCard(String qrB64) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: [
      Text('رمز QR للفاتورة',
        style: TextStyle(color: AC.navy, fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 12),
      QrImageView(
        data: qrB64,
        version: QrVersions.auto,
        size: 220,
        backgroundColor: Colors.white,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      ),
      const SizedBox(height: 10),
      Text('امسحه بتطبيق ZATCA للتحقق',
        style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
      const SizedBox(height: 6),
      SelectableText(qrB64.length > 60 ? '${qrB64.substring(0, 60)}…' : qrB64,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 10, fontFamily: 'monospace')),
    ]),
  );

  Widget _totalsCard(Map totals) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(children: [
      _kv('المجموع قبل الضريبة', '${totals['subtotal']} ${totals['currency']}'),
      _kv('الضريبة (VAT)', '${totals['vat_total']} ${totals['currency']}', vc: AC.warn),
      Divider(color: AC.bdr),
      _kv('الإجمالي', '${totals['total']} ${totals['currency']}',
        vc: AC.gold, bold: true),
    ]),
  );

  Widget _hashCard(String hash) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.fingerprint, color: AC.gold, size: 18),
          const SizedBox(width: 6),
          Text('SHA-256 Hash', style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.copy, color: AC.ts, size: 16),
            tooltip: 'نسخ',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: hash));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('تم نسخ الهاش'), backgroundColor: AC.ok));
            },
          ),
        ]),
        SelectableText(hash,
          style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace')),
      ],
    ),
  );

  Widget _warningsCard(List warnings) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AC.warn.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AC.warn.withValues(alpha: 0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: AC.warn, size: 18),
          const SizedBox(width: 6),
          Text('تنبيهات', style: TextStyle(color: AC.warn, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        ...warnings.map((w) => Text('• $w',
          style: TextStyle(color: AC.tp, fontSize: 12))),
      ],
    ),
  );

  Widget _xmlCard(String xml) => ExpansionTile(
    backgroundColor: AC.navy2,
    collapsedBackgroundColor: AC.navy2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AC.bdr)),
    collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AC.bdr)),
    leading: Icon(Icons.code, color: AC.gold),
    title: Text('UBL 2.1 XML Preview',
      style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700)),
    subtitle: Text('${xml.length} حرف',
      style: TextStyle(color: AC.ts, fontSize: 11)),
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AC.navy,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(xml,
          style: TextStyle(color: AC.tp, fontSize: 10, fontFamily: 'monospace', height: 1.4)),
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Row(children: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: xml));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('تم نسخ XML'), backgroundColor: AC.ok));
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('نسخ XML'),
          ),
        ]),
      ),
    ],
  );

  // ── Helpers ────────────────────────────────────────────────────

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 6),
    child: Row(children: [
      Container(width: 4, height: 20, decoration: BoxDecoration(
        color: AC.gold, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(
        color: AC.tp, fontSize: 15, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _field(TextEditingController c, String label, IconData icon,
      {TextInputType? keyboard, int? maxLength}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        maxLength: maxLength,
        style: TextStyle(color: AC.tp),
        decoration: _inpDec(label, icon).copyWith(counterText: ''),
      ),
    );

  InputDecoration _inpDec(String label, IconData? icon) => InputDecoration(
    labelText: label,
    prefixIcon: icon != null ? Icon(icon, color: AC.goldText, size: 20) : null,
    filled: true,
    fillColor: AC.navy3,
    labelStyle: TextStyle(color: AC.ts),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AC.goldText),
    ),
  );

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AC.err.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AC.err.withValues(alpha: 0.35)),
    ),
    child: Row(children: [
      Icon(Icons.error_outline, color: AC.err, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: TextStyle(color: AC.err, fontSize: 13))),
    ]),
  );

  Widget _kv(String k, String v, {Color? vc, bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: TextStyle(color: AC.ts, fontSize: 13)),
        Text(v, style: TextStyle(
          color: vc ?? AC.tp,
          fontSize: bold ? 16 : 13,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          fontFamily: 'monospace',
        )),
      ],
    ),
  );
}
