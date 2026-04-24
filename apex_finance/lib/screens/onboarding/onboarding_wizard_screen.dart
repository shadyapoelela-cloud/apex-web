/// APEX — Onboarding Wizard
/// Multi-step: company info → industry COA template → tax setup →
/// invite accountant → done.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class OnboardingWizardScreen extends StatefulWidget {
  const OnboardingWizardScreen({super.key});
  @override
  State<OnboardingWizardScreen> createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  int _step = 0;
  final _companyName = TextEditingController();
  final _vatNumber = TextEditingController();
  String _country = 'sa';
  String _industry = '';
  bool _loadingTemplates = true;
  List<Map<String, dynamic>> _templates = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    final res = await ApiService.aiListCoaTemplates();
    if (!mounted) return;
    setState(() {
      _templates = ((res.data?['data'] as List?) ?? []).cast<Map<String, dynamic>>();
      _loadingTemplates = false;
    });
  }

  bool _submitting = false;
  Map<String, dynamic>? _submissionResult;

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final res = await ApiService.onboardingComplete({
      'company_name': _companyName.text.trim(),
      'vat_number': _vatNumber.text.trim(),
      'country': _country,
      'industry': _industry,
    });
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (res.success && res.data != null) {
        _submissionResult = (res.data['data'] as Map).cast<String, dynamic>();
      }
    });
    if (res.success) {
      _next();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'فشل إنشاء الحساب')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('تهيئة الحساب', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _stepsBar(),
                  const SizedBox(height: 24),
                  Expanded(child: _stepBody()),
                  _navButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepsBar() {
    const labels = ['معلومات المنشأة', 'قطاع النشاط', 'الإعدادات الضريبية', 'اكتمل'];
    return Row(
      children: List.generate(labels.length, (i) {
        final active = _step == i;
        final done = _step > i;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: done ? AC.ok : (active ? AC.gold : AC.navy3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : Text('${i + 1}', style: TextStyle(color: active ? AC.btnFg : AC.ts, fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                style: TextStyle(
                  color: active ? AC.gold : AC.ts,
                  fontFamily: 'Tajawal',
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _stepBody() {
    switch (_step) {
      case 0:
        return _companyInfoStep();
      case 1:
        return _industryStep();
      case 2:
        return _taxStep();
      default:
        return _doneStep();
    }
  }

  Widget _companyInfoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('معلومات المنشأة', 'سنستخدمها لتخصيص دفاترك والقوالب'),
        const SizedBox(height: 18),
        _input(_companyName, 'الاسم التجاري للمنشأة'),
        const SizedBox(height: 10),
        _input(_vatNumber, 'الرقم الضريبي (15 رقم بدءاً/انتهاء بـ 3)'),
        const SizedBox(height: 10),
        _countryPicker(),
      ],
    );
  }

  Widget _industryStep() {
    if (_loadingTemplates) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('قطاع النشاط', 'اختر قالب شجرة حسابات مُعدّاً مسبقاً'),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: _templates.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final t = _templates[i];
              final selected = _industry == t['id'];
              return InkWell(
                onTap: () => setState(() => _industry = t['id'] as String),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected ? AC.gold.withValues(alpha: 0.15) : AC.navy2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AC.gold : AC.gold.withValues(alpha: 0.18),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.category_outlined, color: selected ? AC.gold : AC.ts),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${t['name_ar']} (${t['account_count']} حساب)',
                                style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${t['description_ar']}',
                                style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5, height: 1.4)),
                          ],
                        ),
                      ),
                      if (selected) Icon(Icons.check_circle, color: AC.gold, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _taxStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle('الإعدادات الضريبية', 'سيُمكّن التقويم الضريبي تلقائياً'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('الدولة', _countryLabel(_country)),
              _kv('قالب شجرة الحسابات', _industry.isEmpty ? '—' : _industry),
              _kv('VAT Cadence', 'شهري (افتراضي — يمكن تغييره لاحقاً)'),
              _kv('ZATCA Phase 2', _country == 'sa' ? 'جاهز للاتصال — أضِف CSID من الإعدادات' : 'لا ينطبق'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _doneStep() {
    final tid = _submissionResult?['tenant_id'];
    final eid = _submissionResult?['entity_id'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, color: AC.ok, size: 64),
        const SizedBox(height: 14),
        Text('تم إنشاء الحساب', style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (tid != null) Text('Tenant: $tid', style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 11)),
        if (eid != null) Text('Entity: $eid', style: TextStyle(color: AC.ts, fontFamily: 'monospace', fontSize: 11)),
        const SizedBox(height: 8),
        Text('ابدأ بإصدار أول فاتورة أو استيراد دفاتر سابقة.',
            style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 13)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => GoRouter.of(context).go('/app'),
          icon: const Icon(Icons.rocket_launch),
          label: const Text('إلى لوحة التحكم', style: TextStyle(fontFamily: 'Tajawal')),
          style: FilledButton.styleFrom(
            backgroundColor: AC.gold,
            foregroundColor: AC.btnFg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _navButtons() {
    final canNext = _step == 1 ? _industry.isNotEmpty : true;
    return Row(
      children: [
        if (_step > 0 && _step < 3)
          TextButton(
            onPressed: _back,
            child: Text('السابق', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')),
          ),
        const Spacer(),
        if (_step < 3)
          FilledButton(
            onPressed: canNext && !_submitting ? (_step == 2 ? _submit : _next) : null,
            style: FilledButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: _submitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_step == 2 ? 'إنشاء الحساب' : 'التالي', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12.5)),
      ],
    );
  }

  Widget _input(TextEditingController c, String label) {
    return TextField(
      controller: c,
      style: TextStyle(color: AC.tp, fontFamily: 'Tajawal'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
        filled: true,
        fillColor: AC.navy2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _countryPicker() {
    const countries = [
      ('sa', 'السعودية'), ('ae', 'الإمارات'), ('eg', 'مصر'),
      ('om', 'عُمان'), ('bh', 'البحرين'),
    ];
    return DropdownButtonFormField<String>(
      value: _country,
      dropdownColor: AC.navy2,
      style: TextStyle(color: AC.tp, fontFamily: 'Tajawal'),
      decoration: InputDecoration(
        labelText: 'الدولة',
        labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal'),
        filled: true,
        fillColor: AC.navy2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      items: countries.map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2, style: const TextStyle(fontFamily: 'Tajawal')))).toList(),
      onChanged: (v) => setState(() => _country = v ?? 'sa'),
    );
  }

  String _countryLabel(String c) {
    const map = {'sa': 'السعودية', 'ae': 'الإمارات', 'eg': 'مصر', 'om': 'عُمان', 'bh': 'البحرين'};
    return map[c] ?? c;
  }

  Widget _kv(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Text('$k: ', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12.5)),
        Expanded(child: Text(v, style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12.5, fontWeight: FontWeight.w600))),
      ],
    ),
  );
}
