/// APEX Wave 21 — GOSI & WPS (Compliance > Regulatory).
///
/// KSA-specific: GOSI (General Organization for Social Insurance) +
/// WPS (Wage Protection System via Mudad).
///
/// Route: /app/compliance/regulatory/gosi
library;

import 'package:flutter/material.dart';

import '../../core/v5/apex_v5_undo_toast.dart';

class GosiWpsScreen extends StatefulWidget {
  const GosiWpsScreen({super.key});

  @override
  State<GosiWpsScreen> createState() => _GosiWpsScreenState();
}

class _GosiWpsScreenState extends State<GosiWpsScreen> {
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
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          _tabBtn(0, 'قائمة الموظفين', Icons.people),
          _tabBtn(1, 'الإرسال الشهري', Icons.send),
          _tabBtn(2, 'WPS / مدد', Icons.shield),
          _tabBtn(3, 'الانحرافات', Icons.warning),
          _tabBtn(4, 'السجل', Icons.history),
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
          color: active ? const Color(0xFF2E7D5B).withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFF2E7D5B).withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF2E7D5B) : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? const Color(0xFF2E7D5B) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _buildRoster();
      case 1: return _buildMonthly();
      case 2: return _buildWps();
      case 3: return _buildVariances();
      case 4: return _buildHistory();
      default: return const SizedBox();
    }
  }

  Widget _buildRoster() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('سعوديون مسجّلون', '42', Icons.flag, const Color(0xFF2E7D5B)),
            _Stat('غير سعوديين', '45', Icons.public, const Color(0xFF2563EB)),
            _Stat('نسبة السعودة', '48%', Icons.equalizer, const Color(0xFFD4AF37)),
            _Stat('مساهمة GOSI شهرياً', '142K ر.س', Icons.health_and_safety, const Color(0xFF7C3AED)),
          ]),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('قائمة الموظفين المسجّلين في GOSI', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.sync, size: 14),
                label: const Text('مزامنة مع HR'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _rosterHeader(),
                _rosterRow('أحمد السالم', '1234567890', 'CEO', 'سعودي', 45000, 4950, active: true),
                _rosterRow('سارة محمود', '2345678901', 'CFO', 'سعودي', 28000, 3080, active: true),
                _rosterRow('Sarah Mitchell', '2401234567', 'Consultant', 'غير سعودي', 22000, 440, active: true),
                _rosterRow('خالد أحمد', '1456789012', 'محاسب أول', 'سعودي', 18000, 1980, active: true),
                _rosterRow('فاطمة علي', '1567890123', 'مسؤول مخزون', 'سعودي', 12000, 1320, active: false, note: 'إجازة أمومة'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rosterHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.06))),
      ),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('الموظف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text('الهوية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text('الوظيفة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text('الجنسية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text('الراتب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
          Expanded(child: Text('مساهمة GOSI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _rosterRow(String name, String nid, String role, String nationality, double salary, double gosi, {required bool active, String? note}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFF059669) : const Color(0xFFD97706),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      if (note != null)
                        Text(note, style: const TextStyle(fontSize: 10, color: Color(0xFFD97706))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: Text(nid, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54))),
          Expanded(child: Text(role, style: const TextStyle(fontSize: 11))),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: nationality == 'سعودي'
                    ? const Color(0xFF2E7D5B).withOpacity(0.12)
                    : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                nationality,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: nationality == 'سعودي' ? const Color(0xFF2E7D5B) : Colors.black54,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              '${salary.toStringAsFixed(0)} ر.س',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              '${gosi.toStringAsFixed(0)} ر.س',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: Color(0xFF2E7D5B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthly() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D5B), Color(0xFF059669)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.send, color: Colors.white, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'الإرسال الشهري — أبريل 2026',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _monthlyStatPill('المبلغ', '142,340 ر.س', Colors.white),
                    const SizedBox(width: 12),
                    _monthlyStatPill('الموظفون', '87', Colors.white),
                    const SizedBox(width: 12),
                    _monthlyStatPill('آخر موعد', '2026-05-10', Colors.white),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('تفاصيل المساهمات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _breakdownRow('مساهمة الشركة (11%)', 78_340, const Color(0xFF2E7D5B)),
                _breakdownRow('مساهمة الموظف (10%)', 64_000, const Color(0xFF2563EB)),
                const Divider(),
                _breakdownRow('إجمالي الإرسال', 142_340, const Color(0xFF059669), bold: true),
                _breakdownRow('من الأحمال على الشركة', 78_340, const Color(0xFF059669)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFD97706).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Color(0xFFD97706), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تذكير: موعد الإرسال قبل اليوم 10 من الشهر التالي — غرامة التأخير 25% من قيمة الفترة.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.preview, size: 14),
                label: const Text('معاينة'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  ApexV5UndoToast.show(
                    context,
                    messageAr: 'تم إرسال GOSI لشهر أبريل 2026 — 142,340 ر.س',
                    onUndo: () {},
                  );
                },
                icon: const Icon(Icons.send, size: 14),
                label: const Text('إرسال الآن'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D5B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _monthlyStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, double value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
          const Spacer(),
          Text(
            '${value.toStringAsFixed(0)} ر.س',
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWps() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F2937), Color(0xFF374151)],
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
                  child: const Icon(Icons.shield, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'نظام حماية الأجور (WPS) — مدد',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ملف SIF جاهز للتسليم لمنصّة مدد — 87 موظف',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text('جاهز', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('ملف SIF — أبريل 2026', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black.withOpacity(0.08)),
            ),
            child: Column(
              children: [
                _sifRow('عدد الموظفين', '87', Icons.people, const Color(0xFF2563EB)),
                _sifRow('إجمالي الرواتب', '780,000 ر.س', Icons.payments, const Color(0xFF059669)),
                _sifRow('معرّف المنشأة', 'EST-8472-2021', Icons.business, Colors.black54),
                _sifRow('رقم البنك', 'SA03-8000-0000-6080101469XX', Icons.account_balance, const Color(0xFFD4AF37)),
                _sifRow('تاريخ الاستحقاق', '2026-05-01', Icons.event, const Color(0xFFD97706)),
                _sifRow('حجم الملف', '4.2 KB', Icons.description, Colors.black54),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.preview, size: 14),
                label: const Text('معاينة الملف'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.download, size: 14),
                label: const Text('تحميل SIF'),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () {
                  ApexV5UndoToast.show(
                    context,
                    messageAr: 'تم رفع ملف SIF إلى مدد — 87 موظف، 780K ر.س',
                    onUndo: () {},
                  );
                },
                icon: const Icon(Icons.cloud_upload, size: 14),
                label: const Text('رفع إلى مدد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D5B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sifRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildVariances() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('انحرافات هذا الشهر', '3', Icons.warning, const Color(0xFFD97706)),
            _Stat('عالية الخطورة', '1', Icons.error, const Color(0xFFB91C1C)),
            _Stat('تم حلّها', '7 هذا الربع', Icons.check_circle, const Color(0xFF059669)),
            _Stat('إجمالي الفوارق', '8,400 ر.س', Icons.compare_arrows, const Color(0xFF7C3AED)),
          ]),
          const SizedBox(height: 16),
          const Text('الانحرافات بين GOSI والرواتب', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _varianceCard(
            'سارة محمود',
            'راتب في GOSI: 25,000 vs HR: 28,000',
            'اختلاف 3,000 ر.س — الراتب زاد في HR لكن لم يُحدَّث في GOSI',
            const Color(0xFFB91C1C),
            action: 'تحديث GOSI',
          ),
          _varianceCard(
            'خالد أحمد',
            'تاريخ الالتحاق: GOSI 2022-09-01 vs HR 2022-09-15',
            'فارق 14 يوم — قد يؤثر على حساب العلاوات',
            const Color(0xFFD97706),
            action: 'تأكيد التاريخ',
          ),
          _varianceCard(
            'فاطمة علي',
            'الحالة: GOSI نشط vs HR في إجازة أمومة',
            'تحديث الحالة في GOSI يوفر 1,320 ر.س/شهر',
            const Color(0xFF2563EB),
            action: 'تعديل الحالة',
          ),
        ],
      ),
    );
  }

  Widget _varianceCard(String name, String issue, String detail, Color color, {required String action}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.warning, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(issue, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(detail, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ApexV5UndoToast.show(
                context,
                messageAr: 'تم $action لـ $name',
                onUndo: () {},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل الإرساليات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final h in [
            _History('أبريل 2026', 142340, 87, 'معتمد ✓', const Color(0xFF059669)),
            _History('مارس 2026', 138920, 86, 'معتمد ✓', const Color(0xFF059669)),
            _History('فبراير 2026', 135600, 85, 'معتمد ✓', const Color(0xFF059669)),
            _History('يناير 2026', 131480, 84, 'معتمد ✓', const Color(0xFF059669)),
            _History('ديسمبر 2025', 128300, 82, 'معتمد ✓', const Color(0xFF059669)),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.black54),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(h.period, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text('${h.employees} موظف', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                  Text(
                    '${h.amount.toStringAsFixed(0)} ر.س',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: h.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(h.status, style: TextStyle(fontSize: 11, color: h.color, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
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
              decoration: BoxDecoration(
                color: s.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: s.color.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: s.color)),
                        Text(s.label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
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
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  _Stat(this.label, this.value, this.icon, this.color);
}

class _History {
  final String period;
  final double amount;
  final int employees;
  final String status;
  final Color color;
  _History(this.period, this.amount, this.employees, this.status, this.color);
}
