/// APEX — Output chips footer.
/// Drop at the bottom of an INPUT screen to surface the OUTPUT screens
/// that this data feeds into. Each chip is a tappable cross-link.
///
/// Usage:
///   ApexOutputChips(items: [
///     ApexChipLink('أعمار AR', '/sales/aging', Icons.timeline),
///     ApexChipLink('VAT Return', '/compliance/vat-return', Icons.receipt_long),
///   ])
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';

class ApexChipLink {
  final String label;
  final String route;
  final IconData icon;
  const ApexChipLink(this.label, this.route, this.icon);
}

class ApexOutputChips extends StatelessWidget {
  final String title;
  final List<ApexChipLink> items;
  const ApexOutputChips({
    super.key,
    this.title = 'مخرجات مرتبطة',
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy3,
        border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.alt_route, color: AC.gold, size: 14),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  color: AC.gold,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((it) => InkWell(
                onTap: () => context.go(it.route),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AC.navy2,
                    border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(it.icon, color: AC.gold, size: 13),
                    const SizedBox(width: 6),
                    Text(it.label,
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_back, color: AC.gold, size: 11),
                  ]),
                ),
              )).toList(),
        ),
      ]),
    );
  }
}
