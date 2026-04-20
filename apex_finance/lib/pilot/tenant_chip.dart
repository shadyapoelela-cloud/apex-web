/// Tenant Chip — مؤشر بسيط يعرض المستأجر الحالي في شريط العنوان.
///
/// يقرأ من PilotSession مباشرة. النقر يفتح حوار اختيار/تبديل.
/// لا ChangeNotifier — كل شاشة تقرأ القيم عند البناء.

library;

import 'package:flutter/material.dart';

import 'api/pilot_client.dart';
import 'session.dart';

class TenantChip extends StatefulWidget {
  const TenantChip({super.key});
  @override
  State<TenantChip> createState() => _TenantChipState();
}

class _TenantChipState extends State<TenantChip> {
  String? _tenantName;
  String? _entityCode;
  String? _branchCode;
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  Future<void> _loadNames() async {
    if (!PilotSession.hasTenant) {
      if (mounted) setState(() => _loadedOnce = true);
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
    if (mounted) setState(() => _loadedOnce = true);
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
              ? const Color(0xFFD4AF37).withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: bound
                ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.12),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            bound ? Icons.cloud_done : Icons.cloud_off,
            size: 14,
            color: bound ? const Color(0xFF059669) : Colors.black54,
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: bound ? Colors.black87 : Colors.black54,
              )),
          const SizedBox(width: 3),
          Icon(Icons.arrow_drop_down,
              size: 16,
              color: bound ? Colors.black87 : Colors.black54),
        ]),
      ),
    );
  }

  Future<void> _open(BuildContext ctx) async {
    await showDialog(
      context: ctx,
      builder: (_) => _PickerDialog(onChanged: () {
        _loadedOnce = false;
        _tenantName = null;
        _entityCode = null;
        _branchCode = null;
        _loadNames();
      }),
    );
  }
}

class _PickerDialog extends StatefulWidget {
  final VoidCallback onChanged;
  const _PickerDialog({required this.onChanged});
  @override
  State<_PickerDialog> createState() => _PickerDialogState();
}

class _PickerDialogState extends State<_PickerDialog> {
  final _tidCtrl = TextEditingController(text: PilotSession.tenantId ?? '');
  List<Map<String, dynamic>> _entities = [];
  List<Map<String, dynamic>> _branches = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (PilotSession.hasTenant) _loadEntities();
    if (PilotSession.hasEntity) _loadBranches();
  }

  Future<void> _bindTenant() async {
    final id = _tidCtrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _loading = true);
    final r = await pilotClient.getTenant(id);
    if (r.success) {
      PilotSession.tenantId = id;
      PilotSession.clearEntityAndBranch();
      await _loadEntities();
      widget.onChanged();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red,
            content: Text(r.error ?? 'فشل تحميل المستأجر')));
      }
    }
    setState(() => _loading = false);
  }

  Future<void> _loadEntities() async {
    final r = await pilotClient.listEntities(PilotSession.tenantId!);
    if (r.success) {
      setState(() => _entities = List<Map<String, dynamic>>.from(r.data));
    }
  }

  Future<void> _loadBranches() async {
    if (!PilotSession.hasEntity) return;
    final r = await pilotClient.listBranches(PilotSession.entityId!);
    if (r.success) {
      setState(() => _branches = List<Map<String, dynamic>>.from(r.data));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Row(children: const [
          Icon(Icons.link, color: Color(0xFFD4AF37)),
          SizedBox(width: 8),
          Text('اختيار الشركة'),
        ]),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tenant ID:',
                  style: TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _tidCtrl,
                    decoration: InputDecoration(
                      hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black),
                  onPressed: _loading ? null : _bindTenant,
                  child: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('تحميل'),
                ),
              ]),
              if (_entities.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('الكيان:',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _entities.map((e) {
                    final sel = PilotSession.entityId == e['id'];
                    return ChoiceChip(
                      label: Text(
                          '${e['code']} — ${e['name_ar'] ?? ''} (${e['functional_currency']})'),
                      selected: sel,
                      onSelected: (_) {
                        PilotSession.entityId = e['id'];
                        PilotSession.clearBranch();
                        _loadBranches();
                        widget.onChanged();
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
              if (_branches.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('الفرع:',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _branches.map((b) {
                    final sel = PilotSession.branchId == b['id'];
                    return ChoiceChip(
                      label: Text('${b['code']} — ${b['city'] ?? ''}'),
                      selected: sel,
                      onSelected: (_) {
                        PilotSession.branchId = b['id'];
                        widget.onChanged();
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (PilotSession.hasTenant)
            TextButton(
              onPressed: () {
                PilotSession.clear();
                widget.onChanged();
                Navigator.pop(context);
              },
              child: const Text('مسح', style: TextStyle(color: Colors.red)),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(context),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }
}
