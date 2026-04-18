/// Sprint 38 — Composable Dashboard + Notification Center.
///
/// Brings two powerful-but-hidden widgets (ApexDashboardBuilder and
/// ApexNotificationBell) into a single interactive demo. Users can:
///   • Toggle edit mode → add/remove/reorder KPI blocks
///   • Resize blocks across the 12-column grid
///   • Open the bell → see categorized notifications with severity
///   • Mark read / mark-all / "see all"
library;

import 'package:flutter/material.dart';

import '../../core/apex_dashboard_builder.dart';
import '../../core/apex_notification_bell.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class Sprint38ComposableScreen extends StatefulWidget {
  const Sprint38ComposableScreen({super.key});

  @override
  State<Sprint38ComposableScreen> createState() =>
      _Sprint38ComposableScreenState();
}

class _Sprint38ComposableScreenState extends State<Sprint38ComposableScreen> {
  // Starting layout — 4 KPI cards + a wide chart.
  List<DashboardBlock> _blocks = const [
    DashboardBlock(id: 'b1', widgetId: 'revenue', span: 3),
    DashboardBlock(id: 'b2', widgetId: 'cash', span: 3),
    DashboardBlock(id: 'b3', widgetId: 'ar', span: 3),
    DashboardBlock(id: 'b4', widgetId: 'burn', span: 3),
    DashboardBlock(id: 'b5', widgetId: 'trend', span: 12),
  ];

  late List<ApexNotification> _notes = [
    ApexNotification(
      id: 'n1',
      title: 'فاتورة متأخرة',
      body: 'فاتورة INV-1042 عبرت تاريخ الاستحقاق بـ 5 أيام',
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      severity: 'error',
    ),
    ApexNotification(
      id: 'n2',
      title: 'تم توقيع فاتورة ZATCA',
      body: 'INV-1041 تم اعتمادها وإرسالها إلى Fatoora بنجاح',
      timestamp: DateTime.now().subtract(const Duration(minutes: 23)),
      severity: 'success',
    ),
    ApexNotification(
      id: 'n3',
      title: 'تحذير: معدل الحرق',
      body: 'Burn Rate ارتفع 18% هذا الشهر — Runway 8.2 شهراً',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      severity: 'warning',
    ),
    ApexNotification(
      id: 'n4',
      title: 'تقرير جاهز',
      body: 'P&L لشهر مارس جاهز للمراجعة',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
      severity: 'info',
      read: true,
    ),
  ];

  List<DashboardWidgetDef> get _registry => [
        DashboardWidgetDef(
          id: 'revenue',
          title: 'الإيرادات',
          subtitle: 'هذا الشهر',
          icon: Icons.trending_up,
          builder: (_) => _kpi('الإيرادات', '١٢٤,٥٠٠', 'ر.س', AC.ok, '+12%'),
        ),
        DashboardWidgetDef(
          id: 'cash',
          title: 'السيولة',
          subtitle: 'حساب بنكي رئيسي',
          icon: Icons.account_balance_wallet,
          builder: (_) => _kpi('السيولة', '٨٩,٢٠٠', 'ر.س', AC.gold, '+4.8%'),
        ),
        DashboardWidgetDef(
          id: 'ar',
          title: 'المدينون',
          subtitle: 'فواتير غير محصّلة',
          icon: Icons.receipt_long,
          builder: (_) => _kpi('AR', '٤٢,٨٠٠', 'ر.س', AC.err, '+18%'),
        ),
        DashboardWidgetDef(
          id: 'burn',
          title: 'معدل الحرق',
          subtitle: 'Burn / Runway',
          icon: Icons.local_fire_department,
          builder: (_) => _kpi('Burn', '١٥,٠٠٠', 'ر.س/شهر', AC.err, '8.2mo'),
        ),
        DashboardWidgetDef(
          id: 'trend',
          title: 'اتجاه الإيرادات',
          subtitle: 'آخر 12 شهراً',
          icon: Icons.show_chart,
          defaultSpan: 12,
          builder: (_) => _trendChart(),
        ),
        DashboardWidgetDef(
          id: 'aging',
          title: 'تقادم الذمم',
          subtitle: 'AR Aging Bucket',
          icon: Icons.pie_chart,
          defaultSpan: 6,
          builder: (_) => _agingChart(),
        ),
        DashboardWidgetDef(
          id: 'tax',
          title: 'الالتزامات الضريبية',
          subtitle: 'VAT + Zakat + ZATCA',
          icon: Icons.account_balance,
          builder: (_) => _kpi('VAT Q1', '١٨,٦٠٠', 'ر.س', AC.gold, 'Due 30 Apr'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              const ApexStickyToolbar(title: '🧱 Sprint 38: قابل للتكوين'),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  ApexNotificationBell(
                    notifications: _notes,
                    onMarkRead: _markRead,
                    onMarkAllRead: _markAllRead,
                    onSeeAll: () => _toast('سينتقل إلى /notifications'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ]),
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  const SizedBox(height: AppSpacing.lg),
                  ApexDashboardBuilder(
                    blocks: _blocks,
                    widgetRegistry: _registry,
                    onLayoutChanged: (b) => setState(() => _blocks = b),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.2), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.gold.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.view_quilt, color: Colors.amber, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لوحة قابلة للتكوين — SAP Fiori + Odoo 19 style',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.xl,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'اضغط "تحرير" → أضف/احذف/غيّر حجم الكتل. جرّب الجرس 🔔 (أعلى اليمين) لمركز الإشعارات مع 4 مستويات خطورة.',
                  style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _kpi(String label, String value, String unit, Color accent,
      String delta) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm)),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: TextStyle(
                      color: accent,
                      fontSize: AppFontSize.h2,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit,
                    style:
                        TextStyle(color: AC.td, fontSize: AppFontSize.xs)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(delta,
                style: TextStyle(
                    color: accent,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _trendChart() => Container(
        height: 180,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
        ),
        child: CustomPaint(
          painter: _SparkPainter(AC.gold),
          size: Size.infinite,
        ),
      );

  Widget _agingChart() => Container(
        height: 180,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _bucket('0-30 يوم', 0.45, AC.ok),
            const SizedBox(height: AppSpacing.sm),
            _bucket('31-60 يوم', 0.30, AC.gold),
            const SizedBox(height: AppSpacing.sm),
            _bucket('61-90 يوم', 0.18, Colors.amber.shade700),
            const SizedBox(height: AppSpacing.sm),
            _bucket('> 90 يوم', 0.07, AC.err),
          ],
        ),
      );

  Widget _bucket(String label, double pct, Color color) => Row(children: [
        SizedBox(
            width: 80,
            child: Text(label,
                style:
                    TextStyle(color: AC.ts, fontSize: AppFontSize.xs))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AC.navy4,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 14,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 40,
          child: Text('${(pct * 100).round()}%',
              style: TextStyle(
                  color: AC.tp,
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.w600)),
        ),
      ]);

  void _markRead(String id) {
    setState(() {
      _notes = _notes
          .map((n) => n.id == id
              ? ApexNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  timestamp: n.timestamp,
                  severity: n.severity,
                  read: true)
              : n)
          .toList();
    });
  }

  void _markAllRead() {
    setState(() {
      _notes = _notes
          .map((n) => ApexNotification(
                id: n.id,
                title: n.title,
                body: n.body,
                timestamp: n.timestamp,
                severity: n.severity,
                read: true,
              ))
          .toList();
    });
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), duration: const Duration(seconds: 2)));
  }
}

class _SparkPainter extends CustomPainter {
  final Color color;
  _SparkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // 12 months of made-up data — a gentle upward trend with noise.
    final data = [0.4, 0.42, 0.5, 0.48, 0.55, 0.62, 0.59, 0.68, 0.75, 0.72, 0.82, 0.90];
    final stepX = size.width / (data.length - 1);
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - data[i] * size.height * 0.9 - 8;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    // Fill underneath.
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size));
    // Stroke on top.
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    // Dots on each point.
    final dotPaint = Paint()..color = color;
    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - data[i] * size.height * 0.9 - 8;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
