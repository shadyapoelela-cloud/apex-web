/// APEX — WhatsApp Share button
/// ═══════════════════════════════════════════════════════════════════════
/// Saudi #1 communication channel for SMBs. Per the gap analysis,
/// WhatsApp Business is mandatory on every shareable entity.
///
/// Usage:
///   ApexWhatsAppShareButton(
///     message: 'فاتورة #INV-2026-0042 بمبلغ 11,500 ريال',
///     phoneNumber: '+966501234567', // optional
///   )
///
/// Tapping launches `https://wa.me/{phone}?text={url-encoded message}`.
library;

import 'dart:html' as html;
import 'package:flutter/material.dart';

class ApexWhatsAppShareButton extends StatelessWidget {
  final String message;
  final String? phoneNumber;
  final String? tooltip;
  final bool compact;

  const ApexWhatsAppShareButton({
    super.key,
    required this.message,
    this.phoneNumber,
    this.tooltip,
    this.compact = false,
  });

  void _launch() {
    final phone = phoneNumber?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
    final encoded = Uri.encodeComponent(message);
    final url = phone.isEmpty
        ? 'https://wa.me/?text=$encoded'
        : 'https://wa.me/$phone?text=$encoded';
    html.window.open(url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return IconButton(
        icon: Icon(Icons.share, color: const Color(0xFF25D366), size: 18),
        tooltip: tooltip ?? 'مشاركة على واتساب',
        onPressed: _launch,
      );
    }
    return ElevatedButton.icon(
      onPressed: _launch,
      icon: const Icon(Icons.share, size: 16),
      label: const Text('شارك على واتساب'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF25D366), // WhatsApp green
        foregroundColor: Colors.white,
      ),
    );
  }
}
