/// APEX — Unified List Shell
/// ═══════════════════════════════════════════════════════════════════════
/// One shell for every list/index screen across APEX. Enforces:
///   • Page header (title + subtitle + actions)
///   • Filter chips row
///   • Sticky empty state when no rows
///   • Pull-to-refresh on mobile
///   • Pagination footer (50 rows/page default)
///   • Primary CTA on trailing edge (RTL: leading visually = LEFT)
///
/// Usage:
///   ApexListShell(
///     title: 'الفواتير',
///     subtitle: '12 صادرة · 3 مسوّدات',
///     primaryCta: ApexCta(label: 'فاتورة جديدة', icon: Icons.add, onPressed: …),
///     onRefresh: _load,
///     filterChips: [ApexFilterChip(...)],
///     items: _invoices,
///     itemBuilder: (ctx, inv) => InvoiceRow(inv),
///     emptyState: ApexEmptyState(
///       icon: Icons.receipt_long,
///       title: 'لا توجد فواتير بعد',
///       description: 'ابدأ بإصدار فاتورتك الأولى',
///       primaryCta: ApexCta(label: 'فاتورة جديدة', onPressed: …),
///     ),
///   )
library;

import 'package:flutter/material.dart';

import 'apex_empty_state.dart';
import 'theme.dart';

class ApexCta {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool destructive;
  const ApexCta({
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.destructive = false,
  });
}

class ApexFilterChip {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;
  const ApexFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.count,
  });
}

class ApexListShell<T> extends StatefulWidget {
  final String title;
  final String? subtitle;
  final ApexCta? primaryCta;
  final List<Widget> headerActions;
  final List<ApexFilterChip> filterChips;
  final List<T> items;
  final Widget Function(BuildContext, T) itemBuilder;
  final ApexEmptyState emptyState;
  final Future<void> Function()? onRefresh;
  final bool loading;
  final String? error;
  final int pageSize;
  final Widget? listHeader;
  final Widget? listFooter;
  final Widget? trailingFloatingActionButton;

  const ApexListShell({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    required this.emptyState,
    this.subtitle,
    this.primaryCta,
    this.headerActions = const [],
    this.filterChips = const [],
    this.onRefresh,
    this.loading = false,
    this.error,
    this.pageSize = 50,
    this.listHeader,
    this.listFooter,
    this.trailingFloatingActionButton,
  });

  @override
  State<ApexListShell<T>> createState() => _ApexListShellState<T>();
}

class _ApexListShellState<T> extends State<ApexListShell<T>> {
  int _page = 0;

  int get _totalPages =>
      (widget.items.length / widget.pageSize).ceil().clamp(1, 999);
  List<T> get _pageItems {
    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize).clamp(0, widget.items.length);
    return widget.items.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: _buildAppBar(),
      body: Column(children: [
        if (widget.filterChips.isNotEmpty) _buildFilterRow(),
        if (widget.error != null) _buildErrorBanner(),
        Expanded(child: _buildBody()),
        if (widget.items.length > widget.pageSize) _buildPagination(),
      ]),
      floatingActionButton: widget.trailingFloatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      // ↑ startFloat = bottom-trailing (RTL: bottom-LEFT, LTR: bottom-right)
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AC.navy2,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              style: TextStyle(
                  color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          if (widget.subtitle != null)
            Text(widget.subtitle!,
                style: TextStyle(color: AC.ts, fontSize: 11.5)),
        ],
      ),
      actions: [
        ...widget.headerActions,
        if (widget.primaryCta != null) _ctaButton(widget.primaryCta!),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _ctaButton(ApexCta cta) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 8),
      child: cta.loading
          ? Container(
              width: 36,
              alignment: Alignment.center,
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AC.gold)),
            )
          : ElevatedButton.icon(
              onPressed: cta.onPressed,
              icon: cta.icon == null ? const SizedBox.shrink() : Icon(cta.icon, size: 16),
              label: Text(cta.label),
              style: ElevatedButton.styleFrom(
                backgroundColor: cta.destructive ? AC.err : AC.gold,
                foregroundColor: cta.destructive ? Colors.white : AC.navy,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
    );
  }

  Widget _buildFilterRow() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AC.navy2,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: widget.filterChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final chip = widget.filterChips[i];
          return InkWell(
            onTap: chip.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: chip.selected ? AC.gold : AC.navy3,
                border: Border.all(
                    color: chip.selected ? AC.gold : AC.bdr),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (chip.icon != null) ...[
                  Icon(chip.icon, size: 14,
                      color: chip.selected ? AC.navy : AC.ts),
                  const SizedBox(width: 4),
                ],
                Text(chip.label,
                    style: TextStyle(
                        color: chip.selected ? AC.navy : AC.tp,
                        fontSize: 11.5,
                        fontWeight: chip.selected ? FontWeight.w700 : FontWeight.w500)),
                if (chip.count != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: (chip.selected ? AC.navy : AC.gold)
                          .withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('${chip.count}',
                        style: TextStyle(
                            color: chip.selected ? AC.navy : AC.gold,
                            fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: AC.err.withValues(alpha: 0.10),
      child: Row(children: [
        Icon(Icons.error_outline, color: AC.err, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(widget.error!,
            style: TextStyle(color: AC.err, fontSize: 12))),
        if (widget.onRefresh != null)
          TextButton(
            onPressed: widget.onRefresh,
            child: Text('إعادة المحاولة', style: TextStyle(color: AC.err)),
          ),
      ]),
    );
  }

  Widget _buildBody() {
    if (widget.loading && widget.items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AC.gold));
    }
    if (widget.items.isEmpty) {
      return Center(child: widget.emptyState);
    }
    final list = ListView.separated(
      itemCount: _pageItems.length + (widget.listHeader != null ? 1 : 0)
          + (widget.listFooter != null ? 1 : 0),
      separatorBuilder: (_, __) =>
          Divider(color: AC.bdr.withValues(alpha: 0.5), height: 1),
      itemBuilder: (ctx, i) {
        var idx = i;
        if (widget.listHeader != null) {
          if (i == 0) return widget.listHeader!;
          idx--;
        }
        if (widget.listFooter != null && idx == _pageItems.length) {
          return widget.listFooter!;
        }
        return widget.itemBuilder(ctx, _pageItems[idx]);
      },
    );
    if (widget.onRefresh == null) return list;
    return RefreshIndicator(onRefresh: widget.onRefresh!, child: list);
  }

  Widget _buildPagination() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(top: BorderSide(color: AC.bdr)),
      ),
      child: Row(children: [
        Text('${_page * widget.pageSize + 1}–'
            '${((_page + 1) * widget.pageSize).clamp(0, widget.items.length)}'
            ' من ${widget.items.length}',
            style: TextStyle(color: AC.ts, fontSize: 11)),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.chevron_right, color: AC.gold, size: 18),
          tooltip: 'السابق',
          onPressed: _page > 0 ? () => setState(() => _page--) : null,
        ),
        Text('${_page + 1} / $_totalPages',
            style: TextStyle(color: AC.tp, fontSize: 11.5)),
        IconButton(
          icon: Icon(Icons.chevron_left, color: AC.gold, size: 18),
          tooltip: 'التالي',
          onPressed: _page < _totalPages - 1 ? () => setState(() => _page++) : null,
        ),
      ]),
    );
  }
}
