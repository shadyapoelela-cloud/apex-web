import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

class ArchiveScreen extends StatefulWidget {
  final String? clientId;
  final String? token;
  const ArchiveScreen({super.key, this.clientId, this.token});
  @override State<ArchiveScreen> createState() => _ArchiveS();
}

class _ArchiveS extends State<ArchiveScreen> {
  List<dynamic> _items = [];
  bool _loading = true;
  int _page = 1, _total = 0;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = widget.clientId != null
        ? await ApiService.getClientArchive(widget.clientId!, page: _page)
        : await ApiService.getUserArchive(page: _page);
      if (r.success) {
        setState(() { _items = r.data['data'] ?? []; _total = r.data['total'] ?? 0; _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: Text(widget.clientId != null ? 'أرشيف العميل' : 'أرشيف حسابي', style: TextStyle(color: AC.gold)),
      backgroundColor: AC.navy2),
    body: _loading ? Center(child: CircularProgressIndicator(color: AC.gold))
      : _items.isEmpty ? Center(child: Text('لا توجد ملفات في الأرشيف', style: TextStyle(color: AC.ts)))
      : Column(children: [
          Padding(padding: EdgeInsets.all(12),
            child: Text('إجمالي: ' + _total.toString() + ' ملف', style: TextStyle(color: AC.ts, fontSize: 12))),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final item = _items[i];
              final days = item['days_remaining'] ?? 0;
              final urgent = (days is int) && days <= 7;
              return Container(
                margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: urgent ? AC.warn.withValues(alpha: 0.5) : AC.bdr)),
                child: Row(children: [
                  Icon(_fileIcon(item['file_name'] ?? ''), color: AC.gold, size: 28),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['file_name'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('المصدر: ' + (item['source_type'] ?? '').toString(), style: TextStyle(color: AC.ts, fontSize: 11)),
                    Text('متبقي: ' + days.toString() + ' يوم',
                      style: TextStyle(color: urgent ? AC.warn : AC.ts, fontSize: 11, fontWeight: urgent ? FontWeight.bold : FontWeight.normal)),
                  ])),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: AC.ts),
                    color: AC.navy3,
                    onSelected: (v) { if (v == 'delete') _deleteItem(item['id']); },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'attach', child: Text('إرفاق في عملية', style: TextStyle(color: AC.tp))),
                      PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: AC.err))),
                    ]),
                ]));
            })),
          Padding(padding: EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ApexIconButton(icon: Icons.chevron_right, color: AC.ts,
              onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null),
            Text('صفحة ' + _page.toString(), style: TextStyle(color: AC.ts)),
            ApexIconButton(icon: Icons.chevron_left, color: AC.ts,
              onPressed: _total > _page * 20 ? () { setState(() => _page++); _load(); } : null),
          ])),
        ]),
  );

  IconData _fileIcon(String name) {
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (name.endsWith('.xlsx') || name.endsWith('.xls')) return Icons.table_chart;
    if (name.endsWith('.csv')) return Icons.grid_on;
    return Icons.insert_drive_file;
  }

  Future<void> _deleteItem(String id) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      backgroundColor: AC.navy2,
      title: Text('حذف الملف', style: TextStyle(color: AC.gold)),
      content: Text('هل تريد حذف هذا الملف نهائياً؟ لا يمكن التراجع عن هذا الإجراء.', style: TextStyle(color: AC.tp)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: TextStyle(color: AC.ts))),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('حذف', style: TextStyle(color: AC.err))),
      ]));
    if (ok != true) return;
    try {
      final r = await ApiService.deleteArchiveItem(id);
      if (r.success) { _load(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم الحذف'), backgroundColor: AC.ok)); }
    } catch (_) {}
  }
}
