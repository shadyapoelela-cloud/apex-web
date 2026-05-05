/// APEX — CoA Editor (full-featured account creation)
/// /app/erp/finance/coa-editor — add/edit/move accounts in the tree
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class CoaEditorScreen extends StatefulWidget {
  const CoaEditorScreen({super.key});
  @override
  State<CoaEditorScreen> createState() => _CoaEditorScreenState();
}

class _CoaEditorScreenState extends State<CoaEditorScreen> {
  final _codeCtl = TextEditingController();
  final _nameArCtl = TextEditingController();
  final _nameEnCtl = TextEditingController();
  String _category = 'asset';
  String _subcategory = 'cash';
  String _normalBalance = 'debit';
  String _parentCode = '1100';
  bool _isControl = false;
  bool _requireCostCenter = false;

  static const _categories = [
    ('asset', 'أصول', 'debit'),
    ('liability', 'خصوم', 'credit'),
    ('equity', 'حقوق ملكية', 'credit'),
    ('revenue', 'إيرادات', 'credit'),
    ('expense', 'مصروفات', 'debit'),
  ];

  static const Map<String, List<(String, String)>> _subcategories = {
    'asset': [('cash', 'نقد'), ('bank', 'بنوك'), ('receivables', 'ذمم مدينة'), ('inventory', 'مخزون'), ('fixed_asset', 'أصل ثابت')],
    'liability': [('payables', 'ذمم دائنة'), ('vat', 'ضريبة القيمة المضافة'), ('loan', 'قرض'), ('accrual', 'مستحق')],
    'equity': [('capital', 'رأس المال'), ('retained_earnings', 'أرباح محتجزة'), ('reserves', 'احتياطيات')],
    'revenue': [('sales', 'مبيعات'), ('service', 'خدمات'), ('other', 'أخرى')],
    'expense': [('cogs', 'تكلفة بضاعة'), ('payroll', 'رواتب'), ('rent', 'إيجار'), ('utilities', 'مرافق'), ('other', 'أخرى')],
  };

  @override
  void dispose() {
    _codeCtl.dispose();
    _nameArCtl.dispose();
    _nameEnCtl.dispose();
    super.dispose();
  }

  void _onCategoryChange(String cat) {
    setState(() {
      _category = cat;
      _normalBalance = _categories.firstWhere((c) => c.$1 == cat).$3;
      _subcategory = _subcategories[cat]!.first.$1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('محرر شجرة الحسابات', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _basicCard(),
          const SizedBox(height: 12),
          _classificationCard(),
          const SizedBox(height: 12),
          _hierarchyCard(),
          const SizedBox(height: 12),
          _flagsCard(),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: AC.ok,
                  content: Text('تم إنشاء الحساب ${_codeCtl.text} بنجاح'),
                ));
              },
              icon: const Icon(Icons.save),
              label: const Text('احفظ الحساب'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AC.gold, foregroundColor: AC.navy,
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
          const ApexOutputChips(items: [
            ApexChipLink('شجرة الحسابات', '/app/erp/finance/coa-editor', Icons.account_tree),
            ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
            ApexChipLink('ميزان المراجعة', '/app/erp/finance/statements', Icons.assessment),
          ]),
        ]),
      ),
    );
  }

  Widget _basicCard() => _card('بيانات أساسية', [
        _input(_codeCtl, 'الكود (مثال: 1110)', Icons.tag, numeric: true),
        const SizedBox(height: 8),
        _input(_nameArCtl, 'الاسم بالعربية', Icons.translate),
        const SizedBox(height: 8),
        _input(_nameEnCtl, 'Name (English)', Icons.language),
      ]);

  Widget _classificationCard() => _card('التصنيف', [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in _categories)
            ChoiceChip(
              label: Text(c.$2),
              selected: _category == c.$1,
              onSelected: (_) => _onCategoryChange(c.$1),
              selectedColor: AC.gold,
              labelStyle: TextStyle(color: _category == c.$1 ? AC.navy : AC.tp),
            ),
        ]),
        const SizedBox(height: 12),
        Text('التصنيف الفرعي', style: TextStyle(color: AC.ts, fontSize: 11)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final s in _subcategories[_category]!)
            ChoiceChip(
              label: Text(s.$2),
              selected: _subcategory == s.$1,
              onSelected: (_) => setState(() => _subcategory = s.$1),
              selectedColor: AC.gold.withValues(alpha: 0.6),
              labelStyle: TextStyle(color: _subcategory == s.$1 ? AC.navy : AC.tp),
            ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AC.navy3,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(children: [
            Icon(Icons.balance, color: AC.gold, size: 14),
            const SizedBox(width: 6),
            Text('الطبيعة: ',
                style: TextStyle(color: AC.ts, fontSize: 11)),
            Text(_normalBalance == 'debit' ? 'مدين' : 'دائن',
                style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
      ]);

  Widget _hierarchyCard() => _card('الهيكل', [
        Text('الحساب الرئيسي (parent)',
            style: TextStyle(color: AC.ts, fontSize: 11)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _parentCode,
          dropdownColor: AC.navy3,
          style: TextStyle(color: AC.tp, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide.none,
            ),
          ),
          items: const [
            DropdownMenuItem(value: '1100', child: Text('1100 — الأصول المتداولة')),
            DropdownMenuItem(value: '1500', child: Text('1500 — الأصول الثابتة')),
            DropdownMenuItem(value: '2100', child: Text('2100 — الخصوم المتداولة')),
            DropdownMenuItem(value: '3000', child: Text('3000 — حقوق الملكية')),
            DropdownMenuItem(value: '4000', child: Text('4000 — الإيرادات')),
            DropdownMenuItem(value: '5000', child: Text('5000 — المصروفات')),
          ],
          onChanged: (v) => setState(() => _parentCode = v ?? '1100'),
        ),
      ]);

  Widget _flagsCard() => _card('خصائص متقدمة', [
        SwitchListTile(
          title: Text('حساب رقابي (Sub-ledger)', style: TextStyle(color: AC.tp, fontSize: 12.5)),
          subtitle: Text('AR/AP — يربط بأطراف مقابلة',
              style: TextStyle(color: AC.ts, fontSize: 11)),
          value: _isControl,
          onChanged: (v) => setState(() => _isControl = v),
          activeColor: AC.gold,
        ),
        SwitchListTile(
          title: Text('يتطلب مركز تكلفة', style: TextStyle(color: AC.tp, fontSize: 12.5)),
          subtitle: Text('كل قيد على هذا الحساب يحتاج CC',
              style: TextStyle(color: AC.ts, fontSize: 11)),
          value: _requireCostCenter,
          onChanged: (v) => setState(() => _requireCostCenter = v),
          activeColor: AC.gold,
        ),
      ]);

  Widget _card(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border.all(color: AC.bdr),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title,
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _input(TextEditingController c, String label, IconData icon, {bool numeric = false}) =>
      TextField(
        controller: c,
        keyboardType: numeric ? TextInputType.number : TextInputType.text,
        style: TextStyle(color: AC.tp, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: AC.ts, fontSize: 11.5),
          prefixIcon: Icon(icon, color: AC.ts, size: 16),
          isDense: true,
          filled: true,
          fillColor: AC.navy3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
        ),
      );
}
