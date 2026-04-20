/// AttachmentsPanel — مكوّن قابل لإعادة الاستخدام لعرض + رفع مرفقات
/// أي كيان (Vendor, JE, PO, PI, Payment, ...).
///
/// الاستخدام:
///   AttachmentsPanel(
///     parentType: 'vendors',
///     parentId: vendor['id'],
///   )
///
/// يدعم:
///   • رفع ملف كـ data: URI (للملفات الصغيرة <2MB)
///   • قائمة المرفقات مع حجم + نوع + تاريخ
///   • حذف (مع فحص is_locked)
///   • تنزيل (فتح data URI أو URL)
library;

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';

import '../api/pilot_client.dart';
import '../session.dart';

const _gold = Color(0xFFD4AF37);
const _navy2 = Color(0xFF132339);
const _navy3 = Color(0xFF1D3150);
const _bdr = Color(0x33FFFFFF);
const _tp = Color(0xFFFFFFFF);
const _ts = Color(0xFFBCC5D3);
const _td = Color(0xFF6B7A90);
const _ok = Color(0xFF10B981);
const _err = Color(0xFFEF4444);
const _warn = Color(0xFFF59E0B);

const _kKinds = <String, String>{
  'invoice': 'فاتورة',
  'receipt': 'إيصال',
  'delivery_note': 'بوليصة تسليم',
  'contract': 'عقد',
  'cr_document': 'سجل تجاري',
  'vat_cert': 'شهادة ضريبية',
  'bank_letter': 'خطاب بنكي',
  'purchase_order': 'أمر شراء',
  'other': 'أخرى',
};

class AttachmentsPanel extends StatefulWidget {
  final String parentType;
  final String parentId;
  final String? title;
  final bool readOnly;

  const AttachmentsPanel({
    super.key,
    required this.parentType,
    required this.parentId,
    this.title,
    this.readOnly = false,
  });

  @override
  State<AttachmentsPanel> createState() => _AttachmentsPanelState();
}

class _AttachmentsPanelState extends State<AttachmentsPanel> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await pilotClient.listAttachments(
        widget.parentType, widget.parentId);
    if (!mounted) return;
    setState(() {
      _items = r.success && r.data is List
          ? List<Map<String, dynamic>>.from(r.data)
          : [];
      _loading = false;
    });
  }

  Future<void> _pickAndUpload() async {
    final input = html.FileUploadInputElement()
      ..accept = '.pdf,.png,.jpg,.jpeg,.webp';
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;
    final file = files.first;

    // Size guard — 2MB max for data URI
    if (!mounted) return;
    if (file.size > 2 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _err,
          content: Text('الملف كبير جداً (>2MB). استخدم S3 للملفات الكبيرة.')));
      return;
    }

    // Read as data URI
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoad.first;
    final dataUri = reader.result as String;

    // Kind picker dialog
    String kind = 'other';
    String description = '';
    final kindCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _navy2,
            title: const Text('تفاصيل المرفق',
                style: TextStyle(color: _tp)),
            content: SizedBox(
              width: 400,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('الملف: ${file.name}',
                    style: const TextStyle(color: _ts, fontSize: 12)),
                Text('الحجم: ${(file.size / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(color: _td, fontSize: 11)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: _navy3,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _bdr)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: kind,
                      isExpanded: true,
                      dropdownColor: _navy2,
                      style: const TextStyle(color: _tp, fontSize: 12),
                      items: _kKinds.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setSt(() => kind = v ?? 'other'),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: _tp, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'وصف (اختياري)',
                    hintStyle: const TextStyle(color: _td),
                    filled: true,
                    fillColor: _navy3,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _bdr)),
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء', style: TextStyle(color: _ts))),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: Colors.black),
                onPressed: () {
                  description = descCtrl.text;
                  Navigator.pop(ctx, true);
                },
                child: const Text('رفع'),
              ),
            ],
          ),
        ),
      ),
    );
    kindCtrl.dispose();
    descCtrl.dispose();
    if (ok != true) return;

    // رفع للـ backend
    if (!PilotSession.hasTenant) return;
    if (!mounted) return;

    final r = await pilotClient.createAttachment({
      'tenant_id': PilotSession.tenantId,
      'parent_type': widget.parentType,
      'parent_id': widget.parentId,
      'kind': kind,
      'filename': file.name,
      'content_type': file.type,
      'size_bytes': file.size,
      if (description.isNotEmpty) 'description': description,
      'storage_url': dataUri,
    });
    if (!mounted) return;
    if (r.success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: _ok, content: Text('تم رفع المرفق ✓')));
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _err, content: Text(r.error ?? 'فشل الرفع')));
    }
  }

  void _downloadAttachment(Map<String, dynamic> att) {
    final url = att['storage_url']?.toString() ?? '';
    if (url.isEmpty) return;
    // إذا data URI — ننشئ blob وتحميل
    if (url.startsWith('data:')) {
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', att['filename'] ?? 'file')
        ..style.display = 'none';
      html.document.body!.append(anchor);
      anchor.click();
      anchor.remove();
    } else {
      // URL خارجي — فتح في tab جديد
      html.window.open(url, '_blank');
    }
  }

  Future<void> _deleteAttachment(Map<String, dynamic> att) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: const Text('حذف المرفق', style: TextStyle(color: _tp)),
          content: Text('هل تريد حذف "${att['filename']}"؟',
              style: const TextStyle(color: _ts)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء', style: TextStyle(color: _ts))),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _err, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final r = await pilotClient.deleteAttachment(att['id']);
    if (!mounted) return;
    if (r.success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: _err, content: Text(r.error ?? 'فشل الحذف')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.attach_file, color: _gold, size: 16),
            const SizedBox(width: 6),
            Text(widget.title ?? 'المرفقات',
                style: const TextStyle(
                    color: _tp, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            if (_items.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: Text('${_items.length}',
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
            const Spacer(),
            if (!widget.readOnly)
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: _gold,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                onPressed: _pickAndUpload,
                icon: const Icon(Icons.upload_file, size: 14),
                label: const Text('رفع', style: TextStyle(fontSize: 11)),
              ),
          ]),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _gold))),
            )
          else if (_items.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: _navy3.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _bdr.withAlpha(100))),
              child: const Text('لا توجد مرفقات حتى الآن',
                  style: TextStyle(color: _td, fontSize: 11),
                  textAlign: TextAlign.center),
            )
          else
            Column(children: _items.map(_attachmentTile).toList()),
        ],
      ),
    );
  }

  Widget _attachmentTile(Map<String, dynamic> att) {
    final locked = att['is_locked'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: locked ? _warn : _bdr),
      ),
      child: Row(children: [
        Icon(
          _iconForKind(att['kind']),
          color: _gold,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                      att['filename'] ?? '—',
                      style: const TextStyle(
                          color: _tp,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis),
                ),
                if (locked)
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.lock, color: _warn, size: 12),
                  ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(3)),
                  child: Text(_kKinds[att['kind']] ?? att['kind'] ?? '',
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 6),
                Text(_sizeStr(att['size_bytes']),
                    style: const TextStyle(color: _td, fontSize: 10)),
                const SizedBox(width: 6),
                Text(
                    (att['uploaded_at'] ?? '').toString().substring(
                        0, (att['uploaded_at'] ?? '').toString().length.clamp(0, 10)),
                    style: const TextStyle(color: _td, fontSize: 10)),
              ]),
              if ((att['description'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(att['description'],
                    style: const TextStyle(color: _ts, fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'تنزيل',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.download, color: _gold, size: 16),
          onPressed: () => _downloadAttachment(att),
        ),
        if (!widget.readOnly && !locked) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'حذف',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.delete, color: _err, size: 16),
            onPressed: () => _deleteAttachment(att),
          ),
        ],
      ]),
    );
  }

  IconData _iconForKind(String? kind) {
    switch (kind) {
      case 'invoice':
        return Icons.receipt;
      case 'receipt':
        return Icons.receipt_long;
      case 'delivery_note':
        return Icons.local_shipping;
      case 'contract':
        return Icons.description;
      case 'cr_document':
        return Icons.business;
      case 'vat_cert':
        return Icons.verified;
      case 'bank_letter':
        return Icons.account_balance;
      case 'purchase_order':
        return Icons.shopping_cart;
    }
    return Icons.insert_drive_file;
  }

  String _sizeStr(dynamic bytes) {
    if (bytes == null) return '—';
    final n = bytes is num ? bytes.toDouble() : double.tryParse('$bytes') ?? 0;
    if (n < 1024) return '${n.toInt()} B';
    if (n < 1024 * 1024) return '${(n / 1024).toStringAsFixed(1)} KB';
    return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ignore: unused_element
  String _base64FromDataUri(String dataUri) {
    final idx = dataUri.indexOf(',');
    return idx > 0 ? dataUri.substring(idx + 1) : '';
  }

  // ignore: unused_element
  List<int> _decodeBase64(String b64) => base64.decode(b64);
}
