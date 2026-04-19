/// V5.2 Reference Implementation — Onboarding using FormWizardTemplate.
///
/// Demonstrates T3 (Form Wizard) with:
///   - 6 guided steps to complete initial setup
///   - Per-step validation with error toast
///   - "Save as Draft" functionality
///   - Side stepper (desktop) / linear progress (mobile)
library;

import 'package:flutter/material.dart';

import '../../core/v5/templates/form_wizard_template.dart';

class OnboardingV52Screen extends StatefulWidget {
  const OnboardingV52Screen({super.key});

  @override
  State<OnboardingV52Screen> createState() => _OnboardingV52ScreenState();
}

class _OnboardingV52ScreenState extends State<OnboardingV52Screen> {
  // Form data
  String _companyName = '';
  String _crNumber = '';
  String _vatNumber = '';
  String _currency = 'SAR';
  String _industry = 'تكنولوجيا';
  bool _enabledVAT = true;
  bool _enabledZatca = true;
  bool _enabledPayroll = false;
  bool _enabledProjects = false;
  bool _importedCoa = false;
  bool _addedUsers = false;

  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);

  @override
  Widget build(BuildContext context) {
    return FormWizardTemplate(
      titleAr: 'إعداد حسابك في APEX',
      subtitleAr: 'نحتاج بعض المعلومات لتجهيز نظامك للعمل',
      onSaveDraft: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم الحفظ كمسودة — يمكنك المتابعة لاحقاً')),
        );
      },
      onSubmit: () async {
        await Future.delayed(const Duration(seconds: 1));
        return true;
      },
      steps: [
        WizardStep(
          labelAr: 'البيانات الأساسية',
          descriptionAr: 'اسم الشركة وأرقام التسجيل الأساسية',
          icon: Icons.business,
          validate: () => _companyName.trim().isEmpty ? 'اسم الشركة مطلوب' : null,
          builder: (ctx) => _buildBasicsStep(),
        ),
        WizardStep(
          labelAr: 'الإعدادات المالية',
          descriptionAr: 'العملة، السنة المالية، طريقة الاستحقاق',
          icon: Icons.attach_money,
          builder: (ctx) => _buildFinancialStep(),
        ),
        WizardStep(
          labelAr: 'الوحدات المطلوبة',
          descriptionAr: 'اختر الوحدات التي ستستخدمها',
          icon: Icons.apps,
          builder: (ctx) => _buildModulesStep(),
        ),
        WizardStep(
          labelAr: 'دليل الحسابات',
          descriptionAr: 'استيراد أو اختيار قالب جاهز',
          icon: Icons.account_tree,
          validate: () => _importedCoa ? null : 'يجب اختيار دليل حسابات',
          builder: (ctx) => _buildCoaStep(),
        ),
        WizardStep(
          labelAr: 'دعوة الفريق',
          descriptionAr: 'أضف المستخدمين وحدد أدوارهم',
          icon: Icons.group_add,
          builder: (ctx) => _buildUsersStep(),
        ),
        WizardStep(
          labelAr: 'المراجعة النهائية',
          descriptionAr: 'راجع الإعدادات قبل التفعيل',
          icon: Icons.check_circle,
          builder: (ctx) => _buildReviewStep(),
        ),
      ],
    );
  }

  // ── Step 1 — Basics ──────────────────────────────────────────
  Widget _buildBasicsStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _input('اسم الشركة القانوني *', 'مثال: شركة أبكس للتجارة', (v) => _companyName = v),
          const SizedBox(height: 16),
          _input('السجل التجاري', '1010XXXXXX', (v) => _crNumber = v, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _input('الرقم الضريبي (VAT)', '3009XXXXXXXXXXX', (v) => _vatNumber = v, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _dropdown('القطاع', _industry, const ['تكنولوجيا', 'تجارة', 'خدمات', 'تصنيع', 'مقاولات', 'ضيافة'], (v) => setState(() => _industry = v!)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'سيتم التحقق من صحة أرقام السجل والضريبة تلقائياً مع ZATCA.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2 — Financial ──────────────────────────────────────
  Widget _buildFinancialStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dropdown('العملة الأساسية', _currency,
            const ['SAR', 'USD', 'AED', 'EUR', 'GBP'],
            (v) => setState(() => _currency = v!)),
        const SizedBox(height: 16),
        _dropdown('السنة المالية تبدأ من', 'يناير',
            const ['يناير', 'أبريل', 'يوليو', 'أكتوبر'], (_) {}),
        const SizedBox(height: 16),
        const Text('طريقة المحاسبة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _radioCard('الاستحقاق', 'المعيار الدولي IFRS', true)),
            const SizedBox(width: 10),
            Expanded(child: _radioCard('النقدي', 'الشركات الصغيرة', false)),
          ],
        ),
      ],
    );
  }

  // ── Step 3 — Modules ────────────────────────────────────────
  Widget _buildModulesStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ما الوحدات التي ستستخدمها؟',
              style: TextStyle(fontSize: 13, color: Colors.black54)),
          const SizedBox(height: 12),
          _moduleCheck(Icons.percent, 'ضريبة القيمة المضافة (VAT)', 'تتبع تلقائي للضريبة', _enabledVAT, (v) => setState(() => _enabledVAT = v!)),
          _moduleCheck(Icons.qr_code, 'ZATCA E-Invoicing', 'فوترة إلكترونية معتمدة من ZATCA', _enabledZatca, (v) => setState(() => _enabledZatca = v!)),
          _moduleCheck(Icons.payments, 'الموارد البشرية والرواتب', 'GOSI + WPS + Payroll', _enabledPayroll, (v) => setState(() => _enabledPayroll = v!)),
          _moduleCheck(Icons.work, 'إدارة المشاريع', 'مشاريع + ربحية + فوترة مراحل', _enabledProjects, (v) => setState(() => _enabledProjects = v!)),
        ],
      ),
    );
  }

  Widget _moduleCheck(IconData icon, String label, String sub, bool value, ValueChanged<bool?> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? _gold.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value ? _gold : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _gold.withOpacity(value ? 0.15 : 0.06),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: _gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(sub, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: _gold),
        ],
      ),
    );
  }

  // ── Step 4 — CoA ────────────────────────────────────────────
  Widget _buildCoaStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('اختر طريقة إعداد دليل الحسابات:',
            style: TextStyle(fontSize: 13, color: Colors.black54)),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(() => _importedCoa = true),
          child: _coaOption(Icons.auto_awesome, 'قالب موصى به', 'دليل حسابات جاهز للقطاع: $_industry', _importedCoa),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {},
          child: _coaOption(Icons.upload_file, 'استيراد من Excel/CSV', 'ارفع ملفك الحالي (سنُحلّله بـ AI)', false),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {},
          child: _coaOption(Icons.add_box, 'إنشاء من الصفر', 'ابدأ بحسابات أساسية فقط', false),
        ),
      ],
    );
  }

  Widget _coaOption(IconData icon, String title, String sub, bool selected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? _gold.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _gold : Colors.grey.shade300, width: selected ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: selected ? _gold : Colors.black54, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: selected ? _navy : Colors.black87)),
                Text(sub, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          if (selected) const Icon(Icons.check_circle, color: _gold),
        ],
      ),
    );
  }

  // ── Step 5 — Users ──────────────────────────────────────────
  Widget _buildUsersStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('أضف أعضاء الفريق — لكل عضو صلاحيات مختلفة',
                  style: TextStyle(fontSize: 13, color: Colors.black54)),
            ),
            OutlinedButton.icon(
              onPressed: () => setState(() => _addedUsers = true),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('إضافة مستخدم'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_addedUsers) ...[
          _userCard('أحمد محمد', 'مدير مالي', 'CFO Workspace'),
          _userCard('سارة علي', 'محاسبة', 'Accountant Workspace'),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
            ),
            child: const Column(
              children: [
                Icon(Icons.group_add, size: 40, color: Colors.black38),
                SizedBox(height: 8),
                Text('لم تُضِف مستخدمين بعد',
                    style: TextStyle(color: Colors.black54)),
                SizedBox(height: 4),
                Text('يمكنك تخطي هذه الخطوة وإضافتهم لاحقاً',
                    style: TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _userCard(String name, String role, String workspace) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _gold.withOpacity(0.15),
            child: Text(name.substring(0, 1), style: const TextStyle(color: _gold, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('$role · $workspace', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {}),
        ],
      ),
    );
  }

  // ── Step 6 — Review ────────────────────────────────────────
  Widget _buildReviewStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_gold.withOpacity(0.1), Colors.green.withOpacity(0.08)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _gold),
            ),
            child: const Row(
              children: [
                Icon(Icons.celebration, color: _gold, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('جاهز للتفعيل',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
                      Text('راجع الإعدادات أدناه ثم اضغط "إتمام" لتفعيل النظام',
                          style: TextStyle(fontSize: 12, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _reviewSection('البيانات الأساسية', [
            ('الشركة', _companyName.isEmpty ? '—' : _companyName),
            ('السجل التجاري', _crNumber.isEmpty ? '—' : _crNumber),
            ('الرقم الضريبي', _vatNumber.isEmpty ? '—' : _vatNumber),
            ('القطاع', _industry),
          ]),
          _reviewSection('الإعدادات المالية', [
            ('العملة', _currency),
            ('السنة المالية', 'تبدأ من يناير'),
            ('طريقة المحاسبة', 'الاستحقاق'),
          ]),
          _reviewSection('الوحدات المُفعّلة', [
            if (_enabledVAT) ('✓', 'VAT'),
            if (_enabledZatca) ('✓', 'ZATCA E-Invoicing'),
            if (_enabledPayroll) ('✓', 'HR & Payroll'),
            if (_enabledProjects) ('✓', 'Projects'),
          ]),
        ],
      ),
    );
  }

  Widget _reviewSection(String title, List<(String, String)> rows) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(r.$1, style: const TextStyle(fontSize: 12, color: Colors.black54))),
                    Text(r.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────
  Widget _input(String label, String hint, ValueChanged<String> onChanged, {TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        TextField(
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _dropdown(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _radioCard(String title, String sub, bool selected) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? _gold.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _gold : Colors.grey.shade300, width: selected ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? _gold : Colors.black38, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(sub, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
