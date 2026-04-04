import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

const _api = 'https://apex-api-ootk.onrender.com';

class AC {
  static const gold = Color(0xFFC9A84C);
  static const navy = Color(0xFF050D1A);
  static const navy2 = Color(0xFF080F1F);
  static const navy3 = Color(0xFF0D1829);
  static const navy4 = Color(0xFF0F2040);
  static const cyan = Color(0xFF00C2E0);
  static const tp = Color(0xFFF0EDE6);
  static const ts = Color(0xFF8A8880);
  static const ok = Color(0xFF2ECC8A);
  static const warn = Color(0xFFF0A500);
  static const err = Color(0xFFE05050);
  static const bdr = Color(0x26C9A84C);
}

InputDecoration _inp(String l, {IconData? ic}) => InputDecoration(
  labelText: l, prefixIcon: ic != null ? Icon(ic, color: AC.gold, size: 20) : null,
  filled: true, fillColor: AC.navy3, labelStyle: const TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold)),
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
  final _addressC = TextEditingController();
  final _cityC = TextEditingController();

  List<dynamic> _entityTypes = [];
  String? _selectedEntityType;

  List<dynamic> _sectors = [];
  String? _selectedSector;

  List<dynamic> _subSectors = [];
  String? _selectedSubSector;

  String _clientType = 'standard_business';

  Map<String, dynamic>? _stageNote;

  Map<String, String> get _h => {
    'Authorization': 'Bearer ${widget.token ?? ""}',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    try {
      // Load draft
      final dr = await http.get(Uri.parse('$_api/onboarding/draft'), headers: _h);
      if (dr.statusCode == 200) {
        final d = jsonDecode(dr.body);
        if (d['success'] == true && d['data'] != null) {
          final data = d['data']['draft_data'] ?? {};
          _step = d['data']['step_completed'] ?? 0;
          _nameArC.text = data['name_ar'] ?? '';
          _nameEnC.text = data['name_en'] ?? '';
          _crC.text = data['cr_number'] ?? '';
          _taxC.text = data['tax_number'] ?? '';
          _addressC.text = data['national_address'] ?? '';
          _cityC.text = data['city'] ?? '';
          _selectedEntityType = data['legal_entity_type'];
          _selectedSector = data['sector_main_code'];
          _selectedSubSector = data['sector_sub_code'];
          _clientType = data['client_type'] ?? 'standard_business';
        }
      }

      // Load entity types
      final et = await http.get(Uri.parse('$_api/legal-entity-types'));
      if (et.statusCode == 200) _entityTypes = jsonDecode(et.body)['data'] ?? [];

      // Load sectors
      final sc = await http.get(Uri.parse('$_api/sectors'));
      if (sc.statusCode == 200) _sectors = jsonDecode(sc.body)['data'] ?? [];

      // Load sub sectors if sector selected
      if (_selectedSector != null) await _loadSubSectors(_selectedSector!);

      // Load stage note
      await _loadStageNote();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSubSectors(String mainCode) async {
    try {
      final r = await http.get(Uri.parse('$_api/sectors/$mainCode/sub'));
      if (r.statusCode == 200) _subSectors = jsonDecode(r.body)['data'] ?? [];
    } catch (_) {}
  }

  Future<void> _loadStageNote() async {
    const stages = ['entity_info', 'legal_entity', 'sector', 'sector', 'client_type', 'documents', 'review'];
    if (_step < stages.length) {
      try {
        final r = await http.get(Uri.parse('$_api/stage-notes/client_onboarding/${stages[_step]}'));
        if (r.statusCode == 200) {
          final d = jsonDecode(r.body);
          if (d['success'] == true) _stageNote = d['data'];
        }
      } catch (_) {}
    }
  }

  Future<void> _saveDraft() async {
    try {
      await http.post(Uri.parse('$_api/onboarding/draft'), headers: _h,
        body: jsonEncode({
          'step_completed': _step,
          'draft_data': {
            'name_ar': _nameArC.text, 'name_en': _nameEnC.text,
            'cr_number': _crC.text, 'tax_number': _taxC.text,
            'national_address': _addressC.text, 'city': _cityC.text,
            'legal_entity_type': _selectedEntityType,
            'sector_main_code': _selectedSector,
            'sector_sub_code': _selectedSubSector,
            'client_type': _clientType,
          }
        }));
    } catch (_) {}
  }

  void _next() async {
    if (_step == 0 && _nameArC.text.trim().isEmpty) {
      setState(() => _error = 'ط§ظ„ط§ط³ظ… ط§ظ„ط¹ط±ط¨ظٹ ظ…ط·ظ„ظˆط¨');
      return;
    }
    if (_step == 1 && _selectedEntityType == null) {
      setState(() => _error = 'ط§ط®طھط± ط§ظ„ط´ظƒظ„ ط§ظ„ظ‚ط§ظ†ظˆظ†ظٹ');
      return;
    }
    if (_step == 2 && _selectedSector == null) {
      setState(() => _error = 'ط§ط®طھط± ط§ظ„ظ†ط´ط§ط· ط§ظ„ط±ط¦ظٹط³ظٹ');
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
      final r = await http.post(Uri.parse('$_api/clients'), headers: _h,
        body: jsonEncode({
          'name_ar': _nameArC.text.trim(),
          'client_type_code': _clientType,
          'name_en': _nameEnC.text.trim(),
          'cr_number': _crC.text.trim(),
          'tax_number': _taxC.text.trim(),
          'city': _cityC.text.trim(),
        }));
      final d = jsonDecode(r.body);
      if (mounted) {
        if (r.statusCode == 200 && d['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('طھظ… ط¥ظ†ط´ط§ط، ط§ظ„ط¹ظ…ظٹظ„ ط¨ظ†ط¬ط§ط­'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        } else {
          setState(() { _error = d['detail'] ?? d['error'] ?? 'ظپط´ظ„ ط§ظ„ط¥ظ†ط´ط§ط،'; _loading = false; });
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'ط®ط·ط£: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: AC.navy,
        body: const Center(child: CircularProgressIndicator(color: AC.gold)));
    }

    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: const Text('طھط³ط¬ظٹظ„ ط¹ظ…ظٹظ„ ط¬ط¯ظٹط¯', style: TextStyle(color: AC.gold)),
        leading: _step > 0 ? IconButton(icon: const Icon(Icons.arrow_back, color: AC.gold), onPressed: _back) : null,
        actions: [
          if (_stageNote != null) IconButton(
            icon: const Icon(Icons.help_outline, color: AC.gold),
            tooltip: 'ظ„ظ…ط§ط°ط§ ظ‡ط°ظ‡ ط§ظ„ط®ط·ظˆط©طں',
            onPressed: () => _showStageNote(context)),
        ],
      ),
      body: Column(children: [
        _buildProgressBar(),
        if (_error != null) Container(
          margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AC.err.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            const Icon(Icons.error_outline, color: AC.err, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_error!, style: const TextStyle(color: AC.err, fontSize: 12))),
          ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: _buildStep())),
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          if (_step > 0) Expanded(child: OutlinedButton(
            onPressed: _back,
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.gold), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('ط§ظ„ط³ط§ط¨ظ‚', style: TextStyle(color: AC.gold)))),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: _step == 6 ? _submit : _next,
            style: ElevatedButton.styleFrom(
              backgroundColor: _step == 6 ? Colors.green.shade700 : AC.gold,
              padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(_step == 6 ? 'ط¥ظ†ط´ط§ط، ط§ظ„ط¹ظ…ظٹظ„' : 'ط§ظ„طھط§ظ„ظٹ',
              style: TextStyle(color: _step == 6 ? Colors.white : AC.navy, fontWeight: FontWeight.bold)))),
        ])),
      ]),
    );
  }

  Widget _buildProgressBar() {
    final percent = ((_step + 1) / 7 * 100).toInt();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('ط®ط·ظˆط© ' + (_step + 1).toString() + ' ظ…ظ† 7', style: const TextStyle(color: AC.ts, fontSize: 12)),
          Text(percent.toString() + '%', style: const TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: (_step + 1) / 7, minHeight: 6,
            backgroundColor: AC.navy3, valueColor: const AlwaysStoppedAnimation(AC.gold))),
        const SizedBox(height: 4),
        Text(_stepTitle(), style: const TextStyle(color: AC.tp, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  String _stepTitle() {
    const titles = ['ط¨ظٹط§ظ†ط§طھ ط§ظ„ظƒظٹط§ظ†', 'ط§ظ„ط´ظƒظ„ ط§ظ„ظ‚ط§ظ†ظˆظ†ظٹ', 'ط§ظ„ظ†ط´ط§ط· ط§ظ„ط±ط¦ظٹط³ظٹ', 'ط§ظ„ظ†ط´ط§ط· ط§ظ„ظپط±ط¹ظٹ', 'ظ†ظˆط¹ ط§ظ„ط¹ظ…ظٹظ„', 'ط§ظ„ظ…ط³طھظ†ط¯ط§طھ', 'ط§ظ„ظ…ط±ط§ط¬ط¹ط© ظˆط§ظ„طھظپط¹ظٹظ„'];
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
    _field('ط§ظ„ط§ط³ظ… ط§ظ„طھط¬ط§ط±ظٹ (ط¹ط±ط¨ظٹ) *', _nameArC, Icons.business),
    _field('ط§ظ„ط§ط³ظ… ط§ظ„طھط¬ط§ط±ظٹ (ط¥ظ†ط¬ظ„ظٹط²ظٹ)', _nameEnC, Icons.business),
    _field('ط§ظ„ط³ط¬ظ„ ط§ظ„طھط¬ط§ط±ظٹ', _crC, Icons.assignment),
    _field('ط§ظ„ط±ظ‚ظ… ط§ظ„ط¶ط±ظٹط¨ظٹ', _taxC, Icons.receipt),
    _field('ط§ظ„ط¹ظ†ظˆط§ظ† ط§ظ„ظˆط·ظ†ظٹ', _addressC, Icons.location_on),
    _field('ط§ظ„ظ…ط¯ظٹظ†ط©', _cityC, Icons.location_city),
  ]);

  Widget _field(String label, TextEditingController c, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(controller: c, style: const TextStyle(color: Colors.white), decoration: _inp(label, ic: icon)));

  Widget _stepLegalEntity() => Column(children: _entityTypes.map((e) =>
    _radioTile(e['code'], e['name_ar'], e['description_ar'] ?? '', _selectedEntityType,
      (v) => setState(() => _selectedEntityType = v))).toList());

  Widget _stepMainSector() => Column(children: _sectors.map((s) =>
    _radioTile(s['code'], s['name_ar'], '', _selectedSector,
      (v) { setState(() { _selectedSector = v; _selectedSubSector = null; _subSectors = []; });
        _loadSubSectors(v!).then((_) { if (mounted) setState(() {}); }); })).toList());

  Widget _stepSubSector() => _subSectors.isEmpty
    ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('ط§ط®طھط± ط§ظ„ظ†ط´ط§ط· ط§ظ„ط±ط¦ظٹط³ظٹ ط£ظˆظ„ط§ظ‹ ط£ظˆ ظ„ط§ طھظˆط¬ط¯ ط£ظ†ط´ط·ط© ظپط±ط¹ظٹط©', style: TextStyle(color: AC.ts))))
    : Column(children: _subSectors.map((s) {
        final hasLicense = s['requires_license'] == true;
        return _radioTile(s['code'], s['name_ar'], hasLicense ? 'ظٹطھط·ظ„ط¨ طھط±ط®ظٹطµ' : '', _selectedSubSector,
          (v) => setState(() => _selectedSubSector = v), badge: hasLicense ? 'ظ…ط±ط®طµ' : null);
      }).toList());

  Widget _stepClientType() {
    const types = [
      {'code': 'standard_business', 'label': 'ط´ط±ظƒط© طھط¬ط§ط±ظٹط© ط¹ط§ط¯ظٹط©', 'km': false},
      {'code': 'financial_entity', 'label': 'ط¬ظ‡ط© ظ…ط§ظ„ظٹط©', 'km': true},
      {'code': 'accounting_firm', 'label': 'ظ…ظƒطھط¨ ظ…ط­ط§ط³ط¨ط©', 'km': true},
      {'code': 'audit_firm', 'label': 'ظ…ظƒطھط¨ ظ…ط±ط§ط¬ط¹ط©', 'km': true},
      {'code': 'investment_entity', 'label': 'ط¬ظ‡ط© ط§ط³طھط«ظ…ط§ط±ظٹط©', 'km': true},
      {'code': 'government_entity', 'label': 'ط¬ظ‡ط© ط­ظƒظˆظ…ظٹط©', 'km': true},
      {'code': 'legal_regulatory_entity', 'label': 'ط¬ظ‡ط© ظ‚ط§ظ†ظˆظ†ظٹط©/طھظ†ط¸ظٹظ…ظٹط©', 'km': true},
    ];
    return Column(children: types.map((t) =>
      _radioTile(t['code'] as String, t['label'] as String, '', _clientType,
        (v) => setState(() => _clientType = v!),
        badge: (t['km'] as bool) ? 'ظ…ط¹ط±ظپظٹ' : null)).toList());
  }

  Widget _stepDocuments() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Icon(Icons.cloud_upload, size: 48, color: AC.gold),
    const SizedBox(height: 12),
    const Text('ط§ظ„ظ…ط³طھظ†ط¯ط§طھ ط§ظ„ظ…ط·ظ„ظˆط¨ط© ط³طھط¸ظ‡ط± ط¨ظ†ط§ط،ظ‹ ط¹ظ„ظ‰ ظ†ظˆط¹ ط§ظ„ظƒظٹط§ظ† ظˆط§ظ„ظ†ط´ط§ط·',
      textAlign: TextAlign.center, style: TextStyle(color: AC.ts, fontSize: 14)),
    const SizedBox(height: 12),
    Container(padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ط§ظ„ظ…ط³طھظ†ط¯ط§طھ ط§ظ„ط£ط³ط§ط³ظٹط©:', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _docRow('ط§ظ„ط³ط¬ظ„ ط§ظ„طھط¬ط§ط±ظٹ', _crC.text.isNotEmpty),
        _docRow('ط§ظ„ط±ظ‚ظ… ط§ظ„ط¶ط±ظٹط¨ظٹ', _taxC.text.isNotEmpty),
        _docRow('ط§ظ„ط¹ظ†ظˆط§ظ† ط§ظ„ظˆط·ظ†ظٹ', _addressC.text.isNotEmpty),
        if (_selectedEntityType != null && _selectedEntityType != 'individual')
          _docRow('ط¹ظ‚ط¯ ط§ظ„طھط£ط³ظٹط³', false),
      ])),
  ]);

  Widget _docRow(String name, bool done) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? AC.ok : AC.ts, size: 18),
      const SizedBox(width: 8),
      Text(name, style: TextStyle(color: done ? AC.tp : AC.ts, fontSize: 13)),
    ]));

  Widget _stepReview() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Icon(Icons.verified, size: 48, color: AC.ok),
    const SizedBox(height: 12),
    const Text('ظ…ط±ط§ط¬ط¹ط© ط§ظ„ط¨ظٹط§ظ†ط§طھ ظ‚ط¨ظ„ ط§ظ„ط¥ظ†ط´ط§ط،', textAlign: TextAlign.center,
      style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold)),
    const SizedBox(height: 16),
    _reviewRow('ط§ظ„ط§ط³ظ… ط§ظ„ط¹ط±ط¨ظٹ', _nameArC.text),
    _reviewRow('ط§ظ„ط§ط³ظ… ط§ظ„ط¥ظ†ط¬ظ„ظٹط²ظٹ', _nameEnC.text),
    _reviewRow('ط§ظ„ط³ط¬ظ„ ط§ظ„طھط¬ط§ط±ظٹ', _crC.text),
    _reviewRow('ط§ظ„ط±ظ‚ظ… ط§ظ„ط¶ط±ظٹط¨ظٹ', _taxC.text),
    _reviewRow('ط§ظ„ط´ظƒظ„ ط§ظ„ظ‚ط§ظ†ظˆظ†ظٹ', _selectedEntityType ?? 'â€”'),
    _reviewRow('ط§ظ„ظ†ط´ط§ط· ط§ظ„ط±ط¦ظٹط³ظٹ', _selectedSector ?? 'â€”'),
    _reviewRow('ط§ظ„ظ†ط´ط§ط· ط§ظ„ظپط±ط¹ظٹ', _selectedSubSector ?? 'â€”'),
    _reviewRow('ظ†ظˆط¹ ط§ظ„ط¹ظ…ظٹظ„', _clientType),
    _reviewRow('ط§ظ„ظ…ط¯ظٹظ†ط©', _cityC.text),
  ]);

  Widget _reviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AC.ts, fontSize: 13)),
      Flexible(child: Text(value.isEmpty ? 'â€”' : value,
        style: const TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.end)),
    ]));

  Widget _radioTile(String code, String label, String desc, String? selected, ValueChanged<String?> onChanged, {String? badge}) {
    final sel = selected == code;
    return GestureDetector(
      onTap: () => onChanged(code),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AC.gold.withOpacity(0.12) : AC.navy3,
          border: Border.all(color: sel ? AC.gold : Colors.white12, width: sel ? 1.5 : 1),
          borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? AC.gold : AC.ts, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(color: sel ? AC.gold : AC.tp, fontSize: 14, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
            if (desc.isNotEmpty) Text(desc, style: const TextStyle(color: AC.ts, fontSize: 11)),
          ])),
          if (badge != null) Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AC.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(badge, style: const TextStyle(color: AC.gold, fontSize: 10))),
        ])));
  }

  void _showStageNote(BuildContext ctx) {
    if (_stageNote == null) return;
    showModalBottomSheet(context: ctx, backgroundColor: AC.navy2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(padding: const EdgeInsets.all(20), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.help_outline, color: AC.gold),
            const SizedBox(width: 8),
            Expanded(child: Text(_stageNote!['title_ar'] ?? '', style: const TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold))),
          ]),
          const SizedBox(height: 12),
          Text(_stageNote!['body_ar'] ?? '', style: const TextStyle(color: AC.tp, fontSize: 13, height: 1.6)),
          if (_stageNote!['common_errors_ar'] != null) ...[
            const SizedBox(height: 12),
            const Text('ط£ط®ط·ط§ط، ط´ط§ط¦ط¹ط©:', style: TextStyle(color: AC.warn, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(_stageNote!['common_errors_ar'], style: const TextStyle(color: AC.warn, fontSize: 12)),
          ],
          if (_stageNote!['impact_ar'] != null) ...[
            const SizedBox(height: 12),
            const Text('ط£ط«ط± ط¹ط¯ظ… ط§ظ„ط¥ظƒظ…ط§ظ„:', style: TextStyle(color: AC.err, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(_stageNote!['impact_ar'], style: const TextStyle(color: AC.err, fontSize: 12)),
          ],
          const SizedBox(height: 20),
        ])));
  }
}

