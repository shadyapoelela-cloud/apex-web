/// APEX Kanban — Odoo/Trello-style drag-drop board.
///
/// Cards live in columns keyed by a status string. The widget is
/// generic: the host passes:
///   • `columns`: status → title map (ordered list)
///   • `cards`: list of items with a `status` resolver
///   • `onMove(card, newStatus)` called when a card is dropped
///
/// Each card renders via a user-supplied builder (so the same board
/// works for CRM leads, HR requests, ticket triage, etc.).
///
/// Supports horizontal scroll, empty-column drop targets, and a
/// subtle "dragging" highlight. The visuals follow the APEX theme.
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

class ApexKanbanColumn {
  final String status;
  final String title;
  final IconData? icon;
  final Color? accent;

  const ApexKanbanColumn({
    required this.status,
    required this.title,
    this.icon,
    this.accent,
  });
}

class ApexKanban<T extends Object> extends StatefulWidget {
  final List<ApexKanbanColumn> columns;
  final List<T> cards;

  /// Which column a card belongs in.
  final String Function(T card) statusOf;

  /// Render one card.
  final Widget Function(BuildContext, T card) cardBuilder;

  /// Called when user drops a card into a new column. Host must
  /// update its data source to reflect the move and return `true` on
  /// success; return `false` to reject and snap back.
  final bool Function(T card, String newStatus) onMove;

  /// Width for each column. 280 is the Trello default.
  final double columnWidth;

  const ApexKanban({
    super.key,
    required this.columns,
    required this.cards,
    required this.statusOf,
    required this.cardBuilder,
    required this.onMove,
    this.columnWidth = 280,
  });

  @override
  State<ApexKanban<T>> createState() => _ApexKanbanState<T>();
}

class _ApexKanbanState<T extends Object> extends State<ApexKanban<T>> {
  T? _dragging;
  String? _hoverTarget;

  List<T> _cardsIn(String status) =>
      widget.cards.where((c) => widget.statusOf(c) == status).toList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 560,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: widget.columns.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, i) => _column(widget.columns[i]),
      ),
    );
  }

  Widget _column(ApexKanbanColumn col) {
    final cards = _cardsIn(col.status);
    final isHover = _hoverTarget == col.status && _dragging != null;
    final accent = col.accent ?? AC.gold;
    return Semantics(
      label: '${col.title}, ${cards.length} بطاقة',
      container: true,
      child: DragTarget<T>(
        onWillAcceptWithDetails: (d) {
          setState(() => _hoverTarget = col.status);
          return widget.statusOf(d.data) != col.status;
        },
        onLeave: (_) => setState(() => _hoverTarget = null),
        onAcceptWithDetails: (d) {
          final ok = widget.onMove(d.data, col.status);
          setState(() {
            _dragging = null;
            _hoverTarget = null;
          });
          if (!ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('لم يُقبل النقل'),
                  duration: Duration(seconds: 2)),
            );
          }
        },
        builder: (ctx, __, ___) => Container(
          width: widget.columnWidth,
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
                color: isHover ? accent : AC.bdr, width: isHover ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(col, cards.length, accent),
              const Divider(height: 1),
              Expanded(
                child: cards.isEmpty
                    ? _empty(isHover, accent)
                    : ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        itemCount: cards.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (_, i) => _draggableCard(cards[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(ApexKanbanColumn col, int count, Color accent) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(children: [
          if (col.icon != null) ...[
            Icon(col.icon, size: 16, color: accent),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(col.title,
                style: TextStyle(
                    color: AC.tp,
                    fontWeight: FontWeight.w700,
                    fontSize: AppFontSize.base)),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: accent,
                    fontSize: AppFontSize.xs,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _empty(bool isHover, Color accent) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            isHover ? 'أفلت هنا' : 'لا بطاقات',
            style: TextStyle(
                color: isHover ? accent : AC.td,
                fontSize: AppFontSize.sm,
                fontStyle: FontStyle.italic),
          ),
        ),
      );

  Widget _draggableCard(T card) {
    return LongPressDraggable<T>(
      data: card,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => setState(() => _dragging = card),
      onDragEnd: (_) => setState(() {
        _dragging = null;
        _hoverTarget = null;
      }),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.9,
          child: SizedBox(
            width: widget.columnWidth - AppSpacing.md * 2,
            child: widget.cardBuilder(context, card),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: widget.cardBuilder(context, card),
      ),
      child: widget.cardBuilder(context, card),
    );
  }
}
