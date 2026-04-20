/// Pilot Onboarding Wizard — إعدادات إنشاء الشركة من الصفر.
/// ═════════════════════════════════════════════════════════════════════
/// 8 خطوات تُنشئ كل ما يحتاجه عميل تجزئة جديد:
///   1. المستأجر (Tenant) — البيانات القانونية الأساسية
///   2. الكيانات (Entities) — شركة لكل دولة
///   3. الفروع (Branches) — مواقع بيع
///   4. المستودعات (Warehouses) — واحد على الأقل لكل فرع
///   5. العملات (Currencies) — تفعيل العملات المطلوبة
///   6. شجرة الحسابات (CoA) — بذر SOCPA الافتراضية
///   7. الفترات المحاسبية (Fiscal Periods) — 12 شهر
///   8. ZATCA Onboarding — للكيانات السعودية فقط
///
/// في نهاية كل خطوة، البيانات تُرسَل فوراً إلى /pilot/* endpoints.
/// يمكن الخروج والرجوع — الخطوات المُكتملة تبقى محفوظة في الـ backend.
library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../api/pilot_client.dart';
import '../../session.dart';

class PilotOnboardingWizard extends StatefulWidget {
  const PilotOnboardingWizard({super.key});
  @override
  State<PilotOnboardingWizard> createState() => _PilotOnboardingWizardState();
}

class _PilotOnboardingWizardState extends State<PilotOnboardingWizard> {
  int _step = 0;
  final PilotClient _client = pilotClient;

  // Step 1 — Tenant
  final _slugCtrl = TextEditingController();
  final _tenantNameArCtrl = TextEditingController();
  final _tenantNameEnCtrl = TextEditingController();
  final _crCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _primaryCountry = 'SA';
  String _tier = 'growth';
  String? _tenantId;

  // Step 2 — Entities (add multiple)
  final List<Map<String, dynamic>> _entitiesToCreate = [];
  final Map<String, String> _createdEntityIds = {}; // code → id

  // Step 3 — Branches
  final List<Map<String, dynamic>> _branchesToCreate = [];
  final Map<String, String> _createdBranchIds = {};

  // Step 4 — Warehouses
  final List<Map<String, dynamic>> _warehousesToCreate = [];

  // Step 5 — Currencies
  final Set<String> _activeCurrencies = {'SAR'};

  // Progress
  bool _loading = false;
  String? _error;

  static const _gccCountries = [
    {'code': 'SA', 'name': 'السعودية', 'currency': 'SAR'},
    {'code': 'AE', 'name': 'الإمارات', 'currency': 'AED'},
    {'code': 'QA', 'name': 'قطر', 'currency': 'QAR'},
    {'code': 'KW', 'name': 'الكويت', 'currency': 'KWD'},
    {'code': 'BH', 'name': 'البحرين', 'currency': 'BHD'},
    {'code': 'OM', 'name': 'عُمان', 'currency': 'OMR'},
    {'code': 'EG', 'name': 'مصر', 'currency': 'EGP'},
  ];

  static const _stepTitles = [
    '1. المستأجر',
    '2. الكيانات',
    '3. الفروع',
    '4. المستودعات',
    '5. العملات',
    '6. شجرة الحسابات',
    '7. الفترات المحاسبية',
    '8. ZATCA',
    '9. جاهز ✓',
  ];

  @override
  void dispose() {
    _slugCtrl.dispose();
    _tenantNameArCtrl.dispose();
    _tenantNameEnCtrl.dispose();
    _crCtrl.dispose();
    _vatCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: Text('Setup Wizard — إعداد الشركة من الصفر',
              style: TextStyle(color: AC.tp)),
          iconTheme: IconThemeData(color: AC.tp),
        ),
        body: Column(children: [
          _stepper(),
          if (_error != null) _errorBanner(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _currentStepBody(),
          )),
          _footer(),
        ]),
      ),
    );
  }

  Widget _stepper() => Container(
        color: AC.navy2,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(_stepTitles.length, (i) {
              final done = i < _step;
              final active = i == _step;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? AC.ok
                            : active
                                ? AC.gold
                                : AC.navy3,
                        border: Border.all(
                          color: active ? AC.gold : AC.bdr,
                          width: active ? 2 : 1,
                        ),
                      ),
                      child: done
                          ? Icon(Icons.check, color: Colors.white, size: 16)
                          : Text('${i + 1}',
                              style: TextStyle(
                                  color: active ? AC.btnFg : AC.ts,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    Text(_stepTitles[i],
                        style: TextStyle(
                            color: active
                                ? AC.tp
                                : done
                                    ? AC.ts
                                    : AC.td,
                            fontWeight:
                                active ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12)),
                    if (i < _stepTitles.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.chevron_left,
                            color: AC.td, size: 16),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
      );

  Widget _errorBanner() => Container(
        color: AC.err.withValues(alpha: 0.15),
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.error, color: AC.err),
          const SizedBox(width: 8),
          Expanded(child: Text(_error!, style: TextStyle(color: AC.err))),
          IconButton(
              icon: Icon(Icons.close, color: AC.err),
              onPressed: () => setState(() => _error = null)),
        ]),
      );

  Widget _footer() => Container(
        color: AC.navy2,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          if (_step > 0 && _step < 8)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr)),
              onPressed: _loading ? null : () => setState(() => _step--),
              icon: Icon(Icons.chevron_right, color: AC.ts),
              label: Text('السابق', style: TextStyle(color: AC.ts)),
            ),
          const Spacer(),
          if (_step < 8)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.btnFg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: _loading ? null : _advance,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_left),
              label: Text(_step == 7 ? 'إنهاء الإعداد' : 'التالي',
                  style: const TextStyle(fontSize: 15)),
            )
          else
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: AC.ok, foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).pop(_tenantId),
              icon: const Icon(Icons.done_all),
              label: const Text('فتح الواجهة الرئيسية'),
            ),
        ]),
      );

  Widget _currentStepBody() {
    switch (_step) {
      case 0:
        return _step1Tenant();
      case 1:
        return _step2Entities();
      case 2:
        return _step3Branches();
      case 3:
        return _step4Warehouses();
      case 4:
        return _step5Currencies();
      case 5:
        return _step6CoA();
      case 6:
        return _step7Periods();
      case 7:
        return _step8Zatca();
      case 8:
        return _stepDone();
    }
    return const SizedBox.shrink();
  }

  // ═════════════════════════════════════════════════════════════════════
  // Step 1 — Tenant
  // ═════════════════════════════════════════════════════════════════════

  Widget _step1Tenant() => _card('المستأجر (المجموعة الأم)',
      'أدخل البيانات القانونية للشركة الأم.', [
        _field(_tenantNameArCtrl, 'الاسم القانوني بالعربية *',
            'شركة الأزياء المتطورة'),
        _field(_tenantNameEnCtrl, 'الاسم بالإنجليزية (اختياري)',
            'Advanced Fashion Co.'),
        _field(_slugCtrl, 'معرِّف مختصر (slug) *', 'advanced-fashion'),
        _countryPicker('الدولة الأساسية', _primaryCountry,
            (v) => setState(() => _primaryCountry = v)),
        _field(_crCtrl, 'رقم السجل التجاري', '1010234567'),
        _field(_vatCtrl, 'الرقم الضريبي (15 رقم)', '310234567890003'),
        _field(_emailCtrl, 'البريد الإلكتروني *', 'admin@company.sa'),
        _field(_phoneCtrl, 'الهاتف', '+966500000000'),
        Row(children: [
          Text('الخطة: ',
              style: TextStyle(color: AC.ts, fontWeight: FontWeight.w500)),
          const SizedBox(width: 8),
          ...['starter', 'growth', 'enterprise', 'custom'].map((t) => Padding(
                padding: const EdgeInsetsDirectional.only(start: 6),
                child: ChoiceChip(
                  label: Text(_tierLabel(t)),
                  selected: _tier == t,
                  onSelected: (_) => setState(() => _tier = t),
                  selectedColor: AC.gold.withValues(alpha: 0.25),
                  backgroundColor: AC.navy3,
                  labelStyle: TextStyle(
                      color: _tier == t ? AC.gold : AC.ts,
                      fontWeight: FontWeight.w600),
                ),
              )),
        ]),
      ]);

  String _tierLabel(String t) {
    return {
      'starter': 'البداية',
      'growth': 'النمو',
      'enterprise': 'المؤسسي',
      'custom': 'مخصّص',
    }[t]!;
  }

  // ═════════════════════════════════════════════════════════════════════
  // Step 2 — Entities
  // ═════════════════════════════════════════════════════════════════════

  Widget _step2Entities() => _card(
        'الكيانات (شركة قانونية لكل دولة)',
        'أضف كياناً واحداً على الأقل. العميل يعمل في عدة دول → كيان لكل دولة.',
        [
          if (_entitiesToCreate.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AC.navy3,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(children: [
                Icon(Icons.business, color: AC.td, size: 40),
                const SizedBox(height: 8),
                Text('لم تُضف أي كيانات بعد',
                    style: TextStyle(color: AC.td)),
              ]),
            ),
          ..._entitiesToCreate.asMap().entries.map((e) => _entityTile(e.key, e.value)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(side: BorderSide(color: AC.gold)),
            icon: Icon(Icons.add, color: AC.gold),
            label: Text('إضافة كيان', style: TextStyle(color: AC.gold)),
            onPressed: _openEntityDialog,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.cyan.withValues(alpha: 0.5))),
            icon: Icon(Icons.auto_awesome, color: AC.cyan),
            label: Text('إضافة جميع دول الخليج + مصر (افتراضي)',
                style: TextStyle(color: AC.cyan)),
            onPressed: _addDefaultEntities,
          ),
        ],
      );

  Widget _entityTile(int i, Map<String, dynamic> e) {
    final createdId = _createdEntityIds[e['code']];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: createdId != null ? AC.ok : AC.bdr,
            width: createdId != null ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(
            createdId != null
                ? Icons.check_circle
                : Icons.pending_actions,
            color: createdId != null ? AC.ok : AC.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${e['code']} — ${e['name_ar']}',
                  style: TextStyle(
                      color: AC.tp, fontWeight: FontWeight.w600)),
              Text('${e['country']} • ${e['functional_currency']}',
                  style: TextStyle(color: AC.ts, fontSize: 12)),
            ],
          ),
        ),
        if (createdId == null)
          IconButton(
            icon: Icon(Icons.delete, color: AC.err, size: 18),
            onPressed: () => setState(() => _entitiesToCreate.removeAt(i)),
          ),
      ]),
    );
  }

  void _openEntityDialog() {
    final codeCtrl = TextEditingController();
    final nameArCtrl = TextEditingController();
    final crCtrl = TextEditingController();
    final vatCtrl = TextEditingController();
    String country = 'SA';
    String currency = 'SAR';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AC.navy2,
            title: Text('كيان جديد', style: TextStyle(color: AC.tp)),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: country,
                    dropdownColor: AC.navy3,
                    style: TextStyle(color: AC.tp),
                    decoration: InputDecoration(
                        labelText: 'الدولة',
                        labelStyle: TextStyle(color: AC.ts)),
                    items: _gccCountries
                        .map((c) => DropdownMenuItem(
                              value: c['code'],
                              child: Text(
                                  '${c['name']} (${c['currency']})',
                                  style: TextStyle(color: AC.tp)),
                            ))
                        .toList(),
                    onChanged: (v) => setS(() {
                      country = v!;
                      currency = _gccCountries
                          .firstWhere((c) => c['code'] == v)['currency']!;
                      codeCtrl.text = v;
                    }),
                  ),
                  _field(codeCtrl, 'كود الكيان *', 'SA / AE / QA...'),
                  _field(nameArCtrl, 'الاسم بالعربية *',
                      'الشركة في الدولة'),
                  _field(crCtrl, 'رقم السجل', '1010123456'),
                  _field(vatCtrl, 'الرقم الضريبي', ''),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: TextStyle(color: AC.ts)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: AC.gold, foregroundColor: AC.btnFg),
                onPressed: () {
                  if (codeCtrl.text.trim().isEmpty ||
                      nameArCtrl.text.trim().isEmpty) return;
                  setState(() => _entitiesToCreate.add({
                        'code': codeCtrl.text.trim(),
                        'name_ar': nameArCtrl.text.trim(),
                        'country': country,
                        'type': 'subsidiary',
                        'functional_currency': currency,
                        if (crCtrl.text.isNotEmpty) 'cr_number': crCtrl.text,
                        if (vatCtrl.text.isNotEmpty)
                          'vat_number': vatCtrl.text,
                      }));
                  _activeCurrencies.add(currency);
                  Navigator.pop(ctx);
                },
                child: const Text('إضافة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addDefaultEntities() {
    setState(() {
      for (final c in _gccCountries) {
        if (!_entitiesToCreate.any((e) => e['code'] == c['code'])) {
          _entitiesToCreate.add({
            'code': c['code'],
            'name_ar': 'شركتنا في ${c['name']}',
            'country': c['code'],
            'type': 'subsidiary',
            'functional_currency': c['currency'],
          });
          _activeCurrencies.add(c['currency']!);
        }
      }
    });
  }

  // ═════════════════════════════════════════════════════════════════════
  // Step 3 — Branches
  // ═════════════════════════════════════════════════════════════════════

  Widget _step3Branches() {
    final createdEntities = _createdEntityIds.entries.toList();
    return _card(
      'الفروع (مواقع البيع الفعلية)',
      'كل كيان يحتاج فرعاً واحداً على الأقل.',
      [
        if (createdEntities.isEmpty)
          Text('أنشئ الكيانات أولاً في الخطوة السابقة.',
              style: TextStyle(color: AC.err)),
        ...createdEntities.map((ent) {
          final branchesForEntity = _branchesToCreate
              .where((b) => b['_entity_code'] == ent.key)
              .toList();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.business, color: AC.gold, size: 20),
                  const SizedBox(width: 8),
                  Text('الكيان: ${ent.key}',
                      style: TextStyle(
                          color: AC.tp, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openBranchDialog(ent.key),
                    icon: Icon(Icons.add, color: AC.gold, size: 18),
                    label: Text('فرع', style: TextStyle(color: AC.gold)),
                  ),
                ]),
                if (branchesForEntity.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('لا توجد فروع — أضف فرعاً واحداً على الأقل',
                        style: TextStyle(color: AC.td, fontSize: 12)),
                  ),
                ...branchesForEntity.map((b) {
                  final i = _branchesToCreate.indexOf(b);
                  final created = _createdBranchIds[b['code']];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Icon(
                          created != null
                              ? Icons.check_circle
                              : Icons.store,
                          color: created != null ? AC.ok : AC.ts,
                          size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              '${b['code']} — ${b['name_ar']} (${b['city']})',
                              style: TextStyle(color: AC.tp, fontSize: 13))),
                      if (created == null)
                        IconButton(
                          icon: Icon(Icons.delete, color: AC.err, size: 14),
                          onPressed: () =>
                              setState(() => _branchesToCreate.removeAt(i)),
                        ),
                    ]),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }

  void _openBranchDialog(String entityCode) {
    final codeCtrl = TextEditingController();
    final nameArCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String type = 'retail_store';
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AC.navy2,
          title: Text('فرع جديد في $entityCode',
              style: TextStyle(color: AC.tp)),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _field(codeCtrl, 'كود الفرع *', '$entityCode-RIY-PAN'),
              _field(nameArCtrl, 'اسم الفرع', 'الرياض — بانوراما مول'),
              _field(cityCtrl, 'المدينة', 'الرياض'),
              StatefulBuilder(
                builder: (ctx2, setS) => DropdownButtonFormField<String>(
                  value: type,
                  dropdownColor: AC.navy3,
                  style: TextStyle(color: AC.tp),
                  decoration: InputDecoration(
                      labelText: 'النوع',
                      labelStyle: TextStyle(color: AC.ts)),
                  items: const [
                    DropdownMenuItem(
                        value: 'retail_store', child: Text('متجر تجزئة')),
                    DropdownMenuItem(
                        value: 'wholesale', child: Text('جملة')),
                    DropdownMenuItem(
                        value: 'warehouse_only', child: Text('مستودع فقط')),
                    DropdownMenuItem(
                        value: 'head_office', child: Text('مقر رئيسي')),
                    DropdownMenuItem(
                        value: 'showroom', child: Text('معرض')),
                    DropdownMenuItem(
                        value: 'online', child: Text('متجر إلكتروني')),
                  ],
                  onChanged: (v) => setS(() => type = v!),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: TextStyle(color: AC.ts))),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: AC.gold, foregroundColor: AC.btnFg),
              onPressed: () {
                setState(() => _branchesToCreate.add({
                      '_entity_code': entityCode,
                      'code': codeCtrl.text.trim(),
                      'name_ar': nameArCtrl.text.trim(),
                      'city': cityCtrl.text.trim(),
                      'country': _entitiesToCreate
                          .firstWhere((e) => e['code'] == entityCode)['country'],
                      'type': type,
                    }));
                Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // Step 4 — Warehouses
  // ═════════════════════════════════════════════════════════════════════

  Widget _step4Warehouses() => _card(
        'المستودعات',
        'سيتم إنشاء مستودع افتراضي لكل فرع تلقائياً.',
        [
          if (_branchesToCreate.isEmpty)
            Text('أضف فروعاً في الخطوة السابقة.',
                style: TextStyle(color: AC.err)),
          ..._branchesToCreate.map((b) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AC.navy3,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AC.bdr),
              ),
              child: Row(children: [
                Icon(Icons.warehouse, color: AC.gold),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${b['code']}-MAIN',
                          style: TextStyle(
                              color: AC.tp, fontWeight: FontWeight.w600)),
                      Text('مستودع رئيسي — ${b['name_ar'] ?? b['code']}',
                          style: TextStyle(color: AC.ts, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text('تلقائي', style: TextStyle(color: AC.gold, fontSize: 11)),
              ]),
            );
          }),
        ],
      );

  // ═════════════════════════════════════════════════════════════════════
  // Step 5 — Currencies
  // ═════════════════════════════════════════════════════════════════════

  Widget _step5Currencies() => _card(
        'العملات المُفعَّلة',
        'العملات المطلوبة بناءً على الكيانات التي أضفتها. يمكنك إضافة USD / EUR.',
        [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._activeCurrencies.map(
                (c) => Chip(
                  label: Text(c,
                      style: TextStyle(
                          color: AC.gold, fontWeight: FontWeight.bold)),
                  backgroundColor: AC.gold.withValues(alpha: 0.15),
                  deleteIcon: c == 'SAR'
                      ? null
                      : Icon(Icons.close, color: AC.gold, size: 16),
                  onDeleted: c == 'SAR'
                      ? null
                      : () => setState(() => _activeCurrencies.remove(c)),
                ),
              ),
              ...['USD', 'EUR', 'GBP']
                  .where((c) => !_activeCurrencies.contains(c))
                  .map((c) => ActionChip(
                        label: Text('+ $c', style: TextStyle(color: AC.ts)),
                        backgroundColor: AC.navy3,
                        onPressed: () =>
                            setState(() => _activeCurrencies.add(c)),
                      )),
            ],
          ),
          const SizedBox(height: 16),
          Text(
              'سيتم إنشاء هذه العملات تلقائياً في المستأجر. SAR هي العملة الأساسية.',
              style: TextStyle(color: AC.td, fontSize: 12)),
        ],
      );

  // ═════════════════════════════════════════════════════════════════════
  // Step 6 — CoA
  // ═════════════════════════════════════════════════════════════════════

  Widget _step6CoA() => _card(
        'شجرة الحسابات (SOCPA)',
        'بذر 37 حساباً افتراضياً وفق دليل SOCPA المحاسبي السعودي. يمكن تخصيصها لاحقاً.',
        [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AC.cyan.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AC.cyan.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline, color: AC.cyan),
                  const SizedBox(width: 8),
                  Text('ما يتم بذره:',
                      style: TextStyle(
                          color: AC.tp, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                _bullet('1xxx — الأصول (نقد، بنوك، ذمم مدينة، مخزون، VAT Input)'),
                _bullet('2xxx — الالتزامات (ذمم دائنة، VAT Output، زكاة، EoSB)'),
                _bullet('3xxx — حقوق الملكية (رأس المال، أرباح محتجزة)'),
                _bullet('4xxx — الإيرادات (مبيعات، مرتجعات، خصومات)'),
                _bullet('5xxx — المصروفات (COGS، رواتب، GOSI، إيجار، مرافق...)'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('سيتم بذر الشجرة لكل كيان تم إنشاؤه (${_createdEntityIds.length})',
              style: TextStyle(color: AC.ts)),
        ],
      );

  // ═════════════════════════════════════════════════════════════════════
  // Step 7 — Periods
  // ═════════════════════════════════════════════════════════════════════

  int _fiscalYear = DateTime.now().year;

  Widget _step7Periods() => _card(
        'الفترات المحاسبية',
        'بذر 12 فترة شهرية للسنة المالية الحالية.',
        [
          Row(children: [
            Text('السنة: ', style: TextStyle(color: AC.ts)),
            const SizedBox(width: 8),
            ...[_fiscalYear - 1, _fiscalYear, _fiscalYear + 1].map((y) =>
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: ChoiceChip(
                    label: Text('$y'),
                    selected: _fiscalYear == y,
                    onSelected: (_) => setState(() => _fiscalYear = y),
                    selectedColor: AC.gold.withValues(alpha: 0.25),
                    backgroundColor: AC.navy3,
                    labelStyle: TextStyle(
                        color: _fiscalYear == y ? AC.gold : AC.ts,
                        fontWeight: FontWeight.bold),
                  ),
                )),
          ]),
          const SizedBox(height: 16),
          Text('سيتم إنشاء 12 فترة شهرية (يناير → ديسمبر) لكل كيان.',
              style: TextStyle(color: AC.ts)),
        ],
      );

  // ═════════════════════════════════════════════════════════════════════
  // Step 8 — ZATCA
  // ═════════════════════════════════════════════════════════════════════

  Widget _step8Zatca() {
    final saEntities = _createdEntityIds.keys
        .where((code) => _entitiesToCreate
            .firstWhere((e) => e['code'] == code)['country'] == 'SA')
        .toList();
    return _card(
      'ZATCA Onboarding',
      'تسجيل الكيانات السعودية في نظام فوترة ZATCA (محاكاة).',
      [
        if (saEntities.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AC.warn.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
                'لم تضف كيانات سعودية. هذه الخطوة تُخطَّى.',
                style: TextStyle(color: AC.warn)),
          )
        else
          Column(
            children: saEntities
                .map((code) => ListTile(
                      leading: Icon(Icons.verified, color: AC.gold),
                      title: Text('كيان $code',
                          style: TextStyle(color: AC.tp)),
                      subtitle: Text('سيتم تسجيله في ZATCA (محاكاة CSID)',
                          style: TextStyle(color: AC.ts, fontSize: 12)),
                      trailing: Icon(Icons.auto_awesome, color: AC.cyan, size: 16),
                    ))
                .toList(),
          ),
      ],
    );
  }

  // ═════════════════════════════════════════════════════════════════════
  // Step 9 — Done
  // ═════════════════════════════════════════════════════════════════════

  Widget _stepDone() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AC.ok, width: 2),
        ),
        child: Column(
          children: [
            Icon(Icons.check_circle, color: AC.ok, size: 80),
            const SizedBox(height: 16),
            Text('اكتمل الإعداد بنجاح!',
                style: TextStyle(
                    color: AC.tp, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _summary('المستأجر', _tenantId ?? ''),
            _summary('الكيانات', '${_createdEntityIds.length}'),
            _summary('الفروع', '${_createdBranchIds.length}'),
            _summary('المستودعات', '${_createdBranchIds.length}'),
            _summary(
                'العملات', _activeCurrencies.join(', ')),
            _summary('شجرة حسابات', 'SOCPA (37 حساب × ${_createdEntityIds.length})'),
            _summary('الفترات', '12 فترة شهرية × ${_createdEntityIds.length}'),
            const SizedBox(height: 24),
            Text('الآن يمكنك:',
                style: TextStyle(color: AC.ts, fontSize: 14)),
            const SizedBox(height: 8),
            Text('• فتح ورديات POS وبدء البيع\n'
                '• إنشاء قيود اليومية يدوية\n'
                '• إدارة المنتجات والمخزون\n'
                '• استعراض التقارير المالية\n'
                '• دعوة المستخدمين وتعيين أدوار',
                style: TextStyle(color: AC.tp, height: 1.8)),
          ],
        ),
      ),
    );
  }

  Widget _summary(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(
              width: 120,
              child: Text(k, style: TextStyle(color: AC.ts))),
          Expanded(
              child: Text(v,
                  style: TextStyle(
                      color: AC.tp, fontWeight: FontWeight.w600))),
        ]),
      );

  // ═════════════════════════════════════════════════════════════════════
  // Advance logic
  // ═════════════════════════════════════════════════════════════════════

  Future<void> _advance() async {
    setState(() => _error = null);
    try {
      switch (_step) {
        case 0:
          await _doStep1();
          break;
        case 1:
          await _doStep2();
          break;
        case 2:
          await _doStep3();
          break;
        case 3:
          await _doStep4();
          break;
        case 4:
          await _doStep5();
          break;
        case 5:
          await _doStep6();
          break;
        case 6:
          await _doStep7();
          break;
        case 7:
          await _doStep8();
          break;
      }
      if (mounted) setState(() => _step++);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _doStep1() async {
    if (_slugCtrl.text.trim().isEmpty ||
        _tenantNameArCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty) {
      throw 'الحقول المطلوبة: slug، الاسم العربي، الإيميل';
    }
    setState(() => _loading = true);
    final r = await _client.createTenant({
      'slug': _slugCtrl.text.trim(),
      'legal_name_ar': _tenantNameArCtrl.text.trim(),
      if (_tenantNameEnCtrl.text.isNotEmpty)
        'legal_name_en': _tenantNameEnCtrl.text.trim(),
      if (_crCtrl.text.isNotEmpty) 'primary_cr_number': _crCtrl.text.trim(),
      if (_vatCtrl.text.isNotEmpty) 'primary_vat_number': _vatCtrl.text.trim(),
      'primary_country': _primaryCountry,
      'primary_email': _emailCtrl.text.trim(),
      if (_phoneCtrl.text.isNotEmpty) 'primary_phone': _phoneCtrl.text.trim(),
      'tier': _tier,
    });
    if (!r.success) throw r.error ?? 'فشل إنشاء المستأجر';
    _tenantId = (r.data as Map)['id'];
    PilotSession.tenantId = _tenantId;
    setState(() => _loading = false);
  }

  Future<void> _doStep2() async {
    if (_entitiesToCreate.isEmpty) throw 'أضف كياناً واحداً على الأقل';
    if (_tenantId == null) throw 'المستأجر لم يُنشأ';
    setState(() => _loading = true);
    for (final e in _entitiesToCreate) {
      if (_createdEntityIds.containsKey(e['code'])) continue;
      final r = await _client.createEntity(_tenantId!, Map.from(e));
      if (!r.success) throw 'فشل كيان ${e['code']}: ${r.error}';
      _createdEntityIds[e['code']] = (r.data as Map)['id'];
    }
    // re-bind to refresh bridge's entity list
    PilotSession.tenantId = _tenantId;
    setState(() => _loading = false);
  }

  Future<void> _doStep3() async {
    if (_branchesToCreate.isEmpty) throw 'أضف فرعاً واحداً على الأقل';
    setState(() => _loading = true);
    for (final b in _branchesToCreate) {
      if (_createdBranchIds.containsKey(b['code'])) continue;
      final eid = _createdEntityIds[b['_entity_code']]!;
      final payload = Map<String, dynamic>.from(b)..remove('_entity_code');
      final r = await _client.createBranch(eid, payload);
      if (!r.success) throw 'فشل فرع ${b['code']}: ${r.error}';
      _createdBranchIds[b['code']] = (r.data as Map)['id'];
    }
    PilotSession.tenantId = _tenantId;
    setState(() => _loading = false);
  }

  Future<void> _doStep4() async {
    setState(() => _loading = true);
    for (final b in _branchesToCreate) {
      final bid = _createdBranchIds[b['code']]!;
      // check if already has warehouse
      final existing = await _client.listWarehouses(bid);
      if (existing.success && (existing.data as List).isNotEmpty) continue;
      final r = await _client.createWarehouse(bid, {
        'code': '${b['code']}-MAIN',
        'name_ar': 'مستودع رئيسي — ${b['name_ar'] ?? b['code']}',
        'type': 'main',
        'is_default': true,
        'is_sellable_from': true,
        'is_receivable_to': true,
      });
      if (!r.success) throw 'فشل مستودع ${b['code']}: ${r.error}';
    }
    setState(() => _loading = false);
  }

  Future<void> _doStep5() async {
    setState(() => _loading = true);
    for (final c in _activeCurrencies) {
      final r = await _client.createCurrency(_tenantId!, {
        'code': c,
        'name_ar': _currencyNameAr(c),
        'name_en': _currencyNameEn(c),
        'symbol': _currencySymbol(c),
        'decimal_places': (c == 'KWD' || c == 'BHD' || c == 'OMR') ? 3 : 2,
      });
      // tolerate 409 (already exists)
      if (!r.success && !(r.error?.contains('already') ?? false)) {
        // continue — some currencies are auto-seeded
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _doStep6() async {
    setState(() => _loading = true);
    for (final eid in _createdEntityIds.values) {
      final r = await _client.seedCoa(eid);
      if (!r.success) throw 'فشل بذر CoA: ${r.error}';
    }
    setState(() => _loading = false);
  }

  Future<void> _doStep7() async {
    setState(() => _loading = true);
    for (final eid in _createdEntityIds.values) {
      final r = await _client.seedFiscalPeriods(eid, _fiscalYear);
      if (!r.success) throw 'فشل بذر الفترات: ${r.error}';
    }
    setState(() => _loading = false);
  }

  Future<void> _doStep8() async {
    setState(() => _loading = true);
    final saEntities = _entitiesToCreate
        .where((e) => e['country'] == 'SA')
        .map((e) => _createdEntityIds[e['code']])
        .whereType<String>()
        .toList();
    for (final eid in saEntities) {
      final r = await _client.zatcaOnboard(eid, simulate: true);
      if (!r.success) throw 'فشل ZATCA: ${r.error}';
    }
    setState(() => _loading = false);
  }

  // ═════════════════════════════════════════════════════════════════════
  // Helpers
  // ═════════════════════════════════════════════════════════════════════

  Widget _card(String title, String hint, List<Widget> children) => Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: AC.tp, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(hint, style: TextStyle(color: AC.ts)),
            const Divider(height: 32),
            ...children,
          ],
        ),
      );

  Widget _field(TextEditingController c, String label, String hint) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: AC.ts),
            hintText: hint,
            hintStyle: TextStyle(color: AC.td, fontSize: 12),
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.bdr)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AC.gold)),
          ),
        ),
      );

  Widget _countryPicker(
          String label, String value, ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: value,
          dropdownColor: AC.navy3,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: AC.ts),
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          items: _gccCountries
              .map((c) => DropdownMenuItem(
                    value: c['code'],
                    child: Text('${c['name']} (${c['currency']})',
                        style: TextStyle(color: AC.tp)),
                  ))
              .toList(),
          onChanged: (v) => onChanged(v!),
        ),
      );

  Widget _bullet(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• ', style: TextStyle(color: AC.cyan)),
          Expanded(child: Text(text, style: TextStyle(color: AC.tp))),
        ]),
      );

  String _currencyNameAr(String c) => const {
        'SAR': 'ريال سعودي',
        'AED': 'درهم إماراتي',
        'QAR': 'ريال قطري',
        'KWD': 'دينار كويتي',
        'BHD': 'دينار بحريني',
        'OMR': 'ريال عُماني',
        'EGP': 'جنيه مصري',
        'USD': 'دولار أمريكي',
        'EUR': 'يورو',
        'GBP': 'جنيه إسترليني',
      }[c] ?? c;

  String _currencyNameEn(String c) => const {
        'SAR': 'Saudi Riyal',
        'AED': 'UAE Dirham',
        'QAR': 'Qatari Riyal',
        'KWD': 'Kuwaiti Dinar',
        'BHD': 'Bahraini Dinar',
        'OMR': 'Omani Rial',
        'EGP': 'Egyptian Pound',
        'USD': 'US Dollar',
        'EUR': 'Euro',
        'GBP': 'British Pound',
      }[c] ?? c;

  String _currencySymbol(String c) => const {
        'SAR': '﷼',
        'AED': 'د.إ',
        'QAR': 'ر.ق',
        'KWD': 'د.ك',
        'BHD': 'د.ب',
        'OMR': 'ر.ع',
        'EGP': 'ج.م',
        'USD': '\$',
        'EUR': '€',
        'GBP': '£',
      }[c] ?? c;
}
