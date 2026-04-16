import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import 'dart:html' as html;

/// COA Journey v2 — loads the optimized HTML Prototype fullscreen
/// Contains all 6000+ lines of UI improvements via IFrame overlay
/// JS Bridge connects HTML ↔ Dart for backend API calls
class CoaJourneyV2Screen extends ConsumerStatefulWidget {
  final String clientId;
  final String clientName;

  const CoaJourneyV2Screen({super.key, required this.clientId, this.clientName = ''});

  @override
  ConsumerState<CoaJourneyV2Screen> createState() => _CoaJourneyV2State();
}

class _CoaJourneyV2State extends ConsumerState<CoaJourneyV2Screen> {
  html.IFrameElement? _iframe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mountIframe());
  }

  void _mountIframe() {
    // Hide Flutter canvas
    final glass = html.document.querySelector('flt-glass-pane');
    if (glass != null) (glass as html.HtmlElement).style.display = 'none';

    // Create fullscreen iframe with HTML prototype
    _iframe = html.IFrameElement()
      ..src = 'coa_screen.html'
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100vw'
      ..style.height = '100vh'
      ..style.border = 'none'
      ..style.zIndex = '99999';

    html.document.body?.append(_iframe!);

    // Listen for bridge messages from HTML
    html.window.addEventListener('message', (html.Event event) {
      _handleBridgeMessage(event as html.MessageEvent);
    });
  }

  void _handleBridgeMessage(html.MessageEvent event) {
    if (event.data == null) return;
    try {
      if (event.data is! String) return;
      final data = jsonDecode(event.data as String) as Map<String, dynamic>;
      final action = data['action'];
      switch (action) {
        case 'navigate_back':
          _cleanup();
          Navigator.of(context).maybePop();
          break;
        case 'upload_file':
          // TODO: connect to backend via CoaApiService
          debugPrint('Bridge: upload_file ${data['fileName']}');
          break;
        case 'approve_coa':
          debugPrint('Bridge: approve_coa');
          break;
      }
    } catch (_) {}
  }

  void _cleanup() {
    _iframe?.remove();
    _iframe = null;
    final glass = html.document.querySelector('flt-glass-pane');
    if (glass != null) (glass as html.HtmlElement).style.display = '';
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
