/// APEX V5.1 — Draft with AI (Enhancement #6).
///
/// Inspired by Microsoft Copilot + GitHub Copilot.
/// Every long textarea in the platform gets an "✨ اكتب بالذكاء" button
/// that drafts content based on context.
///
/// Examples:
///   - Invoice description → drafted from PO/line items
///   - JE narration → drafted from accounts hit + amounts
///   - Audit finding → drafted from evidence attached
///   - Management letter point → drafted from finding + severity
///
/// Usage:
///   ApexV5DraftWithAi(
///     controller: _descriptionCtl,
///     contextAr: 'فاتورة لـ ABC Trading بمبلغ 10,000 ريال',
///     onDraft: (suggestions) => setState(() => _aiSuggestions = suggestions),
///   )
library;

import 'dart:async';

import 'package:flutter/material.dart';

class ApexV5DraftWithAi extends StatefulWidget {
  final TextEditingController controller;
  final String contextAr;
  final String placeholderAr;
  final int? maxLines;
  final int? minLines;
  final String? labelAr;

  /// When non-null, the widget simulates an async backend call. Production
  /// binds to Copilot: `POST /copilot/draft?context=...`.
  final Future<List<String>> Function(String context)? draftBackend;

  const ApexV5DraftWithAi({
    super.key,
    required this.controller,
    required this.contextAr,
    this.placeholderAr = 'اكتب هنا أو اطلب من الذكاء كتابتها',
    this.maxLines = 5,
    this.minLines = 3,
    this.labelAr,
    this.draftBackend,
  });

  @override
  State<ApexV5DraftWithAi> createState() => _ApexV5DraftWithAiState();
}

class _ApexV5DraftWithAiState extends State<ApexV5DraftWithAi> {
  bool _loading = false;
  List<String> _suggestions = [];
  bool _showSuggestions = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.labelAr != null) ...[
          Text(
            widget.labelAr!,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54),
          ),
          const SizedBox(height: 4),
        ],
        Stack(
          children: [
            TextField(
              controller: widget.controller,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              decoration: InputDecoration(
                hintText: widget.placeholderAr,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: _buildAiButton(),
            ),
          ],
        ),
        if (_showSuggestions && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSuggestions(),
        ],
      ],
    );
  }

  Widget _buildAiButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _loading ? null : _requestDraft,
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: _loading
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                  ),
            color: _loading ? Colors.black.withOpacity(0.05) : null,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_loading)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                )
              else
                const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
              const SizedBox(width: 5),
              Text(
                _loading ? 'يكتب...' : 'اكتب بالذكاء',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _loading ? Colors.black54 : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              const Text(
                'اقتراحات الذكاء',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF7C3AED)),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 14),
                onPressed: () => setState(() => _showSuggestions = false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final s in _suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _applySuggestion(s),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(s, style: const TextStyle(fontSize: 12)),
                        ),
                        const Icon(Icons.arrow_back, size: 14, color: Color(0xFF7C3AED)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _requestDraft() async {
    setState(() {
      _loading = true;
      _showSuggestions = false;
    });

    final backend = widget.draftBackend ?? _mockBackend;

    try {
      final results = await backend(widget.contextAr);
      setState(() {
        _suggestions = results;
        _showSuggestions = true;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<String>> _mockBackend(String ctx) async {
    // Simulate ~1s backend latency.
    await Future.delayed(const Duration(milliseconds: 900));

    // POC: return 3 hand-crafted suggestions based on context keywords.
    if (ctx.contains('فاتورة') || ctx.contains('invoice')) {
      return [
        'فاتورة بموجب العقد رقم $ctx — خدمات استشارية ربع سنوية.',
        'تحصيل مستحق من $ctx حسب الاتفاقية المبرمة بتاريخ 2026-01-15.',
        'فواتير شهر أبريل 2026 — $ctx — ضريبة القيمة المضافة 15%.',
      ];
    }
    if (ctx.contains('قيد') || ctx.contains('JE')) {
      return [
        'قيد تسوية ربع سنوي — $ctx — يعكس استهلاك أصل ثابت للفترة.',
        'قيد رد مبالغ مستلمة عن غير طريق — $ctx — حسب المستند المرفق.',
        'قيد ترحيل $ctx لبند المصروفات — وفقاً لمبادئ IFRS 15.',
      ];
    }
    if (ctx.contains('ملاحظة') || ctx.contains('audit')) {
      return [
        'لم يتم الحصول على مستند داعم لهذا البند خلال فترة المراجعة.',
        'تم ملاحظة فارق بمبلغ جوهري بين السجل والمستند — يوصى بالتسوية.',
        'تم التحقق من الضوابط الداخلية — النتيجة: فعّالة مع توصيات بسيطة.',
      ];
    }
    return [
      'يمكن استخدام هذا النص كمدخل مناسب لسياق: $ctx',
      'نقترح صياغة بديلة: "تمت المعالجة وفقاً للسياسة المعتمدة."',
      'خيار مفصّل: "هذا البند يُعالج حسب قاعدة $ctx بتاريخ المعالجة."',
    ];
  }

  void _applySuggestion(String text) {
    widget.controller.text = text;
    setState(() => _showSuggestions = false);
  }
}
