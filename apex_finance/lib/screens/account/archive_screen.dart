import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_config.dart';
import '../../core/theme.dart';

const _api = apiBase;

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

  Map<String, String> get _h => {'Authorization': 'Bearer ${widget.token ?? ""}'};

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final url = widget.clientId != null
        ? '$_api/clients/${widget.clientId}/archive?page=$_page'
        : '$_api/account/archive?page=$_page';
      final r = await http.get(Uri.parse(url), headers: _h);
      if (r.statusCode == 200) {
        final d = jsonDecode(utf8.decode(r.bodyBytes));
        setState(() { _items = d['data'] ?? []; _total = d['total'] ?? 0; _loading = false; });
      } else { setState(() => _loading = false); }
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(
      title: Text(widget.clientId != null ? 'أرشيف العميل' : 'أرشيف حسابي', style: const TextStyle(color: AC.gold)),
      backgroundColor: const Color(0xFF080F1F)),
    body: _loading ? const Center(child: CircularProgressIndicator(color: AC.gold))
      : _items.isEmpty ? const Center(child: Text('لا توجد ملفات في الأرشيف', style: TextStyle(color: AC.ts)))
      : Column(children: [
          Padding(padding: const EdgeInsets.all(12),
            child: Text('إجمالي: ' + _total.toString() + ' ملف', style: const TextStyle(color: AC.ts, fontSize: 12))),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final item = _items[i];
              final days = item['days_remaining'] ?? 0;
              final urgent = (days is int) && days <= 7;
              return Container(
                margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: urgent ? AC.warn.withOpacity(0.5) : AC.bdr)),
                child: Row(children: [
                  Icon(_fileIcon(item['file_name'] ?? ''), color: AC.gold, size: 28),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item['file_name'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('المصدر: ' + (item['source_type'] ?? '').toString(), style: const TextStyle(color: AC.ts, fontSize: 11)),
                    Text('متبقي: ' + days.toString() + ' يوم',
                      style: TextStyle(color: urgent ? AC.warn : AC.ts, fontSize: 11, fontWeight: urgent ? FontWeight.bold : FontWeight.normal)),
                  ])),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: AC.ts),
                    color: AC.navy3,
                    onSelected: (v) { if (v == 'delete') _deleteItem(item['id']); },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'attach', child: Text('إرفاق في عملية', style: TextStyle(color: AC.tp))),
                      PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: AC.err))),
                    ]),
                ]));
            })),
          Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(icon: const Icon(Icons.chevron_right, color: AC.ts),
              onPressed: _page > 1 ? () { setState(() => _page--); _load(); } : null),
            Text('صفحة ' + _page.toString(), style: const TextStyle(color: AC.ts)),
            IconButton(icon: const Icon(Icons.chevron_left, color: AC.ts),
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
    try {
      final r = await http.delete(Uri.parse('$_api/archive/items/$id'), headers: _h);
      if (r.statusCode == 200) { _load(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحذف'))); }
    } catch (_) {}
  }
}
