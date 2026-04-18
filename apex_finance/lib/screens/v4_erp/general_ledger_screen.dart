/// APEX Wave 41 — General Ledger Viewer.
/// Route: /app/erp/finance/gl
///
/// Shows account balances with drill-down to transactions.
library;

import 'package:flutter/material.dart';

class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key});
  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends State<GeneralLedgerScreen> {
  String _selectedAccount = '1100';
  String _period = '2026-04';
  String _query = '';

  final _accounts = const [
    _Account('1100', 'النقدية', 'أصول', 125400, 'debit'),
    _Account('1110', 'البنوك - الراجحي', 'أصول', 485200, 'debit'),
    _Account('1200', 'العملاء', 'أصول', 342100, 'debit'),
    _Account('1300', 'المخزون', 'أصول', 189500, 'debit'),
    _Account('1500', 'الأصول الثابتة', 'أصول', 1250000, 'debit'),
    _Account('2100', 'الموردون', 'خصوم', 156800, 'credit'),
    _Account('2200', 'قروض طويلة الأجل', 'خصوم', 750000, 'credit'),
    _Account('2300', 'ضريبة القيمة المضافة مستحقة', 'خصوم', 48200, 'credit'),
    _Account('3100', 'رأس المال', 'حقوق ملكية', 1000000, 'credit'),
    _Account('3200', 'الأرباح المحتجزة', 'حقوق ملكية', 287300, 'credit'),
    _Account('4100', 'إيرادات المبيعات', 'إيرادات', 1850000, 'credit'),
    _Account('4200', 'إيرادات الخدمات', 'إيرادات', 420000, 'credit'),
    _Account('5100', 'مصروف الرواتب', 'مصروفات', 620000, 'debit'),
    _Account('5200', 'مصروف الإيجار', 'مصروفات', 180000, 'debit'),
    _Account('5300', 'مصروفات عمومية وإدارية', 'مصروفات', 145000, 'debit'),
  ];

  List<_Txn> _txnsFor(String account) {
    return const [
      _Txn('2026-04-28', 'JE-2026-145', 'تحصيل فاتورة SABIC', 52500, 0, 'SABIC-INV-2026-145'),
      _Txn('2026-04-25', 'JE-2026-144', 'صرف مسير الرواتب — مارس', 0, 410000, 'PR-2026-03'),
      _Txn('2026-04-22', 'JE-2026-143', 'تحصيل فاتورة ARAMCO', 128000, 0, 'ARAMCO-INV-099'),
      _Txn('2026-04-20', 'JE-2026-142', 'دفع موردين — NESMA', 0, 87500, 'NESMA-PO-2026-14'),
      _Txn('2026-04-18', 'JE-2026-141', 'تحصيل فاتورة BINLADIN', 95000, 0, 'BNL-INV-2026-78'),
      _Txn('2026-04-15', 'JE-2026-140', 'دفع ZATCA — ضريبة مارس', 0, 48200, 'ZATCA-2026-03'),
      _Txn('2026-04-12', 'JE-2026-139', 'تحصيل فاتورة STC', 67000, 0, 'STC-INV-2026-52'),
      _Txn('2026-04-10', 'JE-2026-138', 'دفع إيجار أبريل', 0, 15000, 'RENT-2026-04'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _accounts
        : _accounts.where((a) =>
            a.code.contains(_query) ||
            a.nameAr.contains(_query) ||
            a.type.contains(_query)).toList();

    final account = _accounts.firstWhere((a) => a.code == _selectedAccount);
    final txns = _txnsFor(_selectedAccount);
    final totalDebit = txns.fold(0.0, (s, t) => s + t.debit);
    final totalCredit = txns.fold(0.0, (s, t) => s + t.credit);

    return Column(
      children: [
        _buildHero(),
        _buildStats(),
        Expanded(
          child: Row(
            children: [
              // Accounts sidebar
              SizedBox(
                width: 340,
                child: Container(
                  margin: const EdgeInsets.only(right: 20, bottom: 20, left: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.grey.shade50,
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_tree, size: 16, color: Color(0xFFD4AF37)),
                                SizedBox(width: 6),
                                Text('الحسابات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'بحث بالرقم أو الاسم',
                                hintStyle: const TextStyle(fontSize: 12),
                                prefixIcon: const Icon(Icons.search, size: 16),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                isDense: true,
                              ),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final a = filtered[i];
                            final isSelected = a.code == _selectedAccount;
                            return InkWell(
                              onTap: () => setState(() => _selectedAccount = a.code),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFD4AF37).withOpacity(0.12) : null,
                                  border: Border(
                                    bottom: BorderSide(color: Colors.black12.withOpacity(0.5)),
                                    right: BorderSide(
                                      color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _typeColor(a.type).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        a.code,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: _typeColor(a.type),
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(a.nameAr,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                              )),
                                          Text(a.type, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    Text(_fmt(a.balance),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: a.nature == 'debit' ? Colors.green : Colors.orange,
                                        )),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Transactions pane
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(left: 20, bottom: 20, right: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        color: Colors.grey.shade50,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _typeColor(account.type).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(account.code,
                                  style: TextStyle(fontWeight: FontWeight.w900, color: _typeColor(account.type))),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(account.nameAr,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                  Text('${account.type} · الطبيعة: ${account.nature == 'debit' ? 'مدين' : 'دائن'}',
                                      style: const TextStyle(fontSize: 11, color: Colors.black54)),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.download, size: 18),
                              tooltip: 'تصدير Excel',
                            ),
                            IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.print, size: 18),
                              tooltip: 'طباعة',
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.grey.shade100,
                        child: const Row(
                          children: [
                            Expanded(child: Text('التاريخ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                            Expanded(child: Text('رقم القيد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                            Expanded(flex: 3, child: Text('البيان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                            Expanded(child: Text('مدين', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.green))),
                            Expanded(child: Text('دائن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.orange))),
                            Expanded(child: Text('المرجع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: txns.length,
                          itemBuilder: (ctx, i) {
                            final t = txns[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(t.date, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                                  Expanded(
                                    child: Text(
                                      t.jeNo,
                                      style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF1E3A8A), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Expanded(flex: 3, child: Text(t.desc, style: const TextStyle(fontSize: 12))),
                                  Expanded(
                                    child: Text(
                                      t.debit > 0 ? _fmt(t.debit) : '—',
                                      style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700, color: t.debit > 0 ? Colors.green : Colors.black26),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      t.credit > 0 ? _fmt(t.credit) : '—',
                                      style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700, color: t.credit > 0 ? Colors.orange : Colors.black26),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(t.ref, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: Colors.grey.shade100,
                        child: Row(
                          children: [
                            const Expanded(flex: 4, child: Text('الإجماليات', style: TextStyle(fontWeight: FontWeight.w900))),
                            Expanded(
                              child: Text(_fmt(totalDebit),
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
                            ),
                            Expanded(
                              child: Text(_fmt(totalCredit),
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.orange)),
                            ),
                            const Expanded(child: SizedBox()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.book, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('دفتر الأستاذ العام',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('تفصيل حركة كل حساب مع التنقل الذكي بين الحسابات',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _period,
              dropdownColor: const Color(0xFF1E3A8A),
              underline: const SizedBox(),
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              iconEnabledColor: Colors.white,
              items: const [
                DropdownMenuItem(value: '2026-04', child: Text('أبريل 2026')),
                DropdownMenuItem(value: '2026-Q1', child: Text('الربع الأول 2026')),
                DropdownMenuItem(value: '2026-YTD', child: Text('منذ بداية العام')),
              ],
              onChanged: (v) => setState(() => _period = v ?? _period),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final assets = _accounts.where((a) => a.type == 'أصول').fold(0.0, (s, a) => s + a.balance);
    final liab = _accounts.where((a) => a.type == 'خصوم').fold(0.0, (s, a) => s + a.balance);
    final equity = _accounts.where((a) => a.type == 'حقوق ملكية').fold(0.0, (s, a) => s + a.balance);
    final rev = _accounts.where((a) => a.type == 'إيرادات').fold(0.0, (s, a) => s + a.balance);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _statCard('الأصول', assets, Colors.green, Icons.trending_up),
          _statCard('الخصوم', liab, Colors.orange, Icons.trending_down),
          _statCard('حقوق الملكية', equity, Colors.blue, Icons.account_balance),
          _statCard('الإيرادات', rev, const Color(0xFFD4AF37), Icons.attach_money),
        ],
      ),
    );
  }

  Widget _statCard(String label, double value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  Text(_fmt(value), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'أصول':
        return Colors.green;
      case 'خصوم':
        return Colors.orange;
      case 'حقوق ملكية':
        return Colors.blue;
      case 'إيرادات':
        return const Color(0xFFD4AF37);
      case 'مصروفات':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _fmt(double v) {
    final s = v.toStringAsFixed(0);
    return s.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

class _Account {
  final String code;
  final String nameAr;
  final String type;
  final double balance;
  final String nature;
  const _Account(this.code, this.nameAr, this.type, this.balance, this.nature);
}

class _Txn {
  final String date;
  final String jeNo;
  final String desc;
  final double debit;
  final double credit;
  final String ref;
  const _Txn(this.date, this.jeNo, this.desc, this.debit, this.credit, this.ref);
}
