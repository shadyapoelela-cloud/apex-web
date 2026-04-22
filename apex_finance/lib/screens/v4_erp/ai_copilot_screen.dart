/// APEX Wave 74 — AI Copilot / Chat.
/// Route: /app/erp/finance/copilot
///
/// Conversational AI assistant grounded in company data.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key});
  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final _msgCtl = TextEditingController();
  final _scrollCtl = ScrollController();

  final _messages = <_Msg>[
    _Msg('system', DateTime(2026, 4, 19, 9, 0), 'مرحباً! أنا Copilot. أستطيع إجابة أسئلتك عن المالية، العملاء، الضرائب، المراجعة، والموظفين. جرّب: "كم إيرادات أرامكو YTD؟"'),
    _Msg(
      'user',
      DateTime(2026, 4, 19, 9, 15),
      'أعطني ملخص الأداء المالي للربع الأول',
    ),
    _Msg(
      'ai',
      DateTime(2026, 4, 19, 9, 15),
      '''📊 **ملخّص أداء الربع الأول 2026**

**الإيرادات:** 4.85M ر.س (+24% YoY)
**المصروفات:** 3.65M ر.س (+15% YoY)
**الربح الصافي:** 1.2M ر.س (+38% YoY)
**الهامش:** 24.7% (Q1-2025: 22.1%)

**النقاط الرئيسية:**
• نمو قوي في خدمات الاستشارات (+42%)
• تحسّن الكفاءة التشغيلية — انخفاض تكلفة الفاتورة 18%
• العميل الأكبر (أرامكو) زاد 31%

**نقاط تحذيرية:**
• مصروفات التسويق تجاوزت الموازنة بـ 34%
• معدل التسرّب ارتفع إلى 9%

هل تريد التعمّق في أي بند؟''',
      sources: ['القوائم المالية Q1-2026', 'موازنة 2026', 'تقارير الموارد البشرية'],
    ),
    _Msg(
      'user',
      DateTime(2026, 4, 19, 9, 18),
      'تفاصيل الإيرادات حسب القطاع',
    ),
    _Msg(
      'ai',
      DateTime(2026, 4, 19, 9, 18),
      '''📈 **الإيرادات حسب القطاع — Q1-2026**

| القطاع | القيمة | % | نمو YoY |
|---|---|---|---|
| ERP | 2.1M ر.س | 43% | +28% |
| المراجعة | 1.2M ر.س | 25% | +15% |
| الاستشارات | 0.9M ر.س | 19% | +42% |
| السوق | 0.45M ر.س | 9% | +18% |
| الامتثال | 0.2M ر.س | 4% | +8% |

أكبر عميل: **أرامكو** — 520K ر.س (11%)
أعلى نمو: **الاستشارات** — +42% مدفوعاً بمشاريع التحوّل الرقمي''',
      sources: ['ERP ledger', 'CRM deals', 'Customer 360'],
    ),
  ];

  final _suggestions = const [
    '📊 كم إيرادات هذا الربع؟',
    '👥 أعلى 5 عملاء قيمةً',
    '📅 ما الإقرارات الضريبية الواجبة هذا الشهر؟',
    '⚠️ ما الانحرافات الكبرى في موازنة أبريل؟',
    '💰 هل نحن قادرون على دفع الرواتب الشهر القادم؟',
    '🔎 معدل تسرّب الموظفين خلال آخر 6 أشهر',
    '📦 المخزون الراكد منذ 90 يوم',
    '🏦 السيولة النقدية المتوقعة خلال 13 أسبوع',
  ];

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_Msg('user', DateTime.now(), text));
      _messages.add(_Msg('ai', DateTime.now(),
          'جاري تحليل البيانات من ERP, CRM, وسجل المعاملات... 🤔\n\n(في الـ POC هذا رد تمثيلي — في الإصدار الإنتاجي يستدعي Claude API مع Retrieval Augmented Generation على بيانات المنشأة).',
          sources: ['Mock response']));
      _msgCtl.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtl.hasClients) {
        _scrollCtl.animateTo(
          _scrollCtl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _msgCtl.dispose();
    _scrollCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHero(),
        Expanded(
          child: Row(
            children: [
              SizedBox(width: 280, child: _buildSidebar()),
              Expanded(child: _buildChat()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF311B92), core_theme.AC.gold],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.auto_awesome, color: core_theme.AC.gold, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('APEX Copilot',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text('مساعد ذكي مُدرَّب على بياناتك — يجيب عن الأسئلة ويُنفّذ المهام الروتينية',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: core_theme.AC.ok,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.white, size: 8),
                SizedBox(width: 5),
                Text('متصل', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, bottom: 20, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: core_theme.AC.bdr),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: core_theme.AC.navy3,
            child: Row(
              children: [
                Icon(Icons.lightbulb, color: core_theme.AC.gold, size: 16),
                SizedBox(width: 6),
                Text('اقتراحات شائعة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _suggestions.length,
              itemBuilder: (ctx, i) => InkWell(
                onTap: () => _send(_suggestions[i]),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: core_theme.AC.gold.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: core_theme.AC.gold.withOpacity(0.2)),
                  ),
                  child: Text(_suggestions[i], style: const TextStyle(fontSize: 12, height: 1.4)),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: core_theme.AC.purple,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.privacy_tip, color: core_theme.AC.purple, size: 14),
                    SizedBox(width: 6),
                    Text('الخصوصية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.purple)),
                  ],
                ),
                SizedBox(height: 4),
                Text('المحادثات لا تخرج من بيئة المنشأة. النموذج مدرّب محلياً على بياناتك فقط.',
                    style: TextStyle(fontSize: 10, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChat() {
    return Container(
      margin: const EdgeInsets.only(left: 10, bottom: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: core_theme.AC.bdr),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtl,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) => _messageBubble(_messages[i]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: core_theme.AC.navy3,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              border: Border(top: BorderSide(color: core_theme.AC.bdr)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.attach_file, size: 20),
                  tooltip: 'إرفاق ملف',
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.mic, size: 20),
                  tooltip: 'إملاء صوتي',
                ),
                Expanded(
                  child: TextField(
                    controller: _msgCtl,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'اسأل عن أي شيء — المالية، العملاء، الموظفين، الضرائب...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      isDense: true,
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _send(_msgCtl.text),
                  icon: const Icon(Icons.send, size: 16),
                  label: Text('إرسال'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: core_theme.AC.gold,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(_Msg m) {
    if (m.role == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: core_theme.AC.info,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: core_theme.AC.info),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: core_theme.AC.info, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(m.content, style: const TextStyle(fontSize: 12, height: 1.5))),
          ],
        ),
      );
    }
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isUser) ...[
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: core_theme.AC.gold.withOpacity(0.15),
                      child: Icon(Icons.auto_awesome, color: core_theme.AC.gold, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text('Copilot',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                  ],
                  if (isUser) ...[
                    Text('أنت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.info)),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: core_theme.AC.info.withOpacity(0.15),
                      child: Icon(Icons.person, color: core_theme.AC.info, size: 14),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isUser ? core_theme.AC.info : core_theme.AC.gold.withOpacity(0.08),
                  borderRadius: BorderRadius.only(
                    topRight: const Radius.circular(14),
                    topLeft: const Radius.circular(14),
                    bottomRight: Radius.circular(isUser ? 14 : 2),
                    bottomLeft: Radius.circular(isUser ? 2 : 14),
                  ),
                  border: Border.all(
                    color: isUser ? core_theme.AC.info.withOpacity(0.2) : core_theme.AC.gold.withOpacity(0.2),
                  ),
                ),
                child: SelectableText(
                  m.content,
                  style: const TextStyle(fontSize: 13, height: 1.7),
                ),
              ),
              if (m.sources != null && m.sources!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    Text('المصادر:', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    for (final s in m.sources!)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: core_theme.AC.bdr,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(s, style: TextStyle(fontSize: 10, color: core_theme.AC.tp)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 3),
              Text('${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10, color: core_theme.AC.td, fontFamily: 'monospace')),
            ],
          ),
        ),
      ),
    );
  }
}

class _Msg {
  final String role;
  final DateTime timestamp;
  final String content;
  final List<String>? sources;
  _Msg(this.role, this.timestamp, this.content, {this.sources});
}
