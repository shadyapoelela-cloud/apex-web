import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

class AdvancedUnitScreen extends StatefulWidget {
  final int unitNumber;
  final String title, subtitle, endpoint;
  final IconData icon;
  final Color color;
  const AdvancedUnitScreen({super.key, required this.unitNumber, required this.title, required this.subtitle, required this.endpoint, required this.icon, required this.color});
  @override
  State<AdvancedUnitScreen> createState() => _AdvancedUnitScreenState();
}

class _AdvancedUnitScreenState extends State<AdvancedUnitScreen> {
  bool _fileSelected = false, _loading = false, _done = false;
  String _fileName = '', _error = '';
  PlatformFile? _pickedFile;
  Map<String, dynamic>? _result;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['xlsx', 'xls', 'csv', 'pdf'], withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() { _fileSelected = true; _fileName = result.files.first.name; _pickedFile = result.files.first; _done = false; _result = null; _error = ''; });
    }
  }

  Future<void> _analyze() async {
    if (_pickedFile == null) return;
    setState(() { _loading = true; _error = ''; });
    try {
      final uri = Uri.parse(widget.endpoint);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, elevation: 0,
        title: Text(widget.title, style: const TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AC.textSecondary, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // بانر
          Container(width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [widget.color.withOpacity(0.1), AC.navy3]), borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.color.withOpacity(0.3))),
            child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: widget.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: Icon(widget.icon, color: widget.color, size: 24)),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(widget.title, textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: widget.color, fontFamily: 'Tajawal')),
                const SizedBox(height: 2),
                Text(widget.subtitle, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
              ])])),
          const SizedBox(height: 16),

          // المستندات المطلوبة
          Container(width: double.infinity, padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                const Text('المستندات المطلوبة', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
                const SizedBox(width: 8),
                Icon(Icons.checklist_rounded, color: widget.color, size: 18),
              ]),
              const SizedBox(height: 10),
              ..._getRequiredDocs().map((doc) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Flexible(child: Text(doc['name']!, textDirection: TextDirection.rtl,
                    style: TextStyle(fontSize: 12, color: doc['req'] == '1' ? AC.textPrimary : AC.textSecondary, fontFamily: 'Tajawal'))),
                  const SizedBox(width: 8),
                  Icon(doc['req'] == '1' ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                    color: doc['req'] == '1' ? widget.color : AC.textHint, size: 16),
                ]))),
              const SizedBox(height: 6),
              Container(width: double.infinity, padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: widget.color.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                child: Text('ارفع ملف واحد يحتوي على البيانات — المنصة تكتشف الأعمدة تلقائياً',
                  textDirection: TextDirection.rtl, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: widget.color, fontFamily: 'Tajawal'))),
            ])),
          const SizedBox(height: 14),

          // رفع الملف
          GestureDetector(onTap: _pickFile,
            child: Container(width: double.infinity, height: 130,
              decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: _fileSelected ? widget.color.withOpacity(0.5) : AC.border)),
              child: _fileSelected
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.description_rounded, color: widget.color, size: 36), const SizedBox(height: 6),
                    Text(_fileName, style: const TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal')),
                    Text('جاهز — اضغط لتغيير', style: TextStyle(color: widget.color, fontSize: 11, fontFamily: 'Tajawal'))])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 50, height: 50, decoration: BoxDecoration(color: widget.color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.cloud_upload_rounded, color: widget.color, size: 26)),
                    const SizedBox(height: 8),
                    const Text('ارفع الملف المطلوب', style: TextStyle(color: AC.textPrimary, fontSize: 14, fontFamily: 'Tajawal')),
                    const Text('Excel, CSV, أو PDF', style: TextStyle(color: AC.textSecondary, fontSize: 11, fontFamily: 'Tajawal'))]))),
          const SizedBox(height: 14),

          if (_error.isNotEmpty)
            Container(width: double.infinity, padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFE24B4A).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE24B4A).withOpacity(0.3))),
              child: Text(_error, textDirection: TextDirection.rtl, style: const TextStyle(color: Color(0xFFE24B4A), fontSize: 12, fontFamily: 'Tajawal'))),

          if (!_done)
            GestureDetector(onTap: _fileSelected && !_loading ? _analyze : null,
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(
                  gradient: _fileSelected && !_loading ? LinearGradient(colors: [widget.color, widget.color.withOpacity(0.7)]) : null,
                  color: !_fileSelected || _loading ? AC.navy3 : null,
                  borderRadius: BorderRadius.circular(14), border: Border.all(color: _fileSelected ? widget.color.withOpacity(0.5) : AC.border)),
                child: Center(child: _loading
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 10), Text('جاري التحليل...', style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: 'Tajawal'))])
                  : Text(_fileSelected ? 'بدء التحليل' : 'اختر ملف أولاً',
                      style: TextStyle(color: _fileSelected ? Colors.white : AC.textHint, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'))))),

          // ═══ النتائج ═══
          if (_done && _result != null) ...[
            const SizedBox(height: 20),
            _buildConfidence(),
            const SizedBox(height: 14),
            _buildFileInfo(),
            const SizedBox(height: 14),
            _buildAIAnalysis(),
            const SizedBox(height: 16),
            GestureDetector(onTap: () => setState(() { _fileSelected = false; _done = false; _result = null; _fileName = ''; _pickedFile = null; }),
              child: Container(width: double.infinity, height: 52,
                decoration: BoxDecoration(gradient: LinearGradient(colors: [widget.color, widget.color.withOpacity(0.7)]), borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('تحليل ملف آخر', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Tajawal'))))),
            const SizedBox(height: 40),
          ],
        ])));
  }

  Widget _buildConfidence() {
    final conf = (_result!['confidence_pct'] ?? 85).toDouble();
    final label = _result!['quality_label'] ?? 'جيد';
    return Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: widget.color.withOpacity(0.3))),
      child: Row(children: [
        SizedBox(width: 60, height: 60, child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(value: conf / 100, strokeWidth: 5, backgroundColor: AC.border, color: widget.color),
          Text('${conf.toInt()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: widget.color, fontFamily: 'Tajawal'))])),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$conf%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: widget.color, fontFamily: 'Tajawal')),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: widget.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(label, style: TextStyle(fontSize: 11, color: widget.color, fontFamily: 'Tajawal', fontWeight: FontWeight.w600)))])]));
  }

  Widget _buildFileInfo() {
    final cols = (_result!['columns'] as List?)?.cast<String>() ?? [];
    final rows = _result!['rows'] ?? 0;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('معلومات الملف — $rows صف', textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end,
          children: cols.map((c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: widget.color.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: widget.color.withOpacity(0.15))),
            child: Text(c, style: TextStyle(fontSize: 10, color: widget.color, fontFamily: 'Tajawal')))).toList()),
      ]));
  }

  Widget _buildAIAnalysis() {
    final ai = _result!['ai_analysis'] ?? {};
    if (ai.isEmpty) return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.border)),
      child: const Center(child: Text('لم يتوفر تحليل AI — تحقق من اتصالك', textDirection: TextDirection.rtl,
        style: TextStyle(color: AC.textSecondary, fontSize: 13, fontFamily: 'Tajawal'))));

    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.gold.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Text('تحليل الذكاء الاصطناعي', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
        const SizedBox(height: 10),
        // عرض كل حقول الـ AI ديناميكياً
        ...ai.entries.where((e) => e.value is String && e.key != 'source' && (e.value as String).length > 5).map((e) =>
          Padding(padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_labelAr(e.key), textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.color, fontFamily: 'Tajawal')),
              const SizedBox(height: 2),
              Text(e.value.toString(), textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.5)),
            ]))),
        // عرض القوائم
        ...ai.entries.where((e) => e.value is List).map((e) {
          final list = (e.value as List).cast<dynamic>();
          if (list.isEmpty) return const SizedBox.shrink();
          final isGood = e.key.contains('strength') || e.key.contains('advantage') || e.key.contains('opportunit');
          final isBad = e.key.contains('risk') || e.key.contains('weakness') || e.key.contains('threat');
          final color = isGood ? AC.success : isBad ? const Color(0xFFE24B4A) : AC.cyan;
          final icon = isGood ? Icons.check_circle_outline_rounded : isBad ? Icons.warning_amber_rounded : Icons.arrow_circle_left_outlined;
          return Padding(padding: const EdgeInsets.only(bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_labelAr(e.key), textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color, fontFamily: 'Tajawal')),
              ...list.map((item) {
                final text = item is Map ? (item['action'] ?? item.toString()) : item.toString();
                final sub = item is Map ? (item['timeline'] ?? item['priority'] ?? '') : '';
                return Padding(padding: const EdgeInsets.only(top: 3),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (sub.toString().isNotEmpty) Text(' ($sub)', style: const TextStyle(fontSize: 10, color: AC.textHint, fontFamily: 'Tajawal')),
                    Flexible(child: Text(text.toString(), textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal'))),
                    const SizedBox(width: 6), Icon(icon, color: color, size: 14)]));
              }),
            ]));
        }),
        // عرض الأرقام المهمة
        ...ai.entries.where((e) => e.value is num && e.key != 'confidence_pct').map((e) =>
          Padding(padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text('${e.value}${e.key.contains('pct') ? '%' : ''}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: widget.color, fontFamily: 'Tajawal')),
              const Spacer(),
              Text(_labelAr(e.key), textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
            ]))),
      ]));
  }

  List<Map<String, String>> _getRequiredDocs() {
    final docs = {
      5: [{"name": "القوائم المالية (قائمة دخل + ميزانية)", "req": "1"}, {"name": "كشف حساب بنكي آخر 12 شهر", "req": "1"}, {"name": "جدول الديون والالتزامات", "req": "1"}, {"name": "السجل التجاري + رخصة النشاط", "req": "0"}, {"name": "تقرير SIMAH الائتماني", "req": "0"}],
      6: [{"name": "القوائم المالية لآخر 3 سنوات", "req": "1"}, {"name": "قائمة التدفقات النقدية", "req": "1"}, {"name": "الميزانية التقديرية", "req": "0"}, {"name": "تقرير المبيعات الشهرية", "req": "0"}, {"name": "جدول الالتزامات والأقساط", "req": "0"}],
      7: [{"name": "القوائم المالية لآخر 3 سنوات", "req": "1"}, {"name": "خطة العمل Business Plan", "req": "1"}, {"name": "دراسة السوق / تحليل المنافسين", "req": "0"}, {"name": "توقعات الإيرادات والمصروفات", "req": "0"}, {"name": "تفاصيل الأصول والممتلكات", "req": "0"}],
      8: [{"name": "القوائم المالية للشركة", "req": "1"}, {"name": "بيانات المنافسين (إن وجدت)", "req": "0"}, {"name": "تقارير القطاع / السوق", "req": "0"}, {"name": "تقرير المبيعات حسب المنطقة", "req": "0"}, {"name": "بيانات الحصة السوقية", "req": "0"}],
    };
    return docs[widget.unitNumber] ?? [{"name": "ملف البيانات المالية", "req": "1"}];
  }

  String _labelAr(String key) {
    const map = {
      'summary': 'الملخص', 'executive_summary': 'الملخص التنفيذي',
      'strengths': 'نقاط القوة', 'weaknesses': 'نقاط الضعف',
      'risks': 'المخاطر', 'recommendations': 'التوصيات',
      'opportunities': 'الفرص', 'threats': 'التهديدات',
      'competitive_advantages': 'المزايا التنافسية',
      'competitive_threats': 'التهديدات التنافسية',
      'required_documents': 'المستندات المطلوبة',
      'action_plan': 'خطة العمل',
      'credit_score': 'الدرجة الائتمانية',
      'credit_rating': 'التصنيف الائتماني',
      'bank_readiness_pct': 'جاهزية البنوك',
      'estimated_financing_range': 'نطاق التمويل المتوقع',
      'current_cash_position': 'الوضع النقدي',
      'burn_rate_monthly': 'معدل الحرق الشهري',
      'runway_months': 'المدرج (أشهر)',
      'company_valuation': 'تقييم الشركة',
      'valuation_method': 'طريقة التقييم',
      'roi_pct': 'العائد على الاستثمار',
      'payback_period_years': 'فترة الاسترداد (سنوات)',
      'npv': 'صافي القيمة الحالية',
      'irr_pct': 'معدل العائد الداخلي',
      'feasibility_score': 'درجة الجدوى',
      'feasibility_label': 'تقييم الجدوى',
      'market_position': 'الموقع في السوق',
      'market_share_estimate_pct': 'الحصة السوقية المقدرة',
      'sector_avg_margin_pct': 'متوسط هامش القطاع',
      'company_margin_pct': 'هامش الشركة',
      'inventory_score': 'درجة المخزون',
      'sales_health': 'صحة المبيعات',
      'returns_verdict': 'حكم المرتجعات',
      'loss_items_action': 'إجراء المنتجات الخاسرة',
    };
    return map[key] ?? key.replaceAll('_', ' ');
  }
}



