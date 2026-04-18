/// APEX V5.1 — APEX Studio (Enhancement #11).
///
/// No-code customization — drag-drop field builder + workflow rules.
/// Replaces Odoo Studio + Salesforce Lightning App Builder for MENA.
library;

import 'package:flutter/material.dart';

class ApexStudioScreen extends StatefulWidget {
  const ApexStudioScreen({super.key});

  @override
  State<ApexStudioScreen> createState() => _ApexStudioScreenState();
}

class _ApexStudioScreenState extends State<ApexStudioScreen> {
  int _tab = 0;
  final _customFields = <_CustomField>[
    _CustomField('cost_center', 'مركز التكلفة', _FieldType.dropdown, required: true),
    _CustomField('project_code', 'رمز المشروع', _FieldType.text, required: false),
    _CustomField('approval_status', 'حالة الاعتماد', _FieldType.dropdown, required: true),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.architecture, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'APEX Studio — مصمّم بدون كود',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'أضف حقول · صمّم نماذج · اكتب workflows · من غير مبرمج',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Odoo Studio · Salesforce LAB',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                _tabButton(0, 'Custom Fields', Icons.view_column),
                _tabButton(1, 'Workflow Rules', Icons.account_tree),
                _tabButton(2, 'Page Layout', Icons.dashboard_customize),
                _tabButton(3, 'Approval Chains', Icons.approval),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_tab == 0) _buildCustomFields(),
          if (_tab == 1) _buildWorkflowRules(),
          if (_tab == 2) _buildPageLayout(),
          if (_tab == 3) _buildApprovalChains(),
        ],
      ),
    );
  }

  Widget _tabButton(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF7C3AED).withOpacity(0.1) : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: active ? const Color(0xFF7C3AED) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? const Color(0xFF7C3AED) : Colors.black54,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                  color: active ? const Color(0xFF7C3AED) : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomFields() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'حقول مخصّصة للفواتير',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _addField(),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('حقل جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Side-by-side: field list + live preview
          LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 700;
              return wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _fieldList()),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _livePreview()),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _fieldList(),
                        const SizedBox(height: 12),
                        _livePreview(),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _fieldList() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _customFields.length; i++)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: i < _customFields.length - 1
                      ? BorderSide(color: Colors.black.withOpacity(0.04))
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.drag_handle, size: 14, color: Colors.black38),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _fieldTypeColor(_customFields[i].type).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _fieldTypeIcon(_customFields[i].type),
                      size: 12,
                      color: _fieldTypeColor(_customFields[i].type),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _customFields[i].label,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            if (_customFields[i].required) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB91C1C).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  '*',
                                  style: TextStyle(fontSize: 10, color: Color(0xFFB91C1C), fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          '${_customFields[i].key} · ${_fieldTypeLabel(_customFields[i].type)}',
                          style: const TextStyle(fontSize: 10, color: Colors.black54, fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, size: 14, color: Colors.black54),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 14, color: Color(0xFFB91C1C)),
                    onPressed: () {
                      setState(() => _customFields.removeAt(i));
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _livePreview() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.remove_red_eye, size: 14, color: Color(0xFF7C3AED)),
              SizedBox(width: 6),
              Text(
                'المعاينة المباشرة',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Fake invoice form using the custom fields
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('فاتورة جديدة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const Divider(),
                for (final f in _customFields)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              f.label,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                            ),
                            if (f.required)
                              const Text(' *', style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C))),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black.withOpacity(0.15)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(_fieldTypeIcon(f.type), size: 12, color: Colors.black38),
                              const SizedBox(width: 6),
                              Text(
                                f.type == _FieldType.dropdown ? 'اختر...' : 'أدخل ${f.label}',
                                style: const TextStyle(fontSize: 11, color: Colors.black45),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowRules() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'قواعد العمل (Workflow Rules)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _workflowCard(
            title: 'فاتورة > 50,000 ر.س',
            trigger: 'عندما تُنشأ فاتورة',
            condition: 'المبلغ > 50,000',
            actions: ['أرسل للمدير المالي', 'تطلب اعتماد', 'تنبيه Slack'],
          ),
          _workflowCard(
            title: 'فاتورة متأخرة > 30 يوم',
            trigger: 'يومياً الساعة 08:00',
            condition: 'أعمار > 30 يوم · لم تُدفع',
            actions: ['أرسل تذكير للعميل', 'سجّل نشاط Copilot'],
          ),
          _workflowCard(
            title: 'قيد > 100,000 ر.س',
            trigger: 'عند ترحيل قيد',
            condition: 'المبلغ > 100K',
            actions: ['راجع AI Guardrails', 'يتطلّب اعتماد CFO'],
          ),
        ],
      ),
    );
  }

  Widget _workflowCard({
    required String title,
    required String trigger,
    required String condition,
    required List<String> actions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.play_arrow, size: 14, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              const Spacer(),
              Switch(
                value: true,
                onChanged: (_) {},
                activeColor: const Color(0xFF7C3AED),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _rulePart('IF', trigger, const Color(0xFF2563EB)),
          _rulePart('WHEN', condition, const Color(0xFFD97706)),
          _rulePart('THEN', actions.join(' · '), const Color(0xFF059669)),
        ],
      ),
    );
  }

  Widget _rulePart(String label, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildPageLayout() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: const Column(
        children: [
          Icon(Icons.dashboard_customize, size: 48, color: Color(0xFF7C3AED)),
          SizedBox(height: 12),
          Text(
            'Page Layout Editor',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'اسحب-أفلت الحقول لتغيير ترتيبها · اخفِ الحقول غير المستخدمة · ضع tooltips',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            child: Text(
              'ميزة متقدّمة — متاحة في Wave 26',
              style: TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalChains() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'سلاسل الاعتماد (Approval Chains)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _approvalChain('فواتير > 100K', ['المحاسب', 'المدير المالي', 'CFO']),
          _approvalChain('قيود تسوية', ['المحاسب', 'المراجع']),
          _approvalChain('فواتير استشارية', ['مدير المشروع', 'المدير المالي']),
        ],
      ),
    );
  }

  Widget _approvalChain(String title, List<String> steps) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF059669).withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (int i = 0; i < steps.length; i++) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF059669)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${i + 1}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                      ),
                      const SizedBox(width: 6),
                      Text(steps[i], style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.arrow_back, size: 12, color: Color(0xFF059669)),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _addField() {
    setState(() {
      _customFields.add(
        _CustomField(
          'custom_${_customFields.length + 1}',
          'حقل جديد',
          _FieldType.text,
        ),
      );
    });
  }

  Color _fieldTypeColor(_FieldType t) {
    switch (t) {
      case _FieldType.text: return const Color(0xFF2563EB);
      case _FieldType.number: return const Color(0xFF059669);
      case _FieldType.date: return const Color(0xFFD97706);
      case _FieldType.dropdown: return const Color(0xFF7C3AED);
      case _FieldType.checkbox: return const Color(0xFFEC4899);
    }
  }

  IconData _fieldTypeIcon(_FieldType t) {
    switch (t) {
      case _FieldType.text: return Icons.text_fields;
      case _FieldType.number: return Icons.calculate;
      case _FieldType.date: return Icons.event;
      case _FieldType.dropdown: return Icons.arrow_drop_down_circle;
      case _FieldType.checkbox: return Icons.check_box;
    }
  }

  String _fieldTypeLabel(_FieldType t) {
    switch (t) {
      case _FieldType.text: return 'نص';
      case _FieldType.number: return 'رقم';
      case _FieldType.date: return 'تاريخ';
      case _FieldType.dropdown: return 'قائمة منسدلة';
      case _FieldType.checkbox: return 'مربع اختيار';
    }
  }
}

class _CustomField {
  final String key;
  String label;
  _FieldType type;
  bool required;

  _CustomField(this.key, this.label, this.type, {this.required = false});
}

enum _FieldType { text, number, date, dropdown, checkbox }
