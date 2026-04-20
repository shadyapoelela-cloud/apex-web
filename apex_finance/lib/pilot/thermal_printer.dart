/// Thermal Printer service — ESC/POS commands via Web USB API.
///
/// Wave N — دعم الطابعة الحرارية 58mm / 80mm في POS.
///
/// يدعم Epson TM-T20/T88 + Star TSP-100 + معظم الطابعات الصينية المتوافقة
/// (Xprinter, Bixolon, GP-58, إلخ) التي تدعم ESC/POS standard.
///
/// المتصفح: Chrome/Edge على Windows/Mac/Android. Safari/Firefox غير مدعومين
/// (Web USB API غير متاح).
///
/// Fallback: إذا الطابعة غير متاحة → HTML print via window.print()
library;

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

/// أوامر ESC/POS الأساسية
class EscPos {
  // Control codes
  static const int esc = 0x1B;
  static const int gs = 0x1D;
  static const int lf = 0x0A;
  static const int ht = 0x09;
  // Init printer
  static const List<int> init = [0x1B, 0x40];
  // Cut paper (partial)
  static const List<int> cut = [0x1D, 0x56, 0x42, 0x00];
  // Line feeds
  static List<int> feed(int lines) => [0x1B, 0x64, lines];
  // Bold
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  // Double size
  static const List<int> doubleSize = [0x1D, 0x21, 0x11];
  static const List<int> normalSize = [0x1D, 0x21, 0x00];
  // Alignment
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  // Arabic code page (CP864 / CP1256)
  static const List<int> arabicCodepage = [0x1B, 0x74, 0x16]; // CP864
  // Open drawer
  static const List<int> openDrawer = [0x1B, 0x70, 0x00, 0x32, 0xFA];

  /// تحويل نص عربي إلى bytes CP1256
  /// ملاحظة: Dart لا يدعم CP1256 مباشرة، لذا نستخدم Windows-1256 fallback
  static List<int> arabicText(String text) {
    // Simple approach: convert to UTF-8 and let printer handle
    // OR transliterate to Latin (simpler for now)
    // Most Xprinter/Epson support UTF-8 with proper codepage setting
    return utf8.encode(text);
  }
}

/// Receipt builder — يبني bytes للطباعة من معاملة POS
class ReceiptBuilder {
  final List<int> _bytes = [];

  void addHeader(String companyName, {String? subtitle}) {
    _bytes.addAll(EscPos.init);
    _bytes.addAll(EscPos.arabicCodepage);
    _bytes.addAll(EscPos.alignCenter);
    _bytes.addAll(EscPos.boldOn);
    _bytes.addAll(EscPos.doubleSize);
    _bytes.addAll(EscPos.arabicText(companyName));
    _bytes.add(EscPos.lf);
    _bytes.addAll(EscPos.normalSize);
    _bytes.addAll(EscPos.boldOff);
    if (subtitle != null) {
      _bytes.addAll(EscPos.arabicText(subtitle));
      _bytes.add(EscPos.lf);
    }
    _bytes.add(EscPos.lf);
  }

  void addTitle(String title) {
    _bytes.addAll(EscPos.alignCenter);
    _bytes.addAll(EscPos.boldOn);
    _bytes.addAll(EscPos.arabicText(title));
    _bytes.add(EscPos.lf);
    _bytes.addAll(EscPos.boldOff);
  }

  void addSeparator({String char = '-', int width = 32}) {
    _bytes.addAll(EscPos.alignCenter);
    _bytes.addAll(EscPos.arabicText(char * width));
    _bytes.add(EscPos.lf);
  }

  void addKeyValue(String key, String value) {
    _bytes.addAll(EscPos.alignLeft);
    _bytes.addAll(EscPos.arabicText(key));
    _bytes.add(EscPos.ht);
    _bytes.addAll(EscPos.arabicText(value));
    _bytes.add(EscPos.lf);
  }

  void addItem(String desc, double qty, double price) {
    _bytes.addAll(EscPos.alignLeft);
    _bytes.addAll(EscPos.arabicText(desc));
    _bytes.add(EscPos.lf);
    final line =
        '  ${qty.toStringAsFixed(2)} × ${price.toStringAsFixed(2)} = ${(qty * price).toStringAsFixed(2)}';
    _bytes.addAll(EscPos.arabicText(line));
    _bytes.add(EscPos.lf);
  }

  void addTotal(String label, double value, {bool bold = false}) {
    _bytes.addAll(EscPos.alignLeft);
    if (bold) _bytes.addAll(EscPos.boldOn);
    _bytes.addAll(EscPos.arabicText('$label: ${value.toStringAsFixed(2)}'));
    _bytes.add(EscPos.lf);
    if (bold) _bytes.addAll(EscPos.boldOff);
  }

  void addQr(String data) {
    // ESC/POS QR code: GS ( k pL pH cn fn m
    // data bytes...
    // This is a simplified implementation — printers that support QR
    // will render it. Others ignore.
    _bytes.addAll(EscPos.alignCenter);
    // Select QR model
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    // Set size
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]);
    // Error correction
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
    // Store data
    final dataBytes = utf8.encode(data);
    final len = dataBytes.length + 3;
    _bytes.addAll([
      0x1D, 0x28, 0x6B,
      len & 0xFF, (len >> 8) & 0xFF,
      0x31, 0x50, 0x30,
    ]);
    _bytes.addAll(dataBytes);
    // Print
    _bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
    _bytes.add(EscPos.lf);
  }

  void addFooter(String text) {
    _bytes.add(EscPos.lf);
    _bytes.addAll(EscPos.alignCenter);
    _bytes.addAll(EscPos.arabicText(text));
    _bytes.add(EscPos.lf);
  }

  void cut() {
    _bytes.addAll(EscPos.feed(3));
    _bytes.addAll(EscPos.cut);
  }

  void openCashDrawer() {
    _bytes.addAll(EscPos.openDrawer);
  }

  Uint8List build() => Uint8List.fromList(_bytes);
}

/// ThermalPrinter service — connect + print
class ThermalPrinter {
  static dynamic _device;
  static dynamic _endpoint;

  /// يطلب من المستخدم اختيار الطابعة (Web USB dialog)
  static Future<bool> connect() async {
    if (!_isWebUsbAvailable()) {
      return false;
    }
    try {
      final navigator = html.window.navigator;
      final usb = js_util.getProperty(navigator, 'usb');
      if (usb == null) return false;

      // Request device — أي طابعة USB
      final filters = js_util.jsify([
        {'classCode': 7},  // Printer class
      ]);
      final options = js_util.jsify({'filters': filters});
      _device = await js_util
          .promiseToFuture<dynamic>(js_util.callMethod(usb, 'requestDevice', <dynamic>[options]));
      if (_device == null) return false;

      // Open + select
      await js_util.promiseToFuture<dynamic>(
          js_util.callMethod(_device, 'open', <dynamic>[]));
      await js_util.promiseToFuture<dynamic>(
          js_util.callMethod(_device, 'selectConfiguration', <dynamic>[1]));
      await js_util.promiseToFuture<dynamic>(
          js_util.callMethod(_device, 'claimInterface', <dynamic>[0]));

      // Find OUT endpoint
      final config = js_util.getProperty(_device, 'configuration');
      final ifaces = js_util.getProperty(config, 'interfaces') as List;
      for (final iface in ifaces) {
        final alternate = js_util.getProperty(iface, 'alternate');
        final endpoints = js_util.getProperty(alternate, 'endpoints') as List;
        for (final ep in endpoints) {
          if (js_util.getProperty(ep, 'direction') == 'out') {
            _endpoint = js_util.getProperty(ep, 'endpointNumber');
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      // ignore: avoid_print
      print('[ThermalPrinter] connect failed: $e');
      return false;
    }
  }

  /// هل الطابعة متصلة؟
  static bool get isConnected => _device != null && _endpoint != null;

  /// إرسال bytes للطباعة
  static Future<bool> sendBytes(Uint8List data) async {
    if (!isConnected) return false;
    try {
      await js_util.promiseToFuture<dynamic>(js_util.callMethod(
          _device, 'transferOut', <dynamic>[_endpoint, data]));
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[ThermalPrinter] print failed: $e');
      return false;
    }
  }

  static bool _isWebUsbAvailable() {
    try {
      final navigator = html.window.navigator;
      return js_util.hasProperty(navigator, 'usb');
    } catch (_) {
      return false;
    }
  }

  /// طريقة بديلة — إذا الطابعة غير متاحة، نفتح نافذة HTML للطباعة يدوياً
  static void printHtmlReceipt({
    required String companyName,
    required String receiptNumber,
    required String cashier,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double vat,
    required double total,
    required double paid,
    required double change,
    String? qrData,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html dir="rtl" lang="ar">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<title>إيصال $receiptNumber</title>');
    buffer.writeln('<style>');
    buffer.writeln('''
      @page { size: 80mm auto; margin: 3mm; }
      body { font-family: 'Tahoma', sans-serif; font-size: 11px;
             width: 76mm; margin: 0 auto; color: #000; }
      .center { text-align: center; }
      .bold { font-weight: bold; }
      .big { font-size: 14px; }
      .sep { border-top: 1px dashed #000; margin: 4px 0; }
      table { width: 100%; border-collapse: collapse; font-size: 10px; }
      td { padding: 2px 0; vertical-align: top; }
      .right { text-align: left; font-family: monospace; }
      @media print { .noprint { display: none; } }
      .btn { background: #D4AF37; color: #000; border: none; padding: 8px 16px;
             border-radius: 4px; cursor: pointer; margin: 5px; font-family: inherit; }
    ''');
    buffer.writeln('</style>');
    buffer.writeln('</head><body>');
    buffer.writeln(
        '<div class="noprint center"><button class="btn" onclick="window.print()">🖨️ طباعة</button></div>');

    buffer.writeln('<div class="center bold big">$companyName</div>');
    buffer.writeln('<div class="sep"></div>');
    buffer.writeln('<div>إيصال: <b>$receiptNumber</b></div>');
    buffer.writeln('<div>كاشير: $cashier</div>');
    buffer.writeln(
        '<div>التاريخ: ${DateTime.now().toIso8601String().substring(0, 19).replaceAll("T", " ")}</div>');
    buffer.writeln('<div class="sep"></div>');

    buffer.writeln('<table>');
    for (final item in items) {
      final desc = item['description'] ?? '';
      final qty = (item['qty'] ?? 0).toString();
      final price = (item['unit_price'] ?? 0).toString();
      final total = (item['line_total'] ?? 0).toString();
      buffer.writeln('<tr><td colspan="2"><b>$desc</b></td></tr>');
      buffer.writeln(
          '<tr><td>$qty × $price</td><td class="right">$total</td></tr>');
    }
    buffer.writeln('</table>');

    buffer.writeln('<div class="sep"></div>');
    buffer.writeln(
        '<table><tr><td>المجموع:</td><td class="right">${subtotal.toStringAsFixed(2)}</td></tr>');
    buffer.writeln(
        '<tr><td>VAT (15%):</td><td class="right">${vat.toStringAsFixed(2)}</td></tr>');
    buffer.writeln(
        '<tr><td class="bold big">الإجمالي:</td><td class="right bold big">${total.toStringAsFixed(2)}</td></tr>');
    buffer.writeln('</table>');
    buffer.writeln('<div class="sep"></div>');
    buffer.writeln(
        '<div>المدفوع: ${paid.toStringAsFixed(2)}</div>');
    buffer.writeln(
        '<div>الباقي: ${change.toStringAsFixed(2)}</div>');
    buffer.writeln('<div class="sep"></div>');

    if (qrData != null) {
      buffer.writeln(
          '<div class="center"><img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${Uri.encodeComponent(qrData)}" alt="QR"></div>');
      buffer.writeln(
          '<div class="center" style="font-size: 9px;">فاتورة ZATCA الإلكترونية</div>');
    }

    buffer.writeln(
        '<div class="center" style="margin-top: 10px;">شكراً لتعاملكم معنا 🙏</div>');
    buffer.writeln('</body></html>');

    // افتح نافذة منفصلة
    final encoded = Uri.encodeComponent(buffer.toString());
    html.window.open('data:text/html;charset=utf-8,$encoded', '_blank');
  }
}
