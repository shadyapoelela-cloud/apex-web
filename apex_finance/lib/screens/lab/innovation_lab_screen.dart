/// APEX Innovation Lab — three interactive prototypes of features that no
/// other ERP currently ships:
///   1. Ledger Lens     — every figure is a clickable surface with lineage,
///                        trust score, and a conversation thread attached
///                        to the number itself.
///   2. Time-Scrubber   — a horizontal slider that rewinds the same report
///                        through historical snapshots in real time.
///   3. Workflow Chains — after a save, AI proposes the next 3 likely
///                        steps as a single chained action.
///
/// All three demos use in-memory mock data so they work standalone — the
/// goal is to validate the interaction model before wiring to live data.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Top-level screen
// ═══════════════════════════════════════════════════════════════════════════

class InnovationLabScreen extends StatelessWidget {
  const InnovationLabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Header(),
            const SizedBox(height: 24),
            _SectionCard(
              number: 1,
              title: 'Ledger Lens',
              subtitle: 'كل رقم يفتح شجرة المصدر + درجة الثقة + محادثة',
              accent: const Color(0xFF7C3AED),
              child: const _LedgerLensDemo(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              number: 2,
              title: 'Time-Scrubber',
              subtitle: 'اسحب الشريط الزمني — التقرير يرجع للخلف لحظياً',
              accent: const Color(0xFF2ECC8A),
              child: const _TimeScrubberDemo(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              number: 3,
              title: 'Workflow Chains',
              subtitle: 'بعد الحفظ، AI يقترح الخطوات الثلاث التالية كسلسلة',
              accent: const Color(0xFFE74C3C),
              child: const _WorkflowChainsDemo(),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold, AC.purple],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.science_rounded, color: Colors.white, size: 26),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('مختبر الابتكار',
              style: TextStyle(
                  color: AC.tp,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('ثلاثة تفاعلات لم يطبّقها أي ERP في العالم',
              style: TextStyle(color: AC.ts, fontSize: 13)),
        ]),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AC.gold.withValues(alpha: 0.14),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bolt_rounded, color: AC.gold, size: 14),
          const SizedBox(width: 4),
          Text('PROTOTYPE',
              style: TextStyle(
                  color: AC.gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
        ]),
      ),
    ]);
  }
}

class _SectionCard extends StatelessWidget {
  final int number;
  final String title;
  final String subtitle;
  final Color accent;
  final Widget child;
  const _SectionCard({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.16),
                accent.withValues(alpha: 0.04),
              ],
            ),
            border: Border(
                bottom: BorderSide(color: AC.bdr.withValues(alpha: 0.5))),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text('$number',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: AC.ts, fontSize: 12)),
                  ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. LEDGER LENS — clickable figures with lineage / trust / chat
// ═══════════════════════════════════════════════════════════════════════════

class _PnlRow {
  final String label;
  final double amount;
  final List<_LineageItem> lineage;
  final double trust;
  final List<_Comment> seedComments;
  _PnlRow({
    required this.label,
    required this.amount,
    required this.lineage,
    required this.trust,
    required this.seedComments,
  });
}

class _LineageItem {
  final String label;
  final double value;
  final IconData icon;
  final String? alert;
  const _LineageItem(this.label, this.value, this.icon, {this.alert});
}

class _Comment {
  final String author;
  final String text;
  final String time;
  final bool isAi;
  const _Comment({
    required this.author,
    required this.text,
    required this.time,
    this.isAi = false,
  });
}

final List<_PnlRow> _kPnlRows = [
  _PnlRow(
    label: 'إيرادات المبيعات',
    amount: 2_450_000,
    trust: 0.87,
    lineage: const [
      _LineageItem('فواتير منشورة (47)', 2_180_000, Icons.receipt_long_rounded),
      _LineageItem('قيود تسوية يدوية (3)', 270_000, Icons.edit_note_rounded,
          alert: 'قيد JE-0034 يدوي يحتاج توثيق'),
      _LineageItem('عكوس قيد (1)', -85_000, Icons.undo_rounded),
      _LineageItem('فواتير مرتدة', 85_000, Icons.refresh_rounded),
    ],
    seedComments: const [
      _Comment(
        author: 'Apex AI',
        text:
            'لاحظت ٣ قيود يدوية تساوي ١١٪ من الإيرادات. توصية: مراجعة JE-0034 قبل الإقفال.',
        time: 'منذ ٥ د',
        isAi: true,
      ),
      _Comment(
        author: 'محمد العمري',
        text: 'JE-0034 خاص بصفقة طارئة قبل نهاية الشهر. مرفق العقد.',
        time: 'منذ ١٢ د',
      ),
    ],
  ),
  _PnlRow(
    label: 'تكلفة البضاعة المباعة',
    amount: 1_320_000,
    trust: 0.94,
    lineage: const [
      _LineageItem('مخزون مستهلك', 1_180_000, Icons.inventory_2_rounded),
      _LineageItem('شحن مباشر', 95_000, Icons.local_shipping_rounded),
      _LineageItem('تسويات FX', 45_000, Icons.currency_exchange_rounded),
    ],
    seedComments: const [
      _Comment(
        author: 'Apex AI',
        text: 'COGS ضمن النطاق الطبيعي مقارنة بالـ ٦ أشهر الماضية.',
        time: 'منذ ١ س',
        isAi: true,
      ),
    ],
  ),
  _PnlRow(
    label: 'مصاريف تشغيلية',
    amount: 480_000,
    trust: 0.72,
    lineage: const [
      _LineageItem('رواتب', 320_000, Icons.badge_rounded),
      _LineageItem('إيجارات', 75_000, Icons.home_work_rounded),
      _LineageItem('تسويق', 60_000, Icons.campaign_rounded,
          alert: 'زيادة ٣٢٪ عن الشهر السابق — تستحق تفسير'),
      _LineageItem('متفرقات', 25_000, Icons.more_horiz_rounded),
    ],
    seedComments: const [
      _Comment(
        author: 'Apex AI',
        text:
            'تنبيه: قفزة ٣٢٪ في مصاريف التسويق. السبب المحتمل: حملة الإطلاق في ١٢ مارس.',
        time: 'منذ ٢ س',
        isAi: true,
      ),
    ],
  ),
  _PnlRow(
    label: 'الربح الصافي',
    amount: 650_000,
    trust: 0.83,
    lineage: const [
      _LineageItem('إجمالي الربح', 1_130_000, Icons.trending_up_rounded),
      _LineageItem('− مصاريف', -480_000, Icons.trending_down_rounded),
    ],
    seedComments: const [
      _Comment(
        author: 'Apex AI',
        text: 'هامش صافي ٢٦.٥٪ — أعلى من متوسط القطاع (١٨٪).',
        time: 'منذ ٣٠ د',
        isAi: true,
      ),
    ],
  ),
];

class _LedgerLensDemo extends StatelessWidget {
  const _LedgerLensDemo();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _miniHint('انقر أي رقم لرؤية شجرة المصدر + الثقة + المحادثة'),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AC.bdr.withValues(alpha: 0.5)),
        ),
        child: Column(
            children: List.generate(_kPnlRows.length, (i) {
          final r = _kPnlRows[i];
          final isLast = i == _kPnlRows.length - 1;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: isLast
                          ? Colors.transparent
                          : AC.bdr.withValues(alpha: 0.3))),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Text(r.label,
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 14,
                        fontWeight:
                            isLast ? FontWeight.w800 : FontWeight.w500)),
              ),
              _ClickableFigure(row: r),
            ]),
          );
        })),
      ),
    ]);
  }
}

class _ClickableFigure extends StatefulWidget {
  final _PnlRow row;
  const _ClickableFigure({required this.row});

  @override
  State<_ClickableFigure> createState() => _ClickableFigureState();
}

class _ClickableFigureState extends State<_ClickableFigure> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showLensSheet(context, r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hover
                ? AC.purple.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hover
                  ? AC.purple.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_fmt(r.amount),
                style: TextStyle(
                    color: AC.tp,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            const SizedBox(width: 8),
            _TrustDot(trust: r.trust),
            if (_hover) ...[
              const SizedBox(width: 6),
              Icon(Icons.search_rounded,
                  size: 14, color: AC.purple),
            ],
          ]),
        ),
      ),
    );
  }
}

class _TrustDot extends StatelessWidget {
  final double trust;
  const _TrustDot({required this.trust});
  @override
  Widget build(BuildContext context) {
    final c = trust >= 0.85
        ? AC.ok
        : trust >= 0.7
            ? AC.warn
            : AC.err;
    return Tooltip(
      message: 'درجة الثقة: ${(trust * 100).round()}٪',
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: c.withValues(alpha: 0.5),
                blurRadius: 6,
                spreadRadius: 1),
          ],
        ),
      ),
    );
  }
}

void _showLensSheet(BuildContext context, _PnlRow row) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _LensSheet(row: row),
  );
}

class _LensSheet extends StatefulWidget {
  final _PnlRow row;
  const _LensSheet({required this.row});

  @override
  State<_LensSheet> createState() => _LensSheetState();
}

class _LensSheetState extends State<_LensSheet> {
  late List<_Comment> _comments;
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    _comments = List<_Comment>.from(widget.row.seedComments);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _comments.add(_Comment(
          author: 'أنت', text: text, time: 'الآن'));
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.row;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, ctl) => Container(
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AC.navy4,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AC.purple.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.lens_blur_rounded,
                    color: AC.purple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.label,
                          style: TextStyle(
                              color: AC.tp,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(_fmt(r.amount),
                          style: TextStyle(
                              color: AC.gold,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                    ]),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: AC.ts),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Divider(height: 1, color: AC.bdr),
          Expanded(
            child: ListView(
              controller: ctl,
              padding: const EdgeInsets.all(16),
              children: [
                _trustBlock(r.trust),
                const SizedBox(height: 18),
                _sectionHeader('شجرة المصدر', Icons.account_tree_rounded),
                const SizedBox(height: 8),
                ...r.lineage.map(_lineageRow),
                const SizedBox(height: 18),
                _sectionHeader('محادثة الرقم', Icons.forum_rounded),
                const SizedBox(height: 8),
                ..._comments.map(_commentRow),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AC.navy3,
              border: Border(top: BorderSide(color: AC.bdr)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  style: TextStyle(color: AC.tp, fontSize: 13),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'علّق على هذا الرقم… @شخص أو @AI للسؤال',
                    hintStyle: TextStyle(
                        color: AC.ts, fontSize: 12),
                    isDense: true,
                    filled: true,
                    fillColor: AC.navy2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: AC.bdr),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send_rounded, color: AC.gold),
                onPressed: _send,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _trustBlock(double trust) {
    final c = trust >= 0.85 ? AC.ok : trust >= 0.7 ? AC.warn : AC.err;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        border: Border.all(color: c.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: trust,
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation(c),
              backgroundColor: c.withValues(alpha: 0.18),
            ),
            Text('${(trust * 100).round()}%',
                style: TextStyle(
                    color: c, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('درجة ثقة AI',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    trust >= 0.85
                        ? 'كل المصادر موثّقة وضمن النمط الطبيعي'
                        : trust >= 0.7
                            ? 'مصدر أو أكثر يستحق المراجعة قبل الإقفال'
                            : 'تحذير: مصادر متعددة خارج النمط — راجع قبل الترحيل',
                    style:
                        TextStyle(color: AC.ts, fontSize: 12, height: 1.4)),
              ]),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String label, IconData icon) {
    return Row(children: [
      Icon(icon, color: AC.gold, size: 16),
      const SizedBox(width: 8),
      Text(label,
          style: TextStyle(
              color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _lineageRow(_LineageItem it) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AC.bdr.withValues(alpha: 0.4)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(it.icon, color: AC.ts, size: 14),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(it.label,
                      style: TextStyle(color: AC.tp, fontSize: 12.5))),
              Text(_fmt(it.value),
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures:
                          const [FontFeature.tabularFigures()])),
            ]),
            if (it.alert != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.warning_amber_rounded,
                    color: AC.warn, size: 13),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(it.alert!,
                        style: TextStyle(
                            color: AC.warn,
                            fontSize: 11,
                            fontWeight: FontWeight.w500))),
              ]),
            ],
          ]),
    );
  }

  Widget _commentRow(_Comment c) {
    final color = c.isAi ? AC.purple : AC.gold;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          right: BorderSide(color: color, width: 3),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (c.isAi)
            Icon(Icons.auto_awesome_rounded, color: color, size: 13)
          else
            Icon(Icons.person_rounded, color: color, size: 13),
          const SizedBox(width: 6),
          Text(c.author,
              style: TextStyle(
                  color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
          const Spacer(),
          Text(c.time, style: TextStyle(color: AC.td, fontSize: 10)),
        ]),
        const SizedBox(height: 6),
        Text(c.text,
            style: TextStyle(color: AC.tp, fontSize: 12.5, height: 1.5)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 2. TIME-SCRUBBER — slider rewinds the same report
// ═══════════════════════════════════════════════════════════════════════════

class _Snapshot {
  final String label;
  final Map<String, double> rows;
  const _Snapshot({required this.label, required this.rows});
}

const List<_Snapshot> _kSnapshots = [
  _Snapshot(label: 'يناير', rows: {
    'إيرادات': 1_820_000,
    'تكاليف': 1_050_000,
    'مصاريف تشغيل': 380_000,
    'صافي الربح': 390_000,
  }),
  _Snapshot(label: 'فبراير', rows: {
    'إيرادات': 2_010_000,
    'تكاليف': 1_140_000,
    'مصاريف تشغيل': 405_000,
    'صافي الربح': 465_000,
  }),
  _Snapshot(label: 'مارس', rows: {
    'إيرادات': 2_280_000,
    'تكاليف': 1_245_000,
    'مصاريف تشغيل': 430_000,
    'صافي الربح': 605_000,
  }),
  _Snapshot(label: 'أبريل (حتى ٢٨)', rows: {
    'إيرادات': 2_450_000,
    'تكاليف': 1_320_000,
    'مصاريف تشغيل': 480_000,
    'صافي الربح': 650_000,
  }),
];

class _TimeScrubberDemo extends StatefulWidget {
  const _TimeScrubberDemo();

  @override
  State<_TimeScrubberDemo> createState() => _TimeScrubberDemoState();
}

class _TimeScrubberDemoState extends State<_TimeScrubberDemo> {
  double _t = 1.0; // 0..1 across snapshots

  _Snapshot get _current {
    final idx = (_t * (_kSnapshots.length - 1)).round();
    return _kSnapshots[idx];
  }

  Map<String, double> get _interpolated {
    final scaled = _t * (_kSnapshots.length - 1);
    final lo = scaled.floor();
    final hi = scaled.ceil().clamp(0, _kSnapshots.length - 1);
    final f = scaled - lo;
    final a = _kSnapshots[lo].rows;
    final b = _kSnapshots[hi].rows;
    return {
      for (final k in a.keys)
        k: a[k]! + (b[k]! - a[k]!) * f,
    };
  }

  @override
  Widget build(BuildContext context) {
    final snap = _current;
    final values = _interpolated;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _miniHint('اسحب المؤشر — الأرقام تتحرك بسلاسة بين اللقطات الزمنية'),
      const SizedBox(height: 14),
      // Scrubber track
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AC.bdr.withValues(alpha: 0.5)),
        ),
        child: Column(children: [
          Row(children: [
            Icon(Icons.history_rounded, color: AC.ok, size: 16),
            const SizedBox(width: 8),
            Text('عرض كما كان في:',
                style: TextStyle(color: AC.ts, fontSize: 12)),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AC.ok.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(snap.label,
                  style: TextStyle(
                      color: AC.ok,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _t = 1.0),
              icon: const Icon(Icons.fast_forward_rounded, size: 16),
              label: const Text('الآن'),
              style: TextButton.styleFrom(foregroundColor: AC.gold),
            ),
          ]),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AC.ok,
              inactiveTrackColor: AC.navy4,
              thumbColor: AC.ok,
              overlayColor: AC.ok.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: _t,
              onChanged: (v) => setState(() => _t = v),
            ),
          ),
          // Tick marks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _kSnapshots
                  .map((s) => Text(s.label,
                      style: TextStyle(
                          color: AC.td,
                          fontSize: 10,
                          fontWeight: FontWeight.w500)))
                  .toList(),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      // The "rewindable" report
      Container(
        decoration: BoxDecoration(
          color: AC.navy3,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AC.bdr.withValues(alpha: 0.5)),
        ),
        child: Column(
            children: values.entries.toList().asMap().entries.map((e) {
          final i = e.key;
          final entry = e.value;
          final isLast = i == values.length - 1;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                      color: isLast
                          ? Colors.transparent
                          : AC.bdr.withValues(alpha: 0.3))),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Expanded(
                child: Text(entry.key,
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 14,
                        fontWeight:
                            isLast ? FontWeight.w800 : FontWeight.w500)),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 80),
                child: Text(
                  _fmt(entry.value),
                  key: ValueKey('${entry.key}-${entry.value.round()}'),
                  style: TextStyle(
                      color: isLast ? AC.gold : AC.tp,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures:
                          const [FontFeature.tabularFigures()]),
                ),
              ),
            ]),
          );
        }).toList()),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 3. WORKFLOW CHAINS — AI suggests next 3 steps after save
// ═══════════════════════════════════════════════════════════════════════════

class _ChainStep {
  final String label;
  final String detail;
  final IconData icon;
  const _ChainStep(this.label, this.detail, this.icon);
}

const List<_ChainStep> _kChainSteps = [
  _ChainStep('تسجيل دفعة العميل', 'سداد كامل / جزئي + تخصيص للحساب',
      Icons.payments_rounded),
  _ChainStep('إيداع بنكي', 'إيداع المتحصلات في حساب الراجحي الرئيسي',
      Icons.account_balance_rounded),
  _ChainStep('تحديث COGS', 'خصم الكمية من المخزون + توليد قيد التكلفة',
      Icons.inventory_2_rounded),
];

enum _ChainPhase { form, suggested, running, done }

class _WorkflowChainsDemo extends StatefulWidget {
  const _WorkflowChainsDemo();

  @override
  State<_WorkflowChainsDemo> createState() => _WorkflowChainsDemoState();
}

class _WorkflowChainsDemoState extends State<_WorkflowChainsDemo> {
  _ChainPhase _phase = _ChainPhase.form;
  int _runningIdx = 0;
  Timer? _timer;
  final _customer = TextEditingController(text: 'شركة المعرفة المتقدمة');
  final _amount = TextEditingController(text: '12500');

  @override
  void dispose() {
    _timer?.cancel();
    _customer.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _onSave() {
    setState(() => _phase = _ChainPhase.suggested);
  }

  void _runAll() {
    setState(() {
      _phase = _ChainPhase.running;
      _runningIdx = 0;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted) return;
      setState(() {
        _runningIdx++;
        if (_runningIdx >= _kChainSteps.length) {
          _phase = _ChainPhase.done;
          t.cancel();
        }
      });
    });
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _phase = _ChainPhase.form;
      _runningIdx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _miniHint(
          'احفظ الفاتورة — AI سيقترح ٣ خطوات تالية كسلسلة ينفذها بنقرة واحدة'),
      const SizedBox(height: 14),
      _buildForm(),
      const SizedBox(height: 14),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        child: _buildPhase(),
      ),
    ]);
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AC.bdr.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.receipt_long_rounded, color: AC.gold, size: 18),
          const SizedBox(width: 8),
          Text('فاتورة بيع جديدة',
              style: TextStyle(
                  color: AC.tp,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _customer,
          enabled: _phase == _ChainPhase.form,
          style: TextStyle(color: AC.tp, fontSize: 13),
          decoration: InputDecoration(
            labelText: 'العميل',
            isDense: true,
            filled: true,
            fillColor: AC.navy2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          enabled: _phase == _ChainPhase.form,
          style: TextStyle(color: AC.tp, fontSize: 13),
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'المبلغ (ر.س)',
            isDense: true,
            filled: true,
            fillColor: AC.navy2,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: ElevatedButton.icon(
            onPressed: _phase == _ChainPhase.form ? _onSave : null,
            icon: const Icon(Icons.save_rounded, size: 16),
            label: const Text('حفظ الفاتورة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildPhase() {
    switch (_phase) {
      case _ChainPhase.form:
        return const SizedBox(key: ValueKey('form'));
      case _ChainPhase.suggested:
        return _buildSuggestion();
      case _ChainPhase.running:
        return _buildRunning();
      case _ChainPhase.done:
        return _buildDone();
    }
  }

  Widget _buildSuggestion() {
    return Container(
      key: const ValueKey('suggested'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.purple.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AC.purple.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: AC.purple, size: 16),
          ),
          const SizedBox(width: 10),
          Text('Apex AI يقترح',
              style: TextStyle(
                  color: AC.purple,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        Text(
            'بعد فواتير مشابهة، احتجت في المتوسط لهذه الخطوات الـ ٣ التالية. هل أنفذها لك كسلسلة؟',
            style:
                TextStyle(color: AC.tp, fontSize: 12.5, height: 1.6)),
        const SizedBox(height: 12),
        ..._kChainSteps.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                    color: AC.purple.withValues(alpha: 0.18),
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: AC.purple,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Icon(s.icon, color: AC.tp, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(s.label,
                      style:
                          TextStyle(color: AC.tp, fontSize: 12.5))),
            ]),
          );
        }),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('لا شكراً'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _runAll,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('نفّذ الـ ٣ خطوات'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildRunning() {
    return Container(
      key: const ValueKey('running'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.purple.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('جارٍ تنفيذ السلسلة…',
            style: TextStyle(
                color: AC.purple,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ..._kChainSteps.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          final done = i < _runningIdx;
          final running = i == _runningIdx;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: done
                  ? AC.ok.withValues(alpha: 0.10)
                  : running
                      ? AC.purple.withValues(alpha: 0.10)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: done
                    ? AC.ok.withValues(alpha: 0.4)
                    : running
                        ? AC.purple.withValues(alpha: 0.5)
                        : AC.bdr.withValues(alpha: 0.3),
              ),
            ),
            child: Row(children: [
              SizedBox(
                width: 22,
                height: 22,
                child: done
                    ? Icon(Icons.check_circle_rounded,
                        color: AC.ok, size: 22)
                    : running
                        ? CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(AC.purple))
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AC.bdr, width: 1.5),
                              shape: BoxShape.circle,
                            ),
                          ),
              ),
              const SizedBox(width: 10),
              Icon(s.icon,
                  color: done ? AC.ok : running ? AC.purple : AC.ts,
                  size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label,
                            style: TextStyle(
                                color: AC.tp,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                        Text(s.detail,
                            style: TextStyle(
                                color: AC.ts, fontSize: 10.5)),
                      ])),
            ]),
          );
        }),
      ]),
    );
  }

  Widget _buildDone() {
    return Container(
      key: const ValueKey('done'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.ok.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.ok.withValues(alpha: 0.5)),
      ),
      child: Column(children: [
        Icon(Icons.task_alt_rounded, color: AC.ok, size: 36),
        const SizedBox(height: 10),
        Text('السلسلة اكتملت',
            style: TextStyle(
                color: AC.ok, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('فاتورة + دفعة + إيداع + تحديث COGS — ٤ عمليات بنقرة واحدة',
            textAlign: TextAlign.center,
            style: TextStyle(color: AC.ts, fontSize: 12)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _reset,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('جرّب مرة أخرى'),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Shared helpers
// ═══════════════════════════════════════════════════════════════════════════

Widget _miniHint(String text) {
  return Builder(builder: (ctx) {
    return Row(children: [
      Icon(Icons.info_outline_rounded,
          color: AC.gold, size: 14),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: TextStyle(color: AC.ts, fontSize: 11.5, height: 1.5)),
      ),
    ]);
  });
}

String _fmt(double v) {
  final neg = v < 0;
  final abs = v.abs();
  final s = abs >= 1000
      ? abs.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},')
      : abs.toStringAsFixed(0);
  return '${neg ? '−' : ''}$s';
}

// math is imported but unused; keep import for future trig animations.
// ignore: unused_element
double _twoPi() => 2 * math.pi;
