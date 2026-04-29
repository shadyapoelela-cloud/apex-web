/// APEX — Webhook Subscriptions Console
/// /admin/webhooks — manage external system event subscriptions.
///
/// Wired to the Webhook Subscriptions backend (Wave 1E Phase T):
///   GET    /admin/webhooks
///   POST   /admin/webhooks            { event_pattern, target_url, secret?, … }
///   PATCH  /admin/webhooks/{id}       { enabled?, target_url?, … }
///   DELETE /admin/webhooks/{id}
///   POST   /admin/webhooks/{id}/reset
///   POST   /admin/webhooks/{id}/test  { event, payload }
library;

import 'dart:convert';

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class WebhooksScreen extends StatefulWidget {
  const WebhooksScreen({super.key});
  @override
  State<WebhooksScreen> createState() => _WebhooksScreenState();
}

class _WebhooksScreenState extends State<WebhooksScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _subs = [];
  Map<String, dynamic>? _stats;

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
    final res = await ApiService.webhooksList();
    final st = await ApiService.webhooksStats();
    if (!mounted) return;
    if (res.success) {
      final raw = (res.data is Map ? res.data['subscriptions'] : null) ?? const [];
      _subs = (raw as List).cast<Map<String, dynamic>>();
    } else {
      _error = res.error ?? 'فشل تحميل الاشتراكات';
    }
    if (st.success) {
      _stats = st.data is Map<String, dynamic> ? st.data as Map<String, dynamic> : null;
    }
    setState(() => _loading = false);
  }

  Future<void> _create() async {
    final eventCtrl = TextEditingController(text: 'invoice.*');
    final urlCtrl = TextEditingController(text: 'https://');
    final secretCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إنشاء اشتراك جديد', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _formField(eventCtrl, 'النمط (event_pattern)', hint: 'مثل: invoice.* أو payment.received'),
            const SizedBox(height: 10),
            _formField(urlCtrl, 'Target URL', hint: 'https://...'),
            const SizedBox(height: 10),
            _formField(secretCtrl, 'الـ secret (HMAC) — اختياري', obscure: true),
            const SizedBox(height: 10),
            _formField(descCtrl, 'الوصف (اختياري)'),
          ]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.gold),
            child: Text('إنشاء', style: TextStyle(color: AC.btnFg)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.webhooksCreate({
      'event_pattern': eventCtrl.text.trim(),
      'target_url': urlCtrl.text.trim(),
      if (secretCtrl.text.trim().isNotEmpty) 'secret': secretCtrl.text.trim(),
      if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
    });
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.ok, content: const Text('✅ تم إنشاء الاشتراك')),
      );
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
    }
  }

  Future<void> _toggle(Map<String, dynamic> sub) async {
    final id = sub['id'] as String;
    final newEnabled = !(sub['enabled'] == true);
    final res = await ApiService.webhooksUpdate(id, {'enabled': newEnabled});
    if (!mounted) return;
    if (res.success) {
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
    }
  }

  Future<void> _testDelivery(Map<String, dynamic> sub) async {
    final id = sub['id'] as String;
    final ctrl = TextEditingController(text: '{}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('اختبار التسليم', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: ctrl,
            maxLines: 6,
            style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 11),
            decoration: InputDecoration(
              labelText: 'JSON Payload',
              labelStyle: TextStyle(color: AC.ts),
              filled: true,
              fillColor: AC.navy3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    Map<String, dynamic> payload;
    try {
      final t = ctrl.text.trim();
      payload = t.isEmpty
          ? <String, dynamic>{}
          : (jsonDecode(t) as Map).cast<String, dynamic>();
    } catch (_) {
      payload = <String, dynamic>{};
    }
    final res = await ApiService.webhooksTest(id, payload: payload);
    if (!mounted) return;
    final delivered = res.success
        ? (((res.data as Map)['subscription'] as Map?)?['last_status'] ?? 'unknown')
        : 'failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: res.success ? AC.cyan : AC.err,
        content: Text('Last status: $delivered'),
      ),
    );
    _load();
  }

  Future<void> _delete(Map<String, dynamic> sub) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('حذف الاشتراك', style: TextStyle(color: AC.tp)),
        content: Text(
          'حذف ${sub['target_url'] ?? ''}؟ لا يمكن التراجع.',
          style: TextStyle(color: AC.ts),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.err),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.webhooksDelete(sub['id'] as String);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.ok, content: const Text('🗑 حُذف')),
      );
      _load();
    }
  }

  Future<void> _reset(Map<String, dynamic> sub) async {
    final res = await ApiService.webhooksReset(sub['id'] as String);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.ok, content: const Text('🔄 reset success')),
      );
      _load();
    }
  }

  Widget _formField(TextEditingController c, String label,
      {bool obscure = false, String? hint}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: TextStyle(color: AC.tp, fontFamily: 'monospace', fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AC.ts, fontSize: 12),
        hintStyle: TextStyle(color: AC.ts.withValues(alpha: 0.5), fontSize: 11),
        filled: true,
        fillColor: AC.navy3,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'اشتراكات Webhooks',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
              ApexToolbarAction(
                label: 'جديد',
                icon: Icons.add,
                primary: true,
                onPressed: _create,
              ),
            ],
          ),
          if (_stats != null) _statsBar(_stats!),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _statsBar(Map<String, dynamic> s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: AC.navy2,
      child: Wrap(spacing: 8, runSpacing: 4, children: [
        _statChip('إجمالي', s['subscriptions_total'].toString(), AC.tp),
        _statChip('مُفعّل', s['subscriptions_enabled'].toString(), AC.ok),
        _statChip('متوقّف', s['subscriptions_paused'].toString(), AC.warn),
        _statChip('تسليمات', s['deliveries_total'].toString(), AC.cyan),
        _statChip('فشل', s['deliveries_failed'].toString(), AC.err),
      ]),
    );
  }

  Widget _statChip(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: TextStyle(color: AC.ts, fontSize: 11)),
        Text(value, style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }

  Widget _body() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AC.gold));
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: TextStyle(color: AC.err)),
        ),
      );
    }
    if (_subs.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.webhook, color: AC.ts, size: 64),
          const SizedBox(height: 12),
          Text('لا توجد اشتراكات بعد', style: TextStyle(color: AC.tp, fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('إنشاء أول اشتراك'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
            ),
          ),
        ]),
      );
    }
    return RefreshIndicator(
      color: AC.gold,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _subs.length,
        itemBuilder: (ctx, i) => _card(_subs[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> s) {
    final enabled = s['enabled'] == true;
    final consecutiveFails = (s['consecutive_failures'] ?? 0) as int;
    final isPaused = !enabled && consecutiveFails > 0;
    final lastError = s['last_error']?.toString();
    final lastStatus = s['last_status'];
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: enabled ? AC.ok.withValues(alpha: 0.4) : (isPaused ? AC.warn : AC.bdr),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.webhook, color: AC.gold, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                s['target_url']?.toString() ?? '',
                style: TextStyle(
                    color: AC.tp,
                    fontWeight: FontWeight.bold,
                    fontSize: AppFontSize.md,
                    fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
              if ((s['description'] ?? '').toString().isNotEmpty)
                Text(s['description'].toString(), style: TextStyle(color: AC.ts, fontSize: 11)),
            ]),
          ),
          Switch(value: enabled, activeColor: AC.ok, onChanged: (_) => _toggle(s)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 4, children: [
          _miniChip('event: ${s['event_pattern']}', AC.warn),
          if (s['has_secret'] == true) _miniChip('🔐 HMAC', AC.cyan),
          _miniChip('${s['deliveries_total'] ?? 0} delivered', AC.tp),
          if ((s['deliveries_failed'] ?? 0) as int > 0)
            _miniChip('${s['deliveries_failed']} failed', AC.err),
          if (lastStatus != null) _miniChip('last: $lastStatus', AC.ts),
        ]),
        if (lastError != null && lastError.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AC.err.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              'آخر خطأ: $lastError',
              style: TextStyle(color: AC.err, fontSize: 10.5),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          OutlinedButton.icon(
            onPressed: () => _testDelivery(s),
            icon: const Icon(Icons.send, size: 14),
            label: const Text('اختبار'),
            style: OutlinedButton.styleFrom(
                side: BorderSide(color: AC.cyan), foregroundColor: AC.cyan),
          ),
          if (isPaused) ...[
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _reset(s),
              icon: const Icon(Icons.restart_alt, size: 14),
              label: const Text('إعادة تشغيل'),
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AC.warn), foregroundColor: AC.warn),
            ),
          ],
          const Spacer(),
          IconButton(
            onPressed: () => _delete(s),
            icon: Icon(Icons.delete_outline, color: AC.err, size: 18),
            tooltip: 'حذف',
          ),
        ]),
      ]),
    );
  }

  Widget _miniChip(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: c, fontSize: 10, fontFamily: text.contains(':') ? 'monospace' : null),
      ),
    );
  }
}
