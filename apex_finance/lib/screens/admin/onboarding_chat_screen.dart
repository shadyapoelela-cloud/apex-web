/// APEX — Conversational Onboarding (AI Chat)
/// /admin/tenant-onboarding-ai — chat-style intake (replacement for Wave 1N
/// form wizard). Users converse with the assistant, which validates each
/// answer and finalizes via the existing tenant_directory.onboard pathway.
///
/// Wired to Wave 1R Phase YY backend:
///   POST /api/v1/onboarding-chat/start
///   POST /api/v1/onboarding-chat/{id}/reply
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class OnboardingChatScreen extends StatefulWidget {
  const OnboardingChatScreen({super.key});
  @override
  State<OnboardingChatScreen> createState() => _OnboardingChatScreenState();
}

class _OnboardingChatScreenState extends State<OnboardingChatScreen> {
  bool _starting = true;
  bool _sending = false;
  String? _sessionId;
  String _step = 'tenant_id';
  bool _finalized = false;
  Map<String, dynamic> _collected = const {};
  Map<String, dynamic>? _finalResult;
  List<Map<String, dynamic>> _turns = [];
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    final r = await ApiService.onboardingChatStart();
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _applySession(Map<String, dynamic>.from(r.data['session'] as Map));
    } else {
      _error = r.error ?? 'تعذّر بدء الجلسة';
    }
    setState(() => _starting = false);
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending || _sessionId == null) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    // Optimistically add user turn for immediate feedback.
    setState(() {
      _turns = [
        ..._turns,
        {
          'role': 'user',
          'text': text,
          'ts': DateTime.now().toIso8601String(),
        },
      ];
    });
    _scrollToBottom();
    final r = await ApiService.onboardingChatReply(_sessionId!, text);
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _applySession(Map<String, dynamic>.from(r.data['session'] as Map));
    } else {
      // Revert optimistic + show error
      _turns.removeLast();
      _turns = [
        ..._turns,
        {
          'role': 'ai',
          'text': '⚠️ ${r.error ?? "خطأ في الاتصال"}',
          'ts': DateTime.now().toIso8601String(),
        },
      ];
    }
    setState(() => _sending = false);
    _scrollToBottom();
  }

  void _applySession(Map<String, dynamic> s) {
    _sessionId = s['session_id']?.toString();
    _step = (s['step'] ?? 'tenant_id').toString();
    _finalized = s['finalized'] == true;
    _collected = (s['collected'] as Map?)?.cast<String, dynamic>() ?? {};
    _finalResult = (s['final_result'] as Map?)?.cast<String, dynamic>();
    _turns = ((s['turns'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        ApexStickyToolbar(
          title: 'استقبال ذكي بالمحادثة',
          actions: [
            ApexToolbarAction(
              label: 'جلسة جديدة',
              icon: Icons.refresh,
              onPressed: _start,
            ),
            ApexToolbarAction(
              label: 'الكلاسيكي',
              icon: Icons.list_alt,
              onPressed: () =>
                  GoRouter.of(context).go('/admin/tenant-onboarding'),
            ),
          ],
        ),
        _stepIndicator(),
        Expanded(child: _chat()),
        if (!_finalized) _composer(),
        if (_finalized) _doneBanner(),
      ]),
    );
  }

  Widget _stepIndicator() {
    const labels = {
      'tenant_id': 'المعرّف',
      'display_name': 'الاسم',
      'industry': 'القطاع',
      'headcount': 'الموظفون',
      'review': 'مراجعة',
      'done': 'مكتمل',
    };
    const order = ['tenant_id', 'display_name', 'industry', 'headcount', 'review', 'done'];
    final currentIdx = order.indexOf(_step);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AC.navy2,
      child: Row(children: [
        for (var i = 0; i < order.length; i++) ...[
          _stepDot(i, labels[order[i]]!, currentIdx),
          if (i < order.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i < currentIdx ? AC.gold : AC.bdr,
              ),
            ),
        ],
      ]),
    );
  }

  Widget _stepDot(int i, String label, int currentIdx) {
    final active = i == currentIdx;
    final done = i < currentIdx;
    final color = done ? AC.ok : (active ? AC.gold : AC.ts);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: color),
        ),
        child: Center(
          child: done
              ? Icon(Icons.check, color: color, size: 12)
              : Text('${i + 1}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  )),
        ),
      ),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: color, fontSize: 9)),
    ]);
  }

  Widget _chat() {
    if (_starting) {
      return Center(child: CircularProgressIndicator(color: AC.gold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: AC.err)),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _turns.length + (_sending ? 1 : 0),
      itemBuilder: (ctx, i) {
        if (i == _turns.length && _sending) return _typingBubble();
        return _bubble(_turns[i]);
      },
    );
  }

  Widget _bubble(Map<String, dynamic> turn) {
    final isAi = turn['role'] == 'ai';
    final text = turn['text']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAi) _avatar(Icons.auto_awesome, AC.gold),
          if (isAi) const SizedBox(width: 8),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAi ? AC.navy2 : AC.gold.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isAi
                      ? AC.bdr
                      : AC.gold.withValues(alpha: 0.4),
                ),
              ),
              child: SelectableText(
                text,
                style: TextStyle(
                  color: AC.tp,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ),
          if (!isAi) const SizedBox(width: 8),
          if (!isAi) _avatar(Icons.person, AC.cyan),
        ],
      ),
    );
  }

  Widget _avatar(IconData icon, Color color) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _typingBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        _avatar(Icons.auto_awesome, AC.gold),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AC.bdr),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AC.gold),
            ),
            const SizedBox(width: 8),
            Text('يكتب...', style: TextStyle(color: AC.ts, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(top: BorderSide(color: AC.bdr)),
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _inputCtrl,
            style: TextStyle(color: AC.tp),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: _hintForStep(),
              hintStyle: TextStyle(color: AC.ts, fontSize: 12),
              filled: true,
              fillColor: AC.navy3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 44,
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              backgroundColor: AC.gold,
            ),
            child: Icon(Icons.send, color: AC.btnFg, size: 18),
          ),
        ),
      ]),
    );
  }

  String _hintForStep() {
    return switch (_step) {
      'tenant_id' => 'مثلاً: acme_co',
      'display_name' => 'مثلاً: شركة Acme',
      'industry' => 'صف نشاطك أو اختر pack_id',
      'headcount' => 'عدد الموظفين',
      'review' => 'اكتب "نعم" للتأكيد',
      _ => 'اكتب رسالتك...',
    };
  }

  Widget _doneBanner() {
    final ok = _finalResult != null && (_finalResult!['error'] == null);
    final tid = _collected['tenant_id']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ok
            ? AC.ok.withValues(alpha: 0.15)
            : AC.err.withValues(alpha: 0.15),
        border: Border(top: BorderSide(color: ok ? AC.ok : AC.err)),
      ),
      child: Row(children: [
        Icon(ok ? Icons.task_alt : Icons.error, color: ok ? AC.ok : AC.err),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ok
                ? 'تم تشغيل $tid بنجاح. اضغط الأزرار لرؤية النتيجة.'
                : 'حدث خطأ — راجع الرسالة الأخيرة',
            style: TextStyle(color: AC.tp, fontSize: 12),
          ),
        ),
        if (ok) ...[
          OutlinedButton.icon(
            onPressed: () =>
                GoRouter.of(context).go('/admin/dashboard-health'),
            icon: const Icon(Icons.dashboard, size: 14),
            label: const Text('اللوحة'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.cyan),
              foregroundColor: AC.cyan,
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            onPressed: () => GoRouter.of(context).go('/admin/tenants'),
            icon: const Icon(Icons.list_alt, size: 14),
            label: const Text('الدليل'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AC.gold),
              foregroundColor: AC.gold,
            ),
          ),
        ],
      ]),
    );
  }
}
