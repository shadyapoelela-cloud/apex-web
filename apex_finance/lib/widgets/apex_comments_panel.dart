/// APEX — Universal Comments Panel
/// ════════════════════════════════════════════════════════════════════════
/// Embeddable widget that lists + lets the current user post comments on
/// ANY APEX entity (invoice, JE, COA account, bill, period, custom).
/// Drop into any screen with:
///
///   ApexCommentsPanel(
///     objectType: 'invoice',
///     objectId: invoice.id,
///   )
///
/// @mentions: type @{user_id} — autocomplete-friendly format the backend
/// understands. Mention parsing extracts the IDs and emits
/// `mention.received` events workflow rules can route to Slack DMs etc.
///
/// Wired to the Comments backend (Wave 1E Phase U):
///   GET    /api/v1/comments?object_type=...&object_id=...
///   POST   /api/v1/comments
///   PATCH  /api/v1/comments/{id}
///   DELETE /api/v1/comments/{id}
///   POST   /api/v1/comments/{id}/react
library;

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../core/design_tokens.dart';
import '../core/session.dart';
import '../core/theme.dart';

class ApexCommentsPanel extends StatefulWidget {
  final String objectType;
  final String objectId;
  final String? title;
  final bool collapsedInitially;

  const ApexCommentsPanel({
    super.key,
    required this.objectType,
    required this.objectId,
    this.title,
    this.collapsedInitially = false,
  });

  @override
  State<ApexCommentsPanel> createState() => _ApexCommentsPanelState();
}

class _ApexCommentsPanelState extends State<ApexCommentsPanel> {
  bool _loading = true;
  bool _collapsed = false;
  String? _error;
  List<Map<String, dynamic>> _comments = [];
  final TextEditingController _composer = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.collapsedInitially;
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.commentsList(
      objectType: widget.objectType,
      objectId: widget.objectId,
      tenantId: S.tenantId,
    );
    if (!mounted) return;
    if (res.success) {
      final raw = (res.data is Map ? res.data['comments'] : null) ?? const [];
      _comments = (raw as List).cast<Map<String, dynamic>>();
    } else {
      _error = res.error ?? 'فشل تحميل التعليقات';
    }
    setState(() => _loading = false);
  }

  Future<void> _post() async {
    final body = _composer.text.trim();
    if (body.isEmpty) return;
    final uid = S.uid;
    if (uid == null || uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.warn, content: const Text('يجب تسجيل الدخول')),
      );
      return;
    }
    setState(() => _posting = true);
    final res = await ApiService.commentsAdd(
      objectType: widget.objectType,
      objectId: widget.objectId,
      authorUserId: uid,
      body: body,
      tenantId: S.tenantId,
    );
    if (!mounted) return;
    setState(() => _posting = false);
    if (res.success) {
      _composer.clear();
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
    }
  }

  Future<void> _react(Map<String, dynamic> c, String emoji) async {
    final uid = S.uid;
    if (uid == null || uid.isEmpty) return;
    final res = await ApiService.commentsReact(c['id'] as String, uid, emoji);
    if (res.success) _load();
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final uid = S.uid;
    if (uid == null || uid.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('حذف التعليق', style: TextStyle(color: AC.tp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.err),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.commentsDelete(c['id'] as String, uid);
    if (res.success && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (!_collapsed) ...[
            const Divider(height: 1, thickness: 1),
            _list(),
            const Divider(height: 1, thickness: 1),
            _composerBar(),
          ],
        ],
      ),
    );
  }

  Widget _header() {
    final count = _comments.where((c) => c['is_deleted'] != true).length;
    return InkWell(
      onTap: () => setState(() => _collapsed = !_collapsed),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(children: [
          Icon(Icons.forum_outlined, color: AC.gold, size: 18),
          const SizedBox(width: 8),
          Text(
            widget.title ?? 'التعليقات',
            style: TextStyle(
              color: AC.tp,
              fontWeight: FontWeight.w700,
              fontSize: AppFontSize.md,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AC.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'تحديث',
            iconSize: 18,
            onPressed: _load,
            icon: Icon(Icons.refresh, color: AC.ts),
          ),
          Icon(
            _collapsed ? Icons.expand_more : Icons.expand_less,
            color: AC.ts,
          ),
        ]),
      ),
    );
  }

  Widget _list() {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: AC.gold, strokeWidth: 2)),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12)),
      );
    }
    final visible = _comments.where((c) => c['is_deleted'] != true).toList();
    if (visible.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'لا توجد تعليقات بعد. كن أول من يعلّق.',
          style: TextStyle(color: AC.ts, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        itemCount: visible.length,
        itemBuilder: (ctx, i) => _commentRow(visible[i]),
      ),
    );
  }

  Widget _commentRow(Map<String, dynamic> c) {
    final author = c['author_user_id']?.toString() ?? '';
    final body = c['body']?.toString() ?? '';
    final created = c['created_at']?.toString() ?? '';
    final isMine = author == S.uid;
    final reactions = c['reactions'] is Map ? c['reactions'] as Map : const {};
    final mentioned = (c['mentioned_user_ids'] as List?)?.cast<String>() ?? const [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AC.gold.withValues(alpha: 0.2),
              child: Text(
                author.isNotEmpty ? author[0].toUpperCase() : '?',
                style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                author,
                style: TextStyle(
                  color: AC.tp,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _shortTime(created),
              style: TextStyle(color: AC.ts, fontSize: 10),
            ),
            if (isMine)
              IconButton(
                onPressed: () => _delete(c),
                iconSize: 14,
                tooltip: 'حذف',
                icon: Icon(Icons.delete_outline, color: AC.err.withValues(alpha: 0.6)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              ),
          ]),
          const SizedBox(height: 4),
          SelectableText(body, style: TextStyle(color: AC.tp, fontSize: 12)),
          if (mentioned.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                for (final uid in mentioned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AC.cyan.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text('@$uid',
                        style: TextStyle(color: AC.cyan, fontSize: 9.5, fontFamily: 'monospace')),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Row(children: [
            for (final emoji in const ['👍', '🙏', '🔥'])
              _reactionButton(c, emoji, (reactions[emoji] as List?)?.length ?? 0),
            const Spacer(),
            for (final entry in reactions.entries)
              if (!const ['👍', '🙏', '🔥'].contains(entry.key))
                _reactionTag(entry.key, (entry.value as List).length),
          ]),
        ],
      ),
    );
  }

  Widget _reactionButton(Map<String, dynamic> c, String emoji, int count) {
    return InkWell(
      onTap: () => _react(c, emoji),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        margin: const EdgeInsets.only(left: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AC.navy.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Text(
          count > 0 ? '$emoji $count' : emoji,
          style: const TextStyle(fontSize: 11),
        ),
      ),
    );
  }

  Widget _reactionTag(String emoji, int count) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AC.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text('$emoji $count', style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _composerBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _composer,
              maxLines: 3,
              minLines: 1,
              style: TextStyle(color: AC.tp, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'اكتب تعليقاً… استخدم @{user_id} للإشارة',
                hintStyle: TextStyle(color: AC.ts.withValues(alpha: 0.6), fontSize: 11),
                filled: true,
                fillColor: AC.navy3,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: _posting ? null : _post,
            icon: _posting
                ? SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AC.btnFg),
                  )
                : const Icon(Icons.send, size: 14),
            label: const Text('نشر'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  String _shortTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
      return iso.substring(0, 10);
    } catch (_) {
      return iso.substring(0, iso.length.clamp(0, 10));
    }
  }
}
