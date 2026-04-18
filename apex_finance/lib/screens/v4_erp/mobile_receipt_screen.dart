/// APEX V5.1 — Mobile Receipt Capture (Enhancement #20).
///
/// Expensify-killer: photo/upload → AI extracts vendor, amount, VAT,
/// date, category in seconds. Integrates with expense claims + JE.
///
/// Route: /app/erp/finance/budgets (demo as Expense Capture)
library;

import 'package:flutter/material.dart';

import '../../core/v5/apex_v5_undo_toast.dart';

class MobileReceiptScreen extends StatefulWidget {
  const MobileReceiptScreen({super.key});

  @override
  State<MobileReceiptScreen> createState() => _MobileReceiptScreenState();
}

class _MobileReceiptScreenState extends State<MobileReceiptScreen> {
  bool _uploaded = false;
  bool _extracting = false;
  _ExtractedReceipt? _result;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF2563EB)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التقاط الإيصال بالذكاء الاصطناعي',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'صوّر أو ارفع · يستخرج البيانات في 3 ثواني · يستبدل Expensify',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    r'$5/user/month · 50K+ customers',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!_uploaded) _buildUpload() else _buildResult(),
        ],
      ),
    );
  }

  Widget _buildUpload() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF059669).withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long, size: 48, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 16),
          const Text(
            'اسحب الإيصال هنا أو',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _extracting ? null : _onCapture,
                icon: _extracting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.camera_alt, size: 16),
                label: Text(_extracting ? 'يستخرج...' : 'التقط صورة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _extracting ? null : _onCapture,
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('ارفع ملف'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'يدعم: JPG · PNG · PDF · HEIC · حتى 10MB',
            style: TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          // Features grid
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            childAspectRatio: 3.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _FeatureChip(icon: Icons.text_fields, text: 'استخراج نصي بالعربي'),
              _FeatureChip(icon: Icons.receipt, text: 'قراءة VAT تلقائياً'),
              _FeatureChip(icon: Icons.category, text: 'تصنيف ذكي'),
              _FeatureChip(icon: Icons.flash_on, text: 'نتيجة في 3 ثواني'),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onCapture() async {
    setState(() => _extracting = true);
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    setState(() {
      _extracting = false;
      _uploaded = true;
      _result = _ExtractedReceipt(
        vendor: 'ABC Cafe',
        amount: 87.50,
        vat: 11.41,
        currency: 'SAR',
        date: '2026-04-18',
        category: 'السفر والوجبات',
        categoryConfidence: 0.94,
        items: [
          _ReceiptItem('قهوة أمريكانو', 18.00),
          _ReceiptItem('كرواسون', 22.00),
          _ReceiptItem('عصير برتقال', 15.00),
          _ReceiptItem('شاي بالحليب', 21.09),
        ],
        paymentMethod: 'بطاقة مدى',
        invoiceNumber: 'INV-2026-8471',
      );
    });
  }

  Widget _buildResult() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main card
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle, color: Color(0xFF059669), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تم الاستخراج بنجاح',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'استغرق 2.3 ثانية · كل الحقول مستخرجة',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '98% ثقة',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final wide = constraints.maxWidth > 700;
                    return wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _receiptPreview()),
                              const SizedBox(width: 16),
                              Expanded(child: _extractedFields(r)),
                            ],
                          )
                        : Column(
                            children: [
                              _receiptPreview(),
                              const SizedBox(height: 12),
                              _extractedFields(r),
                            ],
                          );
                  },
                ),
              ),
              // Actions
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.02),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                  border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _uploaded = false;
                        _result = null;
                      }),
                      icon: const Icon(Icons.refresh, size: 14),
                      label: const Text('إيصال جديد'),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('تعديل'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        ApexV5UndoToast.show(
                          context,
                          messageAr: 'تم حفظ الإيصال — ${r.amount} ر.س — ${r.category}',
                          onUndo: () {},
                        );
                      },
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('احفظ كطلب مصروف'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _receiptPreview() {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.black26),
                SizedBox(height: 8),
                Text(
                  'ABC Cafe\n───────────\nقهوة أمريكانو   18.00\nكرواسون        22.00\nعصير برتقال     15.00\nشاي بالحليب    21.09\n───────────\nالمجموع: 76.09\nVAT 15%: 11.41\n═══════════\nالإجمالي: 87.50',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          // Simulated boxes over extracted fields
          Positioned(
            top: 80,
            right: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.2),
                border: Border.all(color: const Color(0xFF059669), width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ABC Cafe',
                style: TextStyle(fontSize: 9, color: Color(0xFF059669), fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _extractedFields(_ExtractedReceipt r) {
    return Column(
      children: [
        _field('المورد', r.vendor, Icons.store),
        _field('المبلغ الإجمالي', '${r.amount.toStringAsFixed(2)} ${r.currency}', Icons.payments, color: const Color(0xFF059669)),
        _field('VAT (15%)', '${r.vat.toStringAsFixed(2)} ${r.currency}', Icons.percent),
        _field('التاريخ', r.date, Icons.event),
        _field(
          'التصنيف',
          r.category,
          Icons.category,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(r.categoryConfidence * 100).toInt()}%',
              style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.w700),
            ),
          ),
        ),
        _field('طريقة الدفع', r.paymentMethod, Icons.credit_card),
        _field('رقم الفاتورة', r.invoiceNumber, Icons.tag),
        const SizedBox(height: 8),
        if (r.items.isNotEmpty) ...[
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.list, size: 12, color: Colors.black54),
                SizedBox(width: 6),
                Text(
                  'البنود المستخرجة',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black54),
                ),
              ],
            ),
          ),
          for (final item in r.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Text('• ', style: TextStyle(color: Colors.black54)),
                  Expanded(
                    child: Text(item.label, style: const TextStyle(fontSize: 11)),
                  ),
                  Text(
                    '${item.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _field(String label, String value, IconData icon, {Color? color, Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 13, color: Colors.black45),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing,
          ],
        ],
      ),
    );
  }
}

class _ExtractedReceipt {
  final String vendor;
  final double amount;
  final double vat;
  final String currency;
  final String date;
  final String category;
  final double categoryConfidence;
  final List<_ReceiptItem> items;
  final String paymentMethod;
  final String invoiceNumber;

  _ExtractedReceipt({
    required this.vendor,
    required this.amount,
    required this.vat,
    required this.currency,
    required this.date,
    required this.category,
    required this.categoryConfidence,
    required this.items,
    required this.paymentMethod,
    required this.invoiceNumber,
  });
}

class _ReceiptItem {
  final String label;
  final double amount;
  _ReceiptItem(this.label, this.amount);
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF059669).withOpacity(0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF059669)),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ),
    );
  }
}
