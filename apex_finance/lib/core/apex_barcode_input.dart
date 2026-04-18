/// APEX Barcode Input — hardware-scanner + manual-type widget.
///
/// Most warehouses use USB/Bluetooth barcode guns that act as HID
/// keyboards: they type the code then hit Enter. This widget listens
/// for that pattern (fast sequence of keystrokes ending with Enter)
/// and fires [onScan]. Falls back to a plain TextField for manual
/// entry when no scanner is connected.
///
/// Supports EAN-13, Code 128, UPC-A, QR data — basically anything the
/// gun types. Validates length / charset if [validate] is passed.
///
/// We don't touch the device camera here because the Web target can't
/// reliably access it from inside a Flutter canvas app; pair this with
/// a native channel later when you ship mobile.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';
import 'theme.dart';

typedef BarcodeValidator = String? Function(String code);

class ApexBarcodeInput extends StatefulWidget {
  final String label;
  final String? hint;

  /// Called on Enter or scanner end.
  final ValueChanged<String> onScan;

  /// Optional validator; return null = valid, string = error.
  final BarcodeValidator? validate;

  /// If true, focus autofocuses on mount (typical for "scan next item"
  /// receiving workflow).
  final bool autofocus;

  const ApexBarcodeInput({
    super.key,
    required this.onScan,
    this.label = 'باركود',
    this.hint = 'امسح أو اكتب يدوياً...',
    this.validate,
    this.autofocus = true,
  });

  @override
  State<ApexBarcodeInput> createState() => _ApexBarcodeInputState();
}

class _ApexBarcodeInputState extends State<ApexBarcodeInput> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  DateTime _lastKey = DateTime.fromMillisecondsSinceEpoch(0);
  bool _likelyScanner = false;
  String? _error;
  String? _lastScan;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _commit(_controller.text);
    }
  }

  void _commit(String raw) {
    final code = raw.trim();
    if (code.isEmpty) return;
    final err = widget.validate?.call(code);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _lastScan = code;
      _controller.clear();
    });
    widget.onScan(code);
    // Keep focus for the next scan in a batch workflow.
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.qr_code_scanner, size: 20, color: AC.gold),
            const SizedBox(width: AppSpacing.sm),
            Text(widget.label,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w700)),
            const Spacer(),
            if (_lastScan != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AC.ok.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AC.ok.withValues(alpha: 0.5)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check, size: 12, color: AC.ok),
                  const SizedBox(width: 4),
                  Text('آخر: $_lastScan',
                      style: TextStyle(
                          color: AC.ok,
                          fontSize: AppFontSize.xs,
                          fontFamily: 'monospace')),
                ]),
              ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: _handleKey,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: Icon(Icons.barcode_reader, color: AC.gold),
                errorText: _error,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AC.bdr),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: AC.gold, width: 2),
                ),
              ),
              style: TextStyle(
                  color: AC.tp,
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.base),
              onSubmitted: _commit,
              onChanged: (_) {
                // Best-effort scanner detection via inter-key timing.
                final now = DateTime.now();
                if (now.difference(_lastKey).inMilliseconds < 30) {
                  if (!_likelyScanner) {
                    setState(() => _likelyScanner = true);
                  }
                }
                _lastKey = now;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Icon(
              _likelyScanner
                  ? Icons.sensors
                  : Icons.keyboard_alt_outlined,
              size: 12,
              color: AC.td,
            ),
            const SizedBox(width: 4),
            Text(
              _likelyScanner
                  ? 'اكتُشف جهاز مسح — اتركه يعمل'
                  : 'اكتب يدوياً أو وصّل ماسحاً — Enter للتأكيد',
              style: TextStyle(color: AC.td, fontSize: AppFontSize.xs),
            ),
          ]),
        ],
      ),
    );
  }
}
