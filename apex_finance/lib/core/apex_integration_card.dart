/// APEX Integration Marketplace Card — like Shopify / Stripe / Xero app
/// store tiles. Each card represents one third-party connector (bank
/// feed, e-commerce, payroll, POS, etc.) the tenant can enable.
///
/// States:
///   • available  → "Install" primary button
///   • connected  → green "Connected" badge + "Configure" outline button
///   • pending    → amber badge (waiting for OAuth or secret)
///   • failed     → red badge + "Reconnect" button
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';
import 'theme.dart' as core_theme;

enum IntegrationStatus { available, connected, pending, failed }

class IntegrationTile {
  final String id;
  final String name;
  final String vendor;
  final String category;
  final String description;
  final IconData icon;
  final Color accent;
  final IntegrationStatus status;
  final List<String> capabilities;
  final String? priceMonthly; // e.g. "99 ر.س / شهر"

  const IntegrationTile({
    required this.id,
    required this.name,
    required this.vendor,
    required this.category,
    required this.description,
    required this.icon,
    required this.accent,
    this.status = IntegrationStatus.available,
    this.capabilities = const [],
    this.priceMonthly,
  });

  IntegrationTile withStatus(IntegrationStatus s) => IntegrationTile(
        id: id,
        name: name,
        vendor: vendor,
        category: category,
        description: description,
        icon: icon,
        accent: accent,
        status: s,
        capabilities: capabilities,
        priceMonthly: priceMonthly,
      );
}

class ApexIntegrationCard extends StatelessWidget {
  final IntegrationTile tile;
  final VoidCallback? onInstall;
  final VoidCallback? onConfigure;
  final VoidCallback? onReconnect;
  final VoidCallback? onDisconnect;

  const ApexIntegrationCard({
    super.key,
    required this.tile,
    this.onInstall,
    this.onConfigure,
    this.onReconnect,
    this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${tile.name} من ${tile.vendor} — الحالة: ${_statusLabel(tile.status)}',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: tile.status == IntegrationStatus.connected
                ? AC.ok.withValues(alpha: 0.5)
                : AC.bdr,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: tile.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(tile.icon, color: tile.accent, size: 24),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tile.name,
                          style: TextStyle(
                              color: AC.tp,
                              fontSize: AppFontSize.base,
                              fontWeight: FontWeight.w700)),
                      Text(tile.vendor,
                          style: TextStyle(
                              color: AC.td, fontSize: AppFontSize.xs)),
                    ]),
              ),
              _statusPill(tile.status),
            ]),
            const SizedBox(height: AppSpacing.sm),
            Text(tile.description,
                style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.sm,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (tile.capabilities.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final c in tile.capabilities)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AC.navy3,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: AC.bdr),
                      ),
                      child: Text(c,
                          style: TextStyle(
                              color: AC.ts,
                              fontSize: AppFontSize.xs)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              if (tile.priceMonthly != null)
                Expanded(
                  child: Text(tile.priceMonthly!,
                      style: TextStyle(
                          color: AC.gold,
                          fontSize: AppFontSize.xs,
                          fontWeight: FontWeight.w700)),
                )
              else
                Expanded(
                  child: Text('مجاني',
                      style: TextStyle(
                          color: AC.ok,
                          fontSize: AppFontSize.xs,
                          fontWeight: FontWeight.w700)),
                ),
              _primaryAction(),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _primaryAction() {
    return switch (tile.status) {
      IntegrationStatus.available => FilledButton(
          onPressed: onInstall,
          style: FilledButton.styleFrom(
            backgroundColor: tile.accent,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          ),
          child: const Text('تثبيت'),
        ),
      IntegrationStatus.connected => OutlinedButton(
          onPressed: onConfigure,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          ),
          child: const Text('إعداد'),
        ),
      IntegrationStatus.pending => Text('بانتظار الموافقة',
          style: TextStyle(
              color: core_theme.AC.warn,
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600)),
      IntegrationStatus.failed => FilledButton(
          onPressed: onReconnect,
          style: FilledButton.styleFrom(
            backgroundColor: AC.err,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          ),
          child: const Text('إعادة الاتصال'),
        ),
    };
  }

  Widget _statusPill(IntegrationStatus s) {
    final (color, label, icon) = switch (s) {
      IntegrationStatus.connected => (AC.ok, 'متصل', Icons.check_circle),
      IntegrationStatus.pending =>
        (core_theme.AC.warn, 'معلّق', Icons.hourglass_bottom),
      IntegrationStatus.failed => (AC.err, 'فشل', Icons.error),
      IntegrationStatus.available =>
        (AC.ts, 'متاح', Icons.download),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: AppFontSize.xs,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  static String _statusLabel(IntegrationStatus s) => switch (s) {
        IntegrationStatus.connected => 'متصل',
        IntegrationStatus.pending => 'معلّق',
        IntegrationStatus.failed => 'فشل',
        IntegrationStatus.available => 'متاح للتثبيت',
      };
}
