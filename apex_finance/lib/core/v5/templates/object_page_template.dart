/// APEX V5.2 — Object Page Template (T2 from 10-round synthesis).
///
/// Unified pattern for detail/form screens, inspired by:
///   - SAP Fiori Object Page (Header + Facets + Related Items)
///   - Oracle NetSuite Record Form (Tabs + Subtabs)
///   - Odoo Chatter (right-rail comments + activities)
///   - Dynamics 365 Business Process Flow (top stage bar)
///
/// Structure:
///   ┌──────────────────────────────────────────────────┐
///   │ [← back] Title · Status Pill · [⋯ Actions]       │ Header
///   ├──────────────────────────────────────────────────┤
///   │ ⚪ Draft → ⚫ Pending → ⚪ Approved → ⚪ Posted      │ Process Flow (optional)
///   ├──────────────────────────────────────────────────┤
///   │ [📄 8 فواتير] [💰 2 مدفوعات] [📎 3 ملفات]         │ Smart Buttons (optional)
///   ├──────────┬─────────────────────────────┬─────────┤
///   │ Tabs:    │ Content tab:                │ Chatter │
///   │ - نظرة    │ [Your sections + fields]   │ - أنشطة  │
///   │ - بنود    │                             │ - رسائل  │
///   │ - محاسبة  │                             │ - متابعون│
///   │ - مرفقات  │                             │ - مرفقات │
///   │ - سجل     │                             │         │
///   └──────────┴─────────────────────────────┴─────────┘
library;

import 'package:flutter/material.dart';
import '../../theme.dart' as core_theme;

/// A tab in an Object Page (right content pane).
class ObjectPageTab {
  final String id;
  final String labelAr;
  final IconData icon;
  final Widget Function(BuildContext) builder;
  const ObjectPageTab({
    required this.id,
    required this.labelAr,
    required this.icon,
    required this.builder,
  });
}

/// A smart button in the header strip — shows count + navigates to related.
class SmartButton {
  final IconData icon;
  final String labelAr;
  final int? count;
  final VoidCallback? onTap;
  final Color? color;
  const SmartButton({
    required this.icon,
    required this.labelAr,
    this.count,
    this.onTap,
    this.color,
  });
}

/// A stage in a business process flow.
class ProcessStage {
  final String labelAr;
  final IconData? icon;
  const ProcessStage({required this.labelAr, this.icon});
}

/// Chatter rail item (activity/message/log).
class ChatterEntry {
  final String authorAr;
  final String contentAr;
  final DateTime timestamp;
  final IconData? icon;
  final Color? color;
  final ChatterKind kind;
  const ChatterEntry({
    required this.authorAr,
    required this.contentAr,
    required this.timestamp,
    required this.kind,
    this.icon,
    this.color,
  });
}

enum ChatterKind { message, activity, logNote, statusChange }

class ObjectPageTemplate extends StatefulWidget {
  final String titleAr;
  final String? subtitleAr;

  /// Status pill (e.g., "قيد الاعتماد" with orange color).
  final String? statusLabelAr;
  final Color? statusColor;

  /// Process flow bar (optional). If provided, current index is highlighted.
  final List<ProcessStage>? processStages;
  final int processCurrentIndex;

  /// Smart buttons strip (related entities with counts).
  final List<SmartButton>? smartButtons;

  /// Header-right action buttons.
  final List<Widget>? primaryActions;

  /// Tabs (left sidebar in desktop, top tabs in narrow).
  final List<ObjectPageTab> tabs;

  /// When true, render tabs as a horizontal row directly above the content
  /// (Odoo-style) instead of as a vertical sidebar on the right. Default
  /// false to preserve existing screens. Width-narrow always falls back
  /// to top tabs regardless of this flag.
  final bool tabsAtTop;

  /// When true, suppress the shell's tab bar entirely so the parent can
  /// render its own tab strip inside the content area. The shell still
  /// uses tabs[0].builder for content, so callers should pass a single
  /// tab whose builder owns tab switching.
  final bool hideTabsBar;

  /// Chatter rail entries (right side). Null = no chatter rail.
  final List<ChatterEntry>? chatterEntries;

  final VoidCallback? onBack;

  const ObjectPageTemplate({
    super.key,
    required this.titleAr,
    required this.tabs,
    this.subtitleAr,
    this.statusLabelAr,
    this.statusColor,
    this.processStages,
    this.processCurrentIndex = 0,
    this.smartButtons,
    this.primaryActions,
    this.chatterEntries,
    this.onBack,
    this.tabsAtTop = false,
    this.hideTabsBar = false,
  });

  @override
  State<ObjectPageTemplate> createState() => _ObjectPageTemplateState();
}

class _ObjectPageTemplateState extends State<ObjectPageTemplate> {
  int _tabIndex = 0;
  bool _chatterOpen = true;

  static Color get _gold => core_theme.AC.gold;
  static final _navy = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 900;

    final useTopTabs = widget.tabsAtTop || isNarrow;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(
          children: [
            _buildHeader(context),
            if (widget.processStages != null && widget.processStages!.isNotEmpty)
              _buildProcessFlowBar(),
            if (widget.smartButtons != null && widget.smartButtons!.isNotEmpty)
              _buildSmartButtons(),
            const Divider(height: 1),
            if (useTopTabs && !widget.hideTabsBar) _buildTabsHorizontal(),
            if (useTopTabs && !widget.hideTabsBar) const Divider(height: 1),
            Expanded(
              child: Row(
                children: [
                  if (!useTopTabs && !widget.hideTabsBar) _buildTabsSidebar(),
                  if (!useTopTabs && !widget.hideTabsBar)
                    const VerticalDivider(width: 1),
                  Expanded(child: _buildContent()),
                  if (widget.chatterEntries != null && _chatterOpen && !isNarrow) ...[
                    const VerticalDivider(width: 1),
                    _buildChatterRail(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tabs Horizontal (Odoo-style top bar) ───────────────────────
  Widget _buildTabsHorizontal() {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Row(
          children: List.generate(widget.tabs.length, (i) {
            final tab = widget.tabs[i];
            final active = i == _tabIndex;
            return InkWell(
              onTap: () => setState(() => _tabIndex = i),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? _gold : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon,
                        size: 16,
                        color: active ? _gold : core_theme.AC.ts),
                    const SizedBox(width: 8),
                    Text(
                      tab.labelAr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            active ? FontWeight.w800 : FontWeight.w500,
                        color: active ? _navy : core_theme.AC.tp,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_forward, size: 22), // RTL-forward
            onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
            tooltip: 'رجوع',
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.titleAr,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                if (widget.subtitleAr != null)
                  Text(widget.subtitleAr!,
                      style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
              ],
            ),
          ),
          if (widget.statusLabelAr != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (widget.statusColor ?? _gold).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: (widget.statusColor ?? _gold).withValues(alpha: 0.4)),
              ),
              child: Text(
                widget.statusLabelAr!,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: widget.statusColor ?? _gold),
              ),
            ),
          if (widget.primaryActions != null) ...[
            const SizedBox(width: 12),
            ...widget.primaryActions!,
          ],
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'إجراءات إضافية',
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'print', child: Text('🖨️  طباعة')),
              PopupMenuItem(value: 'export', child: Text('📤  تصدير PDF')),
              PopupMenuItem(value: 'duplicate', child: Text('📑  نسخ')),
              PopupMenuItem(value: 'archive', child: Text('🗄️  أرشفة')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'share', child: Text('🔗  مشاركة')),
              PopupMenuItem(value: 'audit', child: Text('🔍  سجل التدقيق')),
            ],
            onSelected: (_) {},
          ),
          if (widget.chatterEntries != null)
            IconButton(
              icon: Icon(_chatterOpen ? Icons.chat : Icons.chat_bubble_outline),
              onPressed: () => setState(() => _chatterOpen = !_chatterOpen),
              tooltip: 'Chatter',
            ),
        ],
      ),
    );
  }

  // ── Process Flow Bar ────────────────────────────────────────────
  Widget _buildProcessFlowBar() {
    final stages = widget.processStages!;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(stages.length * 2 - 1, (i) {
            if (i.isOdd) {
              // Connector line
              return Container(
                width: 40,
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: (i ~/ 2) < widget.processCurrentIndex ? _gold : core_theme.AC.bdr,
              );
            }
            final stageIdx = i ~/ 2;
            final stage = stages[stageIdx];
            final isActive = stageIdx == widget.processCurrentIndex;
            final isPast = stageIdx < widget.processCurrentIndex;
            final color = isActive || isPast ? _gold : core_theme.AC.td;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? _gold : (isPast ? _gold.withValues(alpha: 0.15) : core_theme.AC.navy3),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Center(
                    child: isPast
                        ? Icon(Icons.check, size: 14, color: _gold)
                        : Text('${stageIdx + 1}',
                            style: TextStyle(
                                color: isActive ? Colors.white : color,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stage.labelAr,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                    color: isActive || isPast ? _navy : core_theme.AC.ts,
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  // ── Smart Buttons ──────────────────────────────────────────────
  Widget _buildSmartButtons() {
    final buttons = widget.smartButtons!;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: buttons
              .map((b) => Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: b.onTap,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: (b.color ?? _navy).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (b.color ?? _navy).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(b.icon, size: 14, color: b.color ?? _navy),
                            const SizedBox(width: 6),
                            Text(
                              b.count != null ? '${b.count} ${b.labelAr}' : b.labelAr,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: b.color ?? _navy,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ── Tabs Sidebar ───────────────────────────────────────────────
  Widget _buildTabsSidebar() {
    return Container(
      width: 200,
      color: Colors.white,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: widget.tabs.length,
        itemBuilder: (ctx, i) {
          final tab = widget.tabs[i];
          final active = i == _tabIndex;
          return InkWell(
            onTap: () => setState(() => _tabIndex = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: active ? _gold.withValues(alpha: 0.08) : null,
                border: BorderDirectional(
                  end: BorderSide(
                    color: active ? _gold : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(tab.icon,
                      size: 16, color: active ? _gold : core_theme.AC.ts),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tab.labelAr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active ? _navy : core_theme.AC.tp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────────
  Widget _buildContent() {
    return widget.tabs[_tabIndex].builder(context);
  }

  // ── Chatter Rail ───────────────────────────────────────────────
  Widget _buildChatterRail() {
    final entries = widget.chatterEntries!;
    return Container(
      width: 320,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: _navy.withValues(alpha: 0.04),
              border: Border(bottom: BorderSide(color: core_theme.AC.bdr)),
            ),
            child: Row(
              children: [
                Icon(Icons.chat, color: _navy, size: 16),
                SizedBox(width: 8),
                Text('المحادثات والأنشطة',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) => _ChatterItem(entry: entries[i]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: core_theme.AC.navy3,
              border: Border(top: BorderSide(color: core_theme.AC.bdr)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file, size: 18),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'اكتب رسالة...',
                      hintStyle: const TextStyle(fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: core_theme.AC.bdr),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.send, size: 18, color: _gold),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatterItem extends StatelessWidget {
  final ChatterEntry entry;
  const _ChatterItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (entry.kind) {
      ChatterKind.message => (core_theme.AC.info, Icons.chat),
      ChatterKind.activity => (core_theme.AC.warn, Icons.event_note),
      ChatterKind.logNote => (core_theme.AC.ts, Icons.note),
      ChatterKind.statusChange => (core_theme.AC.ok, Icons.trending_up),
    };
    final diff = DateTime.now().difference(entry.timestamp);
    final timeAgo = diff.inDays > 0
        ? '${diff.inDays} يوم'
        : diff.inHours > 0
            ? '${diff.inHours} ساعة'
            : '${diff.inMinutes} دقيقة';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: (entry.color ?? color).withValues(alpha: 0.15),
          child: Icon(entry.icon ?? icon, size: 14, color: entry.color ?? color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(entry.authorAr,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  Text('قبل $timeAgo',
                      style: TextStyle(fontSize: 10, color: core_theme.AC.td)),
                ],
              ),
              const SizedBox(height: 2),
              Text(entry.contentAr,
                  style: const TextStyle(fontSize: 12, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
