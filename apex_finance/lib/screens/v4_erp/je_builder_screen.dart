/// APEX Wave 37 — Journal Entry Builder + Period Close.
/// Route: /app/erp/finance/je-builder + /app/erp/finance/period-close
library;

import 'package:flutter/material.dart';
import '../../core/v5/apex_v5_undo_toast.dart';
import '../../core/v5/apex_v5_draft_with_ai.dart';

class JeBuilderScreen extends StatefulWidget {
  const JeBuilderScreen({super.key});
  @override
  State<JeBuilderScreen> createState() => _JeBuilderScreenState();
}

class _JeBuilderScreenState extends State<JeBuilderScreen> {
  final _lines = <_JeLine>[
    _JeLine('1100 - النقدية', 52500, 0),
    _JeLine('4100 - إيرادات المبيعات', 0, 45652),
    _JeLine('2300 - ضريبة القيمة المضافة مستحقة', 0, 6848),
  ];
  final _narrationCtl = TextEditingController(text: 'تحصيل فاتورة INV-2026-145 من SABIC — مبيعات خدمات استشارية');
  String _type = 'standard';

  double get _totalDebit => _lines.fold(0.0, (s, l) => s + l.debit);
  double get _totalCredit => _lines.fold(0.0, (s, l) => s + l.credit);
  bool get _isBalanced => (_totalDebit - _totalCredit).abs() < 0.01;

  @override
  void dispose() {
    _narrationCtl.dispose();
    super.dispose();
  }

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
              gradient: const LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFE6C200)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.book, color: Colors.white, size: 32),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('منشئ قيد اليومية', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text('قيد مزدوج القيد — يضمن التوازن تلقائياً', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _isBalanced ? const Color(0xFF059669) : const Color(0xFFB91C1C), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    children: [
                      Icon(_isBalanced ? Icons.check_circle : Icons.warning, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(_isBalanced ? 'متوازن ✓' : 'غير متوازن', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Meta
          LayoutBuilder(builder: (ctx, c) {
            final wide = c.maxWidth > 700;
            return wide ? Row(children: _meta()) : Column(children: _meta().expand((w) => [w, const SizedBox(height: 8)]).toList());
          }),
          const SizedBox(height: 16),
          // Entry table
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withValues(alpha: 0.08))),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: const BorderRadius.vertical(top: Radius.circular(10)), border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06)))),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('الحساب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                      Expanded(flex: 2, child: Text('مدين', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('دائن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      Expanded(flex: 3, child: Text('الوصف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                      SizedBox(width: 50),
                    ],
                  ),
                ),
                for (int i = 0; i < _lines.length; i++) _lineRow(i),
                Container(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      OutlinedButton.icon(onPressed: () => setState(() => _lines.add(_JeLine('', 0, 0))), icon: const Icon(Icons.add, size: 14), label: const Text('إضافة سطر')),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.description, size: 14), label: const Text('من قالب')),
                    ],
                  ),
                ),
                // Totals
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _isBalanced ? const Color(0xFF059669).withValues(alpha: 0.05) : const Color(0xFFB91C1C).withValues(alpha: 0.05)),
                  child: Row(
                    children: [
                      const Expanded(flex: 3, child: Text('الإجمالي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
                      Expanded(flex: 2, child: Text('${_totalDebit.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: _isBalanced ? const Color(0xFF059669) : Colors.black87), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('${_totalCredit.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: _isBalanced ? const Color(0xFF059669) : Colors.black87), textAlign: TextAlign.center)),
                      Expanded(flex: 3, child: Text('الفارق: ${(_totalDebit - _totalCredit).toStringAsFixed(2)}', style: TextStyle(fontSize: 12, color: _isBalanced ? const Color(0xFF059669) : const Color(0xFFB91C1C)), textAlign: TextAlign.end)),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Narration with AI
          const Text('الوصف (Narration)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ApexV5DraftWithAi(
            controller: _narrationCtl,
            contextAr: 'قيد يومي — ${_lines.map((l) => l.account).join(' / ')}',
            placeholderAr: 'اكتب وصف القيد...',
            minLines: 2,
          ),
          const SizedBox(height: 16),
          // Actions
          Row(
            children: [
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.save_alt, size: 14), label: const Text('حفظ كمسودّة')),
              const SizedBox(width: 8),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.copy, size: 14), label: const Text('حفظ كقالب')),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isBalanced ? () {
                  ApexV5UndoToast.show(context, messageAr: 'تم ترحيل القيد JE-2026-0542 · ${_totalDebit.toStringAsFixed(0)} ر.س', onUndo: () {});
                } : null,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('ترحيل القيد'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _meta() => [
        Expanded(flex: 2, child: _metaField('رقم القيد', 'JE-2026-0542 (تلقائي)', false)),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: _metaField('التاريخ', '2026-04-18', true)),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('نوع القيد', style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _type,
            isDense: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
            items: const [
              DropdownMenuItem(value: 'standard', child: Text('قيد عادي', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'recurring', child: Text('قيد متكرّر', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'reversal', child: Text('قيد عكسي', style: TextStyle(fontSize: 12))),
              DropdownMenuItem(value: 'adjustment', child: Text('قيد تسوية', style: TextStyle(fontSize: 12))),
            ],
            onChanged: (v) => setState(() => _type = v!),
          ),
        ])),
      ];

  Widget _metaField(String label, String value, bool editable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(border: Border.all(color: Colors.black.withValues(alpha: 0.15)), borderRadius: BorderRadius.circular(4), color: editable ? Colors.white : const Color(0xFFF9FAFB)),
          child: Text(value, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
        ),
      ],
    );
  }

  Widget _lineRow(int i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.04)))),
      child: Row(
        children: [
          Expanded(flex: 3, child: TextField(
            controller: TextEditingController(text: _lines[i].account),
            onChanged: (v) => _lines[i].account = v,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '1100 - النقدية', hintStyle: TextStyle(fontSize: 11), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: const TextStyle(fontSize: 12),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: TextField(
            controller: TextEditingController(text: _lines[i].debit > 0 ? _lines[i].debit.toStringAsFixed(2) : ''),
            onChanged: (v) => setState(() => _lines[i].debit = double.tryParse(v) ?? 0),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0.00', hintStyle: TextStyle(fontSize: 11), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 2, child: TextField(
            controller: TextEditingController(text: _lines[i].credit > 0 ? _lines[i].credit.toStringAsFixed(2) : ''),
            onChanged: (v) => setState(() => _lines[i].credit = double.tryParse(v) ?? 0),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: '0.00', hintStyle: TextStyle(fontSize: 11), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
          )),
          const SizedBox(width: 6),
          Expanded(flex: 3, child: TextField(
            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'وصف اختياري', hintStyle: TextStyle(fontSize: 11), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
            style: const TextStyle(fontSize: 11),
          )),
          SizedBox(width: 50, child: IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFB91C1C)), onPressed: () => setState(() => _lines.removeAt(i)))),
        ],
      ),
    );
  }
}

class _JeLine {
  String account;
  double debit, credit;
  _JeLine(this.account, this.debit, this.credit);
}

/// Period Close Workflow
class PeriodCloseScreen extends StatefulWidget {
  const PeriodCloseScreen({super.key});
  @override
  State<PeriodCloseScreen> createState() => _PeriodCloseScreenState();
}

class _PeriodCloseScreenState extends State<PeriodCloseScreen> {
  final _steps = [
    _CloseStep('1', 'مراجعة القيود غير المرحّلة', '3 قيود معلّقة', true, false),
    _CloseStep('2', 'مطابقة البنوك', '18 معاملة مطابقة ✓', true, false),
    _CloseStep('3', 'اعتماد الذمم المدينة والدائنة', 'AR: 285K · AP: 128K', true, false),
    _CloseStep('4', 'تسويات الإهلاك', '12 أصل · 42K ر.س', true, false),
    _CloseStep('5', 'تسويات المخصصات', 'ECL + استحقاقات', false, true),
    _CloseStep('6', 'حسابات الضرائب', 'VAT + Zakat', false, false),
    _CloseStep('7', 'مراجعة TB قبل الإقفال', 'متوازن ✓', false, false),
    _CloseStep('8', 'إقفال حسابات النتيجة', 'Revenue → Retained Earnings', false, false),
    _CloseStep('9', 'إصدار القوائم المالية', 'P&L + BS + CF', false, false),
    _CloseStep('10', 'قفل الفترة نهائياً', 'لا تعديل بعد ذلك', false, false),
  ];

  @override
  Widget build(BuildContext context) {
    final done = _steps.where((s) => s.done).length;
    final pct = done / _steps.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.lock_clock, color: Colors.white, size: 32),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إقفال الفترة — أبريل 2026', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text('10 خطوات متسلسلة · لا يمكن تجاوز خطوة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$done/${_steps.length}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                    Text('${(pct * 100).toInt()}%', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: pct, minHeight: 10, backgroundColor: Colors.black.withValues(alpha: 0.06), valueColor: const AlwaysStoppedAnimation(Color(0xFF4A148C)))),
          const SizedBox(height: 20),
          for (final s in _steps) _stepCard(s),
        ],
      ),
    );
  }

  Widget _stepCard(_CloseStep s) {
    final color = s.done ? const Color(0xFF059669) : s.active ? const Color(0xFF4A148C) : Colors.black45;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: s.active ? const Color(0xFF4A148C).withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.active ? const Color(0xFF4A148C) : Colors.black.withValues(alpha: 0.08), width: s.active ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: s.done ? const Color(0xFF059669) : s.active ? const Color(0xFF4A148C).withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.06), shape: BoxShape.circle),
            child: s.done ? const Icon(Icons.check, color: Colors.white, size: 18) : Text(s.num, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: s.active ? const Color(0xFF4A148C) : Colors.black54)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: s.done ? Colors.black54 : Colors.black87, decoration: s.done ? TextDecoration.lineThrough : null)),
                Text(s.detail, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
          if (s.active)
            ElevatedButton(
              onPressed: () {
                ApexV5UndoToast.show(context, messageAr: 'تم إكمال: ${s.title}', onUndo: () {});
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A148C), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
              child: const Text('أكمل الخطوة'),
            )
          else if (s.done)
            const Icon(Icons.check_circle, color: Color(0xFF059669), size: 20),
        ],
      ),
    );
  }
}

class _CloseStep {
  final String num, title, detail;
  final bool done, active;
  _CloseStep(this.num, this.title, this.detail, this.done, this.active);
}
