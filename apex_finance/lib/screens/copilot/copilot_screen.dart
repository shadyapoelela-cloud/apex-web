import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class CopilotScreen extends StatefulWidget {
  final String? clientId;
  const CopilotScreen({super.key, this.clientId});
  @override State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  String? _sessionId;
  final List<Map<String, dynamic>> _messages = [];
  bool _loading = false;
  bool _sessionFailed = false;
  Map<String, dynamic>? _lastIntent;
  List<Map<String, dynamic>> _nextActions = [];
  late AnimationController _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _initSession();
  }

  Future<void> _initSession() async {
    try {
      final res = await ApiService.copilotCreateSession(clientId: widget.clientId);
      if (res.success && res.data != null) {
        setState(() => _sessionId = res.data['data']?['id'] ?? res.data['id']);
      } else {
        setState(() => _sessionFailed = true);
      }
    } catch (_) {
      setState(() => _sessionFailed = true);
    }
  }

  Future<void> _sendMessage([String? override]) async {
    final text = (override ?? _controller.text).trim();
    if (text.isEmpty || _loading) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text, 'time': DateTime.now()});
      _loading = true;
      _controller.clear();
      _nextActions.clear();
    });
    _scrollToBottom();

    final res = await ApiService.copilotChat(
      message: text,
      sessionId: _sessionId,
      clientId: widget.clientId,
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
          'time': DateTime.now(),
        });
        _lastIntent = data['intent'];
        _nextActions = List<Map<String, dynamic>>.from(msg['next_actions'] ?? []);
        _sessionId ??= data['session_id'];
      });
    } else {
      setState(() => _messages.add({
        'role': 'assistant',
        'content': res.error ?? 'عذراً، حدث خطأ في الاتصال. يرجى المحاولة مرة أخرى.',
        'time': DateTime.now(),
      }));
    }
    _scrollToBottom();
    _focusNode.requestFocus();
  }

  void _newSession() {
    setState(() {
      _messages.clear();
      _sessionId = null;
      _nextActions.clear();
      _lastIntent = null;
      _sessionFailed = false;
    });
    _initSession();
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
    final width = MediaQuery.of(context).size.width;
    final isWide = width > 800;

    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: AC.ts, size: 18),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Row(children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AC.gold.withValues(alpha: 0.2), AC.gold.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.smart_toy, color: AC.gold, size: 20),
          ),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(width: 6),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('AI', style: TextStyle(color: AC.gold, fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ]),
            Text('مدعوم بالذكاء الاصطناعي', style: TextStyle(color: AC.ts, fontSize: 10)),
          ]),
        ]),
        actions: [
          if (_lastIntent != null)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Chip(
                label: Text(_intentLabel(_lastIntent!['intent'] ?? ''),
                  style: TextStyle(color: AC.gold, fontSize: 9, fontWeight: FontWeight.w600)),
                backgroundColor: AC.gold.withValues(alpha: 0.08),
                side: BorderSide(color: AC.gold.withValues(alpha: 0.2)),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: Icon(Icons.add_comment_outlined, color: AC.ts, size: 20),
            tooltip: 'محادثة جديدة',
            onPressed: _newSession,
          ),
          SizedBox(width: 4),
        ],
      ),
      body: Column(children: [
        // Messages area
        Expanded(
          child: _messages.isEmpty ? _buildWelcome(isWide) : ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: isWide ? width * 0.15 : 14, vertical: 16),
            itemCount: _messages.length + (_loading ? 1 : 0),
            itemBuilder: (ctx, i) {
              if (i == _messages.length) return _buildTypingIndicator();
              return _buildMessage(_messages[i], i);
            },
          ),
        ),
        // Suggested actions
        if (_nextActions.isNotEmpty) _buildNextActions(),
        // Input bar
        _buildInput(isWide, width),
      ]),
    );
  }

  // ── Welcome Screen ──
  Widget _buildWelcome(bool isWide) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 80 : 24, vertical: 32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Logo + animation
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.05 + _pulseAnim.value * 0.08),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AC.gold.withValues(alpha: 0.15 + _pulseAnim.value * 0.15)),
                boxShadow: [BoxShadow(color: AC.gold.withValues(alpha: 0.05 + _pulseAnim.value * 0.05), blurRadius: 30, spreadRadius: 5)],
              ),
              child: Icon(Icons.smart_toy, color: AC.gold, size: 52),
            ),
          ),
          SizedBox(height: 24),
          Text('Apex Copilot', style: TextStyle(color: AC.tp, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1)),
          SizedBox(height: 8),
          Text('مساعدك الذكي للتحليل المالي والحوكمة المعرفية',
            style: TextStyle(color: AC.ts, fontSize: 14), textAlign: TextAlign.center),
          SizedBox(height: 8),
          Text('مدعوم بتقنية Claude AI من Anthropic',
            style: TextStyle(color: AC.ts.withValues(alpha: 0.6), fontSize: 11)),
          const SizedBox(height: 36),

          // Quick action cards
          Wrap(
            spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
            children: [
              _quickCard('📊', 'تحليل مالي', 'نسب مالية وقوائم', 'أريد إجراء تحليل مالي'),
              _quickCard('📋', 'شجرة حسابات', 'رفع وتصنيف COA', 'كيف أرفع شجرة حسابات؟'),
              _quickCard('⚖️', 'فحص امتثال', 'ZATCA والضريبة', 'ما متطلبات الامتثال لضريبة القيمة المضافة؟'),
              _quickCard('🔍', 'مراجعة', 'تدقيق ومراجعة', 'أريد بدء مراجعة محاسبية'),
              _quickCard('💰', 'جاهزية تمويل', 'تقييم للتمويل', 'هل منشأتي جاهزة للتمويل البنكي؟'),
              _quickCard('📚', 'بحث معرفي', 'معايير وأنظمة', 'ما هو معيار IFRS 15؟'),
              _quickCard('🛒', 'طلب خدمة', 'سوق الخدمات', 'أحتاج مكتب محاسبة لمسك الدفاتر'),
              _quickCard('💬', 'سؤال عام', 'أي استفسار', 'ما هي خدمات منصة APEX؟'),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _quickCard(String emoji, String title, String subtitle, String prompt) {
    return GestureDetector(
      onTap: () => _sendMessage(prompt),
      child: Container(
        width: 155, padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy3, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(emoji, style: TextStyle(fontSize: 24)),
          SizedBox(height: 8),
          Text(title, style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700),
            textDirection: TextDirection.rtl),
          SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: AC.ts, fontSize: 10),
            textDirection: TextDirection.rtl),
        ]),
      ),
    );
  }

  // ── Message Bubble ──
  Widget _buildMessage(Map<String, dynamic> msg, int index) {
    final isUser = msg['role'] == 'user';
    final content = msg['content'] ?? '';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? AC.gold.withValues(alpha: 0.12) : AC.navy3,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(color: isUser ? AC.gold.withValues(alpha: 0.25) : AC.bdr),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header for assistant messages
          if (!isUser) ...[
            Row(children: [
              Icon(Icons.smart_toy, color: AC.gold, size: 14),
              SizedBox(width: 6),
              Text('Apex Copilot', style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700)),
              Spacer(),
              // Copy button
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('تم نسخ الرد', style: TextStyle(fontFamily: 'Tajawal')),
                      backgroundColor: AC.ok, duration: Duration(seconds: 1)));
                },
                child: Icon(Icons.copy, color: AC.ts, size: 14),
              ),
            ]),
            SizedBox(height: 10),
          ],

          // Message content with rich formatting
          _buildRichContent(content, isUser),

          // Meta badges for assistant
          if (!isUser && (msg['confidence'] != null || msg['intent'] != null)) ...[
            SizedBox(height: 10),
            Divider(color: AC.bdr, height: 1),
            SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (msg['intent'] != null)
                _metaBadge(_intentLabel(msg['intent']), AC.cyan),
              if (msg['confidence'] != null)
                _metaBadge('ثقة: ${((msg['confidence'] as num) * 100).toInt()}%',
                  (msg['confidence'] as num) > 0.7 ? AC.ok : (msg['confidence'] as num) > 0.5 ? AC.warn : AC.err),
              if (msg['risk_level'] != null && msg['risk_level'] != 'low')
                _metaBadge('خطر: ${msg['risk_level'] == 'high' ? 'عالي' : 'متوسط'}',
                  msg['risk_level'] == 'high' ? AC.err : AC.warn),
            ]),
          ],

          // Escalation warning
          if (!isUser && msg['escalation'] != null && msg['escalation']['needed'] == true) ...[
            SizedBox(height: 10),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AC.warn.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AC.warn.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: AC.warn, size: 16),
                SizedBox(width: 6),
                Expanded(child: Text('يُنصح بمراجعة بشرية لهذه النتيجة',
                  style: TextStyle(color: AC.warn, fontSize: 11), textDirection: TextDirection.rtl)),
              ]),
            ),
          ],

          // References
          if (!isUser && msg['references'] != null && (msg['references'] as List).isNotEmpty) ...[
            SizedBox(height: 8),
            Wrap(spacing: 4, runSpacing: 4, children: (msg['references'] as List).map<Widget>((r) =>
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AC.cyan.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AC.cyan.withValues(alpha: 0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.menu_book, color: AC.cyan, size: 10),
                  SizedBox(width: 4),
                  Text(r['note'] ?? r['source'] ?? '', style: TextStyle(color: AC.cyan, fontSize: 9)),
                ]),
              ),
            ).toList()),
          ],
        ]),
      ),
    );
  }

  // ── Rich content renderer (handles bullet points, bold, etc.) ──
  Widget _buildRichContent(String content, bool isUser) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(SizedBox(height: 6));
        continue;
      }

      // Header-like lines (═══ or --- or lines ending with :)
      if (line.contains('═══') || line.contains('───')) {
        continue; // Skip decorative lines
      }

      // Numbered list: "1. text" or "١. text"
      final numberedMatch = RegExp(r'^(\d+[\.\)]\s)(.*)$').firstMatch(line.trim());
      if (numberedMatch != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 4, right: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 22, height: 22, margin: EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: AC.gold.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Center(child: Text(numberedMatch.group(1)!.trim().replaceAll('.', '').replaceAll(')', ''),
                style: TextStyle(color: AC.gold, fontSize: 10, fontWeight: FontWeight.w700))),
            ),
            SizedBox(width: 8),
            Expanded(child: Text(numberedMatch.group(2)!, textDirection: TextDirection.rtl,
              style: TextStyle(color: AC.tp, fontSize: 13.5, height: 1.6))),
          ]),
        ));
        continue;
      }

      // Bullet points: "- text" or "• text" or "* text"
      if (line.trim().startsWith('- ') || line.trim().startsWith('• ') || line.trim().startsWith('* ')) {
        final text = line.trim().substring(2);
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 3, right: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 5, height: 5, margin: EdgeInsets.only(top: 7),
              decoration: BoxDecoration(color: AC.gold, shape: BoxShape.circle)),
            SizedBox(width: 8),
            Expanded(child: Text(text, textDirection: TextDirection.rtl,
              style: TextStyle(color: AC.tp, fontSize: 13.5, height: 1.6))),
          ]),
        ));
        continue;
      }

      // Emoji-prefixed lines (📊 text)
      final emojiMatch = RegExp(r'^([📊📋⚖️🔍💰📚🛒⚠️📎💬🔴✅❌]+)\s+(.*)$').firstMatch(line.trim());
      if (emojiMatch != null) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emojiMatch.group(1)!, style: TextStyle(fontSize: 16)),
            SizedBox(width: 8),
            Expanded(child: Text(emojiMatch.group(2)!, textDirection: TextDirection.rtl,
              style: TextStyle(color: AC.tp, fontSize: 13.5, height: 1.6))),
          ]),
        ));
        continue;
      }

      // Bold text: **text** or lines that look like headers
      if (line.contains('**')) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: _buildBoldText(line),
        ));
        continue;
      }

      // Regular text
      widgets.add(Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: Text(line, textDirection: TextDirection.rtl,
          style: TextStyle(color: isUser ? AC.tp : AC.tp, fontSize: 13.5, height: 1.6)),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
  }

  Widget _buildBoldText(String text) {
    final parts = text.split('**');
    final spans = <TextSpan>[];
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          color: i % 2 == 1 ? AC.gold : AC.tp,
          fontSize: 13.5, height: 1.6,
          fontWeight: i % 2 == 1 ? FontWeight.w700 : FontWeight.normal,
        ),
      ));
    }
    return RichText(textDirection: TextDirection.rtl, text: TextSpan(children: spans));
  }

  // ── Meta badge ──
  Widget _metaBadge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
  );

  // ── Typing indicator ──
  Widget _buildTypingIndicator() => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AC.navy3, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AC.bdr),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.smart_toy, color: AC.gold, size: 14),
        SizedBox(width: 8),
        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AC.gold)),
        SizedBox(width: 10),
        Text('يُحلّل ويجهّز الرد...', style: TextStyle(color: AC.ts, fontSize: 12)),
      ]),
    ),
  );

  // ── Next Actions ──
  Widget _buildNextActions() => Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: AC.navy2, border: Border(top: BorderSide(color: AC.bdr, width: 0.5))),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        Padding(
          padding: EdgeInsets.only(left: 8),
          child: Text('💡', style: TextStyle(fontSize: 14)),
        ),
        ..._nextActions.map((a) => Padding(
          padding: EdgeInsets.only(left: 6),
          child: ActionChip(
            avatar: Icon(_getIcon(a['icon'] ?? ''), color: AC.gold, size: 14),
            label: Text(a['label'] ?? '', style: TextStyle(color: AC.tp, fontSize: 11)),
            backgroundColor: AC.navy3, side: BorderSide(color: AC.gold.withValues(alpha: 0.2)),
            visualDensity: VisualDensity.compact,
            onPressed: () => _sendMessage(a['label'] ?? ''),
          ),
        )),
      ]),
    ),
  );

  // ── Input Bar ──
  Widget _buildInput(bool isWide, double width) => Container(
    padding: EdgeInsets.symmetric(horizontal: isWide ? width * 0.12 : 12, vertical: 10),
    decoration: BoxDecoration(
      color: AC.navy2,
      border: Border(top: BorderSide(color: AC.bdr, width: 0.5)),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: Offset(0, -3))],
    ),
    child: SafeArea(
      top: false,
      child: Row(children: [
        Expanded(child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: TextStyle(color: AC.tp, fontSize: 14),
          textDirection: TextDirection.rtl,
          maxLines: 4, minLines: 1,
          decoration: InputDecoration(
            hintText: 'اسأل Apex Copilot أي شيء...',
            hintStyle: TextStyle(color: AC.ts, fontSize: 13),
            filled: true, fillColor: AC.navy3,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: AC.gold.withValues(alpha: 0.5))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          ),
          onSubmitted: (_) => _sendMessage(),
          textInputAction: TextInputAction.send,
        )),
        SizedBox(width: 8),
        AnimatedContainer(
          duration: Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AC.gold, AC.gold.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: AC.gold.withValues(alpha: 0.3), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: IconButton(
            icon: Icon(_loading ? Icons.hourglass_top : Icons.send_rounded, color: AC.navy, size: 20),
            onPressed: _loading ? null : () => _sendMessage(),
          ),
        ),
      ]),
    ),
  );

  // ── Intent label translation ──
  String _intentLabel(String intent) {
    const map = {
      'financial_analysis': 'تحليل مالي',
      'coa_workflow': 'شجرة حسابات',
      'tb_binding': 'ربط ميزان',
      'funding_readiness': 'جاهزية تمويل',
      'compliance': 'امتثال',
      'audit_review': 'مراجعة',
      'knowledge_lookup': 'بحث معرفي',
      'service_request': 'طلب خدمة',
      'explain_result': 'شرح نتيجة',
      'account_management': 'إدارة حساب',
      'general': 'عام',
      'error': 'خطأ',
    };
    return map[intent] ?? intent;
  }

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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }
}
