/// APEX V5.1 — Workspace Selector (Level -1).
///
/// Role-based bundle of shortcuts across services.
/// Inspired by SAP Fiori Spaces — each workspace = curated view.
library;

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;
import 'package:go_router/go_router.dart';

import 'v5_data.dart';
import 'v5_models.dart';

class ApexV5WorkspaceSelector extends StatefulWidget {
  /// Currently selected workspace id (persisted in prefs in production).
  final String initialWorkspaceId;

  final ValueChanged<V5Workspace>? onChanged;

  const ApexV5WorkspaceSelector({
    super.key,
    this.initialWorkspaceId = 'accountant',
    this.onChanged,
  });

  @override
  State<ApexV5WorkspaceSelector> createState() =>
      _ApexV5WorkspaceSelectorState();
}

class _ApexV5WorkspaceSelectorState extends State<ApexV5WorkspaceSelector> {
  late String _currentId;

  @override
  void initState() {
    super.initState();
    _currentId = widget.initialWorkspaceId;
  }

  V5Workspace get _current =>
      v5Workspaces.firstWhere((w) => w.id == _currentId,
          orElse: () => v5Workspaces.first);

  @override
  Widget build(BuildContext context) {
    final ws = _current;
    return PopupMenuButton<String>(
      tooltip: 'اختيار بيئة العمل',
      position: PopupMenuPosition.under,
      onSelected: (id) {
        setState(() => _currentId = id);
        final picked = v5Workspaces.firstWhere((w) => w.id == id);
        widget.onChanged?.call(picked);
      },
      itemBuilder: (ctx) => [
        for (final w in v5Workspaces)
          PopupMenuItem<String>(
            value: w.id,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: w.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(w.icon, color: w.color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.labelAr,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${w.shortcuts.length} اختصارات',
                        style: TextStyle(
                          fontSize: 11,
                          color: core_theme.AC.ts,
                        ),
                      ),
                    ],
                  ),
                ),
                if (w.id == _currentId)
                  Icon(Icons.check, color: w.color, size: 18),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: ws.color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ws.color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ws.icon, size: 16, color: ws.color),
            const SizedBox(width: 8),
            Text(
              ws.labelAr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ws.color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: ws.color),
          ],
        ),
      ),
    );
  }
}

/// Workspace Home — grid of shortcuts for the selected workspace.
class ApexV5WorkspaceHome extends StatelessWidget {
  final V5Workspace workspace;

  const ApexV5WorkspaceHome({super.key, required this.workspace});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: workspace.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(workspace.icon, color: workspace.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workspace.labelAr,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workspace.descriptionAr,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: core_theme.AC.ts,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Shortcuts grid
          Text(
            'الاختصارات المفضّلة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final crossAxis = constraints.maxWidth > 900
                  ? 4
                  : constraints.maxWidth > 600
                      ? 3
                      : 2;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: crossAxis,
                childAspectRatio: 2.4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final s in workspace.shortcuts)
                    _ShortcutCard(shortcut: s, color: workspace.color),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatefulWidget {
  final V5Shortcut shortcut;
  final Color color;

  const _ShortcutCard({required this.shortcut, required this.color});

  @override
  State<_ShortcutCard> createState() => _ShortcutCardState();
}

class _ShortcutCardState extends State<_ShortcutCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(widget.shortcut.route),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hover
                ? widget.color.withOpacity(0.08)
                : core_theme.AC.tp.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.color.withOpacity(_hover ? 0.3 : 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(widget.shortcut.icon,
                    color: widget.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.shortcut.labelAr,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.shortcut.route,
                      style: TextStyle(
                        fontSize: 10,
                        color: core_theme.AC.td,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_back_ios, // RTL: pointing left = forward
                  size: 14, color: core_theme.AC.td),
            ],
          ),
        ),
      ),
    );
  }
}
