/// APEX Manufacturing Work Orders — production planning board.
///
/// Builds on ApexBomTree from Sprint 42. A Work Order (WO) is one
/// scheduled production run: "produce 25 desks by 2026-05-10". The
/// board shows WOs as stages (planned → released → in progress →
/// quality check → done) with progress bars, start/end dates, and
/// material availability pulled from the BOM.
///
/// This file provides:
///   • WorkOrder value object
///   • ApexWorkOrderCard (single WO tile)
///   • Helpers to compute stage colour + progress %
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

enum WorkOrderStage { planned, released, inProgress, qualityCheck, done }

class WorkOrder {
  final String id;
  final String productSku;
  final String productName;
  final int quantity;
  final DateTime startDate;
  final DateTime dueDate;
  final int completed;      // units completed so far
  final WorkOrderStage stage;
  final bool materialsReady;
  final String? assignedTo;

  const WorkOrder({
    required this.id,
    required this.productSku,
    required this.productName,
    required this.quantity,
    required this.startDate,
    required this.dueDate,
    required this.completed,
    required this.stage,
    required this.materialsReady,
    this.assignedTo,
  });

  double get progressPct =>
      quantity == 0 ? 0 : (completed / quantity).clamp(0, 1);

  bool get overdue =>
      DateTime.now().isAfter(dueDate) && stage != WorkOrderStage.done;

  WorkOrder copyWith({WorkOrderStage? stage, int? completed}) => WorkOrder(
        id: id,
        productSku: productSku,
        productName: productName,
        quantity: quantity,
        startDate: startDate,
        dueDate: dueDate,
        completed: completed ?? this.completed,
        stage: stage ?? this.stage,
        materialsReady: materialsReady,
        assignedTo: assignedTo,
      );
}

String workOrderStageLabel(WorkOrderStage s) => switch (s) {
      WorkOrderStage.planned => 'مُخطَّط',
      WorkOrderStage.released => 'مُفعَّل',
      WorkOrderStage.inProgress => 'قيد التصنيع',
      WorkOrderStage.qualityCheck => 'فحص جودة',
      WorkOrderStage.done => 'منتهي',
    };

Color workOrderStageColor(WorkOrderStage s) => switch (s) {
      WorkOrderStage.planned => AC.ts,
      WorkOrderStage.released => AC.gold,
      WorkOrderStage.inProgress => Colors.orange.shade400,
      WorkOrderStage.qualityCheck => Colors.purple.shade300,
      WorkOrderStage.done => AC.ok,
    };

class ApexWorkOrderCard extends StatelessWidget {
  final WorkOrder wo;
  final VoidCallback? onTap;
  final void Function(WorkOrderStage next)? onStageChange;

  const ApexWorkOrderCard({
    super.key,
    required this.wo,
    this.onTap,
    this.onStageChange,
  });

  @override
  Widget build(BuildContext context) {
    final stageColor = workOrderStageColor(wo.stage);
    final isOverdue = wo.overdue;
    return Semantics(
      label:
          'أمر عمل ${wo.id} لـ ${wo.productName} — ${workOrderStageLabel(wo.stage)}',
      button: onTap != null,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AC.navy2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isOverdue
                    ? AC.err.withValues(alpha: 0.6)
                    : stageColor.withValues(alpha: 0.4),
                width: isOverdue ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: stageColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border:
                          Border.all(color: stageColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(workOrderStageLabel(wo.stage),
                        style: TextStyle(
                            color: stageColor,
                            fontSize: AppFontSize.xs,
                            fontWeight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Text(wo.id,
                      style: TextStyle(
                          color: AC.td,
                          fontSize: AppFontSize.xs,
                          fontFamily: 'monospace')),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Text(wo.productName,
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.base,
                        fontWeight: FontWeight.w700)),
                Text('${wo.quantity} وحدة • SKU ${wo.productSku}',
                    style: TextStyle(
                        color: AC.ts, fontSize: AppFontSize.xs)),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: wo.progressPct,
                    backgroundColor: AC.navy4,
                    valueColor: AlwaysStoppedAnimation(stageColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Text('${wo.completed}/${wo.quantity}',
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: AppFontSize.xs,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${(wo.progressPct * 100).round()}%',
                      style: TextStyle(
                          color: stageColor,
                          fontSize: AppFontSize.xs,
                          fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Icon(Icons.calendar_month_outlined,
                      size: 12, color: AC.td),
                  const SizedBox(width: 4),
                  Text(_fmt(wo.startDate),
                      style: TextStyle(
                          color: AC.ts,
                          fontSize: AppFontSize.xs,
                          fontFamily: 'monospace')),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 12, color: AC.td),
                  const SizedBox(width: 4),
                  Text(_fmt(wo.dueDate),
                      style: TextStyle(
                          color: isOverdue ? AC.err : AC.ts,
                          fontSize: AppFontSize.xs,
                          fontFamily: 'monospace',
                          fontWeight: isOverdue
                              ? FontWeight.w700
                              : FontWeight.w400)),
                  const Spacer(),
                  if (!wo.materialsReady)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AC.err.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber,
                                size: 10, color: AC.err),
                            const SizedBox(width: 2),
                            Text('نقص مواد',
                                style: TextStyle(
                                    color: AC.err,
                                    fontSize: AppFontSize.xs,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                ]),
                if (wo.assignedTo != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.engineering_outlined,
                        size: 12, color: AC.td),
                    const SizedBox(width: 4),
                    Text(wo.assignedTo!,
                        style: TextStyle(
                            color: AC.ts, fontSize: AppFontSize.xs)),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
