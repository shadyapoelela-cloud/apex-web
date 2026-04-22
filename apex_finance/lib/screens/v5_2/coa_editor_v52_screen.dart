/// V5.2 — Chart of Accounts Editor using TreeView pattern.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class CoaEditorV52Screen extends StatefulWidget {
  const CoaEditorV52Screen({super.key});

  @override
  State<CoaEditorV52Screen> createState() => _CoaEditorV52ScreenState();
}

class _CoaEditorV52ScreenState extends State<CoaEditorV52Screen> {
  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  final Set<String> _expanded = {'1', '11', '12', '13', '2', '21', '22', '3', '4', '41', '5'};
  String? _selectedId;
  _AcctType? _filter;

  late final Map<String, _Account> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = _buildCoA();
  }

  Map<String, _Account> _buildCoA() {
    final map = <String, _Account>{};
    void add(String id, String name, String nameEn, _AcctType type, String? parent, {double balance = 0, bool isLeaf = false}) {
      map[id] = _Account(id, name, nameEn, type, parent, balance, isLeaf);
    }

    // Assets (1)
    add('1', 'الأصول', 'Assets', _AcctType.asset, null, balance: 36970000);
    add('11', 'الأصول المتداولة', 'Current Assets', _AcctType.asset, '1', balance: 11130000);
    add('1110', 'النقدية والبنوك', 'Cash & Banks', _AcctType.asset, '11', balance: 3240000, isLeaf: true);
    add('1120', 'الاستثمارات قصيرة الأجل', 'Short-term Investments', _AcctType.asset, '11', balance: 1400000, isLeaf: true);
    add('1210', 'الذمم المدينة التجارية', 'Trade Receivables', _AcctType.asset, '11', balance: 4580000, isLeaf: true);
    add('1220', 'ذمم مدينة أخرى', 'Other Receivables', _AcctType.asset, '11', balance: 820000, isLeaf: true);
    add('1310', 'المخزون', 'Inventory', _AcctType.asset, '11', balance: 890000, isLeaf: true);
    add('1320', 'المصروفات المدفوعة مقدماً', 'Prepayments', _AcctType.asset, '11', balance: 200000, isLeaf: true);
    add('12', 'الأصول غير المتداولة', 'Non-current Assets', _AcctType.asset, '1', balance: 25840000);
    add('1410', 'الأراضي والمباني', 'Land & Buildings', _AcctType.asset, '12', balance: 18500000, isLeaf: true);
    add('1420', 'السيارات والمعدات', 'Vehicles & Equipment', _AcctType.asset, '12', balance: 1840000, isLeaf: true);
    add('1430', 'أجهزة الكمبيوتر', 'Computer Equipment', _AcctType.asset, '12', balance: 1100000, isLeaf: true);
    add('1490', 'مجمّع الإهلاك', 'Accumulated Depreciation', _AcctType.asset, '12', balance: -3040000, isLeaf: true);
    add('1510', 'الاستثمارات طويلة الأجل', 'Long-term Investments', _AcctType.asset, '12', balance: 5600000, isLeaf: true);
    add('1610', 'الأصول غير الملموسة', 'Intangible Assets', _AcctType.asset, '12', balance: 1840000, isLeaf: true);
    add('13', 'الضرائب المؤجلة — أصل', 'Deferred Tax Assets', _AcctType.asset, '1', balance: 0, isLeaf: true);

    // Liabilities (2)
    add('2', 'الالتزامات', 'Liabilities', _AcctType.liability, null, balance: 14620000);
    add('21', 'الالتزامات المتداولة', 'Current Liabilities', _AcctType.liability, '2', balance: 5020000);
    add('2110', 'الذمم الدائنة التجارية', 'Trade Payables', _AcctType.liability, '21', balance: 2840000, isLeaf: true);
    add('2120', 'قروض قصيرة الأجل', 'Short-term Loans', _AcctType.liability, '21', balance: 1500000, isLeaf: true);
    add('2210', 'ضرائب مستحقة', 'Tax Payable', _AcctType.liability, '21', balance: 680000, isLeaf: true);
    add('2220', 'مصروفات مستحقة', 'Accrued Expenses', _AcctType.liability, '21', balance: 0, isLeaf: true);
    add('22', 'الالتزامات غير المتداولة', 'Non-current Liabilities', _AcctType.liability, '2', balance: 9600000);
    add('2310', 'قروض طويلة الأجل', 'Long-term Loans', _AcctType.liability, '22', balance: 8400000, isLeaf: true);
    add('2320', 'مخصصات نهاية الخدمة', 'End-of-service Provisions', _AcctType.liability, '22', balance: 1200000, isLeaf: true);

    // Equity (3)
    add('3', 'حقوق الملكية', 'Equity', _AcctType.equity, null, balance: 22350000);
    add('3110', 'رأس المال المدفوع', 'Paid-up Capital', _AcctType.equity, '3', balance: 10000000, isLeaf: true);
    add('3210', 'الاحتياطي النظامي', 'Statutory Reserve', _AcctType.equity, '3', balance: 2500000, isLeaf: true);
    add('3310', 'الأرباح المحتجزة', 'Retained Earnings', _AcctType.equity, '3', balance: 9850000, isLeaf: true);

    // Revenue (4)
    add('4', 'الإيرادات', 'Revenue', _AcctType.revenue, null, balance: -19000000);
    add('41', 'إيرادات المبيعات', 'Sales Revenue', _AcctType.revenue, '4', balance: -14200000);
    add('4110', 'مبيعات المنتجات', 'Product Sales', _AcctType.revenue, '41', balance: -10400000, isLeaf: true);
    add('4120', 'مبيعات الخدمات', 'Service Sales', _AcctType.revenue, '41', balance: -3800000, isLeaf: true);
    add('4210', 'إيرادات تشغيلية أخرى', 'Other Operating Revenue', _AcctType.revenue, '4', balance: -4800000, isLeaf: true);

    // Expenses (5)
    add('5', 'المصروفات', 'Expenses', _AcctType.expense, null, balance: 13438000);
    add('5110', 'تكلفة المبيعات — منتجات', 'COGS — Products', _AcctType.expense, '5', balance: 7100000, isLeaf: true);
    add('5120', 'تكلفة المبيعات — خدمات', 'COGS — Services', _AcctType.expense, '5', balance: 1900000, isLeaf: true);
    add('5210', 'الرواتب والأجور', 'Salaries & Wages', _AcctType.expense, '5', balance: 1842000, isLeaf: true);
    add('5220', 'الإيجارات والمرافق', 'Rent & Utilities', _AcctType.expense, '5', balance: 420000, isLeaf: true);
    add('5230', 'التسويق والإعلان', 'Marketing & Advertising', _AcctType.expense, '5', balance: 380000, isLeaf: true);
    add('5240', 'الإهلاك والاستهلاك', 'Depreciation & Amortization', _AcctType.expense, '5', balance: 800000, isLeaf: true);
    add('5250', 'المصروفات المالية', 'Financial Expenses', _AcctType.expense, '5', balance: 420000, isLeaf: true);
    add('5260', 'الزكاة والضرائب', 'Zakat & Tax', _AcctType.expense, '5', balance: 576000, isLeaf: true);

    return map;
  }

  List<_Account> _topLevel() => _accounts.values.where((a) => a.parent == null).toList();

  List<_Account> _children(String id) => _accounts.values.where((a) => a.parent == id).toList();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(children: [
          _header(),
          _statsRow(),
          _toolbar(),
          const Divider(height: 1),
          Expanded(child: Row(children: [
            Expanded(flex: 3, child: _tree()),
            if (_selectedId != null) ...[
              const VerticalDivider(width: 1),
              SizedBox(width: 360, child: _details()),
            ],
          ])),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Icon(Icons.account_tree, color: _gold),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('دليل الحسابات (Chart of Accounts)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
          Text('SOCPA 2017 · IFRS · 42 حساب نشط', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
        ])),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.file_upload, size: 16), label: Text('استيراد من Excel')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.file_download, size: 16), label: Text('تصدير')),
        const SizedBox(width: 8),
        FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _gold), icon: const Icon(Icons.add, size: 16), label: Text('حساب جديد')),
      ]),
    );
  }

  Widget _statsRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(children: _AcctType.values.map((t) {
        final count = _accounts.values.where((a) => a.type == t && a.isLeaf).length;
        final total = _accounts.values.where((a) => a.type == t && a.isLeaf).fold<double>(0, (s, a) => s + a.balance.abs());
        return Expanded(child: Padding(padding: const EdgeInsets.only(left: 10), child: InkWell(
          onTap: () => setState(() => _filter = _filter == t ? null : t),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _filter == t ? t.color.withOpacity(0.15) : t.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _filter == t ? t.color : t.color.withOpacity(0.2), width: _filter == t ? 2 : 1),
            ),
            child: Row(children: [
              Icon(t.icon, color: t.color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.labelAr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: t.color)),
                Text('$count حساب', style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
              ])),
              Text('${(total / 1e6).toStringAsFixed(1)}M', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: t.color)),
            ]),
          ),
        )));
      }).toList()),
    );
  }

  Widget _toolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(children: [
        SizedBox(
          width: 300,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'بحث بالرقم أو الاسم...',
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            if (_expanded.isEmpty) {
              _expanded.addAll(_accounts.keys);
            } else {
              _expanded.clear();
            }
          }),
          icon: const Icon(Icons.unfold_more, size: 16),
          label: Text(_expanded.isEmpty ? 'فتح الكل' : 'طي الكل'),
        ),
        const Spacer(),
        if (_filter != null) Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _filter!.color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(_filter!.icon, size: 12, color: _filter!.color),
            const SizedBox(width: 4),
            Text('مُصفّى: ${_filter!.labelAr}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _filter!.color)),
            const SizedBox(width: 4),
            InkWell(onTap: () => setState(() => _filter = null), child: Icon(Icons.close, size: 12, color: _filter!.color)),
          ]),
        ),
      ]),
    );
  }

  Widget _tree() {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Column headers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: core_theme.AC.navy3, borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              SizedBox(width: 80, child: Text('الرقم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.ts))),
              Expanded(flex: 3, child: Text('الاسم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.ts))),
              SizedBox(width: 90, child: Text('النوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.ts))),
              SizedBox(width: 150, child: Text('الرصيد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.ts), textAlign: TextAlign.end)),
              SizedBox(width: 80, child: SizedBox()),
            ]),
          ),
          const SizedBox(height: 4),
          for (final root in _topLevel().where((a) => _filter == null || a.type == _filter))
            ..._renderNode(root, 0),
        ],
      ),
    );
  }

  List<Widget> _renderNode(_Account a, int depth) {
    final isExpanded = _expanded.contains(a.id);
    final children = _children(a.id);
    final hasChildren = children.isNotEmpty;
    final selected = a.id == _selectedId;
    return [
      InkWell(
        onTap: () => setState(() => _selectedId = selected ? null : a.id),
        child: Container(
          padding: EdgeInsetsDirectional.only(start: 12 + depth * 22, end: 12, top: 10, bottom: 10),
          decoration: BoxDecoration(
            color: selected ? _gold.withOpacity(0.08) : null,
            border: BorderDirectional(
              end: BorderSide(color: selected ? _gold : Colors.transparent, width: 3),
              bottom: BorderSide(color: core_theme.AC.navy3),
            ),
          ),
          child: Row(children: [
            SizedBox(
              width: 80,
              child: Row(children: [
                if (hasChildren)
                  InkWell(
                    onTap: () => setState(() {
                      if (isExpanded) {
                        _expanded.remove(a.id);
                      } else {
                        _expanded.add(a.id);
                      }
                    }),
                    child: Icon(isExpanded ? Icons.expand_more : Icons.chevron_left, size: 18, color: core_theme.AC.ts),
                  )
                else const SizedBox(width: 18),
                const SizedBox(width: 4),
                Text(a.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
            Expanded(flex: 3, child: Row(children: [
              Icon(a.type.icon, size: 14, color: a.type.color),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.nameAr, style: TextStyle(fontSize: 13, fontWeight: hasChildren ? FontWeight.w800 : FontWeight.w500)),
                Text(a.nameEn, style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontStyle: FontStyle.italic)),
              ])),
            ])),
            SizedBox(
              width: 90,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: a.type.color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                child: Text(a.type.labelAr, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: a.type.color), textAlign: TextAlign.center),
              ),
            ),
            SizedBox(
              width: 150,
              child: Text(
                a.balance >= 0 ? '${a.balance.toStringAsFixed(0)}' : '(${(-a.balance).toStringAsFixed(0)})',
                style: TextStyle(
                  fontSize: hasChildren ? 13 : 12,
                  fontFamily: 'monospace',
                  fontWeight: hasChildren ? FontWeight.w800 : FontWeight.w500,
                  color: a.balance >= 0 ? core_theme.AC.tp : core_theme.AC.err,
                ),
                textAlign: TextAlign.end,
              ),
            ),
            SizedBox(
              width: 80,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton(icon: Icon(Icons.add, size: 14, color: core_theme.AC.ok), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: 'إضافة فرعي'),
                const SizedBox(width: 6),
                IconButton(icon: const Icon(Icons.edit, size: 14), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints(), tooltip: 'تعديل'),
                const SizedBox(width: 6),
                IconButton(icon: const Icon(Icons.more_vert, size: 14), onPressed: () {}, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ),
          ]),
        ),
      ),
      if (isExpanded)
        for (final child in children) ..._renderNode(child, depth + 1),
    ];
  }

  Widget _details() {
    final a = _accounts[_selectedId];
    if (a == null) return const SizedBox();
    return Container(
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: a.type.color.withOpacity(0.06), border: Border(bottom: BorderSide(color: core_theme.AC.bdr))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: a.type.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(a.type.icon, color: a.type.color)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.id, style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: core_theme.AC.ts)),
              Text(a.nameAr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              Text(a.nameEn, style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontStyle: FontStyle.italic)),
            ])),
            IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _selectedId = null)),
          ]),
        ),
        Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [
          _kvBig('الرصيد الحالي', a.balance.toStringAsFixed(2), 'ر.س', a.balance >= 0 ? core_theme.AC.ok : core_theme.AC.err),
          const Divider(height: 24),
          Text('معلومات الحساب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 10),
          _kv('النوع', a.type.labelAr),
          _kv('المستوى', a.isLeaf ? 'ورقة (Leaf)' : 'أصل (Parent)'),
          _kv('الأصل', a.parent ?? '—'),
          _kv('اسم بالإنجليزية', a.nameEn),
          const SizedBox(height: 10),
          _kv('SOCPA ID', 'SOCPA-${a.id}'),
          _kv('IFRS Mapping', '${a.type.ifrsLine}'),
          _kv('Posting Allowed', a.isLeaf ? 'نعم' : 'لا (أصل فقط)'),
          const SizedBox(height: 10),
          _kv('العملة', 'SAR (مع دعم FX)'),
          _kv('الضرائب', 'خاضع للـ VAT'),
          _kv('مستخدم في التقارير', 'نعم'),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: () {}, style: FilledButton.styleFrom(backgroundColor: _gold), icon: const Icon(Icons.edit, size: 16), label: Text('تعديل الحساب'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.visibility, size: 16), label: Text('عرض القيود'))),
          ]),
        ])),
      ]),
    );
  }

  Widget _kv(String k, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
        SizedBox(width: 120, child: Text(k, style: TextStyle(fontSize: 11, color: core_theme.AC.ts))),
        Expanded(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
      ]));

  Widget _kvBig(String k, String v, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color.withOpacity(0.9))),
        const SizedBox(height: 4),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, fontFamily: 'monospace')),
          const SizedBox(width: 6),
          Text(unit, style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
        ]),
      ]),
    );
  }
}

enum _AcctType { asset, liability, equity, revenue, expense }

extension _AcctTypeX on _AcctType {
  String get labelAr => switch (this) {
        _AcctType.asset => 'أصل',
        _AcctType.liability => 'خصم',
        _AcctType.equity => 'حقوق ملكية',
        _AcctType.revenue => 'إيراد',
        _AcctType.expense => 'مصروف',
      };
  Color get color => switch (this) {
        _AcctType.asset => core_theme.AC.ok,
        _AcctType.liability => core_theme.AC.warn,
        _AcctType.equity => core_theme.AC.gold,
        _AcctType.revenue => core_theme.AC.info,
        _AcctType.expense => core_theme.AC.err,
      };
  IconData get icon => switch (this) {
        _AcctType.asset => Icons.trending_up,
        _AcctType.liability => Icons.trending_down,
        _AcctType.equity => Icons.account_balance,
        _AcctType.revenue => Icons.arrow_circle_up,
        _AcctType.expense => Icons.arrow_circle_down,
      };
  String get ifrsLine => switch (this) {
        _AcctType.asset => 'IAS 1 — Assets',
        _AcctType.liability => 'IAS 1 — Liabilities',
        _AcctType.equity => 'IAS 1 — Equity',
        _AcctType.revenue => 'IFRS 15 — Revenue',
        _AcctType.expense => 'IAS 1 — Expenses',
      };
}

class _Account {
  final String id, nameAr, nameEn;
  final _AcctType type;
  final String? parent;
  final double balance;
  final bool isLeaf;
  const _Account(this.id, this.nameAr, this.nameEn, this.type, this.parent, this.balance, this.isLeaf);
}
