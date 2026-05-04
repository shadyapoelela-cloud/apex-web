/// G-CLEANUP-4 (Sprint 15): public "قيد البناء" screen for direct-URL
/// access to disabled `V5MainModule` entries.
///
/// Background: the `V5MainModule.enabled` flag (added Sprint 15 Stage 3)
/// hides non-functional modules from app launchers. But a user could
/// still bookmark or guess a disabled module's URL — e.g.
/// `/app/erp/crm-marketing/dashboard`. Without this screen they'd see
/// either a 404 or the broken empty default. With it, they see an
/// honest "قيد البناء" page that matches the F-018 reference pattern
/// (the existing `Construction` module's empty-state).
///
/// Visual model: lifted from the existing private `_ComingSoonBanner`
/// in `apex_v5_service_shell.dart:3280` so the look-and-feel stays
/// consistent across embedded chip-level placeholders and full-route
/// fallbacks.
///
/// See:
///  - APEX_BLUEPRINT/09 § 20.1 G-CLEANUP-4
///  - APEX_BLUEPRINT/39 § 3.3 (the directive)
///  - apex_finance/lib/core/v5/v5_models.dart V5MainModule.enabled
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart' as core_theme;

/// Full-route fallback shown when the user URL-directs to a disabled
/// module. Designed to live inside `ApexV5ServiceShell.bodyOverride`
/// so the surrounding chrome (top bar, breadcrumb) is provided by the
/// shell — this widget only renders the body content.
class ComingSoonScreen extends StatelessWidget {
  /// Arabic label of the disabled module (e.g. "علاقات العملاء والتسويق").
  final String labelAr;

  /// Service ID for the "العودة" button — sends the user back to the
  /// service's app launcher, e.g. `/app/erp/apps`.
  final String serviceId;

  /// Optional icon — defaults to a generic construction icon.
  final IconData icon;

  const ComingSoonScreen({
    super.key,
    required this.labelAr,
    required this.serviceId,
    this.icon = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: core_theme.AC.td),
              const SizedBox(height: 20),
              Text(
                labelAr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Tajawal',
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'هذه الوحدة قيد البناء — سترى المحتوى الحقيقي قريباً.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: core_theme.AC.ts,
                  fontFamily: 'Tajawal',
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: core_theme.AC.warn.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: core_theme.AC.warn.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'قيد البناء',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/app/$serviceId/apps'),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text(
                  'العودة إلى مركز التطبيقات',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: core_theme.AC.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
