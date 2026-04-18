/// APEX V5.1 — Service Switcher (9-dots popup).
///
/// Like Office 365 / Zoho One / SAP Fiori — one button (top-left)
/// opens a grid of the 5 services. Current service is highlighted.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'v5_data.dart';
import 'v5_models.dart';

class ApexV5ServiceSwitcher extends StatelessWidget {
  /// The id of the current service (if any) so it's highlighted.
  final String? currentServiceId;

  const ApexV5ServiceSwitcher({super.key, this.currentServiceId});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'التبديل بين خدمات APEX',
      icon: const Icon(Icons.apps, size: 22),
      onPressed: () => _openPicker(context),
    );
  }

  void _openPicker(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (ctx) => _ServicePickerDialog(currentServiceId: currentServiceId),
    );
  }
}

class _ServicePickerDialog extends StatelessWidget {
  final String? currentServiceId;

  const _ServicePickerDialog({this.currentServiceId});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Material(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surface,
          elevation: 12,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.apps, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'خدمات APEX',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'اختر خدمة للانتقال إليها · ⌘+Shift+K',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: 20),
                // Grid of services — 3 per row on wide screens, 2 on narrow.
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final crossAxis = constraints.maxWidth > 520 ? 3 : 2;
                    return GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: crossAxis,
                      childAspectRatio: 1.4,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (int i = 0; i < v5Services.length; i++)
                          _ServiceTile(
                            service: v5Services[i],
                            isActive: v5Services[i].id == currentServiceId,
                            shortcutNumber: i + 1,
                            onTap: () {
                              Navigator.of(context).pop();
                              context.go('/app/${v5Services[i].id}');
                            },
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.keyboard, size: 16, color: Colors.black54),
                      const SizedBox(width: 8),
                      Text(
                        'اختصار: Alt+1..5 للانتقال السريع · ⌘K لـ Command Palette',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatefulWidget {
  final V5Service service;
  final bool isActive;
  final int shortcutNumber;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.service,
    required this.isActive,
    required this.shortcutNumber,
    required this.onTap,
  });

  @override
  State<_ServiceTile> createState() => _ServiceTileState();
}

class _ServiceTileState extends State<_ServiceTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.service.color;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isActive
                ? color.withOpacity(0.12)
                : _hover
                    ? color.withOpacity(0.06)
                    : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isActive ? color : color.withOpacity(_hover ? 0.4 : 0.15),
              width: widget.isActive ? 2 : 1,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.service.icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.service.labelAr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: widget.isActive ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.service.descriptionAr,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              // Shortcut number (top-right corner)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Alt+${widget.shortcutNumber}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
