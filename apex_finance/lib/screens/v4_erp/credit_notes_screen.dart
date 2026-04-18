import 'package:flutter/material.dart';

/// Wave 106 — Credit Notes & Refunds
/// Credit note lifecycle, refund processing, reason analysis
class CreditNotesScreen extends StatefulWidget {
  const CreditNotesScreen({super.key});

  @override
  State<CreditNotesScreen> createState() => _CreditNotesScreenState();
}

class _CreditNotesScreenState extends State<CreditNotesScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        body: SafeArea(
          child: Column(
            children: [
              _buildHero(),
              _buildKpis(),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tc,
                  labelColor: const Color(0xFF4A148C),
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: const Color(0xFFD4AF37),
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'إشعارات الدائن'),
                    Tab(text: 'المبالغ المستردة'),
                    Tab(text: 'التحليل بالأسباب'),
                    Tab(text: 'التحليلات'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tc,
                  children: [
                    _buildNotesTab(),
                    _buildRefundsTab(),
                    _buildReasonsTab(),
                    _buildAnalyticsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF4A148C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_return, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إشعارات الدائن والمبالغ المستردة',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'دورة حياة إشعارات الدائن ومعالجة المبالغ المستردة مع ZATCA',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إصدار إشعار'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    final total = _notes.length;
    final totalAmount = _notes.fold<double>(0, (s, n) => s + n.amount);
    final approved = _notes.where((n) => n.status.contains('معتمد')).length;
    final pending = _notes.where((n) => n.status.contains('معلق')).length;

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: _kpi('الإجمالي', '$total', Icons.receipt, const Color(0xFF1A237E))),
          Expanded(child: _kpi('القيمة', _fmtM(totalAmount), Icons.payments, const Color(0xFFD4AF37))),
          Expanded(child: _kpi('معتمدة', '$approved', Icons.check_circle, const Color(0xFF2E7D32))),
          Expanded(child: _kpi('معلقة', '$pending', Icons.hourglass_bottom, const Color(0xFFE65100))),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _notes.length,
      itemBuilder: (context, i) {
        final n = _notes[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _statusColor(n.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.assignment_return, color: _statusColor(n.status), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(n.customer, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          Text('ضد الفاتورة: ${n.invoiceRef}',
                              style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_fmt(n.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828), fontSize: 15)),
                        Text(n.date, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(n.status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(n.status,
                          style: TextStyle(color: _statusColor(n.status), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('السبب: ${n.reason}',
                          style: const TextStyle(color: Color(0xFF1A237E), fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    if (n.zatcaCompliant)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified, color: Color(0xFF2E7D32), size: 12),
                            SizedBox(width: 3),
                            Text('ZATCA',
                                style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRefundsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _refunds.length,
      itemBuilder: (context, i) {
        final r = _refunds[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _refundStatus(r.status).withValues(alpha: 0.15),
              child: Icon(_refundIcon(r.method), color: _refundStatus(r.status)),
            ),
            title: Text(r.id, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.customer, style: const TextStyle(fontSize: 12)),
                Text('${r.method} • ${r.date}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt(r.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _refundStatus(r.status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(r.status,
                      style: TextStyle(color: _refundStatus(r.status), fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReasonsTab() {
    final reasons = <String, (int, double)>{};
    for (final n in _notes) {
      final current = reasons[n.reason] ?? (0, 0.0);
      reasons[n.reason] = (current.$1 + 1, current.$2 + n.amount);
    }
    final entries = reasons.entries.toList()..sort((a, b) => b.value.$2.compareTo(a.value.$2));
    final maxAmount = entries.first.value.$2;

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final ratio = e.value.$2 / maxAmount;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(e.key,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    Text('${e.value.$1} إشعار',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(width: 10),
                    Text(_fmt(e.value.$2),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC62828))),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 8,
                    backgroundColor: Colors.black12,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFC62828)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _insight('💳 معدل الاسترداد', '2.8% من إجمالي المبيعات (المعيار الصناعي 3.5%)', const Color(0xFF2E7D32)),
        _insight('⏱️ متوسط المعالجة', '3.2 يوم من الطلب إلى الاسترداد', const Color(0xFF1A237E)),
        _insight('🎯 الأسباب الرئيسية',
            'أخطاء الفوترة 38% • إرجاع منتج 24% • خدمة ناقصة 18% • أخرى 20%', const Color(0xFF4A148C)),
        _insight('✅ الامتثال ZATCA', '100% من الإشعارات مرسلة لبوابة فاتورة', const Color(0xFF2E7D32)),
        _insight('⚠️ تنبيه', '5 إشعارات تحتاج معالجة خلال 48 ساعة', const Color(0xFFE65100)),
        _insight('📊 الاتجاه', 'انخفاض 12% مقارنة بالربع السابق', const Color(0xFF2E7D32)),
      ],
    );
  }

  Widget _insight(String title, String text, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 6),
            Text(text, style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) {
    if (s.contains('معتمد')) return const Color(0xFF2E7D32);
    if (s.contains('معلق')) return const Color(0xFFE65100);
    if (s.contains('مرفوض')) return const Color(0xFFC62828);
    if (s.contains('مسودة')) return Colors.black54;
    return const Color(0xFF1A237E);
  }

  Color _refundStatus(String s) {
    if (s.contains('مكتمل')) return const Color(0xFF2E7D32);
    if (s.contains('معالجة')) return const Color(0xFFE65100);
    if (s.contains('فشل')) return const Color(0xFFC62828);
    return Colors.black54;
  }

  IconData _refundIcon(String m) {
    if (m.contains('بنكي')) return Icons.account_balance;
    if (m.contains('بطاقة')) return Icons.credit_card;
    if (m.contains('رصيد')) return Icons.wallet;
    if (m.contains('مدى')) return Icons.payment;
    return Icons.payments;
  }

  String _fmt(double v) => '${v.toStringAsFixed(0)} ر.س';
  String _fmtM(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  static const List<_CreditNote> _notes = [
    _CreditNote('CN-2026-0001', 'شركة الاتصالات السعودية', 'INV-2026-0123', 45_000, 'خطأ في الفوترة',
        '2026-04-15', 'معتمد', true),
    _CreditNote('CN-2026-0002', 'بنك الراجحي', 'INV-2026-0098', 28_500, 'إرجاع جزئي',
        '2026-04-14', 'معلق للمراجعة', false),
    _CreditNote('CN-2026-0003', 'أرامكو السعودية', 'INV-2026-0145', 112_000, 'خصم تفاوضي',
        '2026-04-12', 'معتمد', true),
    _CreditNote('CN-2026-0004', 'سابك', 'INV-2026-0156', 18_700, 'خدمة ناقصة',
        '2026-04-10', 'معتمد', true),
    _CreditNote('CN-2026-0005', 'stc', 'INV-2026-0167', 6_400, 'خطأ في الفوترة',
        '2026-04-09', 'مسودة', false),
    _CreditNote('CN-2026-0006', 'مجموعة سامبا', 'INV-2026-0178', 34_200, 'إلغاء طلب',
        '2026-04-07', 'مرفوض', false),
    _CreditNote('CN-2026-0007', 'شركة المراعي', 'INV-2026-0189', 8_900, 'إرجاع منتج',
        '2026-04-05', 'معتمد', true),
    _CreditNote('CN-2026-0008', 'معرض الجزيرة', 'INV-2026-0201', 15_300, 'خصم تفاوضي',
        '2026-04-03', 'معتمد', true),
    _CreditNote('CN-2026-0009', 'مستشفى الحبيب', 'INV-2026-0212', 22_800, 'خطأ في الفوترة',
        '2026-04-01', 'معتمد', true),
    _CreditNote('CN-2026-0010', 'فنادق الفيصلية', 'INV-2026-0225', 5_600, 'إرجاع منتج',
        '2026-03-28', 'معلق للمراجعة', false),
  ];

  static const List<_Refund> _refunds = [
    _Refund('REF-2026-0001', 'شركة الاتصالات السعودية', 45_000, 'تحويل بنكي', '2026-04-16', 'مكتمل'),
    _Refund('REF-2026-0002', 'أرامكو السعودية', 112_000, 'تحويل بنكي', '2026-04-13', 'مكتمل'),
    _Refund('REF-2026-0003', 'سابك', 18_700, 'رصيد عميل', '2026-04-11', 'مكتمل'),
    _Refund('REF-2026-0004', 'شركة المراعي', 8_900, 'بطاقة ائتمان', '2026-04-06', 'مكتمل'),
    _Refund('REF-2026-0005', 'معرض الجزيرة', 15_300, 'تحويل مدى', '2026-04-04', 'معالجة'),
    _Refund('REF-2026-0006', 'مستشفى الحبيب', 22_800, 'تحويل بنكي', '2026-04-02', 'مكتمل'),
    _Refund('REF-2026-0007', 'بنك الراجحي', 28_500, 'رصيد عميل', '-', 'معالجة'),
  ];
}

class _CreditNote {
  final String id;
  final String customer;
  final String invoiceRef;
  final double amount;
  final String reason;
  final String date;
  final String status;
  final bool zatcaCompliant;
  const _CreditNote(this.id, this.customer, this.invoiceRef, this.amount, this.reason, this.date,
      this.status, this.zatcaCompliant);
}

class _Refund {
  final String id;
  final String customer;
  final double amount;
  final String method;
  final String date;
  final String status;
  const _Refund(this.id, this.customer, this.amount, this.method, this.date, this.status);
}
