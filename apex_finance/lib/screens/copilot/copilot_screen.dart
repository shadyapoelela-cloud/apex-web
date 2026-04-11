import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class CopilotScreen extends StatefulWidget {
  final String? clientId;
  const CopilotScreen({super.key, this.clientId});
  @override State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  String? _sessionId;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  Map<String, dynamic>? _lastIntent;
  List<Map<String, dynamic>> _nextActions = [];

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final res = await ApiService.copilotCreateSession(clientId: widget.clientId);
    if (res.success && res.data != null) {
      setState(() => _sessionId = res.data['data']?['id'] ?? res.data['id']);
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _loading = true;
      _controller.clear();
    });
    _scrollToBottom();

    final res = await ApiService.copilotChat(
      message: text, sessionId: _sessionId, clientId: widget.clientId,
    );
    setState(() => _loading = false);

    if (res.success && res.data != null) {
      final data = res.data['data'] ?? res.data;
      final msg = data['message'] ?? {};
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': msg['content'] ?? '',
          'confidence': msg['confidence'],
          'risk_level': msg['risk_level'],
          'intent': msg['intent'],
          'references': msg['references'],
          'escalation': msg['escalation'],
        });
        _lastIntent = data['intent'];
        _nextActions = List<Map<String, dynamic>>.from(msg['next_actions'] ?? []);
        _sessionId ??= data['session_id'];
      });
    } else {
      setState(() => _messages.add({'role': 'assistant', 'content': res.error ?? 'حدث خطأ'}));
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.smart_toy, color: AC.gold, size: 20),
          ),
          const SizedBox(width: 10),
          Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Text('AI', style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
        actions: [
          if (_lastIntent != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Chip(
                label: Text(_lastIntent!['intent'] ?? '', style: TextStyle(color: AC.tp, fontSize: 10)),
                backgroundColor: AC.navy3,
                side: BorderSide(color: AC.gold.withValues(alpha: 0.3)),
              ),
            ),
          IconButton(icon: Icon(Icons.refresh, color: AC.ts), onPressed: () {
            setState(() { _messages.clear(); _sessionId = null; _nextActions.clear(); _lastIntent = null; });
            _initSession();
          }),
        ],
      ),
      body: Column(children: [
        // Messages
        Expanded(
          child: _messages.isEmpty ? _buildWelcome() : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length) return _buildTypingIndicator();
              return _buildMessage(_messages[i]);
            },
          ),
        ),
        // Next Actions
        if (_nextActions.isNotEmpty) _buildNextActions(),
        // Input
        _buildInput(),
      ]),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AC.gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.smart_toy, color: AC.gold, size: 48),
          ),
          const SizedBox(height: 20),
          Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            '\u0645\u0633\u0627\u0639\u062f\u0643 \u0627\u0644\u0630\u0643\u064a \u0644\u0644\u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0627\u0644\u064a \u0648\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0648\u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644',
            style: TextStyle(color: AC.ts, fontSize: 14),
          ),
          const SizedBox(height: 30),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            _quickAction('\u062a\u062d\u0644\u064a\u0644 \u0645\u0627\u0644\u064a', Icons.analytics),
            _quickAction('\u0631\u0641\u0639 \u0634\u062c\u0631\u0629 \u062d\u0633\u0627\u0628\u0627\u062a', Icons.account_tree),
            _quickAction('\u0641\u062d\u0635 \u0627\u0645\u062a\u062b\u0627\u0644', Icons.verified),
            _quickAction('\u0645\u0631\u0627\u062c\u0639\u0629 \u0645\u062d\u0627\u0633\u0628\u064a\u0629', Icons.checklist),
            _quickAction('\u062c\u0627\u0647\u0632\u064a\u0629 \u062a\u0645\u0648\u064a\u0644', Icons.account_balance),
            _quickAction('\u0628\u062d\u062b \u0645\u0639\u0631\u0641\u064a', Icons.search),
          ]),
        ]),
      ),
    );
  }

  Widget _quickAction(String label, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, color: AC.gold, size: 16),
      label: Text(label, style: TextStyle(color: AC.tp, fontSize: 12)),
      backgroundColor: AC.navy3,
      side: BorderSide(color: AC.bdr),
      onPressed: () { _controller.text = label; _sendMessage(); },
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? AC.gold.withValues(alpha: 0.15) : AC.navy3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isUser ? AC.gold.withValues(alpha: 0.3) : AC.bdr),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(msg['content'] ?? '', style: TextStyle(color: AC.tp, fontSize: 14, height: 1.5), textDirection: TextDirection.rtl),
          if (!isUser && msg['confidence'] != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              _metaBadge('\u062b\u0642\u0629: %',
                (msg['confidence'] as num) > 0.7 ? AC.ok : (msg['confidence'] as num) > 0.5 ? AC.warn : AC.err),
              const SizedBox(width: 6),
              if (msg['risk_level'] != null) _metaBadge(
                '\u062e\u0637\u0631: ',
                msg['risk_level'] == 'high' ? AC.err : msg['risk_level'] == 'medium' ? AC.warn : AC.ok,
              ),
              if (msg['intent'] != null) ...[
                const SizedBox(width: 6),
                _metaBadge(msg['intent'], AC.cyan),
              ],
            ]),
          ],
          if (!isUser && msg['references'] != null && (msg['references'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 4, children: (msg['references'] as List).map<Widget>((r) =>
              Chip(label: Text('', style: TextStyle(color: AC.tp, fontSize: 9)),
                backgroundColor: AC.navy4, side: BorderSide(color: AC.cyan.withValues(alpha: 0.3)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ).toList()),
          ],
          if (!isUser && msg['escalation'] != null && msg['escalation']['needed'] == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AC.warn.withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(Icons.warning_amber, color: AC.warn, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text('\u064a\u0646\u0635\u062d \u0628\u0645\u0631\u0627\u062c\u0639\u0629 \u0628\u0634\u0631\u064a\u0629 \u0644\u0647\u0630\u0647 \u0627\u0644\u0646\u062a\u064a\u062c\u0629', style: TextStyle(color: AC.warn, fontSize: 11))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _metaBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  Widget _buildTypingIndicator() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AC.gold)),
        const SizedBox(width: 10),
        Text('\u062c\u0627\u0631\u064a \u0627\u0644\u062a\u062d\u0644\u064a\u0644...', style: TextStyle(color: AC.ts, fontSize: 13)),
      ]),
    ),
  );

  Widget _buildNextActions() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    color: AC.navy2,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: _nextActions.map((a) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: ActionChip(
          avatar: Icon(_getIcon(a['icon'] ?? ''), color: AC.gold, size: 15),
          label: Text(a['label'] ?? '', style: TextStyle(color: AC.tp, fontSize: 11)),
          backgroundColor: AC.navy3, side: BorderSide(color: AC.gold.withValues(alpha: 0.3)),
          onPressed: () { _controller.text = a['label'] ?? ''; _sendMessage(); },
        ),
      )).toList()),
    ),
  );

  Widget _buildInput() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AC.navy2, border: Border(top: BorderSide(color: AC.bdr))),
    child: Row(children: [
      Expanded(child: TextField(
        controller: _controller,
        style: TextStyle(color: AC.tp, fontSize: 14),
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: '\u0627\u0633\u0623\u0644 \u0645\u0633\u0627\u0639\u062f Apex...',
          hintStyle: TextStyle(color: AC.ts),
          filled: true, fillColor: AC.navy3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: AC.gold)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        onSubmitted: (_) => _sendMessage(),
      )),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(color: AC.gold, borderRadius: BorderRadius.circular(20)),
        child: IconButton(
          icon: Icon(Icons.send, color: AC.navy, size: 20),
          onPressed: _sendMessage,
        ),
      ),
    ]),
  );

  IconData _getIcon(String name) {
    const map = {
      'upload_file': Icons.upload_file, 'analytics': Icons.analytics, 'receipt_long': Icons.receipt_long,
      'map': Icons.map, 'assessment': Icons.assessment, 'verified': Icons.verified, 'gavel': Icons.gavel,
      'support_agent': Icons.support_agent, 'checklist': Icons.checklist, 'timeline': Icons.timeline,
      'find_in_page': Icons.find_in_page, 'account_balance': Icons.account_balance, 'warning': Icons.warning,
      'folder_open': Icons.folder_open, 'source': Icons.source, 'rule': Icons.rule, 'person': Icons.person,
      'smart_toy': Icons.smart_toy, 'store': Icons.store, 'dashboard': Icons.dashboard,
    };
    return map[name] ?? Icons.arrow_forward;
  }

  void _onAction(String action) {
    final routes = {
      'تحليل': '/financial-ops',
      'مالي': '/financial-ops',
      'مراجعة': '/audit-workflow',
      'معرف': '/knowledge-brain',
      'عميل': '/clients',
      'خدم': '/financial-ops',
    };
    for (final e in routes.entries) {
      if (action.contains(e.key)) { context.go(e.value); return; }
    }
  }

  @override
  void dispose() { _controller.dispose(); _scrollController.dispose(); super.dispose(); }
}
