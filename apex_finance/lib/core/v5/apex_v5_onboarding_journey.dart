/// APEX V5.1 — Onboarding Journey (Enhancement #8).
///
/// Inspired by QuickBooks + Workday Journeys.
/// 10-step guided first-time experience with:
///   - Progress bar (gamified)
///   - Completion badges
///   - Optional skip (but tracked for re-engagement)
///   - "🎁 مفاجأة" reward on completion
///
/// Shows up at /app/onboarding or as a dismissible overlay on Launchpad.
library;

import 'package:flutter/material.dart';
import '../theme.dart' as core_theme;

class V5OnboardingStep {
  final String id;
  final String titleAr;
  final String descriptionAr;
  final IconData icon;
  final String? ctaLabelAr;
  final String? ctaRoute;
  final bool required;

  const V5OnboardingStep({
    required this.id,
    required this.titleAr,
    required this.descriptionAr,
    required this.icon,
    this.ctaLabelAr,
    this.ctaRoute,
    this.required = true,
  });
}

const v5OnboardingSteps = <V5OnboardingStep>[
  V5OnboardingStep(
    id: 'account',
    titleAr: 'إنشاء حسابك',
    descriptionAr: 'معلومات الشركة الأساسية + الشعار',
    icon: Icons.person_add,
    ctaLabelAr: 'أكمل الحساب',
    ctaRoute: '/account/profile',
  ),
  V5OnboardingStep(
    id: 'coa',
    titleAr: 'شجرة الحسابات',
    descriptionAr: 'ارفع CoA موجود أو ابدأ بقالب جاهز حسب القطاع',
    icon: Icons.account_tree,
    ctaLabelAr: 'رفع CoA',
    ctaRoute: '/app/erp/finance/gl',
  ),
  V5OnboardingStep(
    id: 'first_customer',
    titleAr: 'إضافة أول عميل',
    descriptionAr: 'ابدأ تسجيل العملاء لتبدأ بالفواتير',
    icon: Icons.person_pin,
    ctaLabelAr: 'إضافة عميل',
    ctaRoute: '/app/erp/finance/sales',
  ),
  V5OnboardingStep(
    id: 'first_invoice',
    titleAr: 'إنشاء أول فاتورة',
    descriptionAr: 'فاتورة ZATCA متوافقة مع TLV QR تلقائياً',
    icon: Icons.receipt,
    ctaLabelAr: 'فاتورة جديدة',
    ctaRoute: '/app/erp/finance/invoices',
  ),
  V5OnboardingStep(
    id: 'zatca_cert',
    titleAr: 'تفعيل شهادة زاتكا',
    descriptionAr: 'CSID من بيئة الاختبار ثم الإنتاج — إرشادات مفصّلة',
    icon: Icons.verified_user,
    ctaLabelAr: 'تفعيل CSID',
    ctaRoute: '/app/compliance/zatca/csid',
  ),
  V5OnboardingStep(
    id: 'bank',
    titleAr: 'ربط حسابك البنكي',
    descriptionAr: 'Lean أو Tarabut — معاملاتك تصل تلقائياً',
    icon: Icons.account_balance,
    ctaLabelAr: 'ربط بنك',
    ctaRoute: '/app/erp/treasury/banks',
  ),
  V5OnboardingStep(
    id: 'team',
    titleAr: 'دعوة فريقك',
    descriptionAr: 'محاسب، مراجع، CFO — كل واحد له صلاحيات مخصّصة',
    icon: Icons.group_add,
    ctaLabelAr: 'إرسال دعوات',
    ctaRoute: '/settings/users',
  ),
  V5OnboardingStep(
    id: 'ai',
    titleAr: 'اختبار الذكاء الاصطناعي',
    descriptionAr: 'جرّب Copilot + Anomaly Detector + AI Bank Rec',
    icon: Icons.auto_awesome,
    ctaLabelAr: 'تجربة Copilot',
    ctaRoute: '/settings/ai-agents',
  ),
  V5OnboardingStep(
    id: 'close_period',
    titleAr: 'إقفال الفترة التجريبية',
    descriptionAr: 'أوّل period close مع TB + Financial Statements',
    icon: Icons.lock_clock,
    ctaLabelAr: 'إقفال فترة',
    ctaRoute: '/app/erp/finance/gl',
    required: false,
  ),
  V5OnboardingStep(
    id: 'reward',
    titleAr: '🎁 اكتمال الإعداد',
    descriptionAr: 'مفاجأة — شهر مجاني كامل + prioritized support',
    icon: Icons.emoji_events,
    required: false,
  ),
];

/// Full onboarding screen — shows all steps with progress.
class ApexV5OnboardingScreen extends StatefulWidget {
  /// Initially completed step ids (from backend).
  final Set<String> completedStepIds;

  final VoidCallback? onDismiss;

  const ApexV5OnboardingScreen({
    super.key,
    this.completedStepIds = const {'account', 'coa'},
    this.onDismiss,
  });

  @override
  State<ApexV5OnboardingScreen> createState() => _ApexV5OnboardingScreenState();
}

class _ApexV5OnboardingScreenState extends State<ApexV5OnboardingScreen> {
  late Set<String> _completed;

  @override
  void initState() {
    super.initState();
    _completed = {...widget.completedStepIds};
  }

  double get _progress {
    final required = v5OnboardingSteps.where((s) => s.required).length;
    final done = _completed.where((id) {
      final step = v5OnboardingSteps.firstWhere((s) => s.id == id, orElse: () => v5OnboardingSteps.first);
      return step.required;
    }).length;
    return required > 0 ? done / required : 0;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_progress * 100).toInt();
    final isComplete = pct >= 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isComplete
                    ? [core_theme.AC.gold, const Color(0xFFE6C200)]
                    : [core_theme.AC.info, core_theme.AC.purple],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isComplete ? Icons.emoji_events : Icons.waving_hand,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isComplete
                            ? '🎉 تهانينا! اكتمل إعدادك'
                            : 'أهلاً بك في APEX!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isComplete
                            ? 'شهر مجاني كامل + أولوية الدعم — استمتع!'
                            : 'نساعدك في إعداد كل شيء في 10 دقائق · ما يمكن تخطّيه هو اختياري',
                        style: TextStyle(
                          color: core_theme.AC.ts,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onDismiss,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Progress bar
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: core_theme.AC.tp.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation(
                        isComplete ? core_theme.AC.gold : core_theme.AC.purple,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isComplete
                      ? core_theme.AC.gold
                      : core_theme.AC.purple,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$pct%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_completed.length} من ${v5OnboardingSteps.length} مكتملة',
            style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
          ),
          const SizedBox(height: 20),

          // Steps list
          for (int i = 0; i < v5OnboardingSteps.length; i++)
            _StepCard(
              index: i + 1,
              step: v5OnboardingSteps[i],
              isComplete: _completed.contains(v5OnboardingSteps[i].id),
              isActive: !_completed.contains(v5OnboardingSteps[i].id) &&
                  v5OnboardingSteps.indexWhere((s) => !_completed.contains(s.id)) == i,
              onToggle: () {
                setState(() {
                  if (_completed.contains(v5OnboardingSteps[i].id)) {
                    _completed.remove(v5OnboardingSteps[i].id);
                  } else {
                    _completed.add(v5OnboardingSteps[i].id);
                  }
                });
              },
            ),
        ],
      ),
    );
  }
}

class _StepCard extends StatefulWidget {
  final int index;
  final V5OnboardingStep step;
  final bool isComplete;
  final bool isActive;
  final VoidCallback onToggle;

  const _StepCard({
    required this.index,
    required this.step,
    required this.isComplete,
    required this.isActive,
    required this.onToggle,
  });

  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.isComplete
        ? _State.done
        : widget.isActive
            ? _State.active
            : _State.pending;
    final color = _stateColor(state);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.isActive
              ? core_theme.AC.purple.withValues(alpha: 0.05)
              : widget.isComplete
                  ? core_theme.AC.gold.withValues(alpha: 0.04)
                  : _hover
                      ? core_theme.AC.tp.withValues(alpha: 0.02)
                      : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isActive
                ? core_theme.AC.purple.withValues(alpha: 0.3)
                : widget.isComplete
                    ? core_theme.AC.gold.withValues(alpha: 0.3)
                    : core_theme.AC.tp.withValues(alpha: 0.1),
            width: widget.isActive ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Check circle or number
            GestureDetector(
              onTap: widget.onToggle,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.isComplete
                      ? core_theme.AC.gold
                      : widget.isActive
                          ? core_theme.AC.purple.withValues(alpha: 0.15)
                          : core_theme.AC.tp.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                  border: widget.isActive
                      ? Border.all(color: core_theme.AC.purple, width: 2)
                      : null,
                ),
                child: Center(
                  child: widget.isComplete
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text(
                          '${widget.index}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: widget.isActive ? core_theme.AC.purple : core_theme.AC.ts,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.step.icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.step.titleAr,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: widget.isComplete ? core_theme.AC.ts : core_theme.AC.tp,
                          decoration: widget.isComplete ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (!widget.step.required) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: core_theme.AC.tp.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'اختياري',
                            style: TextStyle(
                              fontSize: 9,
                              color: core_theme.AC.ts,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.step.descriptionAr,
                    style: TextStyle(fontSize: 12, color: core_theme.AC.ts),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // CTA
            if (widget.step.ctaLabelAr != null && !widget.isComplete)
              ElevatedButton(
                onPressed: widget.onToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isActive
                      ? core_theme.AC.purple
                      : core_theme.AC.tp.withValues(alpha: 0.06),
                  foregroundColor: widget.isActive ? Colors.white : core_theme.AC.ts,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                child: Text(widget.step.ctaLabelAr!),
              ),
          ],
        ),
      ),
    );
  }
}

enum _State { pending, active, done }

Color _stateColor(_State s) {
  switch (s) {
    case _State.done: return core_theme.AC.gold;
    case _State.active: return core_theme.AC.purple;
    case _State.pending: return core_theme.AC.td;
  }
}
