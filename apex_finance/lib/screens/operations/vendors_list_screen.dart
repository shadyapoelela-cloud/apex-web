/// APEX — Vendors List (mirror of Customers List)
/// /purchase/vendors — uses ApexListShell with filters.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class VendorsListScreen extends StatefulWidget {
  const VendorsListScreen({super.key});
  @override
  State<VendorsListScreen> createState() => _VendorsListScreenState();
}

class _VendorsListScreenState extends State<VendorsListScreen> {
  List<Map<String, dynamic>> _all = [];
  String _filter = 'all';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tenantId = S.savedTenantId;
    if (tenantId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotListVendors(tenantId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _all = (res.data as List).cast<Map<String, dynamic>>();
      } else {
        _error = res.error;
      }
    });
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _all;
    final wanted = _filter == 'active';
    return _all.where((v) => (v['is_active'] == true) == wanted).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'الموردون',
      subtitle: '${_all.length} مورد',
      primaryCta: ApexCta(
        label: 'مورد جديد',
        icon: Icons.add,
        onPressed: () => context.go('/purchase'),
      ),
      filterChips: [
        ApexFilterChip(
            label: 'الكل',
            selected: _filter == 'all',
            onTap: () => setState(() => _filter = 'all'),
            count: _all.length),
        ApexFilterChip(
            label: 'نشط',
            selected: _filter == 'active',
            onTap: () => setState(() => _filter = 'active'),
            icon: Icons.check_circle_outline,
            count: _all.where((v) => v['is_active'] == true).length),
      ],
      items: _filtered,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('فواتير الموردين', '/purchase/bills', Icons.receipt_outlined),
        ApexChipLink('أعمار AP', '/purchase/aging', Icons.timeline),
        ApexChipLink('استقطاع المصدر WHT', '/compliance/wht-v2', Icons.percent),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'لا يوجد موردون بعد',
        description: 'ابدأ بإضافة أول مورد لتسجيل المشتريات',
        primaryLabel: 'إضافة مورد',
        primaryIcon: Icons.add,
        onPrimary: () => context.go('/purchase'),
      ),
      itemBuilder: (ctx, v) => InkWell(
        onTap: () => context.go('/operations/vendor-360/${v['id']}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AC.gold.withValues(alpha: 0.20),
              child: Icon(Icons.local_shipping, color: AC.gold, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${v['code'] ?? ''} — ${v['name_ar'] ?? '-'}',
                    style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${v['phone'] ?? v['email'] ?? ''}',
                    style: TextStyle(color: AC.ts, fontSize: 11)),
              ]),
            ),
            if (v['vat_number'] != null)
              Text('${v['vat_number']}',
                  style: TextStyle(color: AC.gold, fontSize: 10, fontFamily: 'monospace')),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left, color: AC.ts, size: 16),
          ]),
        ),
      ),
    );
  }
}
