/// Vendors — إدارة الموردين.
///
/// مستقلة — تعتمد على PilotSession.tenantId فقط.
///
/// تعرض:
///   • قائمة الموردين (مع فلترة حسب النوع + البحث)
///   • KPI: إجمالي، حسب النوع، مشتريات YTD، رصيد مستحق
///   • Add Vendor (code, names, kind, country, CR/VAT, terms, bank, contact)
///   • View detail (+ Ledger: مجموع فواتير/مدفوعات/aging)
///   • Edit + toggle is_active/on_hold/is_preferred
library;

import 'package:flutter/material.dart';

import '../../api/pilot_client.dart';
import '../../num_utils.dart';
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
const _warn = Color(0xFFF59E0B);

const _kKinds = <String, String>{
  'goods': 'سلع',
  'services': 'خدمات',
  'both': 'سلع وخدمات',
  'employee': 'موظف',
  'government': 'حكومي',
};

const _kTerms = <String, String>{
  'cash': 'نقدي',
  'net_0': 'حال الدفع',
  'net_15': '15 يوم',
  'net_30': '30 يوم',
  'net_45': '45 يوم',
  'net_60': '60 يوم',
  'net_90': '90 يوم',
  'advance': 'مُقدّم',
};

const _kCountries = <String, String>{
  'SA': '🇸🇦 السعودية',
  'AE': '🇦🇪 الإمارات',
  'KW': '🇰🇼 الكويت',
  'QA': '🇶🇦 قطر',
  'BH': '🇧🇭 البحرين',
  'OM': '🇴🇲 عُمان',
  'EG': '🇪🇬 مصر',
};

class VendorsScreen extends StatefulWidget {
  const VendorsScreen({super.key});
  @override
  State<VendorsScreen> createState() => _VendorsScreenState();
}

class _VendorsScreenState extends State<VendorsScreen> {
  final PilotClient _client = pilotClient;
  List<Map<String, dynamic>> _vendors = [];
  bool _loading = true;
  String? _error;
  String _kindFilter = 'all';
  bool _activeOnly = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
        _error = 'يجب اختيار الشركة من شريط العنوان أولاً.';
      });
      return;
    }
    final r = await _client.listVendors(
      PilotSession.tenantId!,
      kind: _kindFilter == 'all' ? null : _kindFilter,
      activeOnly: _activeOnly,
      search: _search.isEmpty ? null : _search,
    );
    if (!r.success) {
      setState(() {
        _loading = false;
        _error = r.error ?? 'فشل تحميل الموردين';
      });
      return;
    }
    setState(() {
      _vendors = List<Map<String, dynamic>>.from(r.data);
      _loading = false;
    });
  }

  Future<void> _add() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => _VendorDialog(existing: null),
    );
    if (res == true) _load();
  }

  Future<void> _edit(Map<String, dynamic> v) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => _VendorDialog(existing: v),
    );
    if (res == true) _load();
  }

  Future<void> _showDetail(Map<String, dynamic> v) async {
    await showDialog(
      context: context,
      builder: (_) => _VendorDetailDialog(vendor: v),
    );
  }

  double _sumField(String field) {
    double t = 0;
    for (final v in _vendors) {
      final val = v[field];
      if (val == null) continue;
      if (val is num) t += val.toDouble();
      if (val is String) t += double.tryParse(val) ?? 0;
    }
    return t;
  }

  int _countByKind(String kind) =>
      _vendors.where((v) => v['kind'] == kind).length;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        body: Column(children: [
          _header(),
          _toolbar(),
          _kpiRow(),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
        color: _navy2,
        border: Border(bottom: BorderSide(color: _bdr)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gold.withValues(alpha: 0.4)),
          ),
          child: const Icon(Icons.local_shipping, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الموردون',
                style: TextStyle(
                    color: _tp, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${_vendors.length} مورد — ${_activeOnly ? "نشط فقط" : "الكل"}',
                style: const TextStyle(color: _ts, fontSize: 12)),
          ],
        ),
        const Spacer(),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
              foregroundColor: _tp, side: const BorderSide(color: _bdr)),
          onPressed: _load,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('تحديث'),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: _gold, foregroundColor: Colors.black),
          onPressed: _add,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('مورد جديد'),
        ),
      ]),
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      color: _navy2.withValues(alpha: 0.6),
      child: Row(children: [
        SizedBox(
          width: 280,
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: _tp, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'بحث بالرقم أو الاسم...',
              hintStyle: const TextStyle(color: _td),
              prefixIcon: const Icon(Icons.search, color: _td, size: 18),
              isDense: true,
              filled: true,
              fillColor: _navy3,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _bdr)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _bdr)),
            ),
            onSubmitted: (v) {
              _search = v;
              _load();
            },
            onChanged: (v) => _search = v,
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: _navy3, foregroundColor: _tp),
          onPressed: _load,
          icon: const Icon(Icons.search, size: 14),
          label: const Text('بحث'),
        ),
        const SizedBox(width: 16),
        _chip('all', 'الكل', _kindFilter == 'all', () {
          setState(() => _kindFilter = 'all');
          _load();
        }),
        const SizedBox(width: 6),
        ..._kKinds.entries.map((e) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _chip(e.key, e.value, _kindFilter == e.key, () {
                setState(() => _kindFilter = e.key);
                _load();
              }),
            )),
        const Spacer(),
        Row(children: [
          Checkbox(
            value: _activeOnly,
            onChanged: (v) {
              setState(() => _activeOnly = v ?? true);
              _load();
            },
            checkColor: Colors.black,
            fillColor: WidgetStateProperty.resolveWith<Color?>(
                (s) => s.contains(WidgetState.selected) ? _gold : _navy3),
          ),
          const Text('نشط فقط', style: TextStyle(color: _ts, fontSize: 12)),
        ]),
      ]),
    );
  }

  Widget _chip(String k, String label, bool sel, VoidCallback tap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? _gold : _navy3,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: sel ? _gold : _bdr, width: sel ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: sel ? Colors.black : _ts,
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
      ),
    );
  }

  Widget _kpiRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      color: _navy,
      child: Row(children: [
        Expanded(
            child: _kpi('الإجمالي', '${_vendors.length}',
                Icons.local_shipping, _gold)),
        const SizedBox(width: 10),
        Expanded(
            child: _kpi('سلع', '${_countByKind("goods")}',
                Icons.inventory_2, _ok)),
        const SizedBox(width: 10),
        Expanded(
            child: _kpi('خدمات', '${_countByKind("services")}',
                Icons.build, const Color(0xFF6366F1))),
        const SizedBox(width: 10),
        Expanded(
            child: _kpi(
                'مشتريات YTD',
                _fmt(_sumField('total_purchases_ytd')),
                Icons.shopping_cart,
                _warn)),
        const SizedBox(width: 10),
        Expanded(
            child: _kpi(
                'مستحق الدفع',
                _fmt(_sumField('outstanding_balance')),
                Icons.payments_outlined,
                _err)),
      ]),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _td, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _gold));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _err, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _ts)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: _tp, side: const BorderSide(color: _bdr)),
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('إعادة المحاولة'),
          ),
        ]),
      );
    }
    if (_vendors.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_shipping_outlined,
              color: _gold.withValues(alpha: 0.4), size: 72),
          const SizedBox(height: 14),
          const Text('لا يوجد موردون بعد',
              style: TextStyle(color: _tp, fontSize: 16)),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('إضافة أول مورد'),
          ),
        ]),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
      children: [
        // Header row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _bdr),
          ),
          child: Row(children: const [
            SizedBox(width: 90, child: Text('الكود', style: _th)),
            Expanded(flex: 3, child: Text('الاسم', style: _th)),
            SizedBox(width: 70, child: Text('النوع', style: _th)),
            SizedBox(width: 80, child: Text('الدولة', style: _th)),
            SizedBox(width: 90, child: Text('الشروط', style: _th)),
            SizedBox(width: 120, child: Text('مشتريات YTD', style: _th, textAlign: TextAlign.end)),
            SizedBox(width: 120, child: Text('المستحق', style: _th, textAlign: TextAlign.end)),
            SizedBox(width: 80, child: Text('الحالة', style: _th)),
          ]),
        ),
        const SizedBox(height: 8),
        ..._vendors.map(_vendorRow),
      ],
    );
  }

  Widget _vendorRow(Map<String, dynamic> v) {
    final ytd = asDouble(v['total_purchases_ytd']);
    final out = asDouble(v['outstanding_balance']);
    final active = v['is_active'] == true;
    final preferred = v['is_preferred'] == true;
    final onHold = v['on_hold'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _showDetail(v),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _navy2.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: onHold
                      ? _err.withValues(alpha: 0.4)
                      : active
                          ? _bdr
                          : _td.withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              SizedBox(
                width: 90,
                child: Text(v['code'] ?? '',
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace')),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      if (preferred) ...[
                        const Icon(Icons.star,
                            color: _warn, size: 12),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(v['legal_name_ar'] ?? '',
                            style: const TextStyle(
                                color: _tp,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                    if ((v['contact_name'] ?? '').toString().isNotEmpty)
                      Text(
                          '${v['contact_name']}${(v['phone'] ?? '').toString().isNotEmpty ? " · ${v["phone"]}" : ""}',
                          style: const TextStyle(color: _td, fontSize: 10),
                          overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              SizedBox(
                  width: 70,
                  child: _tag(_kKinds[v['kind']] ?? v['kind'] ?? '—',
                      v['kind'] == 'goods'
                          ? _ok
                          : v['kind'] == 'services'
                              ? const Color(0xFF6366F1)
                              : _warn)),
              SizedBox(
                width: 80,
                child: Text(
                  _kCountries[v['country']] ?? v['country'] ?? '—',
                  style: const TextStyle(color: _ts, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(_kTerms[v['payment_terms']] ?? v['payment_terms'] ?? '—',
                    style: const TextStyle(color: _ts, fontSize: 11)),
              ),
              SizedBox(
                width: 120,
                child: Text(_fmt(ytd),
                    style: const TextStyle(
                        color: _tp,
                        fontSize: 12,
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.end),
              ),
              SizedBox(
                width: 120,
                child: Text(_fmt(out),
                    style: TextStyle(
                        color: out > 0 ? _err : _td,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace'),
                    textAlign: TextAlign.end),
              ),
              SizedBox(
                width: 80,
                child: Row(children: [
                  if (!active)
                    _tag('معطّل', _td)
                  else if (onHold)
                    _tag('موقوف', _err)
                  else
                    _tag('نشط', _ok),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.edit, color: _ts, size: 16),
                    onPressed: () => _edit(v),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}

const _th = TextStyle(
    color: _td, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5);

// ══════════════════════════════════════════════════════════════════════════
// Vendor Dialog (Add / Edit)
// ══════════════════════════════════════════════════════════════════════════

class _VendorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _VendorDialog({required this.existing});
  @override
  State<_VendorDialog> createState() => _VendorDialogState();
}

class _VendorDialogState extends State<_VendorDialog> {
  final _code = TextEditingController();
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _tradeName = TextEditingController();
  final _category = TextEditingController();
  final _cr = TextEditingController();
  final _vat = TextEditingController();
  final _creditLimit = TextEditingController();
  final _bankName = TextEditingController();
  final _iban = TextEditingController();
  final _swift = TextEditingController();
  final _contactName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _addr1 = TextEditingController();
  final _city = TextEditingController();

  String _kind = 'goods';
  String _country = 'SA';
  String _currency = 'SAR';
  String _terms = 'net_30';
  bool _preferred = false;
  bool _active = true;
  bool _onHold = false;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _code.text = e['code'] ?? '';
      _nameAr.text = e['legal_name_ar'] ?? '';
      _nameEn.text = e['legal_name_en'] ?? '';
      _tradeName.text = e['trade_name'] ?? '';
      _category.text = e['category'] ?? '';
      _cr.text = e['cr_number'] ?? '';
      _vat.text = e['vat_number'] ?? '';
      _creditLimit.text = (e['credit_limit'] ?? '').toString();
      _bankName.text = e['bank_name'] ?? '';
      _iban.text = e['bank_iban'] ?? '';
      _swift.text = e['bank_swift'] ?? '';
      _contactName.text = e['contact_name'] ?? '';
      _email.text = e['email'] ?? '';
      _phone.text = e['phone'] ?? '';
      _addr1.text = e['address_line1'] ?? '';
      _city.text = e['city'] ?? '';
      _kind = e['kind'] ?? 'goods';
      _country = e['country'] ?? 'SA';
      _currency = e['default_currency'] ?? 'SAR';
      _terms = e['payment_terms'] ?? 'net_30';
      _preferred = e['is_preferred'] == true;
      _active = e['is_active'] == true;
      _onHold = e['on_hold'] == true;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _code, _nameAr, _nameEn, _tradeName, _category, _cr, _vat,
      _creditLimit, _bankName, _iban, _swift, _contactName, _email, _phone,
      _addr1, _city,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.text.trim().isEmpty || _nameAr.text.trim().isEmpty) {
      setState(() => _error = 'الكود والاسم العربي مطلوبان');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    if (_isEdit) {
      final body = <String, dynamic>{
        'legal_name_ar': _nameAr.text.trim(),
        'trade_name': _tradeName.text.trim().isEmpty ? null : _tradeName.text.trim(),
        'payment_terms': _terms,
        'credit_limit':
            _creditLimit.text.trim().isEmpty ? null : _creditLimit.text.trim(),
        'bank_iban': _iban.text.trim().isEmpty ? null : _iban.text.trim(),
        'contact_name':
            _contactName.text.trim().isEmpty ? null : _contactName.text.trim(),
        'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'is_active': _active,
        'is_preferred': _preferred,
        'on_hold': _onHold,
      };
      final r = await pilotClient.updateVendor(widget.existing!['id'], body);
      setState(() => _loading = false);
      if (!mounted) return;
      if (r.success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: _ok, content: Text('تم تحديث المورد ✓')));
      } else {
        setState(() => _error = r.error ?? 'فشل التحديث');
      }
    } else {
      final body = <String, dynamic>{
        'code': _code.text.trim(),
        'legal_name_ar': _nameAr.text.trim(),
        if (_nameEn.text.trim().isNotEmpty) 'legal_name_en': _nameEn.text.trim(),
        if (_tradeName.text.trim().isNotEmpty) 'trade_name': _tradeName.text.trim(),
        'kind': _kind,
        if (_category.text.trim().isNotEmpty) 'category': _category.text.trim(),
        'country': _country,
        if (_cr.text.trim().isNotEmpty) 'cr_number': _cr.text.trim(),
        if (_vat.text.trim().isNotEmpty) 'vat_number': _vat.text.trim(),
        'default_currency': _currency,
        'payment_terms': _terms,
        if (_creditLimit.text.trim().isNotEmpty)
          'credit_limit': _creditLimit.text.trim(),
        if (_bankName.text.trim().isNotEmpty) 'bank_name': _bankName.text.trim(),
        if (_iban.text.trim().isNotEmpty) 'bank_iban': _iban.text.trim(),
        if (_swift.text.trim().isNotEmpty) 'bank_swift': _swift.text.trim(),
        if (_contactName.text.trim().isNotEmpty)
          'contact_name': _contactName.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
        if (_addr1.text.trim().isNotEmpty) 'address_line1': _addr1.text.trim(),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
        'is_preferred': _preferred,
      };
      final r = await pilotClient.createVendor(PilotSession.tenantId!, body);
      setState(() => _loading = false);
      if (!mounted) return;
      if (r.success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: _ok, content: Text('تم إنشاء المورد ✓')));
      } else {
        setState(() => _error = r.error ?? 'فشل الإنشاء');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          const Icon(Icons.local_shipping, color: _gold),
          const SizedBox(width: 8),
          Text(_isEdit ? 'تعديل مورد' : 'مورد جديد',
              style: const TextStyle(color: _tp)),
        ]),
        content: SizedBox(
          width: 680,
          height: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('البيانات الأساسية'),
                Row(children: [
                  Expanded(
                      child: _field('الكود *', _code,
                          mono: true, enabled: !_isEdit)),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 2,
                      child: _field('الاسم القانوني (عربي) *', _nameAr)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _field('الاسم الإنجليزي', _nameEn)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('الاسم التجاري', _tradeName)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: _dropdown('النوع', _kind,
                        _kKinds.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(), (v) {
                      setState(() => _kind = v!);
                    }, enabled: !_isEdit),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _field('التصنيف', _category)),
                ]),
                const SizedBox(height: 14),
                _sectionTitle('التسجيل والموقع'),
                Row(children: [
                  Expanded(
                    child: _dropdown('الدولة', _country,
                        _kCountries.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(), (v) {
                      setState(() => _country = v!);
                    }, enabled: !_isEdit),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _field('السجل التجاري (CR)', _cr, mono: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('الرقم الضريبي (VAT)', _vat, mono: true)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(flex: 2, child: _field('العنوان', _addr1)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('المدينة', _city)),
                ]),
                const SizedBox(height: 14),
                _sectionTitle('الشروط المالية'),
                Row(children: [
                  Expanded(
                    child: _dropdown('العملة', _currency, const [
                      DropdownMenuItem(value: 'SAR', child: Text('SAR')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'AED', child: Text('AED')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                    ], (v) {
                      setState(() => _currency = v!);
                    }, enabled: !_isEdit),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dropdown('شروط الدفع', _terms,
                        _kTerms.entries
                            .map((e) => DropdownMenuItem(
                                value: e.key, child: Text(e.value)))
                            .toList(),
                        (v) => setState(() => _terms = v!)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _field('حد الائتمان', _creditLimit, mono: true)),
                ]),
                const SizedBox(height: 14),
                _sectionTitle('البنك'),
                Row(children: [
                  Expanded(child: _field('اسم البنك', _bankName)),
                  const SizedBox(width: 8),
                  Expanded(flex: 2, child: _field('IBAN', _iban, mono: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('SWIFT', _swift, mono: true)),
                ]),
                const SizedBox(height: 14),
                _sectionTitle('التواصل'),
                Row(children: [
                  Expanded(child: _field('اسم المسؤول', _contactName)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('البريد', _email)),
                  const SizedBox(width: 8),
                  Expanded(child: _field('الجوال', _phone, mono: true)),
                ]),
                const SizedBox(height: 14),
                Wrap(spacing: 14, children: [
                  _check('مفضَّل', _preferred,
                      (v) => setState(() => _preferred = v)),
                  if (_isEdit)
                    _check('نشط', _active,
                        (v) => setState(() => _active = v)),
                  if (_isEdit)
                    _check('موقوف', _onHold,
                        (v) => setState(() => _onHold = v)),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _err.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _err.withValues(alpha: 0.4)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: _err, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(color: _err, fontSize: 12))),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: _ts)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_isEdit ? 'حفظ' : 'إنشاء'),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(children: [
        Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: _gold, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(t,
            style: const TextStyle(
                color: _tp, fontSize: 13, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {bool mono = false, bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          enabled: enabled,
          style: TextStyle(
              color: enabled ? _tp : _td,
              fontSize: 12,
              fontFamily: mono ? 'monospace' : null),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: _navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _bdr)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _bdr)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _dropdown<T>(String label, T value, List<DropdownMenuItem<T>> items,
      ValueChanged<T?> onChanged,
      {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _bdr),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              dropdownColor: _navy2,
              style: TextStyle(color: enabled ? _tp : _td, fontSize: 12),
              icon: const Icon(Icons.arrow_drop_down, color: _ts),
              items: items,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Checkbox(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        checkColor: Colors.black,
        fillColor: WidgetStateProperty.resolveWith<Color?>(
            (s) => s.contains(WidgetState.selected) ? _gold : _navy3),
      ),
      Text(label, style: const TextStyle(color: _ts, fontSize: 12)),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Vendor Detail Dialog — includes Ledger
// ══════════════════════════════════════════════════════════════════════════

class _VendorDetailDialog extends StatefulWidget {
  final Map<String, dynamic> vendor;
  const _VendorDetailDialog({required this.vendor});
  @override
  State<_VendorDetailDialog> createState() => _VendorDetailDialogState();
}

class _VendorDetailDialogState extends State<_VendorDetailDialog> {
  Map<String, dynamic>? _ledger;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await pilotClient.vendorLedger(widget.vendor['id']);
    setState(() {
      _loading = false;
      if (r.success && r.data is Map) {
        _ledger = Map<String, dynamic>.from(r.data);
      } else {
        _error = r.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vendor;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: _navy2,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4)),
            child: Text(v['code'] ?? '',
                style: const TextStyle(
                    color: _gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace')),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(v['legal_name_ar'] ?? '',
                  style: const TextStyle(color: _tp, fontSize: 15))),
        ]),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: _kv('الاسم الإنجليزي', v['legal_name_en'] ?? '—')),
                  const SizedBox(width: 10),
                  Expanded(child: _kv('النوع', _kKinds[v['kind']] ?? v['kind'] ?? '—')),
                ]),
                Row(children: [
                  Expanded(
                      child:
                          _kv('الدولة', _kCountries[v['country']] ?? v['country'] ?? '—')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _kv('العملة', v['default_currency'] ?? '—')),
                ]),
                Row(children: [
                  Expanded(child: _kv('CR', v['cr_number'] ?? '—', mono: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _kv('VAT', v['vat_number'] ?? '—', mono: true)),
                ]),
                Row(children: [
                  Expanded(child: _kv('البنك', v['bank_name'] ?? '—')),
                  const SizedBox(width: 10),
                  Expanded(child: _kv('IBAN', v['bank_iban'] ?? '—', mono: true)),
                ]),
                Row(children: [
                  Expanded(child: _kv('المسؤول', v['contact_name'] ?? '—')),
                  const SizedBox(width: 10),
                  Expanded(child: _kv('الجوال', v['phone'] ?? '—', mono: true)),
                ]),
                _kv('البريد', v['email'] ?? '—'),
                _kv('شروط الدفع',
                    _kTerms[v['payment_terms']] ?? v['payment_terms'] ?? '—'),
                const SizedBox(height: 14),
                const Divider(color: _bdr, height: 1),
                const SizedBox(height: 14),
                Row(children: const [
                  Icon(Icons.account_balance_wallet, color: _gold, size: 16),
                  SizedBox(width: 6),
                  Text('كشف حساب المورد',
                      style: TextStyle(
                          color: _tp,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 10),
                if (_loading)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: _gold),
                  ))
                else if (_error != null)
                  Text(_error!, style: const TextStyle(color: _err, fontSize: 12))
                else if (_ledger != null)
                  _buildLedger(_ledger!),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: _gold, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildLedger(Map<String, dynamic> led) {
    final inv = asDouble(led['total_invoiced']);
    final paid = asDouble(led['total_paid']);
    final out = asDouble(led['outstanding_balance']);
    final aging = led['aging'] as Map?;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _ledCard('إجمالي الفواتير', inv, _gold)),
        const SizedBox(width: 8),
        Expanded(child: _ledCard('إجمالي المدفوعات', paid, _ok)),
        const SizedBox(width: 8),
        Expanded(child: _ledCard('الرصيد المستحق', out, out > 0 ? _err : _td)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
            child: _kv('عدد الفواتير', '${led['invoice_count'] ?? 0}')),
        const SizedBox(width: 10),
        Expanded(
            child:
                _kv('عدد المدفوعات', '${led['payment_count'] ?? 0}')),
      ]),
      if (aging != null) ...[
        const SizedBox(height: 10),
        const Text('أعمار الديون:',
            style: TextStyle(color: _td, fontSize: 11, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: _agingCell('0-30', aging['current'], _ok)),
          const SizedBox(width: 4),
          Expanded(child: _agingCell('31-60', aging['days_31_60'], _warn)),
          const SizedBox(width: 4),
          Expanded(child: _agingCell('61-90', aging['days_61_90'], _warn)),
          const SizedBox(width: 4),
          Expanded(child: _agingCell('+90', aging['days_over_90'], _err)),
        ]),
      ],
    ]);
  }

  Widget _ledCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _td, fontSize: 10)),
        const SizedBox(height: 3),
        Text(_fmt(value),
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _agingCell(String label, dynamic value, Color color) {
    final v = value == null ? 0.0 : (value is num ? value.toDouble() : double.tryParse('$value') ?? 0);
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(_fmt(v),
            style: const TextStyle(
                color: _tp, fontSize: 11, fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _kv(String k, String v, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 110,
          child: Text(k, style: const TextStyle(color: _td, fontSize: 11)),
        ),
        Expanded(
          child: Text(v,
              style: TextStyle(
                  color: _tp,
                  fontSize: 12,
                  fontFamily: mono ? 'monospace' : null)),
        ),
      ]),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '—';
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final intP = parts[0]
        .replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$intP.${parts[1]}';
  }
}
