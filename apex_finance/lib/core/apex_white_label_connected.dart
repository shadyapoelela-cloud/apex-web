/// Network-connected wrapper around ApexWhiteLabelEditor.
///
/// Loads the tenant's branding from `/api/v1/tenant/branding`, lets the
/// admin edit it live, and persists via `PUT /api/v1/tenant/branding`.
/// The ApexWhiteLabelEditor stays a pure widget — this file is the only
/// place that talks to the backend.
///
/// Usage (drop into any settings screen):
/// ```dart
/// const ApexWhiteLabelConnected()
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'theme.dart' as core_theme;
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'apex_white_label.dart';
import 'design_tokens.dart';
import 'session.dart';
import 'theme.dart';

class ApexWhiteLabelConnected extends StatefulWidget {
  const ApexWhiteLabelConnected({super.key});

  @override
  State<ApexWhiteLabelConnected> createState() =>
      _ApexWhiteLabelConnectedState();
}

class _ApexWhiteLabelConnectedState extends State<ApexWhiteLabelConnected> {
  WhiteLabelConfig _current = WhiteLabelConfig();
  WhiteLabelConfig? _saved;      // last persisted copy for diff / revert
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Uri get _url => Uri.parse('$apiBase/api/v1/tenant/branding');

  Map<String, String> get _headers {
    final t = S.token;
    return {
      'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  Color _parseHex(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceAll('#', '');
    try {
      final v = int.parse(
        cleaned.length == 6 ? 'ff$cleaned' : cleaned,
        radix: 16,
      );
      return Color(v);
    } catch (_) {
      return fallback;
    }
  }

  String _toHex(Color c) {
    final r = (c.r * 255).round() & 0xff;
    final g = (c.g * 255).round() & 0xff;
    final b = (c.b * 255).round() & 0xff;
    final hex =
        ((r << 16) | (g << 8) | b).toRadixString(16).padLeft(6, '0');
    return '#${hex.toUpperCase()}';
  }

  WhiteLabelConfig _fromJson(Map<String, dynamic> m) {
    return WhiteLabelConfig(
      brandText: m['brand_text'] as String? ?? 'APEX',
      primary: _parseHex(m['primary_hex'] as String?, core_theme.AC.gold),
      secondary:
          _parseHex(m['secondary_hex'] as String?, const Color(0xFF2E75B6)),
      darkMode: m['dark_mode'] as bool? ?? true,
      radiusScale: (m['radius_scale'] as num?)?.toDouble() ?? 1.0,
      typeScale: (m['type_scale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> _toJson(WhiteLabelConfig c) => {
        'brand_text': c.brandText,
        'primary_hex': _toHex(c.primary),
        'secondary_hex': _toHex(c.secondary),
        'dark_mode': c.darkMode,
        'radius_scale': c.radiusScale,
        'type_scale': c.typeScale,
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(_url, headers: _headers);
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? const {};
      final cfg = _fromJson(data);
      if (!mounted) return;
      setState(() {
        _current = cfg;
        _saved = cfg;
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

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final res = await http.put(
        _url,
        headers: _headers,
        body: jsonEncode(_toJson(_current)),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final body = res.body.isNotEmpty ? res.body : 'HTTP ${res.statusCode}';
        throw Exception(body.length > 300 ? body.substring(0, 300) : body);
      }
      if (!mounted) return;
      setState(() {
        _saved = _current;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ إعدادات الواجهة'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('فشل الحفظ: $e'),
            duration: const Duration(seconds: 3)),
      );
    }
  }

  void _revert() {
    final s = _saved;
    if (s == null) return;
    setState(() => _current = s);
  }

  bool get _isDirty {
    final s = _saved;
    if (s == null) return false;
    return s.brandText != _current.brandText ||
        s.primary != _current.primary ||
        s.secondary != _current.secondary ||
        s.darkMode != _current.darkMode ||
        (s.radiusScale - _current.radiusScale).abs() > 1e-6 ||
        (s.typeScale - _current.typeScale).abs() > 1e-6;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ApexWhiteLabelEditor(
          initial: _current,
          onChanged: (c) => setState(() => _current = c),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Row(children: [
              Icon(Icons.error_outline, size: 14, color: AC.err),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_error!,
                    style: TextStyle(color: AC.err, fontSize: AppFontSize.xs)),
              ),
            ]),
          ),
        Row(
          children: [
            if (_isDirty)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 8, color: AC.gold),
                  const SizedBox(width: 4),
                  Text('تغييرات غير محفوظة',
                      style: TextStyle(
                          color: AC.ts, fontSize: AppFontSize.xs)),
                ]),
              ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('استعادة'),
              onPressed: (_saving || !_isDirty) ? null : _revert,
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: Text(_saving ? 'يُحفظ...' : 'حفظ'),
              onPressed: (_saving || !_isDirty) ? null : _save,
            ),
          ],
        ),
      ],
    );
  }
}
