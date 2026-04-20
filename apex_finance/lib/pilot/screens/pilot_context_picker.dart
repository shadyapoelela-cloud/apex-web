/// Pilot Context Picker — اختيار tenant + entity + branch
/// ═════════════════════════════════════════════════════════════
/// حوار مُبسّط يسمح بإدخال tenant slug (أو ID) واختيار entity/branch.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/pilot_session_provider.dart';
import '../providers/pilot_data_providers.dart';

class PilotContextPicker extends ConsumerStatefulWidget {
  const PilotContextPicker({super.key});
  @override
  ConsumerState<PilotContextPicker> createState() => _PilotContextPickerState();
}

class _PilotContextPickerState extends ConsumerState<PilotContextPicker> {
  final _tenantCtrl = TextEditingController();
  bool _loadingTenant = false;
  String? _error;

  @override
  void dispose() {
    _tenantCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveTenant() async {
    final txt = _tenantCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _loadingTenant = true;
      _error = null;
    });
    // اعتبر النص هو ID إذا كان UUID-style، وإلا حاول كـ slug
    final client = ref.read(pilotClientProvider);
    // PilotClient.getTenant يتوقع ID — لكننا نسمح بالـ slug عبر listTenants
    // (يتطلب admin secret — في الإنتاج نستخدم API بديلة أو /auth/me)
    // للتبسيط هنا: نفترض أن المستخدم يُدخل tenant ID.
    final r = await client.getTenant(txt);
    setState(() => _loadingTenant = false);
    if (r.success && r.data is Map) {
      final t = r.data as Map;
      ref.read(pilotSessionProvider.notifier).selectTenant(
            id: t['id'],
            slug: t['slug'],
            nameAr: t['legal_name_ar'],
          );
    } else {
      setState(() => _error = r.error ?? 'لم يتم العثور على المستأجر');
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(pilotSessionProvider);
    return Container(
      padding: const EdgeInsets.all(24),
      constraints: const BoxConstraints(maxWidth: 600),
      color: AC.navy2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('اختيار السياق',
              style: TextStyle(
                  color: AC.tp, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // ── Tenant ──
          if (!selection.hasTenant) ...[
            Text('1) المستأجر (Tenant):', style: TextStyle(color: AC.ts)),
            const SizedBox(height: 8),
            TextField(
              controller: _tenantCtrl,
              style: TextStyle(color: AC.tp),
              decoration: InputDecoration(
                hintText: 'Tenant ID (UUID)',
                hintStyle: TextStyle(color: AC.td),
                filled: true,
                fillColor: AC.navy3,
                border: OutlineInputBorder(
                    borderSide: BorderSide(color: AC.bdr)),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AC.bdr)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AC.gold)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: AC.err)),
            ],
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
              onPressed: _loadingTenant ? null : _resolveTenant,
              child: _loadingTenant
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تحميل المستأجر'),
            ),
          ] else ...[
            _row('المستأجر', selection.tenantNameAr ?? selection.tenantSlug ?? selection.tenantId!),
            const SizedBox(height: 12),
            Text('2) الكيان (Entity):', style: TextStyle(color: AC.ts)),
            const SizedBox(height: 8),
            _entitiesList(selection.tenantId!),
          ],

          // ── Entity / Branch ──
          if (selection.hasEntity) ...[
            const SizedBox(height: 16),
            _row('الكيان الحالي', '${selection.entityCode} — ${selection.entityNameAr ?? ""} (${selection.functionalCurrency})'),
            const SizedBox(height: 12),
            Text('3) الفرع (Branch):', style: TextStyle(color: AC.ts)),
            const SizedBox(height: 8),
            _branchesList(selection.entityId!),
          ],

          if (selection.hasBranch) ...[
            const SizedBox(height: 16),
            _row('الفرع الحالي', '${selection.branchCode} — ${selection.branchNameAr ?? ""}'),
          ],

          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  ref.read(pilotSessionProvider.notifier).clear();
                  setState(() {
                    _tenantCtrl.clear();
                    _error = null;
                  });
                },
                child: Text('إعادة التعيين', style: TextStyle(color: AC.err)),
              ),
            ),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AC.gold, foregroundColor: AC.btnFg),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('تم'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 100, child: Text(k, style: TextStyle(color: AC.ts))),
          Expanded(
              child: Text(v, style: TextStyle(color: AC.tp, fontWeight: FontWeight.w500))),
        ]),
      );

  Widget _entitiesList(String tid) {
    final entities = ref.watch(entitiesProvider(tid));
    return entities.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('خطأ: $e', style: TextStyle(color: AC.err)),
      data: (list) {
        if (list.isEmpty) {
          return Text('لا توجد كيانات. أنشئ كياناً أولاً.',
              style: TextStyle(color: AC.td));
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((e) {
            final m = e as Map;
            return ActionChip(
              backgroundColor: AC.navy3,
              label: Text('${m['code']} — ${m['name_ar'] ?? ""}',
                  style: TextStyle(color: AC.tp)),
              onPressed: () {
                ref.read(pilotSessionProvider.notifier).selectEntity(
                      id: m['id'],
                      code: m['code'],
                      nameAr: m['name_ar'],
                      country: m['country'],
                      functionalCurrency: m['functional_currency'],
                    );
              },
            );
          }).toList(),
        );
      },
    );
  }

  Widget _branchesList(String eid) {
    final branches = ref.watch(branchesProvider(eid));
    return branches.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('خطأ: $e', style: TextStyle(color: AC.err)),
      data: (list) {
        if (list.isEmpty) {
          return Text('لا توجد فروع لهذا الكيان.',
              style: TextStyle(color: AC.td));
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((b) {
            final m = b as Map;
            return ActionChip(
              backgroundColor: AC.navy3,
              label: Text('${m['code']}',
                  style: TextStyle(color: AC.tp)),
              onPressed: () {
                ref.read(pilotSessionProvider.notifier).selectBranch(
                      id: m['id'],
                      code: m['code'],
                      nameAr: m['name_ar'],
                    );
              },
            );
          }).toList(),
        );
      },
    );
  }
}
