/// @deprecated V4 module — kept temporarily because 6 screens still depend on
/// `apex_screen_host.dart` (the only file with external users). The other
/// widgets here are an internally-consistent dead zone (0 external users) but
/// removing them piecemeal would break `apex_launchpad`, `apex_sub_module_shell`,
/// `apex_command_palette`, and `apex_tab_bar` which all import `v4_groups.dart`.
///
/// Migration to V5 is tracked in G-A2.1 — see
/// `APEX_BLUEPRINT/09_GAPS_AND_REWORK_PLAN.md`. Do NOT add new usages.
/// APEX V4 — ZATCA error card + explain popover (Wave 2 PR#5).
///
/// UI side of the Arabic ZATCA error translator (backend PR#4).
/// Renders a canonical two-line Arabic card for any rejection, with a
/// "ما معنى هذا الرمز؟" ("what does this code mean?") link that
/// fetches extended detail from /zatca/errors/explain and shows it
/// in a lightweight popover.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../design_tokens.dart';
import '../theme.dart';

/// A single translated rejection entry — matches the backend
/// TranslatedRejection shape from app/core/zatca_error_translator.py.
class ZatcaRejection {
  final String code;
  final String category;
  final String titleAr;
  final String actionAr;
  final String originalMessage;
  final String severity; // "error" | "warning"

  const ZatcaRejection({
    required this.code,
    required this.category,
    required this.titleAr,
    required this.actionAr,
    required this.originalMessage,
    required this.severity,
  });

  factory ZatcaRejection.fromJson(Map<String, dynamic> j) => ZatcaRejection(
        code: (j['code'] ?? '') as String,
        category: (j['category'] ?? 'unknown') as String,
        titleAr: (j['title_ar'] ?? '') as String,
        actionAr: (j['action_ar'] ?? '') as String,
        originalMessage: (j['original_message'] ?? '') as String,
        severity: (j['severity'] ?? 'error') as String,
      );

  bool get isError => severity == 'error';
}

/// Card that renders one rejection entry. Use inside a scrollable list
/// when displaying the full rejection summary.
class ApexZatcaErrorCard extends StatelessWidget {
  final ZatcaRejection rejection;

  /// Optional callback when the user taps "عرض الرسالة الأصلية".
  final VoidCallback? onViewOriginal;

  const ApexZatcaErrorCard({
    super.key,
    required this.rejection,
    this.onViewOriginal,
  });

  @override
  Widget build(BuildContext context) {
    final color = rejection.isError ? AC.err : AC.warn;
    final icon =
        rejection.isError ? Icons.error_outline : Icons.warning_amber_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(right: BorderSide(color: color, width: 3)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  rejection.titleAr,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.base,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _CodeChip(code: rejection.code),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            rejection.actionAr,
            style: TextStyle(
              color: AC.ts,
              fontSize: AppFontSize.md,
              height: 1.7,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showExplainPopover(context, rejection.code),
                icon: Icon(Icons.help_outline, size: 16, color: AC.gold),
                label: Text(
                  'ما معنى هذا الرمز؟',
                  style: TextStyle(color: AC.gold, fontSize: AppFontSize.sm),
                ),
              ),
              const Spacer(),
              if (onViewOriginal != null)
                TextButton(
                  onPressed: onViewOriginal,
                  child: Text(
                    'الرسالة الأصلية',
                    style: TextStyle(
                      color: AC.ts,
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CodeChip extends StatelessWidget {
  final String code;
  const _CodeChip({required this.code});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs + 2,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        child: Text(
          code,
          style: TextStyle(
            color: AC.ts,
            fontSize: AppFontSize.xs,
            fontFamily: 'monospace',
            letterSpacing: 0.3,
          ),
        ),
      );
}

/// Open a centered explain popover that fetches /zatca/errors/explain.
/// Exposed as top-level so rejection lists, JE audit trail views, and
/// any other place surfacing a ZATCA code can link to it uniformly.
Future<void> _showExplainPopover(BuildContext context, String code) {
  return showDialog(
    context: context,
    builder: (_) => _ExplainDialog(code: code),
  );
}

class _ExplainDialog extends StatefulWidget {
  final String code;
  const _ExplainDialog({required this.code});

  @override
  State<_ExplainDialog> createState() => _ExplainDialogState();
}

class _ExplainDialogState extends State<_ExplainDialog> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiService.explainZatcaCode(widget.code);
      if (!mounted) return;
      if (!res.success) {
        setState(() {
          _loading = false;
          _error = res.error ?? 'تعذّر جلب الشرح';
        });
        return;
      }
      setState(() {
        _loading = false;
        _data = (res.data is Map && (res.data as Map)['data'] is Map)
            ? Map<String, dynamic>.from((res.data as Map)['data'] as Map)
            : Map<String, dynamic>.from(res.data as Map);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isKnown = _data?['known'] == true;
    return AlertDialog(
      backgroundColor: AC.navy2,
      title: Row(
        children: [
          _CodeChip(code: widget.code),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'شرح الرمز',
            style: TextStyle(
              color: AC.tp,
              fontSize: AppFontSize.h3,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _fetch)
                : _ExplainContent(data: _data!, isKnown: isKnown),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('إغلاق', style: TextStyle(color: AC.gold)),
        ),
      ],
    );
  }
}

class _ExplainContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isKnown;

  const _ExplainContent({required this.data, required this.isKnown});

  @override
  Widget build(BuildContext context) {
    final title = data['title_ar']?.toString() ?? '';
    final action = data['action_ar']?.toString() ?? '';
    final category = data['category']?.toString() ?? 'unknown';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isKnown)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AC.warn.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AC.warn, size: 16),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'لم نضف ترجمة خاصة لهذا الرمز بعد.',
                    style: TextStyle(
                      color: AC.ts,
                      fontSize: AppFontSize.sm,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Text(
          title,
          style: TextStyle(
            color: AC.tp,
            fontSize: AppFontSize.base,
            fontWeight: FontWeight.w700,
            height: 1.6,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          action,
          style: TextStyle(
            color: AC.ts,
            fontSize: AppFontSize.md,
            height: 1.8,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Icon(Icons.bookmark_border, color: AC.ts, size: 14),
            const SizedBox(width: 4),
            Text(
              'الفئة: $category',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AC.err, size: 36),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'تعذّر جلب الشرح',
            style: TextStyle(
              color: AC.tp,
              fontSize: AppFontSize.base,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
}
