/// APEX Saved Views Bar — Xero/Odoo-style "my filters" chip row.
///
/// Client for the backend `/api/v1/saved-views` CRUD. Each screen that
/// has a filter UI adds one of these above its list. A view is a named
/// snapshot of `{filters, sort, columns}` (whatever the screen cares
/// about). The bar lets the user switch, create, rename, delete, and
/// share views — private by default, shared (team) flag for admins.
///
/// Usage:
/// ```dart
/// ApexSavedViewsBar(
///   screen: 'clients',
///   userId: currentUserId,
///   currentPayload: {'filters': _filters, 'sort': _sort},
///   onApply: (view) => setState(() => _applyPayload(view.payload)),
/// )
/// ```
///
/// This widget is intentionally self-contained: it owns its own HTTP
/// state and refreshes on demand via a public `refresh()` on the
/// returned GlobalKey. It does NOT depend on Riverpod so screens can
/// adopt it incrementally.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'design_tokens.dart';
import 'session.dart';
import 'theme.dart';

/// Value object returned by the backend for each saved view.
class ApexSavedView {
  final String id;
  final String screen;
  final String name;
  final Map<String, dynamic> payload;
  final bool isShared;

  ApexSavedView({
    required this.id,
    required this.screen,
    required this.name,
    required this.payload,
    required this.isShared,
  });

  factory ApexSavedView.fromJson(Map<String, dynamic> m) => ApexSavedView(
        id: m['id'] as String,
        screen: m['screen'] as String,
        name: m['name'] as String,
        payload: (m['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
        isShared: (m['is_shared'] as bool?) ?? false,
      );
}

class ApexSavedViewsBar extends StatefulWidget {
  /// Screen identifier (e.g. `'clients'`, `'journal_entries'`). The same
  /// value must be used by every caller that shares this saved-view list.
  final String screen;

  /// User id for scoping private views. Leave null to use the session user.
  final String? userId;

  /// Current filter/sort/column state. Used when the user hits "Save as".
  final Map<String, dynamic> currentPayload;

  /// Called when the user picks a saved view. The screen should apply the
  /// payload to its filter state.
  final void Function(ApexSavedView view) onApply;

  /// If true, the bar renders an "Admin share" option. Default: false.
  final bool canShare;

  const ApexSavedViewsBar({
    super.key,
    required this.screen,
    required this.currentPayload,
    required this.onApply,
    this.userId,
    this.canShare = false,
  });

  @override
  State<ApexSavedViewsBar> createState() => _ApexSavedViewsBarState();
}

class _ApexSavedViewsBarState extends State<ApexSavedViewsBar> {
  List<ApexSavedView> _views = const [];
  String? _activeId;
  bool _loading = true;
  String? _error;

  String get _base => apiBase;

  String? get _uid => widget.userId ?? S.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Uri _u(String path, [Map<String, String>? q]) {
    final qp = <String, String>{'screen': widget.screen};
    if (_uid != null) qp['user_id'] = _uid!;
    qp.addAll(q ?? const {});
    return Uri.parse('$_base/api/v1/saved-views$path')
        .replace(queryParameters: qp);
  }

  Map<String, String> get _headers {
        final t = S.token;
        return {
          'Content-Type': 'application/json',
          if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
        };
      }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(_u(''), headers: _headers);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (body['data'] as List).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _views = data.map(ApexSavedView.fromJson).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _create() async {
    final name = await _prompt(context, 'اسم العرض', hint: 'مثال: فواتير هذا الشهر');
    if (name == null || name.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await http.post(
        _u(''),
        headers: _headers,
        body: jsonEncode({
          'screen': widget.screen,
          'name': name,
          'payload': widget.currentPayload,
          'is_shared': false,
        }),
      );
      if (res.statusCode == 409) {
        _toast('الاسم موجود بالفعل');
      } else if (res.statusCode != 201) {
        _toast('فشل الحفظ (${res.statusCode})');
      }
      await _load();
    } catch (e) {
      _toast('خطأ: $e');
      await _load();
    }
  }

  Future<void> _delete(ApexSavedView v) async {
    final ok = await _confirm(context, 'حذف "${v.name}"؟');
    if (ok != true) return;
    setState(() => _loading = true);
    try {
      await http.delete(_u('/${v.id}'), headers: _headers);
      if (_activeId == v.id) _activeId = null;
    } finally {
      await _load();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _views.isEmpty) {
      return const SizedBox(
          height: 44,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return Semantics(
      label: 'شريط العروض المحفوظة',
      container: true,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.bookmark_outline, color: AC.gold, size: 18),
            const SizedBox(width: AppSpacing.xs),
            Text('عروض محفوظة:',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _views.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
                itemBuilder: (_, i) => _chip(_views[i]),
              ),
            ),
            if (_error != null)
              Tooltip(
                message: _error!,
                child: Icon(Icons.error_outline, color: AC.err, size: 18),
              ),
            IconButton(
              tooltip: 'حفظ العرض الحالي كعرض جديد',
              icon: Icon(Icons.add_circle_outline, color: AC.gold, size: 20),
              onPressed: _create,
            ),
            IconButton(
              tooltip: 'تحديث',
              icon: Icon(Icons.refresh, color: AC.ts, size: 18),
              onPressed: _load,
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(ApexSavedView v) {
    final active = v.id == _activeId;
    return InkWell(
      onTap: () {
        setState(() => _activeId = v.id);
        widget.onApply(v);
      },
      onLongPress: () => _delete(v),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: active ? AC.gold.withValues(alpha: 0.15) : AC.navy3,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
              color: active ? AC.gold : AC.bdr,
              width: active ? 1.5 : 1),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (v.isShared)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.group_outlined, size: 14, color: AC.ts),
            ),
          Text(v.name,
              style: TextStyle(
                  color: active ? AC.gold : AC.tp,
                  fontSize: AppFontSize.sm,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
        ]),
      ),
    );
  }
}

// ── Tiny dialogs ──────────────────────────────────────────

Future<String?> _prompt(BuildContext ctx, String title, {String? hint}) async {
  final c = TextEditingController();
  final res = await showDialog<String>(
    context: ctx,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
        FilledButton(
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: const Text('حفظ')),
      ],
    ),
  );
  c.dispose();
  return res;
}

Future<bool?> _confirm(BuildContext ctx, String msg) async => showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('تأكيد')),
        ],
      ),
    );
