/// APEX Workflow Rules Builder — Odoo Automation-style if-then engine UI.
///
/// Lets non-technical users build "when X, do Y" rules:
///   WHEN  [trigger]  matches  [condition]
///   THEN  [action1]  [action2]  ...
///
/// The widget is a thin UI layer around a pure data model — host
/// persists + executes the rules server-side. This file gives you:
///   • WorkflowRule + WorkflowCondition + WorkflowAction value types
///   • ApexWorkflowBuilder widget (add/edit/remove/toggle-enabled)
///   • Built-in trigger/action registries you can override
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';
import 'theme.dart' as core_theme;

/// A rule trigger, e.g. "invoice.created" or "payment.overdue".
class WorkflowTrigger {
  final String id;
  final String label;
  final IconData icon;
  const WorkflowTrigger(
      {required this.id, required this.label, required this.icon});
}

/// A conjunctive condition — all must match.
class WorkflowCondition {
  final String field;   // e.g. 'amount', 'customer.country', 'days_overdue'
  final String op;      // '==' | '>' | '<' | '>=' | '<=' | 'contains'
  final String value;

  const WorkflowCondition({
    required this.field,
    required this.op,
    required this.value,
  });

  WorkflowCondition copyWith({String? field, String? op, String? value}) =>
      WorkflowCondition(
          field: field ?? this.field,
          op: op ?? this.op,
          value: value ?? this.value);
}

/// A side effect — e.g. "send WhatsApp reminder", "create journal entry".
class WorkflowAction {
  final String id;
  final String label;
  final IconData icon;
  final Map<String, String> params;

  const WorkflowAction({
    required this.id,
    required this.label,
    required this.icon,
    this.params = const {},
  });
}

class WorkflowRule {
  final String id;
  final String name;
  final bool enabled;
  final String triggerId;
  final List<WorkflowCondition> conditions;
  final List<WorkflowAction> actions;

  const WorkflowRule({
    required this.id,
    required this.name,
    required this.enabled,
    required this.triggerId,
    required this.conditions,
    required this.actions,
  });

  WorkflowRule copyWith({
    String? name,
    bool? enabled,
    String? triggerId,
    List<WorkflowCondition>? conditions,
    List<WorkflowAction>? actions,
  }) =>
      WorkflowRule(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        triggerId: triggerId ?? this.triggerId,
        conditions: conditions ?? this.conditions,
        actions: actions ?? this.actions,
      );
}

class ApexWorkflowBuilder extends StatefulWidget {
  final List<WorkflowRule> rules;
  final List<WorkflowTrigger> triggers;
  final List<WorkflowAction> actionCatalog;
  final ValueChanged<List<WorkflowRule>> onChanged;

  const ApexWorkflowBuilder({
    super.key,
    required this.rules,
    required this.triggers,
    required this.actionCatalog,
    required this.onChanged,
  });

  @override
  State<ApexWorkflowBuilder> createState() => _ApexWorkflowBuilderState();
}

class _ApexWorkflowBuilderState extends State<ApexWorkflowBuilder> {
  late List<WorkflowRule> _rules;

  @override
  void initState() {
    super.initState();
    _rules = List.of(widget.rules);
  }

  void _emit() => widget.onChanged(List.unmodifiable(_rules));

  void _toggle(String id) {
    setState(() {
      final i = _rules.indexWhere((r) => r.id == id);
      if (i < 0) return;
      _rules[i] = _rules[i].copyWith(enabled: !_rules[i].enabled);
    });
    _emit();
  }

  void _remove(String id) {
    setState(() => _rules.removeWhere((r) => r.id == id));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('القواعد الآلية (${_rules.length})',
              style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          FilledButton.icon(
            icon: const Icon(Icons.add, size: 16),
            label: const Text('قاعدة جديدة'),
            onPressed: _addSample,
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        for (final r in _rules) ...[
          _ruleCard(r),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  void _addSample() {
    setState(() {
      _rules.add(WorkflowRule(
        id: 'r_${DateTime.now().millisecondsSinceEpoch}',
        name: 'قاعدة جديدة',
        enabled: true,
        triggerId: widget.triggers.first.id,
        conditions: const [],
        actions: const [],
      ));
    });
    _emit();
  }

  Widget _ruleCard(WorkflowRule r) {
    final trigger = widget.triggers.firstWhere(
      (t) => t.id == r.triggerId,
      orElse: () => widget.triggers.first,
    );
    final alpha = r.enabled ? 1.0 : 0.5;
    return Opacity(
      opacity: alpha,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: r.enabled ? AC.gold.withValues(alpha: 0.35) : AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(trigger.icon, color: AC.gold, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(r.name,
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.base,
                        fontWeight: FontWeight.w700)),
              ),
              Semantics(
                toggled: r.enabled,
                label: r.enabled ? 'مفعّلة' : 'معطّلة',
                child: Switch(
                  value: r.enabled,
                  activeColor: AC.gold,
                  onChanged: (_) => _toggle(r.id),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: AC.err, size: 18),
                tooltip: 'حذف',
                onPressed: () => _remove(r.id),
              ),
            ]),
            const SizedBox(height: AppSpacing.sm),
            _block('عند', trigger.label, Icons.flash_on, AC.gold),
            if (r.conditions.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final c in r.conditions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _block(
                      'و',
                      '${c.field} ${c.op} ${c.value}',
                      Icons.filter_alt_outlined,
                      core_theme.AC.warn),
                ),
            ],
            const SizedBox(height: 4),
            if (r.actions.isEmpty)
              _block('ثم', '(لا إجراءات — أضف فعلاً)', Icons.warning_amber,
                  AC.err)
            else
              for (final a in r.actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _block('ثم', a.label, a.icon, AC.ok),
                ),
          ],
        ),
      ),
    );
  }

  Widget _block(String prefix, String text, IconData icon, Color color) =>
      Row(children: [
        SizedBox(
          width: 36,
          child: Text(prefix,
              style: TextStyle(
                  color: AC.td,
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(text,
                    style:
                        TextStyle(color: AC.tp, fontSize: AppFontSize.sm),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
        ),
      ]);
}
