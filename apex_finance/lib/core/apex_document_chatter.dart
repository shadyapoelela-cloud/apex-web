/// APEX — Document Chatter (Odoo activity log on any record)
/// ═══════════════════════════════════════════════════════════
/// Collapsible right-side panel that displays the activity log for
/// any document. Wraps the existing ApexChatter widget with a toggle
/// button so any screen can add it in one line:
///
///   Row(children: [
///     Expanded(child: MyDocumentDetail()),
///     ApexDocumentChatterPanel(entityType: 'journal_entry', entityId: jeId),
///   ])
///
/// The panel itself is togglable; collapsed state shows a thin
/// vertical bar with a count badge so users see activity without the
/// real estate tax.
library;

import 'package:flutter/material.dart';

import 'apex_chatter.dart';
import 'theme.dart';

class ApexDocumentChatterPanel extends StatefulWidget {
  final String entityType;
  final String entityId;
  final double widthWhenOpen;
  final bool startCollapsed;

  const ApexDocumentChatterPanel({
    super.key,
    required this.entityType,
    required this.entityId,
    this.widthWhenOpen = 320,
    this.startCollapsed = true,
  });

  @override
  State<ApexDocumentChatterPanel> createState() => _ApexDocumentChatterPanelState();
}

class _ApexDocumentChatterPanelState extends State<ApexDocumentChatterPanel>
    with SingleTickerProviderStateMixin {
  bool _collapsed = true;
  int _activityCount = 0;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.startCollapsed;
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed) return _collapsedBar();
    return _expandedPanel();
  }

  Widget _collapsedBar() {
    return InkWell(
      onTap: () => setState(() => _collapsed = false),
      child: Container(
        width: 44,
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border(right: BorderSide(color: AC.gold.withValues(alpha: 0.2))),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Icon(Icons.forum_outlined, color: AC.gold, size: 20),
            const SizedBox(height: 4),
            if (_activityCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AC.gold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('$_activityCount',
                    style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 8),
            RotatedBox(
              quarterTurns: 3,
              child: Text('السجل',
                  style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _expandedPanel() {
    return Container(
      width: widget.widthWhenOpen,
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(right: BorderSide(color: AC.gold.withValues(alpha: 0.2))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(
            child: _DocumentActivityLog(
              entityType: widget.entityType,
              entityId: widget.entityId,
              onCountChange: (n) => setState(() => _activityCount = n),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AC.gold.withValues(alpha: 0.15), AC.gold.withValues(alpha: 0.05)]),
        border: Border(bottom: BorderSide(color: AC.gold.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          Icon(Icons.forum_outlined, color: AC.gold, size: 16),
          const SizedBox(width: 8),
          Text('سجل النشاط',
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.keyboard_arrow_right, color: AC.ts, size: 18),
            onPressed: () => setState(() => _collapsed = true),
            tooltip: 'طوي',
          ),
        ],
      ),
    );
  }
}


/// Internal — renders the activity entries. Uses the existing
/// ApexChatter widget. Loads from audit trail + AI suggestions.
class _DocumentActivityLog extends StatefulWidget {
  final String entityType;
  final String entityId;
  final void Function(int) onCountChange;
  const _DocumentActivityLog({
    required this.entityType,
    required this.entityId,
    required this.onCountChange,
  });

  @override
  State<_DocumentActivityLog> createState() => _DocumentActivityLogState();
}

class _DocumentActivityLogState extends State<_DocumentActivityLog> {
  List<ChatterEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_DocumentActivityLog old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId) _load();
  }

  Future<void> _load() async {
    // Seed with a placeholder — real data fetch via ApiService.aiListAuditEvents
    // would filter by entity_type + entity_id. For now show a starter set.
    final now = DateTime.now();
    final entries = <ChatterEntry>[
      ChatterEntry.system('تم إنشاء المستند', now.subtract(const Duration(hours: 2))),
      ChatterEntry.message('مساعد الذكاء', 'صُنِّفت الحركة تلقائياً — ثقة عالية', now.subtract(const Duration(minutes: 45))),
    ];
    if (!mounted) return;
    setState(() => _entries = entries);
    widget.onCountChange(entries.length);
  }

  @override
  Widget build(BuildContext context) {
    return ApexChatter(
      entries: _entries,
      onSend: (text) async {
        setState(() {
          _entries = [
            ChatterEntry.message('أنت', text, DateTime.now()),
            ..._entries,
          ];
        });
        widget.onCountChange(_entries.length);
      },
    );
  }
}
