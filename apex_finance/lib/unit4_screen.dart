import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class Unit4Screen extends StatefulWidget {
  const Unit4Screen({super.key});
  @override
  State<Unit4Screen> createState() => _Unit4ScreenState();
}

class _Unit4ScreenState extends State<Unit4Screen> {
  bool _fileSelected = false, _loading = false, _done = false;
  String _fileName = '', _error = '';
  PlatformFile? _pickedFile;
  Map<String, dynamic>? _result;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv'], withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() { _fileSelected = true; _fileName = result.files.first.name; _pickedFile = result.files.first; _done = false; _result = null; _error = ''; });
    }
  }

  Future<void> _analyze() async {
    if (_pickedFile == null) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final uri = Uri.parse('http://localhost:8000/unit4/analyze/multistage');
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

  Map<String, dynamic> _getData() => _result?['final_result']?['data'] ?? {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, elevation: 0,
        title: const Text('تحليل الجرد', style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AC.textSecondary, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // بانر
          Container(width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [AC.warning.withOpacity(0.1), AC.navy3]), borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.warning.withOpacity(0.3))),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: AC.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.inventory_2_rounded, color: AC.warning, size: 24)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
                Text('تحليل بضاعة آخر المدة', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.warning, fontFamily: 'Tajawal')),
                SizedBox(height: 2),
                Text('هوامش الربح + ABC + مقارنة بالسوق', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
              ])])),
          const SizedBox(height: 16),

          // رفع الملف
          GestureDetector(onTap: _pickFile,
            child: Container(width: double.infinity, height: 130,
              decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: _fileSelected ? AC.warning.withOpacity(0.5) : AC.border)),
              child: _fileSelected
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.description_rounded, color: AC.warning, size: 36), const SizedBox(height: 6),
                    Text(_fileName, style: const TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal')),
                    const Text('جاهز — اضغط لتغيير', style: TextStyle(color: AC.warning, fontSize: 11, fontFamily: 'Tajawal'))])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 50, height: 50, decoration: BoxDecoration(color: AC.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.cloud_upload_rounded, color: AC.warning, size: 26)),
                    const SizedBox(height: 8),
                    const Text('ارفع ملف الجرد', style: TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal')),
                    const Text('Excel (.xlsx) أو CSV', style: TextStyle(color: AC.textSecondary, fontSize: 11, fontFamily: 'Tajawal'))]))),
          const SizedBox(height: 14),

          if (_error.isNotEmpty)
            Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFE24B4A).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE24B4A).withOpacity(0.3))),
              child: Text(_error, textDirection: TextDirection.rtl, style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 12, fontFamily: 'Tajawal'))),

          if (!_done)
            GestureDetector(onTap: _fileSelected && !_loading ? _analyze : null,
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  gradient: _fileSelected && !_loading ? const LinearGradient(colors: [AC.warning, Color(0xFFB8860B)]) : null,
                  color: !_fileSelected || _loading ? AC.navy3 : null,
                  borderRadius: BorderRadius.circular(14), border: Border.all(color: _fileSelected ? AC.warning.withOpacity(0.5) : AC.border)),
                child: Center(child: _loading
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10), Text('جاري تحليل الجرد...', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Tajawal'))])
                  : Text(_fileSelected ? 'بدء تحليل الجرد' : 'اختر ملف الجرد',
                      style: TextStyle(color: _fileSelected ? Colors.white : AC.textHint, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'))))),

          // ═══ النتائج ═══
          if (_done && _result != null) ...[
            const SizedBox(height: 20),
            _buildConfidence(),
            const SizedBox(height: 14),
            _buildKPIs(),
            const SizedBox(height: 14),
            _buildABC(),
            const SizedBox(height: 14),
            _buildMarketComparison(),
            const SizedBox(height: 14),
            _buildTopItems('أعلى الأصناف قيمة', Map<String, dynamic>.from(_getData()['top_by_value'] ?? {}), Icons.attach_money_rounded, AC.gold),
            const SizedBox(height: 14),
            _buildTopItems('أعلى الأصناف كمية', Map<String, dynamic>.from(_getData()['top_by_qty'] ?? {}), Icons.shopping_cart_rounded, AC.cyan),
            const SizedBox(height: 14),
            _buildTopItems('أعلى هامش ربح', Map<String, dynamic>.from(_getData()['top_by_margin'] ?? {}), Icons.trending_up_rounded, AC.success, suffix: '%'),
            const SizedBox(height: 14),
            if ((_getData()['loss_products'] as Map?)?.isNotEmpty ?? false)
              _buildTopItems('منتجات خاسرة', Map<String, dynamic>.from(_getData()['loss_products'] ?? {}), Icons.warning_rounded, const Color(0xFFE24B4A), suffix: '%'),
            if ((_getData()['loss_products'] as Map?)?.isNotEmpty ?? false)
              const SizedBox(height: 14),
            _buildAIAnalysis(),
            const SizedBox(height: 16),
            GestureDetector(onTap: () => setState(() { _fileSelected = false; _done = false; _result = null; _fileName = ''; _pickedFile = null; }),
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.warning, Color(0xFFB8860B)]), borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('تحليل ملف آخر', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))))),
            const SizedBox(height: 40),
          ],
        ])));
  }

  Widget _buildConfidence() {
    final fr = _result!['final_result'] ?? {};
    final conf = (fr['confidence_pct'] ?? 90).toDouble();
    final label = fr['quality_label'] ?? 'جيد';
    final platforms = (_result!['stages']?['stage1_ai']?['platforms_used'] as List?)?.cast<String>() ?? [];
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.warning.withOpacity(0.3))),
      child: Column(children: [
        Row(children: [
          SizedBox(width: 60, height: 60, child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: conf / 100, strokeWidth: 5, backgroundColor: AC.border, color: AC.warning),
            Text('${conf.toInt()}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AC.warning, fontFamily: 'Tajawal'))])),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$conf%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AC.warning, fontFamily: 'Tajawal')),
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: AC.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(label, style: const TextStyle(fontSize: 11, color: AC.warning, fontFamily: 'Tajawal', fontWeight: FontWeight.w600)))])]),
        if (platforms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, alignment: WrapAlignment.end,
            children: platforms.map((p) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AC.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(p, style: const TextStyle(fontSize: 10, color: AC.gold, fontFamily: 'Tajawal')))).toList())]]));
  }

  Widget _buildKPIs() {
    final s = _getData()['summary'] ?? {};
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('مؤشرات الجرد الرئيسية', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _kpi('عدد الأصناف', '${s['num_items'] ?? 0}', AC.gold)),
          const SizedBox(width: 8),
          Expanded(child: _kpi('إجمالي الكمية', _fmt(s['total_quantity']), AC.cyan)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _kpi('قيمة التكلفة', _fmt(s['total_cost_value']), AC.warning)),
          const SizedBox(width: 8),
          Expanded(child: _kpi('قيمة البيع', _fmt(s['total_sell_value']), AC.success)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _kpi('الربح المتوقع', _fmt(s['expected_profit']), AC.gold)),
          const SizedBox(width: 8),
          Expanded(child: _kpi('هامش الربح', '${s['expected_margin_pct'] ?? 0}%', AC.success)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _kpi('منتجات خاسرة', '${s['num_loss_items'] ?? 0}', const Color(0xFFE24B4A))),
          const SizedBox(width: 8),
          Expanded(child: _kpi('هامش عالي (>50%)', '${s['num_high_margin_items'] ?? 0}', const Color(0xFF6C5CE7))),
        ]),
      ]));
  }

  Widget _kpi(String label, String value, Color color) {
    return Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.15))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, fontFamily: 'Tajawal')),
        Text(label, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
      ]));
  }

  Widget _buildABC() {
    final abc = _getData()['abc_analysis'] ?? {};
    final total = (abc['a_items'] ?? 0) + (abc['b_items'] ?? 0) + (abc['c_items'] ?? 0);
    if (total == 0) return const SizedBox.shrink();
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('تحليل ABC للمخزون', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 4),
        const Text('توزيع الأصناف حسب قيمتها من إجمالي المخزون', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal')),
        const SizedBox(height: 14),
        _abcRow('A', 'أصناف حيوية — 80% من القيمة', abc['a_items'] ?? 0, abc['a_value'] ?? 0, const Color(0xFFE24B4A), total),
        const SizedBox(height: 10),
        _abcRow('B', 'أصناف متوسطة — 15% من القيمة', abc['b_items'] ?? 0, abc['b_value'] ?? 0, AC.warning, total),
        const SizedBox(height: 10),
        _abcRow('C', 'أصناف ثانوية — 5% من القيمة', abc['c_items'] ?? 0, abc['c_value'] ?? 0, AC.success, total),
      ]));
  }

  Widget _abcRow(String grade, String desc, int count, double value, Color color, int total) {
    final pct = total > 0 ? (count / total * 100) : 0.0;
    return Container(padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        Text(_fmt(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(' ($count صنف — ${pct.toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 10, color: AC.textSecondary, fontFamily: 'Tajawal')),
            Text('  الفئة $grade', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
          ]),
          Text(desc, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 10, color: AC.textHint, fontFamily: 'Tajawal')),
        ]),
      ]));
  }

  Widget _buildMarketComparison() {
    final mc = _getData()['market_comparison'] ?? {};
    if (mc.isEmpty) return const SizedBox.shrink();
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('مقارنة بمعايير السوق', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 10),
        ...(mc.entries.where((e) => e.value is Map)).map((e) {
          final item = e.value as Map;
          final status = item['status'] ?? '';
          final detail = item['detail'] ?? '';
          final clr = status.contains('أعلى') ? AC.cyan : status.contains('أقل') ? const Color(0xFFE24B4A) : status.contains('ضمن') ? AC.success : AC.textSecondary;
          return Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: clr.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(status, style: TextStyle(fontSize: 10, color: clr, fontFamily: 'Tajawal', fontWeight: FontWeight.w600))),
              const Spacer(),
              Flexible(child: Text(detail, textDirection: TextDirection.rtl, overflow: TextOverflow.ellipsis, maxLines: 2,
                style: const TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal'))),
            ]));
        }),
      ]));
  }

  Widget _buildTopItems(String title, Map<String, dynamic> items, IconData icon, Color color, {String suffix = ''}) {
    if (items.isEmpty) return const SizedBox.shrink();
    final sorted = items.entries.toList()..sort((a, b) => (b.value as num).abs().compareTo((a.value as num).abs()));
    final maxVal = sorted.isNotEmpty ? (sorted.first.value as num).toDouble().abs() : 1.0;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text(title, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
          const SizedBox(width: 8), Icon(icon, color: color, size: 18)]),
        const SizedBox(height: 10),
        ...sorted.take(5).map((e) {
          final val = (e.value as num).toDouble();
          return Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(children: [
                Text('${suffix.isEmpty ? _fmt(val) : val.toStringAsFixed(1)}$suffix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFamily: 'Tajawal')),
                const Spacer(),
                Flexible(child: Text(e.key, textDirection: TextDirection.rtl, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal')))]),
              const SizedBox(height: 3),
              ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: maxVal > 0 ? val.abs() / maxVal : 0, minHeight: 4, backgroundColor: AC.border, color: color)),
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
        const Text('تحليل الذكاء الاصطناعي', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        if (summary.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(summary, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5))],
        if (strengths.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('نقاط القوة', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AC.success, fontFamily: 'Tajawal')),
          ...strengths.map((s) => Padding(padding: const EdgeInsets.only(top: 3),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text(s, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal'))),
              const SizedBox(width: 6), const Icon(Icons.check_circle_outline_rounded, color: AC.success, size: 14)])))],
        if (weaknesses.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('نقاط الضعف', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE24B4A), fontFamily: 'Tajawal')),
          ...weaknesses.map((w) => Padding(padding: const EdgeInsets.only(top: 3),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Flexible(child: Text(w, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal'))),
              const SizedBox(width: 6), const Icon(Icons.warning_amber_rounded, color: Color(0xFFE24B4A), size: 14)])))],
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
                const SizedBox(width: 6), const Icon(Icons.arrow_circle_left_outlined, color: AC.cyan, size: 14)]));
          })],
      ]));
  }
}
