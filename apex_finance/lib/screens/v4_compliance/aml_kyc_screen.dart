/// APEX Wave 22 — AML & KYC (Compliance > Regulatory).
///
/// Anti-Money Laundering + Know Your Customer.
/// Compares against PEP lists, sanctions, SAR filings.
///
/// Route: /app/compliance/regulatory/aml
library;

import 'package:flutter/material.dart';

import '../../core/v5/apex_v5_undo_toast.dart';

class AmlKycScreen extends StatefulWidget {
  const AmlKycScreen({super.key});

  @override
  State<AmlKycScreen> createState() => _AmlKycScreenState();
}

class _AmlKycScreenState extends State<AmlKycScreen> {
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
          _tabBtn(0, 'الفحص', Icons.search),
          _tabBtn(1, 'الحالات', Icons.folder_special),
          _tabBtn(2, 'قواعد المراقبة', Icons.rule),
          _tabBtn(3, 'إيداعات SAR', Icons.description),
          _tabBtn(4, 'قائمة المراقبة', Icons.list_alt),
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
          color: active ? const Color(0xFFB91C1C).withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(6),
          border: active ? Border.all(color: const Color(0xFFB91C1C).withOpacity(0.4)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFFB91C1C) : Colors.black54),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? const Color(0xFFB91C1C) : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case 0: return _buildScreening();
      case 1: return _buildCases();
      case 2: return _buildRules();
      case 3: return _buildSar();
      case 4: return _buildWatchlist();
      default: return const SizedBox();
    }
  }

  Widget _buildScreening() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('فحوصات اليوم', '47', Icons.search, const Color(0xFF2563EB)),
            _Stat('تطابقات PEP', '2', Icons.warning, const Color(0xFFD97706)),
            _Stat('عقوبات', '0', Icons.block, const Color(0xFF059669)),
            _Stat('بحاجة مراجعة', '5', Icons.pending_actions, const Color(0xFFB91C1C)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB91C1C), Color(0xFF7C3AED)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Icon(Icons.security, color: Colors.white, size: 28),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AML Screening Engine',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'فحص تلقائي مقابل: OFAC · EU · UN · SAMA · KSA PEP Lists',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('فحص عميل/مورّد جديد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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
                const TextField(
                  decoration: InputDecoration(
                    labelText: 'الاسم الكامل (عربي أو إنجليزي)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'رقم الهوية/الإقامة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'الدولة',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ApexV5UndoToast.show(
                        context,
                        messageAr: 'بدأ الفحص AML... سيستغرق 2-3 ثواني',
                        icon: Icons.search,
                      );
                    },
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('ابدأ الفحص'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('النتائج الأخيرة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _screeningResult('ABC Trading Co — محمد علي', 'نظيف ✓', const Color(0xFF059669), 'لا تطابقات'),
          _screeningResult('SABIC Procurement — عبدالرحمن', 'تطابق PEP', const Color(0xFFD97706), 'تطابق جزئي مع قائمة SAMA'),
          _screeningResult('XYZ Holdings Ltd', 'عالي الخطورة', const Color(0xFFB91C1C), 'تطابق OFAC — مطلوب توقّف'),
        ],
      ),
    );
  }

  Widget _screeningResult(String name, String status, Color color, String detail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              color == const Color(0xFF059669) ? Icons.check_circle : Icons.warning,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(detail, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildCases() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statsRow([
            _Stat('حالات مفتوحة', '8', Icons.folder_open, const Color(0xFF2563EB)),
            _Stat('عالية الخطورة', '2', Icons.error, const Color(0xFFB91C1C)),
            _Stat('محلّلة هذا الشهر', '14', Icons.check_circle, const Color(0xFF059669)),
            _Stat('متوسط زمن الحل', '4.2 يوم', Icons.timer, const Color(0xFF7C3AED)),
          ]),
          const SizedBox(height: 16),
          const Text('الحالات النشطة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final c in [
            _Case('AML-2026-012', 'XYZ Holdings Ltd', 'عالية', 'تطابق OFAC', 'تحت التحقيق'),
            _Case('AML-2026-011', 'ABC Trading', 'متوسطة', 'تحويل مشبوه', 'مراجعة'),
            _Case('AML-2026-010', 'فرد — سعيد العتيبي', 'عالية', 'PEP تطابق', 'مكتمل التحقق'),
            _Case('AML-2026-009', 'Quick Exchange', 'متوسطة', 'نشاط غير معتاد', 'تحت التحقيق'),
          ])
            _caseCard(c),
        ],
      ),
    );
  }

  Widget _caseCard(_Case c) {
    final color = c.severity == 'عالية'
        ? const Color(0xFFB91C1C)
        : c.severity == 'متوسطة'
            ? const Color(0xFFD97706)
            : const Color(0xFF2563EB);

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
            width: 4,
            height: 48,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(c.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(c.severity, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(c.subject, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                Text(c.reason, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(c.status, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: () {}, child: const Text('عرض')),
        ],
      ),
    );
  }

  Widget _buildRules() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('قواعد المراقبة النشطة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final r in [
            _Rule('Structuring — الهيكلة', 'معاملات متعدّدة تحت 10K خلال 24 ساعة', true, const Color(0xFFB91C1C)),
            _Rule('Round Number Transactions', 'مبالغ مستديرة > 50K', true, const Color(0xFFD97706)),
            _Rule('Cross-Border Large', 'تحويلات > 100K عبر الحدود', true, const Color(0xFFB91C1C)),
            _Rule('New Vendor Large', 'أول معاملة مع مورد جديد > 50K', true, const Color(0xFFD97706)),
            _Rule('Off-hours Activity', 'معاملات بين 22:00-06:00', true, const Color(0xFF7C3AED)),
            _Rule('Sanctions Screening', 'فحص تلقائي لكل مورد/عميل جديد', true, const Color(0xFF059669)),
          ])
            _ruleCard(r),
        ],
      ),
    );
  }

  Widget _ruleCard(_Rule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: rule.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.shield, color: rule.color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rule.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Text(rule.desc, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              ],
            ),
          ),
          Switch(value: rule.active, onChanged: (_) {}, activeColor: rule.color),
        ],
      ),
    );
  }

  Widget _buildSar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFB91C1C).withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFB91C1C).withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.gavel, color: Color(0xFFB91C1C), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تقارير النشاط المشبوه (SAR) — تُرسل إلى إدارة الاحتيال المالي بوزارة الداخلية السعودية',
                    style: TextStyle(fontSize: 12, color: Color(0xFFB91C1C), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _statsRow([
            _Stat('إيداعات هذا العام', '7', Icons.description, const Color(0xFFB91C1C)),
            _Stat('قيد الإعداد', '2', Icons.edit, const Color(0xFFD97706)),
            _Stat('مقبولة', '5', Icons.check_circle, const Color(0xFF059669)),
            _Stat('مرفوضة', '0', Icons.block, const Color(0xFF6B7280)),
          ]),
          const SizedBox(height: 16),
          const Text('السجل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final s in [
            _Sar('SAR-2026-007', 'XYZ Holdings', '2026-04-10', 'قيد الإعداد'),
            _Sar('SAR-2026-006', 'Quick Exchange', '2026-03-22', 'مقبول'),
            _Sar('SAR-2026-005', 'ABC Trading', '2026-02-15', 'مقبول'),
            _Sar('SAR-2026-004', 'Premium Cars Co', '2026-02-01', 'مقبول'),
          ])
            _sarRow(s),
        ],
      ),
    );
  }

  Widget _sarRow(_Sar s) {
    final statusColor = s.status == 'مقبول'
        ? const Color(0xFF059669)
        : s.status == 'قيد الإعداد'
            ? const Color(0xFFD97706)
            : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.description, color: Colors.black54, size: 18),
          const SizedBox(width: 10),
          Text(s.id, style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.black54)),
          const SizedBox(width: 16),
          Expanded(child: Text(s.subject, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
          Text(s.date, style: const TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(s.status, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchlist() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('قوائم المراقبة المتصلة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final w in [
            _Watchlist('OFAC SDN List', 'وزارة الخزانة الأمريكية', '12,847 اسم', true, const Color(0xFFB91C1C)),
            _Watchlist('EU Consolidated List', 'الاتحاد الأوروبي', '3,421 اسم', true, const Color(0xFF2563EB)),
            _Watchlist('UN Security Council', 'الأمم المتحدة', '892 اسم', true, const Color(0xFF059669)),
            _Watchlist('SAMA PEP List', 'ساما السعودية', '2,134 اسم', true, const Color(0xFFD4AF37)),
            _Watchlist('Interpol Red Notices', 'الإنتربول', '6,718 اسم', true, const Color(0xFF7C3AED)),
            _Watchlist('Internal Watchlist', 'قائمة داخلية', '47 اسم', true, Colors.black54),
          ])
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black.withOpacity(0.08)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: w.color.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                    child: Icon(Icons.list_alt, color: w.color, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                        Text('${w.source} · ${w.count}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sync, size: 11, color: Color(0xFF059669)),
                        SizedBox(width: 3),
                        Text('متزامن', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
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
  final String label, value;
  final IconData icon;
  final Color color;
  _Stat(this.label, this.value, this.icon, this.color);
}

class _Case {
  final String id, subject, severity, reason, status;
  _Case(this.id, this.subject, this.severity, this.reason, this.status);
}

class _Rule {
  final String name, desc;
  final bool active;
  final Color color;
  _Rule(this.name, this.desc, this.active, this.color);
}

class _Sar {
  final String id, subject, date, status;
  _Sar(this.id, this.subject, this.date, this.status);
}

class _Watchlist {
  final String name, source, count;
  final bool active;
  final Color color;
  _Watchlist(this.name, this.source, this.count, this.active, this.color);
}
