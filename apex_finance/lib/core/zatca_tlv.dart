/// ZATCA Phase 1 TLV QR Code helper.
///
/// G-SALES-INVOICE-UX-COMPLETE (2026-05-10): pure Dart helper that
/// builds the Tag-Length-Value byte string ZATCA Phase 1 mandates on
/// every B2C simplified-tax invoice, then base64-encodes it for
/// embedding in a QR code.
///
/// **Why this exists**: ZATCA QR is required on every issued invoice.
/// Encoding it on the client (rather than server) means we can render
/// the QR for in-progress drafts in print-preview without a round trip.
/// Backend signature/CSID tags (Tag 6+) belong to Phase 2 and are
/// added by the server-side ZATCA submission service — out of scope
/// for this helper.
///
/// Tag schedule (Phase 1):
///
///   Tag 1 — Seller name (UTF-8)
///   Tag 2 — VAT registration number (15 digits, ASCII)
///   Tag 3 — Invoice timestamp (ISO 8601, UTC)
///   Tag 4 — Invoice total (with VAT, decimal-as-string)
///   Tag 5 — VAT total (decimal-as-string)
library;

import 'dart:convert';

/// Builds the ZATCA Phase 1 TLV byte string for the given fields.
///
/// All five fields are required. The resulting list of bytes is the raw
/// TLV payload — call [zatcaQrBase64] to get the QR-ready base64 string.
List<int> zatcaTlvBytes({
  required String sellerName,
  required String vatNumber,
  required DateTime invoiceTimestampUtc,
  required String invoiceTotal,
  required String vatTotal,
}) {
  final fields = <_TlvField>[
    _TlvField(1, sellerName),
    _TlvField(2, vatNumber),
    _TlvField(3, invoiceTimestampUtc.toUtc().toIso8601String()),
    _TlvField(4, invoiceTotal),
    _TlvField(5, vatTotal),
  ];
  final out = <int>[];
  for (final f in fields) {
    final value = utf8.encode(f.value);
    if (value.length > 255) {
      throw ArgumentError(
        'TLV value for tag ${f.tag} exceeds single-byte length (255). '
        'Phase 1 spec only supports 1-byte length encoding.',
      );
    }
    out.add(f.tag);
    out.add(value.length);
    out.addAll(value);
  }
  return out;
}

/// Convenience wrapper that returns the TLV payload as a base64 string,
/// ready to be encoded as the QR `data` parameter.
String zatcaQrBase64({
  required String sellerName,
  required String vatNumber,
  required DateTime invoiceTimestampUtc,
  required String invoiceTotal,
  required String vatTotal,
}) {
  return base64Encode(zatcaTlvBytes(
    sellerName: sellerName,
    vatNumber: vatNumber,
    invoiceTimestampUtc: invoiceTimestampUtc,
    invoiceTotal: invoiceTotal,
    vatTotal: vatTotal,
  ));
}

class _TlvField {
  final int tag;
  final String value;
  _TlvField(this.tag, this.value);
}
