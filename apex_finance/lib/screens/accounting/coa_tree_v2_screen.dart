/// APEX — Chart of Accounts (canonical, hierarchical with category filters)
/// /app/erp/finance/coa-editor — replaces legacy /coa-tree
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';
import '../compliance/account_ledger_screen.dart';

class CoaTreeV2Screen extends StatefulWidget {
  const CoaTreeV2Screen({super.key});
  @override
  State<CoaTreeV2Screen> createState() => _CoaTreeV2ScreenState();
}

class _CoaTreeV2ScreenState extends State<CoaTreeV2Screen> {
  List<Map<String, dynamic>> _all = [];
  String _filter = 'all';
  bool _loading = false;
  String? _error;

  static const _categories = [
    ('all', 'الكل'),
    ('asset', 'أصول'),
    ('liability', 'خصوم'),
    ('equity', 'حقوق ملكية'),
    ('revenue', 'إيرادات'),
    ('expense', 'مصروفات'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entityId = S.savedEntityId;
    if (entityId == null) {
      setState(() => _error = 'لا يوجد كيان نشط');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.pilotListAccounts(entityId);
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
    return _all.where((a) => a['category'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'شجرة الحسابات (SOCPA)',
      subtitle: '${_all.length} حساب',
      primaryCta: ApexCta(
        label: 'حساب جديد',
        icon: Icons.add,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('شاشة إنشاء حساب — قادمة')),
          );
        },
      ),
      filterChips: [
        for (final cat in _categories)
          ApexFilterChip(
            label: cat.$2,
            selected: _filter == cat.$1,
            onTap: () => setState(() => _filter = cat.$1),
            count: cat.$1 == 'all' ? _all.length : _all.where((a) => a['category'] == cat.$1).length,
          ),
      ],
      items: _filtered,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('قائمة القيود', '/app/erp/finance/je-builder', Icons.book),
        ApexChipLink('ميزان المراجعة', '/app/erp/finance/statements', Icons.assessment),
        ApexChipLink('محرر الحسابات', '/app/erp/finance/coa-editor', Icons.edit_note),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.account_tree_outlined,
        title: 'لا توجد حسابات',
        description: 'يجب إعداد شجرة الحسابات أولاً (SOCPA افتراضي)',
        primaryLabel: 'بذر الحسابات الافتراضية',
        primaryIcon: Icons.bolt,
        onPrimary: () async {
          final entityId = S.savedEntityId;
          if (entityId == null) return;
          await ApiService.pilotSeedCoa(entityId);
          if (mounted) _load();
        },
      ),
      itemBuilder: (ctx, a) {
        final isHeader = a['type'] == 'header';
        final color = switch (a['category']) {
          'asset' => AC.info,
          'liability' => AC.warn,
          'equity' => AC.gold,
          'revenue' => AC.ok,
          'expense' => AC.err,
          _ => AC.ts,
        };
        final level = (a['level'] as int?) ?? 1;
        return InkWell(
          onTap: () {
            if (a['type'] == 'detail') {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => AccountLedgerScreen(
                  accountId: a['id'] as String,
                  accountCode: a['code'] as String?,
                  accountName: a['name_ar'] as String?,
                ),
              ));
            }
          },
          child: Padding(
            padding: EdgeInsetsDirectional.only(
                start: 14.0 + (level - 1) * 16,
                end: 14, top: 10, bottom: 10),
            child: Row(children: [
              Icon(isHeader ? Icons.folder : Icons.description,
                  color: color, size: 14),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: Text('${a['code']}',
                    style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11.5)),
              ),
              Expanded(
                child: Text('${a['name_ar']}',
                    style: TextStyle(
                        color: isHeader ? AC.gold : AC.tp,
                        fontSize: 12.5,
                        fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500)),
              ),
              if (a['type'] == 'detail') Icon(Icons.chevron_left, color: AC.ts, size: 14),
            ]),
          ),
        );
      },
    );
  }
}
