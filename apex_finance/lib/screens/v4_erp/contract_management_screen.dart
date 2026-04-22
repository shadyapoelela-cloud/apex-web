/// APEX Wave 61 — Contract Management.
/// Route: /app/erp/operations/contracts
///
/// Active contracts registry with renewals, SLAs, and risk flags.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class ContractManagementScreen extends StatefulWidget {
  const ContractManagementScreen({super.key});
  @override
  State<ContractManagementScreen> createState() => _ContractManagementScreenState();
}

class _ContractManagementScreenState extends State<ContractManagementScreen> {
  String _typeFilter = 'all';
  String _statusFilter = 'all';

  final _contracts = const [
    _Contract('CTR-2024-042', 'اتفاقية توريد سنوية — سابك', 'supply', 'customer', 'active', '2024-01-01', '2026-12-31', 8500000, 4500000, 92, 'سنوي'),
    _Contract('CTR-2024-018', 'عقد تدقيق خارجي — NEOM', 'audit', 'customer', 'active', '2024-03-15', '2025-03-14', 2400000, 1800000, 75, 'سنوي'),
    _Contract('CTR-2025-005', 'عقد صيانة نظم — STC', 'service', 'customer', 'active', '2025-01-01', '2027-12-31', 1850000, 620000, 35, 'سنوي ديناميكي'),
    _Contract('CTR-2025-012', 'اتفاقية استشارية — Saudi Airlines', 'advisory', 'customer', 'active', '2025-04-01', '2026-03-31', 950000, 620000, 68, 'عند الإنجاز'),
    _Contract('CTR-2024-065', 'عقد إيجار مقر رئيسي', 'lease', 'vendor', 'active', '2022-07-01', '2027-06-30', 3600000, 1500000, 58, 'سنوي مقدّم'),
    _Contract('CTR-2024-033', 'اتفاقية ترخيص SAP', 'license', 'vendor', 'expiring', '2024-04-01', '2026-04-30', 1200000, 1200000, 98, 'سنوي'),
    _Contract('CTR-2024-028', 'عقد اتصالات — STC', 'service', 'vendor', 'active', '2024-01-01', '2026-12-31', 480000, 280000, 58, 'شهري'),
    _Contract('CTR-2023-075', 'عقد تمويل بنكي', 'financing', 'vendor', 'active', '2023-06-01', '2028-06-01', 15000000, 0, 55, 'ربعي'),
    _Contract('CTR-2024-055', 'عقد توريد مواد — Oracle', 'license', 'vendor', 'expired', '2024-04-01', '2025-04-01', 850000, 850000, 100, 'سنوي'),
  ];

  List<_Contract> get _filtered {
    return _contracts.where((c) {
      if (_typeFilter != 'all' && c.type != _typeFilter) return false;
      if (_statusFilter != 'all' && c.status != _statusFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalValue = _contracts.fold(0.0, (s, c) => s + c.value);
    final active = _contracts.where((c) => c.status == 'active').length;
    final expiring = _contracts.where((c) => c.status == 'expiring').length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('إجمالي القيمة', _fmtM(totalValue), core_theme.AC.gold, Icons.attach_money),
            _kpi('عقود سارية', '$active', core_theme.AC.ok, Icons.check_circle),
            _kpi('قرب الانتهاء', '$expiring', core_theme.AC.warn, Icons.schedule),
            _kpi('إجمالي العقود', '${_contracts.length}', core_theme.AC.info, Icons.description),
          ],
        ),
        const SizedBox(height: 16),
        _buildFilters(),
        const SizedBox(height: 16),
        for (final c in _filtered) _contractCard(c),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF455A64), Color(0xFF607D8B)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.gavel, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إدارة العقود',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('سجل شامل للعقود مع تنبيهات التجديد، SLAs، وتقييم المخاطر',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 16),
            label: Text('عقد جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF455A64),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterChip('النوع', _typeFilter, [
          _FilterOpt('all', 'الكل'),
          _FilterOpt('supply', 'توريد'),
          _FilterOpt('service', 'خدمات'),
          _FilterOpt('audit', 'تدقيق'),
          _FilterOpt('advisory', 'استشارات'),
          _FilterOpt('lease', 'إيجار'),
          _FilterOpt('license', 'تراخيص'),
          _FilterOpt('financing', 'تمويل'),
        ], (v) => setState(() => _typeFilter = v)),
        _filterChip('الحالة', _statusFilter, [
          _FilterOpt('all', 'الكل'),
          _FilterOpt('active', 'ساري'),
          _FilterOpt('expiring', 'قرب الانتهاء'),
          _FilterOpt('expired', 'منتهي'),
        ], (v) => setState(() => _statusFilter = v)),
      ],
    );
  }

  Widget _filterChip(String label, String value, List<_FilterOpt> options, void Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: core_theme.AC.td),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label:', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          const SizedBox(width: 6),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            isDense: true,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: core_theme.AC.tp),
            items: options.map((o) => DropdownMenuItem(value: o.id, child: Text(o.label))).toList(),
            onChanged: (v) => onChanged(v ?? 'all'),
          ),
        ],
      ),
    );
  }

  Widget _contractCard(_Contract c) {
    final endDate = DateTime.parse(c.endDate);
    final daysLeft = endDate.difference(DateTime(2026, 4, 19)).inDays;
    final statusColor = _statusColor(c.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _typeColor(c.type).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_typeIcon(c.type), color: _typeColor(c.type)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(c.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _typeColor(c.type).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(_typeLabel(c.type),
                              style: TextStyle(fontSize: 10, color: _typeColor(c.type), fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (c.side == 'customer' ? core_theme.AC.ok : core_theme.AC.warn).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(c.side == 'customer' ? 'عميل' : 'مورد',
                              style: TextStyle(
                                fontSize: 10,
                                color: c.side == 'customer' ? core_theme.AC.ok : core_theme.AC.warn,
                                fontWeight: FontWeight.w800,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(c.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_fmt(c.value),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: core_theme.AC.gold, fontFamily: 'monospace')),
                  Text('ر.س إجمالي', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(_statusLabel(c.status),
                        style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: core_theme.AC.navy3,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('البداية', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      Text(c.startDate, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('النهاية', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      Text(c.endDate, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الأيام المتبقية', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      Text('${daysLeft < 0 ? 0 : daysLeft} يوم',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: daysLeft < 60 ? core_theme.AC.warn : core_theme.AC.ok,
                          )),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('شروط الدفع', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      Text(c.paymentTerms, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text('نسبة الإنجاز', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              const SizedBox(width: 8),
              Expanded(
                child: LinearProgressIndicator(
                  value: c.progress / 100,
                  backgroundColor: core_theme.AC.bdr,
                  valueColor: AlwaysStoppedAnimation(core_theme.AC.gold),
                  minHeight: 6,
                ),
              ),
              const SizedBox(width: 8),
              Text('${c.progress}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: core_theme.AC.gold)),
            ],
          ),
          if (daysLeft < 60 && daysLeft > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: core_theme.AC.warn,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: core_theme.AC.warn),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: core_theme.AC.warn, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'ينتهي العقد خلال $daysLeft يوم — ابدأ محادثات التجديد',
                      style: TextStyle(fontSize: 11, color: core_theme.AC.warn),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text('تجديد', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'supply':
        return core_theme.AC.info;
      case 'service':
        return core_theme.AC.info;
      case 'audit':
        return core_theme.AC.purple;
      case 'advisory':
        return core_theme.AC.purple;
      case 'lease':
        return Colors.brown;
      case 'license':
        return Colors.deepOrange;
      case 'financing':
        return core_theme.AC.gold;
      default:
        return core_theme.AC.td;
    }
  }

  IconData _typeIcon(String t) {
    switch (t) {
      case 'supply':
        return Icons.local_shipping;
      case 'service':
        return Icons.build;
      case 'audit':
        return Icons.fact_check;
      case 'advisory':
        return Icons.lightbulb;
      case 'lease':
        return Icons.home_work;
      case 'license':
        return Icons.vpn_key;
      case 'financing':
        return Icons.account_balance;
      default:
        return Icons.description;
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'supply':
        return 'توريد';
      case 'service':
        return 'خدمات';
      case 'audit':
        return 'تدقيق';
      case 'advisory':
        return 'استشارات';
      case 'lease':
        return 'إيجار';
      case 'license':
        return 'تراخيص';
      case 'financing':
        return 'تمويل';
      default:
        return t;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return core_theme.AC.ok;
      case 'expiring':
        return core_theme.AC.warn;
      case 'expired':
        return core_theme.AC.err;
      default:
        return core_theme.AC.td;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'ساري';
      case 'expiring':
        return 'قرب الانتهاء';
      case 'expired':
        return 'منتهي';
      default:
        return s;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  String _fmtM(double v) {
    if (v >= 1_000_000) return '${(v / 1_000_000).toStringAsFixed(1)}M ر.س';
    if (v >= 1_000) return '${(v / 1_000).toStringAsFixed(0)}K ر.س';
    return '${v.toStringAsFixed(0)} ر.س';
  }
}

class _Contract {
  final String id;
  final String title;
  final String type;
  final String side;
  final String status;
  final String startDate;
  final String endDate;
  final double value;
  final double invoiced;
  final int progress;
  final String paymentTerms;
  const _Contract(this.id, this.title, this.type, this.side, this.status, this.startDate, this.endDate, this.value, this.invoiced, this.progress, this.paymentTerms);
}

class _FilterOpt {
  final String id;
  final String label;
  const _FilterOpt(this.id, this.label);
}
