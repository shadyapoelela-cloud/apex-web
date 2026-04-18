/// APEX Wave 29 — Admin Panel (Tenant Settings + Users + Integrations).
///
/// Route: /settings
library;

import 'package:flutter/material.dart';

import '../../core/v5/apex_v5_undo_toast.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 240, child: _buildSidebar()),
        const VerticalDivider(width: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('الإعدادات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF4A148C))),
          ),
          _sidebarGroup('المؤسّسة', [
            _sidebarItem(0, 'معلومات الشركة', Icons.business),
            _sidebarItem(1, 'المستخدمون والصلاحيات', Icons.group),
            _sidebarItem(2, 'الفروع والكيانات', Icons.account_tree),
          ]),
          _sidebarGroup('التكاملات', [
            _sidebarItem(3, 'التكاملات الخارجية', Icons.extension),
            _sidebarItem(4, 'Webhooks', Icons.webhook),
            _sidebarItem(5, 'API Keys', Icons.key),
          ]),
          _sidebarGroup('الذكاء الاصطناعي', [
            _sidebarItem(6, 'وكلاء الذكاء', Icons.auto_awesome),
            _sidebarItem(7, 'قواعد Guardrails', Icons.shield),
          ]),
          _sidebarGroup('العلامة التجارية', [
            _sidebarItem(8, 'White-Label', Icons.palette),
            _sidebarItem(9, 'موّلد السمات', Icons.color_lens),
          ]),
          _sidebarGroup('الحسابات', [
            _sidebarItem(10, 'الاشتراكات', Icons.card_membership),
            _sidebarItem(11, 'الفواتير', Icons.receipt_long),
            _sidebarItem(12, 'سجل الأمان', Icons.security),
          ]),
        ],
      ),
    );
  }

  Widget _sidebarGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
          child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.black54, letterSpacing: 1)),
        ),
        ...children,
      ],
    );
  }

  Widget _sidebarItem(int idx, String label, IconData icon) {
    final active = _section == idx;
    return GestureDetector(
      onTap: () => setState(() => _section = idx),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4A148C).withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: active ? const Color(0xFF4A148C) : Colors.black54),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w800 : FontWeight.w500, color: active ? const Color(0xFF4A148C) : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_section) {
      case 0: return _tenantInfo();
      case 1: return _usersRoles();
      case 2: return _entities();
      case 3: return _integrations();
      case 4: return _webhooks();
      case 5: return _apiKeys();
      case 6: return _aiAgents();
      case 7: return _guardrails();
      case 8: return _whiteLabel();
      case 9: return _themeGen();
      case 10: return _subscriptions();
      case 11: return _billing();
      case 12: return _security();
      default: return const SizedBox();
    }
  }

  Widget _tenantInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('معلومات الشركة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                      child: const Icon(Icons.bolt, size: 48, color: Color(0xFFD4AF37)),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('شركة الرياض للتجارة', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        const Text('سجل تجاري: 1010123456 · VAT: 300001234500003', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.edit, size: 14), label: const Text('تعديل')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _formRow('الاسم بالعربي', 'شركة الرياض للتجارة'),
                _formRow('Name (English)', 'Riyadh Trading Co.'),
                _formRow('السجل التجاري', '1010123456'),
                _formRow('الرقم الضريبي', '300001234500003'),
                _formRow('العنوان', 'الرياض، حي النخيل، شارع الملك فهد'),
                _formRow('الهاتف', '+966 11 234 5678'),
                _formRow('البريد', 'admin@riyadh-trading.com'),
                _formRow('الموقع', 'www.riyadh-trading.com'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _formRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 150, child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: Colors.black.withOpacity(0.1)), borderRadius: BorderRadius.circular(4)),
              child: Text(value, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _usersRoles() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('المستخدمون والصلاحيات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add, size: 16),
                label: const Text('دعوة مستخدم'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Role bundles
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.08))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الأدوار المُعدّة مسبقاً (Role Bundles)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final cols = constraints.maxWidth > 600 ? 4 : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: cols,
                      childAspectRatio: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _roleTile('المحاسب', 'erp.*.*.view+post+edit', 3, const Color(0xFF2563EB)),
                        _roleTile('المراجع (Auditor)', 'audit.*.*.*', 1, const Color(0xFF4A148C)),
                        _roleTile('المدير المالي', 'erp.*.*.approve', 1, const Color(0xFF059669)),
                        _roleTile('مسؤول الامتثال', 'compliance.*.*.*', 1, const Color(0xFF2E7D5B)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('المستخدمون النشطون', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final u in [
            _User('أحمد السالم', 'CEO', 'admin@riyadh-trading.com', 'مدير النظام', const Color(0xFFB91C1C), true),
            _User('سارة محمود', 'CFO', 'sarah@riyadh-trading.com', 'المدير المالي', const Color(0xFF059669), true),
            _User('خالد أحمد', 'محاسب', 'khaled@riyadh-trading.com', 'المحاسب', const Color(0xFF2563EB), true),
            _User('نورا القحطاني', 'HR Manager', 'nora@riyadh-trading.com', 'مدير النظام', const Color(0xFFB91C1C), true),
            _User('محمد الراشد', 'مدير العمليات', 'mohammed@riyadh-trading.com', 'المحاسب', const Color(0xFF2563EB), false),
          ])
            _userRow(u),
        ],
      ),
    );
  }

  Widget _roleTile(String name, String capability, int users, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.shield, color: Colors.white, size: 14),
              ),
              const Spacer(),
              Text('$users', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          Text(capability, style: const TextStyle(fontSize: 9, color: Colors.black54, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _userRow(_User u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black.withOpacity(0.08))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: u.roleColor.withOpacity(0.2),
            child: Text(u.name.substring(0, 1), style: TextStyle(color: u.roleColor, fontSize: 18, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text(u.title, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text(u.email, style: const TextStyle(fontSize: 11, color: Colors.black54, fontFamily: 'monospace'))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: u.roleColor.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(u.role, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: u.roleColor)),
          ),
          const SizedBox(width: 8),
          if (u.twoFa) ...[
            const Icon(Icons.verified_user, size: 14, color: Color(0xFF059669)),
            const SizedBox(width: 4),
            const Text('2FA', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
          ] else ...[
            const Icon(Icons.warning, size: 14, color: Color(0xFFD97706)),
            const SizedBox(width: 4),
            const Text('No 2FA', style: TextStyle(fontSize: 10, color: Color(0xFFD97706))),
          ],
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.edit, size: 14), onPressed: () {}),
          IconButton(icon: const Icon(Icons.block, size: 14, color: Color(0xFFB91C1C)), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _integrations() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('التكاملات الخارجية', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const Text('الحكومية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 2.5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _intCard('زاتكا (Fatoora)', 'فوترة إلكترونية', const Color(0xFF2E7D5B), connected: true),
                  _intCard('GOSI', 'التأمينات الاجتماعية', const Color(0xFF2563EB), connected: true),
                  _intCard('Mudad (WPS)', 'حماية الأجور', const Color(0xFF7C3AED), connected: true),
                  _intCard('UAE FTA', 'ضريبة الإمارات', const Color(0xFFD4AF37), connected: false),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('البنوك', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 900 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 2.5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _intCard('Lean Technologies', 'Open Banking', const Color(0xFF059669), connected: true),
                  _intCard('Tarabut Gateway', 'Open Banking', const Color(0xFF059669), connected: true),
                  _intCard('Salt Edge', 'Banking APIs', const Color(0xFF059669), connected: false),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Text('الذكاء الاصطناعي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 900 ? 3 : 2;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 2.5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _intCard('Anthropic Claude', 'Copilot + OCR', const Color(0xFFEC4899), connected: true),
                  _intCard('OpenAI', 'Alternative AI', const Color(0xFF059669), connected: false),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _intCard(String name, String purpose, Color color, {required bool connected}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: connected ? color.withOpacity(0.4) : Colors.black.withOpacity(0.08), width: connected ? 2 : 1)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.extension, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(purpose, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          if (connected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF059669), borderRadius: BorderRadius.circular(3)),
              child: const Text('متصل', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800)),
            )
          else
            OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)), child: const Text('اتصل', style: TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _entities() => _comingSection('الفروع والكيانات', 'إدارة متعدّدة الكيانات — فروع + شركات فرعية');
  Widget _webhooks() => _comingSection('Webhooks', 'أحداث واقعية على endpoints خارجية');
  Widget _apiKeys() => _comingSection('API Keys', 'مفاتيح الـ REST API للتكاملات المخصّصة');
  Widget _aiAgents() => _comingSection('معرض وكلاء الذكاء', 'Copilot · Anomaly Scanner · Risk Scorer · Bank Rec');
  Widget _guardrails() => _comingSection('AI Guardrails', 'قواعد الاعتماد لقرارات الذكاء');
  Widget _whiteLabel() => _comingSection('White-Label', 'نطاق مخصّص · ألوان + شعار + قوالب بريد');
  Widget _themeGen() => _comingSection('مولّد السمات', 'Linear-style 3-variable theme generator');
  Widget _subscriptions() => _comingSection('الاشتراكات', 'خطط APEX — ERP/Compliance/Audit/Advisory/Marketplace');
  Widget _billing() => _comingSection('الفواتير', 'سجل فواتير APEX');
  Widget _security() => _comingSection('سجل الأمان', 'Hash-chain audit — من فعل ماذا ومتى');

  Widget _comingSection(String title, String desc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.settings, size: 64, color: Colors.black26),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black54), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _User {
  final String name, title, email, role;
  final Color roleColor;
  final bool twoFa;
  _User(this.name, this.title, this.email, this.role, this.roleColor, this.twoFa);
}

/// Wave 30 — Custom Report Builder.
class ReportBuilderScreen extends StatefulWidget {
  const ReportBuilderScreen({super.key});

  @override
  State<ReportBuilderScreen> createState() => _ReportBuilderScreenState();
}

class _ReportBuilderScreenState extends State<ReportBuilderScreen> {
  String _reportName = 'تقرير مبيعات ربع سنوي';
  final List<String> _selectedColumns = ['التاريخ', 'العميل', 'المبلغ', 'VAT', 'الإجمالي'];
  final List<String> _filters = ['الربع = Q1 2026'];
  final List<String> _groupBy = ['العميل'];
  String _chartType = 'bar';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 320, child: _buildBuilder()),
        const VerticalDivider(width: 1),
        Expanded(child: _buildPreview()),
      ],
    );
  }

  Widget _buildBuilder() {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Row(
            children: [
              Icon(Icons.architecture, color: Color(0xFF4A148C), size: 20),
              SizedBox(width: 8),
              Text('مُنشئ التقارير', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          _builderSection('اسم التقرير', TextField(
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'تقرير مبيعات ربع سنوي',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            ),
            controller: TextEditingController(text: _reportName),
          )),
          _builderSection('مصدر البيانات', Wrap(
            spacing: 6,
            runSpacing: 6,
            children: const [
              Chip(label: Text('الفواتير'), avatar: Icon(Icons.receipt, size: 14)),
              Chip(label: Text('العملاء'), avatar: Icon(Icons.person, size: 14)),
              Chip(label: Text('القيود'), avatar: Icon(Icons.book, size: 14)),
            ],
          )),
          _builderSection('الأعمدة', Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final col in _selectedColumns)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(col, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      const Icon(Icons.close, size: 11, color: Color(0xFF2563EB)),
                    ],
                  ),
                ),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 12), label: const Text('+ عمود', style: TextStyle(fontSize: 11))),
            ],
          )),
          _builderSection('المرشحات (Filters)', Column(
            children: [
              for (final f in _filters)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFD97706).withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 12, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      Expanded(child: Text(f, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                      const Icon(Icons.close, size: 12, color: Color(0xFFD97706)),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 12), label: const Text('+ مرشّح', style: TextStyle(fontSize: 11))),
            ],
          )),
          _builderSection('التجميع (Group By)', Wrap(
            spacing: 4,
            children: [
              for (final g in _groupBy)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                  child: Text(g, style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                ),
            ],
          )),
          _builderSection('نوع الرسم البياني', Wrap(
            spacing: 4,
            children: [
              _chartBtn('bar', 'أعمدة', Icons.bar_chart),
              _chartBtn('line', 'خطّي', Icons.show_chart),
              _chartBtn('pie', 'دائري', Icons.pie_chart),
              _chartBtn('none', 'بدون', Icons.table_chart),
            ],
          )),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ApexV5UndoToast.show(context, messageAr: 'تم حفظ التقرير · متاح في Saved Reports', onUndo: () {});
                  },
                  icon: const Icon(Icons.save, size: 14),
                  label: const Text('احفظ'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 6),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.schedule, size: 14), label: const Text('جدولة')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _builderSection(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black.withOpacity(0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _chartBtn(String type, String label, IconData icon) {
    final active = _chartType == type;
    return GestureDetector(
      onTap: () => setState(() => _chartType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF4A148C).withOpacity(0.12) : null,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? const Color(0xFF4A148C) : Colors.black.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: active ? const Color(0xFF4A148C) : Colors.black54),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? const Color(0xFF4A148C) : Colors.black54)),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08)))),
          child: Row(
            children: [
              const Text('معاينة مباشرة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.picture_as_pdf, size: 14), label: const Text('PDF')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.file_download, size: 14), label: const Text('Excel')),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.1))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_reportName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            const Text('شركة الرياض للتجارة · Q1 2026', style: TextStyle(fontSize: 11, color: Colors.black54)),
                          ],
                        ),
                      ),
                      Image.network(
                        'https://via.placeholder.com/80x80',
                        width: 60,
                        height: 60,
                        errorBuilder: (_, __, ___) => Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.bolt, size: 32, color: Color(0xFFD4AF37)),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // Chart placeholder
                  if (_chartType != 'none')
                    Container(
                      height: 180,
                      decoration: BoxDecoration(color: const Color(0xFF4A148C).withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final h in [0.4, 0.6, 0.8, 0.5, 0.9, 0.7, 0.55])
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Container(
                                  height: 150 * h,
                                  decoration: BoxDecoration(color: const Color(0xFF4A148C), borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Table
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.black.withOpacity(0.08)), borderRadius: BorderRadius.circular(6)),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF9FAFB)),
                      headingTextStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      dataTextStyle: const TextStyle(fontSize: 11),
                      columns: const [
                        DataColumn(label: Text('التاريخ')),
                        DataColumn(label: Text('العميل')),
                        DataColumn(label: Text('المبلغ'), numeric: true),
                        DataColumn(label: Text('VAT'), numeric: true),
                        DataColumn(label: Text('الإجمالي'), numeric: true),
                      ],
                      rows: const [
                        DataRow(cells: [
                          DataCell(Text('2026-01-15')),
                          DataCell(Text('SABIC')),
                          DataCell(Text('45,000')),
                          DataCell(Text('6,750')),
                          DataCell(Text('51,750')),
                        ]),
                        DataRow(cells: [
                          DataCell(Text('2026-02-08')),
                          DataCell(Text('Al Rajhi')),
                          DataCell(Text('28,500')),
                          DataCell(Text('4,275')),
                          DataCell(Text('32,775')),
                        ]),
                        DataRow(cells: [
                          DataCell(Text('2026-02-22')),
                          DataCell(Text('Marriott')),
                          DataCell(Text('15,000')),
                          DataCell(Text('2,250')),
                          DataCell(Text('17,250')),
                        ]),
                        DataRow(cells: [
                          DataCell(Text('2026-03-05')),
                          DataCell(Text('STC')),
                          DataCell(Text('12,500')),
                          DataCell(Text('1,875')),
                          DataCell(Text('14,375')),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF059669).withOpacity(0.08), borderRadius: BorderRadius.circular(4)),
                    child: const Row(
                      children: [
                        Icon(Icons.functions, size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 6),
                        Text('الإجمالي العام: 116,150 ر.س · VAT: 15,150 ر.س', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
