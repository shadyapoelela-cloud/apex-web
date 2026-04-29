/// APEX — Proactive Suggestions Inbox
/// /admin/suggestions — see + apply / dismiss platform suggestions.
///
/// Wired to the Suggestions backend (Wave 1G Phase EE):
///   GET  /api/v1/suggestions[?status=proposed]
///   POST /api/v1/suggestions/{id}/apply
///   POST /api/v1/suggestions/{id}/dismiss
///
/// "Apply" navigates to the action_target route (e.g.
/// /admin/workflow/templates) so the admin can install the suggested
/// template; the suggestion gets marked applied automatically.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

class SuggestionsInboxScreen extends StatefulWidget {
  const SuggestionsInboxScreen({super.key});
  @override
  State<SuggestionsInboxScreen> createState() => _SuggestionsInboxScreenState();
}

class _SuggestionsInboxScreenState extends State<SuggestionsInboxScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  String _filter = 'proposed';

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
    final res = await ApiService.suggestionsList(
      tenantId: S.tenantId,
      status: _filter == 'all' ? null : _filter,
    );
    if (!mounted) return;
    if (res.success) {
      final raw = (res.data is Map ? res.data['suggestions'] : null) ?? const [];
      _items = (raw as List).cast<Map<String, dynamic>>();
    } else {
      _error = res.error ?? 'فشل';
    }
    setState(() => _loading = false);
  }

  Future<void> _apply(Map<String, dynamic> s) async {
    final action = s['action']?.toString() ?? 'info';
    final target = s['action_target']?.toString();

    // Mark as applied immediately so the inbox updates.
    await ApiService.suggestionsApply(s['id'] as String);
    if (!mounted) return;

    if (action == 'install_template' && target != null) {
      // Navigate to the templates browser; admin clicks "تثبيت" there.
      GoRouter.of(context).go('/admin/workflow/templates');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.cyan,
          content: Text('🎯 افتح قالب: $target'),
        ),
      );
    } else if ((action == 'review' || action == 'configure') && target != null) {
      GoRouter.of(context).go(target);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.ok, content: const Text('✅ تم وضع علامة "مُطبَّق"')),
      );
      _load();
    }
  }

  Future<void> _dismiss(Map<String, dynamic> s) async {
    final res = await ApiService.suggestionsDismiss(s['id'] as String);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.warn, content: const Text('تم التجاهل')),
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'اقتراحات المنصة',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AC.navy2,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final f in const [
                  ['proposed', 'مقترحة'],
                  ['applied', 'مُطبَّقة'],
                  ['dismissed', 'مُتجاهَلة'],
                  ['all', 'الكل'],
                ])
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(f[1]),
                      selected: _filter == f[0],
                      onSelected: (_) {
                        setState(() => _filter = f[0]);
                        _load();
                      },
                      backgroundColor: AC.navy3,
                      selectedColor: AC.gold,
                      labelStyle: TextStyle(
                        color: _filter == f[0] ? AC.btnFg : AC.tp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AC.gold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: AC.err)),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.tips_and_updates_outlined, color: AC.ts, size: 64),
          const SizedBox(height: 12),
          Text(
            _filter == 'proposed'
                ? 'لا توجد اقتراحات حالياً 🎉'
                : 'لا توجد عناصر في هذا الفلتر',
            style: TextStyle(color: AC.tp, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'المنصة تراقب نشاطك وتقترح أتمتة عند اكتشاف الأنماط.',
            style: TextStyle(color: AC.ts, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ]),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _items.length,
        itemBuilder: (ctx, i) => _card(_items[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final severity = s['severity']?.toString() ?? 'info';
    final status = s['status']?.toString() ?? 'proposed';
    final action = s['action']?.toString() ?? 'info';
    final target = s['action_target']?.toString();
    final detected = (s['detected_count'] ?? 1) as int;

    final sevColor = switch (severity) {
      'high' => AC.err,
      'warning' => AC.warn,
      _ => AC.cyan,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: sevColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: sevColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconFor(action), color: sevColor, size: 18),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  s['title_ar']?.toString() ?? '',
                  style: TextStyle(
                    color: AC.tp,
                    fontWeight: FontWeight.bold,
                    fontSize: AppFontSize.md,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  _miniChip(severity, sevColor),
                  _miniChip('detected: $detected', AC.ts),
                  if (status != 'proposed')
                    _miniChip(
                      status,
                      status == 'applied' ? AC.ok : AC.warn,
                    ),
                ]),
              ]),
            ),
          ]),
          if ((s['body_ar'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              s['body_ar'].toString(),
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm, height: 1.5),
            ),
          ],
          if (target != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AC.navy3,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                'الإجراء: $action → $target',
                style: TextStyle(
                  color: AC.cyan,
                  fontSize: 10.5,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
          if (status == 'proposed') ...[
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _apply(s),
                  icon: Icon(_iconFor(action), size: 16),
                  label: Text(_actionLabel(action)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AC.gold,
                    foregroundColor: AC.btnFg,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _dismiss(s),
                icon: const Icon(Icons.close, size: 14),
                label: const Text('تجاهل'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AC.ts),
                  foregroundColor: AC.ts,
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'install_template':
        return 'تثبيت القالب';
      case 'review':
        return 'مراجعة';
      case 'configure':
        return 'إعداد';
      default:
        return 'فهمت';
    }
  }

  IconData _iconFor(String action) {
    switch (action) {
      case 'install_template':
        return Icons.auto_awesome;
      case 'review':
        return Icons.fact_check_outlined;
      case 'configure':
        return Icons.settings;
      default:
        return Icons.lightbulb_outline;
    }
  }

  Widget _miniChip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(color: c, fontSize: 10),
      ),
    );
  }
}
