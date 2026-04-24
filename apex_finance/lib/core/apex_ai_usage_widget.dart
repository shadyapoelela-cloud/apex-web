/// APEX Platform — AI usage widget
/// ═══════════════════════════════════════════════════════════
/// Small card that shows the tenant's Claude consumption for the
/// current billing month: input/output tokens, estimated USD cost,
/// and call count. Meant to be dropped into the admin dashboard or
/// the billing/subscription screen.
///
/// Backed by GET /api/v1/ai/usage. Pulls on mount, refreshable via
/// a tap on the refresh icon.
library;

import 'package:flutter/material.dart';

import '../api_service.dart';
import 'theme.dart';

class ApexAiUsageCard extends StatefulWidget {
  /// Optional — if omitted, the server resolves the tenant from context.
  final String? tenantId;

  /// Called when user taps the card (e.g., to navigate to a detail page).
  final VoidCallback? onTap;

  const ApexAiUsageCard({super.key, this.tenantId, this.onTap});

  @override
  State<ApexAiUsageCard> createState() => _ApexAiUsageCardState();
}

class _ApexAiUsageCardState extends State<ApexAiUsageCard> {
  bool _loading = true;
  String? _error;
  int _inputTokens = 0;
  int _outputTokens = 0;
  double _costUsd = 0.0;
  int _calls = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.aiUsage(tenantId: widget.tenantId);
    if (!mounted) return;
    if (res.success && res.data != null && res.data['data'] != null) {
      final d = res.data['data'] as Map<String, dynamic>;
      setState(() {
        _inputTokens = (d['input_tokens'] ?? 0) as int;
        _outputTokens = (d['output_tokens'] ?? 0) as int;
        _costUsd = ((d['cost_usd'] ?? 0) as num).toDouble();
        _calls = (d['calls'] ?? 0) as int;
        _loading = false;
      });
    } else {
      setState(() {
        _error = res.error ?? 'تعذّر جلب الاستهلاك';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AC.gold.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 14),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(
                    color: AC.err,
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                  ),
                )
              else
                _metrics(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Icon(Icons.auto_awesome, color: AC.gold, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'استهلاك الذكاء الاصطناعي',
            style: TextStyle(
              color: AC.tp,
              fontFamily: 'Tajawal',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          'الشهر الحالي',
          style: TextStyle(
            color: AC.ts,
            fontFamily: 'Tajawal',
            fontSize: 10.5,
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: Icon(Icons.refresh, color: AC.ts, size: 18),
          tooltip: 'تحديث',
          onPressed: _loading ? null : _refresh,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        ),
      ],
    );
  }

  Widget _metrics() {
    return Column(
      children: [
        Row(
          children: [
            _metric(
              label: 'التكلفة',
              value: '\$${_costUsd.toStringAsFixed(_costUsd >= 10 ? 2 : 4)}',
              emphasis: true,
            ),
            const SizedBox(width: 12),
            _metric(label: 'عدد الاستعلامات', value: '$_calls'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _metric(label: 'توكنز إدخال', value: _fmt(_inputTokens)),
            const SizedBox(width: 12),
            _metric(label: 'توكنز إخراج', value: _fmt(_outputTokens)),
          ],
        ),
      ],
    );
  }

  Widget _metric({required String label, required String value, bool emphasis = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AC.ts,
                fontFamily: 'Tajawal',
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: emphasis ? AC.gold : AC.tp,
                fontFamily: 'Tajawal',
                fontSize: emphasis ? 18 : 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int n) {
    if (n >= 1_000_000) return '${(n / 1_000_000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
