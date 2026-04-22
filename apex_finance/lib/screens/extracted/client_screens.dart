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
            title: 'العملاء',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
              ApexToolbarAction(
                label: 'عميل جديد',
                icon: Icons.add,
                primary: true,
                onPressed: _openCreate,
              ),
            ],
          ),
          // 2. Apex Filter Bar
          ApexFilterBar(
            searchHint: 'ابحث بالاسم أو النوع...',
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

// ── 2. Client Create Screen ──
class ClientCreateScreen extends StatefulWidget {
  const ClientCreateScreen({super.key});
  @override
  State<ClientCreateScreen> createState() => _ClientCreateS();
}

class _ClientCreateS extends State<ClientCreateScreen> {
  final _nameC = TextEditingController();
  String? _selectedType;
  bool _ld = false;
  String? _err;

  Future<void> _create() async {
    if (_nameC.text.trim().isEmpty || _selectedType == null) {
      setState(() => _err = 'ادخل اسم العميل واختر النوع');
      return;
    }
    setState(() { _ld = true; _err = null; });
    try {
      final res = await ApiService.createClient(
        clientCode: _nameC.text.trim().replaceAll(' ', '_'),
        name: _nameC.text.trim(),
        clientType: _selectedType!,
        nameAr: _nameC.text.trim(),
      );
      if (res.success) {
        if (mounted) Navigator.pop(context, true);
      } else {
        setState(() { _err = res.error ?? 'فشل'; _ld = false; });
      }
    } catch (e) { setState(() { _err = e.toString(); _ld = false; }); }
  }

  @override
  void dispose() { _nameC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(title: Text('عميل جديد', style: TextStyle(color: AC.gold)), backgroundColor: AC.navy),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SizedBox(
              height: 56,
              child: TextField(
                controller: _nameC,
                style: TextStyle(color: AC.tp),
                decoration: InputDecoration(
                  labelText: 'اسم الشركة *',
                  labelStyle: TextStyle(color: AC.td),
                  prefixIcon: Icon(Icons.business, color: AC.gold),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.bdr), borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AC.gold), borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_err!, style: TextStyle(color: core_theme.AC.err), textAlign: TextAlign.center),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Icon(Icons.category, color: AC.gold, size: 20),
                SizedBox(width: 8),
                Text('نوع العميل *', style: TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _typeCard('standard_business', 'شركة تجارية عادية', Icons.business, false),
                _typeCard('financial_entity', 'جهة مالية', Icons.account_balance, true),
                _typeCard('financing_entity', 'جهة تمويلية', Icons.monetization_on, true),
                _typeCard('accounting_firm', 'مكتب محاسبة', Icons.calculate, true),
                _typeCard('audit_firm', 'مكتب مراجعة', Icons.verified_user, true),
                _typeCard('investment_entity', 'جهة استثمارية', Icons.trending_up, true),
                _typeCard('sector_consulting_entity', 'جهة استشارية', Icons.lightbulb, true),
                _typeCard('government_entity', 'جهة حكومية', Icons.account_balance_wallet, true),
                _typeCard('legal_regulatory_entity', 'جهة قانونية أو تنظيمية', Icons.gavel, true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: _ld
                  ? Center(child: SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AC.gold)))
                  : apexPrimaryButton('انشاء العميل', _ld ? null : _create),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeCard(String code, String label, IconData icon, bool isKm) {
    final sel = _selectedType == code;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = code),
      child: Container(
        height: 52,
        margin: EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.symmetric(horizontal: 16),
        decoration: apexSelectableDecoration(isSelected: sel, activeColor: AC.gold),
        child: Row(
          children: [
            Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? AC.gold : AC.ts, size: 20),
            SizedBox(width: 12),
            Icon(icon, color: sel ? AC.gold : AC.ts, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(label, style: TextStyle(
                color: sel ? AC.gold : AC.tp,
                fontSize: 14,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
              )),
            ),
            if (isKm)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('معرفي', style: TextStyle(color: AC.gold, fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }
}












// ── 3. COA Upload Screen ──
