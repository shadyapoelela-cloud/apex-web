/// APEX Platform — "Ask APEX" slide-over panel
/// ═══════════════════════════════════════════════════════════
/// A dockable, Arabic-first natural-language Q&A surface that calls
/// POST /api/v1/ai/ask. The panel is meant to be available from ANY
/// screen — not a dedicated page — so the user never loses context.
///
/// Two surfaces:
///   • `ApexAskFab`          — a floating action button that opens the panel.
///   • `openApexAskPanel()`  — imperative API (for menu items, shortcuts).
///
/// The agent loop returns both the final answer AND the tool calls it
/// made along the way. We surface the tool calls as small breadcrumb
/// chips under the answer so the user can see "I queried March expenses
/// from the ledger" and trust the number. This is the single most
/// important UX primitive for moving users from "chatbot" to "agent."
library;

import 'package:flutter/material.dart';

import '../api_service.dart';
import 'theme.dart';

/// Public entry point — drop `ApexAskFab()` anywhere in a Scaffold's
/// floatingActionButton slot. Tapping it opens the panel.
class ApexAskFab extends StatelessWidget {
  final String? initialQuery;
  final String heroTag;
  const ApexAskFab({super.key, this.initialQuery, this.heroTag = 'apex_ask_fab'});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: () => openApexAskPanel(context, initialQuery: initialQuery),
      backgroundColor: AC.gold,
      foregroundColor: AC.btnFg,
      icon: const Icon(Icons.auto_awesome),
      label: const Text('اسأل أبكس', style: TextStyle(fontFamily: 'Tajawal')),
    );
  }
}

/// Imperative API — show the panel from a menu item, command palette,
/// or a keyboard shortcut (Ctrl+/).
Future<void> openApexAskPanel(BuildContext context, {String? initialQuery}) async {
  final width = MediaQuery.of(context).size.width;
  if (width >= 900) {
    // Desktop: slide-over on the leading side (RTL → right).
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, a1, a2) => const SizedBox.shrink(),
      transitionBuilder: (ctx, a1, a2, child) {
        final offset = Tween<Offset>(
          begin: const Offset(1.0, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a1, curve: Curves.easeOutCubic));
        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: SlideTransition(
            position: offset,
            child: _AskPanelShell(initialQuery: initialQuery, isSidebar: true),
          ),
        );
      },
    );
  } else {
    // Mobile: full-height bottom sheet.
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _AskPanelShell(initialQuery: initialQuery, isSidebar: false),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Internal widgets
// ────────────────────────────────────────────────────────────

class _AskPanelShell extends StatelessWidget {
  final String? initialQuery;
  final bool isSidebar;
  const _AskPanelShell({this.initialQuery, required this.isSidebar});

  @override
  Widget build(BuildContext context) {
    final width = isSidebar ? 420.0 : double.infinity;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: AC.navy,
        child: SafeArea(
          child: SizedBox(
            width: width,
            height: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(onClose: () => Navigator.of(context).maybePop()),
                Expanded(child: _AskBody(initialQuery: initialQuery)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(bottom: BorderSide(color: AC.gold.withValues(alpha: 0.18))),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: AC.gold, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اسأل أبكس',
                  style: TextStyle(
                    color: AC.tp,
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'مساعد ذكي يقرأ دفاترك ويجيب بالعربية',
                  style: TextStyle(
                    color: AC.ts,
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: AC.ts),
            tooltip: 'إغلاق',
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _AskBody extends StatefulWidget {
  final String? initialQuery;
  const _AskBody({this.initialQuery});

  @override
  State<_AskBody> createState() => _AskBodyState();
}

class _AskBodyState extends State<_AskBody> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final List<_Turn> _turns = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.trim().isNotEmpty) {
      _input.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final q = _input.text.trim();
    if (q.isEmpty || _loading) return;
    setState(() {
      _turns.add(_Turn.user(q));
      _loading = true;
      _input.clear();
    });
    _scrollToBottom();

    // Build multi-turn history from prior exchanges — skip the turn we
    // just added (it's the current query).
    final history = <Map<String, dynamic>>[];
    for (final t in _turns.sublist(0, _turns.length - 1)) {
      if (t.isError) continue;
      history.add({'role': t.role, 'content': t.text});
    }

    final res = await ApiService.aiAsk(q, history: history);
    if (!mounted) return;

    if (res.success && res.data != null) {
      final data = res.data['data'] ?? {};
      final top = res.data;
      if (top['success'] == false) {
        final msg = top['error']?.toString() ?? 'تعذّر الحصول على إجابة';
        setState(() => _turns.add(_Turn.error(msg)));
      } else {
        final answer = (data['answer'] ?? '').toString();
        final toolCalls = (data['tool_calls'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        setState(() => _turns.add(_Turn.assistant(answer, toolCalls)));
      }
    } else {
      setState(() => _turns.add(_Turn.error(res.error ?? 'خطأ غير معروف')));
    }

    setState(() => _loading = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _turns.isEmpty
              ? _EmptyState(onPrompt: (text) {
                  _input.text = text;
                  _send();
                })
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  itemCount: _turns.length + (_loading ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == _turns.length && _loading) {
                      return const _ThinkingBubble();
                    }
                    return _TurnBubble(turn: _turns[i]);
                  },
                ),
        ),
        _Composer(
          controller: _input,
          focus: _focus,
          loading: _loading,
          onSend: _send,
        ),
      ],
    );
  }
}

// ── Turn model ─────────────────────────────────────────────

class _Turn {
  final String role; // 'user' | 'assistant'
  final String text;
  final List<Map<String, dynamic>> toolCalls;
  final bool isError;

  _Turn._(this.role, this.text, this.toolCalls, this.isError);

  factory _Turn.user(String t) => _Turn._('user', t, const [], false);
  factory _Turn.assistant(String t, List<Map<String, dynamic>> tc) =>
      _Turn._('assistant', t, tc, false);
  factory _Turn.error(String t) => _Turn._('assistant', t, const [], true);
}

// ── Turn bubble ────────────────────────────────────────────

class _TurnBubble extends StatelessWidget {
  final _Turn turn;
  const _TurnBubble({required this.turn});

  @override
  Widget build(BuildContext context) {
    final isUser = turn.role == 'user';
    final bg = isUser
        ? AC.gold.withValues(alpha: 0.14)
        : (turn.isError ? AC.err.withValues(alpha: 0.12) : AC.navy2);
    final align = isUser ? Alignment.centerLeft : Alignment.centerRight;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(14),
      topRight: const Radius.circular(14),
      bottomLeft: Radius.circular(isUser ? 4 : 14),
      bottomRight: Radius.circular(isUser ? 14 : 4),
    );

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                turn.text.isEmpty ? '—' : turn.text,
                style: TextStyle(
                  color: turn.isError ? AC.err : AC.tp,
                  fontFamily: 'Tajawal',
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (turn.toolCalls.isNotEmpty) _ToolCallStrip(calls: turn.toolCalls),
              if (_pendingSuggestionIds(turn.toolCalls).isNotEmpty)
                _SuggestionActions(suggestionIds: _pendingSuggestionIds(turn.toolCalls)),
            ],
          ),
        ),
      ),
    );
  }

  /// Pull suggestion_ids from any tool call that created a guarded
  /// proposal (create_invoice, send_reminder). The UI shows approve /
  /// reject buttons for these without leaving the panel.
  static List<String> _pendingSuggestionIds(List<Map<String, dynamic>> calls) {
    final ids = <String>[];
    for (final c in calls) {
      final result = c['result'];
      if (result is Map && result['suggestion_id'] is String) {
        ids.add(result['suggestion_id'] as String);
      }
    }
    return ids;
  }
}

// ── Inline approve/reject actions ──────────────────────────

class _SuggestionActions extends StatefulWidget {
  final List<String> suggestionIds;
  const _SuggestionActions({required this.suggestionIds});

  @override
  State<_SuggestionActions> createState() => _SuggestionActionsState();
}

class _SuggestionActionsState extends State<_SuggestionActions> {
  final Map<String, String> _status = {}; // id → 'approved' | 'rejected'
  bool _busy = false;

  Future<void> _act(String id, {required bool approve}) async {
    setState(() => _busy = true);
    final res = approve
        ? await ApiService.aiApproveSuggestion(id)
        : await ApiService.aiRejectSuggestion(id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (res.success) {
        _status[id] = approve ? 'approved' : 'rejected';
      }
    });
    if (!res.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'تعذّر التنفيذ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // One row per pending suggestion. Usually there's exactly one, but
    // an agent that calls create_invoice + send_reminder in one turn
    // produces two — we show both.
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.suggestionIds.map(_row).toList(),
      ),
    );
  }

  Widget _row(String id) {
    final decided = _status[id];
    if (decided != null) {
      final color = decided == 'approved' ? AC.ok : AC.err;
      final label = decided == 'approved' ? 'اعتُمد ✓' : 'رُفض ✕';
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _busy ? null : () => _act(id, approve: false),
              icon: Icon(Icons.close, size: 14, color: AC.err),
              label: Text('رفض', style: TextStyle(color: AC.err, fontFamily: 'Tajawal', fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.err.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _act(id, approve: true),
              icon: const Icon(Icons.check, size: 14),
              label: const Text('اعتماد', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: AC.ok,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tool-call breadcrumbs ──────────────────────────────────

class _ToolCallStrip extends StatelessWidget {
  final List<Map<String, dynamic>> calls;
  const _ToolCallStrip({required this.calls});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: calls.map((c) {
          final name = (c['name'] ?? '').toString();
          return Tooltip(
            message: _prettyArgs(c['args']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AC.gold.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt, size: 11, color: AC.gold),
                  const SizedBox(width: 4),
                  Text(
                    _toolLabel(name),
                    style: TextStyle(
                      color: AC.tp,
                      fontFamily: 'Tajawal',
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _toolLabel(String name) {
    switch (name) {
      case 'query_financial_data':
        return 'استعلام مالي';
      case 'get_report':
        return 'تقرير';
      case 'explain_variance':
        return 'تحليل فروقات';
      case 'forecast':
        return 'توقّع';
      case 'lookup_entity':
        return 'بحث';
      case 'create_invoice':
        return 'فاتورة (مسودة)';
      case 'send_reminder':
        return 'تذكير';
      case 'generate_report':
        return 'تصدير';
      case 'categorize_transaction':
        return 'تصنيف حركة';
      default:
        return name;
    }
  }

  static String _prettyArgs(dynamic args) {
    if (args is! Map) return '';
    return args.entries
        .take(4)
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
  }
}

// ── Loading / empty states ─────────────────────────────────

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AC.gold,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'يحلّل البيانات…',
              style: TextStyle(
                color: AC.ts,
                fontFamily: 'Tajawal',
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final void Function(String) onPrompt;
  const _EmptyState({required this.onPrompt});

  static const _suggestions = <String>[
    'كم صرفنا على التسويق هذا الشهر؟',
    'اعرض قائمة الدخل لهذا الشهر',
    'ما رصيد النقدية؟',
    'قارن مصروفات التسويق بين الشهر الماضي وهذا الشهر',
    'توقّع السيولة لـ 3 أشهر قادمة',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      children: [
        Icon(Icons.auto_awesome, color: AC.gold.withValues(alpha: 0.9), size: 36),
        const SizedBox(height: 8),
        Text(
          'اسأل أي سؤال مالي',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AC.tp,
            fontFamily: 'Tajawal',
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'سيستخدم Copilot أدوات محاسبية للإجابة برقم ومصدر',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AC.ts,
            fontFamily: 'Tajawal',
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 20),
        ..._suggestions.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => onPrompt(s),
                style: OutlinedButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  foregroundColor: AC.tp,
                  side: BorderSide(color: AC.gold.withValues(alpha: 0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    s,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                  ),
                ),
              ),
            )),
      ],
    );
  }
}

// ── Composer ───────────────────────────────────────────────

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool loading;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.focus,
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(top: BorderSide(color: AC.gold.withValues(alpha: 0.16))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              enabled: !loading,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: TextStyle(
                color: AC.tp,
                fontFamily: 'Tajawal',
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'اكتب سؤالك هنا…',
                hintStyle: TextStyle(color: AC.td, fontFamily: 'Tajawal'),
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: loading ? null : onSend,
            style: FilledButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}
