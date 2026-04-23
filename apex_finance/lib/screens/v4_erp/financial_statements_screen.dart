/// APEX Wave 39 — Financial Statements Builder + CoA Editor.
/// Routes: /app/erp/finance/statements + /app/erp/finance/coa
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/apex_v5_undo_toast.dart';
import '../../pilot/api/pilot_client.dart';
import '../../pilot/session.dart';

class FinancialStatementsScreen extends StatefulWidget {
  const FinancialStatementsScreen({super.key});
  @override
  State<FinancialStatementsScreen> createState() => _FinancialStatementsScreenState();
}

class _FinancialStatementsScreenState extends State<FinancialStatementsScreen> {
  int _tab = 0;
  String _period = 'Q1-2026';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.08)))),
          child: Row(
            children: [
              _tabBtn(0, 'قائمة الدخل', Icons.trending_up),
              _tabBtn(1, 'الميزانية العمومية', Icons.balance),
              _tabBtn(2, 'التدفقات النقدية', Icons.waterfall_chart),
              _tabBtn(3, 'حقوق الملكية', Icons.account_tree),
              const Spacer(),
              DropdownButton<String>(
                value: _period,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'Q1-2026', child: Text('Q1 2026', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'Q4-2025', child: Text('Q4 2025', style: TextStyle(fontSize: 12))),
                  DropdownMenuItem(value: 'FY-2025', child: Text('سنة 2025', style: TextStyle(fontSize: 12))),
                ],
                onChanged: (v) => setState(() => _period = v!),
              ),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: active ? const Color(0xFF1565C0).withValues(alpha: 0.15) : null, borderRadius: BorderRadius.circular(6), border: active ? Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.4)) : null),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF1565C0) : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? const Color(0xFF1565C0) : core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _pnl();
      case 1: return _bs();
      case 2: return _cf();
      case 3: return _equity();
      default: return const SizedBox();
    }
  }

  Widget _pnl() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header('قائمة الدخل', 'Income Statement — IFRS compliant'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
            child: Column(
              children: [
                _fsTitle('شركة الرياض للتجارة · Q1 2026'),
                _fsLine('الإيرادات', null, false),
                _fsLine('  إيرادات المبيعات', 3_850_000, false, sub: true),
                _fsLine('  إيرادات الخدمات', 890_000, false, sub: true),
                _fsLine('إجمالي الإيرادات', 4_740_000, false, bold: true, border: true),
                const SizedBox(height: 8),
                _fsLine('تكلفة الإيرادات', null, false),
                _fsLine('  تكلفة البضاعة المباعة', -2_310_000, true, sub: true),
                _fsLine('  تكلفة الخدمات', -534_000, true, sub: true),
                _fsLine('إجمالي التكلفة', -2_844_000, true, bold: true, border: true),
                const SizedBox(height: 4),
                _fsLine('إجمالي الربح (Gross Profit)', 1_896_000, false, bold: true, highlight: core_theme.AC.ok),
                _fsLine('نسبة إجمالي الربح', 40.0, false, bold: true, pct: true),
                const SizedBox(height: 16),
                _fsLine('المصروفات التشغيلية', null, false),
                _fsLine('  مصروفات البيع والتسويق', -285_000, true, sub: true),
                _fsLine('  الرواتب والأجور', -440_000, true, sub: true),
                _fsLine('  الإيجار والمرافق', -95_000, true, sub: true),
                _fsLine('  مصروفات إدارية أخرى', -128_000, true, sub: true),
                _fsLine('إجمالي المصروفات التشغيلية', -948_000, true, bold: true, border: true),
                const SizedBox(height: 4),
                _fsLine('الدخل التشغيلي (EBITDA)', 948_000, false, bold: true, highlight: const Color(0xFF1565C0)),
                const SizedBox(height: 8),
                _fsLine('الإهلاك والاستهلاك', -82_000, true, sub: true),
                _fsLine('الفوائد', -24_000, true, sub: true),
                _fsLine('الدخل قبل الضريبة (EBT)', 842_000, false, bold: true, border: true),
                _fsLine('الزكاة (2.5%)', -21_050, true, sub: true),
                _fsLine('VAT على المبيعات', 0, false, sub: true),
                const SizedBox(height: 8),
                _fsLine('صافي الدخل', 820_950, false, bold: true, big: true, highlight: core_theme.AC.ok),
                _fsLine('هامش صافي الدخل', 17.3, false, pct: true, bold: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _actions(),
        ],
      ),
    );
  }

  Widget _bs() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header('الميزانية العمومية', 'Balance Sheet — IFRS'),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
                  child: Column(
                    children: [
                      _fsTitle('الموجودات (Assets)'),
                      _fsLine('الموجودات المتداولة', null, false),
                      _fsLine('  النقدية وما في حكمها', 1_240_000, false, sub: true),
                      _fsLine('  الذمم المدينة', 1_850_000, false, sub: true),
                      _fsLine('  المخزون', 920_000, false, sub: true),
                      _fsLine('  مصاريف مدفوعة مقدّماً', 85_000, false, sub: true),
                      _fsLine('مجموع الموجودات المتداولة', 4_095_000, false, bold: true, border: true),
                      const SizedBox(height: 8),
                      _fsLine('الموجودات غير المتداولة', null, false),
                      _fsLine('  الأصول الثابتة (صافي)', 2_850_000, false, sub: true),
                      _fsLine('  الأصول غير الملموسة', 340_000, false, sub: true),
                      _fsLine('  استثمارات طويلة الأجل', 1_200_000, false, sub: true),
                      _fsLine('مجموع الموجودات غير المتداولة', 4_390_000, false, bold: true, border: true),
                      const SizedBox(height: 8),
                      _fsLine('مجموع الموجودات', 8_485_000, false, bold: true, big: true, highlight: core_theme.AC.ok),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
                  child: Column(
                    children: [
                      _fsTitle('المطلوبات وحقوق الملكية'),
                      _fsLine('المطلوبات المتداولة', null, false),
                      _fsLine('  الذمم الدائنة', 890_000, false, sub: true),
                      _fsLine('  قروض قصيرة الأجل', 320_000, false, sub: true),
                      _fsLine('  مصاريف مستحقة', 145_000, false, sub: true),
                      _fsLine('  VAT و Zakat مستحقة', 68_000, false, sub: true),
                      _fsLine('مجموع المطلوبات المتداولة', 1_423_000, false, bold: true, border: true),
                      const SizedBox(height: 8),
                      _fsLine('المطلوبات غير المتداولة', null, false),
                      _fsLine('  قروض طويلة الأجل', 1_420_000, false, sub: true),
                      _fsLine('  مخصصات نهاية الخدمة', 680_000, false, sub: true),
                      _fsLine('مجموع المطلوبات غير المتداولة', 2_100_000, false, bold: true, border: true),
                      const SizedBox(height: 4),
                      _fsLine('مجموع المطلوبات', 3_523_000, false, bold: true),
                      const SizedBox(height: 12),
                      _fsTitle('حقوق الملكية'),
                      _fsLine('  رأس المال', 3_000_000, false, sub: true),
                      _fsLine('  الاحتياطيات', 680_000, false, sub: true),
                      _fsLine('  الأرباح المبقاة', 1_282_000, false, sub: true),
                      _fsLine('مجموع حقوق الملكية', 4_962_000, false, bold: true, border: true),
                      const SizedBox(height: 8),
                      _fsLine('مجموع المطلوبات + الملكية', 8_485_000, false, bold: true, big: true, highlight: core_theme.AC.ok),
                      const SizedBox(height: 4),
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)), child: Row(children: [Icon(Icons.check_circle, color: core_theme.AC.ok, size: 14), SizedBox(width: 6), Text('متوازن ✓', style: TextStyle(color: core_theme.AC.ok, fontWeight: FontWeight.w800, fontSize: 12))])),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _actions(),
        ],
      ),
    );
  }

  Widget _cf() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header('قائمة التدفقات النقدية', 'IAS 7 — Indirect method'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
            child: Column(
              children: [
                _fsTitle('النشاط التشغيلي (Operating)'),
                _fsLine('  صافي الدخل', 820_950, false, sub: true),
                _fsLine('  الإهلاك والاستهلاك', 82_000, false, sub: true),
                _fsLine('  التغيّر في الذمم المدينة', -135_000, true, sub: true),
                _fsLine('  التغيّر في المخزون', -45_000, true, sub: true),
                _fsLine('  التغيّر في الذمم الدائنة', 85_000, false, sub: true),
                _fsLine('صافي النقد من التشغيل', 807_950, false, bold: true, border: true, highlight: core_theme.AC.ok),
                const SizedBox(height: 16),
                _fsTitle('النشاط الاستثماري (Investing)'),
                _fsLine('  شراء أصول ثابتة', -285_000, true, sub: true),
                _fsLine('  بيع استثمارات', 120_000, false, sub: true),
                _fsLine('صافي النقد من الاستثمار', -165_000, true, bold: true, border: true, highlight: core_theme.AC.warn),
                const SizedBox(height: 16),
                _fsTitle('النشاط التمويلي (Financing)'),
                _fsLine('  سداد قروض', -80_000, true, sub: true),
                _fsLine('  توزيعات أرباح', -200_000, true, sub: true),
                _fsLine('صافي النقد من التمويل', -280_000, true, bold: true, border: true, highlight: const Color(0xFFB91C1C)),
                const SizedBox(height: 16),
                _fsLine('صافي الزيادة في النقد', 362_950, false, bold: true, big: true),
                _fsLine('النقد في بداية الفترة', 877_050, false),
                _fsLine('النقد في نهاية الفترة', 1_240_000, false, bold: true, big: true, highlight: core_theme.AC.ok),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _actions(),
        ],
      ),
    );
  }

  Widget _equity() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header('قائمة التغيّرات في حقوق الملكية', 'Statement of Changes in Equity'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
            child: Column(
              children: [
                _equityHeader(),
                _equityRow('الرصيد في 1 يناير 2026', '3,000,000', '680,000', '661,050', '4,341,050'),
                _equityRow('صافي الدخل', '—', '—', '820,950', '820,950'),
                _equityRow('توزيعات أرباح', '—', '—', '(200,000)', '(200,000)'),
                _equityRow('تخصيص احتياطي نظامي', '—', '82,000', '(82,000)', '—'),
                Container(padding: const EdgeInsets.all(10), color: core_theme.AC.ok.withValues(alpha: 0.06), child: _equityRow('الرصيد في 31 مارس 2026', '3,000,000', '762,000', '1,200,000', '4,962,000', bold: true)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _actions(),
        ],
      ),
    );
  }

  Widget _header(String title, String sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1565C0), core_theme.AC.purple]), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.assessment, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text('$sub · الفترة: $_period', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fsTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF1565C0))),
      ]),
    );
  }

  Widget _fsLine(String label, double? value, bool negative, {bool sub = false, bool bold = false, bool border = false, bool big = false, bool pct = false, Color? highlight}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: border ? BoxDecoration(border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.1)))) : null,
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: big ? 14 : sub ? 12 : 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w500, color: highlight ?? (sub ? core_theme.AC.ts : core_theme.AC.tp))),
          const Spacer(),
          if (value != null)
            Container(
              padding: highlight != null ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3) : null,
              decoration: highlight != null ? BoxDecoration(color: highlight.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)) : null,
              child: Text(
                pct ? '${value.toStringAsFixed(1)}%' : '${negative ? '(' : ''}${value.abs().toStringAsFixed(0)}${negative ? ')' : ''}',
                style: TextStyle(fontSize: big ? 15 : 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: highlight ?? core_theme.AC.tp, fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _equityHeader() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.08)))),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('البند', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
          Expanded(child: Text('رأس المال', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
          Expanded(child: Text('الاحتياطي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
          Expanded(child: Text('الأرباح المبقاة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
          Expanded(child: Text('الإجمالي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _equityRow(String label, String a, String b, String c, String total, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Expanded(child: Text(a, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(b, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(c, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(total, textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: bold ? core_theme.AC.ok : core_theme.AC.tp))),
        ],
      ),
    );
  }

  Widget _actions() {
    return Row(
      children: [
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.compare_arrows, size: 14), label: Text('مقارنة فترات')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.picture_as_pdf, size: 14), label: Text('PDF')),
        const SizedBox(width: 8),
        OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.table_chart, size: 14), label: Text('Excel')),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () {
            ApexV5UndoToast.show(context, messageAr: 'تم اعتماد القوائم المالية Q1 2026', onUndo: () {});
          },
          icon: const Icon(Icons.verified, size: 14),
          label: Text('اعتماد نهائي'),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
        ),
      ],
    );
  }
}

/// CoA Editor
class CoaEditorScreen extends StatefulWidget {
  const CoaEditorScreen({super.key});
  @override
  State<CoaEditorScreen> createState() => _CoaEditorScreenState();
}

class _CoaEditorScreenState extends State<CoaEditorScreen> {
  String _selected = '1100';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 380, child: _tree()),
        const VerticalDivider(width: 1),
        Expanded(child: _detail()),
      ],
    );
  }

  Widget _tree() {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(Icons.account_tree, size: 18, color: core_theme.AC.gold),
                SizedBox(width: 6),
                Text('شجرة الحسابات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                Spacer(),
              ],
            ),
          ),
          _group('1000', 'الموجودات (Assets)', core_theme.AC.ok, [
            _leaf('1100', 'النقدية وما في حكمها', 1_240_000),
            _leaf('1110', 'الصندوق', 28_000),
            _leaf('1120', 'البنوك', 1_212_000),
            _leaf('1200', 'الذمم المدينة', 1_850_000),
            _leaf('1300', 'المخزون', 920_000),
            _leaf('1500', 'الأصول الثابتة', 2_850_000),
          ]),
          _group('2000', 'المطلوبات (Liabilities)', const Color(0xFFB91C1C), [
            _leaf('2100', 'الذمم الدائنة', 890_000),
            _leaf('2200', 'قروض قصيرة الأجل', 320_000),
            _leaf('2300', 'VAT مستحقة', 68_000),
          ]),
          _group('3000', 'حقوق الملكية (Equity)', core_theme.AC.gold, [
            _leaf('3100', 'رأس المال', 3_000_000),
            _leaf('3200', 'الاحتياطيات', 762_000),
            _leaf('3300', 'الأرباح المبقاة', 1_200_000),
          ]),
          _group('4000', 'الإيرادات (Revenue)', core_theme.AC.info, [
            _leaf('4100', 'إيرادات المبيعات', 3_850_000),
            _leaf('4200', 'إيرادات الخدمات', 890_000),
          ]),
          _group('5000', 'المصروفات (Expenses)', core_theme.AC.purple, [
            _leaf('5100', 'تكلفة البضاعة المباعة', 2_310_000),
            _leaf('5200', 'الرواتب والأجور', 440_000),
            _leaf('5300', 'مصروفات تسويقية', 285_000),
            _leaf('5400', 'مصروفات إدارية', 128_000),
            _leaf('5900', 'الإهلاك والاستهلاك', 82_000),
          ]),
        ],
      ),
    );
  }

  Widget _group(String code, String name, Color color, List<Widget> children) {
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)), child: Text(code, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w800))),
      title: Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      children: children,
    );
  }

  Widget _leaf(String code, String name, double balance) {
    final active = _selected == code;
    return GestureDetector(
      onTap: () => setState(() => _selected = code),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: active ? core_theme.AC.gold.withValues(alpha: 0.15) : null, borderRadius: BorderRadius.circular(4)),
        child: Row(
          children: [
            Text(code, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
            const SizedBox(width: 6),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
            Text('${(balance / 1000).toStringAsFixed(0)}K', style: const TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _detail() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.08)))),
          child: Row(
            children: [
              Icon(Icons.account_balance, color: core_theme.AC.gold, size: 22),
              const SizedBox(width: 10),
              Text('$_selected — النقدية وما في حكمها', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const Spacer(),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 14), label: Text('حساب فرعي')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.save, size: 14),
                label: Text('حفظ'),
                style: ElevatedButton.styleFrom(backgroundColor: core_theme.AC.gold, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
                  child: Column(
                    children: [
                      _field('رقم الحساب', '1100'),
                      _field('الاسم بالعربي', 'النقدية وما في حكمها'),
                      _field('Name (English)', 'Cash and Cash Equivalents'),
                      _field('النوع', 'أصل متداول'),
                      _field('الحساب الأب', '1000 — الموجودات'),
                      _field('حالة التفعيل', 'نشط ✓'),
                      _field('الرصيد الافتتاحي', '877,050 ر.س'),
                      _field('الرصيد الحالي', '1,240,000 ر.س', highlight: true),
                      _field('مسموح القيد المباشر', 'نعم'),
                      _field('تاريخ الإنشاء', '2022-01-01'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('آخر الحركات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
                  child: Column(
                    children: [
                      for (final m in [
                        ('2026-04-18', 'JE-2026-0542', 'تحصيل فاتورة SABIC', 52500.0, 'مدين'),
                        ('2026-04-17', 'JE-2026-0541', 'سداد قسط قرض', -25000.0, 'دائن'),
                        ('2026-04-16', 'JE-2026-0540', 'مقبوضات Al Rajhi', 28000.0, 'مدين'),
                        ('2026-04-15', 'JE-2026-0539', 'دفع مورد ABC', -12800.0, 'دائن'),
                      ])
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.04)))),
                          child: Row(
                            children: [
                              Text(m.$1, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                              const SizedBox(width: 12),
                              Text(m.$2, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              const SizedBox(width: 12),
                              Expanded(child: Text(m.$3, style: const TextStyle(fontSize: 12))),
                              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: (m.$5 == 'مدين' ? core_theme.AC.ok : const Color(0xFFB91C1C)).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)), child: Text(m.$5, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: m.$5 == 'مدين' ? core_theme.AC.ok : const Color(0xFFB91C1C)))),
                              const SizedBox(width: 12),
                              Text('${m.$4 > 0 ? '+' : ''}${m.$4.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: m.$4 > 0 ? core_theme.AC.ok : const Color(0xFFB91C1C))),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 160, child: Text(label, style: TextStyle(fontSize: 12, color: core_theme.AC.ts))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: highlight ? core_theme.AC.gold.withValues(alpha: 0.1) : null, border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(4)),
              child: Text(value, style: TextStyle(fontSize: 12, fontWeight: highlight ? FontWeight.w900 : FontWeight.w500, color: highlight ? core_theme.AC.gold : core_theme.AC.tp, fontFamily: highlight ? 'monospace' : null)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inventory Detailed (items + stock)
/// Inventory Detailed — LIVE backed by Pilot backend.
/// Reads products + variants + stock totals from /pilot/*.
class InventoryDetailedScreen extends StatefulWidget {
  const InventoryDetailedScreen({super.key});
  @override
  State<InventoryDetailedScreen> createState() => _InventoryDetailedScreenState();
}

class _InventoryDetailedScreenState extends State<InventoryDetailedScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!PilotSession.hasTenant) {
      if (mounted) setState(() => _products = []);
      return;
    }
    setState(() => _loading = true);
    final r = await pilotClient.listProducts(PilotSession.tenantId!, limit: 500);
    if (mounted) {
      setState(() {
        _products = r.success ? List<Map<String, dynamic>>.from(r.data) : [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PilotSession.hasTenant) {
      return Container(
        color: const Color(0xFFF9FAFB),
        padding: const EdgeInsets.all(40),
        alignment: Alignment.center,
        child: Text(
          'يتطلب ربط مستأجر من الباك-إند لعرض المخزون الحقيقي.',
          style: TextStyle(fontSize: 16, color: core_theme.AC.ts),
          textDirection: TextDirection.rtl,
        ),
      );
    }
    final totalSkus = _products.fold<int>(
      0,
      (s, p) => s + ((p['active_variant_count'] ?? 0) as int),
    );
    final totalStock = _products.fold<double>(
      0,
      (s, p) => s + (double.tryParse('${p['total_stock_on_hand'] ?? 0}') ?? 0),
    );
    final lowStock = _products
        .where((p) => (double.tryParse('${p['total_stock_on_hand'] ?? 0}') ?? 0) < 10)
        .length;

    return RefreshIndicator(
      onRefresh: _reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _sCard('إجمالي المنتجات', '${_products.length}', Icons.inventory, core_theme.AC.info),
                const SizedBox(width: 8),
                _sCard('إجمالي المتغيّرات (SKUs)', '$totalSkus', Icons.qr_code, core_theme.AC.gold),
                const SizedBox(width: 8),
                _sCard('الكمية الإجمالية', totalStock.toStringAsFixed(0), Icons.layers, core_theme.AC.ok),
                const SizedBox(width: 8),
                _sCard('منخفض المخزون', '$lowStock', Icons.warning, const Color(0xFFB91C1C)),
              ],
            ),
            const SizedBox(height: 16),
            Text('المنتجات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            if (!_loading && _products.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: Text('لا توجد منتجات — أنشئها في Pilot Catalog',
                    style: TextStyle(color: core_theme.AC.ts), textDirection: TextDirection.rtl),
              ),
            if (_products.isNotEmpty)
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                      child: const Row(children: [
                        Expanded(child: Text('الكود', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textDirection: TextDirection.rtl)),
                        Expanded(flex: 3, child: Text('الاسم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textDirection: TextDirection.rtl)),
                        Expanded(child: Text('الحالة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textDirection: TextDirection.rtl)),
                        Expanded(child: Text('المتغيّرات', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                        Expanded(child: Text('المخزون', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      ]),
                    ),
                    for (final p in _products)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.04)))),
                        child: Row(children: [
                          Expanded(child: Text('${p['code']}', style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts), textDirection: TextDirection.rtl)),
                          Expanded(flex: 3, child: Text('${p['name_ar'] ?? p['name_en'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), textDirection: TextDirection.rtl)),
                          Expanded(child: _statusBadge('${p['status']}')),
                          Expanded(child: Text('${p['active_variant_count'] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w800))),
                          Expanded(child: Text('${(double.tryParse('${p['total_stock_on_hand'] ?? 0}') ?? 0).toStringAsFixed(0)}', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: core_theme.AC.gold))),
                        ]),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final col = switch (status) {
      'active' => core_theme.AC.ok,
      'draft' => core_theme.AC.warn,
      'archived' || 'discontinued' => core_theme.AC.ts,
      _ => core_theme.AC.tp,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status,
          style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.2))),
        child: Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 8), Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)), Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts))])]),
      ),
    );
  }
}

