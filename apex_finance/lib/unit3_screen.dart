import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class Unit3Screen extends StatefulWidget {
  const Unit3Screen({super.key});
  @override
  State<Unit3Screen> createState() => _Unit3ScreenState();
}

class _Unit3ScreenState extends State<Unit3Screen> {
  bool _fileSelected = false, _loading = false, _done = false;
  String _fileName = '', _error = '';
  PlatformFile? _pickedFile;
  Map<String, dynamic>? _result;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv'], withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() { _fileSelected = true; _fileName = result.files.first.name; _pickedFile = result.files.first; _done = false; _result = null; _error = ''; });
    }
  }

  Future<void> _analyze() async {
    if (_pickedFile == null) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final uri = Uri.parse('https://apex-api-ootk.onrender.com/unit3/analyze/multistage');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', _pickedFile!.bytes!, filename: _pickedFile!.name));
      final streamed = await request.send().timeout(const Duration(seconds: 180));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) { setState(() { _result = data; _done = true; _loading = false; }); }
        else { setState(() { _error = data['detail'] ?? 'خطأ'; _loading = false; }); }
      } else {
        final err = json.decode(response.body);
        setState(() { _error = err['detail'] ?? 'خطأ: ${response.statusCode}'; _loading = false; });
      }
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    double n = (v is int) ? v.toDouble() : (v is double) ? v : 0.0;
    if (n.abs() >= 1e6) return '${(n/1e6).toStringAsFixed(2)}M';
    if (n.abs() >= 1e3) return '${(n/1e3).toStringAsFixed(1)}K';
    return n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, elevation: 0,
        title: const Text('تحليل المبيعات', style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AC.textSecondary, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // بانر
          Container(width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AC.success.withOpacity(0.1), AC.navy3]), borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.success.withOpacity(0.3))),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: AC.success.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.trending_up_rounded, color: AC.success, size: 24)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
                Text('تحليل أداء المبيعات', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.success, fontFamily: 'Tajawal')),
                SizedBox(height: 2),
                Text('KPIs + نسب النمو + أفضل المنتجات والعملاء', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
              ])])),
          const SizedBox(height: 16),

          // رفع الملف
          GestureDetector(onTap: _pickFile,
            child: Container(width: double.infinity, height: 130,
              decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: _fileSelected ? AC.success.withOpacity(0.5) : AC.border)),
              child: _fileSelected
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.description_rounded, color: AC.success, size: 36),
                    const SizedBox(height: 6),
                    Text(_fileName, style: const TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal')),
                    const Text('جاهز — اضغط لتغيير', style: TextStyle(color: AC.success, fontSize: 11, fontFamily: 'Tajawal'))])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 50, height: 50, decoration: BoxDecoration(color: AC.success.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.cloud_upload_rounded, color: AC.success, size: 26)),
                    const SizedBox(height: 8),
                    const Text('ارفع ملف المبيعات', style: TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal')),
                    const Text('Excel (.xlsx) أو CSV', style: TextStyle(color: AC.textSecondary, fontSize: 11, fontFamily: 'Tajawal'))]))),
          const SizedBox(height: 14),

          // خطأ
          if (_error.isNotEmpty)
            Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFE24B4A).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE24B4A).withOpacity(0.3))),
              child: Text(_error, textDirection: TextDirection.rtl, style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 12, fontFamily: 'Tajawal'))),

          // زر التحليل
          if (!_done)
            GestureDetector(onTap: _fileSelected && !_loading ? _analyze : null,
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  gradient: _fileSelected && !_loading ? const LinearGradient(colors: [AC.success, Color(0xFF1D7D55)]) : null,
                  color: !_fileSelected || _loading ? AC.navy3 : null,
                  borderRadius: BorderRadius.circular(14), border: Border.all(color: _fileSelected ? AC.success.withOpacity(0.5) : AC.border)),
                child: Center(child: _loading
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10),
                      Text('جاري تحليل المبيعات...', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Tajawal'))])
                  : Text(_fileSelected ? 'بدء تحليل المبيعات' : 'اختر ملف المبيعات',
                      style: TextStyle(color: _fileSelected ? Colors.white : AC.textHint, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'))))),

          // ═══ النتائج ═══
          if (_done && _result != null) ...[
            const SizedBox(height: 20),
            _buildConfidence(),
            const SizedBox(height: 14),
            _buildKPIs(),
            const SizedBox(height: 14),
            _buildMonthlySales(),
            const SizedBox(height: 14),
            _buildTopItems('أفضل المنتجات', _getMap('top_products'), Icons.inventory_2_rounded),
            const SizedBox(height: 14),
            _buildTopItems('أفضل العملاء', _getMap('top_clients'), Icons.people_rounded),
            const SizedBox(height: 14),
            _buildTopItems('المبيعات حسب المنطقة', _getMap('region_sales'), Icons.location_on_rounded),
            const SizedBox(height: 14),
            _buildAIAnalysis(),
            const SizedBox(height: 16),
            GestureDetector(onTap: () => setState(() { _fileSelected = false; _done = false; _result = null; _fileName = ''; _pickedFile = null; }),
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.success, Color(0xFF1D7D55)]), borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('تحليل ملف آخر', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))))),
            const SizedBox(height: 40),
          ],
        ])));
  }

  Map<String, dynamic> _getData() => _result?['final_result']?['data'] ?? _result?['stages']?['stage1_code']?['data'] ?? {};
  Map<String, dynamic> _getMap(String key) => Map<String, dynamic>.from(_getData()[key] ?? {});

  Widget _buildConfidence() {
    final fr = _result!['final_result'] ?? {};
    final conf = (fr['confidence_pct'] ?? 90).toDouble();
    final label = fr['quality_label'] ?? 'جيد';
    final platforms = (_result!['stages']?['stage1_ai']?['platforms_used'] as List?)?.cast<String>() ?? [];
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.success.withOpacity(0.3))),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 60, height: 60, child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: conf / 100, strokeWidth: 5, backgroundColor: AC.border, color: AC.success),
            Text('${conf.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AC.success, fontFamily: 'Tajawal'))])),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$conf%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AC.success, fontFamily: 'Tajawal')),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: AC.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(label, style: const TextStyle(fontSize: 11, color: AC.success, fontFamily: 'Tajawal', fontWeight: FontWeight.w600)))])]),
        if (platforms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, alignment: WrapAlignment.end,
            children: platforms.map((p) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AC.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(p, style: const TextStyle(fontSize: 10, color: AC.gold, fontFamily: 'Tajawal')))).toList())]]));
  }

  Widget _buildKPIs() {
    final s = _getData()['summary'] ?? {};
    final kpis = _getData()['kpis'] ?? {};
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('مؤشرات الأداء الرئيسية', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _kpiCard('صافي المبيعات', _fmt(s['net_sales'] ?? s['total_sales']), AC.gold)),
          const SizedBox(width: 8),
          Expanded(child: _kpiCard('نسبة المرتجعات', '${s['return_rate_pct'] ?? 0}%', AC.success)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _kpiCard('عدد الفواتير', '${s['num_sales'] ?? s['num_transactions'] ?? 0}', AC.cyan)),
          const SizedBox(width: 8),
          Expanded(child: _kpiCard('متوسط الفاتورة', '${s['avg_invoice'] ?? kpis['avg_transaction_value'] ?? 0}%', const Color(0xFF6C5CE7))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _kpiCard('إجمالي المبيعات', _fmt(s['gross_sales'] ?? s['total_sales']), AC.warning)),
          const SizedBox(width: 8),
          Expanded(child: _kpiCard('المرتجعات', _fmt(s['total_returns']), const Color(0xFFE24B4A))),
        ]),
      ]));
  }

  Widget _kpiCard(String label, String value, Color color) {
    return Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, fontFamily: 'Tajawal')),
        Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }

  Widget _buildMonthlySales() {
    final monthly = _getMap('monthly_sales');
    final growth = _getMap('monthly_growth');
    if (monthly.isEmpty) return const SizedBox.shrink();
    final sorted = monthly.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = sorted.map((e) => (e.value as num).toDouble()).fold<double>(0, (a, b) => a > b ? a : b);
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('المبيعات الشهرية', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 12),
        ...sorted.map((e) {
          final val = (e.value as num).toDouble();
          final g = growth[e.key];
          return Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Text(_fmt(val), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.textPrimary, fontFamily: 'Tajawal')),
                if (g != null) ...[
                  const SizedBox(width: 6),
                  Text('${(g as num).toDouble() >= 0 ? "+" : ""}${(g as num).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10, color: (g as num).toDouble() >= 0 ? AC.success : const Color(0xFFE24B4A), fontFamily: 'Tajawal'))],
                const Spacer(),
                Text(e.key, style: const TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal'))]),
              const SizedBox(height: 3),
              ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: maxVal > 0 ? val / maxVal : 0, minHeight: 5, backgroundColor: AC.border, color: AC.gold)),
            ]));
        }),
      ]));
  }

  Widget _buildTopItems(String title, Map<String, dynamic> items, IconData icon) {
    if (items.isEmpty) return const SizedBox.shrink();
    final sorted = items.entries.toList()..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final maxVal = (sorted.first.value as num).toDouble();
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
          const SizedBox(width: 8),
          Icon(icon, color: AC.gold, size: 18)]),
        const SizedBox(height: 10),
        ...sorted.take(5).map((e) {
          final val = (e.value as num).toDouble();
          return Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Text(_fmt(val), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AC.textPrimary, fontFamily: 'Tajawal')),
                const Spacer(),
                Flexible(child: Text(e.key, textDirection: TextDirection.rtl, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')))]),
              const SizedBox(height: 3),
              ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: maxVal > 0 ? val / maxVal : 0, minHeight: 4, backgroundColor: AC.border, color: AC.success)),
            ]));
        }),
      ]));
  }

  Widget _buildAIAnalysis() {
    final ai = _result?['final_result']?['ai_analysis'] ?? {};
    if (ai.isEmpty || ai['error'] != null) return const SizedBox.shrink();
    final summary = ai['executive_summary'] ?? ai['summary'] ?? '';
    final strengths = (ai['strengths'] as List?)?.cast<String>() ?? [];
    final weaknesses = (ai['weaknesses'] as List?)?.cast<String>() ?? [];
    final plan = (ai['action_plan'] as List?) ?? [];
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('تحليل الذكاء الاصطناعي', textDirection: TextDirection.rtl,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(summary, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5))],
        if (strengths.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('نقاط القوة', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.success, fontFamily: 'Tajawal')),
          ...strengths.map((s) => Padding(padding: const EdgeInsets.only(top: 3),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text(s, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal'))),
              const SizedBox(width: 6),
              const Icon(Icons.check_circle_outline_rounded, color: AC.success, size: 14)])))],
        if (weaknesses.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('نقاط الضعف', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE24B4A), fontFamily: 'Tajawal')),
          ...weaknesses.map((w) => Padding(padding: const EdgeInsets.only(top: 3),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text(w, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal'))),
              const SizedBox(width: 6),
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE24B4A), size: 14)])))],
        if (plan.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('خطة التحسين', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.cyan, fontFamily: 'Tajawal')),
          ...plan.map((p) {
            final action = p is Map ? (p['action'] ?? p.toString()) : p.toString();
            final timeline = p is Map ? (p['timeline'] ?? '') : '';
            return Padding(padding: const EdgeInsets.only(top: 3),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (timeline.isNotEmpty) Text(' ($timeline)', style: const TextStyle(fontSize: 10, color: AC.textHint, fontFamily: 'Tajawal')),
                Flexible(child: Text(action.toString(), textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal'))),
                const SizedBox(width: 6),
                const Icon(Icons.arrow_circle_left_outlined, color: AC.cyan, size: 14)]));
          })],
      ]));
  }
}



