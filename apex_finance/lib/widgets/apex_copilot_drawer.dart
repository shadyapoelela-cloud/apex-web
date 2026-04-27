/// APEX — In-screen AI Copilot drawer.
///
/// Scaffold endDrawer that opens from the visual LEFT in RTL (matches the
/// "ذكاء" button position in `ApexListToolbar`). The drawer carries
/// `screenName` and `screenContext` so the assistant can ground its
/// answers in what the user is actually looking at — number of records,
/// active filters, current grouping, etc.
///
/// Wave 1 ships the UX shell with a canned response that summarises the
/// passed context. Wave 2 wires the input to the Anthropic API via the
/// backend's `/api/v1/copilot` endpoint with streaming.
library;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Single chat message — user or assistant.
class _CopilotMsg {
  final String role; // 'user' | 'assistant'
  final String text;
  final DateTime at;
  _CopilotMsg(this.role, this.text, [DateTime? at])
      : at = at ?? DateTime.now();
}

class ApexCopilotDrawer extends StatefulWidget {
  /// e.g. "فواتير المبيعات".
  final String screenName;

  /// Snapshot of relevant screen state — total count, visible count,
  /// active filters, grouping, sort, etc. The assistant uses this to
  /// answer "what am I looking at?" without an extra round-trip.
  final Map<String, dynamic> screenContext;

  const ApexCopilotDrawer({
    super.key,
    required this.screenName,
    required this.screenContext,
  });

  @override
  State<ApexCopilotDrawer> createState() => _ApexCopilotDrawerState();
}

class _ApexCopilotDrawerState extends State<ApexCopilotDrawer> {
  final _inputCtl = TextEditingController();
  final _scrollCtl = ScrollController();
  final List<_CopilotMsg> _messages = [];
  bool _thinking = false;

  @override
  void initState() {
    super.initState();
    // Welcome message + automatic context summary so the user knows
    // the assistant is grounded in this screen.
    _messages.add(_CopilotMsg('assistant', _welcomeText()));
  }

  String _welcomeText() {
    final ctx = widget.screenContext;
    final lines = <String>[
      'مرحباً 👋 أنا ذكاء — مساعدك في "${widget.screenName}".',
      '',
      '**ما أراه على الشاشة الآن:**',
    ];
    if (ctx['totalCount'] is int) {
      final t = ctx['totalCount'];
      final v = ctx['visibleCount'] ?? t;
      lines.add('• عدد السجلات: $v / $t');
    }
    if (ctx['filters'] is Map) {
      final f = ctx['filters'] as Map;
      final active = f.entries
          .where((e) =>
              e.value != null &&
              e.value != 'all' &&
              e.value != 'none' &&
              e.value != '' &&
              !(e.value is List && (e.value as List).isEmpty))
          .toList();
      if (active.isNotEmpty) {
        lines.add('• الفلاتر النشطة: ${active.length}');
      }
    }
    if (ctx['groupBy'] is String && ctx['groupBy'] != 'none') {
      lines.add('• التجميع: ${ctx['groupBy']}');
    }
    lines.addAll([
      '',
      '**يمكنك أن تسألني:**',
      '• ملخّص أداء هذا الشهر',
      '• أعلى ٥ من المبالغ',
      '• اقتراحات لتحسين السيولة',
      '• أين الفواتير المتأخرة؟',
    ]);
    return lines.join('\n');
  }

  @override
  void dispose() {
    _inputCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _inputCtl.text.trim();
    if (text.isEmpty || _thinking) return;
    setState(() {
      _messages.add(_CopilotMsg('user', text));
      _inputCtl.clear();
      _thinking = true;
    });
    _scrollToBottom();

    // Wave 1 placeholder. Wave 2 will replace this with a streaming call
    // to /api/v1/copilot using ApiService.copilotChat(question, context).
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _messages.add(_CopilotMsg(
        'assistant',
        _placeholderResponse(text),
      ));
      _thinking = false;
    });
    _scrollToBottom();
  }

  String _placeholderResponse(String userQ) {
    return 'سؤالك: "$userQ"\n\n'
        '⚙️ التكامل الحقيقي مع Claude API قيد التطوير في الموجة ٢.\n\n'
        'في هذه الأثناء، يمكنك زيارة Ask APEX الكامل من '
        'القائمة الجانبية للحصول على إجابات مفصّلة.';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients) {
        _scrollCtl.animateTo(
          _scrollCtl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─── UI ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        backgroundColor: AC.navy,
        width: 460,
        shape: const RoundedRectangleBorder(),
        child: Column(
          children: [
            _header(),
            Divider(height: 1, color: AC.bdr),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtl,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length + (_thinking ? 1 : 0),
                itemBuilder: (_, i) {
                  if (_thinking && i == _messages.length) return _thinkingBubble();
                  return _msgBubble(_messages[i]);
                },
              ),
            ),
            Divider(height: 1, color: AC.bdr),
            _inputBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AC.purple.withValues(alpha: 0.18),
            AC.purple.withValues(alpha: 0.06),
          ],
        ),
        border: Border(bottom: BorderSide(color: AC.bdr)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AC.purple.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AC.purple.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: AC.purple, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('ذكاء',
                    style: TextStyle(
                      color: AC.purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 2),
                Text(widget.screenName,
                    style: TextStyle(color: AC.ts, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إغلاق',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.close_rounded, color: AC.ts, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _msgBubble(_CopilotMsg m) {
    final isUser = m.role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AC.purple.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: AC.purple, size: 12),
            ),
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: isUser
                    ? AC.gold.withValues(alpha: 0.12)
                    : AC.navy2,
                border: Border.all(
                  color: isUser
                      ? AC.gold.withValues(alpha: 0.35)
                      : AC.bdr,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft:
                      isUser ? const Radius.circular(12) : Radius.zero,
                  bottomRight:
                      isUser ? Radius.zero : const Radius.circular(12),
                ),
              ),
              child: SelectableText(
                m.text,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: AC.tp,
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thinkingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AC.purple.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.auto_awesome_rounded,
                color: AC.purple, size: 12),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AC.navy2,
              border: Border.all(color: AC.bdr),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AC.purple),
                ),
                const SizedBox(width: 8),
                Text('يفكّر…',
                    style: TextStyle(color: AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      color: AC.navy2,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputCtl,
              textDirection: TextDirection.rtl,
              minLines: 1,
              maxLines: 4,
              style: TextStyle(color: AC.tp, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'اسأل عن البيانات…',
                hintStyle: TextStyle(color: AC.td, fontSize: 12.5),
                filled: true,
                fillColor: AC.navy3,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AC.bdr),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AC.bdr),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AC.purple, width: 1.4),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: _thinking ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AC.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Icon(Icons.send_rounded, size: 16),
          ),
        ],
      ),
    );
  }
}
