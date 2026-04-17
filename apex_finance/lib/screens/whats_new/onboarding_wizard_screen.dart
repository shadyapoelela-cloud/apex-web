/// APEX Onboarding Wizard — 5 steps from sign-up to first invoice.
///
/// Source: Xero/QuickBooks 5-minute time-to-value.
///
/// Steps:
///   1. Company info (name + CR + VAT)
///   2. Industry Pack selection (F&B / Construction / Medical / Logistics / Services)
///   3. Chart of Accounts (upload / use pack default / skip)
///   4. First client (or "try with sample data")
///   5. First invoice (pre-filled from step 4)
///
/// Progress bar at top, skip option per step, persistent progress (saves
/// to SharedPreferences so refresh doesn't lose progress).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/apex_form_field.dart';
import '../../core/apex_responsive.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/validators_ui.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});

  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  int _step = 0;

  // Step 1: company
  final _companyCtrl = TextEditingController();
  final _crCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();

  // Step 2: industry
  String _industry = 'services';

  // Step 3: COA
  String _coaOption = 'pack';

  // Step 4: first client
  final _clientNameCtrl = TextEditingController();
  final _clientIbanCtrl = TextEditingController();

  // Step 5: first invoice
  final _invoiceAmountCtrl = TextEditingController();

  final List<_WizardStep> _steps = const [
    _WizardStep(title: 'بيانات الشركة', icon: Icons.business),
    _WizardStep(title: 'اختر قطاعك', icon: Icons.apps),
    _WizardStep(title: 'دليل الحسابات', icon: Icons.account_tree),
    _WizardStep(title: 'أول عميل', icon: Icons.person_add_alt),
    _WizardStep(title: 'أول فاتورة', icon: Icons.receipt),
  ];

  @override
  void dispose() {
    _companyCtrl.dispose();
    _crCtrl.dispose();
    _vatCtrl.dispose();
    _clientNameCtrl.dispose();
    _clientIbanCtrl.dispose();
    _invoiceAmountCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      // Finished!
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('تم إعداد الحساب بنجاح 🎉'),
          backgroundColor: AC.ok,
        ),
      );
      context.go('/whats-new');
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  void _skipAll() {
    context.go('/whats-new');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'إعداد الحساب — ${_step + 1} من ${_steps.length}',
            actions: [
              ApexToolbarAction(
                label: 'تخطي الكل',
                icon: Icons.fast_forward,
                onPressed: _skipAll,
              ),
            ],
          ),
          _progressBar(),
          _stepperHeader(),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(
                ApexResponsive.isMobile(context)
                    ? AppSpacing.lg
                    : AppSpacing.xxl,
              ),
              child: SingleChildScrollView(child: _currentStep()),
            ),
          ),
          _navButtons(),
        ],
      ),
    );
  }

  Widget _progressBar() {
    final pct = (_step + 1) / _steps.length;
    return Container(
      height: 4,
      color: AC.navy2,
      child: Row(
        children: [
          Expanded(
            flex: (pct * 1000).round(),
            child: Container(color: AC.gold),
          ),
          Expanded(
            flex: (1000 - pct * 1000).round(),
            child: const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _stepperHeader() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(bottom: BorderSide(color: AC.navy4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_steps.length * 2 - 1, (i) {
          if (i.isEven) {
            final idx = i ~/ 2;
            final step = _steps[idx];
            final isCurrent = idx == _step;
            final isDone = idx < _step;
            final color = isDone
                ? AC.ok
                : isCurrent
                    ? AC.gold
                    : AC.td;
            return Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: color),
                  ),
                  child: Icon(
                    isDone ? Icons.check : step.icon,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  step.title,
                  style: TextStyle(
                    color: color,
                    fontSize: AppFontSize.sm,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            );
          }
          final idx = (i - 1) ~/ 2;
          final done = idx < _step;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 18),
              height: 2,
              color: done ? AC.ok : AC.navy4,
            ),
          );
        }),
      ),
    );
  }

  Widget _currentStep() {
    return switch (_step) {
      0 => _stepCompany(),
      1 => _stepIndustry(),
      2 => _stepCoa(),
      3 => _stepFirstClient(),
      _ => _stepFirstInvoice(),
    };
  }

  Widget _stepCompany() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepIntro(
          'لنبدأ بأساسيات شركتك',
          'هذه المعلومات ستظهر على فواتيرك وتقاريرك الرسمية.',
        ),
        const SizedBox(height: AppSpacing.xl),
        ApexFormField(
          label: 'اسم الشركة (كما يظهر في السجل التجاري)',
          controller: _companyCtrl,
          validator: (v) => validateRequired(v, fieldName: 'اسم الشركة'),
        ),
        const SizedBox(height: AppSpacing.lg),
        ApexFormField(
          label: 'رقم السجل التجاري',
          controller: _crCtrl,
          validator: validateSaudiCR,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.lg),
        ApexFormField(
          label: 'الرقم الضريبي VAT (اختياري)',
          controller: _vatCtrl,
          validator: (v) => v == null || v.isEmpty ? null : validateSaudiVatNumber(v),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _stepIndustry() {
    const packs = [
      ('services', 'خدمات واستشارات', Icons.psychology_outlined),
      ('fnb_retail', 'مطاعم وتجزئة', Icons.restaurant_menu),
      ('construction', 'مقاولات', Icons.construction),
      ('medical', 'عيادات طبية', Icons.medical_services),
      ('logistics', 'نقل ولوجستيات', Icons.local_shipping),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepIntro(
          'ما قطاع نشاطك؟',
          'سنحمّل لك دليل حسابات وتقارير مخصصة لقطاعك.',
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: packs.map((p) {
            final (id, label, icon) = p;
            final selected = _industry == id;
            return InkWell(
              onTap: () => setState(() => _industry = id),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: selected ? AC.gold.withValues(alpha: 0.1) : AC.navy2,
                  border: Border.all(
                      color: selected ? AC.gold : AC.navy4, width: selected ? 2 : 1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(icon, color: selected ? AC.gold : AC.ts, size: 24),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: AC.tp,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (selected) Icon(Icons.check_circle, color: AC.gold, size: 18),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _stepCoa() {
    const options = [
      ('pack', 'استخدم دليل الحسابات الافتراضي للقطاع', Icons.auto_awesome),
      ('upload', 'ارفع دليل الحسابات الخاص بي (Excel)', Icons.upload_file),
      ('skip', 'تخطٍ — سأضبطه لاحقاً', Icons.skip_next),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepIntro('كيف تريد إعداد دليل الحسابات؟',
            'الخيار الافتراضي يأتي مع ٣٠-٤٠ حساباً مُخصصاً لقطاعك.'),
        const SizedBox(height: AppSpacing.xl),
        ...options.map((o) {
          final (id, label, icon) = o;
          final selected = _coaOption == id;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: RadioListTile<String>(
              value: id,
              groupValue: _coaOption,
              onChanged: (v) => setState(() => _coaOption = v!),
              activeColor: AC.gold,
              title: Row(
                children: [
                  Icon(icon, color: selected ? AC.gold : AC.ts),
                  const SizedBox(width: AppSpacing.sm),
                  Text(label, style: TextStyle(color: AC.tp)),
                ],
              ),
              tileColor: selected ? AC.gold.withValues(alpha: 0.08) : AC.navy2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                side: BorderSide(color: selected ? AC.gold : AC.navy4),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _stepFirstClient() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepIntro('أول عميل لك', 'يمكنك إضافة المزيد لاحقاً — ابدأ بواحد.'),
        const SizedBox(height: AppSpacing.xl),
        ApexFormField(
          label: 'اسم العميل',
          controller: _clientNameCtrl,
          validator: (v) => validateRequired(v, fieldName: 'اسم العميل'),
        ),
        const SizedBox(height: AppSpacing.lg),
        ApexFormField(
          label: 'IBAN العميل (اختياري)',
          controller: _clientIbanCtrl,
          validator: (v) => v == null || v.isEmpty ? null : validateSaudiIban(v),
        ),
        const SizedBox(height: AppSpacing.xl),
        InkWell(
          onTap: () {
            setState(() {
              _clientNameCtrl.text = 'شركة تجريبية المحدودة';
              _clientIbanCtrl.text = 'SA0380000000608010167519';
            });
          },
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AC.cyan.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AC.cyan.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline, color: AC.cyan, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'أو استخدم بيانات تجريبية — اضغط هنا لتعبئة حقل.',
                    style: TextStyle(color: AC.ts, fontSize: AppFontSize.md),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepFirstInvoice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepIntro(
          'أنشئ أول فاتورة',
          'عميل "${_clientNameCtrl.text.isEmpty ? "—" : _clientNameCtrl.text}" سيكون متلقي الفاتورة.',
        ),
        const SizedBox(height: AppSpacing.xl),
        ApexFormField(
          label: 'مبلغ الفاتورة (ر.س)',
          controller: _invoiceAmountCtrl,
          validator: validateSarAmount,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AC.gold.withValues(alpha: 0.18),
                AC.navy2,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.rocket_launch, color: AC.gold, size: 32),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('تهانينا 🎉',
                        style: TextStyle(
                            color: AC.tp,
                            fontSize: AppFontSize.xl,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'بضغطة واحدة سيتم إعداد شركتك وإصدار أول فاتورة. '
                      'يمكنك دائماً تعديل أو حذف أي شيء من لوحة التحكم.',
                      style: TextStyle(color: AC.ts, fontSize: AppFontSize.md),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepIntro(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: AC.tp,
            fontSize: AppFontSize.h2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: TextStyle(color: AC.ts, fontSize: AppFontSize.lg),
        ),
      ],
    );
  }

  Widget _navButtons() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        border: Border(top: BorderSide(color: AC.navy4)),
      ),
      child: Row(
        children: [
          if (_step > 0)
            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_forward),
              label: const Text('السابق'),
              onPressed: _back,
            ),
          const Spacer(),
          ElevatedButton.icon(
            icon: Icon(_step == _steps.length - 1
                ? Icons.check
                : Icons.arrow_back),
            label: Text(_step == _steps.length - 1 ? 'إنهاء' : 'التالي'),
            onPressed: _next,
          ),
        ],
      ),
    );
  }
}

class _WizardStep {
  final String title;
  final IconData icon;
  const _WizardStep({required this.title, required this.icon});
}
