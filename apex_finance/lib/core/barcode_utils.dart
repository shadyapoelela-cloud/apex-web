/// Barcode utilities — G-FIN-PRODUCT-CATALOG (Sprint 4, 2026-05-09).
///
/// Pure-Dart helpers that do not import Flutter or any plugin, so they
/// can be tested under flutter_test without dragging in `package:web`.
///
/// Two functions:
///   * `ean13CheckDigit(prefix12)` — computes the 13th digit of an
///     EAN-13 barcode from its 12-digit prefix using the standard
///     mod-10 weighted-sum algorithm (weights 1,3,1,3,...).
///   * `generateEan13(prefix9)` — given a 9-digit company prefix,
///     produces a candidate EAN-13: prefix + 3 random digits + check
///     digit. Caller is responsible for collision detection against
///     existing barcodes (server-side `/pilot/tenants/{tid}/barcode/{value}`
///     lookup).
library;

import 'dart:math';

/// Returns the EAN-13 check digit (0-9) for a 12-digit numeric prefix.
///
/// Throws `ArgumentError` when input is not exactly 12 digits.
int ean13CheckDigit(String prefix12) {
  if (prefix12.length != 12) {
    throw ArgumentError('EAN-13 prefix must be exactly 12 digits; '
        'got ${prefix12.length}');
  }
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    final d = int.tryParse(prefix12[i]);
    if (d == null) {
      throw ArgumentError('EAN-13 prefix must be all digits; '
          'index $i was "${prefix12[i]}"');
    }
    // Weights alternate 1, 3, 1, 3, ... starting from the leftmost digit.
    sum += d * ((i % 2 == 0) ? 1 : 3);
  }
  final mod = sum % 10;
  return mod == 0 ? 0 : 10 - mod;
}

/// Generates a candidate 13-digit EAN-13 barcode given a 9-digit
/// company prefix. The middle 3 digits are random, the 13th is the
/// check digit.
///
/// Throws `ArgumentError` when input is not exactly 9 digits.
String generateEan13(String companyPrefix9, {Random? random}) {
  if (companyPrefix9.length != 9) {
    throw ArgumentError('company prefix must be exactly 9 digits; '
        'got ${companyPrefix9.length}');
  }
  final r = random ?? Random();
  final middle = r.nextInt(1000).toString().padLeft(3, '0');
  final prefix12 = companyPrefix9 + middle;
  final check = ean13CheckDigit(prefix12);
  return '$prefix12$check';
}
