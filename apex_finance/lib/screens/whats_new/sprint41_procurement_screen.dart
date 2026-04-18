/// Sprint 41 — Procurement & Receiving.
///
/// Three tabs:
///   1) المخزون: ApexBarcodeInput + inventory list (scan to lookup)
///   2) 3-Way Match: PO ↔ GRN ↔ Bill reconciliation widget
///   3) مركز الإشعارات: full notification list page
library;

import 'package:flutter/material.dart';

import '../../core/apex_barcode_input.dart';
import '../../core/apex_data_table.dart';
import '../../core/apex_notification_bell.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/apex_three_way_match.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class Sprint41ProcurementScreen extends StatefulWidget {
  const Sprint41ProcurementScreen({super.key});

  @override
  State<Sprint41ProcurementScreen> createState() =>
      _Sprint41ProcurementScreenState();
}

class _Sprint41ProcurementScreenState
    extends State<Sprint41ProcurementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(
              title: '📦 Sprint 41: الشراء والاستلام + الإشعارات'),
          Container(
            color: AC.navy2,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AC.gold,
              labelColor: AC.gold,
              unselectedLabelColor: AC.ts,
              tabs: const [
                Tab(
                    icon: Icon(Icons.inventory_2_outlined),
                    text: 'المخزون + الباركود'),
                Tab(
                    icon: Icon(Icons.compare_arrows),
                    text: '3-Way Match'),
                Tab(
                    icon: Icon(Icons.notifications_outlined),
                    text: 'مركز الإشعارات'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: const [
                _InventoryTab(),
                _ThreeWayMatchTab(),
                _NotificationCenterTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Inventory Tab ────────────────────────────────────────

class _InventoryTab extends StatefulWidget {
  const _InventoryTab();
  @override
  State<_InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<_InventoryTab> {
  final List<_Item> _items = [
    _Item('8414520011001', 'زيت زيتون فاخر 1L', 45, 18.5, 12),
    _Item('6281007122005', 'معكرونة سباغيتي 500g', 120, 4.25, 20),
    _Item('5449000000996', 'ماء معدني 1.5L × 6', 84, 12.0, 30),
    _Item('8901060600012', 'شاي أسود 100 كيس', 32, 22.0, 8),
    _Item('6223000234569', 'أرز بسمتي 5kg', 18, 65.0, 5),
  ];

  _Item? _lastFound;
  int _scanCount = 0;

  void _onScan(String code) {
    setState(() {
      _scanCount++;
      for (final it in _items) {
        if (it.sku == code) {
          _lastFound = it;
          return;
        }
      }
      _lastFound = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('صنف غير معروف: $code'),
            duration: const Duration(seconds: 2)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _header(),
        const SizedBox(height: AppSpacing.lg),
        ApexBarcodeInput(
          onScan: _onScan,
          validate: (c) {
            if (c.length < 8) return 'الباركود قصير جداً';
            if (!RegExp(r'^\d+$').hasMatch(c)) return 'أرقام فقط';
            return null;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (_lastFound != null) _foundCard(_lastFound!),
        const SizedBox(height: AppSpacing.lg),
        _section('قائمة المخزون (${_items.length} صنف)', _inventoryTable()),
      ],
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.15), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.gold.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.qr_code_scanner, color: Colors.amber, size: 28),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المخزون + مسح الباركود',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.lg,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'جرّب: امسح بجهاز USB أو اكتب 8414520011001 (زيت زيتون) أو 6223000234569 (أرز بسمتي). عمليات المسح: $_scanCount',
                  style:
                      TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                ),
              ],
            ),
          ),
        ]),
      );

  Widget _foundCard(_Item it) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.ok.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AC.ok.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Icon(Icons.check_circle, color: AC.ok, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(it.description,
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.base,
                        fontWeight: FontWeight.w700)),
                Text('SKU: ${it.sku}',
                    style: TextStyle(
                        color: AC.ts,
                        fontSize: AppFontSize.xs,
                        fontFamily: 'monospace')),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('المتوفر: ${it.qty}',
                  style: TextStyle(
                      color: it.qty > it.reorderPoint ? AC.ok : AC.err,
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.w800)),
              Text('@ ${it.price.toStringAsFixed(2)} ر.س',
                  style: TextStyle(
                      color: AC.gold,
                      fontSize: AppFontSize.sm,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ]),
      );

  Widget _section(String title, Widget body) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            body,
          ],
        ),
      );

  Widget _inventoryTable() => ApexDataTable<_Item>(
        rows: _items,
        columns: [
          ApexColumn(
              key: 'sku',
              label: 'SKU',
              cell: (i) => Text(i.sku,
                  style: TextStyle(
                      color: AC.ts,
                      fontSize: AppFontSize.xs,
                      fontFamily: 'monospace')),
              sortValue: (i) => i.sku,
              width: 140),
          ApexColumn(
              key: 'desc',
              label: 'الوصف',
              cell: (i) => Text(i.description,
                  style: TextStyle(color: AC.tp)),
              sortValue: (i) => i.description,
              flex: 2),
          ApexColumn(
              key: 'qty',
              label: 'المتوفر',
              numeric: true,
              cell: (i) => Row(mainAxisSize: MainAxisSize.min, children: [
                    if (i.qty <= i.reorderPoint)
                      Icon(Icons.warning_amber,
                          size: 14, color: AC.err),
                    const SizedBox(width: 4),
                    Text('${i.qty}',
                        style: TextStyle(
                            color: i.qty <= i.reorderPoint ? AC.err : AC.tp,
                            fontWeight: FontWeight.w700)),
                  ]),
              sortValue: (i) => i.qty,
              width: 100),
          ApexColumn(
              key: 'reorder',
              label: 'حد الطلب',
              numeric: true,
              cell: (i) => Text('${i.reorderPoint}',
                  style: TextStyle(color: AC.ts)),
              sortValue: (i) => i.reorderPoint,
              width: 100),
          ApexColumn(
              key: 'price',
              label: 'السعر',
              numeric: true,
              cell: (i) => Text(i.price.toStringAsFixed(2),
                  style: TextStyle(
                      color: AC.gold,
                      fontWeight: FontWeight.w600,
                      fontFeatures:
                          const [FontFeature.tabularFigures()])),
              sortValue: (i) => i.price,
              width: 90),
        ],
      );
}

// ── 3-Way Match Tab ──────────────────────────────────────

class _ThreeWayMatchTab extends StatefulWidget {
  const _ThreeWayMatchTab();
  @override
  State<_ThreeWayMatchTab> createState() => _ThreeWayMatchTabState();
}

class _ThreeWayMatchTabState extends State<_ThreeWayMatchTab> {
  int _selected = 0;

  final _samples = const [
    _MatchSample(
      title: 'تطابق كامل (PO-2025-041)',
      poNumber: 'PO-2025-041',
      grnNumber: 'GRN-2025-091',
      billNumber: 'BILL-V-881',
      vendor: 'شركة التوريدات المتقدمة',
      lines: [
        MatchLine(
            sku: '8414520011001',
            description: 'زيت زيتون فاخر 1L',
            poQty: 100,
            poPrice: 18.5,
            grnQty: 100,
            billQty: 100,
            billPrice: 18.5),
        MatchLine(
            sku: '6281007122005',
            description: 'معكرونة سباغيتي 500g',
            poQty: 200,
            poPrice: 4.25,
            grnQty: 200,
            billQty: 200,
            billPrice: 4.25),
      ],
    ),
    _MatchSample(
      title: 'نقص كمية (PO-2025-042)',
      poNumber: 'PO-2025-042',
      grnNumber: 'GRN-2025-093',
      billNumber: 'BILL-V-884',
      vendor: 'صناعات البحر الأحمر',
      lines: [
        MatchLine(
            sku: '5449000000996',
            description: 'ماء معدني 1.5L × 6',
            poQty: 500,
            poPrice: 12.0,
            grnQty: 480, // 20 units short
            billQty: 500, // vendor still billed for full quantity
            billPrice: 12.0),
      ],
    ),
    _MatchSample(
      title: 'فرق سعر (PO-2025-043)',
      poNumber: 'PO-2025-043',
      grnNumber: 'GRN-2025-095',
      billNumber: 'BILL-V-887',
      vendor: 'مؤسسة النخبة للتجارة',
      lines: [
        MatchLine(
            sku: '6223000234569',
            description: 'أرز بسمتي 5kg',
            poQty: 50,
            poPrice: 65.0,
            grnQty: 50,
            billQty: 50,
            billPrice: 68.5), // priced up 3.5 ر.س
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sample = _samples[_selected];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (var i = 0; i < _samples.length; i++)
                ChoiceChip(
                  label: Text(_samples[i].title),
                  selected: _selected == i,
                  selectedColor: AC.gold.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _selected = i),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AC.navy2,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AC.bdr),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المورّد: ${sample.vendor}',
                    style: TextStyle(
                        color: AC.ts,
                        fontSize: AppFontSize.sm,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.md),
                ApexThreeWayMatch(
                  poNumber: sample.poNumber,
                  grnNumber: sample.grnNumber,
                  billNumber: sample.billNumber,
                  vendor: sample.vendor,
                  lines: sample.lines,
                  onApprove: () =>
                      _toast('تم اعتماد الفاتورة ${sample.billNumber}'),
                  onEscalate: () =>
                      _toast('رُفعت للمراجعة من AP Manager'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), duration: const Duration(seconds: 2)),
    );
  }
}

class _MatchSample {
  final String title;
  final String poNumber;
  final String grnNumber;
  final String billNumber;
  final String vendor;
  final List<MatchLine> lines;

  const _MatchSample({
    required this.title,
    required this.poNumber,
    required this.grnNumber,
    required this.billNumber,
    required this.vendor,
    required this.lines,
  });
}

// ── Notification Center Tab ──────────────────────────────

class _NotificationCenterTab extends StatefulWidget {
  const _NotificationCenterTab();
  @override
  State<_NotificationCenterTab> createState() =>
      _NotificationCenterTabState();
}

class _NotificationCenterTabState extends State<_NotificationCenterTab> {
  String _filter = 'all';

  late List<ApexNotification> _all = [
    ApexNotification(
        id: 'n1',
        title: 'فاتورة متأخرة INV-1042',
        body: 'عبرت تاريخ الاستحقاق بـ 5 أيام — شركة الرياض للتجارة',
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
        severity: 'error'),
    ApexNotification(
        id: 'n2',
        title: 'تم توقيع فاتورة ZATCA',
        body: 'INV-1041 اعتُمدت وأُرسلت إلى Fatoora بنجاح',
        timestamp: DateTime.now().subtract(const Duration(minutes: 23)),
        severity: 'success'),
    ApexNotification(
        id: 'n3',
        title: 'تحذير: معدل الحرق',
        body: 'Burn Rate ارتفع 18% هذا الشهر — Runway 8.2 شهراً',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        severity: 'warning'),
    ApexNotification(
        id: 'n4',
        title: 'تقرير P&L جاهز',
        body: 'قوائم مارس جاهزة للمراجعة والنشر',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        severity: 'info',
        read: true),
    ApexNotification(
        id: 'n5',
        title: 'مطابقة 3-Way أخفقت',
        body: 'BILL-V-884 فيها نقص 20 وحدة — يتطلب مراجعة',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        severity: 'error'),
    ApexNotification(
        id: 'n6',
        title: 'طلب إجازة جديد',
        body: 'ريم القحطاني تطلب 60 يوم أمومة',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        severity: 'info'),
    ApexNotification(
        id: 'n7',
        title: 'GOSI جاهز للسداد',
        body: 'استحقاق شهر مارس: 8,670 ر.س قبل 10 أبريل',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        severity: 'warning'),
    ApexNotification(
        id: 'n8',
        title: 'باقة جديدة في السوق',
        body: 'مؤسسة النجم الذهبي اشتركت في الباقة الاحترافية',
        timestamp: DateTime.now().subtract(const Duration(days: 2)),
        severity: 'success',
        read: true),
  ];

  List<ApexNotification> get _filtered {
    if (_filter == 'all') return _all;
    if (_filter == 'unread') return _all.where((n) => !n.read).toList();
    return _all.where((n) => n.severity == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unread = _all.where((n) => !n.read).length;
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(children: [
          Icon(Icons.notifications_active, color: AC.gold, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مركز الإشعارات',
                    style: TextStyle(
                        color: AC.tp,
                        fontSize: AppFontSize.xl,
                        fontWeight: FontWeight.w800)),
                Text('$unread غير مقروء من ${_all.length}',
                    style: TextStyle(
                        color: AC.ts, fontSize: AppFontSize.sm)),
              ],
            ),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.done_all, size: 16),
            label: const Text('تعليم الكل مقروءاً'),
            onPressed: () => setState(() {
              _all = _all
                  .map((n) => ApexNotification(
                      id: n.id,
                      title: n.title,
                      body: n.body,
                      timestamp: n.timestamp,
                      severity: n.severity,
                      read: true))
                  .toList();
            }),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final f in const [
              ('all', 'الكل', Icons.all_inbox),
              ('unread', 'غير مقروء', Icons.mark_email_unread),
              ('error', 'خطأ', Icons.error_outline),
              ('warning', 'تحذير', Icons.warning_amber),
              ('success', 'نجاح', Icons.check_circle_outline),
              ('info', 'معلومة', Icons.info_outline),
            ])
              FilterChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.$3, size: 14),
                  const SizedBox(width: 4),
                  Text(f.$2),
                ]),
                selected: _filter == f.$1,
                selectedColor: AC.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _filter = f.$1),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Expanded(
        child: ListView.separated(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _notifTile(_filtered[i]),
        ),
      ),
    ]);
  }

  Widget _notifTile(ApexNotification n) {
    final (color, icon) = switch (n.severity) {
      'error' => (AC.err, Icons.error_outline),
      'warning' => (Colors.amber.shade700, Icons.warning_amber),
      'success' => (AC.ok, Icons.check_circle_outline),
      _ => (AC.gold, Icons.info_outline),
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () => _markRead(n.id),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: n.read ? AC.navy2 : AC.navy3,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: n.read
                    ? AC.bdr
                    : color.withValues(alpha: 0.5),
                width: n.read ? 1 : 1.5),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(n.title,
                            style: TextStyle(
                                color: AC.tp,
                                fontSize: AppFontSize.base,
                                fontWeight: n.read
                                    ? FontWeight.w500
                                    : FontWeight.w700)),
                      ),
                      Text(_timeAgo(n.timestamp),
                          style: TextStyle(
                              color: AC.td, fontSize: AppFontSize.xs)),
                    ]),
                    const SizedBox(height: 2),
                    Text(n.body,
                        style: TextStyle(
                            color: AC.ts, fontSize: AppFontSize.sm)),
                  ],
                ),
              ),
              if (!n.read)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 4, top: 4),
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return 'قبل ${d.inMinutes} د';
    if (d.inHours < 24) return 'قبل ${d.inHours} س';
    return 'قبل ${d.inDays} يوم';
  }

  void _markRead(String id) {
    setState(() {
      _all = _all
          .map((n) => n.id == id
              ? ApexNotification(
                  id: n.id,
                  title: n.title,
                  body: n.body,
                  timestamp: n.timestamp,
                  severity: n.severity,
                  read: true)
              : n)
          .toList();
    });
  }
}

class _Item {
  final String sku;
  final String description;
  final int qty;
  final double price;
  final int reorderPoint;
  const _Item(
      this.sku, this.description, this.qty, this.price, this.reorderPoint);
}
