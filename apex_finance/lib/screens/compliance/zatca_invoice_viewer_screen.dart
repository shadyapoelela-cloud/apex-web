/// APEX — ZATCA E-Invoice Viewer (with QR + cleared XML preview)
/// /compliance/zatca-invoice-viewer/:id — Saudi-specific Phase 2 viewer
library;

import 'package:flutter/material.dart';

import '../../core/apex_whatsapp_share.dart';
import '../../core/hijri_date.dart';
import '../../core/theme.dart';

class ZatcaInvoiceViewerScreen extends StatelessWidget {
  final String invoiceId;
  const ZatcaInvoiceViewerScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    // Demo data — to be replaced with real /zatca/invoice/{id} fetch
    final issueDate = DateTime.now();
    final hijri = HijriDate.fromGregorian(issueDate);
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('فاتورة إلكترونية — ZATCA', style: TextStyle(color: AC.gold)),
        actions: [
          ApexWhatsAppShareButton(
            compact: true,
            tooltip: 'مشاركة على واتساب',
            message:
                'فاتورة إلكترونية INV-2026-0042 بقيمة 11,500 ريال — موثّقة من ZATCA',
          ),
          IconButton(
            icon: Icon(Icons.print, color: AC.gold),
            tooltip: 'طباعة',
            onPressed: () {},
          ),
          IconButton(
            icon: Icon(Icons.download, color: AC.gold),
            tooltip: 'تحميل XML',
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _zatcaStatusCard(),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _invoiceBody(issueDate, hijri),
          ),
          const SizedBox(height: 14),
          _xmlSection(),
          const SizedBox(height: 14),
          _auditTrailSection(),
        ]),
      ),
    );
  }

  Widget _zatcaStatusCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.ok.withValues(alpha: 0.10),
          border: Border.all(color: AC.ok.withValues(alpha: 0.5), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.verified, color: AC.ok, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('تمّ التوثيق من ZATCA',
                  style: TextStyle(color: AC.ok, fontSize: 14, fontWeight: FontWeight.w800)),
              Text('UUID: 3a8f9b2c-...4e7d · Cleared at 2026-04-25 14:32:18',
                  style: TextStyle(color: AC.tp, fontSize: 11, fontFamily: 'monospace')),
            ]),
          ),
        ]),
      );

  Widget _invoiceBody(DateTime issue, HijriDate hijri) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(
        child: Text('فاتورة ضريبية',
            style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w900)),
      ),
      Center(
        child: Text('Tax Invoice',
            style: TextStyle(color: Colors.black54, fontSize: 12, letterSpacing: 1)),
      ),
      const Divider(),
      // QR placeholder
      Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12),
          ),
          child: CustomPaint(
            painter: _QrPlaceholderPainter(),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Center(
        child: Text('ZATCA QR Code (TLV)',
            style: TextStyle(color: Colors.black54, fontSize: 9.5)),
      ),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _kv('رقم الفاتورة', 'INV-2026-0042')),
        Expanded(child: _kv('Invoice #', 'INV-2026-0042')),
      ]),
      Row(children: [
        Expanded(child: _kv('التاريخ', '${issue.year}/${issue.month}/${issue.day}')),
        Expanded(child: _kv('Hijri', hijri.formatLong())),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        color: Colors.black.withValues(alpha: 0.04),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('البائع', style: TextStyle(color: Colors.black54, fontSize: 11)),
          Text('شركة الاختبار النهائي',
              style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w700)),
          Text('VAT: 300123456700003',
              style: TextStyle(color: Colors.black54, fontSize: 11, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(10),
        color: Colors.black.withValues(alpha: 0.04),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المشتري', style: TextStyle(color: Colors.black54, fontSize: 11)),
          Text('شركة الدمام للصناعة',
              style: TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w700)),
          Text('VAT: 300555555300003',
              style: TextStyle(color: Colors.black54, fontSize: 11, fontFamily: 'monospace')),
        ]),
      ),
      const SizedBox(height: 16),
      _lineRow('1', 'خدمة استشارية شهرية', '1', '10,000.00', '10,000.00'),
      const Divider(),
      _totalRow('الصافي قبل الضريبة', '10,000.00 SAR'),
      _totalRow('VAT 15%', '1,500.00 SAR'),
      _totalRow('الإجمالي', '11,500.00 SAR', bold: true),
      const SizedBox(height: 16),
      Center(
        child: Text(
            'هذه الفاتورة موثّقة إلكترونياً بختم ZATCA الرقمي · This invoice is digitally cleared by ZATCA',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontSize: 9.5, fontStyle: FontStyle.italic)),
      ),
    ]);
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: TextStyle(color: Colors.black54, fontSize: 10)),
          Text(v,
              style: TextStyle(color: Colors.black87, fontSize: 12, fontFamily: 'monospace')),
        ]),
      );

  Widget _lineRow(String n, String desc, String qty, String price, String total) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 22, child: Text(n, style: TextStyle(color: Colors.black54, fontSize: 11))),
          Expanded(child: Text(desc, style: TextStyle(color: Colors.black87, fontSize: 12))),
          SizedBox(width: 32, child: Text(qty, style: TextStyle(color: Colors.black87, fontSize: 11), textAlign: TextAlign.left)),
          SizedBox(width: 80, child: Text(price, style: TextStyle(color: Colors.black87, fontFamily: 'monospace', fontSize: 11), textAlign: TextAlign.left)),
          SizedBox(width: 90, child: Text(total, style: TextStyle(color: Colors.black87, fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 11), textAlign: TextAlign.left)),
        ]),
      );

  Widget _totalRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label,
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: bold ? 14 : 12,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w400)),
          Text(value,
              style: TextStyle(
                  color: Colors.black87,
                  fontFamily: 'monospace',
                  fontSize: bold ? 16 : 12,
                  fontWeight: bold ? FontWeight.w900 : FontWeight.w400)),
        ]),
      );

  Widget _xmlSection() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.code, color: AC.gold, size: 18),
            const SizedBox(width: 8),
            Text('UBL 2.1 XML (مختصر)',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.black.withValues(alpha: 0.40),
            child: Text(
              '<Invoice xmlns="urn:oasis:names:..."\n'
              '  ProfileID="reporting:1.0"\n'
              '  ID="INV-2026-0042"\n'
              '  IssueDate="${DateTime.now().toIso8601String().substring(0, 10)}"\n'
              '  ...\n'
              '  <Signature>...</Signature>\n'
              '  <PreviousHash>...</PreviousHash>\n'
              '</Invoice>',
              style: TextStyle(color: AC.gold, fontSize: 10.5, fontFamily: 'monospace'),
            ),
          ),
        ]),
      );

  Widget _auditTrailSection() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.06),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.timeline, color: AC.gold),
            const SizedBox(width: 8),
            Text('Audit Trail (Hash-Chain)',
                style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          _trailEvent('14:30:00', 'Invoice Created', AC.info),
          _trailEvent('14:30:15', 'Submitted to ZATCA', AC.warn),
          _trailEvent('14:32:18', 'Cleared by ZATCA · UUID assigned', AC.ok),
          _trailEvent('14:32:18', 'XAdES Signature attached', AC.ok),
          _trailEvent('14:32:19', 'Hash chained to ledger', AC.ok),
        ]),
      );

  Widget _trailEvent(String time, String event, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          SizedBox(
              width: 72,
              child: Text(time,
                  style: TextStyle(color: AC.ts, fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(event, style: TextStyle(color: AC.tp, fontSize: 12))),
        ]),
      );
}

class _QrPlaceholderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    // Render a simple QR-looking pattern (decorative — real QR comes from backend)
    const cell = 7.0;
    final cols = (size.width / cell).floor();
    final rows = (size.height / cell).floor();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Pseudo-random pattern
        if ((r * 7 + c * 13) % 5 < 2) {
          canvas.drawRect(
              Rect.fromLTWH(c * cell, r * cell, cell - 0.5, cell - 0.5), paint);
        }
      }
    }
    // Three corner markers
    final marker = Paint()..color = Colors.black;
    void drawMarker(double x, double y) {
      canvas.drawRect(Rect.fromLTWH(x, y, 21, 21), marker);
      canvas.drawRect(Rect.fromLTWH(x + 3, y + 3, 15, 15), Paint()..color = Colors.white);
      canvas.drawRect(Rect.fromLTWH(x + 6, y + 6, 9, 9), marker);
    }
    drawMarker(4, 4);
    drawMarker(size.width - 25, 4);
    drawMarker(4, size.height - 25);
  }

  @override
  bool shouldRepaint(_) => false;
}
