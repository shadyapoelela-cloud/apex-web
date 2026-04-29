/// APEX — Recent Events Browser
/// /admin/events — debugging tool for the event bus.
///
/// Wired to `/admin/events/recent?limit=N` (Wave 1A Phase F).
/// Helps developers + support + admins see what events are firing
/// (useful when authoring workflow rules).
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class EventsBrowserScreen extends StatefulWidget {
  const EventsBrowserScreen({super.key});
  @override
  State<EventsBrowserScreen> createState() => _EventsBrowserScreenState();
}

class _EventsBrowserScreenState extends State<EventsBrowserScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  int _limit = 100;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
  }

  Future<void> _ensureSecretThenLoad() async {
    if (!ApiService.hasAdminSecret) {
      await _promptSecret();
    }
    await _load();
  }

  Future<void> _promptSecret() async {
    final ctrl = TextEditingController();
    final secret = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('سرّ المسؤول مطلوب', style: TextStyle(color: AC.tp)),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          style: TextStyle(color: AC.tp),
          decoration: InputDecoration(
            labelText: 'X-Admin-Secret',
            labelStyle: TextStyle(color: AC.ts),
            filled: true,
            fillColor: AC.navy3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (secret != null && secret.isNotEmpty) {
      ApiService.adminSecret = secret;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.eventsRecent(limit: _limit);
    if (!mounted) return;
    if (res.success) {
      final raw = (res.data is Map ? res.data['events'] : null) ?? const [];
      _events = (raw as List).cast<Map<String, dynamic>>().reversed.toList();
    } else {
      _error = res.error ?? 'فشل';
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filter.isEmpty
        ? _events
        : _events
            .where((e) =>
                (e['name']?.toString() ?? '').contains(_filter) ||
                jsonEncode(e['payload'] ?? const {}).contains(_filter))
            .toList();
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'مراقب الأحداث',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
          _filterBar(filtered.length),
          Expanded(child: _body(filtered)),
        ],
      ),
    );
  }

  Widget _filterBar(int shownCount) {
    return Container(
      color: AC.navy2,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(children: [
        Expanded(
          child: TextField(
            style: TextStyle(color: AC.tp, fontSize: 12, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: 'ابحث في الاسم أو الحمولة (مثل: invoice، tenant_id)…',
              hintStyle: TextStyle(color: AC.ts.withValues(alpha: 0.6), fontSize: 11),
              filled: true,
              fillColor: AC.navy3,
              isDense: true,
              prefixIcon: Icon(Icons.search, color: AC.ts, size: 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _filter = v.trim()),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: _limit,
          items: const [
            DropdownMenuItem(value: 50, child: Text('50')),
            DropdownMenuItem(value: 100, child: Text('100')),
            DropdownMenuItem(value: 200, child: Text('200')),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _limit = v);
            _load();
          },
          style: TextStyle(color: AC.tp, fontSize: 12),
          dropdownColor: AC.navy3,
          underline: const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        Text('$shownCount / ${_events.length}',
            style: TextStyle(color: AC.ts, fontSize: 11)),
      ]),
    );
  }

  Widget _body(List<Map<String, dynamic>> filtered) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AC.gold));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: AC.err)),
        ),
      );
    }
    if (filtered.isEmpty) {
      return Center(
        child: Text('لا توجد أحداث', style: TextStyle(color: AC.ts)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: filtered.length,
      itemBuilder: (ctx, i) => _row(filtered[i]),
    );
  }

  Widget _row(Map<String, dynamic> e) {
    final name = e['name']?.toString() ?? '';
    final ts = e['ts']?.toString() ?? '';
    final source = e['source']?.toString() ?? '';
    final payload = e['payload'] ?? const {};
    final color = _colorFor(name);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 0),
      childrenPadding: const EdgeInsets.fromLTRB(48, 0, 12, 8),
      leading: Container(
        width: 8,
        height: double.infinity,
        color: color,
      ),
      title: Text(
        name,
        style: TextStyle(
          color: AC.tp,
          fontFamily: 'monospace',
          fontSize: AppFontSize.sm,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Row(children: [
        Text(_shortTime(ts), style: TextStyle(color: AC.ts, fontSize: 10)),
        const SizedBox(width: 8),
        if (source.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AC.navy3,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              source,
              style: TextStyle(color: AC.cyan, fontSize: 9, fontFamily: 'monospace'),
            ),
          ),
      ]),
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AC.navy3,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: SelectableText(
            const JsonEncoder.withIndent('  ').convert(payload),
            style: TextStyle(
              color: AC.tp,
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Color _colorFor(String name) {
    if (name.startsWith('invoice')) return AC.gold;
    if (name.startsWith('payment')) return AC.ok;
    if (name.startsWith('zatca')) return AC.warn;
    if (name.startsWith('anomaly')) return AC.err;
    if (name.startsWith('approval')) return AC.cyan;
    if (name.startsWith('comment') || name.startsWith('mention')) {
      return AC.cyan;
    }
    if (name.startsWith('module') || name.startsWith('role')) {
      return AC.warn;
    }
    if (name.startsWith('suggestion')) return AC.ok;
    return AC.ts;
  }

  String _shortTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inSeconds < 60) return 'الآن';
      if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
      if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
      return iso.substring(0, 16).replaceAll('T', ' ');
    } catch (_) {
      return iso;
    }
  }
}
