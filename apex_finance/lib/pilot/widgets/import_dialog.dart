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
import '../../core/theme.dart' as core_theme;
import '../../api_service.dart' show ApiResult;
import '../export_utils.dart' show exportXlsx;
import '../import_utils.dart';

Color get _gold => core_theme.AC.gold;
Color get _navy2 => core_theme.AC.navy2;
Color get _navy3 => core_theme.AC.navy3;
Color get _bdr => core_theme.AC.bdr;
Color get _tp => core_theme.AC.tp;
Color get _ts => core_theme.AC.ts;
Color get _td => core_theme.AC.td;
// ignore: unused_element
Color get _ok => core_theme.AC.ok;
Color get _err => core_theme.AC.err;
Color get _warn => core_theme.AC.warn;

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
    final picked = await pickFileWithName();
    if (picked == null) return;
    if (!mounted) return;
    try {
      final parsed = autoParse(picked.bytes, picked.name);
      final errors = validateRows(
        sheet: parsed,
        mapping: widget.mapping,
        requiredFields: widget.requiredFields,
      );
      setState(() {
        _parsed = parsed;
        _filename = picked.name;
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

  /// تنزيل قالب Excel (.xlsx) مع headers الصحيحة + 3 صفوف مثال.
  void _downloadTemplate() {
    // استخرج headers الفريدة من الـ mapping بالمفاتيح العربية المفضّلة
    final fieldsSeen = <String>{};
    final headers = <String>[];
    final fieldOrder = <String>[]; // لتتبّع field لكل header
    for (final entry in widget.mapping.columnMap.entries) {
      if (!fieldsSeen.contains(entry.value)) {
        final arabicKey = widget.mapping.columnMap.entries
            .firstWhere(
              (e) =>
                  e.value == entry.value &&
                  RegExp(r'[\u0600-\u06FF]').hasMatch(e.key),
              orElse: () => entry,
            )
            .key;
        headers.add(arabicKey);
        fieldOrder.add(entry.value);
        fieldsSeen.add(entry.value);
      }
    }

    // 3 صفوف مثال متنوّعة
    final samples = <Map<String, dynamic>>[
      {
        'code': '1110',
        'name_ar': 'النقدية في الصندوق',
        'name_en': 'Cash on Hand',
        'category': 'asset',
        'normal_balance': 'debit',
        'type': 'detail',
        '_parent_code': '1100',
      },
      {
        'code': '4100',
        'name_ar': 'إيرادات المبيعات',
        'name_en': 'Sales Revenue',
        'category': 'revenue',
        'normal_balance': 'credit',
        'type': 'detail',
        '_parent_code': '4000',
      },
      {
        'code': '5210',
        'name_ar': 'مصروف الإيجار',
        'name_en': 'Rent Expense',
        'category': 'expense',
        'normal_balance': 'debit',
        'type': 'detail',
        '_parent_code': '5200',
      },
    ];

    final rows = samples.map((sample) {
      return fieldOrder.map<dynamic>((field) => sample[field] ?? '').toList();
    }).toList();

    // ملاحظة: لا نُمرّر title ولا meta لأن parseXlsx يبحث عن أول صفّ
    // ذو 2+ خلية كـ headers، فمعلومات meta قد تختلط مع headers الحقيقية.
    // الإرشادات تُعرض في الـ UI بدلاً من ذلك.
    exportXlsx(
      headers: headers,
      rows: rows,
      filename: 'coa_template_${DateTime.now().millisecondsSinceEpoch}',
      sheetName: 'Accounts',
    );
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
                Icon(Icons.upload_file, color: _gold, size: 22),
                const SizedBox(width: 10),
                Text(widget.title,
                    style: TextStyle(
                        color: _tp,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: _ts),
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
                      style: TextStyle(color: _ts, fontSize: 12)),
                const Spacer(),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('إغلاق',
                        style: TextStyle(color: _ts))),
                const SizedBox(width: 8),
                if (_parsed != null &&
                    _validationErrors.isEmpty &&
                    !_importing)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: _gold,
                        foregroundColor: core_theme.AC.bestOn(_gold)),
                    onPressed: _runImport,
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: Text('استيراد ${_parsed!.rowCount} صف'),
                  )
                else if (_importing)
                  SizedBox(
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
            Text('اختر ملف Excel (.xlsx) أو CSV لاستيراد البيانات',
                style: TextStyle(color: _tp, fontSize: 14)),
            const SizedBox(height: 8),
            Text(
                'يدعم headers عربية وإنجليزية · الصف الأول هو أسماء الأعمدة',
                style: TextStyle(color: _ts, fontSize: 11)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: core_theme.AC.bestOn(_gold),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14)),
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open),
                label: const Text('اختر ملف'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: _ok,
                    side: BorderSide(color: _ok.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14)),
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.file_download, size: 18),
                label: const Text('نزّل القالب (Excel)'),
              ),
            ]),
            const SizedBox(height: 16),
            _buildExpectedFields(),
          ],
        ),
      );
    }
    // ملف مرفوع لكنه فارغ تماماً (لا headers ولا rows)
    if (_parsed!.headers.isEmpty && _parsed!.rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: _err, size: 64),
            const SizedBox(height: 12),
            Text('الملف فارغ أو غير قابل للقراءة',
                style: TextStyle(
                    color: _tp,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
                'تحقق من أن الورقة الأولى تحتوي على headers في الصف الأول وبيانات في الصفوف التالية',
                textAlign: TextAlign.center,
                style: TextStyle(color: _ts, fontSize: 12)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: core_theme.AC.bestOn(_gold)),
                onPressed: _pickFile,
                icon: const Icon(Icons.folder_open, size: 16),
                label: const Text('ملف آخر'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: _ok,
                    side: BorderSide(color: _ok.withValues(alpha: 0.5))),
                onPressed: _downloadTemplate,
                icon: const Icon(Icons.file_download, size: 16),
                label: const Text('نزّل القالب'),
              ),
            ]),
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
            Icon(Icons.description, color: _gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('الملف: ${_filename ?? "مجهول"}',
                  style: TextStyle(color: _tp, fontSize: 13),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: _ok,
                  side: BorderSide(color: _ok.withValues(alpha: 0.4))),
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.file_download, size: 14),
              label: const Text('قالب'),
            ),
            const SizedBox(width: 6),
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
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _err.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _err.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Icon(Icons.error_outline, color: _err, size: 16),
                    const SizedBox(width: 6),
                    Text('${_validationErrors.length} مشكلة:',
                        style: TextStyle(
                            color: _err, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Scrollbar(
                      thumbVisibility: true,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _validationErrors.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(_validationErrors[i],
                              style:
                                  TextStyle(color: _err, fontSize: 11)),
                        ),
                      ),
                    ),
                  ),
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
              Text('الأعمدة المُكتشفة:',
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
                                style: TextStyle(
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
                      style: TextStyle(color: _td, fontSize: 11)),
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
                                TextStyle(color: _td, fontSize: 10)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              row.entries
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(' · '),
                              style: TextStyle(
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
                            TextStyle(color: _err, fontSize: 11)),
                    const SizedBox(height: 4),
                    ..._errorLog.take(10).map((e) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _err.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(e,
                              style: TextStyle(
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
          Text('الحقول المطلوبة (يجب أن تكون في الـ headers):',
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
                          style: TextStyle(
                              color: _err,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace')),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
              '💡 الـ headers يمكن أن تكون بالعربية أو الإنجليزية. الـ mapper يتعرّف على: code/الكود، name_ar/الاسم، category/الفئة، إلخ.',
              style: TextStyle(color: _ts, fontSize: 10, height: 1.5)),
        ],
      ),
    );
  }
}

