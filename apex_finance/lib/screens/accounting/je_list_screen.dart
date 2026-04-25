/// APEX — Journal Entries List (canonical, ApexListShell-based)
/// /accounting/je-list — replaces the legacy /compliance/journal-entries.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class JeListScreen extends StatefulWidget {
  const JeListScreen({super.key});
  @override
  State<JeListScreen> createState() => _JeListScreenState();
}

class _JeListScreenState extends State<JeListScreen> {
  List<Map<String, dynamic>> _all = [];
  String _filter = 'all';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entityId = S.savedEntityId;
    if (entityId == null) {
      setState(() => _error = 'لا يوجد كيان نشط');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotListJournalEntries(entityId, limit: 200);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _all = (res.data as List).cast<Map<String, dynamic>>();
      } else {
        _error = res.error;
      }
    });
  }

  List<Map<String, dynamic>> get _filtered {
    return switch (_filter) {
      'draft' => _all.where((j) => j['status'] == 'draft').toList(),
      'posted' => _all.where((j) => j['status'] == 'posted').toList(),
      'reversed' => _all.where((j) => j['reversed_by_je_id'] != null).toList(),
      _ => _all,
    };
  }

  int _countWhere(bool Function(Map) test) => _all.where(test).length;

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'القيود اليومية',
      subtitle: '${_all.length} قيد',
      primaryCta: ApexCta(
        label: 'قيد جديد',
        icon: Icons.add,
        onPressed: () => context.go('/compliance/journal-entry-builder'),
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل',
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _all.length),
        ApexFilterChip(
            label: 'مرحّل',
            selected: _filter == 'posted',
            onTap: () => setState(() => _filter = 'posted'),
            icon: Icons.verified,
            count: _countWhere((j) => j['status'] == 'posted')),
        ApexFilterChip(
            label: 'مسودة',
            selected: _filter == 'draft',
            onTap: () => setState(() => _filter = 'draft'),
            icon: Icons.edit_note,
            count: _countWhere((j) => j['status'] == 'draft')),
        ApexFilterChip(
            label: 'معكوس',
            selected: _filter == 'reversed',
            onTap: () => setState(() => _filter = 'reversed'),
            icon: Icons.undo,
            count: _countWhere((j) => j['reversed_by_je_id'] != null)),
      ],
      items: _filtered,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      emptyState: ApexEmptyState(
        icon: Icons.book_outlined,
        title: 'لا توجد قيود يومية',
        description: 'القيود تُنشأ تلقائياً من الفواتير، أو يمكنك إضافة قيد يدوي',
        primaryLabel: 'قيد جديد',
        primaryIcon: Icons.add,
        onPrimary: () => context.go('/compliance/journal-entry-builder'),
      ),
      itemBuilder: (ctx, j) {
        final isPosted = j['status'] == 'posted';
        final isReversed = j['reversed_by_je_id'] != null;
        final color = isReversed
            ? AC.ts
            : isPosted
                ? AC.ok
                : AC.warn;
        return InkWell(
          onTap: () {
            final id = j['id'] as String?;
            if (id != null) context.go('/compliance/journal-entry/$id');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Icon(
                  isReversed
                      ? Icons.undo
                      : isPosted
                          ? Icons.verified
                          : Icons.edit_note,
                  color: color,
                  size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${j['je_number']}',
                      style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 12.5, fontWeight: FontWeight.w700)),
                  Text('${j['memo_ar'] ?? j['memo_en'] ?? ''}',
                      style: TextStyle(color: AC.ts, fontSize: 11),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${j['je_date']}',
                      style: TextStyle(color: AC.ts, fontSize: 10.5)),
                  Text('${j['total_debit']} SAR',
                      style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
              Icon(Icons.chevron_left, color: AC.ts, size: 16),
            ]),
          ),
        );
      },
    );
  }
}
