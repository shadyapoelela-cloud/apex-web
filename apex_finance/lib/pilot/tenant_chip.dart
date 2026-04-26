/// Tenant Chip — مؤشر بسيط يعرض المستأجر الحالي في شريط العنوان.
///
/// يقرأ من PilotSession مباشرة. النقر يفتح حوار اختيار/تبديل.
/// لا ChangeNotifier — كل شاشة تقرأ القيم عند البناء.

library;

import 'package:flutter/material.dart';
import '../core/theme.dart' as core_theme;

import 'api/pilot_client.dart';
import 'session.dart';
import 'tenant_tree_picker.dart';

class TenantChip extends StatefulWidget {
  const TenantChip({super.key});
  @override
  State<TenantChip> createState() => _TenantChipState();
}

class _TenantChipState extends State<TenantChip> {
  String? _tenantName;
  String? _entityCode;
  String? _branchCode;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    if (!PilotSession.hasTenant) {
      if (mounted) setState(() {});
      return;
    }
    final t = await pilotClient.getTenant(PilotSession.tenantId!);
    if (t.success) {
      _tenantName = (t.data as Map)['legal_name_ar'];
    }
    if (PilotSession.hasEntity) {
      final e = await pilotClient.getEntity(PilotSession.entityId!);
      if (e.success) _entityCode = (e.data as Map)['code'];
    }
    if (PilotSession.hasBranch) {
      final b = await pilotClient.getBranch(PilotSession.branchId!);
      if (b.success) _branchCode = (b.data as Map)['code'];
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bound = PilotSession.hasTenant;
    final label = bound
        ? [
            _tenantName ?? 'مستأجر',
            if (_entityCode != null) _entityCode!,
            if (_branchCode != null) _branchCode!,
          ].join(' / ')
        : 'اختيار الشركة';
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _open(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bound
              ? core_theme.AC.gold.withValues(alpha: 0.12)
              : core_theme.AC.tp.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: bound
                ? core_theme.AC.gold.withValues(alpha: 0.4)
                : core_theme.AC.tp.withValues(alpha: 0.12),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            bound ? Icons.cloud_done : Icons.cloud_off,
            size: 14,
            color: bound ? core_theme.AC.ok : core_theme.AC.ts,
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: bound ? core_theme.AC.tp : core_theme.AC.ts,
              )),
          const SizedBox(width: 3),
          Icon(Icons.arrow_drop_down,
              size: 16,
              color: bound ? core_theme.AC.tp : core_theme.AC.ts),
        ]),
      ),
    );
  }

  Future<void> _open(BuildContext ctx) async {
    await showTenantTreePicker(
      ctx,
      onChanged: () {
        _tenantName = null;
        _entityCode = null;
        _branchCode = null;
        _loadNames();
      },
    );
  }
}

// Old _PickerDialog removed — replaced by tenant_tree_picker.dart
// (search-first hierarchical tree based on Sage Intacct + Odoo synthesis).
