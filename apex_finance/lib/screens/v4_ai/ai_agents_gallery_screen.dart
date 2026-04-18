/// APEX Wave 35 — AI Agents Gallery.
///
/// All AI features in one place: Copilot · Anomaly Scanner · Risk Scorer ·
/// Bank Rec · Bill Categorizer · Draft Writer · Cash Forecaster.
///
/// Route: /settings/ai-agents
library;

import 'package:flutter/material.dart';

import '../../core/v5/apex_v5_undo_toast.dart';

class AiAgentsGalleryScreen extends StatefulWidget {
  const AiAgentsGalleryScreen({super.key});

  @override
  State<AiAgentsGalleryScreen> createState() => _AiAgentsGalleryScreenState();
}

class _AiAgentsGalleryScreenState extends State<AiAgentsGalleryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final agents = _allAgents.where((a) {
      if (_filter == 'all') return true;
      if (_filter == 'active') return a.active;
      if (_filter == 'needs_setup') return !a.active;
      return a.category == _filter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFEC4899)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('معرض وكلاء الذكاء', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('12 وكيل ذكاء اصطناعي — كلهم يعملون بالعربية ويعرفون سياق محاسبتك', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: const Text('9 نشط', style: TextStyle(color: Color(0xFF7C3AED), fontSize: 16, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                      child: const Text('3 بانتظار الإعداد', style: TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Stats
          Row(
            children: [
              _agentStat('إجمالي الوكلاء', '12', Icons.auto_awesome, const Color(0xFF7C3AED)),
              const SizedBox(width: 12),
              _agentStat('اقتراحات هذا الشهر', '1,247', Icons.lightbulb, const Color(0xFF059669)),
              const SizedBox(width: 12),
              _agentStat('معدّل الدقة', '94.2%', Icons.verified, const Color(0xFF2563EB)),
              const SizedBox(width: 12),
              _agentStat('وقت موفَّر', '142 ساعة', Icons.schedule, const Color(0xFFD4AF37)),
            ],
          ),
          const SizedBox(height: 20),
          // Filters
          Wrap(
            spacing: 6,
            children: [
              _filterChip('all', 'الكل', _allAgents.length),
              _filterChip('active', 'نشط', _allAgents.where((a) => a.active).length),
              _filterChip('needs_setup', 'يحتاج إعداد', _allAgents.where((a) => !a.active).length),
              _filterChip('finance', 'مالية', _allAgents.where((a) => a.category == 'finance').length),
              _filterChip('audit', 'مراجعة', _allAgents.where((a) => a.category == 'audit').length),
              _filterChip('copilot', 'Copilot', _allAgents.where((a) => a.category == 'copilot').length),
            ],
          ),
          const SizedBox(height: 16),
          // Grid
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 1100 ? 3 : constraints.maxWidth > 700 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 1.3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final a in agents) _AgentCard(agent: a),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _agentStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String key, String label, int count) {
    final active = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF7C3AED) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? const Color(0xFF7C3AED) : Colors.black.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.black87)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: (active ? Colors.white : const Color(0xFF7C3AED)).withOpacity(active ? 0.25 : 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : const Color(0xFF7C3AED))),
            ),
          ],
        ),
      ),
    );
  }

  final _allAgents = <_Agent>[
    _Agent('copilot', 'Copilot Conversational AI', 'اسأل أي سؤال محاسبي بالعربية والإنجليزية', Icons.chat_bubble, const Color(0xFF7C3AED), 'copilot', true, 4.9, 542, 'GPT-4 + Claude'),
    _Agent('anomaly', 'Anomaly Scanner', 'يفحص كل 6 ساعات · يكشف ازدواج/round numbers/off-hours', Icons.security, const Color(0xFFB91C1C), 'finance', true, 4.8, 287, 'Rule-based + ML'),
    _Agent('risk-score', 'Transaction Risk Scorer', 'يصنّف كل معاملة 0-100 مع شرح العوامل', Icons.shield, const Color(0xFFD97706), 'audit', true, 4.7, 1847, 'ML Ensemble'),
    _Agent('bank-rec', 'AI Bank Reconciliation', 'يطابق معاملات البنك مع القيود — 95%+ ثقة = تطبيق فوري', Icons.compare_arrows, const Color(0xFFD4AF37), 'finance', true, 4.9, 318, 'Fuzzy matching + AI'),
    _Agent('coa-classifier', 'COA Auto-Classifier', 'يصنّف بنود المصاريف تلقائياً حسب شجرة الحسابات', Icons.account_tree, const Color(0xFF2563EB), 'finance', true, 4.6, 964, 'COA Engine v4.3'),
    _Agent('ocr', 'Receipt/Invoice OCR', 'يستخرج بيانات الإيصالات والفواتير من الصور', Icons.receipt_long, const Color(0xFF059669), 'finance', true, 4.8, 423, 'Claude Vision + OCR'),
    _Agent('draft-ai', 'AI Draft Writer', 'يكتب narration للقيود · Audit findings · ML letters', Icons.edit_note, const Color(0xFFEC4899), 'copilot', true, 4.7, 156, 'Claude Sonnet'),
    _Agent('cashflow', 'Cash Flow Forecaster', 'يتوقّع التدفق النقدي 13 أسبوع بناء على التاريخ', Icons.trending_up, const Color(0xFF059669), 'finance', true, 4.5, 89, 'Time-series ML'),
    _Agent('zatca-translator', 'ZATCA Error Translator', 'يترجم أخطاء زاتكا BR-KSA-* إلى نصوص عربية مفهومة', Icons.translate, const Color(0xFF2E7D5B), 'audit', true, 4.9, 34, '14 BR-KSA codes'),
    _Agent('apex-match', 'APEX Match', 'يختار أفضل 3 مزوّدين للمطلوب — Toptal-style', Icons.psychology, const Color(0xFFE65100), 'copilot', false, null, 0, 'Recommendation ML'),
    _Agent('benford', 'Benford\'s Law Analyzer', 'يكتشف التلاعب في الأرقام عبر تحليل توزيع الأرقام الأولى', Icons.insights, const Color(0xFF4A148C), 'audit', false, null, 0, 'Statistical analysis'),
    _Agent('tax-advisor', 'Tax Strategy Advisor', 'يحلّل الوضع الضريبي ويقترح optimizations', Icons.account_balance, const Color(0xFF1565C0), 'copilot', false, null, 0, 'Rules + LLM'),
  ];
}

class _Agent {
  final String id, name, description, category, engine;
  final IconData icon;
  final Color color;
  final bool active;
  final double? rating;
  final int usageCount;

  _Agent(this.id, this.name, this.description, this.icon, this.color, this.category, this.active, this.rating, this.usageCount, this.engine);
}

class _AgentCard extends StatefulWidget {
  final _Agent agent;
  const _AgentCard({required this.agent});

  @override
  State<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends State<_AgentCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _hover ? widget.agent.color.withOpacity(0.4) : Colors.black.withOpacity(0.08), width: _hover ? 2 : 1),
          boxShadow: _hover
              ? [BoxShadow(color: widget.agent.color.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: widget.agent.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(widget.agent.icon, color: widget.agent.color, size: 24),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.agent.active ? const Color(0xFF059669).withOpacity(0.12) : Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.agent.active ? '🟢 نشط' : '⏸ يحتاج إعداد',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: widget.agent.active ? const Color(0xFF059669) : Colors.black54),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(widget.agent.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(widget.agent.description, style: const TextStyle(fontSize: 11, color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
            const Spacer(),
            if (widget.agent.active) ...[
              Row(
                children: [
                  const Icon(Icons.star, color: Color(0xFFD97706), size: 12),
                  const SizedBox(width: 2),
                  Text('${widget.agent.rating}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Text('${widget.agent.usageCount} استخدام', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  const Spacer(),
                  Text(widget.agent.engine, style: const TextStyle(fontSize: 9, color: Colors.black45, fontFamily: 'monospace')),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.settings, size: 12),
                      label: const Text('إعدادات', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.play_arrow, size: 12),
                      label: const Text('اختبر', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.agent.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                  ),
                ],
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ApexV5UndoToast.show(
                      context,
                      messageAr: 'تم تفعيل ${widget.agent.name}',
                      onUndo: () {},
                    );
                  },
                  icon: const Icon(Icons.power_settings_new, size: 14),
                  label: const Text('فعّل الآن', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.agent.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wave 36 — Global Search Results.
class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  String _query = 'SABIC';
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08)))),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black.withOpacity(0.1))),
                child: TextField(
                  controller: TextEditingController(text: _query),
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20),
                    border: InputBorder.none,
                    hintText: 'ابحث في كل APEX...',
                    hintStyle: TextStyle(fontSize: 14),
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  _filterChip('all', 'الكل', 47),
                  _filterChip('customers', 'العملاء', 3),
                  _filterChip('invoices', 'فواتير', 12),
                  _filterChip('transactions', 'معاملات', 24),
                  _filterChip('documents', 'مستندات', 5),
                  _filterChip('screens', 'شاشات', 3),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _resultGroup('العملاء (3)', const Color(0xFF2563EB), [
                _Result('customer', 'SABIC Procurement', 'عبدالرحمن الشهري · VAT: 300001234500003', '/app/erp/finance/sales'),
                _Result('customer', 'SABIC Subsidiary', 'حساب فرعي · 12 فاتورة', '/app/erp/finance/sales'),
                _Result('customer', 'SABIC International', 'فرع دولي · USD accounts', '/app/erp/finance/sales'),
              ]),
              _resultGroup('الفواتير (12)', const Color(0xFFD4AF37), [
                _Result('invoice', 'INV-2026-145 — SABIC', '52,500 ر.س · 2026-04-15 · مدفوعة ✓', '/app/erp/finance/invoices'),
                _Result('invoice', 'INV-2026-132 — SABIC', '18,000 ر.س · 2026-03-28 · مدفوعة ✓', '/app/erp/finance/invoices'),
                _Result('invoice', 'INV-2026-098 — SABIC', '125,000 ر.س · 2026-02-10 · مدفوعة ✓', '/app/erp/finance/invoices'),
              ]),
              _resultGroup('المعاملات البنكية (24)', const Color(0xFF059669), [
                _Result('transaction', 'BF-2026-04-18-234 — SABIC', '+52,500 ر.س · الراجحي · 2026-04-18', '/app/erp/treasury/banks'),
                _Result('transaction', 'BF-2026-04-10-198 — SABIC Deposit', '+18,000 ر.س · الأهلي · 2026-04-10', '/app/erp/treasury/banks'),
              ]),
              _resultGroup('أوراق المراجعة (2)', const Color(0xFF4A148C), [
                _Result('workpaper', 'B-200 — SABIC Accounts Receivable', 'أحمد · قسم B — الموجودات · مكتمل', '/app/audit/fieldwork/workpapers'),
                _Result('workpaper', 'A-100 — SABIC Engagement Letter', 'د. عبدالله · قسم A — التخطيط · مكتمل', '/app/audit/fieldwork/workpapers'),
              ]),
              _resultGroup('شاشات (3)', const Color(0xFF7C3AED), [
                _Result('screen', 'SABIC Audit 2026 — Project', 'مشروع PRJ-2026-001 · 65% مكتمل', '/app/erp/operations/projects'),
                _Result('screen', 'SABIC Dashboard', 'KPIs خاصة بـ SABIC', '/app/erp/finance/dashboard'),
                _Result('screen', 'SABIC Fatoora Submissions', 'قائمة الفواتير الإلكترونية', '/app/compliance/zatca/queue'),
              ]),
              _resultGroup('المستندات (5)', const Color(0xFFD97706), [
                _Result('document', 'SABIC Audit Report 2025.pdf', '32 صفحة · PDF · آخر تعديل 2025-04-30', '/app/audit/reporting/opinion'),
                _Result('document', 'SABIC VAT Return Q1 2026.pdf', '4 صفحات · PDF · 2026-04-20', '/app/compliance/tax/vat'),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String key, String label, int count) {
    final active = _filter == key;
    return GestureDetector(
      onTap: () => setState(() => _filter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? const Color(0xFF2563EB) : Colors.black.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.black87)),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(color: (active ? Colors.white : const Color(0xFF2563EB)).withOpacity(active ? 0.25 : 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: active ? Colors.white : const Color(0xFF2563EB))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultGroup(String title, Color color, List<_Result> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              ),
              const Spacer(),
              TextButton(onPressed: () {}, child: const Text('عرض الكل ←', style: TextStyle(fontSize: 11))),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.black.withOpacity(0.08))),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++)
                  _resultRow(items[i], color, showDivider: i < items.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultRow(_Result r, Color color, {required bool showDivider}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: showDivider ? Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04))) : null),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
            child: Icon(_iconFor(r.type), color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
                    children: _highlight(r.title, _query),
                  ),
                ),
                Text(r.subtitle, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Text(r.route, style: const TextStyle(fontSize: 10, color: Colors.black38, fontFamily: 'monospace')),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_back, size: 14, color: Colors.black38),
        ],
      ),
    );
  }

  List<TextSpan> _highlight(String text, String query) {
    if (query.isEmpty) return [TextSpan(text: text)];
    final result = <TextSpan>[];
    int i = 0;
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    while (i < text.length) {
      final match = lowerText.indexOf(lowerQuery, i);
      if (match < 0) {
        result.add(TextSpan(text: text.substring(i)));
        break;
      }
      if (match > i) result.add(TextSpan(text: text.substring(i, match)));
      result.add(TextSpan(
        text: text.substring(match, match + query.length),
        style: const TextStyle(backgroundColor: Color(0xFFFEF3C7), fontWeight: FontWeight.w900),
      ));
      i = match + query.length;
    }
    return result;
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'customer': return Icons.person;
      case 'invoice': return Icons.receipt;
      case 'transaction': return Icons.account_balance;
      case 'workpaper': return Icons.description;
      case 'screen': return Icons.window;
      case 'document': return Icons.insert_drive_file;
      default: return Icons.search;
    }
  }
}

class _Result {
  final String type, title, subtitle, route;
  _Result(this.type, this.title, this.subtitle, this.route);
}
