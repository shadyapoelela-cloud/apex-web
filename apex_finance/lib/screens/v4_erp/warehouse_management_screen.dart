/// Warehouse Management — شاشة المستودعات الحيّة.
///
/// ذاتية الاكتفاء. تقرأ PilotSession.entityId ثم تعرض كل المستودعات
/// لجميع فروع هذا الكيان، مع stock levels لكل واحد.

library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../pilot/api/pilot_client.dart';
import '../../pilot/session.dart';

Color get _gold => core_theme.AC.gold;
Color get _navy => core_theme.AC.navy;
Color get _navy2 => core_theme.AC.navy2;
Color get _navy3 => core_theme.AC.navy3;
Color get _bdr => core_theme.AC.bdr;
final _tp = Color(0xFFFFFFFF);
Color get _ts => core_theme.AC.ts;
Color get _td => core_theme.AC.td;
Color get _ok => core_theme.AC.ok;
Color get _err => core_theme.AC.err;

class WarehouseManagementScreen extends StatefulWidget {
  const WarehouseManagementScreen({super.key});
  @override
  State<WarehouseManagementScreen> createState() =>
      _WarehouseManagementScreenState();
}

class _WarehouseManagementScreenState extends State<WarehouseManagementScreen> {
  final PilotClient _client = pilotClient;

  List<Map<String, dynamic>> _branches = [];
  final Map<String, List<Map<String, dynamic>>> _warehousesByBranch = {};
  final Map<String, List<Map<String, dynamic>>> _stockByWarehouse = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!PilotSession.hasEntity) {
      setState(() {
        _loading = false;
        _error = 'لم يتم تحديد الكيان. اذهب لإعدادات الشركة أولاً.';
      });
      return;
    }
    try {
      final bR = await _client.listBranches(PilotSession.entityId!);
      if (!bR.success) throw 'فشل تحميل الفروع';
      _branches = List<Map<String, dynamic>>.from(bR.data);

      for (final b in _branches) {
        final wR = await _client.listWarehouses(b['id']);
        final whs =
            wR.success ? List<Map<String, dynamic>>.from(wR.data) : <Map<String, dynamic>>[];
        _warehousesByBranch[b['id']] = whs;
        for (final w in whs) {
          final sR = await _client.getWarehouseStock(w['id']);
          _stockByWarehouse[w['id']] = sR.success
              ? List<Map<String, dynamic>>.from(sR.data)
              : <Map<String, dynamic>>[];
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
            ? Center(child: CircularProgressIndicator(color: _gold))
            : _error != null
                ? _errorState()
                : _content(),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning, color: _err, size: 56),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _tp, fontSize: 15)),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _gold),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text('إعادة المحاولة'),
            ),
          ]),
        ),
      );

  Widget _content() => RefreshIndicator(
        color: _gold,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(),
            const SizedBox(height: 16),
            ..._branches.map(_branchCard),
            const SizedBox(height: 80),
          ],
        ),
      );

  Widget _header() {
    final totalWh = _warehousesByBranch.values.fold<int>(0, (s, l) => s + l.length);
    final totalSkus = _stockByWarehouse.values.fold<int>(
        0, (s, l) => s + l.length);
    final totalStock = _stockByWarehouse.values
        .expand((l) => l)
        .fold<double>(0,
            (s, r) => s + (double.tryParse('${r['on_hand']}') ?? 0));
    return Row(children: [
      _kpi('الفروع', '${_branches.length}', Icons.store),
      const SizedBox(width: 10),
      _kpi('المستودعات', '$totalWh', Icons.warehouse),
      const SizedBox(width: 10),
      _kpi('أصناف مختزنة', '$totalSkus', Icons.inventory_2),
      const SizedBox(width: 10),
      _kpi('الكمية الإجمالية', totalStock.toStringAsFixed(0), Icons.layers),
    ]);
  }

  Widget _kpi(String label, String val, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _navy2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _bdr),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: _gold, size: 18),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(color: _ts, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              Text(val,
                  style: TextStyle(
                      color: _gold, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );

  Widget _branchCard(Map<String, dynamic> b) {
    final warehouses = _warehousesByBranch[b['id']] ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.store, color: _gold),
          const SizedBox(width: 8),
          Text('${b['code']} — ${b['name_ar'] ?? ''}',
              style: TextStyle(
                  color: _tp, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 8),
          if (b['city'] != null)
            Text('(${b['city']})', style: TextStyle(color: _td, fontSize: 12)),
          const Spacer(),
          TextButton.icon(
            icon: Icon(Icons.add, color: _gold, size: 18),
            label: Text('مستودع', style: TextStyle(color: _gold)),
            onPressed: () => _addWarehouse(b['id']),
          ),
        ]),
        const SizedBox(height: 8),
        if (warehouses.isEmpty)
          Padding(
            padding: EdgeInsets.all(8),
            child: Text('لا توجد مستودعات في هذا الفرع',
                style: TextStyle(color: _td, fontSize: 13)),
          )
        else
          ...warehouses.map((w) => _warehouseTile(w)),
      ]),
    );
  }

  Widget _warehouseTile(Map<String, dynamic> w) {
    final stock = _stockByWarehouse[w['id']] ?? [];
    final total = stock.fold<double>(
        0, (s, r) => s + (double.tryParse('${r['on_hand']}') ?? 0));
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        Icon(Icons.warehouse, color: _gold, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(w['name_ar'] ?? w['code'],
                    style: TextStyle(
                        color: _tp,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(width: 8),
                if (w['is_default'] == true)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('افتراضي',
                        style: TextStyle(color: _gold, fontSize: 10)),
                  ),
              ]),
              Text('${w['code']} • ${w['type']}',
                  style: TextStyle(color: _td, fontSize: 11)),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${stock.length} صنف',
                style: TextStyle(color: _ts, fontSize: 12)),
            Text(total.toStringAsFixed(0),
                style: TextStyle(
                    color: _gold, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: (w['status'] == 'active' ? _ok : core_theme.AC.td)
                .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(w['status'] ?? '',
              style: TextStyle(
                  color: w['status'] == 'active' ? _ok : core_theme.AC.td,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Future<void> _addWarehouse(String branchId) async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    try {
      String type = 'main';
      bool isDefault = false;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setS) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text('مستودع جديد'),
              content: SizedBox(
                width: 400,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                    controller: codeCtrl,
                    decoration: const InputDecoration(labelText: 'الكود *'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'الاسم *'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'النوع'),
                    items: const [
                      DropdownMenuItem(value: 'main', child: Text('رئيسي')),
                      DropdownMenuItem(
                          value: 'stockroom', child: Text('مخزن خلفي')),
                      DropdownMenuItem(
                          value: 'central_dc', child: Text('مركز توزيع')),
                      DropdownMenuItem(
                          value: 'returns', child: Text('مرتجعات')),
                    ],
                    onChanged: (v) => setS(() => type = v!),
                  ),
                  CheckboxListTile(
                    value: isDefault,
                    title: Text('افتراضي'),
                    onChanged: (v) => setS(() => isDefault = v ?? false),
                  ),
                ]),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('إلغاء')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _gold),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('إنشاء'),
                ),
              ],
            ),
          ),
        ),
      );
      if (ok == true) {
        final r = await _client.createWarehouse(branchId, {
          'code': codeCtrl.text.trim(),
          'name_ar': nameCtrl.text.trim(),
          'type': type,
          'is_default': isDefault,
          'is_sellable_from': true,
          'is_receivable_to': true,
        });
        if (r.success) {
          await _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('تم إنشاء المستودع'),
                  backgroundColor: _ok),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(r.error ?? 'فشل'), backgroundColor: _err),
            );
          }
        }
      }
    } finally {
      codeCtrl.dispose();
      nameCtrl.dispose();
    }
  }
}
