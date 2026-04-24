/// APEX — AI Console
/// ═══════════════════════════════════════════════════════════
/// Admin dashboard for everything AI: token consumption, recent
/// suggestions grouped by status, and quick links into approvals +
/// the Ask panel. One-stop surface so a controller/auditor can see
/// what the Copilot has been doing at a glance.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_ai_usage_widget.dart';
import '../../core/apex_ask_panel.dart';
import '../../core/theme.dart';

class AiConsoleScreen extends StatefulWidget {
  const AiConsoleScreen({super.key});

  @override
  State<AiConsoleScreen> createState() => _AiConsoleScreenState();
}

class _AiConsoleScreenState extends State<AiConsoleScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _recent = [];
  Map<String, int> _counts = {
    'needs_approval': 0,
    'approved': 0,
    'rejected': 0,
    'auto_applied': 0,
    'executed': 0,
    'failed': 0,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.aiListSuggestions(limit: 200);
    if (!mounted) return;
    if (res.success && res.data != null) {
      final list = ((res.data['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      final counts = {
        'needs_approval': 0,
        'approved': 0,
        'rejected': 0,
        'auto_applied': 0,
        'executed': 0,
        'failed': 0,
      };
      for (final r in list) {
        final s = (r['status'] ?? '') as String;
        counts[s] = (counts[s] ?? 0) + 1;
      }
      setState(() {
        _recent = list.take(10).toList();
        _counts = counts;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
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
            'مركز الذكاء الاصطناعي',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'اسأل أبكس',
              onPressed: () => openApexAskPanel(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const ApexAiUsageCard(),
              const SizedBox(height: 12),
              _statsRow(),
              const SizedBox(height: 18),
              _sectionHeader('أحدث نشاط الذكاء الاصطناعي', '/admin/ai-suggestions'),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_recent.isEmpty)
                _emptyActivity()
              else
                ..._recent.map(_activityTile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statsRow() {
    final tiles = <Widget>[
      _statTile('بانتظار', _counts['needs_approval'] ?? 0, const Color(0xFFF59E0B)),
      _statTile('معتمد', _counts['approved'] ?? 0, AC.ok),
      _statTile('نُفّذ', _counts['executed'] ?? 0, AC.gold),
      _statTile('مرفوض', _counts['rejected'] ?? 0, AC.err),
    ];
    return Row(
      children: tiles.map((t) => Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: t,
      ))).toList(),
    );
  }

  Widget _statTile(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontFamily: 'Tajawal',
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String targetPath) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AC.tp,
              fontFamily: 'Tajawal',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => GoRouter.of(context).go(targetPath),
          icon: Icon(Icons.chevron_left, color: AC.gold, size: 18),
          label: Text(
            'عرض الكل',
            style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _activityTile(Map<String, dynamic> row) {
    final action = (row['action_type'] ?? '') as String;
    final status = (row['status'] ?? '') as String;
    final created = (row['created_at'] ?? '') as String;
    final reasoning = (row['reasoning'] ?? '') as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _statusColor(status).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(_actionIcon(action), color: _statusColor(status), size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_actionLabel(action)} — ${_statusLabel(status)}',
                  style: TextStyle(
                    color: AC.tp,
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (reasoning != null && reasoning.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      reasoning,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AC.ts,
                        fontFamily: 'Tajawal',
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _shortTime(created),
                    style: TextStyle(
                      color: AC.td,
                      fontFamily: 'Tajawal',
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyActivity() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined, color: AC.ts, size: 40),
          const SizedBox(height: 8),
          Text(
            'لم يسجّل الـ Copilot أي اقتراحات بعد',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 13),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'approved':
      case 'auto_applied':
      case 'executed':
        return const Color(0xFF10B981);
      case 'rejected':
      case 'failed':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  static String _statusLabel(String s) => {
        'approved': 'معتمد',
        'auto_applied': 'تلقائي',
        'executed': 'نُفّذ',
        'rejected': 'مرفوض',
        'failed': 'فشل',
        'needs_approval': 'بانتظار',
      }[s] ?? s;

  static String _actionLabel(String a) => {
        'create_invoice': 'مسودة فاتورة',
        'send_reminder': 'تذكير دفع',
        'categorize_txn': 'تصنيف حركة',
      }[a] ?? a;

  static IconData _actionIcon(String a) {
    switch (a) {
      case 'create_invoice':
        return Icons.receipt_long_outlined;
      case 'send_reminder':
        return Icons.campaign_outlined;
      case 'categorize_txn':
        return Icons.label_outline;
      default:
        return Icons.auto_awesome;
    }
  }

  static String _shortTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'الآن';
      if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
      if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
      return 'قبل ${diff.inDays} يوم';
    } catch (_) {
      return iso.split('T').first;
    }
  }
}
