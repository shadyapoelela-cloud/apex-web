import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

/// Wave 112 — Real Estate Property Management
/// Properties, tenants, leases, maintenance
class RealEstateScreen extends StatefulWidget {
  const RealEstateScreen({super.key});
  @override
  State<RealEstateScreen> createState() => _RealEstateScreenState();
}

class _RealEstateScreenState extends State<RealEstateScreen> with SingleTickerProviderStateMixin {
  late TabController _tc;
  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(child: Column(children: [
        _hero(), _kpis(),
        Container(color: Colors.white, child: TabBar(controller: _tc,
          labelColor: const Color(0xFF4A148C), unselectedLabelColor: core_theme.AC.ts,
          indicatorColor: core_theme.AC.gold, indicatorWeight: 3,
          tabs: const [Tab(text: 'العقارات'), Tab(text: 'المستأجرون'), Tab(text: 'عقود الإيجار'), Tab(text: 'التحليلات')])),
        Expanded(child: TabBarView(controller: _tc, children: [_propertiesTab(), _tenantsTab(), _leasesTab(), _analyticsTab()])),
      ])),
    ));
  }

  Widget _hero() => Container(padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF4A148C)])),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: core_theme.AC.gold, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.apartment, color: Colors.white, size: 32)),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('إدارة الأملاك العقارية', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('العقارات، المستأجرون، عقود الإيجار، الصيانة', style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ])),
    ]),
  );

  Widget _kpis() {
    final totalUnits = _properties.fold(0, (s, p) => s + p.totalUnits);
    final occupied = _properties.fold(0, (s, p) => s + p.occupiedUnits);
    final monthlyRev = _leases.where((l)=>l.status.contains('نشط')).fold<double>(0, (s, l) => s + l.monthlyRent);
    return Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
      Expanded(child: _kpi('العقارات', '${_properties.length}', Icons.apartment, const Color(0xFF1A237E))),
      Expanded(child: _kpi('معدل الإشغال', '${((occupied/totalUnits)*100).toStringAsFixed(0)}%', Icons.people, const Color(0xFF2E7D32))),
      Expanded(child: _kpi('الإيراد الشهري', _fmtM(monthlyRev), Icons.payments, core_theme.AC.gold)),
      Expanded(child: _kpi('عقود نشطة', '${_leases.where((l)=>l.status.contains('نشط')).length}', Icons.description, const Color(0xFF4A148C))),
    ]));
  }

  Widget _kpi(String l, String v, IconData i, Color c) => Container(margin: const EdgeInsets.symmetric(horizontal: 4),
    padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [Icon(i, color: c, size: 22), const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))])),
    ]));

  Widget _propertiesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _properties.length, itemBuilder: (_, i) {
    final p = _properties[i]; final occupancy = p.occupiedUnits / p.totalUnits;
    return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFF4A148C).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(_typeIcon(p.type), color: const Color(0xFF4A148C))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('${p.type} • ${p.location}', style: TextStyle(fontSize: 12, color: core_theme.AC.ts)),
          ])),
          Text(_fmtM(p.value), style: TextStyle(fontWeight: FontWeight.bold, color: core_theme.AC.gold)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _mini('الوحدات', '${p.totalUnits}'),
          _mini('مشغول', '${p.occupiedUnits}'),
          _mini('المساحة', '${p.area} م²'),
          _mini('إشغال', '${(occupancy * 100).toStringAsFixed(0)}%'),
        ]),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: occupancy, minHeight: 6, backgroundColor: core_theme.AC.bdr, valueColor: const AlwaysStoppedAnimation(Color(0xFF2E7D32)))),
      ]),
    ));
  });

  Widget _mini(String l, String v) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: TextStyle(fontSize: 9, color: core_theme.AC.ts)),
    Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
  ]));

  Widget _tenantsTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _tenants.length, itemBuilder: (_, i) {
    final t = _tenants[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: const Color(0xFF1A237E).withValues(alpha: 0.1),
        child: Text(t.name.substring(0, 1), style: const TextStyle(color: Color(0xFF1A237E), fontWeight: FontWeight.bold))),
      title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${t.unit} • ${t.property}', style: const TextStyle(fontSize: 12)),
        Text('عقد ينتهي: ${t.leaseEnd}', style: TextStyle(fontSize: 11, color: core_theme.AC.ts)),
      ]),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: _paymentColor(t.paymentStatus).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text(t.paymentStatus, style: TextStyle(color: _paymentColor(t.paymentStatus), fontSize: 9, fontWeight: FontWeight.bold))),
        const SizedBox(height: 4),
        Text('${t.monthlyRent.toStringAsFixed(0)} ر.س/شهر', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
      ]),
    ));
  });

  Widget _leasesTab() => ListView.builder(padding: const EdgeInsets.all(12), itemCount: _leases.length, itemBuilder: (_, i) {
    final l = _leases[i];
    return Card(margin: const EdgeInsets.only(bottom: 8), child: Padding(padding: const EdgeInsets.all(12),
      child: Row(children: [
        const Icon(Icons.description, color: Color(0xFF4A148C)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text('${l.tenant} → ${l.unit}', style: const TextStyle(fontSize: 11)),
          Text('${l.startDate} → ${l.endDate}', style: TextStyle(fontSize: 10, color: core_theme.AC.ts)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${l.monthlyRent.toStringAsFixed(0)} ر.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E7D32), fontSize: 12)),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: _leaseColor(l.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Text(l.status, style: TextStyle(color: _leaseColor(l.status), fontSize: 9, fontWeight: FontWeight.bold))),
        ]),
      ]),
    ));
  });

  Widget _analyticsTab() => ListView(padding: const EdgeInsets.all(14), children: [
    _insight('🏢 محفظة عقارية', '7 عقارات متنوعة (سكني، تجاري، إداري)', const Color(0xFF1A237E)),
    _insight('📈 معدل الإشغال', '84% — أعلى من متوسط السوق (78%)', const Color(0xFF2E7D32)),
    _insight('💰 عائد الاستثمار', 'ROI 8.2% سنوي على المحفظة', core_theme.AC.gold),
    _insight('🔧 طلبات الصيانة', '12 طلب نشط — متوسط حل 3.2 يوم', const Color(0xFFE65100)),
    _insight('📅 تجديدات قادمة', '8 عقود تنتهي خلال 90 يوم', const Color(0xFF4A148C)),
    _insight('⚠️ متأخرات', '2.4% من الإيجارات متأخرة — أقل من الصناعة (5%)', const Color(0xFFC62828)),
  ]);

  Widget _insight(String t, String txt, Color c) => Card(margin: const EdgeInsets.only(bottom: 10),
    child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
      const SizedBox(height: 6), Text(txt, style: TextStyle(fontSize: 13, color: core_theme.AC.tp)),
    ])));

  IconData _typeIcon(String t) {
    if (t.contains('تجاري')) return Icons.storefront;
    if (t.contains('سكني')) return Icons.home;
    if (t.contains('إداري')) return Icons.business;
    if (t.contains('أرض')) return Icons.landscape;
    return Icons.apartment;
  }

  Color _paymentColor(String s) {
    if (s.contains('منتظم')) return const Color(0xFF2E7D32);
    if (s.contains('متأخر')) return const Color(0xFFC62828);
    if (s.contains('جزئي')) return const Color(0xFFE65100);
    return core_theme.AC.ts;
  }

  Color _leaseColor(String s) {
    if (s.contains('نشط')) return const Color(0xFF2E7D32);
    if (s.contains('منتهي')) return core_theme.AC.ts;
    if (s.contains('ينتهي')) return const Color(0xFFE65100);
    return const Color(0xFF1A237E);
  }

  String _fmtM(double v) => v >= 1000000 ? '${(v/1000000).toStringAsFixed(2)}M' : '${(v/1000).toStringAsFixed(0)}K';

  static const List<_Property> _properties = [
    _Property('برج الرياض التجاري', 'تجاري إداري', 'العليا - الرياض', 85_000_000, 48, 42, 12500),
    _Property('مجمع السلامة السكني', 'سكني', 'السلامة - جدة', 32_000_000, 36, 34, 8200),
    _Property('فندق الكورنيش', 'تجاري فندقي', 'الخبر', 120_000_000, 140, 112, 18500),
    _Property('عمارة النخيل', 'سكني', 'الياسمين - الرياض', 18_000_000, 24, 20, 4500),
    _Property('أرض تجارية - الدمام', 'أرض', 'طريق الملك فهد', 45_000_000, 1, 0, 15000),
    _Property('مجمع تجاري - المدينة', 'تجاري', 'المدينة المنورة', 28_000_000, 18, 14, 6200),
    _Property('برج الملز', 'إداري', 'الملز - الرياض', 52_000_000, 32, 28, 9800),
  ];

  static const List<_Tenant> _tenants = [
    _Tenant('شركة الاتصالات المتكاملة', 'A-502', 'برج الرياض التجاري', '2027-03-15', 85_000, 'منتظم'),
    _Tenant('أحمد العتيبي', 'B-12', 'مجمع السلامة السكني', '2026-08-01', 12_500, 'منتظم'),
    _Tenant('مطعم الأصالة', 'G-01', 'عمارة النخيل', '2028-01-20', 28_000, 'جزئي'),
    _Tenant('فاطمة السبيعي', 'C-7', 'مجمع السلامة السكني', '2026-06-30', 9_800, 'متأخر'),
    _Tenant('صالون الياسمين', 'R-5', 'مجمع تجاري - المدينة', '2027-11-10', 18_500, 'منتظم'),
    _Tenant('بنك الراجحي فرع', 'A-100', 'برج الرياض التجاري', '2029-05-01', 145_000, 'منتظم'),
  ];

  static const List<_Lease> _leases = [
    _Lease('LSE-2026-001', 'شركة الاتصالات المتكاملة', 'A-502', '2025-03-15', '2027-03-15', 85_000, 'نشط'),
    _Lease('LSE-2026-002', 'أحمد العتيبي', 'B-12', '2024-08-01', '2026-08-01', 12_500, 'ينتهي قريباً'),
    _Lease('LSE-2026-003', 'مطعم الأصالة', 'G-01', '2026-01-20', '2028-01-20', 28_000, 'نشط'),
    _Lease('LSE-2026-004', 'فاطمة السبيعي', 'C-7', '2024-06-30', '2026-06-30', 9_800, 'ينتهي قريباً'),
    _Lease('LSE-2026-005', 'صالون الياسمين', 'R-5', '2024-11-10', '2027-11-10', 18_500, 'نشط'),
    _Lease('LSE-2026-006', 'بنك الراجحي فرع', 'A-100', '2024-05-01', '2029-05-01', 145_000, 'نشط'),
    _Lease('LSE-2025-089', 'شركة سابقة', 'C-3', '2023-01-01', '2025-12-31', 0, 'منتهي'),
  ];
}

class _Property { final String name, type, location; final double value; final int totalUnits, occupiedUnits, area;
  const _Property(this.name, this.type, this.location, this.value, this.totalUnits, this.occupiedUnits, this.area); }
class _Tenant { final String name, unit, property, leaseEnd; final double monthlyRent; final String paymentStatus;
  const _Tenant(this.name, this.unit, this.property, this.leaseEnd, this.monthlyRent, this.paymentStatus); }
class _Lease { final String id, tenant, unit, startDate, endDate; final double monthlyRent; final String status;
  const _Lease(this.id, this.tenant, this.unit, this.startDate, this.endDate, this.monthlyRent, this.status); }
