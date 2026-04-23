import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/apex_app_bar.dart';
import '../../core/theme.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/ui_components.dart';

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
  bool _showHistory = false;
  Map<String, dynamic>? _lastIntent;
  List<Map<String, dynamic>> _nextActions = [];
  List<Map<String, dynamic>> _sessionHistory = [];
  late AnimationController _pulseAnim;
  late AnimationController _fadeAnim;
  final Set<int> _likedMessages = {};
  final Set<int> _dislikedMessages = {};

  @override
  void initState() {
    super.initState();
    _pulseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _fadeAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
    _initSession();
    _loadSessionHistory();
  }

  Future<void> _initSession() async {
    try {
      final res = await ApiService.copilotCreateSession(clientId: widget.clientId);
      if (res.success && res.data != null) {
        setState(() {
          _sessionId = res.data['data']?['id'] ?? res.data['id'];
          _sessionFailed = false;
        });
      } else {
        setState(() => _sessionFailed = true);
      }
    } catch (_) {
      setState(() => _sessionFailed = true);
    }
  }

  Future<void> _loadSessionHistory() async {
    try {
      final res = await ApiService.copilotGetSessions();
      if (res.success && res.data != null) {
        final data = res.data['data'] ?? res.data;
        if (data is List) {
          setState(() => _sessionHistory = List<Map<String, dynamic>>.from(data));
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSession(String sessionId) async {
    setState(() {
      _messages.clear();
      _sessionId = sessionId;
      _loading = true;
      _showHistory = false;
      _nextActions.clear();
      _lastIntent = null;
    });
    try {
      final res = await ApiService.copilotGetMessages(sessionId);
      if (res.success && res.data != null) {
        final data = res.data['data'] ?? res.data;
        if (data is List) {
          setState(() {
            for (final m in data) {
              _messages.add({
                'role': m['role'] ?? 'assistant',
                'content': m['content'] ?? '',
                'confidence': m['confidence'],
                'risk_level': m['risk_level'],
                'intent': m['intent'],
                'references': m['references'],
                'escalation': m['escalation'],
                'time': DateTime.tryParse(m['created_at'] ?? '') ?? DateTime.now(),
              });
            }
          });
        }
      }
    } catch (_) {}
    setState(() => _loading = false);
    _scrollToBottom();
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
      _likedMessages.clear();
      _dislikedMessages.clear();
    });
    _initSession();
    _loadSessionHistory();
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

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
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
        leading: ApexIconButton(
          icon: Icons.arrow_back_ios_new,
          color: AC.ts,
          size: 18,
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
              // Stateless mode indicator
              if (_sessionFailed) ...[
                SizedBox(width: 6),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: AC.warn.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                  child: Text('وضع مباشر', style: TextStyle(color: AC.warn, fontSize: 8, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            Text(_sessionFailed ? 'متصل بدون حفظ الجلسات' : 'مدعوم بالذكاء الاصطناعي',
              style: TextStyle(color: _sessionFailed ? AC.warn.withValues(alpha: 0.7) : AC.ts, fontSize: 10)),
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
          // History toggle
          if (isWide && _sessionHistory.isNotEmpty)
            IconButton(
              icon: Icon(_showHistory ? Icons.chat_bubble : Icons.history, color: AC.ts, size: 20),
              tooltip: _showHistory ? 'إغلاق السجل' : 'سجل المحادثات',
              onPressed: () => setState(() => _showHistory = !_showHistory),
            ),
          IconButton(
            icon: Icon(Icons.add_comment_outlined, color: AC.ts, size: 20),
            tooltip: 'محادثة جديدة',
            onPressed: _newSession,
          ),
          SizedBox(width: 4),
        ],
      ),
      // Mobile history drawer
      endDrawer: !isWide ? _buildHistoryDrawer() : null,
      body: Row(children: [
        // Main chat area
        Expanded(child: Column(children: [
          // Messages area
          Expanded(
            child: _messages.isEmpty ? _buildWelcome(isWide) : ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: isWide ? width * 0.1 : 14, vertical: 16),
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
        ])),
        // Desktop history sidebar
        if (isWide && _showHistory) _buildHistorySidebar(),
      ]),
    );
  }

  // ── Welcome Screen ──
  Widget _buildWelcome(bool isWide) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Center(
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
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(color: AC.ok, shape: BoxShape.circle),
              ),
              SizedBox(width: 6),
              Text('مدعوم بتقنية Claude AI من Anthropic',
                style: TextStyle(color: AC.ts.withValues(alpha: 0.6), fontSize: 11)),
            ]),
            const SizedBox(height: 36),

            // Quick action cards
            Wrap(
              spacing: 10, runSpacing: 10, alignment: WrapAlignment.center,
              children: [
                _quickCard('📊', 'تحليل مالي', 'نسب مالية وقوائم', 'أريد إجراء تحليل مالي شامل لمنشأتي'),
                _quickCard('📋', 'شجرة حسابات', 'رفع وتصنيف COA', 'كيف أرفع شجرة حسابات وأبدأ التصنيف؟'),
                _quickCard('⚖️', 'فحص امتثال', 'ZATCA والضريبة', 'ما متطلبات الامتثال لضريبة القيمة المضافة في السعودية؟'),
                _quickCard('🔍', 'مراجعة', 'تدقيق ومراجعة', 'أريد بدء مراجعة محاسبية شاملة'),
                _quickCard('💰', 'جاهزية تمويل', 'تقييم للتمويل', 'هل منشأتي جاهزة للحصول على تمويل بنكي؟'),
                _quickCard('📚', 'بحث معرفي', 'معايير وأنظمة', 'اشرح لي معيار IFRS 15 الإيرادات من العقود مع العملاء'),
                _quickCard('🛒', 'طلب خدمة', 'سوق الخدمات', 'أحتاج مكتب محاسبة لمسك الدفاتر الشهري'),
                _quickCard('💬', 'سؤال عام', 'أي استفسار', 'ما هي خدمات منصة APEX وكيف أستفيد منها؟'),
              ],
            ),

            // Session failed notice
            if (_sessionFailed) ...[
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AC.warn.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AC.warn.withValues(alpha: 0.15)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.wifi_off, color: AC.warn, size: 14),
                  SizedBox(width: 8),
                  Text('وضع المحادثة المباشرة — الردود لن تُحفظ في السجل',
                    style: TextStyle(color: AC.warn, fontSize: 11)),
                ]),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _quickCard(String emoji, String title, String subtitle, String prompt) {
    return _HoverCard(
      onTap: () => _sendMessage(prompt),
      child: Container(
        width: 155, padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AC.navy2, borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))],
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
    final time = msg['time'] as DateTime?;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? AC.gold.withValues(alpha: 0.12) : AC.navy2,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18), topRight: Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.12), blurRadius: 10, offset: Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header for assistant messages
          if (!isUser) ...[
            Row(children: [
              Icon(Icons.smart_toy, color: AC.gold, size: 14),
              SizedBox(width: 6),
              Text('Apex Copilot', style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.w700)),
              Spacer(),
              // Timestamp
              if (time != null)
                Text(_formatTime(time), style: TextStyle(color: AC.ts.withValues(alpha: 0.5), fontSize: 9)),
              SizedBox(width: 8),
              // Copy button
              _IconBtn(Icons.copy, 'نسخ', () {
                Clipboard.setData(ClipboardData(text: content));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم نسخ الرد', style: TextStyle(fontFamily: 'Tajawal')),
                    backgroundColor: AC.ok, duration: Duration(seconds: 1)));
              }),
            ]),
            SizedBox(height: 10),
          ],

          // User message header with time
          if (isUser && time != null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(_formatTime(time), style: TextStyle(color: AC.ts.withValues(alpha: 0.5), fontSize: 9)),
            ]),
            SizedBox(height: 4),
          ],

          // Message content with rich formatting
          _buildRichContent(content, isUser),

          // Feedback buttons for assistant messages
          if (!isUser) ...[
            SizedBox(height: 10),
            Row(children: [
              // Like/dislike
              _FeedbackBtn(
                icon: Icons.thumb_up_outlined,
                activeIcon: Icons.thumb_up,
                isActive: _likedMessages.contains(index),
                color: AC.ok,
                onTap: () => setState(() {
                  if (_likedMessages.contains(index)) {
                    _likedMessages.remove(index);
                  } else {
                    _likedMessages.add(index);
                    _dislikedMessages.remove(index);
                  }
                }),
              ),
              SizedBox(width: 4),
              _FeedbackBtn(
                icon: Icons.thumb_down_outlined,
                activeIcon: Icons.thumb_down,
                isActive: _dislikedMessages.contains(index),
                color: AC.err,
                onTap: () => setState(() {
                  if (_dislikedMessages.contains(index)) {
                    _dislikedMessages.remove(index);
                  } else {
                    _dislikedMessages.add(index);
                    _likedMessages.remove(index);
                  }
                }),
              ),
              Spacer(),
              // Meta badges
              if (msg['intent'] != null)
                _metaBadge(_intentLabel(msg['intent']), AC.cyan),
              if (msg['confidence'] != null) ...[
                SizedBox(width: 4),
                _metaBadge('${((msg['confidence'] as num) * 100).toInt()}%',
                  (msg['confidence'] as num) > 0.7 ? AC.ok : (msg['confidence'] as num) > 0.5 ? AC.warn : AC.err),
              ],
              if (msg['risk_level'] != null && msg['risk_level'] != 'low') ...[
                SizedBox(width: 4),
                _metaBadge(msg['risk_level'] == 'high' ? 'خطر عالي' : 'خطر متوسط',
                  msg['risk_level'] == 'high' ? AC.err : AC.warn),
              ],
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

  // ── Rich content renderer (handles bullet points, bold, code blocks, etc.) ──
  Widget _buildRichContent(String content, bool isUser) {
    final lines = content.split('\n');
    final widgets = <Widget>[];
    bool inCodeBlock = false;
    final codeLines = <String>[];

    for (final line in lines) {
      // Code block handling
      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          // End code block
          widgets.add(_buildCodeBlock(codeLines.join('\n')));
          codeLines.clear();
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        codeLines.add(line);
        continue;
      }

      if (line.trim().isEmpty) {
        widgets.add(SizedBox(height: 6));
        continue;
      }

      // Header-like lines (═══ or --- or lines ending with :)
      if (line.contains('═══') || line.contains('───')) {
        continue; // Skip decorative lines
      }

      // Section headers: lines ending with : or starting with #
      if (line.trim().startsWith('#')) {
        final headerText = line.trim().replaceAll(RegExp(r'^#+\s*'), '');
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 6, top: 4),
          child: Text(headerText, textDirection: TextDirection.rtl,
            style: TextStyle(color: AC.gold, fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.5)),
        ));
        continue;
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
            Expanded(child: _buildInlineFormatted(numberedMatch.group(2)!)),
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
            Expanded(child: _buildInlineFormatted(text)),
          ]),
        ));
        continue;
      }

      // Bold text: **text** or lines that contain inline formatting
      if (line.contains('**') || line.contains('`')) {
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: _buildInlineFormatted(line),
        ));
        continue;
      }

      // Regular text
      widgets.add(Padding(
        padding: EdgeInsets.only(bottom: 2),
        child: Text(line, textDirection: TextDirection.rtl,
          style: TextStyle(color: AC.tp, fontSize: 13.5, height: 1.6)),
      ));
    }

    // Close unclosed code block
    if (inCodeBlock && codeLines.isNotEmpty) {
      widgets.add(_buildCodeBlock(codeLines.join('\n')));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
  }

  // Inline formatting: **bold**, `code`
  Widget _buildInlineFormatted(String text) {
    final spans = <TextSpan>[];
    // Split by ** and ` patterns
    final regex = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`)');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before match
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: AC.tp, fontSize: 13.5, height: 1.6),
        ));
      }

      final matched = match.group(0)!;
      if (matched.startsWith('**') && matched.endsWith('**')) {
        // Bold
        spans.add(TextSpan(
          text: matched.substring(2, matched.length - 2),
          style: TextStyle(color: AC.gold, fontSize: 13.5, height: 1.6, fontWeight: FontWeight.w700),
        ));
      } else if (matched.startsWith('`') && matched.endsWith('`')) {
        // Inline code
        spans.add(TextSpan(
          text: matched.substring(1, matched.length - 1),
          style: TextStyle(
            color: AC.cyan, fontSize: 12.5, height: 1.6,
            fontFamily: 'monospace',
            backgroundColor: AC.cyan.withValues(alpha: 0.08),
          ),
        ));
      }
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: AC.tp, fontSize: 13.5, height: 1.6),
      ));
    }

    if (spans.isEmpty) {
      return Text(text, textDirection: TextDirection.rtl,
        style: TextStyle(color: AC.tp, fontSize: 13.5, height: 1.6));
    }
    return RichText(textDirection: TextDirection.rtl, text: TextSpan(children: spans));
  }

  // Code block widget
  Widget _buildCodeBlock(String code) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.10), blurRadius: 6, offset: Offset(0, 1))],
      ),
      child: Stack(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText(code,
            style: TextStyle(color: AC.cyan, fontSize: 12, fontFamily: 'monospace', height: 1.5)),
        ),
        Positioned(top: 0, left: 0, child: GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تم نسخ الكود'), backgroundColor: AC.ok, duration: Duration(seconds: 1)));
          },
          child: Icon(Icons.copy, color: AC.ts, size: 14),
        )),
      ]),
    );
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
    alignment: AlignmentDirectional.centerStart,
    child: Container(
      margin: EdgeInsets.only(bottom: 12), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AC.navy2, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.12), blurRadius: 10, offset: Offset(0, 2))],
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

  // ── Input Bar with keyboard shortcut ──
  Widget _buildInput(bool isWide, double width) => Container(
    padding: EdgeInsets.symmetric(horizontal: isWide ? width * 0.08 : 12, vertical: 10),
    decoration: BoxDecoration(
      color: AC.navy2,
      border: Border(top: BorderSide(color: AC.bdr, width: 0.5)),
      boxShadow: [BoxShadow(color: core_theme.AC.tp.withValues(alpha: 0.1), blurRadius: 10, offset: Offset(0, -3))],
    ),
    child: SafeArea(
      top: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.enter &&
                  HardwareKeyboard.instance.isControlPressed) {
                _sendMessage();
              }
            },
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              style: TextStyle(color: AC.tp, fontSize: 14),
              textDirection: TextDirection.rtl,
              maxLines: 4, minLines: 1,
              decoration: InputDecoration(
                hintText: 'اسأل Apex Copilot أي شيء...',
                hintStyle: TextStyle(color: AC.ts, fontSize: 13),
                filled: true, fillColor: AC.navy2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: AC.gold.withValues(alpha: 0.5))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
              textInputAction: TextInputAction.send,
            ),
          )),
          SizedBox(width: 8),
          AnimatedContainer(
            duration: Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AC.gold, AC.gold.withValues(alpha: 0.8)]),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: AC.gold.withValues(alpha: 0.3), blurRadius: 8, offset: Offset(0, 2))],
            ),
            child: ApexIconButton(
              icon: _loading ? Icons.hourglass_top : Icons.send_rounded,
              color: AC.navy,
              size: 20,
              onPressed: _loading ? null : () => _sendMessage(),
            ),
          ),
        ]),
        // Shortcut hint
        if (isWide) Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Ctrl + Enter للإرسال السريع', style: TextStyle(color: AC.ts.withValues(alpha: 0.4), fontSize: 9)),
        ),
      ]),
    ),
  );

  // ── History Sidebar (Desktop) ──
  Widget _buildHistorySidebar() => Container(
    width: 280,
    decoration: BoxDecoration(
      color: AC.navy2,
      border: Border(right: BorderSide(color: AC.bdr, width: 0.5)),
    ),
    child: Column(children: [
      Container(
        padding: EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.history, color: AC.gold, size: 18),
          SizedBox(width: 8),
          Text('سجل المحادثات', style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.w700)),
          Spacer(),
          Text('${_sessionHistory.length}', style: TextStyle(color: AC.ts, fontSize: 11)),
        ]),
      ),
      Divider(color: AC.bdr, height: 1),
      Expanded(child: ListView.builder(
        padding: EdgeInsets.all(8),
        itemCount: _sessionHistory.length,
        itemBuilder: (_, i) => _buildSessionTile(_sessionHistory[i]),
      )),
    ]),
  );

  // ── History Drawer (Mobile) ──
  Drawer _buildHistoryDrawer() => Drawer(
    backgroundColor: AC.navy2,
    child: SafeArea(child: Column(children: [
      Container(
        padding: EdgeInsets.all(16),
        child: Row(children: [
          Icon(Icons.history, color: AC.gold, size: 20),
          SizedBox(width: 10),
          Text('سجل المحادثات', style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
      Divider(color: AC.bdr, height: 1),
      Expanded(child: _sessionHistory.isEmpty
        ? Center(child: Text('لا توجد محادثات سابقة', style: TextStyle(color: AC.ts, fontSize: 12)))
        : ListView.builder(
            padding: EdgeInsets.all(8),
            itemCount: _sessionHistory.length,
            itemBuilder: (_, i) => _buildSessionTile(_sessionHistory[i]),
          ),
      ),
    ])),
  );

  Widget _buildSessionTile(Map<String, dynamic> session) {
    final id = session['id'] ?? '';
    final isActive = id == _sessionId;
    final type = session['session_type'] ?? 'general';
    final createdAt = session['created_at'] ?? '';
    final ctx = session['context'] ?? {};
    final msgCount = ctx['message_count'] ?? 0;
    final lastIntent = ctx['last_intent'];

    return GestureDetector(
      onTap: () => _loadSession(id),
      child: Container(
        margin: EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? AC.gold.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? AC.gold.withValues(alpha: 0.25) : AC.bdr.withValues(alpha: 0.5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(children: [
            if (isActive) Container(
              width: 6, height: 6, margin: EdgeInsets.only(left: 6),
              decoration: BoxDecoration(color: AC.ok, shape: BoxShape.circle),
            ),
            Expanded(child: Text(
              lastIntent != null ? _intentLabel(lastIntent) : (type == 'general' ? 'محادثة عامة' : type),
              style: TextStyle(color: isActive ? AC.gold : AC.tp, fontSize: 12, fontWeight: FontWeight.w600),
              textDirection: TextDirection.rtl, overflow: TextOverflow.ellipsis,
            )),
          ]),
          SizedBox(height: 4),
          Row(children: [
            Text('$msgCount رسالة', style: TextStyle(color: AC.ts, fontSize: 10)),
            Spacer(),
            if (createdAt.isNotEmpty)
              Text(_formatSessionDate(createdAt), style: TextStyle(color: AC.ts.withValues(alpha: 0.6), fontSize: 9)),
          ]),
        ]),
      ),
    );
  }

  String _formatSessionDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
      if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

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
    _fadeAnim.dispose();
    super.dispose();
  }
}

// ── Hover effect card (web-friendly) ──
class _HoverCard extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _HoverCard({required this.onTap, required this.child});
  @override State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hovering = true),
    onExit: (_) => setState(() => _hovering = false),
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        transform: Matrix4.identity()..scale(_hovering ? 1.03 : 1.0),
        transformAlignment: Alignment.center,
        child: AnimatedOpacity(
          duration: Duration(milliseconds: 200),
          opacity: _hovering ? 1.0 : 0.85,
          child: widget.child,
        ),
      ),
    ),
  );
}

// ── Small icon button ──
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.tooltip, this.onTap);
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: AC.ts, size: 14),
    ),
  );
}

// ── Feedback button (like/dislike) ──
class _FeedbackBtn extends StatelessWidget {
  final IconData icon, activeIcon;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;
  const _FeedbackBtn({required this.icon, required this.activeIcon, required this.isActive, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: Duration(milliseconds: 200),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(isActive ? activeIcon : icon, size: 14,
        color: isActive ? color : AC.ts.withValues(alpha: 0.5)),
    ),
  );
}
