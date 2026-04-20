/// ImportDialog — استيراد bulk من Excel/CSV لأي كيان.
///
/// الاستخدام:
///   showDialog(
///     context: context,
///     builder: (_) => ImportDialog(
///       title: 'استيراد الحسابات',
///       mapping: coaMapping,
///       requiredFields: ['code', 'name_ar', 'category'],
///       onImport: (row) async => pilotClient.createAccount(...),
///     ),
///   );
library;

// Re-export mappings for convenience of consumers
export '../import_utils.dart' show coaMapping, productMapping, vendorMapping, ImportMapping;

import 'package:flutter/material.dart';
import '../../api_service.dart' show ApiResult;
import '../import_utils.dart';

const _gold = Color(0xFFD4AF37);
const _navy2 = Color(0xFF132339);
const _navy3 = Color(0xFF1D3150);
const _bdr = Color(0x33FFFFFF);
const _tp = Color(0xFFFFFFFF);
const _ts = Color(0xFFBCC5D3);
const _td = Color(0xFF6B7A90);
// ignore: unused_element
const _ok = Color(0xFF10B981);
const _err = Color(0xFFEF4444);
const _warn = Color(0xFFF59E0B);

class ImportDialog extends StatefulWidget {
  final String title;
  final ImportMapping mapping;
  final List<String> requiredFields;
  final Future<ApiResult> Function(Map<String, dynamic>) onImport;

  const ImportDialog({
    super.key,
    required this.title,
    required this.mapping,
    required this.requiredFields,
    required this.onImport,
  });

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  ParsedSheet? _parsed;
  String? _filename;
  List<String> _validationErrors = [];
  bool _importing = false;
  int _successCount = 0;
  int _errorCount = 0;
  List<String> _errorLog = [];

  Future<void> _pickFile() async {
    final bytes = await pickFileBytes();
    if (bytes == null) return;
    // نحصل على الاسم من الـ input (simplified — نستخدم placeholder)
    const filename = 'import.xlsx'; // actually pickFileBytes يمكن تطويرها لترجع name
    if (!mounted) return;
    try {
      final parsed = autoParse(bytes, filename);
      final errors = validateRows(
        sheet: parsed,
        mapping: widget.mapping,
        requiredFields: widget.requiredFields,
      );
      setState(() {
        _parsed = parsed;
        _filename = filename;
        _validationErrors = errors;
        _successCount = 0;
        _errorCount = 0;
        _errorLog = [];
      });
    } catch (e) {
      setState(() {
        _validationErrors = ['فشل parse الملف: $e'];
      });
    }
  }

  Future<void> _runImport() async {
    if (_parsed == null || _validationErrors.isNotEmpty) return;
    setState(() {
      _importing = true;
      _successCount = 0;
      _errorCount = 0;
      _errorLog = [];
    });
    for (int i = 0; i < _parsed!.rows.length; i++) {
      final row = _parsed!.rows[i];
      final mapped = widget.mapping.apply(row);
      try {
        final r = await widget.onImport(mapped);
        if (r.success) {
          _successCount++;
        } else {
          _errorCount++;
          _errorLog.add('الصف ${i + 2}: ${r.error ?? "فشل"}');
        }
      } catch (e) {
        _errorCount++;
        _errorLog.add('الصف ${i + 2}: exception $e');
      }
      if (mounted) setState(() {});
    }
    setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        backgroundColor: _navy2,
        insetPadding: const EdgeInsets.all(40),
        child: Container(
          width: 800,
          height: 650,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _gold.withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              decoration: BoxDecoration(
                color: _navy3,
                border: Border(bottom: BorderSide(color: _bdr)),
              ),
              child: Row(children: [
                const Icon(Icons.upload_file, color: _gold, size: 22),
                const SizedBox(width: 10),
                Text(widget.title,
                    style: const TextStyle(
                        color: _tp,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: _ts),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            // Body
            Expanded(child: _buildBody()),
            // Footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _navy3,
                border: Border(top: BorderSide(color: _bdr)),
              ),
              child: Row(children: [
                if (_parsed != null)
                  Text(
                      'الصفوف: ${_parsed!.rowCount} · نجاح: $_successCount · فشل: $_errorCount',
                      style: const TextStyle(color: _ts, fontSize: 12)),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق',
                        style: TextStyle(color: _ts))),
                const SizedBox(width: 8),
                if (_parsed != null &&
                    _validationErrors.isEmpty &&
                    !_importing)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: Colors.black),
                    onPressed: _runImport,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: Text('استيراد ${_parsed!.rowCount} صف'),
                  )
                else if (_importing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _gold),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_parsed == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload_outlined,
                color: _gold.withValues(alpha: 0.3), size: 80),
            const SizedBox(height: 16),
            const Text('اختر ملف Excel (.xlsx) أو CSV لاستيراد البيانات',
                style: TextStyle(color: _tp, fontSize: 14)),
            const SizedBox(height: 8),
            const Text(
                'يدعم headers عربية وإنجليزية · الصف الأول هو أسماء الأعمدة',
                style: TextStyle(color: _ts, fontSize: 11)),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14)),
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('اختر ملف'),
            ),
            const SizedBox(height: 16),
            _buildExpectedFields(),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary
          Row(children: [
            const Icon(Icons.description, color: _gold, size: 18),
            const SizedBox(width: 8),
            Text('الملف: ${_filename ?? "مجهول"}',
                style: const TextStyle(color: _tp, fontSize: 13)),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: _ts),
              onPressed: _pickFile,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('ملف آخر'),
            ),
          ]),
          const SizedBox(height: 8),
          // Warnings
          if (_parsed!.warnings.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _warn.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _parsed!.warnings
                    .map((w) => Text('ℹ $w',
                        style: TextStyle(color: _warn, fontSize: 11)))
                    .toList(),
              ),
            ),
          const SizedBox(height: 8),
          // Validation errors
          if (_validationErrors.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _err.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _err.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.error_outline, color: _err, size: 16),
                    const SizedBox(width: 6),
                    Text('${_validationErrors.length} مشكلة:',
                        style: const TextStyle(
                            color: _err, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  ..._validationErrors.take(10).map((e) => Text(e,
                      style: const TextStyle(color: _err, fontSize: 11))),
                  if (_validationErrors.length > 10)
                    Text('و ${_validationErrors.length - 10} آخرين...',
                        style: const TextStyle(color: _err, fontSize: 11)),
                ],
              ),
            ),
          const SizedBox(height: 10),
          // Preview headers
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr),
            ),
            child: Row(children: [
              const Text('الأعمدة المُكتشفة:',
                  style:
                      TextStyle(color: _td, fontSize: 11)),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _parsed!.headers
                      .map((h) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(h,
                                style: const TextStyle(
                                    color: _gold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600)),
                          ))
                      .toList(),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          // Preview rows (first 5)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _navy3,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _bdr),
              ),
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  Text(
                      'معاينة أول 5 صفوف (من أصل ${_parsed!.rowCount}):',
                      style: const TextStyle(color: _td, fontSize: 11)),
                  const SizedBox(height: 6),
                  ...(_parsed!.rows.take(5).toList()).asMap().entries.map((e) {
                    final idx = e.key;
                    final row = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _navy2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(children: [
                        Text('${idx + 1}.',
                            style:
                                const TextStyle(color: _td, fontSize: 10)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              row.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(' · '),
                              style: const TextStyle(
                                  color: _ts,
                                  fontSize: 11,
                                  fontFamily: 'monospace'),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    );
                  }),
                  // Error log
                  if (_errorLog.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text('أخطاء الاستيراد (${_errorLog.length}):',
                        style:
                            const TextStyle(color: _err, fontSize: 11)),
                    const SizedBox(height: 4),
                    ..._errorLog.take(10).map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _err.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(e,
                              style: const TextStyle(
                                  color: _err, fontSize: 10)),
                        )),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectedFields() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الحقول المطلوبة (يجب أن تكون في الـ headers):',
              style: TextStyle(color: _td, fontSize: 11)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.requiredFields
                .map((f) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _err.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                        border:
                            Border.all(color: _err.withValues(alpha: 0.4)),
                      ),
                      child: Text(f,
                          style: const TextStyle(
                              color: _err,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace')),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          const Text(
              '💡 الـ headers يمكن أن تكون بالعربية أو الإنجليزية. الـ mapper يتعرّف على: code/الكود، name_ar/الاسم، category/الفئة، إلخ.',
              style: TextStyle(color: _ts, fontSize: 10, height: 1.5)),
        ],
      ),
    );
  }
}

