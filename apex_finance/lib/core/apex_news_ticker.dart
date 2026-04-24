/// APEX — Regulatory news ticker
/// Bloomberg-style horizontal scroller for ZATCA/SAMA/FTA/ETA
/// headlines. Drop into any Scaffold's bottomNavigationBar slot or
/// as a top-of-screen banner.
library;

import 'dart:async';
import 'package:flutter/material.dart';

import '../api_service.dart';
import 'theme.dart';

class ApexNewsTicker extends StatefulWidget {
  final String? jurisdiction;   // null = all
  const ApexNewsTicker({super.key, this.jurisdiction});

  @override
  State<ApexNewsTicker> createState() => _ApexNewsTickerState();
}

class _ApexNewsTickerState extends State<ApexNewsTicker> {
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _items = [];
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  Future<void> _load() async {
    final res = await ApiService.aiRegulatoryNews(jurisdiction: widget.jurisdiction, limit: 20);
    if (!mounted) return;
    final list = ((res.data?['data'] as List?) ?? []).cast<Map<String, dynamic>>();
    setState(() => _items = list);
  }

  void _tick() {
    if (!_scroll.hasClients || _items.isEmpty) return;
    final next = _scroll.offset + 280;
    if (next >= _scroll.position.maxScrollExtent) {
      _scroll.jumpTo(0);
    } else {
      _scroll.animateTo(next, duration: const Duration(milliseconds: 700), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border(top: BorderSide(color: AC.gold.withValues(alpha: 0.2))),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.15),
                border: Border(left: BorderSide(color: AC.gold.withValues(alpha: 0.3))),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign_outlined, color: AC.gold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'تحديثات تنظيمية',
                    style: TextStyle(
                      color: AC.gold,
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                itemCount: _items.length,
                separatorBuilder: (_, __) => Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  color: AC.gold.withValues(alpha: 0.15),
                ),
                itemBuilder: (_, i) => _NewsChip(item: _items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsChip extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NewsChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final title = (item['title_ar'] ?? '') as String;
    final sev = (item['severity'] ?? 'info') as String;
    final color = sev == 'error'
        ? AC.err
        : sev == 'warning' ? AC.gold : AC.ok;
    final date = (item['effective_date'] ?? '') as String;
    final authority = (item['authority'] ?? '') as String;

    return InkWell(
      onTap: () => _showDetails(context, item),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                authority,
                style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12),
            ),
            const SizedBox(width: 8),
            Text(
              date,
              style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext ctx, Map<String, dynamic> item) {
    showDialog(context: ctx, builder: (c) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(item['title_ar'] ?? '', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item['body_ar'] ?? '', style: const TextStyle(fontFamily: 'Tajawal', height: 1.5)),
            const SizedBox(height: 12),
            Text('التأثير على دفاترك:', style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
            Text(item['impact_ar'] ?? '', style: const TextStyle(fontFamily: 'Tajawal', height: 1.5)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Tajawal')))],
      ),
    ));
  }
}
