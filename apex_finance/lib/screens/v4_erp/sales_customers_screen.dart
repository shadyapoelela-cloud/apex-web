/// APEX V4 ERP — Sales & AR / Customers screen (Wave 2 PR#3).
///
/// First V4 screen wired to a real backend. Pulls the authenticated
/// user's client list from /api/v1/clients and renders it via
/// ApexScreenHost so loading / empty / error all share the canonical
/// shell states.
///
/// This is the pattern template every subsequent V4 screen copies:
///   1. Stateful widget owns (loading, rows, error).
///   2. initState() kicks off the API call.
///   3. build() switches on state and delegates the non-ready branches
///      to ApexScreenHost.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../api_service.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/v4/apex_screen_host.dart';

class SalesCustomersScreen extends StatefulWidget {
  const SalesCustomersScreen({super.key});

  @override
  State<SalesCustomersScreen> createState() => _SalesCustomersScreenState();
}

class _SalesCustomersScreenState extends State<SalesCustomersScreen> {
  ApexScreenState _state = ApexScreenState.loading;
  String? _errorDetail;
  List<Map<String, dynamic>> _rows = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _state = ApexScreenState.loading;
      _errorDetail = null;
    });
    try {
      final res = await ApiService.listClients();
      if (!res.success) {
        setState(() {
          _state = ApexScreenState.error;
          _errorDetail = res.error ?? 'unknown error';
        });
        return;
      }

      // The endpoint wraps the list under several possible keys
      // depending on service; normalize here.
      final data = res.data;
      List<Map<String, dynamic>> list = const [];
      if (data is List) {
        list = data.cast<Map<String, dynamic>>();
      } else if (data is Map) {
        for (final key in ['clients', 'items', 'data', 'results']) {
          final v = data[key];
          if (v is List) {
            list = v.cast<Map<String, dynamic>>();
            break;
          }
        }
      }
      setState(() {
        _rows = list;
        _state = list.isEmpty
            ? ApexScreenState.emptyFirstTime
            : ApexScreenState.ready;
      });
    } catch (e) {
      setState(() {
        _state = ApexScreenState.error;
        _errorDetail = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filteredRows {
    if (_query.trim().isEmpty) return _rows;
    final q = _query.trim().toLowerCase();
    return _rows.where((r) {
      final name = (r['name'] ?? r['display_name'] ?? '')
          .toString()
          .toLowerCase();
      final code = (r['code'] ?? r['id'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == ApexScreenState.loading ||
        _state == ApexScreenState.error ||
        _state == ApexScreenState.unauthorized) {
      return ApexScreenHost(
        state: _state,
        errorDetail: _errorDetail,
        primaryAction: _state == ApexScreenState.error
            ? FilledButton(
                onPressed: _load,
                child: const Text('إعادة المحاولة'),
              )
            : null,
      );
    }

    if (_state == ApexScreenState.emptyFirstTime) {
      return ApexScreenHost(
        state: ApexScreenState.emptyFirstTime,
        title: 'لا يوجد عملاء بعد',
        description:
            'أضف أول عميل لبدء إصدار الفواتير، إدارة المقبوضات، وتتبع كشوف الحساب.',
        primaryAction: FilledButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('عميل جديد'),
          onPressed: () => context.push('/clients/new'),
        ),
        secondaryAction: OutlinedButton(
          onPressed: _load,
          child: const Text('تحديث'),
        ),
      );
    }

    // Ready: render the list with filter bar.
    final visible = _filteredRows;
    return Column(
      children: [
        _FilterBar(
          count: visible.length,
          totalCount: _rows.length,
          onQuery: (q) => setState(() => _query = q),
          onCreate: () => context.push('/clients/new'),
          onRefresh: _load,
        ),
        Expanded(
          child: visible.isEmpty
              ? ApexScreenHost(
                  state: ApexScreenState.emptyAfterFilter,
                  description:
                      'لا عميل يطابق "$_query". جرّب بحثًا آخر أو امسح المرشّح.',
                  primaryAction: OutlinedButton(
                    onPressed: () => setState(() => _query = ''),
                    child: const Text('مسح البحث'),
                  ),
                )
              : _CustomersTable(rows: visible),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final int count;
  final int totalCount;
  final ValueChanged<String> onQuery;
  final VoidCallback onCreate;
  final VoidCallback onRefresh;

  const _FilterBar({
    required this.count,
    required this.totalCount,
    required this.onQuery,
    required this.onCreate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          border: Border(bottom: BorderSide(color: AC.navy3)),
        ),
        child: Row(
          children: [
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('عميل جديد'),
            ),
            const SizedBox(width: AppSpacing.md),
            IconButton(
              tooltip: 'تحديث',
              icon: Icon(Icons.refresh, color: AC.ts),
              onPressed: onRefresh,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                onChanged: onQuery,
                style: TextStyle(color: AC.tp),
                cursorColor: AC.gold,
                decoration: InputDecoration(
                  hintText: 'ابحث باسم العميل أو الرمز...',
                  hintStyle: TextStyle(color: AC.ts),
                  prefixIcon: Icon(Icons.search, color: AC.ts),
                  filled: true,
                  fillColor: AC.navy,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AC.navy3),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AC.navy3),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    borderSide: BorderSide(color: AC.gold),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              count == totalCount ? '$count عميل' : '$count / $totalCount',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
          ],
        ),
      );
}

class _CustomersTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  const _CustomersTable({required this.rows});

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        itemCount: rows.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          thickness: 1,
          color: AC.navy3.withValues(alpha: 0.6),
        ),
        itemBuilder: (ctx, i) {
          final r = rows[i];
          final id = (r['id'] ?? '').toString();
          final name =
              (r['name'] ?? r['display_name'] ?? 'عميل بدون اسم').toString();
          final code = (r['code'] ?? r['client_type'] ?? '').toString();
          return InkWell(
            onTap: id.isEmpty
                ? null
                : () => ctx.push('/client-detail?id=$id'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm + 2,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AC.gold.withValues(alpha: 0.18),
                    child: Text(
                      name.isNotEmpty ? name[0] : '?',
                      style: TextStyle(
                        color: AC.gold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: AC.tp,
                            fontSize: AppFontSize.base,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (code.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            code,
                            style: TextStyle(
                              color: AC.ts,
                              fontSize: AppFontSize.sm,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left, color: AC.ts, size: 20),
                ],
              ),
            ),
          );
        },
      );
}
