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

            // App grid — Odoo-compact size (more cols, smaller tiles)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              sliver: SliverLayoutBuilder(
                builder: (ctx, constraints) {
                  final w = constraints.crossAxisExtent;
                  final cols = w > 1600
                      ? 8
                      : w > 1300
                          ? 7
                          : w > 1100
                              ? 6
                              : w > 900
                                  ? 5
                                  : w > 700
                                      ? 4
                                      : w > 500
                                          ? 3
                                          : 2;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      childAspectRatio: 0.95,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _AppTile(
                        service: svc,
                        app: apps[i],
                      ),
                      childCount: apps.length,
                    ),
                  );
                },
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
          message: '${app.descriptionAr}\n${app.labelEn} · $chipCount شاشة',
          waitDuration: const Duration(milliseconds: 600),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            transform: _hover
                ? (Matrix4.identity()..translate(0.0, -2.0, 0.0))
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _hover ? svc.color : Colors.grey.shade200,
                width: _hover ? 1.5 : 1,
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: svc.color.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          svc.color,
                          Color.lerp(svc.color, Colors.black, 0.22)!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(app.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    app.labelAr,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A237E),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isPlaceholder
                          ? Colors.orange.withOpacity(0.10)
                          : svc.color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isPlaceholder ? 'قريباً' : '$chipCount',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isPlaceholder ? Colors.orange.shade800 : svc.color,
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
