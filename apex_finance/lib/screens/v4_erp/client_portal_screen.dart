/// APEX V5.1 — Client Portal (Enhancement #12).
///
/// B2B2C: the company's customer gets login to see HIS invoices,
/// statements, payments, support — reduces back-office emails 70%.
///
/// Replaces: Freshbooks client portal + QuickBooks customer payment portal.
///
/// Route: /app/erp/finance/reports (demoed as "portal preview")
library;

import 'package:flutter/material.dart';

class ClientPortalScreen extends StatefulWidget {
  const ClientPortalScreen({super.key});

  @override
  State<ClientPortalScreen> createState() => _ClientPortalScreenState();
}

class _ClientPortalScreenState extends State<ClientPortalScreen> {
  int _tab = 0;

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
                colors: [Color(0xFFD4AF37), Color(0xFFE6C200)],
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
                  child: const Icon(Icons.account_circle, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بوابة العميل — Client Portal',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'يرى عميلك فواتيره · يدفع مباشرة · يُسقط 70% من emails',
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
                    'FreshBooks Alternative',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Preview box — iPad-style frame
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 900),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withOpacity(0.12), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Browser chrome
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                      border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08))),
                    ),
                    child: Row(
                      children: [
                        ...[Colors.red, Colors.orange, Colors.green].map(
                          (c) => Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.lock, size: 12, color: Color(0xFF059669)),
                                SizedBox(width: 6),
                                Text(
                                  'portal.apex-financial.com/abc-trading',
                                  style: TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Portal content
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Company header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.bolt, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'شركة الرياض للتجارة',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            const Text(
                              'مرحباً، ABC Trading',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.2),
                              child: const Text(
                                'A',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // KPI cards
                        Row(
                          children: [
                            _kpi(
                              label: 'رصيد مستحق',
                              value: '87,500',
                              currency: 'ر.س',
                              color: const Color(0xFFB91C1C),
                              icon: Icons.payment,
                            ),
                            const SizedBox(width: 12),
                            _kpi(
                              label: 'فواتير لم تُدفع',
                              value: '3',
                              color: const Color(0xFFD97706),
                              icon: Icons.receipt_long,
                            ),
                            const SizedBox(width: 12),
                            _kpi(
                              label: 'مدفوع هذا العام',
                              value: '245,300',
                              currency: 'ر.س',
                              color: const Color(0xFF059669),
                              icon: Icons.check_circle,
                            ),
                            const SizedBox(width: 12),
                            _kpi(
                              label: 'التالية استحقاقاً',
                              value: '22 أبريل',
                              color: const Color(0xFF2563EB),
                              icon: Icons.event,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Tabs
                        Row(
                          children: [
                            _portalTab('الفواتير', 0, Icons.receipt),
                            _portalTab('كشوف الحساب', 1, Icons.list),
                            _portalTab('المدفوعات', 2, Icons.payments),
                            _portalTab('المستندات', 3, Icons.folder),
                            _portalTab('الدعم', 4, Icons.support_agent),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black.withOpacity(0.08)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              _invoiceRow('INV-2026-145', '2026-04-22', 12500, 'مدفوعة', const Color(0xFF059669)),
                              _invoiceRow('INV-2026-167', '2026-04-22', 25000, 'متأخرة', const Color(0xFFB91C1C), payable: true),
                              _invoiceRow('INV-2026-182', '2026-04-30', 40000, 'مرسلة', const Color(0xFF2563EB), payable: true),
                              _invoiceRow('INV-2026-191', '2026-05-05', 22500, 'مرسلة', const Color(0xFF2563EB), payable: true),
                              _invoiceRow('INV-2026-088', '2026-03-15', 15000, 'مدفوعة', const Color(0xFF059669)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Payment CTA
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4AF37), Color(0xFFE6C200)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.bolt, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'ادفع 87,500 ر.س الآن — فيزا/ماستركارد/مدى/Apple Pay',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {},
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFFD4AF37),
                                ),
                                child: const Text('ادفع الآن'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Meta
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF2563EB)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'كل عميل يحصل على رابط شخصي + تسجيل دخول آمن · يستخدم نفس بيانات APEX · مجاني للعميل',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi({
    required String label,
    required String value,
    String? currency,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontFamily: 'monospace',
                  ),
                ),
                if (currency != null) ...[
                  const SizedBox(width: 4),
                  Text(
                    currency,
                    style: const TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _portalTab(String label, int idx, IconData icon) {
    final active = _tab == idx;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: () => setState(() => _tab = idx),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFD4AF37).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: active ? Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: active ? const Color(0xFFD4AF37) : Colors.black54),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? const Color(0xFFD4AF37) : Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _invoiceRow(String id, String date, double amount, String statusLabel, Color color, {bool payable = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt, size: 16, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(id, style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600)),
                Text(date, style: const TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${amount.toStringAsFixed(0)} ر.س',
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          if (payable)
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF059669),
                side: const BorderSide(color: Color(0xFF059669)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('ادفع'),
            ),
        ],
      ),
    );
  }
}
