import 'package:flutter/material.dart';
import 'screens/copilot/copilot_screen.dart';
import 'package:file_picker/file_picker.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'api_service.dart';
import 'analysis_full_screen.dart';

class FinancialStatementsScreen extends StatefulWidget {
  final Map<String, dynamic>? apiData;
  final PlatformFile? pickedFile;
  const FinancialStatementsScreen({super.key, this.apiData, this.pickedFile});
  @override
  State<FinancialStatementsScreen> createState() => _FinancialStatementsScreenState();
}

class _FinancialStatementsScreenState extends State<FinancialStatementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingPdf = false;
  bool _loadingExcel = false;

  static const _navy = Color(0xFF050D1A);
  static const _navy2 = Color(0xFF080F1F);
  static const _navy3 = Color(0xFF0D1829);
  static const _gold = Color(0xFFC9A84C);
  static const _border = Color(0x26C9A84C);
  static const _textPrimary = Color(0xFFF0EDE6);
  static const _textSecondary = Color(0xFF8A8880);
  static const _success = Color(0xFF2ECC8A);
  static const _cyan = Color(0xFF00C2E0);
  static const _danger = Color(0xFFE05050);

  Map<String, dynamic> get _data => widget.apiData?['data'] ?? {};

  double _v(String key) => (_data[key] ?? 0).toDouble();

  String fmt(double n) {
    if (n < 0) return '(${n.abs().toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')})';
    return n.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  // حسابات قائمة الدخل
  double get revenue => _v('revenue');
  double get cogs => _v('cost_of_goods_sold');
  double get grossProfit => revenue - cogs;
  double get grossMargin => revenue != 0 ? (grossProfit / revenue * 100) : 0;
  double get opex => _v('operating_expenses');
  double get operatingProfit => grossProfit - opex;
  double get interestExp => _v('interest_expense');
  double get netProfit => operatingProfit - interestExp;
  double get netMargin => revenue != 0 ? (netProfit / revenue * 100) : 0;

  // حسابات الميزانية
  double get totalAssets => _v('total_assets');
  double get currentAssets => _v('current_assets');
  double get fixedAssets => totalAssets - currentAssets;
  double get cash => _v('cash');
  double get inventory => _v('inventory');
  double get receivables => (currentAssets - cash - inventory).clamp(0, double.infinity);
  double get totalLiabilities => _v('total_liabilities');
  double get currentLiabilities => _v('current_liabilities');
  double get longTermLiabilities => (totalLiabilities - currentLiabilities).clamp(0, double.infinity);
  double get equity => totalAssets - totalLiabilities;

  // تدفقات نقدية تقديرية
  double get operatingCashFlow => netProfit + (opex * 0.1);
  double get investingCashFlow => -(fixedAssets * 0.05);
  double get financingCashFlow => -(interestExp);
  double get netCashFlow => operatingCashFlow + investingCashFlow + financingCashFlow;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _downloadReport(String type) async {
    if (widget.pickedFile == null) return;
    setState(() { if (type == 'pdf') _loadingPdf = true; else _loadingExcel = true; });
    try {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('جاري توليد تقرير ${type.toUpperCase()}...'),
        duration: const Duration(seconds: 60)));
      final bytes = await ApiService.downloadReport(type: type, fileBytes: widget.pickedFile!.bytes!, fileName: widget.pickedFile!.name);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (bytes != null) {
        final mimeType = type == 'pdf' ? 'application/pdf'
          : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        final fileName = type == 'pdf' ? 'القوائم_المالية.pdf' : 'القوائم_المالية.xlsx';
        final blob = html.Blob([bytes], mimeType);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement;
        anchor.href = url;
        anchor.download = fileName;
        anchor.click();
        html.Url.revokeObjectUrl(url);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ تم تحميل $fileName'),
          backgroundColor: _success));
      } else {
        throw Exception('فشل التحميل');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('خطأ: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() { _loadingPdf = false; _loadingExcel = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy2,
        title: const Text('القوائم المالية',
          style: TextStyle(fontFamily: 'Tajawal', color: _textPrimary)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _gold,
          labelColor: _gold,
          unselectedLabelColor: _textSecondary,
          labelStyle: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'قائمة الدخل'),
            Tab(text: 'المركز المالي'),
            Tab(text: 'التدفقات النقدية'),
          ]),
      ),
      body: Column(children: [
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildIncomeStatement(),
              _buildBalanceSheet(),
              _buildCashFlow(),
            ])),
        _buildBottomButtons(),
      ]),
    );
  }

  Widget _buildIncomeStatement() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _sectionTitle('قائمة الدخل'),
        const SizedBox(height: 12),
        _statementCard([
          _StatRow('إجمالي المبيعات', fmt(revenue), _gold, true),
          _StatRow('تكلفة البضاعة المباعة', fmt(cogs), _textSecondary, false),
          _divider(),
          _StatRow('مجمل الربح', fmt(grossProfit),
            grossProfit >= 0 ? _success : _danger, true),
          _StatRow('هامش مجمل الربح', '${grossMargin.toStringAsFixed(1)}%',
            grossProfit >= 0 ? _success : _danger, false),
          _divider(),
          _StatRow('المصروفات التشغيلية', fmt(opex), _textSecondary, false),
          _StatRow('الربح التشغيلي', fmt(operatingProfit),
            operatingProfit >= 0 ? _success : _danger, true),
          _divider(),
          _StatRow('مصروف الفوائد', fmt(interestExp), _textSecondary, false),
          _StatRow('صافي الربح / (الخسارة)', fmt(netProfit),
            netProfit >= 0 ? _success : _danger, true),
          _StatRow('هامش صافي الربح', '${netMargin.toStringAsFixed(1)}%',
            netProfit >= 0 ? _success : _danger, false),
        ]),
        const SizedBox(height: 16),
        _summaryCards([
          _SummaryData('إجمالي المبيعات', fmt(revenue), _gold),
          _SummaryData('مجمل الربح', fmt(grossProfit),
            grossProfit >= 0 ? _success : _danger),
          _SummaryData('صافي الربح', fmt(netProfit),
            netProfit >= 0 ? _success : _danger),
        ]),
      ]));
  }

  Widget _buildBalanceSheet() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _sectionTitle('قائمة المركز المالي'),
        const SizedBox(height: 12),
        _subTitle('الأصول'),
        _statementCard([
          _StatRow('الأصول الثابتة', fmt(fixedAssets), _textSecondary, false),
          _StatRow('النقدية وما يعادلها', fmt(cash), _textSecondary, false),
          _StatRow('الذمم المدينة', fmt(receivables), _textSecondary, false),
          _StatRow('المخزون', fmt(inventory), _textSecondary, false),
          _divider(),
          _StatRow('إجمالي الأصول المتداولة', fmt(currentAssets), _gold, true),
          _StatRow('إجمالي الأصول', fmt(totalAssets), _gold, true),
        ]),
        const SizedBox(height: 12),
        _subTitle('الخصوم وحقوق الملكية'),
        _statementCard([
          _StatRow('الالتزامات المتداولة', fmt(currentLiabilities), _textSecondary, false),
          _StatRow('الالتزامات طويلة الأجل', fmt(longTermLiabilities), _textSecondary, false),
          _divider(),
          _StatRow('إجمالي الالتزامات', fmt(totalLiabilities), _textSecondary, true),
          _StatRow('حقوق الملكية', fmt(equity),
            equity >= 0 ? _success : _danger, false),
          _divider(),
          _StatRow('إجمالي الخصوم وحقوق الملكية',
            fmt(totalLiabilities + equity), _gold, true),
        ]),
        const SizedBox(height: 16),
        _summaryCards([
          _SummaryData('إجمالي الأصول', fmt(totalAssets), _gold),
          _SummaryData('إجمالي الالتزامات', fmt(totalLiabilities), _cyan),
          _SummaryData('حقوق الملكية', fmt(equity),
            equity >= 0 ? _success : _danger),
        ]),
      ]));
  }

  Widget _buildCashFlow() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _sectionTitle('قائمة التدفقات النقدية'),
        const SizedBox(height: 12),
        _statementCard([
          _StatRow('التدفقات من الأنشطة التشغيلية', '', _gold, true),
          _StatRow('صافي الربح', fmt(netProfit), _textSecondary, false),
          _StatRow('تعديلات الاستهلاك (تقديري)', fmt(opex * 0.1), _textSecondary, false),
          _divider(),
          _StatRow('صافي التدفقات التشغيلية', fmt(operatingCashFlow),
            operatingCashFlow >= 0 ? _success : _danger, true),
          _divider(),
          _StatRow('التدفقات من الأنشطة الاستثمارية', '', _gold, true),
          _StatRow('مدفوعات الأصول الثابتة', fmt(investingCashFlow), _textSecondary, false),
          _divider(),
          _StatRow('صافي التدفقات الاستثمارية', fmt(investingCashFlow),
            investingCashFlow >= 0 ? _success : _danger, true),
          _divider(),
          _StatRow('التدفقات من الأنشطة التمويلية', '', _gold, true),
          _StatRow('مدفوعات الفوائد', fmt(financingCashFlow), _textSecondary, false),
          _divider(),
          _StatRow('صافي التدفقات التمويلية', fmt(financingCashFlow),
            financingCashFlow >= 0 ? _success : _danger, true),
          _divider(),
          _StatRow('صافي التدفق النقدي', fmt(netCashFlow),
            netCashFlow >= 0 ? _success : _danger, true),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cyan.withOpacity(0.3))),
          child: Row(children: [
            const Icon(Icons.info_outline, color: _cyan, size: 18),
            const SizedBox(width: 10),
            const Expanded(child: Text(
              'التدفقات النقدية محسوبة بطريقة غير المباشرة بناءً على بيانات ميزان المراجعة',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 12, color: _textSecondary, fontFamily: 'Tajawal'))),
          ])),
      ]));
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF080F1F),
        border: Border(top: BorderSide(color: Color(0x26C9A84C)))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // أزرار التحميل
        Row(children: [
          Expanded(child: _DownloadBtn(
            label: 'تحميل PDF',
            icon: Icons.picture_as_pdf_rounded,
            color: _gold,
            loading: _loadingPdf,
            onTap: () => _downloadReport('pdf'))),
          const SizedBox(width: 10),
          Expanded(child: _DownloadBtn(
            label: 'تحميل Excel',
            icon: Icons.table_chart_rounded,
            color: _cyan,
            outlined: true,
            loading: _loadingExcel,
            onTap: () => _downloadReport('excel'))),
        ]),
        const SizedBox(height: 10),
        // زر التحليل المالي
        GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AnalysisFullScreen(
              apiData: widget.apiData,
              pickedFile: widget.pickedFile))),
          child: Container(
            width: double.infinity, height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2ECC8A), Color(0xFF1A8C5C)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: _success.withOpacity(0.3),
                blurRadius: 16, offset: const Offset(0, 4))]),
            child: const Center(child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('التحليل المالي الكامل',
                  style: TextStyle(color: Colors.white, fontSize: 16,
                    fontWeight: FontWeight.w700, fontFamily: 'Tajawal')),
              ])))),
      ]));
  }

  Widget _sectionTitle(String title) => Align(
    alignment: Alignment.centerRight,
    child: Text(title, textDirection: TextDirection.rtl,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
        color: _textPrimary, fontFamily: 'Tajawal')));

  Widget _subTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Align(alignment: Alignment.centerRight,
      child: Text(title, textDirection: TextDirection.rtl,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
          color: _gold, fontFamily: 'Tajawal'))));

  Widget _statementCard(List<Widget> rows) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: _navy3, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border)),
    child: Column(children: rows));

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Divider(color: _border, height: 1));

  Widget _summaryCards(List<_SummaryData> items) => Row(
    children: items.map((s) => Expanded(child: Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _navy3, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(s.label, textDirection: TextDirection.rtl,
          style: const TextStyle(fontSize: 10, color: _textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 4),
        Text(s.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: s.color, fontFamily: 'Tajawal')),
      ])))).toList());
}

class _StatRow extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool bold;
  const _StatRow(this.label, this.value, this.color, this.bold);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(value, style: TextStyle(fontSize: 13, color: color,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontFamily: 'Tajawal')),
      Text(label, textDirection: TextDirection.rtl,
        style: TextStyle(fontSize: 13,
          color: bold ? const Color(0xFFF0EDE6) : const Color(0xFF8A8880),
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
          fontFamily: 'Tajawal')),
    ]));
}

class _SummaryData {
  final String label, value;
  final Color color;
  const _SummaryData(this.label, this.value, this.color);
}

class _DownloadBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final bool loading;
  final VoidCallback onTap;
  const _DownloadBtn({required this.label, required this.icon,
    required this.color, required this.onTap,
    this.outlined = false, this.loading = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(height: 48,
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5)),
      child: Center(child: loading
        ? SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(color: color, strokeWidth: 2))
        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w600, fontFamily: 'Tajawal')),
          ]))));
}
