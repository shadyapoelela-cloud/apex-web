/// APEX Wave 27 — Marketplace Billing & Escrow + Payouts + Ratings.
///
/// Route: /app/marketplace/client/billing + /app/marketplace/provider/payouts
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/apex_v5_undo_toast.dart';

class MarketplaceBillingScreen extends StatefulWidget {
  const MarketplaceBillingScreen({super.key});

  @override
  State<MarketplaceBillingScreen> createState() => _MarketplaceBillingScreenState();
}

class _MarketplaceBillingScreenState extends State<MarketplaceBillingScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.08)))),
      child: Row(
        children: [
          _tabBtn(0, 'الفواتير', Icons.receipt),
          _tabBtn(1, 'الضمان (Escrow)', Icons.lock),
          _tabBtn(2, 'المدفوعات', Icons.payments),
          _tabBtn(3, 'النزاعات', Icons.gavel),
          _tabBtn(4, 'كشوف الحساب', Icons.list_alt),
        ],
      ),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFE65100).withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFFE65100).withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFFE65100) : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? const Color(0xFFE65100) : core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _buildInvoices();
      case 1: return _buildEscrow();
      case 2: return _buildPayments();
      case 3: return _buildDisputes();
      case 4: return _buildStatements();
      default: return const SizedBox();
    }
  }

  Widget _buildInvoices() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('فواتير نشطة', '8', Icons.receipt, core_theme.AC.info),
            _Stat('مدفوعة', '147K ر.س', Icons.check_circle, core_theme.AC.ok),
            _Stat('في الضمان', '85K ر.س', Icons.lock, core_theme.AC.warn),
            _Stat('هذا الربع', '285K ر.س', Icons.trending_up, core_theme.AC.gold),
          ]),
          const SizedBox(height: 16),
          Text('فواتير الخدمات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final inv in [
            _MInvoice('INV-MK-045', 'د. عبدالله السالم', 'مراجعة SABIC 2026', 45000, 'في الضمان', core_theme.AC.warn),
            _MInvoice('INV-MK-044', 'شركة الدليل', 'استشارة ضريبية', 12500, 'مدفوعة', core_theme.AC.ok),
            _MInvoice('INV-MK-043', 'مكتب الثقة', 'مراجعة ABC Trading', 28000, 'في الضمان', core_theme.AC.warn),
            _MInvoice('INV-MK-042', 'د. سارة الحارثي', 'دراسة جدوى', 65000, 'مدفوعة', core_theme.AC.ok),
            _MInvoice('INV-MK-041', 'مكتب النخبة', 'تقييم أصول', 18500, 'متأخرة', const Color(0xFFB91C1C)),
          ])
            _invoiceRow(inv),
        ],
      ),
    );
  }

  Widget _invoiceRow(_MInvoice inv) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
      child: Row(
        children: [
          const Icon(Icons.receipt, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inv.id, style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                Text(inv.provider, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(inv.service, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Text('${inv.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: inv.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(inv.status, style: TextStyle(fontSize: 11, color: inv.color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEscrow() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFE65100), core_theme.AC.purple]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, color: Colors.white, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الضمان (Escrow)', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('المبالغ محتفظة بها لحين تسليم الخدمة — يضمن الحقوق لكلا الطرفين', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _statsRow([
            _Stat('في الضمان الآن', '85K ر.س', Icons.lock, core_theme.AC.warn),
            _Stat('محرَّر هذا الشهر', '127K ر.س', Icons.lock_open, core_theme.AC.ok),
            _Stat('نزاعات نشطة', '1', Icons.warning, const Color(0xFFB91C1C)),
            _Stat('رسوم المنصّة', '8.5K ر.س', Icons.percent, core_theme.AC.info),
          ]),
          const SizedBox(height: 16),
          Text('معاملات الضمان', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final e in [
            _Escrow('ESC-045', 'د. عبدالله السالم', 'مراجعة SABIC 2026', 45000, 2, 3, 'في الضمان'),
            _Escrow('ESC-043', 'مكتب الثقة', 'مراجعة ABC Trading', 28000, 1, 2, 'في الضمان'),
            _Escrow('ESC-040', 'شركة الدليل', 'تقييم فرص', 12000, 3, 3, 'للتحرير'),
          ])
            _escrowCard(e),
        ],
      ),
    );
  }

  Widget _escrowCard(_Escrow e) {
    final ready = e.currentMilestone >= e.totalMilestones;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: (ready ? core_theme.AC.ok : core_theme.AC.warn).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Icon(ready ? Icons.lock_open : Icons.lock, color: ready ? core_theme.AC.ok : core_theme.AC.warn, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.id, style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                    Text(e.provider, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(e.service, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
                  ],
                ),
              ),
              Text('${e.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: Color(0xFFE65100))),
            ],
          ),
          const SizedBox(height: 12),
          // Milestones progress
          Row(
            children: List.generate(e.totalMilestones, (i) {
              final done = i < e.currentMilestone;
              return Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: done ? core_theme.AC.ok : core_theme.AC.tp.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        done ? '✓' : '${i + 1}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: done ? Colors.white : core_theme.AC.ts),
                      ),
                    ),
                    if (i < e.totalMilestones - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: done ? core_theme.AC.ok : core_theme.AC.tp.withValues(alpha: 0.08),
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Text(
            'معلم ${e.currentMilestone} من ${e.totalMilestones}',
            style: TextStyle(fontSize: 11, color: core_theme.AC.ts),
          ),
          if (ready) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ApexV5UndoToast.show(
                        context,
                        messageAr: 'تم تحرير ${e.amount.toStringAsFixed(0)} ر.س للمزوّد ${e.provider}',
                        onUndo: () {},
                      );
                    },
                    icon: const Icon(Icons.lock_open, size: 14),
                    label: Text('حرّر الدفعة'),
                    style: ElevatedButton.styleFrom(backgroundColor: core_theme.AC.ok, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.warning, size: 14),
                  label: Text('افتح نزاع'),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB91C1C), side: const BorderSide(color: Color(0xFFB91C1C))),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPayments() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('طرق الدفع المدعومة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final cols = constraints.maxWidth > 800 ? 3 : constraints.maxWidth > 500 ? 2 : 1;
              return GridView.count(
                shrinkWrap: true,
                crossAxisCount: cols,
                childAspectRatio: 2.5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _payMethod('مدى (Mada)', Icons.credit_card, core_theme.AC.ok, '2.0%', active: true),
                  _payMethod('Apple Pay', Icons.apple, core_theme.AC.tp, '2.0%', active: true),
                  _payMethod('STC Pay', Icons.phone_android, core_theme.AC.purple, '1.5%', active: true),
                  _payMethod('Tabby (BNPL)', Icons.event_note, core_theme.AC.info, '5.0%', active: false),
                  _payMethod('Visa / Mastercard', Icons.credit_card, const Color(0xFF1565C0), '2.9%', active: true),
                  _payMethod('Bank Transfer', Icons.account_balance, core_theme.AC.gold, '0%', active: true),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _payMethod(String name, IconData icon, Color color, String fee, {required bool active}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? color.withValues(alpha: 0.4) : core_theme.AC.tp.withValues(alpha: 0.08), width: active ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text('رسوم: $fee', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
              ],
            ),
          ),
          Switch(value: active, onChanged: (_) {}, activeColor: color),
        ],
      ),
    );
  }

  Widget _buildDisputes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('النزاعات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFB91C1C).withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFB91C1C).withValues(alpha: 0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning, color: Color(0xFFB91C1C), size: 22),
                    SizedBox(width: 10),
                    Text('نزاع #DSP-012', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFB91C1C))),
                    Spacer(),
                    Text('قيد الوساطة', style: TextStyle(fontSize: 11, color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('العميل: شركة XYZ للتجارة', style: TextStyle(fontSize: 13)),
                Text('المزوّد: مكتب النخبة للاستشارات', style: TextStyle(fontSize: 13)),
                Text('المبلغ المتنازع: 18,500 ر.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'السبب: العميل يدّعي أن التسليم ناقص — 2 تقارير فقط من أصل 3 متفق عليها.',
                  style: TextStyle(fontSize: 12, color: core_theme.AC.tp),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(onPressed: () {}, icon: const Icon(Icons.visibility, size: 14), label: Text('عرض الأدلّة')),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.auto_awesome, size: 14),
                      label: Text('اطلب وساطة APEX'),
                      style: ElevatedButton.styleFrom(backgroundColor: core_theme.AC.purple, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatements() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('كشوف الحساب — الضرائب والرسوم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
            child: Column(
              children: [
                _statementRow('إجمالي المعاملات', '285,000 ر.س'),
                _statementRow('رسوم المنصّة (3%)', '-8,550 ر.س'),
                _statementRow('VAT على الرسوم (15%)', '-1,283 ر.س'),
                _statementRow('رسوم معالجة الدفع (2.5%)', '-7,125 ر.س'),
                const Divider(),
                _statementRow('صافي المستلم', '268,042 ر.س', bold: true, color: core_theme.AC.ok),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.download, size: 14), label: Text('تحميل PDF')),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.description, size: 14),
                label: Text('شهادة ضريبية'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statementRow(String label, String value, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _statsRow(List<_Stat> stats) {
    return Row(
      children: [
        for (final s in stats) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: s.color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: s.color.withValues(alpha: 0.2))),
              child: Row(
                children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: s.color)),
                        Text(s.label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (s != stats.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _Stat {
  final String label, value;
  final IconData icon;
  final Color color;
  _Stat(this.label, this.value, this.icon, this.color);
}

class _MInvoice {
  final String id, provider, service, status;
  final double amount;
  final Color color;
  _MInvoice(this.id, this.provider, this.service, this.amount, this.status, this.color);
}

class _Escrow {
  final String id, provider, service, status;
  final double amount;
  final int currentMilestone, totalMilestones;
  _Escrow(this.id, this.provider, this.service, this.amount, this.currentMilestone, this.totalMilestones, this.status);
}

/// Wave 28 — Eligibility Check (Nomu/Tadawul/SME classifier).
class EligibilityCheckScreen extends StatefulWidget {
  const EligibilityCheckScreen({super.key});

  @override
  State<EligibilityCheckScreen> createState() => _EligibilityCheckScreenState();
}

class _EligibilityCheckScreenState extends State<EligibilityCheckScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.08)))),
          child: Row(
            children: [
              _tabBtn(0, 'تصنيف SME', Icons.business),
              _tabBtn(1, 'Nomu / Tadawul', Icons.trending_up),
              _tabBtn(2, 'قرض كفالة', Icons.account_balance),
              _tabBtn(3, 'المناقصات', Icons.gavel),
              _tabBtn(4, 'المنح', Icons.card_giftcard),
            ],
          ),
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2E7D5B).withValues(alpha: 0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFF2E7D5B).withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF2E7D5B) : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? const Color(0xFF2E7D5B) : core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _sme();
      case 1: return _tadawul();
      case 2: return _kafalah();
      case 3: return _tenders();
      case 4: return _grants();
      default: return const SizedBox();
    }
  }

  Widget _sme() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2E7D5B), core_theme.AC.ok]), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Container(width: 80, height: 80, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Text('M', style: TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: Color(0xFF2E7D5B)))),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('تصنيف منشأة متوسطة', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('العمالة: 52 — الإيرادات: 15.5M ر.س', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('معايير منشآت (الهيئة العامة للمنشآت الصغيرة والمتوسطة)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final c in [
            _Criteria('متناهية الصغر', '1-5 موظفين', 'إيرادات ≤ 3M ر.س', false),
            _Criteria('صغيرة', '6-49 موظف', 'إيرادات 3-40M ر.س', false),
            _Criteria('متوسطة', '50-249 موظف', 'إيرادات 40-200M ر.س', true),
            _Criteria('كبيرة', '250+ موظف', 'إيرادات > 200M ر.س', false),
          ])
            _criteriaRow(c),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.ok.withValues(alpha: 0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle, color: core_theme.AC.ok, size: 20),
                    SizedBox(width: 8),
                    Text('المزايا المتاحة لك', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.ok)),
                  ],
                ),
                SizedBox(height: 8),
                Text('✓ إعفاء من الرسوم الحكومية 5 سنوات', style: TextStyle(fontSize: 12)),
                Text('✓ قرض كفالة حتى 15M ر.س', style: TextStyle(fontSize: 12)),
                Text('✓ أولوية في المناقصات الحكومية (30% تخصيص)', style: TextStyle(fontSize: 12)),
                Text('✓ منح رأس مال من صندوق منشآت', style: TextStyle(fontSize: 12)),
                Text('✓ دعم التدريب والتوظيف', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _criteriaRow(_Criteria c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.active ? core_theme.AC.ok.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.active ? core_theme.AC.ok : core_theme.AC.tp.withValues(alpha: 0.08), width: c.active ? 2 : 1),
      ),
      child: Row(
        children: [
          Icon(c.active ? Icons.check_circle : Icons.circle_outlined, color: c.active ? core_theme.AC.ok : core_theme.AC.td, size: 20),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(c.category, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.active ? core_theme.AC.ok : core_theme.AC.tp)),
          ),
          Expanded(child: Text(c.employees, style: const TextStyle(fontSize: 11))),
          Expanded(child: Text(c.revenue, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _tadawul() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1565C0), core_theme.AC.purple]), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(Icons.trending_up, color: Colors.white, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الإدراج في السوق المالية', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('Nomu (للشركات الناشئة) · Tadawul (السوق الرئيسي)', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _marketCard('Nomu — السوق الموازي', 'للشركات الناشئة والمتوسطة', '10M ر.س رأس مال', '3 سنوات عمر', 'مؤهّل ✓', core_theme.AC.ok, eligible: true)),
              const SizedBox(width: 12),
              Expanded(child: _marketCard('Tadawul — السوق الرئيسي', 'للشركات الكبيرة المستقرّة', '300M ر.س رأس مال', '5 سنوات عمر', 'غير مؤهّل', const Color(0xFFB91C1C), eligible: false)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: core_theme.AC.ok.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.ok.withValues(alpha: 0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: core_theme.AC.ok, size: 20),
                    SizedBox(width: 8),
                    Text('التوصية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: core_theme.AC.ok)),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'شركتك مؤهّلة للإدراج في Nomu. الخطوات التالية:\n'
                  '1. تعيين مستشار مالي معتمد\n'
                  '2. إعداد الهيكل القانوني (تحويل لشركة مساهمة مغلقة → عامة)\n'
                  '3. إعداد نشرة إصدار\n'
                  '4. مراجعة SOCPA لآخر 3 سنوات (لدينا APEX Audit!)\n'
                  '5. تقديم الطلب لهيئة السوق المالية',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _marketCard(String name, String desc, String capital, String age, String status, Color color, {required bool eligible}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.4), width: eligible ? 2 : 1)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
                child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 8),
          _reqRow('رأس المال', capital, eligible),
          _reqRow('عمر الشركة', age, eligible),
        ],
      ),
    );
  }

  Widget _reqRow(String label, String value, bool met) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(met ? Icons.check_circle : Icons.cancel, size: 12, color: met ? core_theme.AC.ok : const Color(0xFFB91C1C)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _kafalah() {
    return _comingSoon('قرض كفالة', 'برنامج كفالة لدعم المنشآت — حتى 15M ر.س بضمانات من 50%-80%');
  }

  Widget _tenders() {
    return _comingSoon('المناقصات الحكومية', 'بوابة اعتماد · 30% تخصيص للمنشآت · تصنيف ثلاثي');
  }

  Widget _grants() {
    return _comingSoon('المنح والدعم', 'صندوق منشآت · هدف · تمكين · برامج تمويل متنوّعة');
  }

  Widget _comingSoon(String title, String desc) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 56, color: core_theme.AC.td),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(fontSize: 12, color: core_theme.AC.ts), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: core_theme.AC.warn.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text('Wave 29+ — قريباً', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
          ),
        ],
      ),
    );
  }
}

class _Criteria {
  final String category, employees, revenue;
  final bool active;
  _Criteria(this.category, this.employees, this.revenue, this.active);
}
