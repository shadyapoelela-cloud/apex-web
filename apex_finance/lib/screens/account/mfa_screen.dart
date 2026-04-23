/// APEX — MFA (TOTP 2FA) Settings Screen
/// ════════════════════════════════════════════════════════════════════
/// Exposes the backend's existing /auth/totp/* endpoints to end users.
/// Flow:
///   1. User taps "تفعيل المصادقة الثنائية" → /auth/totp/setup
///      returns provisioning_uri (otpauth://) + secret + recovery codes.
///   2. User scans the QR (or enters secret manually) in Google
///      Authenticator / Microsoft Authenticator / Authy.
///   3. User enters a 6-digit code → /auth/totp/verify activates 2FA.
///   4. Recovery codes are shown ONCE; user must save them offline.
///
/// Screen uses AutoDisposeMixin for safe resource cleanup.
/// ════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/auto_dispose_mixin.dart';
import '../../core/apex_sticky_toolbar.dart';

class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key});
  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen>
    with AutoDisposeMixin<MfaScreen> {
  bool _loading = true;
  bool _isEnabled = false;
  DateTime? _enabledAt;

  // Setup state (after user clicks "Enable").
  String? _provisioningUri;
  String? _secret;
  List<String> _recoveryCodes = const [];
  bool _setupInProgress = false;

  late final _codeCtl = track(TextEditingController());
  String? _verifyError;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    final res = await ApiService.totpStatus();
    if (!mounted) return;
    if (res.success && res.data is Map) {
      final d = res.data as Map;
      setState(() {
        _isEnabled = d['enabled'] == true;
        final at = d['enabled_at'];
        _enabledAt = at is String ? DateTime.tryParse(at) : null;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _startSetup() async {
    setState(() {
      _setupInProgress = true;
      _verifyError = null;
    });
    final res = await ApiService.totpSetup();
    if (!mounted) return;
    if (res.success && res.data is Map) {
      final d = res.data as Map;
      setState(() {
        _provisioningUri = d['provisioning_uri']?.toString();
        _secret = d['secret_base32']?.toString();
        _recoveryCodes = (d['recovery_codes'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [];
      });
    } else {
      setState(() {
        _verifyError = res.error ?? 'تعذّر بدء الإعداد';
        _setupInProgress = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtl.text.trim();
    if (code.isEmpty) {
      setState(() => _verifyError = 'أدخل الرمز');
      return;
    }
    setState(() {
      _verifying = true;
      _verifyError = null;
    });
    final res = await ApiService.totpVerify(code);
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _isEnabled = true;
        _setupInProgress = false;
        _verifying = false;
        _codeCtl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('تم تفعيل المصادقة الثنائية ✓'),
            backgroundColor: AC.ok),
      );
      await _loadStatus();
    } else {
      setState(() {
        _verifyError = res.error ?? 'رمز غير صحيح';
        _verifying = false;
      });
    }
  }

  Future<void> _disable() async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctl = TextEditingController();
        return AlertDialog(
          backgroundColor: AC.surface,
          title: Text('تعطيل المصادقة الثنائية',
              style: TextStyle(color: AC.textStrong, fontSize: 15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('أدخل رمزاً من تطبيق المصادقة أو أحد رموز الاسترداد:',
                style: TextStyle(color: AC.textMedium, fontSize: 12.5)),
            const SizedBox(height: 10),
            TextField(
              controller: ctl,
              autofocus: true,
              style: TextStyle(color: AC.textStrong),
              decoration: InputDecoration(
                hintText: '123456 أو رمز استرداد',
                filled: true,
                fillColor: AC.sidebarBgElevated,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(DS.rMd)),
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: TextStyle(color: AC.textMedium))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctl.text.trim()),
              style: ElevatedButton.styleFrom(backgroundColor: AC.err, foregroundColor: Colors.white),
              child: const Text('تعطيل'),
            ),
          ],
        );
      },
    );
    if (code == null || code.isEmpty) return;
    final res = await ApiService.totpDisable(code);
    if (!mounted) return;
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('تم تعطيل المصادقة الثنائية'),
            backgroundColor: AC.warn),
      );
      await _loadStatus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.error ?? 'فشل التعطيل'), backgroundColor: AC.err),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        ApexStickyToolbar(
          title: 'المصادقة الثنائية (MFA / TOTP)',
          actions: [
            ApexToolbarAction(
              label: 'تحديث',
              icon: Icons.refresh_rounded,
              onPressed: _loading ? null : _loadStatus,
            ),
          ],
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: AC.gold))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _body(),
                ),
        ),
      ]),
    );
  }

  Widget _body() {
    if (_setupInProgress && _provisioningUri != null) {
      return _setupCard();
    }
    return _statusCard();
  }

  Widget _statusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AC.surface,
        borderRadius: BorderRadius.circular(DS.rLg),
        border: Border.all(color: AC.sidebarBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_isEnabled ? AC.ok : AC.warn).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(DS.rMd),
            ),
            child: Icon(
              _isEnabled ? Icons.verified_user_rounded : Icons.shield_outlined,
              color: _isEnabled ? AC.ok : AC.warn,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    _isEnabled
                        ? 'المصادقة الثنائية مُفعَّلة'
                        : 'المصادقة الثنائية غير مُفعَّلة',
                    style: TextStyle(
                        color: AC.textStrong,
                        fontSize: 15,
                        fontWeight: DS.fwBold)),
                const SizedBox(height: 3),
                Text(
                    _isEnabled
                        ? (_enabledAt != null
                            ? 'مُفعَّلة منذ ${_enabledAt!.toLocal().toString().substring(0, 16)}'
                            : 'الحماية الإضافية نشطة لحسابك')
                        : 'أضف طبقة حماية ثانية — كل تسجيل دخول يتطلّب رمزاً من تطبيق المصادقة',
                    style: TextStyle(
                        color: AC.textMedium, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 20),
        if (_isEnabled)
          OutlinedButton.icon(
            onPressed: _disable,
            icon: const Icon(Icons.lock_open_rounded, size: 18),
            label: const Text('تعطيل المصادقة الثنائية'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AC.err,
              side: BorderSide(color: AC.err),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            ),
          )
        else
          ElevatedButton.icon(
            onPressed: _startSetup,
            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
            label: const Text('تفعيل المصادقة الثنائية'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AC.gold,
              foregroundColor: AC.btnFg,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
            ),
          ),
        if (_verifyError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AC.err.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(DS.rMd),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded, color: AC.err, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_verifyError!,
                    style: TextStyle(color: AC.err, fontSize: 12.5)),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _setupCard() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AC.surface,
          borderRadius: BorderRadius.circular(DS.rLg),
          border: Border.all(color: AC.gold),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.qr_code_2_rounded, color: AC.gold, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text('الخطوة 1: امسح رمز QR',
                  style: TextStyle(
                      color: AC.textStrong,
                      fontSize: 14.5,
                      fontWeight: DS.fwBold)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
              'افتح تطبيق مصادقة (Google Authenticator / Microsoft Authenticator / Authy) '
              'وامسح رمز QR أدناه أو أدخل المفتاح السري يدوياً.',
              style: TextStyle(color: AC.textMedium, fontSize: 12, height: 1.6)),
          const SizedBox(height: 12),
          // Embedded QR — use Google Charts API since we don't have a local QR lib.
          if (_provisioningUri != null)
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=${Uri.encodeComponent(_provisioningUri!)}',
                  width: 200,
                  height: 200,
                  errorBuilder: (_, __, ___) => SizedBox(
                    width: 200,
                    height: 200,
                    child: Center(
                      child: Text('QR غير متاح — استخدم المفتاح أدناه',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AC.textMedium, fontSize: 11)),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          if (_secret != null)
            Row(children: [
              Icon(Icons.vpn_key_rounded, color: AC.sidebarItemDim, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: SelectableText(_secret!,
                    style: TextStyle(
                      color: AC.textStrong,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      letterSpacing: 1.2,
                    )),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, color: AC.gold, size: 18),
                tooltip: 'نسخ المفتاح',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _secret!));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم النسخ')),
                    );
                  }
                },
              ),
            ]),
        ]),
      ),
      const SizedBox(height: 14),
      // Step 2: enter code
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AC.surface,
          borderRadius: BorderRadius.circular(DS.rLg),
          border: Border.all(color: AC.sidebarBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('الخطوة 2: أدخل رمز 6 أرقام من تطبيق المصادقة',
              style: TextStyle(
                  color: AC.textStrong,
                  fontSize: 14,
                  fontWeight: DS.fwBold)),
          const SizedBox(height: 10),
          TextField(
            controller: _codeCtl,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AC.textStrong,
              fontSize: 22,
              letterSpacing: 8,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              hintText: '– – – – – –',
              filled: true,
              fillColor: AC.sidebarBgElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DS.rMd),
                borderSide: BorderSide(color: AC.sidebarBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(DS.rMd),
                borderSide: BorderSide(color: AC.gold, width: 2),
              ),
            ),
            onSubmitted: (_) => _verifyCode(),
          ),
          if (_verifyError != null) ...[
            const SizedBox(height: 8),
            Text(_verifyError!,
                style: TextStyle(color: AC.err, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _verifying ? null : _verifyCode,
            icon: _verifying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_verifying ? 'جارٍ التحقّق...' : 'تفعيل المصادقة الثنائية'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AC.ok,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      // Step 3: recovery codes
      if (_recoveryCodes.isNotEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AC.warn.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(DS.rLg),
            border: Border.all(color: AC.warn.withValues(alpha: 0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.warning_amber_rounded, color: AC.warn, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('رموز الاسترداد — احفظها الآن (لن تُعرض مرة أخرى)',
                    style: TextStyle(
                        color: AC.warn,
                        fontSize: 13.5,
                        fontWeight: DS.fwBold)),
              ),
            ]),
            const SizedBox(height: 10),
            Text(
                'استخدم أيّ من هذه الرموز مرّة واحدة إذا فقدت جهازك. احفظها في مكان آمن offline.',
                style: TextStyle(color: AC.textMedium, fontSize: 11.5, height: 1.5)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _recoveryCodes
                  .map((c) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AC.surface,
                          borderRadius: BorderRadius.circular(DS.rSm),
                          border: Border.all(
                              color: AC.warn.withValues(alpha: 0.3)),
                        ),
                        child: SelectableText(c,
                            style: TextStyle(
                              color: AC.textStrong,
                              fontSize: 13,
                              fontFamily: 'monospace',
                              letterSpacing: 1.5,
                            )),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                    ClipboardData(text: _recoveryCodes.join('\n')));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ جميع الرموز')),
                  );
                }
              },
              icon: const Icon(Icons.copy_all_rounded, size: 16),
              label: const Text('نسخ كل الرموز'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AC.warn,
                side: BorderSide(color: AC.warn),
              ),
            ),
          ]),
        ),
    ]);
  }
}
