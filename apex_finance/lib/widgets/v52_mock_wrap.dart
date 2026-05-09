/// V52 Mock Banner — wraps a V5.2 mock screen with a "🚧 قيد التطوير"
/// banner so users see the screen renders fixtures, not real data.
///
/// G-FIN-AUDIT-CLEANUP (Sprint 1, 2026-05-09): introduced after
/// the audit at docs/FINANCE_MODULE_AUDIT_2026-05-09.md identified
/// 18 V5.2 chips with no backend wire today. Wrapping at the chip
/// mapping level (in `v5_wired_screens.dart`) means we don't have to
/// edit each V5.2 screen file — one wrapper, 18 mappings.
///
/// The banner is dismissible per-session (state lives in the wrapper).
/// Once a chip's screen is wired to the real backend, drop the
/// `V52MockWrap()` from its mapping in v5_wired_screens.dart.
library;

import 'package:flutter/material.dart';

class V52MockWrap extends StatefulWidget {
  final Widget child;

  /// Optional override of the banner text.
  final String? messageAr;

  const V52MockWrap({
    super.key,
    required this.child,
    this.messageAr,
  });

  @override
  State<V52MockWrap> createState() => _V52MockWrapState();
}

class _V52MockWrapState extends State<V52MockWrap> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          if (!_dismissed) _buildBanner(context),
          Expanded(child: widget.child),
        ],
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    final amber = const Color(0xFFFFF3CD);
    final amberBorder = const Color(0xFFFFE69C);
    final amberText = const Color(0xFF664D03);
    final msg = widget.messageAr ??
        '🚧 قيد التطوير — هذه الشاشة لا تتصل بالـ backend بعد. ستعتمد على بيانات حقيقية في Sprint قادم.';
    return Material(
      color: amber,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: amberBorder, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.construction, color: amberText, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  color: amberText,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _dismissed = true),
              icon: Icon(Icons.close, color: amberText, size: 18),
              tooltip: 'إخفاء',
              splashRadius: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }
}
