import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

class ClientsTab extends ConsumerStatefulWidget { const ClientsTab({super.key}); @override ConsumerState<ClientsTab> createState()=>_ClientsS(); }
class _ClientsS extends ConsumerState<ClientsTab> {
  List _cl=[]; bool _ld=true; String _search='';
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _ld = true);
    try {
      final r = await ApiService.listClients();
      if (mounted) setState(() { final d = r.data; _cl = d is List ? d : []; _ld = false; });
    } catch(e) {
      if (mounted) setState(() { _cl = []; _ld = false; });
    }
  }
  final _cName = TextEditingController();
  final _cNameAr = TextEditingController();
  final _cEmail = TextEditingController();
  final _cPhone = TextEditingController();
  final _cCR = TextEditingController();
  final _cVAT = TextEditingController();
  final _cAddress = TextEditingController();
  String _cType = '';
  String _cSector = '';
  @override void dispose() {
    _cName.dispose(); _cNameAr.dispose(); _cEmail.dispose();
    _cPhone.dispose(); _cCR.dispose(); _cVAT.dispose(); _cAddress.dispose();
    super.dispose();
  }

  Future<void> _doCreateClient(BuildContext dc) async {
    Navigator.pop(dc);
    final code = 'CL${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final name = _cNameAr.text.isNotEmpty ? _cNameAr.text : (_cName.text.isNotEmpty ? _cName.text : 'New Client');
    final typeMap = {
      '\u0643\u064a\u0627\u0646 \u0633\u0639\u0648\u062f\u064a': 'standard_business',
      '\u0627\u0633\u062a\u062b\u0645\u0627\u0631 \u0623\u062c\u0646\u0628\u064a': 'investment_entity',
      '\u0641\u0631\u0639 \u0634\u0631\u0643\u0629 \u0623\u062c\u0646\u0628\u064a\u0629': 'financial_entity',
    };
    final type = typeMap[_cType] ?? 'standard_business';
    final res = await ApiService.createClient(clientCode: code, name: _cName.text.isNotEmpty ? _cName.text : name, nameAr: _cNameAr.text.isNotEmpty ? _cNameAr.text : name, clientType: type, industry: _cSector.isNotEmpty ? _cSector : null);
    if (res.success) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0639\u0645\u064a\u0644'), backgroundColor: AC.ok));
      _load();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.error ?? '\u062e\u0637\u0623'), backgroundColor: AC.err));
    }
    _cName.clear(); _cNameAr.clear(); _cEmail.clear(); _cPhone.clear(); _cCR.clear(); _cVAT.clear(); _cAddress.clear(); _cType = ''; _cSector = '';
  }


  Widget _wf(String label, TextEditingController ctrl, {bool ltr = false}) => Padding(
    padding: EdgeInsets.only(bottom: 10),
    child: TextField(controller: ctrl, textDirection: ltr ? TextDirection.ltr : null,
      style: TextStyle(color: AC.tp, fontSize: 13),
      decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        filled: true, fillColor: AC.navy3, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AC.gold)))),
  );

  Widget _wc(String label, List<String> opts, String sel, void Function(void Function()) ss, void Function(String) onSel) => Column(
    crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(label, style: TextStyle(color: AC.ts, fontSize: 12)),
      SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: opts.map((o) =>
        ChoiceChip(label: Text(o, style: TextStyle(color: sel == o ? AC.navy : AC.tp, fontSize: 11)),
          selected: sel == o, selectedColor: AC.gold, backgroundColor: AC.navy3,
          side: BorderSide(color: sel == o ? AC.gold : AC.bdr),
          onSelected: (s) { if (s) { onSel(o); ss(() {}); } },
        )).toList()),
    ],
  );

  Widget _buildWizardStep(int step, void Function(void Function()) ss) {
    switch (step) {
      case 0:
        // Step 1: Entity Origin
        return _wc('\u0646\u0648\u0639 \u0627\u0644\u0643\u064a\u0627\u0646', [
          '\u0643\u064a\u0627\u0646 \u0633\u0639\u0648\u062f\u064a',
          '\u0627\u0633\u062a\u062b\u0645\u0627\u0631 \u0623\u062c\u0646\u0628\u064a',
          '\u0641\u0631\u0639 \u0634\u0631\u0643\u0629 \u0623\u062c\u0646\u0628\u064a\u0629',
        ], _cType, ss, (v) { _cType = v; _cSector = ''; });
      case 1:
        // Step 2: Entity Type (based on MoC + SAGIA)
        final saudiTypes = [
          '\u0634\u0631\u0643\u0629 \u0645\u0633\u0627\u0647\u0645\u0629 \u0645\u063a\u0644\u0642\u0629',
          '\u0634\u0631\u0643\u0629 \u0645\u0633\u0627\u0647\u0645\u0629 \u0645\u0641\u062a\u0648\u062d\u0629',
          '\u0634\u0631\u0643\u0629 \u0630\u0627\u062a \u0645\u0633\u0624\u0648\u0644\u064a\u0629 \u0645\u062d\u062f\u0648\u062f\u0629',
          '\u0634\u0631\u0643\u0629 \u062a\u0636\u0627\u0645\u0646\u064a\u0629',
          '\u0634\u0631\u0643\u0629 \u062a\u0648\u0635\u064a\u0629 \u0628\u0633\u064a\u0637\u0629',
          '\u0645\u0624\u0633\u0633\u0629 \u0641\u0631\u062f\u064a\u0629',
          '\u0634\u0631\u0643\u0629 \u0645\u0647\u0646\u064a\u0629',
        ];
        final foreignTypes = [
          '\u0634\u0631\u0643\u0629 \u0630\u0627\u062a \u0645\u0633\u0624\u0648\u0644\u064a\u0629 \u0645\u062d\u062f\u0648\u062f\u0629 (\u0623\u062c\u0646\u0628\u064a)',
          '\u0641\u0631\u0639 \u0634\u0631\u0643\u0629 \u0623\u062c\u0646\u0628\u064a\u0629',
          '\u0645\u0643\u062a\u0628 \u062a\u0645\u062b\u064a\u0644\u064a',
          '\u0645\u0634\u0631\u0648\u0639 \u0645\u0634\u062a\u0631\u0643',
        ];
        final types = _cType.contains('\u0623\u062c\u0646\u0628') ? foreignTypes : saudiTypes;
        return _wc('\u0627\u0644\u0634\u0643\u0644 \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a', types, _cSector, ss, (v) => _cSector = v);
      case 2:
        // Step 3: Basic Info
        return Column(children: [
          _wf('\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629 (\u0639\u0631\u0628\u064a)', _cNameAr),
          _wf('\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629 (\u0625\u0646\u062c\u0644\u064a\u0632\u064a)', _cName, ltr: true),
          _wf('\u0631\u0642\u0645 \u0627\u0644\u0633\u062c\u0644 \u0627\u0644\u062a\u062c\u0627\u0631\u064a (CR)', _cCR, ltr: true),
          _wf('\u0631\u0642\u0645 \u0627\u0644\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u0636\u0631\u064a\u0628\u064a (VAT)', _cVAT, ltr: true),
        ]);
      case 3:
        // Step 4: Contact Info
        return Column(children: [
          _wf('\u0627\u0644\u0628\u0631\u064a\u062f \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a', _cEmail, ltr: true),
          _wf('\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641', _cPhone, ltr: true),
          _wf('\u0627\u0644\u0645\u062f\u064a\u0646\u0629', _cAddress),
        ]);
      case 4:
        // Step 5: Activity Sector (ISIC aligned)
        return _wc('\u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u0627\u0642\u062a\u0635\u0627\u062f\u064a (ISIC)', [
          '\u062a\u062c\u0627\u0631\u0629 \u062a\u062c\u0632\u0626\u0629',
          '\u062a\u062c\u0627\u0631\u0629 \u062c\u0645\u0644\u0629',
          '\u0645\u0642\u0627\u0648\u0644\u0627\u062a \u0648\u062a\u0634\u064a\u064a\u062f',
          '\u0635\u0646\u0627\u0639\u0629 \u0648\u062a\u062d\u0648\u064a\u0644',
          '\u062e\u062f\u0645\u0627\u062a \u0645\u0647\u0646\u064a\u0629',
          '\u062a\u0642\u0646\u064a\u0629 \u0645\u0639\u0644\u0648\u0645\u0627\u062a',
          '\u0639\u0642\u0627\u0631\u0627\u062a',
          '\u0646\u0642\u0644 \u0648\u0644\u0648\u062c\u0633\u062a\u064a\u0643',
          '\u0635\u062d\u0629 \u0648\u0631\u0639\u0627\u064a\u0629 \u0637\u0628\u064a\u0629',
          '\u062a\u0639\u0644\u064a\u0645 \u0648\u062a\u062f\u0631\u064a\u0628',
          '\u0633\u064a\u0627\u062d\u0629 \u0648\u0636\u064a\u0627\u0641\u0629',
          '\u0632\u0631\u0627\u0639\u0629 \u0648\u0623\u063a\u0630\u064a\u0629',
        ], _cSector.contains('\u0634\u0631\u0643\u0629') ? '' : _cSector, ss, (v) => _cSector = _cSector.contains('\u0634\u0631\u0643\u0629') ? _cSector : v);
      case 5:
        // Step 6: Documents
        return Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a \u0627\u0644\u0645\u0637\u0644\u0648\u0628\u0629', style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _docRow('\u0635\u0648\u0631\u0629 \u0627\u0644\u0633\u062c\u0644 \u0627\u0644\u062a\u062c\u0627\u0631\u064a', Icons.description),
            _docRow('\u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u0632\u0643\u0627\u0629 \u0648\u0627\u0644\u062f\u062e\u0644', Icons.receipt_long),
            _docRow('\u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u062a\u0623\u0645\u064a\u0646\u0627\u062a \u0627\u0644\u0627\u062c\u062a\u0645\u0627\u0639\u064a\u0629', Icons.security),
            _docRow('\u0634\u0647\u0627\u062f\u0629 \u0627\u0644\u0636\u0631\u064a\u0628\u0629 \u0627\u0644\u0645\u0636\u0627\u0641\u0629 (VAT)', Icons.paid),
            _docRow('\u0639\u0642\u062f \u0627\u0644\u062a\u0623\u0633\u064a\u0633 / \u0627\u0644\u0646\u0638\u0627\u0645 \u0627\u0644\u0623\u0633\u0627\u0633\u064a', Icons.gavel),
          ]),
        );
      case 6:
        // Step 7: Review
        return Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0628\u064a\u0627\u0646\u0627\u062a', style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _rv('\u0646\u0648\u0639 \u0627\u0644\u0643\u064a\u0627\u0646', _cType),
            _rv('\u0627\u0644\u0634\u0643\u0644 \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a', _cSector),
            _rv('\u0627\u0633\u0645 \u0627\u0644\u0645\u0646\u0634\u0623\u0629', _cNameAr.text),
            _rv('\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0625\u0646\u062c\u0644\u064a\u0632\u064a', _cName.text),
            _rv('\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0648\u0627\u0635\u0644', _cCR.text),
            _rv('\u0627\u0644\u0631\u0642\u0645 \u0627\u0644\u0636\u0631\u064a\u0628\u064a', _cVAT.text),
            _rv('\u0627\u0644\u0628\u0631\u064a\u062f', _cEmail.text),
            _rv('\u0627\u0644\u0647\u0627\u062a\u0641', _cPhone.text),
          ]));
      default: return const SizedBox();
    }
  }

  Widget _docRow(String label, IconData icon) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      OutlinedButton(style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr), padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
        onPressed: () {}, child: Text('\u0631\u0641\u0639', style: TextStyle(color: AC.gold, fontSize: 10))),
      SizedBox(width: 8),
      Expanded(child: Text(label, textAlign: TextAlign.right, style: TextStyle(color: AC.tp, fontSize: 12))),
      SizedBox(width: 8),
      Icon(icon, color: AC.gold, size: 18),
    ]),
  );

  Widget _rv(String l, String v) => Padding(padding: EdgeInsets.only(bottom: 6), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
    Text(v.isEmpty ? '-' : v, style: TextStyle(color: AC.tp, fontSize: 12)), SizedBox(width: 8), Text(l, style: TextStyle(color: AC.ts, fontSize: 11))]));

  void _showNewClientWizard(BuildContext ctx) {
    int _step = 0;
    final steps = [
      '\u0646\u0648\u0639 \u0627\u0644\u0643\u064a\u0627\u0646',
      '\u0627\u0644\u0634\u0643\u0644 \u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a',
      '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0645\u0646\u0634\u0623\u0629',
      '\u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u062a\u0648\u0627\u0635\u0644',
      '\u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u0627\u0642\u062a\u0635\u0627\u062f\u064a',
      '\u0631\u0641\u0639 \u0627\u0644\u0645\u0633\u062a\u0646\u062f\u0627\u062a',
      '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0648\u0627\u0644\u062a\u0623\u0643\u064a\u062f',
    ];
    showDialog(context: ctx, builder: (dc) => StatefulBuilder(builder: (bc, setSt) =>
      Dialog(backgroundColor: Colors.transparent, insetPadding: EdgeInsets.all(24),
        child: Container(
          constraints: BoxConstraints(maxWidth: 500, maxHeight: 550),
          decoration: BoxDecoration(color: AC.navy2.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(20), border: Border.all(color: AC.gold.withValues(alpha: 0.3))),
          padding: EdgeInsets.all(20),
          child: Column(children: [
            Row(children: [
              Text('\u062a\u0633\u062c\u064a\u0644 \u0639\u0645\u064a\u0644 \u062c\u062f\u064a\u062f', style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.bold)),
              Spacer(),
              ApexIconButton(icon: Icons.close, color: AC.ts, size: 20, tooltip: 'إغلاق', onPressed: () => Navigator.pop(dc)),
            ]),
            const SizedBox(height: 16),
            SizedBox(height: 50, child: Row(children: List.generate(7, (idx) =>
              Expanded(child: GestureDetector(
                onTap: () => setSt(() => _step = idx),
                child: Column(children: [
                  Container(width: 28, height: 28,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: idx <= _step ? AC.gold : AC.navy3,
                      border: Border.all(color: idx == _step ? AC.gold : AC.bdr)),
                    child: Center(child: idx < _step
                      ? Icon(Icons.check, color: AC.navy, size: 14)
                      : Text('${idx + 1}', style: TextStyle(color: idx == _step ? AC.navy : AC.ts, fontSize: 11, fontWeight: FontWeight.bold)))),
                  SizedBox(height: 4),
                  if (idx == _step) Text(steps[idx], style: TextStyle(color: AC.gold, fontSize: 7), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                ]),
              )),
            ))),
            Divider(color: AC.bdr),
            Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            _buildWizardStep(_step, setSt),
              SizedBox(height: 12),
              Text(steps[_step], style: TextStyle(color: AC.tp, fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('\u0627\u0644\u062e\u0637\u0648\u0629 ${_step + 1} \u0645\u0646 7', style: TextStyle(color: AC.ts, fontSize: 12)),
            ]))),
            Row(children: [
              if (_step > 0) Expanded(child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: BorderSide(color: AC.bdr), padding: EdgeInsets.symmetric(vertical: 12)),
                onPressed: () => setSt(() => _step--),
                child: Text('\u0627\u0644\u0633\u0627\u0628\u0642', style: TextStyle(color: AC.ts)))),
              if (_step > 0) SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AC.gold, padding: EdgeInsets.symmetric(vertical: 12)),
                onPressed: () { if (_step < 6) { setSt(() => _step++); } else { _doCreateClient(dc); } },
                child: Text(_step < 6 ? '\u0627\u0644\u062a\u0627\u0644\u064a' : '\u062a\u0623\u0643\u064a\u062f', style: TextStyle(color: AC.navy, fontWeight: FontWeight.bold)))),
            ]),
          ]),
        ),
      ),
    ));
  }
  @override Widget build(BuildContext c) {
    final filtered = _search.isEmpty ? _cl : _cl.where((c2) {
      final name = (c2['name_ar'] ?? c2['name'] ?? '').toString().toLowerCase();
      final type = (c2['client_type'] ?? '').toString().toLowerCase();
      return name.contains(_search.toLowerCase()) || type.contains(_search.toLowerCase());
    }).toList();
    return Scaffold(
      backgroundColor: AC.navy,
      floatingActionButton: ApexGlowFAB(icon: Icons.add, color: AC.gold,
        onPressed: () => _showNewClientWizard(c), tooltip: 'شركة جديدة'),
      body: Column(children: [
        // Header with title + search
        Container(padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('الشركات', style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              Text('${_cl.length} عميل', style: TextStyle(color: AC.ts, fontSize: 12)),
            ]),
            SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(color: AC.tp, fontSize: 13),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'بحث عن عميل...',
                hintStyle: TextStyle(color: AC.ts, fontSize: 12),
                prefixIcon: Icon(Icons.search, color: AC.ts, size: 20),
                filled: true, fillColor: AC.navy3, isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AC.gold)),
              ),
            ),
          ]),
        ),
        // Client list
        Expanded(child: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
          filtered.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.business_outlined, color: AC.ts, size: 60), SizedBox(height: 12),
            Text(_cl.isEmpty ? 'لا يوجد عملاء بعد' : 'لا نتائج', style: TextStyle(color: AC.ts, fontSize: 14)),
          ])) :
          RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), itemCount: filtered.length, itemBuilder: (_, i) {
              final c2 = filtered[i];
              final name = c2['name_ar'] ?? c2['name'] ?? '';
              final type = c2['client_type'] ?? '';
              final role = c2['your_role'] ?? '';
              return InkWell(
                onTap: () => context.push('/client-detail', extra: {'id': (c2['id'] ?? '').toString(), 'name': name}),
                child: Container(margin: EdgeInsets.only(bottom: 10), padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AC.bdr)),
                  child: Row(children: [
                    CircleAvatar(backgroundColor: AC.gold.withValues(alpha: 0.15), radius: 24,
                      child: Text(name.isNotEmpty ? name[0] : '?', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 16))),
                    SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: AC.tp, fontSize: 15)),
                      SizedBox(height: 4),
                      Row(children: [
                        if (type.isNotEmpty) Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(type, style: TextStyle(color: AC.gold, fontSize: 10))),
                        if (type.isNotEmpty && role.isNotEmpty) SizedBox(width: 8),
                        if (role.isNotEmpty) Text(role, style: TextStyle(color: AC.ts, fontSize: 11)),
                      ]),
                    ])),
                    Icon(Icons.chevron_left, color: AC.ts, size: 20),
                  ])));
            }))),
      ]),
    );
  }
}
