/// APEX Chatter — activity log + comments widget per record.
///
/// Source: Odoo 19 OWL chatter. Every record (invoice, client, journal
/// entry, ...) gets a chatter panel that shows:
///   • Timeline of activities (status changes, field edits, attachments)
///   • Comments / messages from team members
///   • Composer to add a new message or log a note
///
/// Usage:
/// ```dart
/// ApexChatter(
///   entries: [
///     ChatterEntry.system('الحالة تغيّرت: مسودة → مُرسلة', DateTime.now()),
///     ChatterEntry.message('أحمد', 'هل تمت مراجعة الفاتورة؟', DateTime.now()),
///     ChatterEntry.attachment('سارة', 'invoice.pdf', DateTime.now()),
///   ],
///   onSend: (text) async => _post(text),
/// )
/// ```
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

enum ChatterEntryKind { system, message, attachment, note }

class ChatterEntry {
  final ChatterEntryKind kind;
  final String author;
  final String content;
  final DateTime timestamp;
  final String? icon; // URL or asset path for avatar

  const ChatterEntry({
    required this.kind,
    required this.author,
    required this.content,
    required this.timestamp,
    this.icon,
  });

  factory ChatterEntry.system(String content, DateTime timestamp) =>
      ChatterEntry(
        kind: ChatterEntryKind.system,
        author: 'النظام',
        content: content,
        timestamp: timestamp,
      );

  factory ChatterEntry.message(String author, String content, DateTime timestamp) =>
      ChatterEntry(
        kind: ChatterEntryKind.message,
        author: author,
        content: content,
        timestamp: timestamp,
      );

  factory ChatterEntry.note(String author, String content, DateTime timestamp) =>
      ChatterEntry(
        kind: ChatterEntryKind.note,
        author: author,
        content: content,
        timestamp: timestamp,
      );

  factory ChatterEntry.attachment(String author, String filename, DateTime timestamp) =>
      ChatterEntry(
        kind: ChatterEntryKind.attachment,
        author: author,
        content: filename,
        timestamp: timestamp,
      );
}

class ApexChatter extends StatefulWidget {
  final List<ChatterEntry> entries;
  final Future<void> Function(String text)? onSend;
  final Future<void> Function(String text)? onLogNote;

  const ApexChatter({
    super.key,
    required this.entries,
    this.onSend,
    this.onLogNote,
  });

  @override
  State<ApexChatter> createState() => _ApexChatterState();
}

class _ApexChatterState extends State<ApexChatter> {
  final TextEditingController _ctrl = TextEditingController();
  bool _isNote = false;
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      if (_isNote && widget.onLogNote != null) {
        await widget.onLogNote!(text);
      } else if (widget.onSend != null) {
        await widget.onSend!(text);
      }
      _ctrl.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _composer(),
        const SizedBox(height: AppSpacing.md),
        ...widget.entries.map(_entry),
      ],
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.navy4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _modeTab(
                icon: Icons.chat_bubble_outline,
                label: 'إرسال رسالة',
                selected: !_isNote,
                onTap: () => setState(() => _isNote = false),
              ),
              const SizedBox(width: AppSpacing.md),
              _modeTab(
                icon: Icons.note_alt_outlined,
                label: 'تدوين ملاحظة',
                selected: _isNote,
                onTap: () => setState(() => _isNote = true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            style: TextStyle(color: AC.tp),
            decoration: InputDecoration(
              hintText: _isNote
                  ? 'ملاحظة داخلية لفريقك (لن يراها العميل)...'
                  : 'اكتب رسالتك هنا...',
              hintStyle: TextStyle(color: AC.td),
              filled: true,
              fillColor: AC.navy,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide(color: AC.navy4),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: ElevatedButton.icon(
              icon: Icon(_isNote ? Icons.save_alt : Icons.send),
              label: Text(_sending
                  ? 'جاري الإرسال...'
                  : _isNote
                      ? 'حفظ الملاحظة'
                      : 'إرسال'),
              onPressed: _sending ? null : _send,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeTab({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AC.gold.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? AC.gold : AC.navy4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? AC.gold : AC.ts),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: TextStyle(
                color: selected ? AC.gold : AC.ts,
                fontSize: AppFontSize.md,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _entry(ChatterEntry e) {
    final (bg, iconData, iconColor) = switch (e.kind) {
      ChatterEntryKind.system => (
        AC.navy3,
        Icons.settings,
        AC.cyan,
      ),
      ChatterEntryKind.message => (
        AC.navy2,
        Icons.chat_bubble,
        AC.gold,
      ),
      ChatterEntryKind.note => (
        AC.warn.withValues(alpha: 0.08),
        Icons.note_alt,
        AC.warn,
      ),
      ChatterEntryKind.attachment => (
        AC.navy2,
        Icons.attach_file,
        AC.ts,
      ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AC.navy4.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: iconColor.withValues(alpha: 0.2),
            child: Icon(iconData, size: 14, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      e.author,
                      style: TextStyle(
                        color: AC.tp,
                        fontWeight: FontWeight.w600,
                        fontSize: AppFontSize.md,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _relative(e.timestamp),
                      style: TextStyle(color: AC.td, fontSize: AppFontSize.sm),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  e.content,
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.md,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _relative(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'قبل ثوانٍ';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
