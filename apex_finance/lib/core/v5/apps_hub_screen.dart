/// APEX V5.1 — Apps Hub Screen (Odoo-style grid).
///
/// Shows all V5MainModules (apps) for a given service as tiles.
/// Replaces the flat chip list with a proper app-grid UX matching
/// Odoo / NetSuite / SAP Fiori patterns.
///
/// Reached via `/app/:service/apps` — rendered inside the service shell.
///
/// Each tile shows:
///   - Icon (service-colored)
///   - Arabic label + English label
///   - Short description
///   - Chip count badge
///   - Hover state with slight lift + border glow
///
/// Tapping a tile navigates to `/app/:service/:main` which in turn
/// redirects to the app's dashboard (first chip).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'v5_models.dart';

class AppsHubScreen extends StatefulWidget {
  /// The service whose apps should be displayed.
  final V5Service service;

  const AppsHubScreen({super.key, required this.service});

  @override
  State<AppsHubScreen> createState() => _AppsHubScreenState();
}

class _AppsHubScreenState extends State<AppsHubScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final q = _search.trim().toLowerCase();
    final apps = q.isEmpty
        ? svc.mainModules
        : svc.mainModules.where((m) {
            return m.labelAr.toLowerCase().contains(q) ||
                m.labelEn.toLowerCase().contains(q) ||
                m.descriptionAr.toLowerCase().contains(q) ||
                m.id.toLowerCase().contains(q);
          }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              backgroundColor: svc.color,
              foregroundColor: Colors.white,
              expandedHeight: 180,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 14, end: 16),
                title: Text(
                  '${svc.labelAr} — ${svc.mainModules.length} تطبيق',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                background: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        svc.color,
                        Color.lerp(svc.color, Colors.black, 0.3)!,
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Icon(
                        svc.icon,
                        color: Colors.white.withOpacity(0.12),
                        size: 140,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Search + description strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      svc.descriptionAr,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SearchField(
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ],
                ),
              ),
            ),

            // App grid — Odoo Apps launcher size (very compact, fixed ~120px tile)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 130,  // Max tile width ~130px
                  childAspectRatio: 1.0,    // Square tiles
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _AppTile(
                    service: svc,
                    app: apps[i],
                  ),
                  childCount: apps.length,
                ),
              ),
            ),

            if (apps.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'لا توجد تطبيقات تطابق بحثك',
                      style: TextStyle(color: Colors.black45, fontSize: 16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: TextField(
        onChanged: onChanged,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'ابحث في التطبيقات...',
          hintTextDirection: TextDirection.rtl,
          prefixIcon: const Icon(Icons.search, color: Colors.black54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _AppTile extends StatefulWidget {
  final V5Service service;
  final V5MainModule app;

  const _AppTile({required this.service, required this.app});

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final svc = widget.service;
    final app = widget.app;
    final chipCount = app.chips.length;
    final isPlaceholder = chipCount <= 1;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => context.go('/app/${svc.id}/${app.id}'),
        child: Tooltip(
          message: '${app.labelAr} · ${app.descriptionAr}\n$chipCount شاشة · ${app.labelEn}',
          waitDuration: const Duration(milliseconds: 500),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: _hover ? svc.color.withOpacity(0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Big rounded-square icon — Odoo signature style
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          svc.color,
                          Color.lerp(svc.color, Colors.black, 0.20)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _hover
                          ? [
                              BoxShadow(
                                color: svc.color.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    child: Icon(app.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: Text(
                      app.labelAr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _hover ? svc.color : const Color(0xFF1A237E),
                        height: 1.15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (isPlaceholder)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'قريباً',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
