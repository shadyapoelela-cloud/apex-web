/// APEX Wave 73 — AI Anomaly Detector.
/// Route: /app/erp/finance/anomalies
///
/// ML-powered detection of unusual transactions, patterns,
/// and control breakdowns.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class AnomalyDetectorScreen extends StatefulWidget {
  const AnomalyDetectorScreen({super.key});
  @override
  State<AnomalyDetectorScreen> createState() => _AnomalyDetectorScreenState();
}

class _AnomalyDetectorScreenState extends State<AnomalyDetectorScreen> {
  String _severity = 'all';

  final _anomalies = <_Anomaly>[
    _Anomaly(
      'ANM-2026-0142',
      'critical',
      'دفعة كبيرة لمورد جديد بدون أمر شراء',
      'دفعة 485,000 ر.س لـ "Shadow Tech LLC" مسجّل قبل 3 أيام — لا يوجد PO مطابق ولم يمر بفحص الامتثال.',
      'payment',
      '2026-04-19 09:15',
      0.97,
      ['مورد جديد < 7 أيام', 'مبلغ > 400K ر.س', 'بدون PO مطابق', 'لا فحص AML'],
      'تجميد الدفعة + إحالة للفريق المالي والامتثال',
    ),
    _Anomaly(
      'ANM-2026-0141',
      'high',
      'نمط غير معتاد في مصاريف موظف',
      'الموظف EMP-0078 قدّم 8 مطالبات مصروفات في 5 أيام بإجمالي 24,500 ر.س — المتوسط الشهري 4,200 ر.س.',
      'expense',
      '2026-04-18 16:42',
      0.88,
      ['عدد المطالبات > 3× المتوسط', 'إجمالي > 5× المتوسط', 'كلها أقل من حد الاعتماد الذاتي'],
      'مراجعة المطالبات يدوياً + التأكد من صحة الإيصالات',
    ),
    _Anomaly(
      'ANM-2026-0140',
      'high',
      'فاتورة مكرّرة لنفس العميل والمبلغ',
      'فاتورتان INV-2026-0508 و INV-2026-0517 لـ "مجموعة الحبتور" بنفس المبلغ 125,000 ر.س في يومين متتاليين.',
      'invoice',
      '2026-04-18 11:20',
      0.82,
      ['مبلغ مطابق 100%', 'فارق زمني < 48 ساعة', 'نفس العميل'],
      'اتصال بالعميل للتأكد من صحة الفاتورتين',
    ),
    _Anomaly(
      'ANM-2026-0139',
      'medium',
      'قيد محاسبي بعد ساعات العمل',
      'قيد JE-2026-145 بمبلغ 87,000 ر.س أُدخل الساعة 23:42 من قبل فهد الشمري — غير معتاد.',
      'journal',
      '2026-04-17 23:42',
      0.65,
      ['الوقت خارج ساعات العمل', 'تعديل على حساب إيرادات', 'لا تفسير في الوصف'],
      'استفسار من المستخدم + طلب التوثيق',
    ),
    _Anomaly(
      'ANM-2026-0138',
      'medium',
      'تغيير متكرر على نفس الفاتورة',
      'فاتورة INV-2026-0495 عُدّلت 6 مرات في 3 أيام — آخرها خفض المبلغ من 340K إلى 285K.',
      'invoice',
      '2026-04-17 14:10',
      0.71,
      ['عدد التعديلات > 5', 'خفض المبلغ > 10%', 'بدون موافقة مدير'],
      'مراجعة سجل التعديلات + مطابقة مع العقد',
    ),
    _Anomaly(
      'ANM-2026-0137',
      'low',
      'مورد بعنوان بريدي جديد',
      'المورد SUP-0042 حدّث عنوانه البريدي للمرة الثانية في شهر — علامة احتياطية.',
      'vendor',
      '2026-04-16 09:30',
      0.45,
      ['تغيير بيانات أساسية', 'تواتر > 1 في 30 يوم'],
      'تأكيد العنوان الجديد شفهياً',
    ),
    _Anomaly(
      'ANM-2026-0136',
      'high',
      'محاولة تجاوز حدود الاعتماد',
      'الموظف MGR-012 قسّم فاتورة 580,000 ر.س إلى 5 فواتير كل منها 116,000 (تحت حده 125K).',
      'workflow',
      '2026-04-15 13:25',
      0.93,
      ['تقسيم قيمة كلية', 'كل جزء تحت حد مباشر', 'نفس المورد ونفس اليوم'],
      'إعادة النظر + تصعيد للمدير المالي',
    ),
    _Anomaly(
      'ANM-2026-0135',
      'critical',
      'خرق في نمط تسجيل الدخول',
      'حساب admin@apex.sa — محاولات دخول من 3 دول مختلفة في 10 دقائق.',
      'security',
      '2026-04-15 08:12',
      0.99,
      ['Impossible travel', '3 IPs متفرقة', 'فشل MFA'],
      'تعطيل الحساب فوراً + إبلاغ الأمن السيبراني',
    ),
  ];

  List<_Anomaly> get _filtered {
    if (_severity == 'all') return _anomalies;
    return _anomalies.where((a) => a.severity == _severity).toList();
  }

  @override
  Widget build(BuildContext context) {
    final critical = _anomalies.where((a) => a.severity == 'critical').length;
    final high = _anomalies.where((a) => a.severity == 'high').length;
    final avgConfidence = _anomalies.fold(0.0, (s, a) => s + a.confidence) / _anomalies.length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('مكتشفة اليوم', '${_anomalies.length}', core_theme.AC.purple, Icons.visibility),
            _kpi('حرجة', '$critical', core_theme.AC.err, Icons.error),
            _kpi('عالية الخطورة', '$high', core_theme.AC.warn, Icons.warning),
            _kpi('متوسط الثقة', '${(avgConfidence * 100).toStringAsFixed(0)}%', core_theme.AC.info, Icons.psychology),
            _kpi('معدل الدقة (Precision)', '92%', core_theme.AC.ok, Icons.gps_fixed),
          ],
        ),
        const SizedBox(height: 16),
        _buildAiBanner(),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            _severityChip('all', 'الكل'),
            _severityChip('critical', 'حرج', core_theme.AC.err),
            _severityChip('high', 'عالٍ', core_theme.AC.warn),
            _severityChip('medium', 'متوسط', core_theme.AC.warn),
            _severityChip('low', 'منخفض', core_theme.AC.info),
          ],
        ),
        const SizedBox(height: 16),
        for (final a in _filtered) _anomalyCard(a),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF311B92), Color(0xFF512DA8)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.psychology, color: Colors.white, size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('كاشف الشذوذ الذكي',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('AI Anomaly Detection · نمذجة سلوكية · كشف فوري للمعاملات غير الاعتيادية',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: core_theme.AC.purple,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.purple),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, color: core_theme.AC.purple),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('محرّك كشف الشذوذ',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: core_theme.AC.purple)),
                Text(
                  '⚡ يفحص 10,000+ معاملة يومياً · 🧠 يتعلم من نمط عمل كل مستخدم · 🎯 ينبّه على النمط قبل الحدوث',
                  style: TextStyle(fontSize: 11, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _severityChip(String id, String label, [Color? color]) {
    final selected = _severity == id;
    final c = color ?? const Color(0xFF311B92);
    return InkWell(
      onTap: () => setState(() => _severity = id),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? c : c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : c)),
      ),
    );
  }

  Widget _anomalyCard(_Anomaly a) {
    final color = _severityColor(a.severity);
    final typeInfo = _typeInfo(a.type);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: color.withOpacity(0.25))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Icon(typeInfo.icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(a.id, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: core_theme.AC.ts)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                            child: Text(_severityLabel(a.severity),
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: core_theme.AC.bdr, borderRadius: BorderRadius.circular(3)),
                            child: Text(typeInfo.label,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 6),
                          Text(a.timestamp,
                              style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(a.title,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, height: 1.4)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('ثقة النموذج', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    Text('${(a.confidence * 100).toStringAsFixed(0)}%',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.description, style: TextStyle(fontSize: 12, height: 1.6, color: core_theme.AC.tp)),
                const SizedBox(height: 12),
                Text('🚩 علامات التنبيه:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.ts)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in a.signals)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(s, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: core_theme.AC.gold.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: core_theme.AC.gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb, color: core_theme.AC.gold, size: 16),
                      SizedBox(width: 6),
                      Text('الإجراء الموصى به:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: core_theme.AC.gold)),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(a.recommendation,
                    style: const TextStyle(fontSize: 12, height: 1.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.check, size: 14),
                      label: Text('تأكيد وعلاج', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.flag, size: 14),
                      label: Text('تصعيد', style: TextStyle(fontSize: 11)),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.not_interested, size: 14),
                      label: Text('إنذار كاذب', style: TextStyle(fontSize: 11)),
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

  Color _severityColor(String s) {
    switch (s) {
      case 'critical':
        return core_theme.AC.err;
      case 'high':
        return core_theme.AC.warn;
      case 'medium':
        return core_theme.AC.warn;
      case 'low':
        return core_theme.AC.info;
      default:
        return core_theme.AC.td;
    }
  }

  String _severityLabel(String s) {
    switch (s) {
      case 'critical':
        return 'حرج';
      case 'high':
        return 'عالٍ';
      case 'medium':
        return 'متوسط';
      case 'low':
        return 'منخفض';
      default:
        return s;
    }
  }

  _TypeInfo _typeInfo(String t) {
    switch (t) {
      case 'payment':
        return const _TypeInfo('دفعة', Icons.payments);
      case 'expense':
        return const _TypeInfo('مصروفات', Icons.receipt);
      case 'invoice':
        return const _TypeInfo('فاتورة', Icons.description);
      case 'journal':
        return const _TypeInfo('قيد', Icons.book);
      case 'vendor':
        return const _TypeInfo('مورد', Icons.store);
      case 'workflow':
        return const _TypeInfo('سير عمل', Icons.account_tree);
      case 'security':
        return const _TypeInfo('أمن', Icons.shield);
      default:
        return const _TypeInfo('أخرى', Icons.category);
    }
  }
}

class _Anomaly {
  final String id;
  final String severity;
  final String title;
  final String description;
  final String type;
  final String timestamp;
  final double confidence;
  final List<String> signals;
  final String recommendation;
  const _Anomaly(this.id, this.severity, this.title, this.description, this.type, this.timestamp, this.confidence, this.signals, this.recommendation);
}

class _TypeInfo {
  final String label;
  final IconData icon;
  const _TypeInfo(this.label, this.icon);
}
