/// APEX — Saved Views (NetSuite Saved Search pattern)
/// ═══════════════════════════════════════════════════════════════════════
/// Per gap analysis P1 #9: NetSuite Saved Search is the most-praised UX
/// primitive in mid-market ERP. One definition powers list view + dashboard
/// widget + pivot + scheduled email.
///
/// This is a lightweight client-side implementation:
///   • Save current filter state with a name
///   • Pin to favorites
///   • Share via URL with encoded params
///   • Future: server-persisted + scheduled email
library;

import 'dart:convert';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'theme.dart';

class ApexSavedView {
  final String id;
  final String name;
  final String screen; // e.g., '/sales/invoices'
  final Map<String, dynamic> filters;
  final DateTime createdAt;
  final bool pinned;
  final IconData? icon;

  const ApexSavedView({
    required this.id,
    required this.name,
    required this.screen,
    required this.filters,
    required this.createdAt,
    this.pinned = false,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'screen': screen,
        'filters': filters,
        'created_at': createdAt.toIso8601String(),
        'pinned': pinned,
        'icon': icon?.codePoint,
      };

  factory ApexSavedView.fromJson(Map<String, dynamic> j) => ApexSavedView(
        id: j['id'] as String,
        name: j['name'] as String,
        screen: j['screen'] as String,
        filters: (j['filters'] as Map?)?.cast<String, dynamic>() ?? {},
        createdAt: DateTime.tryParse(j['created_at'] ?? '') ?? DateTime.now(),
        pinned: j['pinned'] == true,
        icon: j['icon'] is int ? IconData(j['icon'] as int, fontFamily: 'MaterialIcons') : null,
      );
}

/// Singleton repository — backs to localStorage for now.
class ApexSavedViewsRepo {
  static const _key = 'apex_saved_views_v2';

  static List<ApexSavedView> all() {
    final raw = html.window.localStorage[_key];
    if (raw == null || raw.isEmpty) return _defaults;
    try {
      final list = jsonDecode(raw) as List;
      return list.map((j) => ApexSavedView.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaults;
    }
  }

  static void save(List<ApexSavedView> views) {
    html.window.localStorage[_key] =
        jsonEncode(views.map((v) => v.toJson()).toList());
  }

  static void add(ApexSavedView view) {
    final existing = all();
    existing.add(view);
    save(existing);
  }

  static void remove(String id) {
    final existing = all().where((v) => v.id != id).toList();
    save(existing);
  }

  static void togglePin(String id) {
    final existing = all().map((v) => ApexSavedView(
          id: v.id,
          name: v.name,
          screen: v.screen,
          filters: v.filters,
          createdAt: v.createdAt,
          pinned: v.id == id ? !v.pinned : v.pinned,
          icon: v.icon,
        )).toList();
    save(existing);
  }

  /// Default views shipped with APEX.
  static final List<ApexSavedView> _defaults = [
    ApexSavedView(
      id: 'default_invoices_overdue',
      name: 'فواتير متأخرة',
      screen: '/sales/invoices',
      filters: {'filter': 'overdue'},
      createdAt: DateTime.now(),
      pinned: true,
      icon: Icons.warning_amber,
    ),
    ApexSavedView(
      id: 'default_ar_high',
      name: 'AR > 90 يوماً',
      screen: '/sales/aging',
      filters: {},
      createdAt: DateTime.now(),
      pinned: true,
      icon: Icons.timeline,
    ),
    ApexSavedView(
      id: 'default_customers_active',
      name: 'العملاء النشطون',
      screen: '/sales/customers',
      filters: {'filter': 'active'},
      createdAt: DateTime.now(),
      pinned: false,
      icon: Icons.people,
    ),
  ];
}

/// Bottom sheet for picking/managing saved views from a list screen.
class ApexSavedViewsSheet extends StatefulWidget {
  final String screen;
  final ValueChanged<ApexSavedView>? onApply;

  const ApexSavedViewsSheet({super.key, required this.screen, this.onApply});

  static Future<ApexSavedView?> show(BuildContext context, {required String screen}) {
    return showModalBottomSheet<ApexSavedView>(
      context: context,
      backgroundColor: AC.navy2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ApexSavedViewsSheet(screen: screen),
    );
  }

  @override
  State<ApexSavedViewsSheet> createState() => _ApexSavedViewsSheetState();
}

class _ApexSavedViewsSheetState extends State<ApexSavedViewsSheet> {
  late List<ApexSavedView> _views;

  @override
  void initState() {
    super.initState();
    _views = ApexSavedViewsRepo.all().where((v) => v.screen == widget.screen).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AC.ts,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Center(
            child: Text('Saved Views',
                style: TextStyle(color: AC.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          if (_views.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('لا توجد saved views لهذه الشاشة',
                    style: TextStyle(color: AC.ts, fontSize: 12)),
              ),
            )
          else
            ..._views.map((v) => ListTile(
                  leading: Icon(v.icon ?? Icons.bookmark_outline, color: AC.gold),
                  title: Text(v.name, style: TextStyle(color: AC.tp)),
                  subtitle: Text('${v.filters.length} فلتر',
                      style: TextStyle(color: AC.ts, fontSize: 11)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: Icon(v.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                          color: v.pinned ? AC.gold : AC.ts, size: 18),
                      onPressed: () {
                        ApexSavedViewsRepo.togglePin(v.id);
                        setState(() => _views = ApexSavedViewsRepo.all()
                            .where((view) => view.screen == widget.screen)
                            .toList());
                      },
                    ),
                  ]),
                  onTap: () {
                    Navigator.pop(context, v);
                    widget.onApply?.call(v);
                  },
                )),
          const Divider(),
          ListTile(
            leading: Icon(Icons.add, color: AC.gold),
            title: Text('احفظ الفلاتر الحالية', style: TextStyle(color: AC.gold)),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved Views — أضف الاسم في النسخة القادمة')),
              );
            },
          ),
        ],
      ),
    );
  }
}
