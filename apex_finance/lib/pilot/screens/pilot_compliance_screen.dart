/// Pilot Compliance — ZATCA + GOSI + WPS + UAE CT + VAT Return
/// ═════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/pilot_session_provider.dart';
import '../providers/pilot_data_providers.dart';

class PilotComplianceScreen extends ConsumerWidget {
  const PilotComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(pilotSessionProvider);
    if (!selection.hasEntity) {
      return Center(
          child: Text('اختر كياناً أولاً', style: TextStyle(color: AC.ts)));
    }
    final eid = selection.entityId!;
    final country = selection.entityCountry;

    return ListView(padding: const EdgeInsets.all(16), children: [
      if (country == 'SA') _zatcaCard(ref, eid),
      if (country == 'SA') ...[
        const SizedBox(height: 12),
        _gosiCard(ref, eid),
        const SizedBox(height: 12),
        _wpsCard(ref, eid),
      ],
      if (country == 'AE') ...[
        const SizedBox(height: 12),
        _ctCard(ref, eid),
      ],
      const SizedBox(height: 12),
      _vatCard(ref, eid, country),
    ]);
  }

  Widget _zatcaCard(WidgetRef ref, String eid) {
    final subs = ref.watch(zatcaSubmissionsProvider(eid));
    return _cardShell(
      title: 'ZATCA — المرحلة الثانية',
      icon: Icons.verified,
      color: AC.gold,
      subtitle: 'الفواتير المُولَّد لها QR + hash chain',
      child: subs.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('خطأ: $e', style: TextStyle(color: AC.err)),
        data: (list) {
          if (list.isEmpty) {
            return Text('لا توجد إرساليات بعد. أنشئ بيعاً في POS.',
                style: TextStyle(color: AC.td));
          }
          return Column(children: [
            Text('${list.length} فاتورة مُرسَلة',
                style: TextStyle(color: AC.tp, fontSize: 15)),
            const SizedBox(height: 8),
            ...list.take(5).map((s) {
              final m = s as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AC.navy3,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('ICV #${m['invoice_counter']}',
                        style: TextStyle(color: AC.gold, fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(m['source_reference'] ?? '',
                          style: TextStyle(color: AC.tp, fontSize: 13))),
                  Text(
                      '${(double.tryParse('${m['total_incl_vat']}') ?? 0).toStringAsFixed(2)}',
                      style: TextStyle(color: AC.ts, fontSize: 13)),
                  const SizedBox(width: 8),
                  _badge(m['status']),
                ]),
              );
            }),
          ]);
        },
      ),
    );
  }

  Widget _gosiCard(WidgetRef ref, String eid) {
    final regs = ref.watch(gosiRegistrationsProvider(eid));
    return _cardShell(
      title: 'GOSI — التأمينات الاجتماعية',
      icon: Icons.health_and_safety,
      color: AC.info,
      subtitle: 'تسجيلات الموظفين واشتراكاتهم',
      child: regs.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('خطأ: $e', style: TextStyle(color: AC.err)),
        data: (list) {
          if (list.isEmpty) {
            return Text('لا توجد تسجيلات بعد.', style: TextStyle(color: AC.td));
          }
          return Text('${list.length} موظف مسجّل',
              style: TextStyle(color: AC.tp, fontSize: 15));
        },
      ),
    );
  }

  Widget _wpsCard(WidgetRef ref, String eid) {
    final batches = ref.watch(wpsBatchesProvider(eid));
    return _cardShell(
      title: 'WPS — نظام حماية الأجور',
      icon: Icons.payments,
      color: AC.ok,
      subtitle: 'دفعات الرواتب + ملفات SIF',
      child: batches.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('خطأ: $e', style: TextStyle(color: AC.err)),
        data: (list) {
          if (list.isEmpty) {
            return Text('لا توجد دفعات WPS بعد.', style: TextStyle(color: AC.td));
          }
          return Column(
            children: list.take(5).map((b) {
              final m = b as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Icon(Icons.description, color: AC.gold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(m['sif_file_name'] ?? '${m['year']}-${m['month']}',
                        style: TextStyle(color: AC.tp)),
                  ),
                  Text('${m['employee_count']} موظف • ${m['total_net']}',
                      style: TextStyle(color: AC.ts, fontSize: 13)),
                  const SizedBox(width: 8),
                  _badge(m['status']),
                ]),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _ctCard(WidgetRef ref, String eid) {
    final filings = ref.watch(FutureProvider.autoDispose((ref) async {
      final client = ref.watch(pilotClientProvider);
      final r = await client.listUaeCtFilings(eid);
      return r.success ? (r.data as List) : [];
    }));
    return _cardShell(
      title: 'UAE Corporate Tax — 9%',
      icon: Icons.account_balance,
      color: AC.warn,
      subtitle: 'إقرارات ضريبة الشركات الإماراتية',
      child: filings.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('خطأ: $e', style: TextStyle(color: AC.err)),
        data: (list) {
          if (list.isEmpty) {
            return Text('لا توجد إقرارات بعد.', style: TextStyle(color: AC.td));
          }
          return Column(
            children: list.map((f) {
              final m = f as Map;
              return Row(children: [
                Text('السنة ${m['fiscal_year']}',
                    style: TextStyle(color: AC.tp)),
                const Spacer(),
                Text('صافي: ${m['net_ct_payable']} AED',
                    style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                _badge(m['status']),
              ]);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _vatCard(WidgetRef ref, String eid, String? country) {
    final returns = ref.watch(vatReturnsProvider(eid));
    return _cardShell(
      title: 'إقرارات VAT',
      icon: Icons.receipt_long,
      color: AC.purple,
      subtitle: 'ربع سنوية — محسوبة من GL تلقائياً',
      child: returns.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text('خطأ: $e', style: TextStyle(color: AC.err)),
        data: (list) {
          if (list.isEmpty) {
            return Text('لم يتم توليد إقرارات VAT بعد.',
                style: TextStyle(color: AC.td));
          }
          return Column(
            children: list.take(5).map((v) {
              final m = v as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text('Q${m['period_number']} ${m['year']}',
                      style: TextStyle(color: AC.tp, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Text('${m['country']}',
                      style: TextStyle(color: AC.ts, fontSize: 12)),
                  const SizedBox(width: 16),
                  Text('Output: ${m['output_vat']}',
                      style: TextStyle(color: AC.ts, fontSize: 13)),
                  const SizedBox(width: 12),
                  Text('صافي: ${m['net_vat_payable']}',
                      style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  _badge(m['status']),
                ]),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _cardShell({
    required String title,
    required IconData icon,
    required Color color,
    required String subtitle,
    required Widget child,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(color: AC.ts, fontSize: 12)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      );

  Widget _badge(String? status) {
    final col = switch (status) {
      'reported' || 'accepted' || 'generated' || 'active' => AC.ok,
      'pending' || 'draft' || 'submitted' => AC.warn,
      'rejected' || 'failed' => AC.err,
      _ => AC.ts,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(status ?? '?',
          style:
              TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}
