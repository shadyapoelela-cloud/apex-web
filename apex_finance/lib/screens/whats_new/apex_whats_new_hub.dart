/// APEX What's New Hub — landing page for every capability added this sprint.
///
/// Presents each new module as a tappable card with icon + title + status
/// + optional "Try it" action opening an interactive mini-demo.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class ApexWhatsNewHub extends StatelessWidget {
  const ApexWhatsNewHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: '🚀 ما الجديد — Sprint 35 → 42'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(
                    'تم بناء 50+ مكوّن جديد في هذه الجلسة',
                    'Foundation fixes + Apex shared layer + Regional compliance + AI features + Industry packs.',
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _group(context, 'الواجهة المشتركة (Apex Layer)', [
                    _Item(
                      icon: Icons.auto_awesome_motion,
                      title: 'Sprint 37-38 — تجربة محسَّنة (جديد)',
                      subtitle: 'مبدّل تطبيقات + معاينة يمنى + شريط سياقي',
                      route: '/sprint37-experience',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.bolt,
                      title: 'Sprint 35-36 — الأساس',
                      subtitle: 'تحرير مضمّن + Alt+1..9 + تحقق لحظي',
                      route: '/sprint35-foundation',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.view_headline,
                      title: 'معرض المكوّنات',
                      subtitle: '9 مكوّنات Flutter + 4 validators',
                      route: '/showcase',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.keyboard_command_key,
                      title: 'Command Palette (Cmd+K)',
                      subtitle: '21 أمراً، بحث فازي عربي، Linear-grade',
                      status: _Status.active,
                    ),
                  ]),
                  _group(context, 'الامتثال الإقليمي (Q1)', [
                    _Item(
                      icon: Icons.qr_code_2,
                      title: 'ZATCA Phase 2 — Signer + Fatoora',
                      subtitle: 'XAdES-BES + 7-field TLV QR + HTTP client',
                      route: '/zatca-demo',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.account_balance,
                      title: 'UAE Corporate Tax — حاسبة',
                      subtitle: '9% + 375K exempt + SBR + QFZP + 75% loss cap',
                      route: '/uae-corp-tax',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.chat_bubble_outline,
                      title: 'WhatsApp Business',
                      subtitle: '7 قوالب عربية + webhook + HMAC verification',
                      route: '/whatsapp-demo',
                      status: _Status.done,
                    ),
                  ]),
                  _group(context, 'الذكاء والأتمتة (Q2)', [
                    _Item(
                      icon: Icons.compare_arrows,
                      title: 'Bank OCR + 4-layer matching',
                      subtitle: 'CSV/MT940 parsers + Arabic fuzzy matcher',
                      route: '/bank-ocr-demo',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.smart_toy_outlined,
                      title: 'Autonomous AP Agent',
                      subtitle: 'Inbox → OCR → coding → approval → payment',
                      route: '/ap-pipeline-demo',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.payment,
                      title: 'GCC Payments',
                      subtitle: 'Mada + STC Pay + Apple Pay + Tabby',
                      route: '/payments-playground',
                      status: _Status.done,
                    ),
                  ]),
                  _group(context, 'الموارد البشرية (KSA/UAE)', [
                    _Item(
                      icon: Icons.calculate,
                      title: 'GOSI / GPSSA Calculator',
                      subtitle: 'KSA 10/12% → 45K cap | UAE 5/12.5% → 50K cap',
                      route: '/gosi-demo',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.receipt_long,
                      title: 'WPS File Generator',
                      subtitle: 'KSA SAMA SIF + UAE MOHRE SIF 5.0',
                      route: '/wps-demo',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.logout,
                      title: 'EOSB Calculator',
                      subtitle: 'نظام العمل السعودي + UAE Art. 51-52',
                      route: '/eosb-demo',
                      status: _Status.done,
                    ),
                  ]),
                  _group(context, 'النظام البيئي (Q4)', [
                    _Item(
                      icon: Icons.apps,
                      title: 'Industry Packs',
                      subtitle: 'F&B + مقاولات + عيادات + لوجستيك + خدمات',
                      route: '/industry-packs',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.trending_up,
                      title: 'Startup Metrics Live',
                      subtitle: 'Burn, Runway, MRR, LTV/CAC, Rule of 40',
                      route: '/startup-metrics',
                      status: _Status.done,
                    ),
                    _Item(
                      icon: Icons.hub,
                      title: 'Open Banking Consent',
                      subtitle: 'SAMA + UAE Open Finance (OAuth2 + 180-day)',
                      route: '/open-banking-demo',
                      status: _Status.scaffold,
                    ),
                  ]),
                  _group(context, 'البنية التحتية (Foundation)', [
                    _Item(
                      icon: Icons.security,
                      title: 'Social Auth (Real verification)',
                      subtitle: 'Google tokeninfo + Apple JWKs',
                      status: _Status.active,
                    ),
                    _Item(
                      icon: Icons.sms,
                      title: 'SMS / OTP (Unifonic + Twilio)',
                      subtitle: 'SHA-256 store + TTL + cooldown',
                      status: _Status.active,
                    ),
                    _Item(
                      icon: Icons.speed,
                      title: 'Rate Limiter (Memory / Redis)',
                      subtitle: 'Pluggable backend + tiered per-path limits',
                      status: _Status.active,
                    ),
                    _Item(
                      icon: Icons.storage,
                      title: 'Alembic Migrations',
                      subtitle: 'Auto-upgrade في production startup',
                      status: _Status.active,
                    ),
                  ]),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AC.gold.withValues(alpha: 0.18),
            AC.navy2,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AC.tp,
              fontSize: AppFontSize.h2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle,
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.lg),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _pill('974 اختبار Python', AC.ok),
              const SizedBox(width: AppSpacing.sm),
              _pill('31 اختبار Flutter', AC.ok),
              const SizedBox(width: AppSpacing.sm),
              _pill('0 regressions', AC.ok),
              const SizedBox(width: AppSpacing.sm),
              _pill('9 commits', AC.cyan),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: AppFontSize.sm,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _group(BuildContext context, String title, List<_Item> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.md,
          ),
          child: Text(
            title,
            style: TextStyle(
              color: AC.gold,
              fontSize: AppFontSize.h3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final columns = constraints.maxWidth > 1100
                ? 3
                : constraints.maxWidth > 700
                    ? 2
                    : 1;
            return Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: items
                  .map(
                    (item) => SizedBox(
                      width: (constraints.maxWidth -
                              (columns - 1) * AppSpacing.md) /
                          columns,
                      child: _card(context, item),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _card(BuildContext context, _Item item) {
    final clickable = item.route != null;
    return InkWell(
      onTap: clickable ? () => context.go(item.route!) : null,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.navy4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.icon, color: AC.gold, size: 24),
                const SizedBox(width: AppSpacing.sm),
                _statusBadge(item.status),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              item.title,
              style: TextStyle(
                color: AC.tp,
                fontSize: AppFontSize.lg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              item.subtitle,
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.md),
            ),
            if (clickable) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Text(
                    'جرّبها الآن',
                    style: TextStyle(
                      color: AC.gold,
                      fontSize: AppFontSize.md,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_back, color: AC.gold, size: 14),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(_Status s) {
    final (label, color) = switch (s) {
      _Status.active => ('نشط', AC.ok),
      _Status.done => ('✓ جاهز', AC.cyan),
      _Status.scaffold => ('scaffold', AC.warn),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: AppFontSize.xs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _Status { active, done, scaffold }

class _Item {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? route;
  final _Status status;

  const _Item({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.route,
    required this.status,
  });
}
