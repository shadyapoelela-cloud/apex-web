/// Pilot Products Screen — عرض المنتجات والمتغيّرات.
/// ═════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../providers/pilot_session_provider.dart';
import '../providers/pilot_data_providers.dart';

class PilotProductsScreen extends ConsumerStatefulWidget {
  const PilotProductsScreen({super.key});
  @override
  ConsumerState<PilotProductsScreen> createState() =>
      _PilotProductsScreenState();
}

class _PilotProductsScreenState extends ConsumerState<PilotProductsScreen> {
  final _searchCtrl = TextEditingController();
  String? _search;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(pilotSessionProvider);
    if (!selection.hasTenant) {
      return Center(
          child: Text('اختر مستأجراً أولاً', style: TextStyle(color: AC.ts)));
    }
    final query = ProductsQuery(
      tenantId: selection.tenantId!,
      search: _search,
    );
    final products = ref.watch(productsProvider(query));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم أو الكود...',
            hintStyle: TextStyle(color: AC.td),
            prefixIcon: Icon(Icons.search, color: AC.gold),
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AC.bdr)),
          ),
          onSubmitted: (v) => setState(() => _search = v.trim().isEmpty ? null : v.trim()),
        ),
      ),
      Expanded(
        child: products.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) =>
              Center(child: Text('خطأ: $e', style: TextStyle(color: AC.err))),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                  child: Text('لا توجد منتجات',
                      style: TextStyle(color: AC.td)));
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(productsProvider(query)),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final p = list[i] as Map;
                  return _productTile(p);
                },
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _productTile(Map p) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AC.bdr),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.checkroom, color: AC.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p['name_ar'] ?? p['name_en'] ?? '',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: 15,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AC.navy3,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(p['code'] ?? '',
                        style: TextStyle(color: AC.gold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                      '${p['active_variant_count'] ?? 0} متغيّر • كمية متاحة: ${p['total_stock_on_hand'] ?? 0}',
                      style: TextStyle(color: AC.ts, fontSize: 12)),
                ]),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(p['status']).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('${p['status'] ?? '?'}',
                style: TextStyle(
                    color: _statusColor(p['status']),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Color _statusColor(String? s) {
    switch (s) {
      case 'active':
        return AC.ok;
      case 'draft':
        return AC.warn;
      case 'archived':
      case 'discontinued':
        return AC.td;
      default:
        return AC.ts;
    }
  }
}
