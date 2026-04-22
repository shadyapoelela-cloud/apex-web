/// APEX Wave 86 — Cybersecurity Dashboard (SOC View).
/// Route: /app/compliance/regulatory/cybersecurity
///
/// Real-time security posture aligned with NIST + ISO 27001.
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class CybersecurityDashboardScreen extends StatefulWidget {
  const CybersecurityDashboardScreen({super.key});
  @override
  State<CybersecurityDashboardScreen> createState() => _CybersecurityDashboardScreenState();
}

class _CybersecurityDashboardScreenState extends State<CybersecurityDashboardScreen> {
  final _incidents = const [
    _Incident('INC-2026-1284', 'محاولة تسجيل دخول مشبوهة — 84.23.115.204', 'critical', 'active', '2026-04-19 08:12', 'Impossible travel', 15),
    _Incident('INC-2026-1283', 'برنامج ضار محجوب عبر Proxy', 'high', 'contained', '2026-04-19 02:45', 'قاعدة WAF', 0),
    _Incident('INC-2026-1282', 'تحميل ملف كبير خارج ساعات العمل', 'medium', 'investigating', '2026-04-18 23:18', 'DLP Alert', 120),
    _Incident('INC-2026-1281', 'فشل في تحديثات ESXi', 'low', 'resolved', '2026-04-18 14:20', 'Monitoring', 0),
    _Incident('INC-2026-1280', 'محاولة حقن SQL على /api/v1/login', 'high', 'contained', '2026-04-18 11:05', 'WAF', 0),
    _Incident('INC-2026-1279', 'تنبيه DDoS على البوابة العامة', 'critical', 'resolved', '2026-04-17 16:30', 'Cloudflare', 0),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildHero(),
        const SizedBox(height: 16),
        _buildPostureScore(),
        const SizedBox(height: 16),
        Row(
          children: [
            _kpi('تنبيهات اليوم', '42', '+12 من أمس', core_theme.AC.err, Icons.warning),
            _kpi('هجمات محجوبة', '1,847', 'آخر 24 ساعة', core_theme.AC.warn, Icons.shield),
            _kpi('حوادث نشطة', '2', '1 حرج', core_theme.AC.err, Icons.error),
            _kpi('متوسط زمن الاحتواء', '18 دقيقة', 'MTTR', core_theme.AC.info, Icons.timer),
            _kpi('نسبة الأجهزة المحدّثة', '98.5%', '156/158', core_theme.AC.ok, Icons.system_update),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildIncidents()),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: _buildThreatMap()),
          ],
        ),
        const SizedBox(height: 16),
        _buildComplianceStatus(),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0D47A1), Color(0xFF1565C0)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Colors.white, size: 36),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الأمن السيبراني — SOC',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Text('NIST · ISO 27001 · SOC 2 · Security Operations Center — مراقبة 24/7',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: core_theme.AC.ok,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.circle, color: Colors.white, size: 10),
                SizedBox(width: 6),
                Text('SOC متصل',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostureScore() {
    final score = 87;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [core_theme.AC.ok, core_theme.AC.ok]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 10,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFFD700)),
                      ),
                    ),
                    Column(
                      children: [
                        Text('$score',
                            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                        Text('/100', style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('درجة الوضع الأمني العامة',
                    style: TextStyle(color: core_theme.AC.ts, fontSize: 12)),
                const Text('قوي — من أفضل 20% في الصناعة',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 8,
                  children: [
                    _postureMetric('الشبكة', 92),
                    _postureMetric('التطبيقات', 85),
                    _postureMetric('الهوية والوصول', 90),
                    _postureMetric('البيانات', 82),
                    _postureMetric('Endpoint', 88),
                    _postureMetric('Cloud', 85),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _postureMetric(String label, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: core_theme.AC.ts, fontSize: 11)),
        const SizedBox(width: 4),
        Text('$value%',
            style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _kpi(String label, String value, String note, Color color, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                  Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
                  Text(note, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidents() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: core_theme.AC.err),
              SizedBox(width: 8),
              Text('آخر الحوادث الأمنية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          for (final i in _incidents) _incidentRow(i),
        ],
      ),
    );
  }

  Widget _incidentRow(_Incident i) {
    final sevColor = _severityColor(i.severity);
    final statusColor = _statusColor(i.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: sevColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sevColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(width: 4, height: 56, color: sevColor),
          const SizedBox(width: 10),
          Icon(_severityIcon(i.severity), color: sevColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(i.id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: core_theme.AC.ts)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(3)),
                      child: Text(_severityLabel(i.severity),
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                      child: Text(_statusLabel(i.status),
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(i.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 10, color: core_theme.AC.td),
                    const SizedBox(width: 3),
                    Text(i.detectedAt, style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                    const SizedBox(width: 10),
                    Icon(Icons.sensors, size: 10, color: core_theme.AC.td),
                    const SizedBox(width: 3),
                    Text(i.detector, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    if (i.durationMin > 0) ...[
                      const SizedBox(width: 10),
                      Icon(Icons.timelapse, size: 10, color: core_theme.AC.td),
                      const SizedBox(width: 3),
                      Text('${i.durationMin}د', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (i.status == 'active')
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: core_theme.AC.err,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(0, 28),
              ),
              child: const Text('احتواء', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _buildThreatMap() {
    final origins = [
      _ThreatOrigin('🇷🇺 روسيا', 342, core_theme.AC.err),
      _ThreatOrigin('🇨🇳 الصين', 285, core_theme.AC.err),
      _ThreatOrigin('🇰🇵 كوريا الشمالية', 124, Colors.deepOrange),
      _ThreatOrigin('🇮🇷 إيران', 98, core_theme.AC.warn),
      _ThreatOrigin('🇺🇸 الولايات المتحدة', 76, core_theme.AC.warn),
      _ThreatOrigin('🇳🇱 هولندا', 48, core_theme.AC.ok),
      _ThreatOrigin('أخرى', 318, core_theme.AC.td),
    ];
    final total = origins.fold(0, (s, o) => s + o.attempts);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.public, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Text('التهديدات حسب المصدر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          Text('آخر 24 ساعة', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
          const SizedBox(height: 14),
          for (final o in origins)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 140, child: Text(o.country, style: const TextStyle(fontSize: 12))),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: o.attempts / total,
                      backgroundColor: core_theme.AC.navy3,
                      valueColor: AlwaysStoppedAnimation(o.color),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${o.attempts}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, fontFamily: 'monospace')),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: core_theme.AC.info,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: core_theme.AC.info, size: 16),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'إجمالي محاولات الهجوم المحجوبة',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
                Text('$total',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: core_theme.AC.info, fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceStatus() {
    final standards = [
      _Standard('ISO 27001', 'إدارة أمن المعلومات', 2026, 'معتمد', core_theme.AC.ok),
      _Standard('SOC 2 Type II', 'ضوابط المنظمة', 2026, 'معتمد', core_theme.AC.ok),
      _Standard('PCI DSS', 'أمن بيانات البطاقات', 2026, 'مطابق', core_theme.AC.ok),
      _Standard('NIST CSF', 'إطار الأمن السيبراني', 2026, 'متبع', core_theme.AC.info),
      _Standard('GDPR / NDMO', 'حماية البيانات الشخصية', 2026, 'مطابق', core_theme.AC.ok),
      _Standard('هيئة الأمن السيبراني NCA', 'الضوابط الأساسية ECC', 2026, 'مطابق', core_theme.AC.ok),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified, color: core_theme.AC.ok),
              SizedBox(width: 8),
              Text('الامتثال للمعايير الأمنية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final s in standards)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: s.color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: s.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: s.color, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            Text(s.description, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: s.color.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                                  child: Text(s.status,
                                      style: TextStyle(fontSize: 10, color: s.color, fontWeight: FontWeight.w800)),
                                ),
                                const SizedBox(width: 6),
                                Text('سنوي ${s.year}',
                                    style: TextStyle(fontSize: 10, color: core_theme.AC.ts, fontFamily: 'monospace')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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

  IconData _severityIcon(String s) {
    switch (s) {
      case 'critical':
        return Icons.gpp_bad;
      case 'high':
        return Icons.warning;
      case 'medium':
        return Icons.error_outline;
      case 'low':
        return Icons.info_outline;
      default:
        return Icons.circle;
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

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return core_theme.AC.err;
      case 'investigating':
        return core_theme.AC.warn;
      case 'contained':
        return core_theme.AC.info;
      case 'resolved':
        return core_theme.AC.ok;
      default:
        return core_theme.AC.td;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'active':
        return 'نشط';
      case 'investigating':
        return 'قيد التحقيق';
      case 'contained':
        return 'محتوى';
      case 'resolved':
        return 'تم الحل';
      default:
        return s;
    }
  }
}

class _Incident {
  final String id;
  final String title;
  final String severity;
  final String status;
  final String detectedAt;
  final String detector;
  final int durationMin;
  const _Incident(this.id, this.title, this.severity, this.status, this.detectedAt, this.detector, this.durationMin);
}

class _ThreatOrigin {
  final String country;
  final int attempts;
  final Color color;
  const _ThreatOrigin(this.country, this.attempts, this.color);
}

class _Standard {
  final String name;
  final String description;
  final int year;
  final String status;
  final Color color;
  const _Standard(this.name, this.description, this.year, this.status, this.color);
}
