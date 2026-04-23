/// APEX Wave 38 — Sales Workflow (Quotes → Invoices → Payments → Statements).
/// Route: /app/erp/finance/sales-workflow
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;
import '../../core/v5/apex_v5_undo_toast.dart';
import '../../core/v5/apex_v5_realtime_tax.dart';

class SalesWorkflowScreen extends StatefulWidget {
  const SalesWorkflowScreen({super.key});
  @override
  State<SalesWorkflowScreen> createState() => _SalesWorkflowScreenState();
}

class _SalesWorkflowScreenState extends State<SalesWorkflowScreen> {
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
              _tabBtn(0, 'عروض الأسعار', Icons.request_quote),
              _tabBtn(1, 'الفواتير', Icons.receipt),
              _tabBtn(2, 'المقبوضات', Icons.payments),
              _tabBtn(3, 'كشوف الحساب', Icons.list_alt),
              _tabBtn(4, 'أعمار الذمم', Icons.hourglass_bottom),
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
        decoration: BoxDecoration(color: active ? core_theme.AC.gold.withValues(alpha: 0.15) : null, borderRadius: BorderRadius.circular(6), border: active ? Border.all(color: core_theme.AC.gold.withValues(alpha: 0.4)) : null),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? core_theme.AC.gold : core_theme.AC.ts),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600, color: active ? core_theme.AC.gold : core_theme.AC.ts)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _quotes();
      case 1: return _invoiceBuilder();
      case 2: return _payments();
      case 3: return _statements();
      case 4: return _aging();
      default: return const SizedBox();
    }
  }

  Widget _quotes() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stats([
            ('عروض نشطة', '12', core_theme.AC.info),
            ('قيمة إجمالية', '458K ر.س', core_theme.AC.gold),
            ('Win Rate', '62%', core_theme.AC.ok),
            ('متوسط الصفقة', '38K ر.س', core_theme.AC.purple),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('عروض الأسعار', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 14), label: Text('عرض جديد'), style: ElevatedButton.styleFrom(backgroundColor: core_theme.AC.gold, foregroundColor: Colors.white)),
            ],
          ),
          const SizedBox(height: 12),
          for (final q in [
            _Quote('QUO-2026-034', 'SABIC', 125000, '2026-04-28', 'مُرسَل', core_theme.AC.info, 85),
            _Quote('QUO-2026-033', 'ABC Trading', 45000, '2026-05-05', 'مُعتمد', core_theme.AC.ok, 100),
            _Quote('QUO-2026-032', 'Marriott', 28000, '2026-04-25', 'تحت المراجعة', core_theme.AC.warn, 60),
            _Quote('QUO-2026-031', 'STC', 18500, '2026-04-20', 'منتهي', const Color(0xFFB91C1C), 0),
          ])
            _quoteRow(q),
        ],
      ),
    );
  }

  Widget _quoteRow(_Quote q) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: q.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Icon(Icons.request_quote, color: q.color, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                Text(q.client, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Text('${q.amount.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace')),
          const SizedBox(width: 12),
          Text('تنتهي: ${q.expires}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(width: 12),
          // Win probability
          SizedBox(width: 80, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('${q.winProb}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: q.color)),
                const SizedBox(width: 4),
                Text('احتمال', style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
              ]),
              const SizedBox(height: 2),
              LinearProgressIndicator(value: q.winProb / 100, backgroundColor: core_theme.AC.tp.withValues(alpha: 0.06), valueColor: AlwaysStoppedAnimation(q.color), minHeight: 3),
            ],
          )),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: q.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
            child: Text(q.status, style: TextStyle(fontSize: 11, color: q.color, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          if (q.status == 'مُعتمد')
            ElevatedButton.icon(
              onPressed: () {
                ApexV5UndoToast.show(context, messageAr: 'تم تحويل ${q.id} إلى فاتورة INV-2026-189', onUndo: () {});
              },
              icon: const Icon(Icons.arrow_back, size: 12),
              label: Text('حوّل لفاتورة', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(backgroundColor: core_theme.AC.ok, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
            ),
        ],
      ),
    );
  }

  Widget _invoiceBuilder() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [core_theme.AC.gold, Color(0xFFE6C200)]), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('منشئ الفاتورة الإلكترونية (زاتكا)', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                      Text('فاتورة B2B متوافقة — TLV QR + XAdES + ZATCA clearance', style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Customer selection
          Text('بيانات العميل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
            child: Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: core_theme.AC.gold, child: Text('S', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SABIC Procurement', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      Text('VAT: 300001234500003 · الرياض · مؤسّسة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                OutlinedButton(onPressed: () {}, child: Text('تغيير')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Items
          Text('البنود', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('الصنف/الوصف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                      Expanded(child: Text('الكمية', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      Expanded(child: Text('السعر', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      Expanded(child: Text('VAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      Expanded(flex: 2, child: Text('الإجمالي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                    ],
                  ),
                ),
                _itemLine('استشارات ضريبية — Q1 2026', 1, 30000, 15, 34500),
                _itemLine('تدقيق ZATCA compliance', 1, 15000, 15, 17250),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.add, size: 12), label: Text('بند', style: TextStyle(fontSize: 11))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Live tax + totals
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ApexV5RealtimeTax(
                initialAmount: 45000,
                initialCountry: 'KSA',
                initialItemType: 'service',
                initialCustomerType: 'business',
              )),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
                  child: Column(
                    children: [
                      _totalRow('المجموع الفرعي', '45,000.00', core_theme.AC.tp),
                      _totalRow('VAT 15%', '6,750.00', core_theme.AC.ts),
                      const Divider(),
                      _totalRow('الإجمالي', '51,750.00', core_theme.AC.ok, bold: true),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ApexV5UndoToast.show(context, messageAr: 'تم إصدار الفاتورة INV-2026-189 إلى ZATCA · 51,750 ر.س', onUndo: () {});
                          },
                          icon: const Icon(Icons.send, size: 16),
                          label: Text('أصدر + أرسل إلى زاتكا'),
                          style: ElevatedButton.styleFrom(backgroundColor: core_theme.AC.gold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.save, size: 14), label: Text('حفظ كمسوّدة'))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _itemLine(String item, int qty, double price, int vat, double total) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.04)))),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(item, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Expanded(child: Text(price.toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Expanded(child: Text('$vat%', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
          Expanded(flex: 2, child: Text(total.toStringAsFixed(0), textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          const Spacer(),
          Text('$value ر.س', style: TextStyle(fontSize: bold ? 16 : 13, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _payments() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stats([
            ('مقبوض اليوم', '87K ر.س', core_theme.AC.ok),
            ('هذا الشهر', '1.8M ر.س', core_theme.AC.gold),
            ('متأخرة', '420K ر.س', const Color(0xFFB91C1C)),
            ('DSO', '42 يوم', core_theme.AC.info),
          ]),
          const SizedBox(height: 16),
          Text('المقبوضات الأخيرة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final p in [
            _Payment('REC-245', 'SABIC', 52500, 'بطاقة مدى', '2026-04-18', 'INV-2026-145'),
            _Payment('REC-244', 'Al Rajhi', 28000, 'تحويل بنكي', '2026-04-17', 'INV-2026-142'),
            _Payment('REC-243', 'Marriott', 15000, 'STC Pay', '2026-04-16', 'INV-2026-138'),
            _Payment('REC-242', 'ABC Trading', 8500, 'شيك', '2026-04-15', 'INV-2026-135'),
          ])
            _payRow(p),
        ],
      ),
    );
  }

  Widget _payRow(_Payment p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
      child: Row(
        children: [
          Icon(Icons.payments, color: core_theme.AC.ok, size: 20),
          const SizedBox(width: 10),
          Text(p.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
          const SizedBox(width: 12),
          Expanded(child: Text(p.customer, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: core_theme.AC.tp.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(3)), child: Text(p.method, style: const TextStyle(fontSize: 10))),
          const SizedBox(width: 12),
          Text(p.invoice, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
          const SizedBox(width: 12),
          Text(p.date, style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(width: 12),
          Text('${p.amount.toStringAsFixed(0)} ر.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, fontFamily: 'monospace', color: core_theme.AC.ok)),
        ],
      ),
    );
  }

  Widget _statements() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('كشف حساب — SABIC · Q1 2026', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
            child: Column(
              children: [
                _stmntHeader(),
                _stmntRow('2026-01-05', 'INV-2026-087', 'فاتورة', 34500, 0, 34500),
                _stmntRow('2026-01-20', 'REC-221', 'مقبوضات', 0, 34500, 0),
                _stmntRow('2026-02-15', 'INV-2026-112', 'فاتورة', 51750, 0, 51750),
                _stmntRow('2026-02-28', 'REC-228', 'مقبوضات', 0, 51750, 0),
                _stmntRow('2026-03-18', 'INV-2026-128', 'فاتورة', 52500, 0, 52500),
                _stmntRow('2026-04-18', 'REC-245', 'مقبوضات', 0, 52500, 0),
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: core_theme.AC.ok.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Text('الرصيد النهائي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      Spacer(),
                      Text('0.00 ر.س ✓ مسدَّد كلياً', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: core_theme.AC.ok)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stmntHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.08)))),
      child: const Row(
        children: [
          Expanded(child: Text('التاريخ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
          Expanded(child: Text('المرجع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
          Expanded(child: Text('النوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
          Expanded(child: Text('مدين', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
          Expanded(child: Text('دائن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
          Expanded(child: Text('الرصيد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _stmntRow(String date, String ref, String type, double dr, double cr, double bal) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.04)))),
      child: Row(
        children: [
          Expanded(child: Text(date, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(ref, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts))),
          Expanded(child: Text(type, style: const TextStyle(fontSize: 11))),
          Expanded(child: Text(dr > 0 ? dr.toStringAsFixed(0) : '—', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'), textAlign: TextAlign.end)),
          Expanded(child: Text(cr > 0 ? cr.toStringAsFixed(0) : '—', style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: cr > 0 ? core_theme.AC.ok : null), textAlign: TextAlign.end)),
          Expanded(child: Text(bal.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w700), textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _aging() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stats([
            ('إجمالي المستحق', '1.24M ر.س', core_theme.AC.gold),
            ('1-30 يوم', '680K ر.س', core_theme.AC.ok),
            ('31-60 يوم', '285K ر.س', core_theme.AC.warn),
            ('> 90 يوم', '275K ر.س', const Color(0xFFB91C1C)),
          ]),
          const SizedBox(height: 16),
          Text('أعمار الذمم المدينة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08))),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('العميل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
                      Expanded(child: Text('<30', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      Expanded(child: Text('31-60', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      Expanded(child: Text('61-90', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      Expanded(child: Text('>90', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.center)),
                      Expanded(child: Text('الإجمالي', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800), textAlign: TextAlign.end)),
                    ],
                  ),
                ),
                _agingRow('SABIC', 125, 0, 0, 0),
                _agingRow('ABC Trading', 45, 28, 0, 32),
                _agingRow('Marriott', 87, 52, 38, 0),
                _agingRow('Al Rajhi Bank', 210, 85, 0, 58),
                _agingRow('STC', 18, 12, 8, 15),
                _agingRow('ARAMCO', 195, 108, 65, 170),
                const Divider(),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: core_theme.AC.ok.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('الإجمالي', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900))),
                      Expanded(child: Text('680K', style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w900, color: core_theme.AC.ok), textAlign: TextAlign.center)),
                      Expanded(child: Text('285K', style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w900, color: core_theme.AC.warn), textAlign: TextAlign.center)),
                      Expanded(child: Text('111K', style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w900), textAlign: TextAlign.center)),
                      Expanded(child: Text('275K', style: TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w900, color: Color(0xFFB91C1C)), textAlign: TextAlign.center)),
                      Expanded(child: Text('1.24M', style: TextStyle(fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.w900, color: core_theme.AC.gold), textAlign: TextAlign.end)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _agingRow(String name, double b1, double b2, double b3, double b4) {
    final total = b1 + b2 + b3 + b4;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.04)))),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text(b1 > 0 ? '${b1.toStringAsFixed(0)}K' : '—', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(b2 > 0 ? '${b2.toStringAsFixed(0)}K' : '—', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: b2 > 0 ? core_theme.AC.warn : null))),
          Expanded(child: Text(b3 > 0 ? '${b3.toStringAsFixed(0)}K' : '—', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
          Expanded(child: Text(b4 > 0 ? '${b4.toStringAsFixed(0)}K' : '—', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: b4 > 0 ? const Color(0xFFB91C1C) : null, fontWeight: b4 > 0 ? FontWeight.w800 : null))),
          Expanded(child: Text('${total.toStringAsFixed(0)}K', textAlign: TextAlign.end, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _stats(List<(String, String, Color)> stats) {
    return Row(
      children: [
        for (final s in stats) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: s.$3.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: s.$3.withValues(alpha: 0.2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.$2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: s.$3)),
                  Text(s.$1, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
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

class _Quote {
  final String id, client, expires, status;
  final double amount;
  final Color color;
  final int winProb;
  _Quote(this.id, this.client, this.amount, this.expires, this.status, this.color, this.winProb);
}

class _Payment {
  final String id, customer, method, date, invoice;
  final double amount;
  _Payment(this.id, this.customer, this.amount, this.method, this.date, this.invoice);
}
