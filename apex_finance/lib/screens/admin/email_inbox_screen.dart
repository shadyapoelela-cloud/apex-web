/// APEX — Email Inbox Status & Manual Poll
/// /admin/email-inbox — surface IMAP listener configuration + cron poll.
///
/// Wired to Wave 1C Phase L backend:
///   GET  /admin/email-inbox/status  — env-var inspection (no secrets)
///   POST /admin/email-inbox/poll    — fetch unread, save attachments,
///                                     emit `email.received` events
///
/// The IMAP listener picks up forwarded vendor invoices. Workflow rules
/// then turn those into draft bills via the AI extraction pipeline. This
/// screen is the operational surface — verify the inbox is configured,
/// trigger a one-shot poll, and read back what was fetched.
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';

class EmailInboxScreen extends StatefulWidget {
  const EmailInboxScreen({super.key});
  @override
  State<EmailInboxScreen> createState() => _EmailInboxScreenState();
}

class _EmailInboxScreenState extends State<EmailInboxScreen> {
  bool _loading = true;
  bool _polling = false;
  String? _error;
  Map<String, dynamic> _status = const {};
  Map<String, dynamic>? _lastPoll;
  final _maxCtrl = TextEditingController(text: '25');

  @override
  void initState() {
    super.initState();
    _ensureSecretThenLoad();
  }

  @override
  void dispose() {
    _maxCtrl.dispose();
    super.dispose();
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
    final r = await ApiService.emailInboxStatus();
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _status = Map<String, dynamic>.from(r.data as Map);
    } else {
      _error = r.error ?? 'تعذّر تحميل الإعدادات';
    }
    setState(() => _loading = false);
  }

  Future<void> _poll() async {
    if (_status['configured'] != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AC.warn,
          content: Text(
            'لم يُكوَّن صندوق البريد. عيّن EMAIL_INBOX_HOST و EMAIL_INBOX_USER و EMAIL_INBOX_PASS أولاً.',
            style: TextStyle(color: AC.tp),
          ),
        ),
      );
      return;
    }
    setState(() {
      _polling = true;
      _error = null;
    });
    final max = int.tryParse(_maxCtrl.text.trim());
    final r = await ApiService.emailInboxPoll(maxMessages: max);
    if (!mounted) return;
    if (r.success && r.data is Map) {
      _lastPoll = Map<String, dynamic>.from(r.data as Map);
    } else {
      _error = r.error ?? 'فشل سحب الرسائل';
    }
    setState(() => _polling = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'صندوق البريد للفواتير',
            actions: [
              ApexToolbarAction(
                label: 'تحديث',
                icon: Icons.refresh,
                onPressed: _load,
              ),
            ],
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) return Center(child: CircularProgressIndicator(color: AC.gold));
    final configured = _status['configured'] == true;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _statusBanner(configured),
          const SizedBox(height: AppSpacing.md),
          _configCard(configured),
          const SizedBox(height: AppSpacing.md),
          _pollControl(configured),
          const SizedBox(height: AppSpacing.md),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AC.err.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AC.err),
              ),
              child: Text(_error!, style: TextStyle(color: AC.err)),
            ),
          if (_lastPoll != null) _pollResult(),
        ],
      ),
    );
  }

  Widget _statusBanner(bool configured) {
    final color = configured ? AC.ok : AC.warn;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.18), AC.navy2],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(
          configured ? Icons.mark_email_read : Icons.mark_email_unread,
          color: color,
          size: 32,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              configured ? 'صندوق البريد جاهز' : 'لم يُكوَّن صندوق البريد',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: AppFontSize.xl,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              configured
                  ? 'يمكنك الآن سحب الرسائل يدوياً أو ربط cron داخلي'
                  : 'عيّن متغيّرات البيئة EMAIL_INBOX_HOST / USER / PASS',
              style: TextStyle(color: AC.ts, fontSize: 12),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _configCard(bool configured) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('الإعدادات الحالية',
            style: TextStyle(
                color: AC.gold, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 12),
        _row('EMAIL_INBOX_HOST', _status['host']?.toString() ?? '—'),
        _row('EMAIL_INBOX_USER', _status['user']?.toString() ?? '—'),
        _row('EMAIL_INBOX_FOLDER', _status['folder']?.toString() ?? 'INBOX'),
        _row('SSL', (_status['use_ssl'] == true) ? 'مُفعّل' : 'متوقّف'),
        _row('سقف الرسائل لكل دورة', _status['max_per_run']?.toString() ?? '25'),
        _row('configured', configured ? 'نعم' : 'لا',
            color: configured ? AC.ok : AC.err),
      ]),
    );
  }

  Widget _row(String k, String v, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(
          width: 220,
          child: Text(k,
              style: TextStyle(
                color: AC.ts,
                fontSize: 11,
                fontFamily: 'monospace',
              )),
        ),
        Expanded(
          child: Text(
            v,
            style: TextStyle(
              color: color ?? AC.tp,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ]),
    );
  }

  Widget _pollControl(bool configured) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.bdr),
      ),
      child: Row(children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: _maxCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AC.tp, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'max_messages',
              labelStyle: TextStyle(color: AC.ts, fontSize: 11),
              isDense: true,
              filled: true,
              fillColor: AC.navy3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: (!configured || _polling) ? null : _poll,
          icon: _polling
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AC.tp),
                )
              : const Icon(Icons.download, size: 16),
          label: const Text('سحب الرسائل غير المقروءة'),
        ),
      ]),
    );
  }

  Widget _pollResult() {
    final fetched = _lastPoll!['fetched'] ?? _lastPoll!['count'] ?? 0;
    final saved = _lastPoll!['attachments_saved'] ?? 0;
    final emitted = _lastPoll!['events_emitted'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.cyan.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.history, color: AC.cyan, size: 18),
          const SizedBox(width: 6),
          Text('آخر دورة سحب',
              style: TextStyle(
                  color: AC.cyan, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 6, children: [
          _stat('رسائل مسحوبة', fetched.toString(), AC.tp),
          _stat('مرفقات محفوظة', saved.toString(), AC.gold),
          _stat('أحداث منبعثة', emitted.toString(), AC.cyan),
        ]),
      ]),
    );
  }

  Widget _stat(String label, String value, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$label: ', style: TextStyle(color: AC.ts, fontSize: 11)),
          Text(
            value,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
          ),
        ]),
      );
}
