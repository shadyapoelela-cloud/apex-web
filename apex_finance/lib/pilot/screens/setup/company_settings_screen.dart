/// Company Settings — إعدادات الشركة المُستخدِمة للبرنامج.
///
/// ذاتية الاكتفاء — تعرض وتُحرّر:
///   • بيانات المستأجر (Tenant) — الاسم، CR، VAT، الدولة
///   • الكيانات (Entities) — إضافة/تعديل/حذف
///   • الفروع (Branches) — لكل كيان
///   • إعدادات الشركة (CompanySettings) — VAT rate، fiscal year
///
/// يُعرض كـ 4 تابات داخل الشاشة.

library;

import 'package:flutter/material.dart';

import '../../api/pilot_client.dart';
import '../../session.dart';

const _gold = Color(0xFFD4AF37);
const _navy = Color(0xFF0A1628);
const _navy2 = Color(0xFF132339);
const _navy3 = Color(0xFF1D3150);
const _bdr = Color(0x33FFFFFF);
const _tp = Color(0xFFFFFFFF);
const _ts = Color(0xFFBCC5D3);
const _td = Color(0xFF6B7A90);
const _ok = Color(0xFF10B981);
const _err = Color(0xFFEF4444);

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});
  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen>
    with SingleTickerProviderStateMixin {
  final PilotClient _client = pilotClient;
  late final TabController _tab;

  Map<String, dynamic>? _tenant;
  Map<String, dynamic>? _settings;
  List<Map<String, dynamic>> _entities = [];
  List<Map<String, dynamic>> _branches = [];  // flat list — filtered per tab
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (!PilotSession.hasTenant) {
      setState(() {
        _loading = false;
        _error =
            'لم يتم إعداد الشركة بعد. اذهب إلى "رحلة الإعداد" من شريط العنوان.';
      });
      return;
    }

    try {
      final tr = await _client.getTenant(PilotSession.tenantId!);
      if (!tr.success) throw tr.error ?? 'فشل تحميل المستأجر';
      _tenant = Map<String, dynamic>.from(tr.data);

      final sr = await _client.getTenantSettings(PilotSession.tenantId!);
      if (sr.success) _settings = Map<String, dynamic>.from(sr.data);

      final er = await _client.listEntities(PilotSession.tenantId!);
      if (er.success) {
        _entities = List<Map<String, dynamic>>.from(er.data);
      }

      _branches = [];
      for (final e in _entities) {
        final br = await _client.listBranches(e['id']);
        if (br.success) {
          for (final b in (br.data as List)) {
            _branches.add({...Map<String, dynamic>.from(b), '_entity_code': e['code']});
          }
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: _navy,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : _error != null
                ? _errorState()
                : Column(children: [
                    TabBar(
                      controller: _tab,
                      isScrollable: true,
                      labelColor: _gold,
                      unselectedLabelColor: _ts,
                      indicatorColor: _gold,
                      tabs: const [
                        Tab(icon: Icon(Icons.business), text: 'الشركة الأم'),
                        Tab(icon: Icon(Icons.domain), text: 'الكيانات'),
                        Tab(icon: Icon(Icons.store), text: 'الفروع'),
                        Tab(icon: Icon(Icons.settings), text: 'إعدادات'),
                        Tab(icon: Icon(Icons.palette), text: 'الهوية البصرية'),
                      ],
                    ),
                    const Divider(color: _bdr, height: 1),
                    Expanded(
                      child: TabBarView(controller: _tab, children: [
                        _tenantTab(),
                        _entitiesTab(),
                        _branchesTab(),
                        _settingsTab(),
                        _brandingTab(),
                      ]),
                    ),
                  ]),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.warning, color: _err, size: 64),
            const SizedBox(height: 12),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _tp, fontSize: 15)),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ]),
        ),
      );

  // ═════════════════════════════════════════════════════════════
  // Tab 1: Tenant
  // ═════════════════════════════════════════════════════════════

  Widget _tenantTab() {
    final t = _tenant!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.business, color: _gold, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t['legal_name_ar'] ?? '',
                        style: const TextStyle(
                            color: _tp,
                            fontSize: 24,
                            fontWeight: FontWeight.bold)),
                    Text(t['slug'] ?? '',
                        style: const TextStyle(
                            color: _td, fontSize: 13, fontFamily: 'monospace')),
                  ],
                ),
              ),
              _badge(t['status'] ?? '', _colorFor(t['status'])),
              const SizedBox(width: 6),
              _badge(t['tier'] ?? '', _gold),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: BorderSide(color: _gold)),
                icon: const Icon(Icons.edit, color: _gold),
                label: const Text('تعديل', style: TextStyle(color: _gold)),
                onPressed: _editTenant,
              ),
            ]),
            const Divider(color: _bdr, height: 32),
            _info('الاسم بالإنجليزية', t['legal_name_en']),
            _info('الاسم التجاري', t['trade_name']),
            _info('السجل التجاري', t['primary_cr_number']),
            _info('الرقم الضريبي', t['primary_vat_number']),
            _info('الدولة الأساسية', t['primary_country']),
            _info('البريد الإلكتروني', t['primary_email']),
            _info('الهاتف', t['primary_phone']),
            if (t['trial_ends_at'] != null)
              _info('نهاية التجربة', t['trial_ends_at'].toString().substring(0, 10)),
            const Divider(color: _bdr, height: 32),
            Text('معرّفات Pilot',
                style: const TextStyle(
                    color: _ts, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            _info('Tenant ID', t['id'], mono: true),
          ],
        ),
      ),
    );
  }

  Color _colorFor(dynamic status) => switch (status?.toString()) {
        'active' => _ok,
        'trial' => _gold,
        'suspended' || 'cancelled' => _err,
        _ => _ts,
      };

  Widget _badge(String text, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.4))),
      child: Text(text,
          style: TextStyle(
              color: c, fontSize: 12, fontWeight: FontWeight.w600)));

  Widget _info(String k, dynamic v, {bool mono = false}) {
    if (v == null || v.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
            width: 160,
            child: Text(k, style: const TextStyle(color: _ts, fontSize: 13))),
        Expanded(
            child: Text(v.toString(),
                style: TextStyle(
                    color: _tp,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: mono ? 'monospace' : null))),
      ]),
    );
  }

  Future<void> _editTenant() async {
    final t = _tenant!;
    final nameArCtrl = TextEditingController(text: t['legal_name_ar']);
    final nameEnCtrl = TextEditingController(text: t['legal_name_en']);
    final tradeCtrl = TextEditingController(text: t['trade_name']);
    final crCtrl = TextEditingController(text: t['primary_cr_number']);
    final vatCtrl = TextEditingController(text: t['primary_vat_number']);
    final emailCtrl = TextEditingController(text: t['primary_email']);
    final phoneCtrl = TextEditingController(text: t['primary_phone']);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('تعديل بيانات الشركة'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _dialogField(nameArCtrl, 'الاسم القانوني بالعربية'),
                _dialogField(nameEnCtrl, 'الاسم بالإنجليزية'),
                _dialogField(tradeCtrl, 'الاسم التجاري'),
                _dialogField(crCtrl, 'رقم السجل التجاري'),
                _dialogField(vatCtrl, 'الرقم الضريبي'),
                _dialogField(emailCtrl, 'البريد الإلكتروني'),
                _dialogField(phoneCtrl, 'الهاتف'),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    final r = await _client.updateTenant(t['id'], {
      'legal_name_ar': nameArCtrl.text.trim(),
      if (nameEnCtrl.text.isNotEmpty) 'legal_name_en': nameEnCtrl.text.trim(),
      if (tradeCtrl.text.isNotEmpty) 'trade_name': tradeCtrl.text.trim(),
      if (crCtrl.text.isNotEmpty) 'primary_cr_number': crCtrl.text.trim(),
      if (vatCtrl.text.isNotEmpty) 'primary_vat_number': vatCtrl.text.trim(),
      if (emailCtrl.text.isNotEmpty) 'primary_email': emailCtrl.text.trim(),
      if (phoneCtrl.text.isNotEmpty) 'primary_phone': phoneCtrl.text.trim(),
    });
    if (r.success) {
      await _load();
      _showMsg('تم الحفظ', _ok);
    } else {
      _showMsg(r.error ?? 'فشل الحفظ', _err);
    }
  }

  // ═════════════════════════════════════════════════════════════
  // Tab 2: Entities
  // ═════════════════════════════════════════════════════════════

  Widget _entitiesTab() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Text('الكيانات (${_entities.length})',
                style: const TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: _addEntity,
              icon: const Icon(Icons.add),
              label: const Text('كيان جديد'),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: _entities.isEmpty
                ? const Center(
                    child: Text('لا توجد كيانات — أضف واحداً',
                        style: TextStyle(color: _td, fontSize: 14)))
                : ListView.separated(
                    itemCount: _entities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _entityCard(_entities[i]),
                  ),
          ),
        ]),
      );

  Widget _entityCard(Map<String, dynamic> e) {
    final brCount = _branches.where((b) => b['_entity_code'] == e['code']).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(e['code'] ?? '',
              style: const TextStyle(
                  color: _gold, fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e['name_ar'] ?? e['code'],
                  style: const TextStyle(
                      color: _tp,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.public, color: _ts, size: 12),
                const SizedBox(width: 4),
                Text('${e['country']} • ${e['functional_currency']}',
                    style: const TextStyle(color: _ts, fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.store, color: _ts, size: 12),
                const SizedBox(width: 4),
                Text('$brCount فرع',
                    style: const TextStyle(color: _ts, fontSize: 12)),
                if (e['cr_number'] != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.description, color: _ts, size: 12),
                  const SizedBox(width: 4),
                  Text('CR: ${e['cr_number']}',
                      style: const TextStyle(color: _ts, fontSize: 11)),
                ],
              ]),
            ],
          ),
        ),
        _badge(e['status'] ?? '', _colorFor(e['status'])),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.edit, color: _ts, size: 18),
          onPressed: () => _editEntity(e),
        ),
      ]),
    );
  }

  Future<void> _addEntity() async {
    await _entityDialog();
  }

  Future<void> _editEntity(Map<String, dynamic> e) async {
    await _entityDialog(existing: e);
  }

  Future<void> _entityDialog({Map<String, dynamic>? existing}) async {
    final codeCtrl = TextEditingController(text: existing?['code'] ?? '');
    final nameArCtrl = TextEditingController(text: existing?['name_ar'] ?? '');
    final nameEnCtrl = TextEditingController(text: existing?['name_en'] ?? '');
    final crCtrl = TextEditingController(text: existing?['cr_number'] ?? '');
    final vatCtrl = TextEditingController(text: existing?['vat_number'] ?? '');
    String country = existing?['country'] ?? 'SA';
    String currency = existing?['functional_currency'] ?? 'SAR';

    const countries = [
      ('SA', 'السعودية', 'SAR'),
      ('AE', 'الإمارات', 'AED'),
      ('QA', 'قطر', 'QAR'),
      ('KW', 'الكويت', 'KWD'),
      ('BH', 'البحرين', 'BHD'),
      ('OM', 'عُمان', 'OMR'),
      ('EG', 'مصر', 'EGP'),
    ];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(existing == null ? 'كيان جديد' : 'تعديل الكيان'),
            content: SizedBox(
              width: 500,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: country,
                  decoration: const InputDecoration(labelText: 'الدولة'),
                  items: countries
                      .map((c) => DropdownMenuItem(
                            value: c.$1,
                            child: Text('${c.$2} (${c.$3})'),
                          ))
                      .toList(),
                  onChanged: existing != null
                      ? null
                      : (v) => setS(() {
                            country = v!;
                            currency =
                                countries.firstWhere((c) => c.$1 == v).$3;
                            codeCtrl.text = v;
                          }),
                ),
                _dialogField(codeCtrl, 'كود الكيان *',
                    enabled: existing == null),
                _dialogField(nameArCtrl, 'الاسم بالعربية *'),
                _dialogField(nameEnCtrl, 'الاسم بالإنجليزية'),
                _dialogField(crCtrl, 'رقم السجل التجاري'),
                _dialogField(vatCtrl, 'الرقم الضريبي'),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    if (existing == null) {
      final r = await _client.createEntity(PilotSession.tenantId!, {
        'code': codeCtrl.text.trim(),
        'name_ar': nameArCtrl.text.trim(),
        if (nameEnCtrl.text.isNotEmpty) 'name_en': nameEnCtrl.text.trim(),
        'country': country,
        'type': 'subsidiary',
        'functional_currency': currency,
        if (crCtrl.text.isNotEmpty) 'cr_number': crCtrl.text.trim(),
        if (vatCtrl.text.isNotEmpty) 'vat_number': vatCtrl.text.trim(),
      });
      if (r.success) {
        await _load();
        _showMsg('تم إنشاء الكيان', _ok);
      } else {
        _showMsg(r.error ?? 'فشل', _err);
      }
    } else {
      final r = await _client.updateEntity(existing['id'], {
        'name_ar': nameArCtrl.text.trim(),
        if (nameEnCtrl.text.isNotEmpty) 'name_en': nameEnCtrl.text.trim(),
        if (crCtrl.text.isNotEmpty) 'cr_number': crCtrl.text.trim(),
        if (vatCtrl.text.isNotEmpty) 'vat_number': vatCtrl.text.trim(),
      });
      if (r.success) {
        await _load();
        _showMsg('تم الحفظ', _ok);
      } else {
        _showMsg(r.error ?? 'فشل', _err);
      }
    }
  }

  // ═════════════════════════════════════════════════════════════
  // Tab 3: Branches
  // ═════════════════════════════════════════════════════════════

  Widget _branchesTab() => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Text('الفروع (${_branches.length})',
                style: const TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (_entities.isNotEmpty)
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: _addBranch,
                icon: const Icon(Icons.add),
                label: const Text('فرع جديد'),
              ),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: _branches.isEmpty
                ? const Center(
                    child: Text('لا توجد فروع',
                        style: TextStyle(color: _td, fontSize: 14)))
                : ListView.separated(
                    itemCount: _branches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _branchCard(_branches[i]),
                  ),
          ),
        ]),
      );

  Widget _branchCard(Map<String, dynamic> b) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _navy2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _bdr),
        ),
        child: Row(children: [
          Icon(_iconForType(b['type']), color: _gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(b['code'],
                      style: const TextStyle(
                          color: _gold,
                          fontSize: 12,
                          fontFamily: 'monospace')),
                  const SizedBox(width: 6),
                  Text('— ${b['name_ar'] ?? ''}',
                      style: const TextStyle(
                          color: _tp,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  Icon(Icons.place, color: _ts, size: 11),
                  const SizedBox(width: 3),
                  Text('${b['city'] ?? '—'}, ${b['country'] ?? ''}',
                      style: const TextStyle(color: _ts, fontSize: 11)),
                  const SizedBox(width: 10),
                  Text('كيان: ${b['_entity_code']}',
                      style: const TextStyle(color: _ts, fontSize: 11)),
                ]),
              ],
            ),
          ),
          _badge(b['type'] ?? '', _ts),
          const SizedBox(width: 4),
          _badge(b['status'] ?? '', _colorFor(b['status'])),
        ]),
      );

  IconData _iconForType(dynamic t) => switch (t?.toString()) {
        'retail_store' => Icons.store,
        'wholesale' => Icons.warehouse,
        'warehouse_only' => Icons.warehouse_outlined,
        'head_office' => Icons.business_center,
        'showroom' => Icons.visibility,
        'online' => Icons.language,
        _ => Icons.place,
      };

  Future<void> _addBranch() async {
    if (_entities.isEmpty) return;
    String entityCode = _entities.first['code'];
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final cityCtrl = TextEditingController();
    String type = 'retail_store';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('فرع جديد'),
            content: SizedBox(
              width: 500,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  value: entityCode,
                  decoration: const InputDecoration(labelText: 'الكيان'),
                  items: _entities
                      .map((e) => DropdownMenuItem(
                            value: e['code'] as String,
                            child: Text('${e['code']} — ${e['name_ar']}'),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => entityCode = v!),
                ),
                _dialogField(codeCtrl, 'كود الفرع *'),
                _dialogField(nameCtrl, 'اسم الفرع *'),
                _dialogField(cityCtrl, 'المدينة'),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: const [
                    DropdownMenuItem(
                        value: 'retail_store', child: Text('متجر تجزئة')),
                    DropdownMenuItem(value: 'wholesale', child: Text('جملة')),
                    DropdownMenuItem(
                        value: 'warehouse_only', child: Text('مستودع')),
                    DropdownMenuItem(
                        value: 'head_office', child: Text('مقر رئيسي')),
                    DropdownMenuItem(value: 'showroom', child: Text('معرض')),
                    DropdownMenuItem(
                        value: 'online', child: Text('متجر إلكتروني')),
                  ],
                  onChanged: (v) => setS(() => type = v!),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('إنشاء'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    final eid =
        _entities.firstWhere((e) => e['code'] == entityCode)['id'] as String;
    final eCountry = _entities
        .firstWhere((e) => e['code'] == entityCode)['country'] as String;
    final r = await _client.createBranch(eid, {
      'code': codeCtrl.text.trim(),
      'name_ar': nameCtrl.text.trim(),
      'city': cityCtrl.text.trim(),
      'country': eCountry,
      'type': type,
    });
    if (r.success) {
      await _load();
      _showMsg('تم إنشاء الفرع', _ok);
    } else {
      _showMsg(r.error ?? 'فشل', _err);
    }
  }

  // ═════════════════════════════════════════════════════════════
  // Tab 4: Settings (CompanySettings)
  // ═════════════════════════════════════════════════════════════

  Widget _settingsTab() {
    if (_settings == null) {
      return const Center(
          child: Text('لا توجد إعدادات', style: TextStyle(color: _td)));
    }
    final s = _settings!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الإعدادات المالية',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: _bdr),
            _info('العملة الأساسية', s['base_currency']),
            _info('طريقة المحاسبة', _methodLabel(s['accounting_method'])),
            _info('بداية السنة المالية',
                'شهر ${s['fiscal_year_start_month']} — يوم ${s['fiscal_year_start_day']}'),
            _info('نوع الفترة', s['period_type']),
            const SizedBox(height: 20),
            const Text('الضريبة',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: _bdr),
            _info('نسبة VAT', '${s['default_vat_rate']}%'),
            _info('نسبة الزكاة', '${(s['zakat_rate_bp'] ?? 0) / 100}%'),
            const SizedBox(height: 20),
            const Text('اللغة والمنطقة',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: _bdr),
            _info('اللغة الافتراضية', s['default_language']),
            _info('التقويم', s['default_calendar']),
            _info('المنطقة الزمنية', s['default_timezone']),
            const SizedBox(height: 20),
            const Text('الإقفال والاحتفاظ',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: _bdr),
            _info('سياسة الإقفال', s['close_lock_policy']),
            _info('فترة الاحتفاظ', '${s['retention_years']} سنة'),
            const SizedBox(height: 20),
            const Text('ترقيم المستندات',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(color: _bdr),
            _info('قيد يومية', '${s['je_prefix']}-...'),
            _info('فاتورة بيع', '${s['invoice_prefix']}-...'),
            _info('فاتورة شراء', '${s['bill_prefix']}-...'),
            _info('طلب شراء', '${s['po_prefix']}-...'),
            _info('إشعار دائن', '${s['cn_prefix']}-...'),
            const SizedBox(height: 20),
            Row(children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: _editSettings,
                icon: const Icon(Icons.edit),
                label: const Text('تعديل الإعدادات'),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  String _methodLabel(dynamic v) =>
      v == 'cash' ? 'نقدي (cash)' : 'استحقاق (accrual)';

  Future<void> _editSettings() async {
    final s = _settings!;
    final vatCtrl =
        TextEditingController(text: (s['default_vat_rate'] ?? 15).toString());
    final jePrefixCtrl = TextEditingController(text: s['je_prefix']);
    final invPrefixCtrl = TextEditingController(text: s['invoice_prefix']);
    final billPrefixCtrl = TextEditingController(text: s['bill_prefix']);
    String lockPolicy = s['close_lock_policy'] ?? 'hard';
    String method = s['accounting_method'] ?? 'accrual';
    int fyStartMonth = s['fiscal_year_start_month'] ?? 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تعديل إعدادات الشركة'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _dialogField(vatCtrl, 'نسبة VAT الافتراضية (%)'),
                  DropdownButtonFormField<String>(
                    value: method,
                    decoration:
                        const InputDecoration(labelText: 'طريقة المحاسبة'),
                    items: const [
                      DropdownMenuItem(value: 'accrual', child: Text('استحقاق')),
                      DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                    ],
                    onChanged: (v) => setS(() => method = v!),
                  ),
                  DropdownButtonFormField<int>(
                    value: fyStartMonth,
                    decoration:
                        const InputDecoration(labelText: 'شهر بداية السنة المالية'),
                    items: List.generate(
                            12,
                            (i) => DropdownMenuItem(
                                value: i + 1, child: Text('شهر ${i + 1}')))
                        ,
                    onChanged: (v) => setS(() => fyStartMonth = v!),
                  ),
                  DropdownButtonFormField<String>(
                    value: lockPolicy,
                    decoration: const InputDecoration(labelText: 'سياسة الإقفال'),
                    items: const [
                      DropdownMenuItem(
                          value: 'hard', child: Text('إقفال صارم')),
                      DropdownMenuItem(
                          value: 'soft', child: Text('مرن')),
                      DropdownMenuItem(
                          value: 'lenient', child: Text('متساهل')),
                    ],
                    onChanged: (v) => setS(() => lockPolicy = v!),
                  ),
                  const SizedBox(height: 8),
                  const Text('ترقيم المستندات:',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  _dialogField(jePrefixCtrl, 'قيد يومية'),
                  _dialogField(invPrefixCtrl, 'فاتورة بيع'),
                  _dialogField(billPrefixCtrl, 'فاتورة شراء'),
                ]),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('إلغاء')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _gold),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    final r = await _client.updateTenantSettings(PilotSession.tenantId!, {
      'default_vat_rate': int.tryParse(vatCtrl.text) ?? 15,
      'accounting_method': method,
      'fiscal_year_start_month': fyStartMonth,
      'close_lock_policy': lockPolicy,
      'je_prefix': jePrefixCtrl.text.trim(),
      'invoice_prefix': invPrefixCtrl.text.trim(),
      'bill_prefix': billPrefixCtrl.text.trim(),
    });
    if (r.success) {
      await _load();
      _showMsg('تم حفظ الإعدادات', _ok);
    } else {
      _showMsg(r.error ?? 'فشل', _err);
    }
  }

  // ═════════════════════════════════════════════════════════════
  // Tab 5: الهوية البصرية (Branding)
  // ═════════════════════════════════════════════════════════════

  Widget _brandingTab() {
    final s = _settings;
    if (s == null) {
      return const Center(
        child: Text('ابذر إعدادات الشركة أولاً من تبويب "إعدادات"',
            style: TextStyle(color: _ts, fontSize: 13)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _brandingHeader(),
          const SizedBox(height: 16),
          _brandingLogoCard(s),
          const SizedBox(height: 14),
          _brandingColorsCard(s),
          const SizedBox(height: 14),
          _brandingInvoiceCard(s),
          const SizedBox(height: 14),
          _brandingPreviewCard(s),
        ],
      ),
    );
  }

  Widget _brandingHeader() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.palette, color: _gold, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('الهوية البصرية للمستندات',
                  style: TextStyle(
                      color: _tp,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text(
                  'الشعار، الألوان، ورأس/ذيل الفواتير — تنطبق على PO، فواتير البيع والشراء، الإيصالات، القيود',
                  style: TextStyle(color: _ts, fontSize: 11, height: 1.5)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _brandingLogoCard(Map<String, dynamic> s) {
    final logoUrl = (s['logo_url'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.image, color: _gold, size: 18),
            const SizedBox(width: 8),
            const Text('شعار الشركة (Logo)',
                style: TextStyle(
                    color: _tp, fontSize: 14, fontWeight: FontWeight.w800)),
            const Spacer(),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: _gold,
                  side: BorderSide(color: _gold.withValues(alpha: 0.4))),
              onPressed: () => _editBrandField('logo_url',
                  'رابط شعار الشركة (URL أو data:image/png;base64,...)'),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('تعديل URL'),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: _bdr,
                  style: logoUrl.isEmpty
                      ? BorderStyle.solid
                      : BorderStyle.solid),
            ),
            child: logoUrl.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_outlined,
                            color: _td.withValues(alpha: 0.5), size: 32),
                        const SizedBox(height: 4),
                        const Text(
                            'لا يوجد شعار — أضف URL أو data URI لصورة PNG/JPG/SVG',
                            style:
                                TextStyle(color: _td, fontSize: 11)),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(8),
                    child: Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => Center(
                        child: Text(
                            'تعذّر تحميل الشعار من الرابط',
                            style:
                                TextStyle(color: _err, fontSize: 11)),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Text('موقع الشعار في الفاتورة:',
                style: TextStyle(color: _ts, fontSize: 12)),
            const SizedBox(width: 10),
            ...['right', 'left', 'center'].map((pos) {
              final sel = s['logo_position'] == pos;
              return Padding(
                padding: const EdgeInsets.only(left: 6),
                child: InkWell(
                  onTap: () => _updateBrandField('logo_position', pos),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: sel ? _gold : _navy3,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: sel ? _gold : _bdr),
                    ),
                    child: Text(
                      pos == 'right'
                          ? 'يمين'
                          : pos == 'left'
                              ? 'يسار'
                              : 'وسط',
                      style: TextStyle(
                          color: sel ? Colors.black : _ts,
                          fontSize: 11,
                          fontWeight: sel
                              ? FontWeight.w700
                              : FontWeight.w500),
                    ),
                  ),
                ),
              );
            }),
          ]),
        ],
      ),
    );
  }

  Widget _brandingColorsCard(Map<String, dynamic> s) {
    final primary = (s['brand_primary_color'] ?? '#D4AF37').toString();
    final secondary = (s['brand_secondary_color'] ?? '#0A1628').toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.palette_outlined, color: _gold, size: 18),
            SizedBox(width: 8),
            Text('الألوان',
                style: TextStyle(
                    color: _tp, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _colorPickerRow(
                'اللون الأساسي (Headers، أزرار)',
                primary,
                (v) => _updateBrandField('brand_primary_color', v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _colorPickerRow(
                'اللون الثانوي (الخلفية)',
                secondary,
                (v) => _updateBrandField('brand_secondary_color', v),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _colorPickerRow(String label, String hex, ValueChanged<String> onSet) {
    Color parsed;
    try {
      parsed = Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      parsed = _gold;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final ctrl = TextEditingController(text: hex);
            await showDialog(
              context: context,
              builder: (_) => Directionality(
                textDirection: TextDirection.rtl,
                child: AlertDialog(
                  backgroundColor: _navy2,
                  title: Text(label, style: const TextStyle(color: _tp)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                          'أدخل قيمة Hex (مثال: #D4AF37)',
                          style: TextStyle(color: _ts, fontSize: 11)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: ctrl,
                        style: const TextStyle(
                            color: _tp,
                            fontSize: 14,
                            fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: _navy3,
                          hintText: '#D4AF37',
                          hintStyle: const TextStyle(color: _td),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: _bdr)),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء',
                            style: TextStyle(color: _ts))),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: Colors.black),
                      onPressed: () {
                        onSet(ctrl.text.trim());
                        Navigator.pop(context);
                      },
                      child: const Text('حفظ'),
                    ),
                  ],
                ),
              ),
            );
            ctrl.dispose();
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _navy3,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _bdr),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: parsed,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _bdr),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(hex,
                    style: const TextStyle(
                        color: _tp,
                        fontSize: 14,
                        fontFamily: 'monospace')),
              ),
              const Icon(Icons.edit, color: _td, size: 14),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _brandingInvoiceCard(Map<String, dynamic> s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.receipt_long, color: _gold, size: 18),
            SizedBox(width: 8),
            Text('رأس وذيل الفاتورة',
                style: TextStyle(
                    color: _tp, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 12),
          _textFieldRow(
            'رأس الفاتورة (HTML/نص — يظهر أعلى كل فاتورة مطبوعة)',
            (s['invoice_header_html'] ?? '').toString(),
            (v) => _updateBrandField('invoice_header_html', v),
            maxLines: 3,
            placeholder: 'مثال: شركة النور التجارية | سجل تجاري 1010203040',
          ),
          const SizedBox(height: 10),
          _textFieldRow(
            'ذيل الفاتورة',
            (s['invoice_footer_html'] ?? '').toString(),
            (v) => _updateBrandField('invoice_footer_html', v),
            maxLines: 2,
            placeholder: 'مثال: شكراً لتعاملكم معنا',
          ),
          const SizedBox(height: 10),
          _textFieldRow(
            'الشروط والأحكام (عربي)',
            (s['invoice_terms_ar'] ?? '').toString(),
            (v) => _updateBrandField('invoice_terms_ar', v),
            maxLines: 4,
            placeholder: 'شروط الدفع، سياسة الإرجاع، إلخ',
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _switchRow(
                'عرض تفصيل VAT على الفاتورة',
                s['show_vat_breakdown'] == true,
                (v) => _updateBrandField('show_vat_breakdown', v),
              ),
            ),
            Expanded(
              child: _switchRow(
                'عرض QR ZATCA على الفاتورة',
                s['show_qr_on_invoice'] == true,
                (v) => _updateBrandField('show_qr_on_invoice', v),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _textFieldRow(String label, String value, ValueChanged<String> onSave,
      {int maxLines = 1, String? placeholder}) {
    return InkWell(
      onTap: () async {
        final ctrl = TextEditingController(text: value);
        await showDialog(
          context: context,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: _navy2,
              title: Text(label,
                  style: const TextStyle(color: _tp, fontSize: 14)),
              content: SizedBox(
                width: 500,
                child: TextField(
                  controller: ctrl,
                  maxLines: maxLines,
                  style: const TextStyle(color: _tp, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: const TextStyle(color: _td),
                    filled: true,
                    fillColor: _navy3,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: _bdr)),
                  ),
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        const Text('إلغاء', style: TextStyle(color: _ts))),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: _gold, foregroundColor: Colors.black),
                  onPressed: () {
                    onSave(ctrl.text);
                    Navigator.pop(context);
                  },
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ),
        );
        ctrl.dispose();
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _navy3,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: _td, fontSize: 11)),
              ),
              const Icon(Icons.edit, color: _td, size: 12),
            ]),
            const SizedBox(height: 4),
            Text(
              value.isEmpty ? (placeholder ?? '—') : value,
              style: TextStyle(
                color: value.isEmpty ? _td : _tp,
                fontSize: 12,
                height: 1.5,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
          checkColor: Colors.black,
          fillColor: WidgetStateProperty.resolveWith<Color?>(
              (s) => s.contains(WidgetState.selected) ? _gold : _navy3),
        ),
        Expanded(
          child: Text(label, style: const TextStyle(color: _ts, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _brandingPreviewCard(Map<String, dynamic> s) {
    final primary = (s['brand_primary_color'] ?? '#D4AF37').toString();
    Color primaryColor;
    try {
      primaryColor = Color(int.parse(primary.replaceFirst('#', '0xFF')));
    } catch (_) {
      primaryColor = _gold;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: primaryColor, width: 3)),
            ),
            child: Row(children: [
              if ((s['logo_url'] ?? '').toString().isNotEmpty)
                Container(
                  width: 48,
                  height: 48,
                  margin: const EdgeInsets.only(left: 12),
                  child: Image.network(
                    s['logo_url'],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.image, color: primaryColor),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_tenant?['legal_name_ar'] ?? 'الشركة',
                        style: TextStyle(
                            color: primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    if ((s['invoice_header_html'] ?? '').toString().isNotEmpty)
                      Text(s['invoice_header_html'],
                          style: const TextStyle(
                              color: Colors.black54, fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('فاتورة ضريبية',
                      style: TextStyle(
                          color: primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const Text('INV-2026-000001',
                      style: TextStyle(
                          color: Colors.black54,
                          fontSize: 10,
                          fontFamily: 'monospace')),
                ],
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // Body
          Container(
            padding: const EdgeInsets.all(10),
            color: primaryColor.withValues(alpha: 0.08),
            child: const Row(children: [
              Expanded(
                  child: Text('الوصف',
                      style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
              SizedBox(
                  width: 60,
                  child: Text('الكمية',
                      style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
              SizedBox(
                  width: 80,
                  child: Text('الإجمالي',
                      style: TextStyle(
                          color: Colors.black87,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
                      textAlign: TextAlign.end)),
            ]),
          ),
          const SizedBox(height: 4),
          Row(children: const [
            Expanded(
                child: Text('سلعة نموذجية',
                    style: TextStyle(color: Colors.black87, fontSize: 11))),
            SizedBox(
                width: 60,
                child: Text('2',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontFamily: 'monospace'))),
            SizedBox(
                width: 80,
                child: Text('100.00',
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.end)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(children: [
              const Expanded(
                  child: Text('الإجمالي النهائي',
                      style: TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w800))),
              Text('115.00 SAR',
                  style: TextStyle(
                      color: primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace')),
            ]),
          ),
          if ((s['invoice_footer_html'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s['invoice_footer_html'],
                style: const TextStyle(
                    color: Colors.black54, fontSize: 10, height: 1.5),
                textAlign: TextAlign.center),
          ],
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            child: Text('🔍 معاينة الفاتورة المطبوعة',
                style: TextStyle(
                    color: primaryColor.withValues(alpha: 0.6),
                    fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateBrandField(String key, dynamic value) async {
    if (!PilotSession.hasTenant) return;
    final r = await _client.updateTenantSettings(
        PilotSession.tenantId!, {key: value});
    if (!mounted) return;
    if (r.success) {
      // update local state for immediate preview
      setState(() {
        if (_settings != null) _settings![key] = value;
      });
      _showMsg('تم حفظ $key ✓', _ok);
    } else {
      _showMsg(r.error ?? 'فشل الحفظ', _err);
    }
  }

  Future<void> _editBrandField(String key, String label) async {
    final ctrl = TextEditingController(
        text: (_settings?[key] ?? '').toString());
    await showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Text(label, style: const TextStyle(color: _tp, fontSize: 14)),
          content: SizedBox(
            width: 500,
            child: TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(
                  color: _tp, fontSize: 12, fontFamily: 'monospace'),
              decoration: InputDecoration(
                filled: true,
                fillColor: _navy3,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: const BorderSide(color: _bdr)),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء', style: TextStyle(color: _ts))),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _gold, foregroundColor: Colors.black),
              onPressed: () {
                _updateBrandField(key, ctrl.text);
                Navigator.pop(context);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
  }

  // ═════════════════════════════════════════════════════════════
  // Shared helpers
  // ═════════════════════════════════════════════════════════════

  Widget _dialogField(TextEditingController c, String label,
          {bool enabled = true}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: c,
          enabled: enabled,
          decoration: InputDecoration(labelText: label),
        ),
      );

  void _showMsg(String msg, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(backgroundColor: c, content: Text(msg)));
  }
}
