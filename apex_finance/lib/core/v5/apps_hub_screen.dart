/// APEX V5.1 — Apps Hub Screen (Odoo-style grid) — 50-wave improvements.
///
/// Reached via `/app/:service/apps` — rendered inside the service shell.
///
/// Waves applied:
///   A — Visual polish (shadows, gradients, typography, header)
///   B — UX/discoverability (filters, sort, favorites, keyboard, search UX)
///   C — A11y/i18n (Semantics, focus ring, contrast, reduced-motion)
///   D — Performance/code quality (tokens, debounce, RepaintBoundary, docs)
///   E — Responsive/RTL (adaptive grid, stagger, group sections)
library;

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart' as core_theme;
import 'module_colors.dart';
import 'v5_models.dart';

// ═══════════════════════════════════════════════════════════════════
// Design tokens — D-31/32 (no magic numbers, single source of truth)
// ═══════════════════════════════════════════════════════════════════
class _HubTokens {
  _HubTokens._();

  // Header
  static const headerHeightExpanded = 200.0;
  static const headerIconSize = 160.0;

  // Grid — E-41 responsive via maxCrossAxisExtent
  static const tileMaxExtent = 148.0;
  static const tileGap = 10.0;
  static const tilePadding = 10.0;
  static const tileRadius = 14.0;

  // Icon box
  static const iconBoxSize = 56.0;
  static const iconBoxRadius = 12.0;
  static const iconSize = 28.0;

  // Motion
  static const hoverDuration = Duration(milliseconds: 140);
  static const searchDebounce = Duration(milliseconds: 220);
  static const staggerStep = Duration(milliseconds: 22);
  static const staggerDuration = Duration(milliseconds: 360);

  // Typography
  static const fsTitle = 18.0;
  static const fsDesc = 13.5;
  static const fsLabel = 11.5;
  static const fsBadge = 9.5;
  static const fsMeta = 10.5;

  // Colors
  static const labelDark = Color(0xFF1A237E);
  static const pageBg = Color(0xFFF6F6F5);
}

// ═══════════════════════════════════════════════════════════════════
// Favorites preference — B-13 pin/unpin, persisted via localStorage
// ═══════════════════════════════════════════════════════════════════
class AppFavoritesPrefs {
  static const _key = 'apex_app_favs_v1';
  static final ValueNotifier<Set<String>> favorites =
      ValueNotifier<Set<String>>(_load());

  static Set<String> _load() {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.isEmpty) return <String>{};
      return raw.split(',').where((s) => s.isNotEmpty).toSet();
    } catch (_) {
      return <String>{};
    }
  }

  static bool isFav(String id) => favorites.value.contains(id);

  static void toggle(String id) {
    final s = {...favorites.value};
    if (!s.add(id)) s.remove(id);
    favorites.value = s;
    try {
      html.window.localStorage[_key] = s.join(',');
    } catch (_) {}
  }
}

// ═══════════════════════════════════════════════════════════════════
// View + sort modes — B-11, B-12
// ═══════════════════════════════════════════════════════════════════
enum _HubView { grid, grouped }

enum _HubSort { defaultOrder, nameAsc, chipCountDesc, favFirst }

const _sortLabels = <_HubSort, String>{
  _HubSort.defaultOrder: 'الترتيب الافتراضي',
  _HubSort.nameAsc: 'الاسم (أ ← ي)',
  _HubSort.chipCountDesc: 'الأكثر شاشات',
  _HubSort.favFirst: 'المفضّلة أولاً',
};

// ═══════════════════════════════════════════════════════════════════
// Focus / clear intents — B-17 keyboard shortcuts
// ═══════════════════════════════════════════════════════════════════
class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _ClearSearchIntent extends Intent {
  const _ClearSearchIntent();
}

// ═══════════════════════════════════════════════════════════════════
// Main screen
// ═══════════════════════════════════════════════════════════════════
class AppsHubScreen extends StatefulWidget {
  /// The service whose apps should be displayed.
  final V5Service service;

  /// When true, the screen renders as a *body only* (no Scaffold, no giant
  /// SliverAppBar header) — meant to be embedded inside ApexV5ServiceShell
  /// which already provides SystemBar + NewsTicker + ScreenBar chrome.
  final bool embedded;

  const AppsHubScreen({super.key, required this.service, this.embedded = false});

  @override
  State<AppsHubScreen> createState() => _AppsHubScreenState();
}

class _AppsHubScreenState extends State<AppsHubScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _search = '';
  Timer? _debounce;

  _HubView _view = _HubView.grid;
  _HubSort _sort = _HubSort.defaultOrder;

  @override
  void initState() {
    super.initState();
    // D-39 sanity assert
    assert(widget.service.mainModules.isNotEmpty,
        'Service ${widget.service.id} has no main modules');
    // B-18 autofocus search on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // D-34 debounced search
  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(_HubTokens.searchDebounce, () {
      if (!mounted) return;
      setState(() => _search = v.trim().toLowerCase());
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    setState(() => _search = '');
  }

  List<V5MainModule> _filteredApps() {
    final q = _search;
    var apps = widget.service.mainModules.toList(growable: true);
    if (q.isNotEmpty) {
      apps = apps
          .where((m) =>
              m.labelAr.toLowerCase().contains(q) ||
              m.labelEn.toLowerCase().contains(q) ||
              m.descriptionAr.toLowerCase().contains(q) ||
              m.id.toLowerCase().contains(q))
          .toList();
    }
    switch (_sort) {
      case _HubSort.defaultOrder:
        break;
      case _HubSort.nameAsc:
        apps.sort((a, b) => a.labelAr.compareTo(b.labelAr));
        break;
      case _HubSort.chipCountDesc:
        apps.sort((a, b) => b.chips.length.compareTo(a.chips.length));
        break;
      case _HubSort.favFirst:
        final favs = AppFavoritesPrefs.favorites.value;
        apps.sort((a, b) {
          final af = favs.contains(a.id) ? 0 : 1;
          final bf = favs.contains(b.id) ? 0 : 1;
          if (af != bf) return af.compareTo(bf);
          return a.labelAr.compareTo(b.labelAr);
        });
        break;
    }
    return apps;
  }

  Map<AppGroup, List<V5MainModule>> _byGroup(List<V5MainModule> apps) {
    final m = <AppGroup, List<V5MainModule>>{};
    for (final a in apps) {
      final g = a.group ?? AppGroup.core;
      (m[g] ??= <V5MainModule>[]).add(a);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final apps = _filteredApps();

    // Core slivers — shared between standalone and embedded modes.
    final slivers = <Widget>[
      // Standalone mode keeps the big gradient hero. Embedded mode drops
      // it because the parent shell already provides the top chrome.
      if (!widget.embedded) _header(svc),
      _searchStrip(svc, apps.length),
      ..._buildContent(svc, apps),
    ];

    final scrollable = Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _FocusSearchIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _ClearSearchIntent(),
        SingleActivator(LogicalKeyboardKey.slash): _FocusSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocus.requestFocus();
              _searchCtrl.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _searchCtrl.text.length,
              );
              return null;
            },
          ),
          _ClearSearchIntent: CallbackAction<_ClearSearchIntent>(
            onInvoke: (_) {
              if (_search.isNotEmpty || _searchCtrl.text.isNotEmpty) {
                _clearSearch();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: CustomScrollView(slivers: slivers),
        ),
      ),
    );

    if (widget.embedded) {
      // Inherit RTL direction from the shell; render flat over pageBg.
      return ColoredBox(color: _HubTokens.pageBg, child: scrollable);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _HubTokens.pageBg,
        body: scrollable,
      ),
    );
  }

  // A-6, A-7: header with 3-stop gradient + light spot + soft watermark
  SliverAppBar _header(V5Service svc) {
    return SliverAppBar.large(
      backgroundColor: svc.color,
      foregroundColor: Colors.white,
      expandedHeight: _HubTokens.headerHeightExpanded,
      pinned: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(
            start: 16, bottom: 14, end: 16),
        title: Text(
          '${svc.labelAr} — ${svc.mainModules.length} تطبيق',
          style: const TextStyle(
            color: Colors.white,
            fontSize: _HubTokens.fsTitle,
            fontWeight: FontWeight.w800,
          ),
        ),
        background: _HeaderBg(service: svc),
      ),
    );
  }

  // Search strip with toolbar
  SliverToBoxAdapter _searchStrip(V5Service svc, int resultCount) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 20, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              container: true,
              child: Text(
                svc.descriptionAr,
                style: TextStyle(
                  fontSize: _HubTokens.fsDesc,
                  color: core_theme.AC.ts,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (ctx, c) {
                final narrow = c.maxWidth < 680;
                return Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    SizedBox(
                      width: narrow ? c.maxWidth : 420,
                      child: _SearchField(
                        controller: _searchCtrl,
                        focusNode: _searchFocus,
                        onChanged: _onSearchChanged,
                        onClear: _clearSearch,
                        resultCount:
                            _search.isEmpty ? null : resultCount,
                      ),
                    ),
                    _ViewToggle(
                      view: _view,
                      onChange: (v) => setState(() => _view = v),
                    ),
                    _SortMenu(
                      sort: _sort,
                      onChange: (s) => setState(() => _sort = s),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 1,
              color: core_theme.AC.bdr.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(V5Service svc, List<V5MainModule> apps) {
    if (apps.isEmpty) {
      return <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(query: _search, onClear: _clearSearch),
        ),
      ];
    }
    if (_view == _HubView.grouped) {
      final groups = _byGroup(apps);
      final out = <Widget>[];
      var runningIndex = 0;
      for (final entry in groups.entries) {
        out.add(SliverToBoxAdapter(
          child: _GroupHeader(group: entry.key, count: entry.value.length),
        ));
        out.add(SliverPadding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
          sliver: _appsGrid(svc, entry.value, baseIndex: runningIndex),
        ));
        runningIndex += entry.value.length;
      }
      return out;
    }
    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        sliver: _appsGrid(svc, apps, baseIndex: 0),
      ),
    ];
  }

  SliverGrid _appsGrid(V5Service svc, List<V5MainModule> apps,
      {required int baseIndex}) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _HubTokens.tileMaxExtent,
        childAspectRatio: 0.92,
        mainAxisSpacing: _HubTokens.tileGap,
        crossAxisSpacing: _HubTokens.tileGap,
      ),
      // D-35 RepaintBoundary per tile
      delegate: SliverChildBuilderDelegate(
        (ctx, i) => RepaintBoundary(
          child: _AppTile(
            key: ValueKey('${svc.id}/${apps[i].id}'),
            service: svc,
            app: apps[i],
            index: baseIndex + i,
            highlight: _search,
          ),
        ),
        childCount: apps.length,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Header background — A-3/A-6/A-7 gradient + light-spot + watermark
// ═══════════════════════════════════════════════════════════════════
class _HeaderBg extends StatelessWidget {
  final V5Service service;
  const _HeaderBg({required this.service});

  @override
  Widget build(BuildContext context) {
    final c = service.color;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            c,
            Color.lerp(c, Colors.white, 0.08)!,
            Color.lerp(c, core_theme.AC.tp, 0.30)!,
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Soft light spot (top-left corner)
          const Positioned(
            top: -40,
            left: -40,
            width: 220,
            height: 220,
            child: _LightSpot(),
          ),
          // Large watermark icon (top-start corner, directional)
          Align(
            alignment: AlignmentDirectional.topStart,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Icon(
                service.icon,
                color: Colors.white.withValues(alpha: 0.12),
                size: _HubTokens.headerIconSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LightSpot extends StatelessWidget {
  const _LightSpot();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Search field — B-19 clear+count, C-21 Semantics, C-26 RTL
// ═══════════════════════════════════════════════════════════════════
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final int? resultCount;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
    this.resultCount,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        final hasText = value.text.isNotEmpty;
        return Semantics(
          label: 'بحث في التطبيقات',
          textField: true,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            textDirection: TextDirection.rtl,
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: _HubTokens.fsDesc, color: core_theme.AC.tp),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: 'ابحث في التطبيقات…  (Ctrl+F)',
              hintTextDirection: TextDirection.rtl,
              hintStyle: TextStyle(
                color: core_theme.AC.td,
                fontSize: _HubTokens.fsDesc,
              ),
              prefixIcon: Icon(Icons.search, color: core_theme.AC.ts),
              suffixIcon: hasText
                  ? IconButton(
                      tooltip: 'مسح (Esc)',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: onClear,
                    )
                  : (resultCount != null
                      ? Padding(
                          padding: const EdgeInsetsDirectional.only(end: 12),
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              '$resultCount نتيجة',
                              style: TextStyle(
                                fontSize: _HubTokens.fsMeta,
                                color: core_theme.AC.ts,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : null),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: _border(core_theme.AC.bdr),
              enabledBorder: _border(core_theme.AC.bdr),
              focusedBorder: _border(core_theme.AC.gold, 1.6),
            ),
          ),
        );
      },
    );
  }

  OutlineInputBorder _border(Color c, [double w = 1.0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
}

// ═══════════════════════════════════════════════════════════════════
// View toggle — B-11
// ═══════════════════════════════════════════════════════════════════
class _ViewToggle extends StatelessWidget {
  final _HubView view;
  final ValueChanged<_HubView> onChange;
  const _ViewToggle({required this.view, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'وضع العرض',
      child: SegmentedButton<_HubView>(
        segments: const <ButtonSegment<_HubView>>[
          ButtonSegment(
            value: _HubView.grid,
            icon: Icon(Icons.grid_view_rounded),
            label: Text('شبكة', style: TextStyle(fontSize: 12)),
          ),
          ButtonSegment(
            value: _HubView.grouped,
            icon: Icon(Icons.category_outlined),
            label: Text('مجموعات', style: TextStyle(fontSize: 12)),
          ),
        ],
        selected: <_HubView>{view},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChange(s.first),
        style: const ButtonStyle(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Sort menu — B-12
// ═══════════════════════════════════════════════════════════════════
class _SortMenu extends StatelessWidget {
  final _HubSort sort;
  final ValueChanged<_HubSort> onChange;
  const _SortMenu({required this.sort, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ترتيب التطبيقات',
      child: PopupMenuButton<_HubSort>(
        tooltip: 'ترتيب',
        initialValue: sort,
        onSelected: onChange,
        position: PopupMenuPosition.under,
        itemBuilder: (_) => <PopupMenuEntry<_HubSort>>[
          for (final e in _sortLabels.entries)
            CheckedPopupMenuItem<_HubSort>(
              value: e.key,
              checked: e.key == sort,
              child: Text(e.value, style: const TextStyle(fontSize: 13)),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: core_theme.AC.bdr),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.sort_rounded, size: 16, color: core_theme.AC.ts),
              const SizedBox(width: 6),
              Text(
                _sortLabels[sort]!,
                style: TextStyle(
                  fontSize: _HubTokens.fsMeta + 1.5,
                  color: core_theme.AC.tp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded,
                  size: 16, color: core_theme.AC.ts),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Group header — E-42
// ═══════════════════════════════════════════════════════════════════
class _GroupHeader extends StatelessWidget {
  final AppGroup group;
  final int count;
  const _GroupHeader({required this.group, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 18, 24, 6),
      child: Row(
        children: <Widget>[
          Container(
            width: 6,
            height: 20,
            decoration: BoxDecoration(
              color: _groupColor(group),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            group.labelAr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: core_theme.AC.tp,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: core_theme.AC.bdr.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                color: core_theme.AC.tp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: core_theme.AC.bdr.withValues(alpha: 0.6),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Color _groupColor(AppGroup g) => switch (g) {
        AppGroup.core => const Color(0xFFD4AF37),
        AppGroup.businessCycles => const Color(0xFF2196F3),
        AppGroup.operations => const Color(0xFF4CAF50),
        AppGroup.resources => const Color(0xFF9C27B0),
        AppGroup.output => const Color(0xFFFF9800),
      };
}

// ═══════════════════════════════════════════════════════════════════
// Empty state — B-20
// ═══════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final String query;
  final VoidCallback onClear;
  const _EmptyState({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.search_off_rounded, size: 56, color: core_theme.AC.td),
            const SizedBox(height: 12),
            Text(
              query.isEmpty
                  ? 'لا توجد تطبيقات لعرضها'
                  : 'لا توجد تطبيقات تطابق "$query"',
              textAlign: TextAlign.center,
              style: TextStyle(color: core_theme.AC.td, fontSize: 16),
            ),
            if (query.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.clear_rounded, size: 18),
                label: const Text('إلغاء البحث'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// App tile — Visual + UX + A11y + Perf + Responsive (all waves)
// ═══════════════════════════════════════════════════════════════════
class _AppTile extends StatefulWidget {
  final V5Service service;
  final V5MainModule app;
  final int index;
  final String highlight;

  const _AppTile({
    super.key,
    required this.service,
    required this.app,
    required this.index,
    required this.highlight,
  });

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile>
    with SingleTickerProviderStateMixin {
  bool _hover = false;
  bool _pressed = false;

  // Canonical app identity color — Odoo-style per-module distinction.
  Color get _appColor =>
      moduleColor(widget.app.id, fallback: widget.service.color);
  Color get _appColorDeep =>
      moduleColorDeep(widget.app.id, fallback: widget.service.color);
  LinearGradient get _appGradient =>
      moduleGradient(widget.app.id, fallback: widget.service.color);

  late final AnimationController _staggerCtrl = AnimationController(
    vsync: this,
    duration: _HubTokens.staggerDuration,
  );
  late final Animation<double> _appear = CurvedAnimation(
    parent: _staggerCtrl,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    // E-46 staggered appearance — but skip under reduced-motion (C-27)
    final reduceMotion =
        WidgetsBinding.instance.window.accessibilityFeatures.disableAnimations;
    if (reduceMotion) {
      _staggerCtrl.value = 1.0;
    } else {
      Future<void>.delayed(_HubTokens.staggerStep * widget.index, () {
        if (mounted) _staggerCtrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _staggerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final app = widget.app;
    final chipCount = app.chips.length;
    final isPlaceholder = chipCount <= 1;
    // Per-module identity color (Odoo-style) — falls back to service color.
    final appColor = moduleColor(app.id, fallback: svc.color);

    return ValueListenableBuilder<Set<String>>(
      valueListenable: AppFavoritesPrefs.favorites,
      builder: (_, favs, __) {
        final isFav = favs.contains(app.id);
        return AnimatedBuilder(
          animation: _appear,
          builder: (_, child) => Opacity(
            opacity: _appear.value,
            child: Transform.translate(
              offset: Offset(0, (1 - _appear.value) * 8),
              child: child,
            ),
          ),
          child: Semantics(
            button: true,
            label: app.labelAr,
            hint: isPlaceholder
                ? 'قيد التطوير — سيتوفر قريباً'
                : '$chipCount شاشة — اضغط Enter للفتح',
            child: Focus(
              child: Builder(builder: (ctx) {
                final focused = Focus.of(ctx).hasFocus;
                return MouseRegion(
                  onEnter: (_) => setState(() => _hover = true),
                  onExit: (_) => setState(() => _hover = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapCancel: () => setState(() => _pressed = false),
                    onTapUp: (_) => setState(() => _pressed = false),
                    onTap: () => context.go('/app/${svc.id}/${app.id}'),
                    child: _body(
                      svc: svc,
                      app: app,
                      chipCount: chipCount,
                      isPlaceholder: isPlaceholder,
                      isFav: isFav,
                      focused: focused,
                    ),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  // Body with tooltip + scale + idle/hover shadow
  Widget _body({
    required V5Service svc,
    required V5MainModule app,
    required int chipCount,
    required bool isPlaceholder,
    required bool isFav,
    required bool focused,
  }) {
    final scale = _pressed ? 0.97 : (_hover ? 1.03 : 1.0);
    return Tooltip(
      message:
          '${app.labelAr} · ${app.descriptionAr}\n$chipCount شاشة · ${app.labelEn}',
      waitDuration: const Duration(milliseconds: 500),
      preferBelow: true,
      child: AnimatedScale(
        scale: scale,
        duration: _HubTokens.hoverDuration,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: _HubTokens.hoverDuration,
          decoration: BoxDecoration(
            color: _hover
                ? _appColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(_HubTokens.tileRadius),
            border: Border.all(
              color: focused ? _appColor : Colors.transparent,
              width: focused ? 2 : 1,
            ),
            boxShadow: _hover
                ? <BoxShadow>[
                    BoxShadow(
                      color: _appColor.withValues(alpha: 0.20),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : <BoxShadow>[],
          ),
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(_HubTokens.tilePadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _iconBox(svc, app, isPlaceholder),
                    const SizedBox(height: 8),
                    Flexible(child: _label(svc, app)),
                    const SizedBox(height: 2),
                    _metaRow(chipCount, isPlaceholder),
                  ],
                ),
              ),
              if (_hover || isFav)
                PositionedDirectional(
                  top: 4,
                  end: 4,
                  child: _favButton(app.id, isFav),
                ),
              if (isPlaceholder)
                PositionedDirectional(
                  top: 4,
                  start: 4,
                  child: _comingSoonBadge(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Per-module gradient icon box (Odoo/MS365 style).
  // Gradient direction varies by app group (see module_colors.dart).
  Widget _iconBox(V5Service svc, V5MainModule app, bool isPlaceholder) {
    final c = _appColor;
    return Container(
      width: _HubTokens.iconBoxSize,
      height: _HubTokens.iconBoxSize,
      decoration: BoxDecoration(
        gradient: isPlaceholder
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color.lerp(c, Colors.grey, 0.50)!,
                  Color.lerp(c, Colors.grey, 0.65)!,
                ],
              )
            : _appGradient,
        borderRadius: BorderRadius.circular(_HubTokens.iconBoxRadius),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.withValues(alpha: _hover ? 0.42 : 0.18),
            blurRadius: _hover ? 12 : 4,
            offset: Offset(0, _hover ? 5 : 2),
          ),
        ],
      ),
      child: Icon(app.icon, color: Colors.white, size: _HubTokens.iconSize),
    );
  }

  // B-19 highlight matching substring in label
  Widget _label(V5Service svc, V5MainModule app) {
    final q = widget.highlight;
    final text = app.labelAr;
    final c = _appColor;
    final baseStyle = TextStyle(
      fontSize: _HubTokens.fsLabel,
      fontWeight: FontWeight.w700,
      color: _hover ? _appColorDeep : _HubTokens.labelDark,
      height: 1.2,
    );
    if (q.isEmpty) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(q);
    if (idx < 0) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      );
    }
    return RichText(
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: <InlineSpan>[
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + q.length),
            style: baseStyle.copyWith(
              backgroundColor: c.withValues(alpha: 0.22),
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: text.substring(idx + q.length)),
        ],
      ),
    );
  }

  // B-14 chip count meta row
  Widget _metaRow(int n, bool placeholder) {
    if (placeholder) return const SizedBox(height: 0);
    return Text(
      '$n شاشة',
      style: TextStyle(
        fontSize: _HubTokens.fsMeta,
        color: core_theme.AC.ts,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  // B-13 favorite toggle button
  Widget _favButton(String appId, bool isFav) {
    return Semantics(
      button: true,
      label: isFav ? 'إلغاء التثبيت' : 'تثبيت كمفضّل',
      child: Material(
        color: Colors.white.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        elevation: 1,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => AppFavoritesPrefs.toggle(appId),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              isFav ? Icons.push_pin : Icons.push_pin_outlined,
              size: 14,
              color: isFav ? _appColor : core_theme.AC.ts,
            ),
          ),
        ),
      ),
    );
  }

  // A-9 coming-soon badge: pill + icon + border
  Widget _comingSoonBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: core_theme.AC.warn.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: core_theme.AC.warn.withValues(alpha: 0.45),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.hourglass_empty_rounded,
                size: 9, color: core_theme.AC.warn),
            const SizedBox(width: 2),
            Text(
              'قريباً',
              style: TextStyle(
                fontSize: _HubTokens.fsBadge,
                fontWeight: FontWeight.w800,
                color: core_theme.AC.warn,
              ),
            ),
          ],
        ),
      );
}
