import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/shared_constants.dart';

// ── 1. Client List Screen ──
class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});
  @override State<ClientListScreen> createState() => _ClientListS();
}
class _ClientListS extends State<ClientListScreen> {
  List<dynamic> _clients = [];
  bool _ld = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiService.listClients();
      if (res.success) {
        final d = res.data;
        setState(() {
          _clients = d is List ? d : (d['clients'] ?? []);
          _ld = false;
        });
      } else { setState(() => _ld = false); }
    } catch (_) { setState(() => _ld = false); }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    backgroundColor: AC.navy,
    appBar: AppBar(title: Text('العملاء', style: TextStyle(color: AC.gold)),
      actions: [IconButton(icon: Icon(Icons.add_circle, color: AC.gold),
        onPressed: () async {
          final created = await context.push('/clients/create');
          if (created == true) _load();
        })]),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold))
      : _clients.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.business, size: 64, color: AC.ts),
            const SizedBox(height: 16),
            Text('لا يوجد عملاء بعد', style: TextStyle(color: AC.ts, fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إنشاء عميل جديد'),
              onPressed: () async {
                final created = await context.push('/clients/create');
                if (created == true) _load();
              }),
          ]))
        : RefreshIndicator(onRefresh: _load, color: AC.gold,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _clients.length,
            itemBuilder: (_, i) {
              final cl = _clients[i];
              final km = cl['knowledge_mode'] == true;
              return InkWell(
              onTap: () => context.push('/client-detail', extra: {'id': cl['id'], 'name': cl['name_ar'] ?? cl['name'] ?? ''}),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AC.navy3,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(children: [
                  CircleAvatar(backgroundColor: AC.gold.withValues(alpha: 0.2),
                    child: Text((cl['name_ar'] ?? cl['name'] ?? '?')[0], style: TextStyle(color: AC.gold))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cl['name_ar'] ?? cl['name'] ?? '', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${cl['client_type_code'] ?? cl['client_type'] ?? ''} • ${cl['role'] ?? 'owner'}',
                      style: TextStyle(color: AC.ts, fontSize: 12)),
                  ])),
                  Icon(Icons.chevron_right, color: AC.ts),
                ]),
              ),
            );            },
          )),
  );
}

// ── 2. Client Create Screen ──
class ClientCreateScreen extends StatefulWidget {
  const ClientCreateScreen({super.key});
  @override
  State<ClientCreateScreen> createState() => _ClientCreateS();
}

class _ClientCreateS extends State<ClientCreateScreen> {
  final _nameC = TextEditingController();
  String? _selectedType;
  bool _ld = false;
  String? _err;

  Future<void> _create() async {
    if (_nameC.text.trim().isEmpty || _selectedType == null) {
      setState(() => _err = 'ادخل اسم العميل واختر النوع');
      return;
    }
    setState(() { _ld = true; _err = null; });
    try {
      final res = await ApiService.createClient(
        clientCode: _nameC.text.trim().replaceAll(' ', '_'),
        name: _nameC.text.trim(),
        clientType: _selectedType!,
        nameAr: _nameC.text.trim(),
      );
      if (res.success) {
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() { _err = res.error ?? 'فشل'; _ld = false; });
      }
    } catch (e) { setState(() { _err = e.toString(); _ld = false; }); }
  }

  @override
  void dispose() { _nameC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(title: Text('عميل جديد', style: TextStyle(color: AC.gold)), backgroundColor: AC.navy),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              height: 56,
              child: TextField(
                controller: _nameC,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'اسم الشركة *',
                  labelStyle: const TextStyle(color: Colors.white54),
                  prefixIcon: Icon(Icons.business, color: AC.gold),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.gold), borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_err!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.category, color: AC.gold, size: 20),
                const SizedBox(width: 8),
                Text('نوع العميل *', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _typeCard('standard_business', 'شركة تجارية عادية', Icons.business, false),
                _typeCard('financial_entity', 'جهة مالية', Icons.account_balance, true),
                _typeCard('financing_entity', 'جهة تمويلية', Icons.monetization_on, true),
                _typeCard('accounting_firm', 'مكتب محاسبة', Icons.calculate, true),
                _typeCard('audit_firm', 'مكتب مراجعة', Icons.verified_user, true),
                _typeCard('investment_entity', 'جهة استثمارية', Icons.trending_up, true),
                _typeCard('sector_consulting_entity', 'جهة استشارية', Icons.lightbulb, true),
                _typeCard('government_entity', 'جهة حكومية', Icons.account_balance_wallet, true),
                _typeCard('legal_regulatory_entity', 'جهة قانونية أو تنظيمية', Icons.gavel, true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _ld ? null : _create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AC.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _ld
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('انشاء العميل', style: TextStyle(color: AC.navy, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeCard(String code, String label, IconData icon, bool isKm) {
    final sel = _selectedType == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = code),
      child: Container(
        height: 52,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: sel ? AC.gold.withValues(alpha: 0.15) : AC.navy3,
          border: Border.all(color: sel ? AC.gold : Colors.white12, width: sel ? 1.5 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? AC.gold : AC.ts, size: 20),
            const SizedBox(width: 12),
            Icon(icon, color: sel ? AC.gold : AC.ts, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(
                color: sel ? AC.gold : AC.tp,
                fontSize: 14,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              )),
            ),
            if (isKm)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('معرفي', style: TextStyle(color: AC.gold, fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }
}












// ── 3. COA Upload Screen ──
