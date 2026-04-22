/// APEX Wave 55 — Expense Claims.
/// Route: /app/erp/finance/expenses
///
/// Employee expense submission + approval + reimbursement.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ExpenseClaimsScreen extends StatefulWidget {
  const ExpenseClaimsScreen({super.key});
  @override
  State<ExpenseClaimsScreen> createState() => _ExpenseClaimsScreenState();
}

class _ExpenseClaimsScreenState extends State<ExpenseClaimsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  final _claims = <_Claim>[
    _Claim('EXP-2026-0287', 'أحمد محمد العتيبي', 'سفر عمل — الرياض', 4850, '2026-04-17', 'قيد الاعتماد', 3, 'travel'),
    _Claim('EXP-2026-0286', 'سارة خالد الدوسري', 'ضيافة عميل — غداء مع SABIC', 1850, '2026-04-16', 'معتمد', 2, 'hospitality'),
    _Claim('EXP-2026-0285', 'محمد عبدالله القحطاني', 'مصاريف طباعة — ملفات المراجعة', 680, '2026-04-15', 'مسدّد', 1, 'office'),
    _Claim('EXP-2026-0284', 'نورة سعد الغامدي', 'مواصلات لعميل — ديمة', 420, '2026-04-15', 'معتمد', 1, 'transport'),
    _Claim('EXP-2026-0283', 'فهد ناصر الشمري', 'شراء برنامج محاسبي — ترخيص', 3200, '2026-04-12', 'قيد الاعتماد', 2, 'software'),
    _Claim('EXP-2026-0282', 'لينا عادل البكري', 'تدريب موظفين — دورة AML', 8500, '2026-04-10', 'مسدّد', 5, 'training'),
    _Claim('EXP-2026-0281', 'أحمد محمد العتيبي', 'مؤتمر مالي في دبي', 12800, '2026-04-05', 'مسدّد', 8, 'travel'),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        _buildKpiRow(),
        TabBar(
          controller: _tab,
          labelColor: core_theme.AC.gold,
          unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold,
          tabs: const [
            Tab(icon: Icon(Icons.list, size: 16), text: 'جميع المطالبات'),
            Tab(icon: Icon(Icons.add_circle, size: 16), text: 'مطالبة جديدة'),
            Tab(icon: Icon(Icons.analytics, size: 16), text: 'تحليل المصروفات'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _buildListTab(),
              _buildNewClaimTab(),
              _buildAnalyticsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF1976D2)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.receipt, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مطالبات المصروفات',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('تقديم مطالبة، اعتمادها، وتسديدها — مع ربط بإيصالات OCR تلقائية',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiRow() {
    final pending = _claims.where((c) => c.status == 'قيد الاعتماد').length;
    final approved = _claims.where((c) => c.status == 'معتمد').length;
    final paid = _claims.where((c) => c.status == 'مسدّد').length;
    final totalPending = _claims.where((c) => c.status != 'مسدّد').fold(0.0, (s, c) => s + c.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _kpi('قيد الاعتماد', '$pending', core_theme.AC.warn, Icons.schedule),
          _kpi('معتمدة للسداد', '$approved', core_theme.AC.info, Icons.check_circle),
          _kpi('مسدّدة هذا الشهر', '$paid', core_theme.AC.ok, Icons.payment),
          _kpi('قيمة المعلّق', _fmt(totalPending), core_theme.AC.gold, Icons.attach_money),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _claims.length,
      itemBuilder: (ctx, i) {
        final c = _claims[i];
        final sc = _statusColor(c.status);
        final cat = _categoryInfo(c.category);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(cat.icon, color: cat.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person, size: 12, color: core_theme.AC.td),
                        const SizedBox(width: 4),
                        Text(c.employee, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                        const SizedBox(width: 10),
                        Icon(Icons.calendar_today, size: 12, color: core_theme.AC.td),
                        const SizedBox(width: 4),
                        Text(c.date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                        const SizedBox(width: 10),
                        Icon(Icons.attach_file, size: 12, color: core_theme.AC.td),
                        const SizedBox(width: 4),
                        Text('${c.receipts} إيصال', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt(c.amount),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
                  Text('ر.س', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sc.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(c.status, style: TextStyle(fontSize: 11, color: sc, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              if (c.status == 'قيد الاعتماد') ...[
                const SizedBox(width: 8),
                Column(
                  children: [
                    IconButton(
                      icon: Icon(Icons.check_circle, color: core_theme.AC.ok, size: 22),
                      onPressed: () => setState(() => c.status = 'معتمد'),
                      tooltip: 'اعتماد',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                    ),
                    IconButton(
                      icon: Icon(Icons.cancel, color: core_theme.AC.err, size: 22),
                      onPressed: () => setState(() => c.status = 'مرفوض'),
                      tooltip: 'رفض',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 28),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNewClaimTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: core_theme.AC.info,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: core_theme.AC.info),
          ),
          child: Row(
            children: [
              Icon(Icons.camera_alt, color: core_theme.AC.info, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ارفع إيصالاتك — نحن نستخرج البيانات',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.info)),
                    Text('OCR يستخرج المبلغ، التاريخ، وBرقم الضريبي تلقائياً',
                        style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: core_theme.AC.bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('معلومات المطالبة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _formField('الموظف', 'أحمد محمد العتيبي', Icons.person, readOnly: true),
              _formField('تاريخ المصروف', '2026-04-19', Icons.calendar_today),
              _formField('العنوان', 'سفر عمل إلى جدة لاجتماع عملاء', Icons.title),
              _formField('المبلغ بالريال', '3200', Icons.attach_money),
              const SizedBox(height: 12),
              Text('الفئة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _catChip('travel', 'سفر', Icons.flight),
                  _catChip('transport', 'مواصلات', Icons.local_taxi),
                  _catChip('hospitality', 'ضيافة', Icons.restaurant),
                  _catChip('office', 'مكتبية', Icons.print),
                  _catChip('software', 'برامج', Icons.apps),
                  _catChip('training', 'تدريب', Icons.school),
                  _catChip('other', 'أخرى', Icons.more_horiz),
                ],
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () {},
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: core_theme.AC.navy3,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: core_theme.AC.td, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload, size: 32, color: core_theme.AC.td),
                      SizedBox(height: 6),
                      Text('اسحب وأفلت الإيصالات هنا أو اضغط للاختيار',
                          style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
                      Text('JPG / PNG / PDF — حد أقصى 10MB',
                          style: TextStyle(fontSize: 10, color: core_theme.AC.td)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {},
                      child: Text('حفظ كمسوّدة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('أُرسلت المطالبة للمدير المباشر للاعتماد'),
                            backgroundColor: core_theme.AC.ok,
                          ),
                        );
                      },
                      icon: const Icon(Icons.send, size: 16),
                      label: Text('إرسال للاعتماد'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: core_theme.AC.gold,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formField(String label, String value, IconData icon, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          isDense: true,
          filled: readOnly,
          fillColor: readOnly ? core_theme.AC.navy3 : null,
        ),
        controller: TextEditingController(text: value),
      ),
    );
  }

  Widget _catChip(String id, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: core_theme.AC.td),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final byCategory = <String, double>{};
    for (final c in _claims) {
      byCategory[c.category] = (byCategory[c.category] ?? 0) + c.amount;
    }
    final total = byCategory.values.fold(0.0, (s, v) => s + v);
    final byEmp = <String, double>{};
    for (final c in _claims) {
      byEmp[c.employee] = (byEmp[c.employee] ?? 0) + c.amount;
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: core_theme.AC.bdr),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('حسب الفئة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    for (final e in byCategory.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Icon(_categoryInfo(e.key).icon, size: 16, color: _categoryInfo(e.key).color),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_catName(e.key), style: const TextStyle(fontSize: 12))),
                            Text('${_fmt(e.value)} ر.س',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                            const SizedBox(width: 8),
                            Container(
                              width: 48,
                              alignment: Alignment.centerRight,
                              child: Text('${(e.value / total * 100).toStringAsFixed(0)}%',
                                  style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: core_theme.AC.bdr),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('حسب الموظف', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    for (final e in byEmp.entries)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: core_theme.AC.gold.withOpacity(0.15),
                              child: Icon(Icons.person, size: 14, color: core_theme.AC.gold),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                            Text('${_fmt(e.value)} ر.س',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  _CatInfo _categoryInfo(String cat) {
    switch (cat) {
      case 'travel':
        return _CatInfo(Icons.flight, core_theme.AC.info);
      case 'transport':
        return _CatInfo(Icons.local_taxi, core_theme.AC.warn);
      case 'hospitality':
        return _CatInfo(Icons.restaurant, core_theme.AC.ok);
      case 'office':
        return _CatInfo(Icons.print, core_theme.AC.td);
      case 'software':
        return _CatInfo(Icons.apps, core_theme.AC.purple);
      case 'training':
        return _CatInfo(Icons.school, core_theme.AC.err);
      default:
        return _CatInfo(Icons.category, core_theme.AC.info);
    }
  }

  String _catName(String cat) {
    switch (cat) {
      case 'travel':
        return 'سفر';
      case 'transport':
        return 'مواصلات';
      case 'hospitality':
        return 'ضيافة';
      case 'office':
        return 'مكتبية';
      case 'software':
        return 'برامج';
      case 'training':
        return 'تدريب';
      default:
        return 'أخرى';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'قيد الاعتماد':
        return core_theme.AC.warn;
      case 'معتمد':
        return core_theme.AC.info;
      case 'مسدّد':
        return core_theme.AC.ok;
      case 'مرفوض':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Claim {
  final String id;
  final String employee;
  final String title;
  final double amount;
  final String date;
  String status;
  final int receipts;
  final String category;
  _Claim(this.id, this.employee, this.title, this.amount, this.date, this.status, this.receipts, this.category);
}

class _CatInfo {
  final IconData icon;
  final Color color;
  const _CatInfo(this.icon, this.color);
}
