/// APEX — AI Suggestions Inbox
/// ═══════════════════════════════════════════════════════════
/// Admin-facing list of AiSuggestion rows. Filters by status chip
/// (needs_approval / approved / rejected / all). Each row shows:
///   • source + action_type + target_id
///   • confidence % and destructive flag
///   • a preview of the proposed `after_json`
///   • approve / reject actions (only when needs_approval)
///
/// Calls GET /api/v1/ai/suggestions on mount + after every filter change.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class AiSuggestionsInboxScreen extends StatefulWidget {
  const AiSuggestionsInboxScreen({super.key});

  @override
  State<AiSuggestionsInboxScreen> createState() => _AiSuggestionsInboxScreenState();
}

class _AiSuggestionsInboxScreenState extends State<AiSuggestionsInboxScreen> {
  String _filter = 'needs_approval';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  static const _filters = <(String, String)>[
    ('needs_approval', 'بانتظار المراجعة'),
    ('approved', 'المعتمدة'),
    ('rejected', 'المرفوضة'),
    ('auto_applied', 'تم تطبيقها تلقائياً'),
    ('', 'الكل'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.aiListSuggestions(
      status: _filter.isEmpty ? null : _filter,
      limit: 100,
    );
    if (!mounted) return;
    if (res.success && res.data != null) {
      final list = (res.data['data'] as List?) ?? [];
      setState(() {
        _rows = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } else {
      setState(() {
        _error = res.error ?? 'تعذّر تحميل القائمة';
        _loading = false;
      });
    }
  }

  Future<void> _approve(String id) async {
    final res = await ApiService.aiApproveSuggestion(id);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الاعتماد')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'فشل الاعتماد')),
      );
    }
  }

  Future<void> _reject(String id) async {
    final reason = await _promptRejectionReason(context);
    if (reason == null) return;
    final res = await ApiService.aiRejectSuggestion(id, reason: reason);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الرفض')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'فشل الرفض')),
      );
    }
  }

  Future<String?> _promptRejectionReason(BuildContext ctx) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: ctx,
      builder: (c) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('سبب الرفض', style: TextStyle(fontFamily: 'Tajawal')),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'اختياري — يظهر في سجل التدقيق',
              hintStyle: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(c).pop(null),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(c).pop(controller.text.trim()),
              child: const Text('رفض', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text(
            'صندوق اقتراحات الذكاء الاصطناعي',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: Column(
          children: [
            _filterBar(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AC.navy2,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) {
            final selected = _filter == f.$1;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                selected: selected,
                selectedColor: AC.gold.withValues(alpha: 0.25),
                backgroundColor: AC.navy3,
                side: BorderSide(
                  color: selected ? AC.gold : AC.gold.withValues(alpha: 0.18),
                ),
                label: Text(
                  f.$2,
                  style: TextStyle(
                    color: AC.tp,
                    fontFamily: 'Tajawal',
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onSelected: (_) {
                  setState(() => _filter = f.$1);
                  _load();
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: AC.err, fontFamily: 'Tajawal'),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, color: AC.ts, size: 56),
            const SizedBox(height: 8),
            Text(
              'لا توجد اقتراحات',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) => _SuggestionCard(
        row: _rows[i],
        onApprove: () => _approve(_rows[i]['id'] as String),
        onReject: () => _reject(_rows[i]['id'] as String),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _SuggestionCard({
    required this.row,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = (row['status'] ?? '') as String;
    final confidence = (row['confidence'] ?? 0) as num;
    final destructive = (row['destructive'] ?? 0) == 1;
    final action = (row['action_type'] ?? '') as String;
    final source = (row['source'] ?? '') as String;
    final targetId = (row['target_id'] ?? '') as String?;
    final after = row['after_json'];
    final reasoning = (row['reasoning'] ?? '') as String?;
    final canAct = status == 'needs_approval';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _badge(_actionLabel(action), AC.gold),
              const SizedBox(width: 8),
              _badge(source, AC.ts),
              const Spacer(),
              if (destructive) _badge('تدميري', AC.err),
              const SizedBox(width: 6),
              _badge(_statusLabel(status), _statusColor(status)),
            ],
          ),
          const SizedBox(height: 10),
          if (targetId != null && targetId.isNotEmpty)
            Text(
              'الهدف: $targetId',
              style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
            ),
          if (reasoning != null && reasoning.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                reasoning,
                style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
              ),
            ),
          const SizedBox(height: 8),
          _afterPreview(after),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'الثقة: ${(confidence / 10).toStringAsFixed(1)}%',
                style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12),
              ),
              const Spacer(),
              if (canAct) ...[
                OutlinedButton.icon(
                  onPressed: onReject,
                  icon: Icon(Icons.close, size: 16, color: AC.err),
                  label: Text('رفض', style: TextStyle(color: AC.err, fontFamily: 'Tajawal')),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AC.err.withValues(alpha: 0.45)),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('اعتماد', style: TextStyle(fontFamily: 'Tajawal')),
                  style: FilledButton.styleFrom(
                    backgroundColor: AC.ok,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _afterPreview(dynamic after) {
    if (after is! Map) return const SizedBox.shrink();
    final entries = after.entries.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            children: [
              Text(
                '${e.key}:',
                style: TextStyle(
                  color: AC.ts,
                  fontFamily: 'Tajawal',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${e.value}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AC.tp,
                    fontFamily: 'Tajawal',
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontFamily: 'Tajawal',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'approved':
      case 'auto_applied':
        return const Color(0xFF10B981);
      case 'rejected':
        return const Color(0xFFEF4444);
      case 'needs_approval':
      default:
        return const Color(0xFFF59E0B);
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'approved':
        return 'معتمد';
      case 'auto_applied':
        return 'تلقائي';
      case 'rejected':
        return 'مرفوض';
      case 'needs_approval':
        return 'بانتظار';
      default:
        return s;
    }
  }

  static String _actionLabel(String a) {
    switch (a) {
      case 'create_invoice':
        return 'مسودة فاتورة';
      case 'send_reminder':
        return 'تذكير دفع';
      case 'categorize_txn':
        return 'تصنيف حركة';
      default:
        return a;
    }
  }
}
