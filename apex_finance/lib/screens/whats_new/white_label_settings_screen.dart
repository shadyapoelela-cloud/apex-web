/// White-Label settings — full end-to-end integration screen.
///
/// Admins land here to customise their tenant's brand identity. The
/// ApexWhiteLabelConnected widget handles load/save against
/// /api/v1/tenant/branding; this screen is the Scaffold shell +
/// context banner.
library;

import 'package:flutter/material.dart';

import '../../core/apex_app_bar.dart';
import '../../core/apex_white_label_connected.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class WhiteLabelSettingsScreen extends StatelessWidget {
  const WhiteLabelSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: const ApexAppBar(title: '🎨 إعدادات العلامة (White-Label)'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _banner(),
            const SizedBox(height: AppSpacing.xl),
            const ApexWhiteLabelConnected(),
            const SizedBox(height: AppSpacing.xl),
            _endpoints(),
          ],
        ),
      ),
    );
  }

  Widget _banner() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.2), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.palette, color: AC.gold, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('علامتك التجارية داخل APEX',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.xl,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'الإعدادات أدناه تُحفظ فوراً على حسابك وتُطبَّق عند دخول المستخدمين التاليين. '
                  'عرض مباشر على اليمين.',
                  style: TextStyle(
                      color: AC.ts,
                      fontSize: AppFontSize.sm,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _endpoints() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.api, size: 16, color: AC.gold),
              const SizedBox(width: 6),
              Text('الـ API',
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: AppSpacing.sm),
            _endpoint('GET', '/api/v1/tenant/branding',
                'قراءة الإعدادات الحالية'),
            _endpoint('PUT', '/api/v1/tenant/branding',
                'حفظ إعدادات جديدة (admin only)'),
          ],
        ),
      );

  Widget _endpoint(String method, String path, String desc) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: method == 'GET' ? AC.ok : Colors.orange.shade700,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            alignment: Alignment.center,
            child: Text(method,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(path,
              style: TextStyle(
                  color: AC.gold,
                  fontSize: AppFontSize.xs,
                  fontFamily: 'monospace')),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(desc,
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.xs)),
          ),
        ]),
      );
}
