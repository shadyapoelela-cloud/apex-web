/// APEX V5.1 — Regulatory News Ticker (Enhancement #13).
///
/// Top-bar scrolling alerts for ZATCA / SAMA / FTA / GOSI updates.
/// Bloomberg-inspired — keeps regulatory changes visible in real time.
///
/// POC uses mock data. Production binds to Knowledge Brain:
///   GET /knowledge-brain/alerts?regions=ksa,uae,bh,om
library;

import 'dart:async';

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;

class V5NewsItem {
  final String authorityAr;
  final String messageAr;
  final V5NewsKind kind;
  final DateTime? effectiveDate;

  const V5NewsItem({
    required this.authorityAr,
    required this.messageAr,
    required this.kind,
    this.effectiveDate,
  });
}

enum V5NewsKind { update, deadline, warning, info }

/// Default mock feed for POC. Production replaces with live API.
const List<V5NewsItem> v5MockNews = [
  V5NewsItem(
    authorityAr: 'زاتكا',
    messageAr: 'تحديث بنية TLV QR — مفعّل في APEX فوراً',
    kind: V5NewsKind.update,
  ),
  V5NewsItem(
    authorityAr: 'FTA الإمارات',
    messageAr: 'موعد إقرار Pillar Two الربع الثاني: 2026-06-30',
    kind: V5NewsKind.deadline,
  ),
  V5NewsItem(
    authorityAr: 'GOSI',
    messageAr: 'تحديث نسب المشاركة يبدأ من 2026-05-01',
    kind: V5NewsKind.update,
  ),
  V5NewsItem(
    authorityAr: 'SAMA',
    messageAr: 'إرشادات جديدة للعناية الواجبة في الخدمات المالية',
    kind: V5NewsKind.info,
  ),
  V5NewsItem(
    authorityAr: 'زاتكا',
    messageAr: 'موعد إرسال إقرار الربع الثاني: 2026-07-28',
    kind: V5NewsKind.deadline,
  ),
];

class ApexV5NewsTicker extends StatefulWidget {
  final List<V5NewsItem> items;
  final Duration rotateEvery;
  final Color? background;

  const ApexV5NewsTicker({
    super.key,
    this.items = v5MockNews,
    this.rotateEvery = const Duration(seconds: 6),
    this.background,
  });

  @override
  State<ApexV5NewsTicker> createState() => _ApexV5NewsTickerState();
}

class _ApexV5NewsTickerState extends State<ApexV5NewsTicker> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.rotateEvery, (_) {
      if (!mounted || widget.items.isEmpty) return;
      setState(() => _index = (_index + 1) % widget.items.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color _kindColor(V5NewsKind k) {
    switch (k) {
      case V5NewsKind.deadline:
        return core_theme.AC.warn; // amber-600
      case V5NewsKind.warning:
        return core_theme.AC.err; // red-600
      case V5NewsKind.update:
        return core_theme.AC.info; // blue-600
      case V5NewsKind.info:
        return const Color(0xFF6B7280); // gray-500
    }
  }

  IconData _kindIcon(V5NewsKind k) {
    switch (k) {
      case V5NewsKind.deadline:
        return Icons.event;
      case V5NewsKind.warning:
        return Icons.warning;
      case V5NewsKind.update:
        return Icons.campaign;
      case V5NewsKind.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final item = widget.items[_index];
    final color = _kindColor(item.kind);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: widget.background ?? core_theme.AC.tp.withValues(alpha: 0.04),
        border: Border(
          bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            'تحديثات تنظيمية',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 16, color: core_theme.AC.tp.withValues(alpha: 0.1)),
          const SizedBox(width: 12),
          Icon(_kindIcon(item.kind), size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '${item.authorityAr}:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                item.messageAr,
                key: ValueKey(_index),
                style: TextStyle(fontSize: 12, color: core_theme.AC.tp),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Pager dots
          Row(
            children: List.generate(widget.items.length, (i) {
              return Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: i == _index ? color : core_theme.AC.tp.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
