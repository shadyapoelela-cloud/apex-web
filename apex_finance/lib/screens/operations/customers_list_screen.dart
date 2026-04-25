/// APEX — Customers List
/// ═══════════════════════════════════════════════════════════════════════
/// First standalone list using ApexListShell. Per blueprint §1:
///   /sales/customers — list with filter chips + create + drill to 360
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});
  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  List<Map<String, dynamic>> _all = [];
  String _filter = 'all'; // all | active | inactive
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tenantId = S.savedTenantId;
    if (tenantId == null) {
      setState(() => _error = 'لا يوجد كيان نشط');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotListCustomers(tenantId);
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
    final activeWanted = _filter == 'active';
    return _all.where((c) => (c['is_active'] == true) == activeWanted).toList();
  }

  int _countWhere(bool active) => _all.where((c) => c['is_active'] == active).length;

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'العملاء',
      subtitle: '${_all.length} عميل',
      primaryCta: ApexCta(
        label: 'عميل جديد',
        icon: Icons.add,
        onPressed: () => context.go('/sales'),
      ),
      filterChips: [
        ApexFilterChip(
          label: 'الكل',
          selected: _filter == 'all',
          onTap: () => setState(() => _filter = 'all'),
          count: _all.length,
        ),
        ApexFilterChip(
          label: 'نشط',
          selected: _filter == 'active',
          onTap: () => setState(() => _filter = 'active'),
          icon: Icons.check_circle_outline,
          count: _countWhere(true),
        ),
        ApexFilterChip(
          label: 'غير نشط',
          selected: _filter == 'inactive',
          onTap: () => setState(() => _filter = 'inactive'),
          icon: Icons.block,
          count: _countWhere(false),
        ),
      ],
      items: _filtered,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('الفواتير', '/sales/invoices', Icons.receipt),
        ApexChipLink('عروض الأسعار', '/sales/quotes', Icons.description),
        ApexChipLink('أعمار AR', '/sales/aging', Icons.timeline),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.people_outline,
        title: 'لا يوجد عملاء بعد',
        description: 'ابدأ بإضافة أول عميل لك أو حمّل بيانات تجريبية من Today',
        primaryLabel: 'إضافة عميل',
        primaryIcon: Icons.add,
        onPrimary: () => context.go('/sales'),
      ),
      itemBuilder: (ctx, c) => InkWell(
        onTap: () => context.go('/operations/customer-360/${c['id']}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AC.gold.withValues(alpha: 0.20),
              child: Icon(Icons.business, color: AC.gold, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${c['code'] ?? ''} — ${c['name_ar'] ?? '-'}',
                    style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${c['phone'] ?? c['email'] ?? ''}',
                    style: TextStyle(color: AC.ts, fontSize: 11)),
              ]),
            ),
            if (c['vat_number'] != null)
              Text('${c['vat_number']}',
                  style: TextStyle(color: AC.gold, fontSize: 10, fontFamily: 'monospace')),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left, color: AC.ts, size: 16),
          ]),
        ),
      ),
    );
  }
}
