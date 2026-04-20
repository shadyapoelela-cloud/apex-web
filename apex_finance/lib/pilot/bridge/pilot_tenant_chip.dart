/// Pilot Tenant Chip — AppBar widget to bind/switch tenants.
/// ══════════════════════════════════════════════════════════
/// Shows in the V5 TopBar next to the EntityScopeSelector.
/// When a tenant is bound, displays its name. Click opens a
/// dialog to paste a Tenant ID and bind.

library;

import 'package:flutter/material.dart';

import 'pilot_bridge.dart';

class PilotTenantChip extends StatefulWidget {
  const PilotTenantChip({super.key});
  @override
  State<PilotTenantChip> createState() => _PilotTenantChipState();
}

class _PilotTenantChipState extends State<PilotTenantChip> {
  @override
  void initState() {
    super.initState();
    PilotBridge.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    PilotBridge.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bridge = PilotBridge.instance;
    final isBound = bridge.isBound;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isBound
              ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBound
                ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isBound ? Icons.cloud_done : Icons.cloud_off,
              size: 14,
              color: isBound ? const Color(0xFF059669) : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              isBound
                  ? (bridge.tenantNameAr ?? bridge.tenantSlug ?? 'مستأجر')
                  : 'اربط مستأجر',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isBound ? Colors.black87 : Colors.black54,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 16, color: isBound ? Colors.black87 : Colors.black54),
          ],
        ),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final bridge = PilotBridge.instance;
    final ctrl = TextEditingController(text: bridge.tenantId ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Row(children: const [
            Icon(Icons.link, color: Color(0xFFD4AF37)),
            SizedBox(width: 8),
            Text('ربط مستأجر Pilot'),
          ]),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (bridge.isBound) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF059669).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.cloud_done,
                              color: Color(0xFF059669), size: 18),
                          const SizedBox(width: 6),
                          Text(bridge.tenantNameAr ?? bridge.tenantSlug ?? '',
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 4),
                        Text('${bridge.entities.length} كيان • '
                            '${bridge.branches.length} فرع',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Tenant ID (UUID):',
                    style: TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 6),
                TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'هذا يربط الواجهة ببيانات حقيقية من الباك-إند عبر '
                  '/pilot/tenants/{id}. كل الشاشات (نقاط البيع، المخزون، '
                  'المستودعات...) ستقرأ من هذا المستأجر.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      height: 1.5),
                ),
              ],
            ),
          ),
          actions: [
            if (bridge.isBound)
              TextButton(
                onPressed: () {
                  PilotBridge.instance.unbind();
                  Navigator.pop(ctx);
                },
                child: const Text('فكّ الربط',
                    style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إغلاق'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
              ),
              onPressed: () async {
                final id = ctrl.text.trim();
                if (id.isEmpty) return;
                final ok = await PilotBridge.instance.bindTenant(id);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  backgroundColor: ok
                      ? const Color(0xFF059669)
                      : Colors.red,
                  content: Text(ok
                      ? 'تم ربط المستأجر بنجاح ✓'
                      : 'فشل ربط المستأجر — تحقق من الـ ID'),
                ));
              },
              child: const Text('ربط'),
            ),
          ],
        ),
      ),
    );
  }
}
