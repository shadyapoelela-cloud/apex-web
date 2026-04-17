/// APEX BOM Tree — Manufacturing Bill of Materials hierarchy.
///
/// A BOM (Bill of Materials) is the recipe for a manufactured product:
/// which raw materials + sub-assemblies + quantities + costs go into
/// making one unit. The tree can be N levels deep (a finished
/// "wooden desk" needs "drawer assembly" which needs "drawer base" +
/// "drawer handle" + screws).
///
/// This widget renders the tree, computes rolled-up costs bottom-up,
/// and flags items where the on-hand quantity is insufficient for the
/// planned production run (MRP feasibility check).
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

class BomNode {
  final String sku;
  final String name;
  final String uom;         // unit of measure (EA, KG, M, etc.)
  final double quantityPer; // units needed per parent unit
  final double unitCost;
  final int onHand;
  final List<BomNode> children;

  const BomNode({
    required this.sku,
    required this.name,
    required this.uom,
    required this.quantityPer,
    required this.unitCost,
    required this.onHand,
    this.children = const [],
  });

  bool get isLeaf => children.isEmpty;

  /// Rolled-up cost = this node's cost + sum of children's rolled-up
  /// costs (each scaled by its quantityPer).
  double rolledUpCost() {
    if (isLeaf) return unitCost;
    return children.fold(
        unitCost, (s, c) => s + c.rolledUpCost() * c.quantityPer);
  }
}

class ApexBomTree extends StatefulWidget {
  final BomNode root;

  /// How many finished units the user wants to produce.
  final int runSize;

  const ApexBomTree({
    super.key,
    required this.root,
    this.runSize = 1,
  });

  @override
  State<ApexBomTree> createState() => _ApexBomTreeState();
}

class _ApexBomTreeState extends State<ApexBomTree> {
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    // Expand the root by default.
    _expanded.add(widget.root.sku);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_node(widget.root, depth: 0, requiredQty: widget.runSize.toDouble())],
    );
  }

  Widget _node(BomNode n, {required int depth, required double requiredQty}) {
    final expanded = _expanded.contains(n.sku);
    final shortage = n.onHand - requiredQty;
    final canMake = shortage >= 0 || !n.isLeaf;
    final rollup = n.rolledUpCost();
    final totalCost = rollup * requiredQty;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: depth * 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (n.isLeaf) return;
                if (expanded) {
                  _expanded.remove(n.sku);
                } else {
                  _expanded.add(n.sku);
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                color: depth == 0 ? AC.navy3 : AC.navy2,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                    color: canMake
                        ? AC.bdr
                        : AC.err.withValues(alpha: 0.5)),
              ),
              child: Row(children: [
                Icon(
                    n.isLeaf
                        ? Icons.circle_outlined
                        : expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                    size: 16,
                    color: AC.gold),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 4,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.name,
                            style: TextStyle(
                                color: AC.tp,
                                fontSize: AppFontSize.sm,
                                fontWeight: depth == 0
                                    ? FontWeight.w800
                                    : FontWeight.w600)),
                        Text('SKU: ${n.sku} • ${n.uom}',
                            style: TextStyle(
                                color: AC.td,
                                fontSize: AppFontSize.xs,
                                fontFamily: 'monospace')),
                      ]),
                ),
                Expanded(
                  child: _cell('${requiredQty.toStringAsFixed(1)} ${n.uom}',
                      AC.gold),
                ),
                Expanded(
                  child: _cell('${n.onHand}', canMake ? AC.ok : AC.err),
                ),
                Expanded(
                  child: _cell('${(rollup).toStringAsFixed(2)} ر.س',
                      AC.gold),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: canMake
                          ? AC.ok.withValues(alpha: 0.18)
                          : AC.err.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                          color: canMake
                              ? AC.ok.withValues(alpha: 0.5)
                              : AC.err.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      canMake
                          ? '${totalCost.toStringAsFixed(2)} ر.س'
                          : 'نقص ${shortage.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                          color: canMake ? AC.ok : AC.err,
                          fontSize: AppFontSize.xs,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ]),
            ),
          ),
          if (expanded)
            for (final c in n.children) ...[
              const SizedBox(height: 4),
              _node(c,
                  depth: depth + 1, requiredQty: requiredQty * c.quantityPer),
            ],
        ],
      ),
    );
  }

  Widget _cell(String s, Color color) => Text(s,
      textAlign: TextAlign.center,
      style: TextStyle(
          color: color,
          fontSize: AppFontSize.xs,
          fontFamily: 'monospace',
          fontFeatures: const [FontFeature.tabularFigures()]));
}
