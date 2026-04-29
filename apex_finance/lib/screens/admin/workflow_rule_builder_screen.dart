/// APEX — Workflow Rule Visual Builder
/// /admin/workflow/rules/new — create a workflow rule from scratch.
///
/// Wired to Wave 1A Phase G backend:
///   POST /admin/workflow/rules
///   GET  /api/v1/events/list
///
/// Until now admins could only install rules from the 12 pre-built
/// templates (Phase M) or hand-write JSON (Phase Q). This screen unlocks
/// the engine for non-technical admins:
///   • Step 1 — Identity: name, description, tenant scope, enabled flag
///   • Step 2 — Trigger: event_pattern picker w/ autocomplete from
///     `/api/v1/events/list` + free-text override (supports wildcards
///     like `je.*`, `*.failed`)
///   • Step 3 — Conditions: AND-joined rows of (field, operator, value).
///     9 operators per the engine: eq/ne/gt/gte/lt/lte/contains/
///     starts_with/in. Field path uses payload.* dot-notation.
///   • Step 4 — Actions: ordered chain. 8 known action types: log,
///     slack, teams, email, notify, webhook, approval, comment. Each
///     type renders its own param form (URL for webhooks, to/subject
///     for email, approver_user_ids for approval, etc.).
///   • Step 5 — Review + Save: serializes to the CreateRuleRequest
///     schema and POSTs.
///
/// Strings inside action params support `{payload.field}` template
/// substitution at execution time (server-side).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class WorkflowRuleBuilderScreen extends StatefulWidget {
  const WorkflowRuleBuilderScreen({super.key});
  @override
  State<WorkflowRuleBuilderScreen> createState() =>
      _WorkflowRuleBuilderScreenState();
}

class _WorkflowRuleBuilderScreenState extends State<WorkflowRuleBuilderScreen> {
  // Step state
  int _step = 0;
  bool _saving = false;
  String? _error;

  // Step 1
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tenantCtrl = TextEditingController();
  bool _enabled = true;

  // Step 2
  final _eventCtrl = TextEditingController();
  List<Map<String, dynamic>> _events = [];

  // Step 3
  final List<_Condition> _conditions = [];

  // Step 4
  final List<_ActionRow> _actions = [];

  static const _operators = [
    'eq', 'ne', 'gt', 'gte', 'lt', 'lte',
    'contains', 'starts_with', 'in',
  ];

  static const _actionTypes = [
    'log', 'slack', 'teams', 'email', 'notify', 'webhook', 'approval', 'comment',
  ];

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoadEvents();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _tenantCtrl.dispose();
    _eventCtrl.dispose();
    for (final c in _conditions) {
      c.dispose();
    }
    for (final a in _actions) {
      a.dispose();
    }
    super.dispose();
  }

  Future<void> _ensureSecretThenLoadEvents() async {
    if (!ApiService.hasAdminSecret) {
      await _promptSecret();
    }
    final r = await ApiService.eventsList();
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _events = ((r.data['events'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {});
    }
  }

  Future<void> _promptSecret() async {
    final ctrl = TextEditingController();
    final secret = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('سرّ المسؤول مطلوب', style: TextStyle(color: AC.tp)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: 'X-Admin-Secret',
            labelStyle: TextStyle(color: AC.ts),
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (secret != null && secret.isNotEmpty) {
      ApiService.adminSecret = secret;
    }
  }

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _nameCtrl.text.trim().isNotEmpty;
      case 1:
        return _eventCtrl.text.trim().isNotEmpty;
      case 2:
        // Conditions are optional; allow zero or more.
        return _conditions.every((c) => c.field.text.trim().isNotEmpty);
      case 3:
        // At least one action required.
        return _actions.isNotEmpty && _actions.every((a) => a.type != null);
      case 4:
        return true;
      default:
        return false;
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'event_pattern': _eventCtrl.text.trim(),
      'enabled': _enabled,
      'description_ar': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'tenant_id': _tenantCtrl.text.trim().isEmpty ? null : _tenantCtrl.text.trim(),
      'conditions': [
        for (final c in _conditions)
          {
            'field': c.field.text.trim(),
            'operator': c.operator,
            'value': _coerceValue(c.value.text.trim(), c.operator),
            'case_sensitive': c.caseSensitive,
          },
      ],
      'actions': [
        for (final a in _actions)
          {
            'type': a.type,
            'params': a.collectParams(),
          },
      ],
    };
    final r = await ApiService.workflowCreateRule(body);
    if (!mounted) return;
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.ok,
          content: Text('✓ تم إنشاء القاعدة',
              style: TextStyle(color: AC.tp)),
        ),
      );
      GoRouter.of(context).go('/admin/workflow/rules');
    } else {
      setState(() {
        _saving = false;
        _error = r.error ?? 'فشل الحفظ';
      });
    }
  }

  dynamic _coerceValue(String raw, String op) {
    if (raw.isEmpty) return '';
    if (op == 'in') {
      // CSV → list, trim each
      return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    if (op == 'gt' || op == 'gte' || op == 'lt' || op == 'lte') {
      final n = num.tryParse(raw);
      return n ?? raw;
    }
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    final n = num.tryParse(raw);
    if (n != null) return n;
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'إنشاء قاعدة أتمتة جديدة',
            actions: [
              ApexToolbarAction(
                label: 'القواعد',
                icon: Icons.list_alt,
                onPressed: () =>
                    GoRouter.of(context).go('/admin/workflow/rules'),
              ),
            ],
          ),
          _stepIndicator(),
          Expanded(child: _body()),
          _actionsBar(),
        ],
      ),
    );
  }

  Widget _stepIndicator() {
    const labels = ['الهوية', 'الحدث', 'الشروط', 'الإجراءات', 'مراجعة'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AC.navy2,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) ...[
          _stepDot(i, labels[i]),
          if (i < labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i < _step ? AC.gold : AC.bdr,
              ),
            ),
        ],
      ]),
    );
  }

  Widget _stepDot(int i, String label) {
    final active = i == _step;
    final done = i < _step;
    final color = done ? AC.ok : (active ? AC.gold : AC.ts);
    return GestureDetector(
      onTap: i <= _step ? () => setState(() => _step = i) : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Center(
            child: done
                ? Icon(Icons.check, color: color, size: 14)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 10)),
      ]),
    );
  }

  Widget _body() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AC.err.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AC.err),
              ),
              child: Text(_error!, style: TextStyle(color: AC.err)),
            ),
          switch (_step) {
            0 => _stepIdentity(),
            1 => _stepEvent(),
            2 => _stepConditions(),
            3 => _stepActions(),
            _ => _stepReview(),
          },
        ],
      ),
    );
  }

  Widget _actionsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AC.navy2,
      child: Row(children: [
        if (_step > 0)
          OutlinedButton.icon(
            onPressed: () => setState(() => _step--),
            icon: const Icon(Icons.arrow_back, size: 14),
            label: const Text('السابق'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.bdr),
              foregroundColor: AC.tp,
            ),
          ),
        const Spacer(),
        if (_step < 4)
          ElevatedButton.icon(
            onPressed: _canAdvance ? () => setState(() => _step++) : null,
            icon: const Icon(Icons.arrow_forward, size: 14),
            label: const Text('التالي'),
          )
        else
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AC.btnFg))
                : const Icon(Icons.save, size: 14),
            label: const Text('حفظ القاعدة'),
            style: ElevatedButton.styleFrom(backgroundColor: AC.ok),
          ),
      ]),
    );
  }

  // ──────── Step 1 — Identity ────────

  Widget _stepIdentity() {
    return _card('الهوية والنطاق', [
      TextField(
        controller: _nameCtrl,
        style: TextStyle(color: AC.tp),
        onChanged: (_) => setState(() {}),
        decoration: _input('اسم القاعدة (مطلوب)', helper: 'مثال: تنبيه عند فشل ZATCA'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _descCtrl,
        maxLines: 2,
        style: TextStyle(color: AC.tp),
        decoration: _input('وصف (اختياري)'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _tenantCtrl,
        style: TextStyle(color: AC.tp),
        decoration:
            _input('tenant_id (اتركه فارغاً للقواعد العامة)'),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Switch(
          value: _enabled,
          activeColor: AC.gold,
          onChanged: (v) => setState(() => _enabled = v),
        ),
        Text('فعّالة عند الحفظ', style: TextStyle(color: AC.ts, fontSize: 12)),
      ]),
    ]);
  }

  // ──────── Step 2 — Event ────────

  Widget _stepEvent() {
    return _card('الحدث المُحفِّز', [
      TextField(
        controller: _eventCtrl,
        style: TextStyle(color: AC.tp, fontFamily: 'monospace'),
        onChanged: (_) => setState(() {}),
        decoration: _input(
          'event_pattern (مطلوب)',
          helper: 'يدعم wildcards: je.*  أو  *.failed  أو  je.posted',
        ),
      ),
      const SizedBox(height: 12),
      Text('الأحداث المسجّلة (${_events.length}) — انقر للاستخدام:',
          style: TextStyle(color: AC.ts, fontSize: 11)),
      const SizedBox(height: 8),
      Container(
        constraints: const BoxConstraints(maxHeight: 280),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _events.length,
          itemBuilder: (ctx, i) {
            final e = _events[i];
            return InkWell(
              onTap: () => setState(() => _eventCtrl.text = e['name']?.toString() ?? ''),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(children: [
                  SizedBox(
                    width: 220,
                    child: Text(
                      e['name']?.toString() ?? '',
                      style: TextStyle(
                        color: AC.cyan,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e['label_ar']?.toString() ?? '',
                      style: TextStyle(color: AC.ts, fontSize: 11),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ──────── Step 3 — Conditions ────────

  Widget _stepConditions() {
    return _card('الشروط (AND)', [
      Text(
        'الشروط مُجمَّعة بـ AND. اتركها فارغة لتفعيل القاعدة لكل حدث مطابق.',
        style: TextStyle(color: AC.ts, fontSize: 11),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _conditions.length; i++) _conditionRow(i),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () {
          setState(() => _conditions.add(_Condition()));
        },
        icon: const Icon(Icons.add, size: 14),
        label: const Text('شرط جديد'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AC.cyan),
          foregroundColor: AC.cyan,
        ),
      ),
    ]);
  }

  Widget _conditionRow(int i) {
    final c = _conditions[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: c.field,
              style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 12),
              onChanged: (_) => setState(() {}),
              decoration: _inputSmall('field — مثال: payload.amount'),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<String>(
              value: c.operator,
              dropdownColor: AC.navy2,
              isDense: true,
              style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
              decoration: _inputSmall('op'),
              items: [
                for (final o in _operators)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) => setState(() => c.operator = v ?? 'eq'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: TextField(
              controller: c.value,
              style: TextStyle(color: AC.tp, fontSize: 12),
              decoration: _inputSmall(
                c.operator == 'in' ? 'value — قيم مفصولة بفواصل' : 'value',
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(() {
              c.dispose();
              _conditions.removeAt(i);
            }),
            icon: Icon(Icons.delete_outline, color: AC.err, size: 16),
          ),
        ]),
      ]),
    );
  }

  // ──────── Step 4 — Actions ────────

  Widget _stepActions() {
    return _card('سلسلة الإجراءات', [
      Text(
        'الإجراءات تُنفَّذ بالترتيب. كل إجراء يستقبل الحمولة الكاملة + النتائج السابقة. السلاسل بين {} مثل {payload.invoice_id} تُستبدل وقت التنفيذ.',
        style: TextStyle(color: AC.ts, fontSize: 11),
      ),
      const SizedBox(height: 8),
      for (var i = 0; i < _actions.length; i++) _actionRow(i),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: () {
          setState(() => _actions.add(_ActionRow()));
        },
        icon: const Icon(Icons.add, size: 14),
        label: const Text('إجراء جديد'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AC.cyan),
          foregroundColor: AC.cyan,
        ),
      ),
    ]);
  }

  Widget _actionRow(int i) {
    final a = _actions[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AC.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '#${i + 1}',
              style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              value: a.type,
              dropdownColor: AC.navy2,
              isDense: true,
              style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
              decoration: _inputSmall('action type'),
              items: [
                for (final t in _actionTypes)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => a.type = v),
            ),
          ),
          const Spacer(),
          if (i > 0)
            IconButton(
              onPressed: () => setState(() {
                final prev = _actions[i - 1];
                _actions[i - 1] = _actions[i];
                _actions[i] = prev;
              }),
              icon: Icon(Icons.arrow_upward, size: 14, color: AC.ts),
            ),
          IconButton(
            onPressed: () => setState(() {
              a.dispose();
              _actions.removeAt(i);
            }),
            icon: Icon(Icons.delete_outline, color: AC.err, size: 16),
          ),
        ]),
        const SizedBox(height: 8),
        if (a.type != null) ..._actionParamFields(a),
      ]),
    );
  }

  List<Widget> _actionParamFields(_ActionRow a) {
    switch (a.type) {
      case 'log':
        return [_paramField(a, 'message', label: 'رسالة')];
      case 'slack':
      case 'teams':
        return [
          _paramField(a, 'title', label: 'العنوان'),
          _paramField(a, 'body', label: 'النص', maxLines: 3),
          _paramField(a, 'url', label: 'URL (اختياري)'),
          _paramField(a, 'severity', label: 'severity (info/warning/error)'),
        ];
      case 'email':
        return [
          _paramField(a, 'to', label: 'إلى'),
          _paramField(a, 'subject', label: 'الموضوع'),
          _paramField(a, 'body_html', label: 'body_html', maxLines: 3),
          _paramField(a, 'body_text', label: 'body_text', maxLines: 2),
        ];
      case 'notify':
        return [
          _paramField(a, 'user_id', label: 'user_id'),
          _paramField(a, 'notification_type', label: 'notification_type'),
          _paramField(a, 'body_ar', label: 'body_ar'),
          _paramField(a, 'action_url', label: 'action_url (اختياري)'),
        ];
      case 'webhook':
        return [
          _paramField(a, 'url', label: 'URL'),
        ];
      case 'approval':
        return [
          _paramField(a, 'approver_user_ids',
              label: 'approver_user_ids (CSV)', helper: 'مثال: u1,u2,u3'),
          _paramField(a, 'title_ar', label: 'العنوان'),
          _paramField(a, 'body', label: 'الوصف'),
          _paramField(a, 'object_type', label: 'object_type (اختياري)'),
          _paramField(a, 'object_id_field',
              label: 'object_id_field — مثال: invoice_id'),
        ];
      case 'comment':
        return [
          _paramField(a, 'object_type', label: 'object_type'),
          _paramField(a, 'object_id_field', label: 'object_id_field'),
          _paramField(a, 'body', label: 'نص التعليق', maxLines: 2),
        ];
      default:
        return const [];
    }
  }

  Widget _paramField(
    _ActionRow a,
    String key, {
    required String label,
    int maxLines = 1,
    String? helper,
  }) {
    final ctrl = a.ensureCtrl(key);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(color: AC.tp, fontSize: 12),
        decoration: _inputSmall(label, helper: helper),
      ),
    );
  }

  // ──────── Step 5 — Review ────────

  Widget _stepReview() {
    return _card('مراجعة قبل الحفظ', [
      _reviewRow('الاسم', _nameCtrl.text.trim()),
      _reviewRow('الحدث', _eventCtrl.text.trim()),
      _reviewRow('فعّالة', _enabled ? 'نعم' : 'لا'),
      if (_tenantCtrl.text.trim().isNotEmpty)
        _reviewRow('tenant_id', _tenantCtrl.text.trim()),
      if (_descCtrl.text.trim().isNotEmpty)
        _reviewRow('الوصف', _descCtrl.text.trim()),
      const SizedBox(height: 12),
      Text('الشروط (${_conditions.length}):',
          style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 12)),
      for (final c in _conditions)
        _reviewRow('  •', '${c.field.text} ${c.operator} ${c.value.text}'),
      if (_conditions.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text('  بلا شروط (تطلق على كل حدث مطابق)',
              style: TextStyle(color: AC.ts, fontSize: 11)),
        ),
      const SizedBox(height: 12),
      Text('الإجراءات (${_actions.length}):',
          style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 12)),
      for (var i = 0; i < _actions.length; i++)
        _reviewRow(
          '  #${i + 1}',
          '${_actions[i].type ?? "?"}: ${_actions[i].previewParams()}',
        ),
    ]);
  }

  Widget _reviewRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 100,
          child: Text(k,
              style: TextStyle(color: AC.ts, fontSize: 12, fontFamily: 'monospace')),
        ),
        Expanded(
          child: Text(
            v.isEmpty ? '—' : v,
            style: TextStyle(
              color: AC.tp,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ]),
    );
  }

  // ──────── Helpers ────────

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: AC.gold, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  InputDecoration _input(String label, {String? helper}) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        helperText: helper,
        helperStyle: TextStyle(color: AC.ts.withValues(alpha: 0.7), fontSize: 10),
        filled: true,
        fillColor: AC.navy3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      );

  InputDecoration _inputSmall(String label, {String? helper}) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontSize: 10),
        helperText: helper,
        helperStyle: TextStyle(color: AC.ts.withValues(alpha: 0.7), fontSize: 10),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: AC.navy2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      );
}

class _Condition {
  final TextEditingController field = TextEditingController();
  final TextEditingController value = TextEditingController();
  String operator = 'eq';
  bool caseSensitive = true;
  void dispose() {
    field.dispose();
    value.dispose();
  }
}

class _ActionRow {
  String? type;
  final Map<String, TextEditingController> _ctrls = {};
  TextEditingController ensureCtrl(String key) =>
      _ctrls.putIfAbsent(key, () => TextEditingController());
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
  }
  Map<String, dynamic> collectParams() {
    final out = <String, dynamic>{};
    for (final e in _ctrls.entries) {
      final raw = e.value.text.trim();
      if (raw.isEmpty) continue;
      // approver_user_ids accepts CSV
      if (e.key == 'approver_user_ids') {
        out[e.key] = raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      } else {
        out[e.key] = raw;
      }
    }
    return out;
  }
  String previewParams() {
    final filled = _ctrls.entries.where((e) => e.value.text.trim().isNotEmpty);
    if (filled.isEmpty) return '(فارغ)';
    return filled.map((e) => '${e.key}=${e.value.text.trim()}').join(', ');
  }
}
