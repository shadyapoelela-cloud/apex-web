/// APEX — Receipt Quick Capture
/// ═══════════════════════════════════════════════════════════════════════
/// Single-screen scan-receipt-and-record-expense flow:
///   1. Tap → file picker (web) or camera (mobile)
///   2. Image preview
///   3. Send to backend OCR (Claude Vision)
///   4. Show extracted: vendor / amount / date / VAT
///   5. User edits + confirms → POST creates a vendor bill / expense JE
///
/// Backend: POST /api/v1/ocr/extract (Claude Vision scaffold)
/// Falls back to manual entry if OCR isn't reachable.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class ReceiptCaptureScreen extends StatefulWidget {
  const ReceiptCaptureScreen({super.key});

  @override
  State<ReceiptCaptureScreen> createState() => _ReceiptCaptureScreenState();
}

class _ReceiptCaptureScreenState extends State<ReceiptCaptureScreen> {
  Uint8List? _imageBytes;
  bool _processing = false;

  // Extracted fields (populated after OCR or by manual entry)
  final _vendorCtl = TextEditingController();
  final _amountCtl = TextEditingController();
  final _vatCtl = TextEditingController(text: '15');
  DateTime? _date;

  @override
  void dispose() {
    _vendorCtl.dispose();
    _amountCtl.dispose();
    _vatCtl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    // Web placeholder — real implementation would use file_picker plugin
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('اختيار الصورة (يتطلب صلاحية الكاميرا/المعرض)'),
      action: SnackBarAction(
        label: 'إدخال يدوي',
        onPressed: () => setState(() => _imageBytes = null),
      ),
    ));
  }

  Future<void> _ocrExtract() async {
    setState(() => _processing = true);
    // TODO: real OCR call when /api/v1/ocr/extract is production-ready.
    // For now: simulate by pre-filling demo fields.
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _processing = false;
      _vendorCtl.text = 'مورد عام';
      _amountCtl.text = '350';
      _date = DateTime.now();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.warn,
      content: const Text('OCR في وضع تجريبي — راجع البيانات قبل الحفظ'),
    ));
  }

  Future<void> _save() async {
    if (_vendorCtl.text.trim().isEmpty || _amountCtl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء البائع والمبلغ')),
      );
      return;
    }
    // TODO: POST /api/v1/pilot/expenses (or vendor bill creation flow)
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: AC.ok,
      content: const Text('تم حفظ المصروف (سيُنفّذ مع backend OCR قريباً)'),
    ));
    context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Text('إيصال جديد', style: TextStyle(color: AC.gold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _imageCard(),
          const SizedBox(height: 14),
          if (_imageBytes != null || _vendorCtl.text.isNotEmpty) _fieldsCard(),
          const ApexOutputChips(items: [
            ApexChipLink('فواتير الموردين', '/purchase/bills', Icons.receipt_outlined),
            ApexChipLink('قائمة القيود', '/accounting/je-list', Icons.book),
            ApexChipLink('تقارير المصاريف', '/hr/expense-reports', Icons.receipt_long),
          ]),
        ]),
      ),
      floatingActionButton: _vendorCtl.text.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _save,
              backgroundColor: AC.gold,
              foregroundColor: AC.navy,
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
            ),
    );
  }

  Widget _imageCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: AC.navy3,
            border: Border.all(color: AC.bdr),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _imageBytes == null
              ? Center(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.receipt_outlined, size: 40, color: AC.ts),
                    const SizedBox(height: 8),
                    Text('لا توجد صورة', style: TextStyle(color: AC.ts, fontSize: 12)),
                  ]),
                )
              : Image.memory(_imageBytes!, fit: BoxFit.contain),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _pickImage,
              icon: Icon(Icons.photo_camera, color: AC.gold),
              label: Text('التقط/اختر', style: TextStyle(color: AC.gold)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _processing ? null : _ocrExtract,
              icon: _processing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.psychology),
              label: Text(_processing ? 'جارٍ القراءة…' : 'استخرج بـ AI'),
              style: ElevatedButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.navy),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _fieldsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border.all(color: AC.bdr),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('البيانات المستخرجة', style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _input(_vendorCtl, 'البائع', Icons.store),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _input(_amountCtl, 'المبلغ', Icons.attach_money, numeric: true)),
          const SizedBox(width: 8),
          SizedBox(width: 100, child: _input(_vatCtl, 'VAT %', Icons.percent, numeric: true)),
        ]),
      ]),
    );
  }

  Widget _input(TextEditingController c, String label, IconData icon, {bool numeric = false}) =>
      TextField(
        controller: c,
        keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
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
