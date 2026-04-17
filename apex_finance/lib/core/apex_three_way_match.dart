/// APEX 3-Way Match — SAP / Odoo-style PO ↔ GRN ↔ Bill reconciliation.
///
/// Three-way match is the gold standard for AP controls: before a
/// vendor bill is approved for payment, the system checks that:
///   1. Quantity and price match the approved Purchase Order (PO)
///   2. Quantity and condition match the Goods Receipt Note (GRN)
///      issued by the warehouse
///   3. The bill is from an authorised vendor
///
/// When all three agree, the bill auto-approves. When they don't, the
/// discrepancies are surfaced for the buyer or AP clerk to resolve.
///
/// This widget renders the three documents side-by-side, highlights
/// the cells where any pair disagrees, and shows an overall match
/// verdict (match / partial / mismatch). The matching logic is pure
/// and deterministic — you can run it server-side too.
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

class MatchLine {
  final String sku;
  final String description;
  final double poQty;
  final double poPrice;
  final double grnQty;
  final double billQty;
  final double billPrice;

  const MatchLine({
    required this.sku,
    required this.description,
    required this.poQty,
    required this.poPrice,
    required this.grnQty,
    required this.billQty,
    required this.billPrice,
  });

  bool get qtyMatches => poQty == grnQty && grnQty == billQty;
  bool get priceMatches => poPrice == billPrice;
  bool get allMatch => qtyMatches && priceMatches;

  MatchStatus get status {
    if (allMatch) return MatchStatus.ok;
    if (!qtyMatches && !priceMatches) return MatchStatus.both;
    if (!qtyMatches) return MatchStatus.qty;
    return MatchStatus.price;
  }
}

enum MatchStatus { ok, qty, price, both }

class ApexThreeWayMatch extends StatelessWidget {
  final String poNumber;
  final String grnNumber;
  final String billNumber;
  final String vendor;
  final List<MatchLine> lines;
  final VoidCallback? onApprove;
  final VoidCallback? onEscalate;

  const ApexThreeWayMatch({
    super.key,
    required this.poNumber,
    required this.grnNumber,
    required this.billNumber,
    required this.vendor,
    required this.lines,
    this.onApprove,
    this.onEscalate,
  });

  @override
  Widget build(BuildContext context) {
    final ok = lines.every((l) => l.allMatch);
    final poTotal = lines.fold<double>(0, (s, l) => s + l.poQty * l.poPrice);
    final billTotal =
        lines.fold<double>(0, (s, l) => s + l.billQty * l.billPrice);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _verdictBanner(ok, poTotal, billTotal),
        const SizedBox(height: AppSpacing.md),
        _headers(),
        const SizedBox(height: AppSpacing.sm),
        for (final l in lines) ...[
          _lineRow(l),
          const SizedBox(height: AppSpacing.xs),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          FilledButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('اعتماد الفاتورة'),
            onPressed: ok ? onApprove : null,
            style: FilledButton.styleFrom(
              backgroundColor: ok ? AC.ok : AC.td,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton.icon(
            icon: const Icon(Icons.report_problem_outlined, size: 16),
            label: const Text('رفع كاستثناء'),
            onPressed: onEscalate,
            style: OutlinedButton.styleFrom(foregroundColor: AC.err),
          ),
          const Spacer(),
          if (!ok)
            Text(
              'فرق: ${(billTotal - poTotal).abs().toStringAsFixed(2)} ر.س',
              style: TextStyle(
                  color: AC.err,
                  fontWeight: FontWeight.w700,
                  fontSize: AppFontSize.sm),
            ),
        ]),
      ],
    );
  }

  Widget _verdictBanner(bool ok, double poTotal, double billTotal) {
    final color = ok ? AC.ok : AC.err;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(children: [
        Icon(
            ok ? Icons.verified_outlined : Icons.warning_amber_rounded,
            size: 28,
            color: color),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ok ? 'تطابق كامل' : 'عدم تطابق — يتطلب مراجعة',
                  style: TextStyle(
                      color: color,
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('PO: $poNumber  •  GRN: $grnNumber  •  Bill: $billNumber',
                  style:
                      TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('الطلب: ${poTotal.toStringAsFixed(2)} ر.س',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
            const SizedBox(height: 2),
            Text('الفاتورة: ${billTotal.toStringAsFixed(2)} ر.س',
                style: TextStyle(
                    color: ok ? AC.ok : AC.err,
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      ]),
    );
  }

  Widget _headers() => Row(
        children: [
          Expanded(
              flex: 3,
              child: Text('الصنف',
                  style: TextStyle(
                      color: AC.td,
                      fontSize: AppFontSize.xs,
                      fontWeight: FontWeight.w700))),
          Expanded(child: _colHead('PO', Colors.blue.shade300)),
          Expanded(child: _colHead('GRN', Colors.purple.shade300)),
          Expanded(child: _colHead('Bill', AC.gold)),
          const SizedBox(width: 80),
        ],
      );

  Widget _colHead(String s, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Text(s,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: c,
                fontSize: AppFontSize.xs,
                fontWeight: FontWeight.w700)),
      );

  Widget _lineRow(MatchLine l) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
            color: l.allMatch
                ? AC.ok.withValues(alpha: 0.3)
                : AC.err.withValues(alpha: 0.5),
            width: l.allMatch ? 1 : 1.5),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.description,
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w600)),
                Text(l.sku,
                    style:
                        TextStyle(color: AC.td, fontSize: AppFontSize.xs)),
              ]),
        ),
        Expanded(
          child: _cell('${l.poQty.toStringAsFixed(0)} × ${l.poPrice.toStringAsFixed(2)}',
              Colors.blue.shade300, highlight: false),
        ),
        Expanded(
          child: _cell(l.grnQty.toStringAsFixed(0),
              Colors.purple.shade300,
              highlight: l.grnQty != l.poQty),
        ),
        Expanded(
          child: _cell(
              '${l.billQty.toStringAsFixed(0)} × ${l.billPrice.toStringAsFixed(2)}',
              AC.gold,
              highlight:
                  l.billQty != l.poQty || l.billPrice != l.poPrice),
        ),
        SizedBox(width: 80, child: _statusPill(l.status)),
      ]),
    );
  }

  Widget _cell(String text, Color accent, {required bool highlight}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: highlight
              ? AC.err.withValues(alpha: 0.15)
              : accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: highlight
              ? Border.all(color: AC.err.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: highlight ? AC.err : accent,
                fontSize: AppFontSize.xs,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
                fontFamily: 'monospace')),
      );

  Widget _statusPill(MatchStatus s) {
    final (color, label, icon) = switch (s) {
      MatchStatus.ok => (AC.ok, 'مطابق', Icons.check_circle),
      MatchStatus.qty => (AC.err, 'كمية', Icons.warning_amber),
      MatchStatus.price => (Colors.amber.shade700, 'سعر', Icons.warning_amber),
      MatchStatus.both => (AC.err, 'الاثنين', Icons.error),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              color: color,
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w700)),
    ]);
  }
}
