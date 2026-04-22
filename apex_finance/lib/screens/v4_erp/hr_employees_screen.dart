/// APEX Wave 18 — HR Employees (ERP Sub-Module).
///
/// Fills the HR gap in V5. Second production wave after Wave 17.
/// Same 5-tab pattern for consistency.
///
/// Tabs: Directory · Org Chart · Contracts · Leaves · Benefits
/// More ▾: Performance · Training · Offboarding · Documents · Settings
///
/// Reuses V5.1 enhancements:
///   #5  Find & Recode on employee records
///   #6  Draft with AI on contract terms
///   #7  Undo Toast on leave approvals
///   #9  Risk Scoring on compensation changes
///
/// Route: /app/erp/hr/employees
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/apex_v5_find_and_recode.dart';
import '../../core/v5/apex_v5_undo_toast.dart';

class HrEmployeesScreen extends StatefulWidget {
  const HrEmployeesScreen({super.key});

  @override
  State<HrEmployeesScreen> createState() => _HrEmployeesScreenState();
}

class _HrEmployeesScreenState extends State<HrEmployeesScreen> {
  int _tab = 0;
  final _selectedEmployees = <String>{};

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            _buildTabs(),
            Expanded(child: _buildBody()),
          ],
        ),
        if (_tab == 0 && _selectedEmployees.isNotEmpty)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ApexV5FindAndRecodeBar(
              selectedCount: _selectedEmployees.length,
              itemTypeLabelAr: 'موظف',
              onRecodeTap: _onRecodeEmployees,
              onExportTap: () => _onExport('الموظفون'),
              onClear: () => setState(() => _selectedEmployees.clear()),
            ),
          ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: core_theme.AC.tp.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          _tabBtn(0, 'الموظفون', Icons.people),
          _tabBtn(1, 'الهيكل التنظيمي', Icons.account_tree),
          _tabBtn(2, 'العقود', Icons.description),
          _tabBtn(3, 'الإجازات', Icons.event_available),
          _tabBtn(4, 'المزايا', Icons.health_and_safety),
          const Spacer(),
          _moreMenu(),
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? core_theme.AC.gold.withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: core_theme.AC.gold.withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? core_theme.AC.gold : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? core_theme.AC.gold : core_theme.AC.ts,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moreMenu() {
    return PopupMenuButton<String>(
      tooltip: 'المزيد',
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('المزيد', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          Icon(Icons.arrow_drop_down, size: 16, color: core_theme.AC.ts),
        ],
      ),
      itemBuilder: (ctx) => [
        _mItem('perf', 'تقييم الأداء', Icons.trending_up),
        _mItem('training', 'التدريب والتطوير', Icons.school),
        _mItem('offboard', 'إنهاء الخدمة (EOSB)', Icons.exit_to_app),
        _mItem('docs', 'مكتبة الوثائق', Icons.folder),
        _mItem('settings', 'الإعدادات', Icons.settings),
      ],
    );
  }

  PopupMenuItem<String> _mItem(String v, String label, IconData icon) {
    return PopupMenuItem(
      value: v,
      child: Row(
        children: [
          Icon(icon, size: 14, color: core_theme.AC.ts),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _buildDirectory();
      case 1: return _buildOrgChart();
      case 2: return _buildContracts();
      case 3: return _buildLeaves();
      case 4: return _buildBenefits();
      default: return const SizedBox();
    }
  }

  // ── Tab 1: Directory ──────────────────────────────────────────────

  Widget _buildDirectory() {
    final employees = _mockEmployees();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('إجمالي الموظفين', '87', Icons.people, core_theme.AC.info),
            _Stat('نشط', '82', Icons.check_circle, core_theme.AC.ok),
            _Stat('إجازة', '3', Icons.flight, core_theme.AC.warn),
            _Stat('تحت التجربة', '5', Icons.access_time, core_theme.AC.purple),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('قائمة الموظفين', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 14),
                    hintText: 'بحث بالاسم أو الرقم...',
                    hintStyle: const TextStyle(fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add, size: 14),
                label: Text('تعيين جديد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: core_theme.AC.gold,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Employee cards grid (Kanban-lite)
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 1100
                  ? 3
                  : constraints.maxWidth > 700
                      ? 2
                      : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 2.8,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final e in employees)
                    _EmployeeCard(
                      employee: e,
                      selected: _selectedEmployees.contains(e.id),
                      onToggle: (sel) {
                        setState(() {
                          if (sel) {
                            _selectedEmployees.add(e.id);
                          } else {
                            _selectedEmployees.remove(e.id);
                          }
                        });
                      },
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ── Tab 2: Org Chart ──────────────────────────────────────────────

  Widget _buildOrgChart() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // CEO
          _orgNode('أحمد السالم', 'الرئيس التنفيذي', core_theme.AC.gold, large: true),
          _connector(),
          // CFO row
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              Column(
                children: [
                  _orgNode('سارة محمود', 'المدير المالي', core_theme.AC.info),
                  _connector(),
                  Row(
                    children: [
                      _orgNode('خالد', 'محاسب أول', core_theme.AC.info, small: true),
                      const SizedBox(width: 8),
                      _orgNode('ليلى', 'محاسب', core_theme.AC.info, small: true),
                      const SizedBox(width: 8),
                      _orgNode('يوسف', 'محاسب', core_theme.AC.info, small: true),
                    ],
                  ),
                ],
              ),
              Column(
                children: [
                  _orgNode('محمد الراشد', 'مدير العمليات', core_theme.AC.ok),
                  _connector(),
                  Row(
                    children: [
                      _orgNode('فاطمة', 'مسؤول مخزون', core_theme.AC.ok, small: true),
                      const SizedBox(width: 8),
                      _orgNode('عبدالله', 'مشرف مستودع', core_theme.AC.ok, small: true),
                    ],
                  ),
                ],
              ),
              Column(
                children: [
                  _orgNode('نورا القحطاني', 'مدير الموارد البشرية', core_theme.AC.purple),
                  _connector(),
                  Row(
                    children: [
                      _orgNode('حمد', 'HR Specialist', core_theme.AC.purple, small: true),
                      const SizedBox(width: 8),
                      _orgNode('منى', 'Payroll', core_theme.AC.purple, small: true),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orgNode(String name, String title, Color color, {bool large = false, bool small = false}) {
    final padding = large ? 16.0 : small ? 8.0 : 12.0;
    final nameSize = large ? 16.0 : small ? 11.0 : 13.0;
    final titleSize = large ? 12.0 : small ? 9.0 : 10.0;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: large ? 24 : small ? 14 : 18,
            backgroundColor: color,
            child: Text(
              name.substring(0, 1),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: large ? 16 : small ? 10 : 13,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w800),
          ),
          Text(
            title,
            style: TextStyle(fontSize: titleSize, color: core_theme.AC.ts),
          ),
        ],
      ),
    );
  }

  Widget _connector() => Container(
        width: 2,
        height: 20,
        color: core_theme.AC.tp.withOpacity(0.2),
      );

  // ── Tab 3: Contracts ──────────────────────────────────────────────

  Widget _buildContracts() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('عقود نشطة', '82', Icons.description, core_theme.AC.ok),
            _Stat('تنتهي خلال 60 يوم', '7', Icons.warning, core_theme.AC.warn),
            _Stat('معلّقة', '3', Icons.hourglass_empty, core_theme.AC.info),
            _Stat('مجدّدة هذا الشهر', '2', Icons.refresh, core_theme.AC.purple),
          ]),
          const SizedBox(height: 16),
          Text('العقود', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: core_theme.AC.tp.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _contractRow('أحمد السالم', 'CEO', '2020-06-01 → 2027-06-01', 'مفتوح المدة', core_theme.AC.ok),
                _contractRow('سارة محمود', 'CFO', '2021-03-15 → 2026-03-15', 'ينتهي خلال 60 يوم', core_theme.AC.warn),
                _contractRow('خالد أحمد', 'محاسب أول', '2022-09-01 → 2025-09-01', 'منتهي — للتجديد', const Color(0xFFB91C1C)),
                _contractRow('فاطمة علي', 'مسؤول مخزون', '2024-01-15 → مفتوح', 'مفتوح المدة', core_theme.AC.ok),
                _contractRow('محمد الراشد', 'مدير العمليات', '2023-05-01 → 2028-05-01', 'نشط', core_theme.AC.ok),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contractRow(String name, String role, String period, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: core_theme.AC.tp.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          Icon(Icons.description, size: 16, color: core_theme.AC.ts),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(role, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              period,
              style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace'),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, size: 16),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Leaves ─────────────────────────────────────────────────

  Widget _buildLeaves() {
    final requests = _mockLeaves();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('طلبات معلّقة', '4', Icons.pending, core_theme.AC.warn),
            _Stat('معتمد هذا الشهر', '12', Icons.check_circle, core_theme.AC.ok),
            _Stat('في إجازة الآن', '3', Icons.flight, core_theme.AC.info),
            _Stat('متوسط الرصيد', '18 يوم', Icons.event, core_theme.AC.purple),
          ]),
          const SizedBox(height: 16),
          Text('طلبات الإجازات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final r in requests)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: core_theme.AC.tp.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: core_theme.AC.gold.withOpacity(0.2),
                    child: Text(
                      r.employee.substring(0, 1),
                      style: TextStyle(color: core_theme.AC.gold, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(r.employee, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _leaveColor(r.type).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                r.type,
                                style: TextStyle(fontSize: 10, color: _leaveColor(r.type), fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${r.days} أيام · ${r.startDate} إلى ${r.endDate}',
                          style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
                        ),
                        if (r.reason != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              r.reason!,
                              style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (r.status == 'pending') ...[
                    OutlinedButton.icon(
                      onPressed: () => _onLeaveReject(r.employee),
                      icon: const Icon(Icons.close, size: 14),
                      label: Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB91C1C),
                        side: const BorderSide(color: Color(0xFFB91C1C)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _onLeaveApprove(r.employee),
                      icon: const Icon(Icons.check, size: 14),
                      label: Text('اعتماد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: core_theme.AC.ok,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: r.status == 'approved'
                            ? core_theme.AC.ok.withOpacity(0.12)
                            : const Color(0xFFB91C1C).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.status == 'approved' ? 'معتمد ✓' : 'مرفوض',
                        style: TextStyle(
                          fontSize: 11,
                          color: r.status == 'approved' ? core_theme.AC.ok : const Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _leaveColor(String type) {
    if (type == 'سنوية') return core_theme.AC.info;
    if (type == 'مرضية') return const Color(0xFFB91C1C);
    if (type == 'طارئة') return core_theme.AC.warn;
    if (type == 'أمومة') return const Color(0xFFEC4899);
    return core_theme.AC.ts;
  }

  // ── Tab 5: Benefits ───────────────────────────────────────────────

  Widget _buildBenefits() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('GOSI الإجمالي', '142K', Icons.health_and_safety, core_theme.AC.info),
            _Stat('EOSB متراكم', '680K', Icons.savings, core_theme.AC.gold),
            _Stat('تأمين طبي', '87 موظف', Icons.medical_services, core_theme.AC.ok),
            _Stat('WPS هذا الشهر', 'جاهز ✓', Icons.check_circle, core_theme.AC.ok),
          ]),
          const SizedBox(height: 16),
          Text('ملخص المزايا', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 800 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 2.3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _benefitCard('GOSI (التأمينات الاجتماعية)', 'مساهمة الشركة 11% + 10% الموظف', '142K ر.س/شهر', Icons.health_and_safety, core_theme.AC.info),
                  _benefitCard('EOSB (مكافأة نهاية الخدمة)', 'نصف شهر لكل سنة أوّل 5 + شهر كامل بعدها', '680K ر.س متراكم', Icons.savings, core_theme.AC.gold),
                  _benefitCard('WPS (نظام حماية الأجور)', 'ملف SIF جاهز — يُسلَّم شهرياً لـ Mudad', 'جاهز ✓', Icons.shield, core_theme.AC.ok),
                  _benefitCard('التأمين الطبي', '87 موظف · شركة BUPA · درجة A', '320K ر.س/سنة', Icons.medical_services, core_theme.AC.purple),
                  _benefitCard('بدل النقل', 'حسب مستوى الوظيفة', '450-1,500 ر.س', Icons.directions_car, core_theme.AC.warn),
                  _benefitCard('بدل السكن', '25% من الراتب الأساسي', 'محسوب تلقائياً', Icons.home, const Color(0xFFEC4899)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _benefitCard(String title, String desc, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
                  maxLines: 2,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsRow(List<_Stat> stats) {
    return Row(
      children: [
        for (final s in stats) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: s.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: s.color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: s.color)),
                        Text(s.label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (s != stats.last) const SizedBox(width: 8),
        ],
      ],
    );
  }

  void _onRecodeEmployees() {
    showRecodeDialogWithUndo(
      context: context,
      count: _selectedEmployees.length,
      itemTypeLabelAr: 'موظف',
      fields: [
        V5RecodeField(
          key: 'department',
          labelAr: 'القسم',
          options: [
            V5RecodeOption('finance', 'المالية'),
            V5RecodeOption('ops', 'العمليات'),
            V5RecodeOption('hr', 'الموارد البشرية'),
            V5RecodeOption('it', 'تقنية المعلومات'),
          ],
        ),
        V5RecodeField(
          key: 'cost_center',
          labelAr: 'مركز التكلفة',
          options: [
            V5RecodeOption('cc1', 'CC-001 الإدارة'),
            V5RecodeOption('cc2', 'CC-002 المبيعات'),
            V5RecodeOption('cc3', 'CC-003 العمليات'),
          ],
        ),
      ],
      apply: (_) => setState(() => _selectedEmployees.clear()),
      undo: () {},
    );
  }

  void _onLeaveApprove(String employee) {
    ApexV5UndoToast.show(
      context,
      messageAr: 'تم اعتماد إجازة $employee',
      onUndo: () {},
    );
  }

  void _onLeaveReject(String employee) {
    ApexV5UndoToast.show(
      context,
      messageAr: 'تم رفض طلب $employee',
      icon: Icons.close,
      color: const Color(0xFFB91C1C),
      onUndo: () {},
    );
  }

  void _onExport(String what) {
    ApexV5UndoToast.show(context, messageAr: 'تصدير $what (Excel)...');
  }

  // ── Mock ──────────────────────────────────────────────────────────

  List<_Employee> _mockEmployees() => [
        _Employee('EMP-001', 'أحمد السالم', 'CEO', 'التنفيذي', 'active', '2020-06-01'),
        _Employee('EMP-002', 'سارة محمود', 'المدير المالي', 'المالية', 'active', '2021-03-15'),
        _Employee('EMP-003', 'محمد الراشد', 'مدير العمليات', 'العمليات', 'active', '2023-05-01'),
        _Employee('EMP-004', 'نورا القحطاني', 'مدير HR', 'الموارد البشرية', 'active', '2021-09-01'),
        _Employee('EMP-005', 'خالد أحمد', 'محاسب أول', 'المالية', 'active', '2022-09-01'),
        _Employee('EMP-006', 'فاطمة علي', 'مسؤول مخزون', 'العمليات', 'on_leave', '2024-01-15'),
        _Employee('EMP-007', 'يوسف الحارثي', 'محاسب', 'المالية', 'active', '2024-06-01'),
        _Employee('EMP-008', 'ليلى السعيد', 'محاسب', 'المالية', 'active', '2025-03-01'),
        _Employee('EMP-009', 'حمد الدوسري', 'HR Specialist', 'الموارد البشرية', 'active', '2023-11-01'),
      ];

  List<_LeaveRequest> _mockLeaves() => [
        _LeaveRequest('محمد الراشد', 'سنوية', 7, '2026-05-01', '2026-05-08', 'pending', reason: 'عطلة عائلية'),
        _LeaveRequest('فاطمة علي', 'أمومة', 60, '2026-04-15', '2026-06-15', 'approved'),
        _LeaveRequest('خالد أحمد', 'مرضية', 3, '2026-04-20', '2026-04-23', 'pending'),
        _LeaveRequest('ليلى السعيد', 'طارئة', 2, '2026-04-22', '2026-04-24', 'pending', reason: 'ظرف عائلي'),
        _LeaveRequest('يوسف الحارثي', 'سنوية', 5, '2026-03-10', '2026-03-15', 'approved'),
      ];
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _Stat(this.label, this.value, this.icon, this.color);
}

class _Employee {
  final String id;
  final String name;
  final String role;
  final String dept;
  final String status;
  final String hireDate;
  _Employee(this.id, this.name, this.role, this.dept, this.status, this.hireDate);
}

class _LeaveRequest {
  final String employee;
  final String type;
  final int days;
  final String startDate;
  final String endDate;
  final String status;
  final String? reason;
  _LeaveRequest(this.employee, this.type, this.days, this.startDate, this.endDate, this.status, {this.reason});
}

class _EmployeeCard extends StatelessWidget {
  final _Employee employee;
  final bool selected;
  final ValueChanged<bool> onToggle;

  const _EmployeeCard({required this.employee, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final statusColor = employee.status == 'active'
        ? core_theme.AC.ok
        : employee.status == 'on_leave'
            ? core_theme.AC.warn
            : core_theme.AC.ts;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? core_theme.AC.gold.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected
              ? core_theme.AC.gold
              : core_theme.AC.tp.withOpacity(0.08),
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Checkbox(value: selected, onChanged: (v) => onToggle(v ?? false)),
          CircleAvatar(
            radius: 22,
            backgroundColor: core_theme.AC.gold.withOpacity(0.2),
            child: Text(
              employee.name.substring(0, 1),
              style: TextStyle(
                color: core_theme.AC.gold,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        employee.name,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                  ],
                ),
                Text(employee.role, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: core_theme.AC.tp.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        employee.dept,
                        style: TextStyle(fontSize: 9, color: core_theme.AC.ts),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      employee.id,
                      style: TextStyle(fontSize: 9, color: core_theme.AC.td, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
