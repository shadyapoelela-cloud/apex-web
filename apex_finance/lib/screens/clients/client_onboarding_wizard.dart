import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

InputDecoration _inp(String l, {IconData? ic}) => InputDecoration(
  labelText: l, prefixIcon: ic != null ? Icon(ic, color: AC.gold, size: 20) : null,
  filled: true, fillColor: AC.navy3, labelStyle: TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.gold)),
);

class ClientOnboardingWizard extends StatefulWidget {
  final String? token;
  const ClientOnboardingWizard({super.key, this.token});
  @override State<ClientOnboardingWizard> createState() => _WizardState();
}

class _WizardState extends State<ClientOnboardingWizard> {
  int _step = 0;
  bool _loading = true;
  String? _error;

  final _nameArC = TextEditingController();
  final _nameEnC = TextEditingController();
  final _crC = TextEditingController();
  final _taxC = TextEditingController();
  final _vatC = TextEditingController();          // NEW — ZATCA 15-digit VAT
  final _addressC = TextEditingController();
  final _cityC = TextEditingController();

  // NEW — tax jurisdiction + default currency per client
  String _jurisdiction = 'SA';                    // SA/AE/KW/BH/QA/OM/EG
  String _currency = 'SAR';                       // ISO 4217

  // Matching pair for the jurisdiction dropdown (name_ar, currency_default)
  static const List<Map<String, String>> _jurisdictions = [
    {'code': 'SA', 'name_ar': 'السعودية', 'currency': 'SAR'},
    {'code': 'AE', 'name_ar': 'الإمارات', 'currency': 'AED'},
    {'code': 'KW', 'name_ar': 'الكويت',   'currency': 'KWD'},
    {'code': 'BH', 'name_ar': 'البحرين',  'currency': 'BHD'},
    {'code': 'QA', 'name_ar': 'قطر',      'currency': 'QAR'},
    {'code': 'OM', 'name_ar': 'عُمان',     'currency': 'OMR'},
    {'code': 'EG', 'name_ar': 'مصر',      'currency': 'EGP'},
  ];
  static const List<String> _currencies = ['SAR', 'AED', 'KWD', 'BHD', 'QAR', 'OMR', 'EGP', 'USD', 'EUR'];

  @override void dispose() {
    _nameArC.dispose(); _nameEnC.dispose(); _crC.dispose();
    _taxC.dispose(); _vatC.dispose();
    _addressC.dispose(); _cityC.dispose();
    super.dispose();
  }

  List<dynamic> _entityTypes = [];
  String? _selectedEntityType;

  List<dynamic> _sectors = [];
  String? _selectedSector;

  List<dynamic> _subSectors = [];
  String? _selectedSubSector;

  String _clientType = 'standard_business';

  Map<String, dynamic>? _stageNote;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      // Load draft
      final dr = await ApiService.getOnboardingDraft();
      if (dr.success && dr.data != null) {
        final draft = dr.data['data'] ?? dr.data;
        final data = draft['draft_data'] ?? {};
        _step = draft['step_completed'] ?? 0;
        _nameArC.text = data['name_ar'] ?? '';
        _nameEnC.text = data['name_en'] ?? '';
        _crC.text = data['cr_number'] ?? '';
        _taxC.text = data['tax_number'] ?? '';
        _vatC.text = data['vat_registration_number'] ?? '';
        _addressC.text = data['national_address'] ?? '';
        _cityC.text = data['city'] ?? '';
        _selectedEntityType = data['legal_entity_type'];
        _selectedSector = data['sector_main_code'];
        _selectedSubSector = data['sector_sub_code'];
        _clientType = data['client_type'] ?? 'standard_business';
        _jurisdiction = data['tax_jurisdiction'] ?? 'SA';
        _currency = data['currency'] ?? 'SAR';
      }

      // Load entity types
      final et = await ApiService.getLegalEntityTypes();
      if (et.success) _entityTypes = et.data is List ? et.data : (et.data['data'] ?? []);

      // Load sectors
      final sc = await ApiService.getSectors();
      if (sc.success) _sectors = sc.data is List ? sc.data : (sc.data['data'] ?? []);

      // Load sub sectors if sector selected
      if (_selectedSector != null) await _loadSubSectors(_selectedSector!);

      // Load stage note
      await _loadStageNote();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSubSectors(String mainCode) async {
    try {
      final r = await ApiService.getSubSectors(mainCode);
      if (r.success) _subSectors = r.data is List ? r.data : (r.data['data'] ?? []);
    } catch (_) {}
  }

  Future<void> _loadStageNote() async {
    const stages = ['entity_info', 'legal_entity', 'sector', 'sector', 'client_type', 'documents', 'review'];
    if (_step < stages.length) {
      try {
        final r = await ApiService.getStageNotes('client_onboarding', stages[_step]);
        if (r.success) _stageNote = r.data is Map ? (r.data['data'] ?? r.data) : null;
      } catch (_) {}
    }
  }

  Future<void> _saveDraft() async {
    try {
      await ApiService.saveOnboardingDraft(step: _step, data: {
        'name_ar': _nameArC.text, 'name_en': _nameEnC.text,
        'cr_number': _crC.text, 'tax_number': _taxC.text,
        'vat_registration_number': _vatC.text,
        'national_address': _addressC.text, 'city': _cityC.text,
        'legal_entity_type': _selectedEntityType,
        'sector_main_code': _selectedSector,
        'sector_sub_code': _selectedSubSector,
        'client_type': _clientType,
        'tax_jurisdiction': _jurisdiction,
        'currency': _currency,
      });
    } catch (_) {}
  }

  void _next() async {
    if (_step == 0 && _nameArC.text.trim().isEmpty) {
      setState(() => _error = 'الاسم العربي مطلوب');
      return;
    }
    if (_step == 1 && _selectedEntityType == null) {
      setState(() => _error = 'اختر الشكل القانوني');
      return;
    }
    if (_step == 2 && _selectedSector == null) {
      setState(() => _error = 'اختر النشاط الرئيسي');
      return;
    }
    setState(() { _error = null; _step++; });
    await _saveDraft();
    await _loadStageNote();
    if (mounted) setState(() {});
  }

  void _back() {
    if (_step > 0) setState(() { _step--; _error = null; });
    _loadStageNote().then((_) { if (mounted) setState(() {}); });
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.createClientFromOnboarding({
        'name_ar': _nameArC.text.trim(),
        'client_type_code': _clientType,
        'name_en': _nameEnC.text.trim(),
        'cr_number': _crC.text.trim(),
        'tax_number': _taxC.text.trim(),
        'vat_registration_number': _vatC.text.trim(),
        'city': _cityC.text.trim(),
        'tax_jurisdiction': _jurisdiction,
        'currency': _currency,
      });
      if (mounted) {
        if (r.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إنشاء العميل بنجاح'), backgroundColor: AC.ok));
          Navigator.pop(context, true);
        } else {
          setState(() { _error = r.error ?? 'فشل الإنشاء'; _loading = false; });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'خطأ: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: AC.navy,
        body: Center(child: CircularProgressIndicator(color: AC.gold)));
    }

    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: Text('تسجيل عميل جديد', style: TextStyle(color: AC.gold)),
        leading: _step > 0 ? IconButton(icon: Icon(Icons.arrow_back, color: AC.gold), onPressed: _back) : null,
        actions: [
          if (_stageNote != null) ApexIconButton(
            icon: Icons.help_outline,
            color: AC.gold,
            tooltip: 'لماذا هذه الخطوة؟',
            onPressed: () => _showStageNote(context)),
        ],
      ),
      body: Column(children: [
        _buildProgressBar(),
        if (_error != null) Container(
          margin: EdgeInsets.all(12), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(Icons.error_outline, color: AC.err, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text(_error!, style: TextStyle(color: AC.err, fontSize: 12))),
          ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildStep())),
        Padding(padding: EdgeInsets.all(16), child: Row(children: [
          if (_step > 0) Expanded(child: apexSecondaryButton('السابق', _back)),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(child: apexPrimaryButton(_step == 6 ? 'إنشاء العميل' : 'التالي', _step == 6 ? _submit : _next)),
        ])),
      ]),
    );
  }

  Widget _buildProgressBar() {
    final percent = ((_step + 1) / 7 * 100).toInt();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('خطوة ' + (_step + 1).toString() + ' من 7', style: TextStyle(color: AC.ts, fontSize: 12)),
          Text(percent.toString() + '%', style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: (_step + 1) / 7, minHeight: 6,
            backgroundColor: AC.navy3, valueColor: AlwaysStoppedAnimation(AC.gold))),
        SizedBox(height: 4),
        Text(_stepTitle(), style: TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  String _stepTitle() {
    const titles = ['بيانات الكيان', 'الشكل القانوني', 'النشاط الرئيسي', 'النشاط الفرعي', 'نوع العميل', 'المستندات', 'المراجعة والتفعيل'];
    return titles[_step.clamp(0, 6)];
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _stepEntityInfo();
      case 1: return _stepLegalEntity();
      case 2: return _stepMainSector();
      case 3: return _stepSubSector();
      case 4: return _stepClientType();
      case 5: return _stepDocuments();
      case 6: return _stepReview();
      default: return const SizedBox();
    }
  }

  Widget _stepEntityInfo() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    _field('الاسم التجاري (عربي) *', _nameArC, Icons.business),
    _field('الاسم التجاري (إنجليزي)', _nameEnC, Icons.business),
    _field('السجل التجاري', _crC, Icons.assignment),
    _field('الرقم الضريبي', _taxC, Icons.receipt),
    // NEW — ZATCA 15-digit VAT registration number
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _vatC,
        keyboardType: TextInputType.number,
        maxLength: 15,
        style: TextStyle(color: AC.tp),
        decoration: _inp('رقم التسجيل الضريبي (VAT) — 15 رقم', ic: Icons.qr_code_2).copyWith(
          counterText: '',
          helperText: 'مطلوب للفوترة الإلكترونية ZATCA في السعودية',
          helperStyle: TextStyle(color: AC.ts, fontSize: 11),
        ),
      ),
    ),
    // NEW — Jurisdiction + Currency (side-by-side on wide screens, stacked on narrow)
    LayoutBuilder(builder: (ctx, cons) {
      final wide = cons.maxWidth > 480;
      final jDropdown = _jurisdictionDropdown();
      final cDropdown = _currencyDropdown();
      if (!wide) {
        return Column(children: [
          Padding(padding: const EdgeInsets.only(bottom: 12), child: jDropdown),
          Padding(padding: const EdgeInsets.only(bottom: 12), child: cDropdown),
        ]);
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          Expanded(child: jDropdown),
          const SizedBox(width: 12),
          Expanded(child: cDropdown),
        ]),
      );
    }),
    _field('العنوان الوطني', _addressC, Icons.location_on),
    _field('المدينة', _cityC, Icons.location_city),
  ]);

  Widget _jurisdictionDropdown() => DropdownButtonFormField<String>(
    value: _jurisdiction,
    decoration: _inp('الولاية الضريبية', ic: Icons.public),
    dropdownColor: AC.navy2,
    style: TextStyle(color: AC.tp, fontSize: 14),
    items: _jurisdictions.map((j) => DropdownMenuItem(
      value: j['code'],
      child: Text('${j['code']} — ${j['name_ar']}',
        style: TextStyle(color: AC.tp)),
    )).toList(),
    onChanged: (v) {
      if (v == null) return;
      setState(() {
        _jurisdiction = v;
        // Auto-pick currency matching the jurisdiction (user can override)
        final match = _jurisdictions.firstWhere(
          (j) => j['code'] == v,
          orElse: () => {'currency': _currency},
        );
        _currency = match['currency'] ?? _currency;
      });
    },
  );

  Widget _currencyDropdown() => DropdownButtonFormField<String>(
    value: _currency,
    decoration: _inp('العملة', ic: Icons.payments),
    dropdownColor: AC.navy2,
    style: TextStyle(color: AC.tp, fontSize: 14),
    items: _currencies.map((c) => DropdownMenuItem(
      value: c,
      child: Text(c, style: TextStyle(color: AC.tp)),
    )).toList(),
    onChanged: (v) { if (v != null) setState(() => _currency = v); },
  );

  Widget _field(String label, TextEditingController c, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: c, style: TextStyle(color: AC.tp), decoration: _inp(label, ic: icon)));

  Widget _stepLegalEntity() => Column(children: _entityTypes.map((e) =>
    _radioTile(e['code'], e['name_ar'], e['description_ar'] ?? '', _selectedEntityType,
      (v) => setState(() => _selectedEntityType = v))).toList());

  Widget _stepMainSector() => Column(children: _sectors.map((s) =>
    _radioTile(s['code'], s['name_ar'], '', _selectedSector,
      (v) { setState(() { _selectedSector = v; _selectedSubSector = null; _subSectors = []; });
        _loadSubSectors(v!).then((_) { if (mounted) setState(() {}); }); })).toList());

  Widget _stepSubSector() => _subSectors.isEmpty
    ? Center(child: Padding(padding: EdgeInsets.all(32), child: Text('اختر النشاط الرئيسي أولاً أو لا توجد أنشطة فرعية', style: TextStyle(color: AC.ts))))
    : Column(children: _subSectors.map((s) {
        final hasLicense = s['requires_license'] == true;
        return _radioTile(s['code'], s['name_ar'], hasLicense ? 'يتطلب ترخيص' : '', _selectedSubSector,
          (v) => setState(() => _selectedSubSector = v), badge: hasLicense ? 'مرخص' : null);
      }).toList());

  Widget _stepClientType() {
    const types = [
      {'code': 'standard_business', 'label': 'شركة تجارية عادية', 'km': false},
      {'code': 'financial_entity', 'label': 'جهة مالية', 'km': true},
      {'code': 'accounting_firm', 'label': 'مكتب محاسبة', 'km': true},
      {'code': 'audit_firm', 'label': 'مكتب مراجعة', 'km': true},
      {'code': 'investment_entity', 'label': 'جهة استثمارية', 'km': true},
      {'code': 'government_entity', 'label': 'جهة حكومية', 'km': true},
      {'code': 'legal_regulatory_entity', 'label': 'جهة قانونية/تنظيمية', 'km': true},
    ];
    return Column(children: types.map((t) =>
      _radioTile(t['code'] as String, t['label'] as String, '', _clientType,
        (v) => setState(() => _clientType = v!),
        badge: (t['km'] as bool) ? 'معرفي' : null)).toList());
  }

  Widget _stepDocuments() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Icon(Icons.cloud_upload, size: 48, color: AC.gold),
    SizedBox(height: 12),
    Text('المستندات المطلوبة ستظهر بناءً على نوع الكيان والنشاط',
      textAlign: TextAlign.center, style: TextStyle(color: AC.ts, fontSize: 14)),
    SizedBox(height: 12),
    Container(padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('المستندات الأساسية:', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _docRow('السجل التجاري', _crC.text.isNotEmpty),
        _docRow('الرقم الضريبي', _taxC.text.isNotEmpty),
        _docRow('العنوان الوطني', _addressC.text.isNotEmpty),
        if (_selectedEntityType != null && _selectedEntityType != 'individual')
          _docRow('عقد التأسيس', false),
      ])),
  ]);

  Widget _docRow(String name, bool done) => Padding(
    padding: EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? AC.ok : AC.ts, size: 18),
      SizedBox(width: 8),
      Text(name, style: TextStyle(color: done ? AC.tp : AC.ts, fontSize: 13)),
    ]));

  Widget _stepReview() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Icon(Icons.verified, size: 48, color: AC.ok),
    SizedBox(height: 12),
    Text('مراجعة البيانات قبل الإنشاء', textAlign: TextAlign.center,
      style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    _reviewRow('الاسم العربي', _nameArC.text),
    _reviewRow('الاسم الإنجليزي', _nameEnC.text),
    _reviewRow('السجل التجاري', _crC.text),
    _reviewRow('الرقم الضريبي', _taxC.text),
    _reviewRow('الشكل القانوني', _selectedEntityType ?? '—'),
    _reviewRow('النشاط الرئيسي', _selectedSector ?? '—'),
    _reviewRow('النشاط الفرعي', _selectedSubSector ?? '—'),
    _reviewRow('نوع العميل', _clientType),
    _reviewRow('المدينة', _cityC.text),
  ]);

  Widget _reviewRow(String label, String value) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(color: AC.ts, fontSize: 13)),
      Flexible(child: Text(value.isEmpty ? '—' : value,
        style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
    ]));

  Widget _radioTile(String code, String label, String desc, String? selected, ValueChanged<String?> onChanged, {String? badge}) {
    final sel = selected == code;
    return GestureDetector(
      onTap: () => onChanged(code),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: apexSelectableDecoration(isSelected: sel, activeColor: AC.gold),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? AC.gold : AC.ts, size: 20),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: sel ? AC.gold : AC.tp, fontSize: 14, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
            if (desc.isNotEmpty) Text(desc, style: TextStyle(color: AC.ts, fontSize: 11)),
          ])),
          if (badge != null) Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(badge, style: TextStyle(color: AC.gold, fontSize: 10))),
        ])));
  }

  void _showStageNote(BuildContext ctx) {
    if (_stageNote == null) return;
    showModalBottomSheet(context: ctx, backgroundColor: AC.navy2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(padding: EdgeInsets.all(20), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.help_outline, color: AC.gold),
            SizedBox(width: 8),
            Expanded(child: Text(_stageNote!['title_ar'] ?? '', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
          SizedBox(height: 12),
          Text(_stageNote!['body_ar'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13, height: 1.6)),
          if (_stageNote!['common_errors_ar'] != null) ...[
            SizedBox(height: 12),
            Text('أخطاء شائعة:', style: TextStyle(color: AC.warn, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(_stageNote!['common_errors_ar'], style: TextStyle(color: AC.warn, fontSize: 12)),
          ],
          if (_stageNote!['impact_ar'] != null) ...[
            SizedBox(height: 12),
            Text('أثر عدم الإكمال:', style: TextStyle(color: AC.err, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(_stageNote!['impact_ar'], style: TextStyle(color: AC.err, fontSize: 12)),
          ],
          const SizedBox(height: 20),
        ])));
  }
}
