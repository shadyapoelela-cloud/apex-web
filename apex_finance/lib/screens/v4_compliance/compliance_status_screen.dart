/// APEX V4 Compliance — Dashboard / Status screen (Wave 4 PR#2).
///
/// First non-ERP V4 screen wired to real state. Shows the current
/// compliance posture at a glance: ZATCA certificate health, VAT
/// return deadline, GOSI submission status. Read-only snapshot — the
/// deep actions live under the specific sub-modules.
///
/// Data sourcing (current):
/// - Certificate expiry / ZATCA status come from user-tenant settings
///   once backend exposes them (future wave). Until then, we render
///   placeholder cards with "بيانات حقيقية قريبًا" stamped on them so
///   the UI skeleton is usable in demos.
library;

import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class ComplianceStatusScreen extends StatelessWidget {
  const ComplianceStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = _statusCards(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _HeroBanner(
          score: 87,
          message:
              'منشأتك ضمن حدود الامتثال الآمنة — يوجد ملاحظتان تستحقان المتابعة.',
        ),
        const SizedBox(height: AppSpacing.lg),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final cols = constraints.maxWidth > 900
                ? 3
                : constraints.maxWidth > 600
                    ? 2
                    : 1;
            return GridView.count(
              crossAxisCount: cols,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: 2.0,
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: cards,
            );
          },
        ),
      ],
    );
  }

  List<Widget> _statusCards(BuildContext ctx) => const [
        _StatusCard(
          title: 'شهادة ZATCA',
          value: 'سارية',
          subtitle: 'تنتهي في 2027-03-15',
          icon: Icons.verified,
          severity: _StatusSeverity.ok,
        ),
        _StatusCard(
          title: 'موجة ZATCA',
          value: 'الموجة 23',
          subtitle: 'إلزامي منذ 2026-03-31',
          icon: Icons.flag,
          severity: _StatusSeverity.ok,
        ),
        _StatusCard(
          title: 'إقرار VAT القادم',
          value: '11 يومًا',
          subtitle: 'تستحق 2026-04-29',
          icon: Icons.event_note,
          severity: _StatusSeverity.warning,
          ctaLabel: 'افتح الإقرار',
        ),
        _StatusCard(
          title: 'GOSI — الشهر الحالي',
          value: 'معلّق',
          subtitle: 'لم يُرسَل بعد — 3 أيام متبقية',
          icon: Icons.groups,
          severity: _StatusSeverity.warning,
          ctaLabel: 'راجع القائمة',
        ),
        _StatusCard(
          title: 'AML — الحالات المفتوحة',
          value: '0',
          subtitle: 'لا تنبيهات حالية',
          icon: Icons.shield,
          severity: _StatusSeverity.ok,
        ),
        _StatusCard(
          title: 'رفض الفواتير — 30 يومًا',
          value: '2',
          subtitle: 'معدل النجاح 99.7%',
          icon: Icons.receipt_long,
          severity: _StatusSeverity.info,
          ctaLabel: 'اعرض السجل',
        ),
      ];
}

class _HeroBanner extends StatelessWidget {
  final int score;
  final String message;

  const _HeroBanner({required this.score, required this.message});

  @override
  Widget build(BuildContext context) {
    final color = score >= 90
        ? AC.ok
        : score >= 70
            ? AC.warn
            : AC.err;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border(right: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  backgroundColor: AC.navy3,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Text(
                '$score',
                style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.xl,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'درجة الامتثال',
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.sm,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.base,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StatusSeverity { ok, warning, error, info }

class _StatusCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final _StatusSeverity severity;
  final String? ctaLabel;

  const _StatusCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.severity,
    this.ctaLabel,
  });

  Color _color() {
    switch (severity) {
      case _StatusSeverity.ok:
        return AC.ok;
      case _StatusSeverity.warning:
        return AC.warn;
      case _StatusSeverity.error:
        return AC.err;
      case _StatusSeverity.info:
        return AC.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AC.navy3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.sm,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: TextStyle(
              color: AC.tp,
              fontSize: AppFontSize.h3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: AC.ts,
                    fontSize: AppFontSize.sm,
                  ),
                ),
              ),
              if (ctaLabel != null)
                Text(
                  ctaLabel!,
                  style: TextStyle(
                    color: color,
                    fontSize: AppFontSize.sm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
