/// APEX — API Keys Management
/// /admin/api-keys — issue + revoke programmatic access keys.
///
/// Wired to the API Keys backend (Wave 1F Phase X):
///   GET    /admin/api-keys
///   POST   /admin/api-keys                    — returns raw_secret ONCE
///   PATCH  /admin/api-keys/{id}
///   POST   /admin/api-keys/{id}/revoke
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class ApiKeysScreen extends StatefulWidget {
  const ApiKeysScreen({super.key});
  @override
  State<ApiKeysScreen> createState() => _ApiKeysScreenState();
}

class _ApiKeysScreenState extends State<ApiKeysScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _keys = [];
  bool _includeRevoked = false;

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
    final res = await ApiService.apiKeysList(includeRevoked: _includeRevoked);
    if (!mounted) return;
    if (res.success) {
      final raw = (res.data is Map ? res.data['keys'] : null) ?? const [];
      _keys = (raw as List).cast<Map<String, dynamic>>();
    } else {
      _error = res.error ?? 'فشل';
    }
    setState(() => _loading = false);
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    final scopesCtrl = TextEditingController(text: 'read:invoices,read:reports');
    final descCtrl = TextEditingController();
    final tenantCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إصدار مفتاح API جديد', style: TextStyle(color: AC.tp)),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _formField(nameCtrl, 'اسم المفتاح', hint: 'مثل: Reporting Bot'),
            const SizedBox(height: 10),
            _formField(scopesCtrl, 'النطاقات (مفصولة بفاصلة)',
                hint: 'read:invoices, read:reports, *'),
            const SizedBox(height: 10),
            _formField(tenantCtrl, 'tenant_id (اختياري)'),
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
            child: Text('إصدار', style: TextStyle(color: AC.btnFg)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final scopes = scopesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final res = await ApiService.apiKeysCreate({
      'name': nameCtrl.text.trim(),
      'scopes': scopes,
      if (tenantCtrl.text.trim().isNotEmpty) 'tenant_id': tenantCtrl.text.trim(),
      if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
    });
    if (!mounted) return;
    if (res.success && res.data is Map && (res.data as Map)['raw_secret'] != null) {
      await _showCreatedKey((res.data as Map)['raw_secret'].toString());
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.err, content: Text(res.error ?? 'فشل')),
      );
    }
  }

  Future<void> _showCreatedKey(String raw) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Row(children: [
          Icon(Icons.warning_amber, color: AC.warn, size: 22),
          const SizedBox(width: 8),
          Text('احفظ هذا المفتاح الآن', style: TextStyle(color: AC.tp, fontSize: 16)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'هذا هو الـ secret الكامل — لن يظهر مرة أخرى. انسخه واحفظه في مكان آمن.',
            style: TextStyle(color: AC.ts, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AC.navy3,
              border: Border.all(color: AC.gold.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: SelectableText(
              raw,
              style: TextStyle(
                color: AC.gold,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: raw));
              if (!ctx.mounted) return;
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(backgroundColor: AC.ok, content: const Text('📋 نُسخ')),
              );
            },
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('نسخ'),
          ),
        ]),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('فهمت — حفظته'),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(Map<String, dynamic> k) async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AC.navy2,
        title: Text('إلغاء المفتاح', style: TextStyle(color: AC.tp)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'إلغاء "${k['name']}" نهائياً. لا يمكن التراجع.',
            style: TextStyle(color: AC.ts),
          ),
          const SizedBox(height: 10),
          _formField(reasonCtrl, 'السبب (اختياري)'),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('إلغاء', style: TextStyle(color: AC.ts)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AC.err),
            child: const Text('إلغاء المفتاح'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final res = await ApiService.apiKeysRevoke(
      k['id'] as String,
      reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
    );
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AC.warn, content: const Text('🚫 أُلغي المفتاح')),
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
            title: 'مفاتيح API',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
              ApexToolbarAction(
                label: 'إصدار',
                icon: Icons.add_moderator,
                primary: true,
                onPressed: _create,
              ),
            ],
          ),
          Container(
            color: AC.navy2,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(children: [
              Checkbox(
                value: _includeRevoked,
                onChanged: (v) {
                  setState(() => _includeRevoked = v ?? false);
                  _load();
                },
                checkColor: AC.btnFg,
                activeColor: AC.gold,
              ),
              Text('عرض المفاتيح المُلغاة', style: TextStyle(color: AC.ts, fontSize: 12)),
            ]),
          ),
          Expanded(child: _body()),
        ],
      ),
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
    if (_keys.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.vpn_key_outlined, color: AC.ts, size: 64),
          const SizedBox(height: 12),
          Text('لا توجد مفاتيح بعد', style: TextStyle(color: AC.tp, fontSize: 14)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add_moderator),
            label: const Text('إصدار أول مفتاح'),
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
        itemCount: _keys.length,
        itemBuilder: (ctx, i) => _card(_keys[i]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> k) {
    final revoked = k['revoked_at'] != null;
    final enabled = k['enabled'] == true && !revoked;
    final scopes = (k['scopes'] as List?)?.cast<String>() ?? const [];
    final useCount = k['use_count'] ?? 0;
    final lastUsed = k['last_used_at']?.toString().split('T').first ?? '—';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: revoked
              ? AC.err.withValues(alpha: 0.3)
              : enabled ? AC.ok.withValues(alpha: 0.4) : AC.bdr,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            revoked ? Icons.vpn_key_off : Icons.vpn_key,
            color: revoked ? AC.err : AC.gold,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                k['name']?.toString() ?? '',
                style: TextStyle(
                  color: AC.tp,
                  fontWeight: FontWeight.bold,
                  fontSize: AppFontSize.md,
                ),
              ),
              Text(
                k['prefix']?.toString() ?? '',
                style: TextStyle(
                  color: AC.ts,
                  fontFamily: 'monospace',
                  fontSize: AppFontSize.xs,
                ),
              ),
            ]),
          ),
          if (revoked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AC.err.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('مُلغى', style: TextStyle(color: AC.err, fontSize: 10)),
            ),
        ]),
        if ((k['description'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(k['description'].toString(), style: TextStyle(color: AC.ts, fontSize: 11)),
        ],
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 4, children: [
          for (final s in scopes) _miniChip(s, AC.cyan),
          _miniChip('$useCount استخدام', AC.tp),
          _miniChip('آخر: $lastUsed', AC.ts),
          _miniChip('${k['rate_limit_per_minute'] ?? 60}/دقيقة', AC.warn),
        ]),
        if (!revoked) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => _revoke(k),
              icon: Icon(Icons.block, color: AC.err, size: 14),
              label: Text('إلغاء المفتاح', style: TextStyle(color: AC.err)),
              style: OutlinedButton.styleFrom(side: BorderSide(color: AC.err)),
            ),
          ),
        ],
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
          color: c,
          fontSize: 10,
          fontFamily: text.contains(':') ? 'monospace' : null,
        ),
      ),
    );
  }
}
