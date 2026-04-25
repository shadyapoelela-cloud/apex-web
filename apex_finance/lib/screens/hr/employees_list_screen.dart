/// APEX — Employees List with Saudization tracking
/// /hr/employees — Saudi-aware HR list
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_empty_state.dart';
import '../../core/apex_list_shell.dart';
import '../../core/theme.dart';
import '../../widgets/apex_output_chips.dart';

class EmployeesListScreen extends StatefulWidget {
  const EmployeesListScreen({super.key});
  @override
  State<EmployeesListScreen> createState() => _EmployeesListScreenState();
}

class _EmployeesListScreenState extends State<EmployeesListScreen> {
  List<Map<String, dynamic>> _all = [];
  String _filter = 'all';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.hrListEmployees();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.success && res.data is List) {
        _all = (res.data as List).cast<Map<String, dynamic>>();
      } else if (res.success && res.data is Map && (res.data as Map)['data'] is List) {
        _all = ((res.data as Map)['data'] as List).cast<Map<String, dynamic>>();
      } else {
        _error = res.error;
      }
    });
  }

  bool _isSaudi(Map e) {
    final nat = (e['nationality'] ?? e['nationality_code'] ?? '').toString().toLowerCase();
    return nat == 'sa' || nat == 'saudi' || nat == 'سعودي' || nat == 'سعودية';
  }

  int get _saudiCount => _all.where(_isSaudi).length;
  int get _nonSaudiCount => _all.length - _saudiCount;
  double get _saudizationPct => _all.isEmpty ? 0 : (_saudiCount / _all.length * 100);

  List<Map<String, dynamic>> get _filtered {
    return switch (_filter) {
      'saudi' => _all.where(_isSaudi).toList(),
      'expat' => _all.where((e) => !_isSaudi(e)).toList(),
      _ => _all,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ApexListShell<Map<String, dynamic>>(
      title: 'الموظفون',
      subtitle: '${_all.length} موظف · سعودة ${_saudizationPct.toStringAsFixed(1)}%',
      primaryCta: ApexCta(
        label: 'موظف جديد',
        icon: Icons.person_add_alt,
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('شاشة إنشاء موظف — قادمة')),
          );
        },
      ),
      filterChips: [
        ApexFilterChip(
          label: 'الكل',
          selected: _filter == 'all',
          onTap: () => setState(() => _filter = 'all'),
          count: _all.length,
        ),
        ApexFilterChip(
          label: 'سعودي',
          selected: _filter == 'saudi',
          onTap: () => setState(() => _filter = 'saudi'),
          icon: Icons.flag,
          count: _saudiCount,
        ),
        ApexFilterChip(
          label: 'مقيم',
          selected: _filter == 'expat',
          onTap: () => setState(() => _filter = 'expat'),
          icon: Icons.public,
          count: _nonSaudiCount,
        ),
      ],
      items: _filtered,
      loading: _loading,
      error: _error,
      onRefresh: _load,
      listHeader: _saudizationCard(),
      listFooter: const ApexOutputChips(items: [
        ApexChipLink('تشغيل الرواتب', '/hr/payroll-run', Icons.payments),
        ApexChipLink('سجل ساعات العمل', '/hr/timesheet', Icons.access_time),
        ApexChipLink('تقارير المصاريف', '/hr/expense-reports', Icons.receipt_long),
      ]),
      emptyState: ApexEmptyState(
        icon: Icons.people_outline,
        title: 'لا يوجد موظفون',
        description: 'أضف موظفك الأول لتفعيل GOSI + Saudization tracking',
        primaryLabel: 'إضافة موظف',
        primaryIcon: Icons.person_add_alt,
        onPrimary: () {},
      ),
      itemBuilder: (ctx, e) {
        final saudi = _isSaudi(e);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AC.gold.withValues(alpha: 0.20),
              child: Icon(saudi ? Icons.flag : Icons.public, color: AC.gold, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${e['name'] ?? e['full_name'] ?? '-'}',
                    style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.w700)),
                Text('${e['position'] ?? e['title'] ?? ''} · ${e['department'] ?? ''}',
                    style: TextStyle(color: AC.ts, fontSize: 11)),
              ]),
            ),
            Text('${e['salary'] ?? e['gross_pay'] ?? '-'}',
                style: TextStyle(color: AC.gold, fontFamily: 'monospace', fontSize: 11.5, fontWeight: FontWeight.w700)),
          ]),
        );
      },
    );
  }

  Widget _saudizationCard() {
    final pct = _saudizationPct;
    final color = pct >= 50 ? AC.ok : pct >= 30 ? AC.warn : AC.err;
    final tier = pct >= 50
        ? 'بلاتيني'
        : pct >= 30
            ? 'فضي'
            : 'أحمر — يحتاج تحسين';
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.20), AC.navy3],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.workspace_premium, color: color),
          const SizedBox(width: 8),
          Text('نسبة السعودة',
              style: TextStyle(color: AC.gold, fontSize: 13, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(tier,
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Text('${pct.toStringAsFixed(1)}%',
              style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.flag, color: AC.gold, size: 12),
                const SizedBox(width: 4),
                Text('$_saudiCount سعودي', style: TextStyle(color: AC.tp, fontSize: 11)),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.public, color: AC.ts, size: 12),
                const SizedBox(width: 4),
                Text('$_nonSaudiCount مقيم', style: TextStyle(color: AC.tp, fontSize: 11)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            backgroundColor: AC.navy3,
            color: color,
            minHeight: 8,
          ),
        ),
      ]),
    );
  }
}
