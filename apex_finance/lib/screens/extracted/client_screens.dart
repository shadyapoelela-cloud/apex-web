import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/apex_app_bar.dart';
import '../../core/apex_sticky_toolbar.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/apex_data_table.dart';
import '../../core/apex_filter_bar.dart';
import '../../core/apex_saved_views.dart';
import '../../core/design_tokens.dart';
import '../../core/shared_constants.dart';
import '../../core/ui_components.dart';

// ── 1. Client List Screen ── (Apex Shared Layer applied 2026-04-17)
class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});
  @override
  State<ClientListScreen> createState() => _ClientListS();
}

class _ClientListS extends State<ClientListScreen> {
  List<Map<String, dynamic>> _allClients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  bool _loading = true;
  ApexFilterState _filter = const ApexFilterState();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.listClients();
      if (res.success) {
        final d = res.data;
        final raw = d is List ? d : (d['clients'] ?? []);
        final list = (raw as List).cast<Map<String, dynamic>>();
        setState(() {
          _allClients = list;
          _applyFilter();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    final q = _filter.searchText.trim().toLowerCase();
    final activeChips = _filter.activeChipKeys;
    _filteredClients = _allClients.where((c) {
      if (q.isNotEmpty) {
        final name = (c['name_ar'] ?? c['name'] ?? '').toString().toLowerCase();
        final code = (c['client_type_code'] ?? '').toString().toLowerCase();
        if (!name.contains(q) && !code.contains(q)) return false;
      }
      if (activeChips.contains('knowledge_mode') && c['knowledge_mode'] != true) {
        return false;
      }
      if (activeChips.contains('owner') && (c['role'] ?? 'owner') != 'owner') {
        return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openCreate() async {
    final created = await context.push('/clients/create');
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          // 1. Apex Sticky Toolbar
          ApexStickyToolbar(
            title: 'الشركات',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
              ApexToolbarAction(
                label: 'شركة جديدة',
                icon: Icons.add,
                primary: true,
                onPressed: _openCreate,
              ),
            ],
          ),
          // 2. Apex Filter Bar
          ApexFilterBar(
            searchHint: 'ابحث باسم الشركة أو النوع...',
            chips: const [
              ApexFilterChip(
                key: 'knowledge_mode',
                label: 'وضع المعرفة',
                icon: Icons.psychology_outlined,
              ),
              ApexFilterChip(
                key: 'owner',
                label: 'أنا المالك',
                icon: Icons.person_outline,
              ),
            ],
            onFilterChanged: (s) {
              setState(() {
                _filter = s;
                _applyFilter();
              });
            },
          ),
          // 3. Saved Views bar — users persist filter presets to the
          // backend (/api/v1/saved-views) and restore with one click.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: ApexSavedViewsBar(
              screen: 'clients',
              currentPayload: {
                'search': _filter.searchText,
                'chips': _filter.activeChipKeys.toList(),
              },
              onApply: (view) {
                final p = view.payload;
                setState(() {
                  _filter = ApexFilterState(
                    searchText: (p['search'] as String?) ?? '',
                    activeChipKeys: {
                      ...((p['chips'] as List?)?.cast<String>() ?? const []),
                    },
                  );
                  _applyFilter();
                });
              },
            ),
          ),
          // 3. Apex Data Table (or Shimmer while loading)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: ApexDataTable<Map<String, dynamic>>(
                loading: _loading,
                columns: [
                  ApexColumn(
                    key: 'avatar',
                    label: '',
                    width: 56,
                    sortable: false,
                    cell: (c) => CircleAvatar(
                      radius: 14,
                      backgroundColor: AC.gold.withValues(alpha: 0.2),
                      child: Text(
                        (c['name_ar'] ?? c['name'] ?? '?').toString()[0],
                        style: TextStyle(
                          color: AC.gold,
                          fontSize: AppFontSize.md,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ApexColumn(
                    key: 'name',
                    label: 'الاسم',
                    flex: 3,
                    sortValue: (c) => (c['name_ar'] ?? c['name'] ?? '').toString(),
                    cell: (c) => Text(
                      (c['name_ar'] ?? c['name'] ?? '').toString(),
                      style: TextStyle(
                        color: AC.tp,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ApexColumn(
                    key: 'type',
                    label: 'النوع',
                    flex: 2,
                    sortValue: (c) => (c['client_type_code'] ?? '').toString(),
                    cell: (c) => Text(
                      (c['client_type_code'] ?? c['client_type'] ?? '—').toString(),
                      style: TextStyle(color: AC.ts),
                    ),
                  ),
                  ApexColumn(
                    key: 'role',
                    label: 'الدور',
                    flex: 1,
                    sortValue: (c) => (c['role'] ?? 'owner').toString(),
                    cell: (c) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AC.navy3,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        (c['role'] ?? 'owner').toString(),
                        style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                      ),
                    ),
                  ),
                  ApexColumn(
                    key: 'kb',
                    label: 'وضع المعرفة',
                    width: 120,
                    alignment: Alignment.center,
                    sortValue: (c) => c['knowledge_mode'] == true ? 1 : 0,
                    cell: (c) => c['knowledge_mode'] == true
                        ? Icon(Icons.check_circle,
                            color: AC.ok, size: 18)
                        : Icon(Icons.remove, color: AC.td, size: 18),
                  ),
                ],
                rows: _filteredClients,
                onRowTap: (c) => context.push(
                  '/client-detail',
                  extra: {
                    'id': c['id'],
                    'name': (c['name_ar'] ?? c['name'] ?? '').toString(),
                  },
                ),
                emptyState: _EmptyClients(onCreate: _openCreate),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyClients extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyClients({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business, size: 64, color: AC.td),
            const SizedBox(height: AppSpacing.md),
            Text(
              'لا يوجد عملاء بعد',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.lg),
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إنشاء عميل جديد'),
              onPressed: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 2. Client Create Screen — REMOVED Stage 5d-3 (2026-04-29) ──
// Never instantiated; client/entity creation handled by /settings/entities
// (EntitySetupScreen). The /clients/create route still works as a redirect.
// Restore from git history.
