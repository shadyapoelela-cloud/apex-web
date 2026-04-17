/// APEX Auto-Save — drop-in mixin for form screens.
///
/// Contract:
///   1. State class mixes in `ApexAutoSaveMixin<WidgetType>`.
///   2. Implements `String get autoSaveKey` — uniquely identifies this form.
///   3. Implements `Map<String, dynamic> snapshot()` — returns current form
///      values as a JSON-safe map.
///   4. Implements `void restore(Map<String, dynamic> data)` — applies a
///      saved snapshot to the form widgets.
///   5. Calls `markDirty()` from every field change callback.
///
/// The mixin handles:
///   - 2s debounced save to SharedPreferences.
///   - 7-day expiry cleanup on load.
///   - Offering "resume draft" on first build if a draft exists.
///   - Exposing `lastSavedAt` for UI badges.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Duration _kDebounce = Duration(seconds: 2);
const Duration _kMaxAge = Duration(days: 7);
const String _kKeyPrefix = 'apex_draft_';

mixin ApexAutoSaveMixin<T extends StatefulWidget> on State<T> {
  Timer? _debounceTimer;
  DateTime? _lastSavedAt;
  bool _hasDraft = false;
  bool _dirty = false;

  /// Unique key for this form (e.g. "invoice_new", "client_wizard:$id").
  String get autoSaveKey;

  /// Snapshot current form state.
  Map<String, dynamic> snapshot();

  /// Restore a previously saved snapshot.
  void restore(Map<String, dynamic> data);

  /// Whether this form has pending unsaved changes.
  bool get isDirty => _dirty;

  /// Timestamp of the last successful auto-save (null if nothing saved yet).
  DateTime? get lastSavedAt => _lastSavedAt;

  /// Whether a draft exists on disk (checked once at init).
  bool get hasDraft => _hasDraft;

  @override
  void initState() {
    super.initState();
    _loadDraftMeta();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Call whenever any tracked field changes.
  void markDirty() {
    _dirty = true;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_kDebounce, _save);
  }

  /// Manual "save now" that skips the debounce.
  Future<void> saveNow() async {
    _debounceTimer?.cancel();
    await _save();
  }

  /// Call after a successful submit to wipe the draft.
  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKeyPrefix + autoSaveKey);
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _hasDraft = false;
      _lastSavedAt = null;
    });
  }

  /// Restore the saved draft into the form, if one exists.
  Future<bool> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKeyPrefix + autoSaveKey);
    if (raw == null) return false;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(decoded['_ts'] as String? ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > _kMaxAge) {
        await clearDraft();
        return false;
      }
      final data = (decoded['data'] as Map?)?.cast<String, dynamic>() ?? {};
      restore(data);
      if (mounted) {
        setState(() {
          _lastSavedAt = savedAt;
          _dirty = false;
          _hasDraft = true;
        });
      }
      return true;
    } catch (_) {
      await clearDraft();
      return false;
    }
  }

  Future<void> _loadDraftMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKeyPrefix + autoSaveKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(decoded['_ts'] as String? ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > _kMaxAge) {
        await prefs.remove(_kKeyPrefix + autoSaveKey);
        return;
      }
      if (mounted) {
        setState(() {
          _hasDraft = true;
          _lastSavedAt = savedAt;
        });
      }
    } catch (_) {
      await prefs.remove(_kKeyPrefix + autoSaveKey);
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final data = snapshot();
      final payload = jsonEncode({
        '_ts': now.toIso8601String(),
        'data': data,
      });
      await prefs.setString(_kKeyPrefix + autoSaveKey, payload);
      if (!mounted) return;
      setState(() {
        _lastSavedAt = now;
        _dirty = false;
      });
    } catch (_) {
      // Non-fatal — auto-save should never surface errors to the user.
    }
  }
}

/// Small status chip for "Draft saved at HH:MM" indicator.
class ApexAutoSaveStatus extends StatelessWidget {
  final bool dirty;
  final DateTime? lastSavedAt;
  final TextStyle? style;

  const ApexAutoSaveStatus({
    super.key,
    required this.dirty,
    required this.lastSavedAt,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final t = lastSavedAt;
    final text = dirty
        ? 'تغييرات غير محفوظة'
        : t != null
            ? 'مسودة محفوظة ${_fmtTime(t)}'
            : '';
    return AnimatedOpacity(
      opacity: text.isEmpty ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            dirty ? Icons.edit_note : Icons.cloud_done_outlined,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(text, style: style),
        ],
      ),
    );
  }

  String _fmtTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return 'الساعة $hh:$mm';
  }
}
