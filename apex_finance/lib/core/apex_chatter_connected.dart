/// Network-connected wrapper around ApexChatter.
///
/// Fetches activity entries from `/api/v1/activity/{entity_type}/{id}`
/// and posts comments to `/api/v1/activity/{entity_type}/{id}/comment`.
/// Auto-refreshes every 30 seconds and optimistically prepends new
/// comments so the UI feels instant.
///
/// Usage:
/// ```dart
/// ApexChatterConnected(
///   entityType: 'client',
///   entityId: client.id,
/// )
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'apex_chatter.dart';
import 'apex_ws_client.dart';
import 'design_tokens.dart';
import 'session.dart';
import 'theme.dart';

class ApexChatterConnected extends StatefulWidget {
  final String entityType;
  final String entityId;

  /// Optional refresh cadence. Default 30 s — set to Duration.zero to
  /// disable the timer (useful for tests).
  final Duration refreshEvery;

  const ApexChatterConnected({
    super.key,
    required this.entityType,
    required this.entityId,
    this.refreshEvery = const Duration(seconds: 30),
  });

  @override
  State<ApexChatterConnected> createState() => _ApexChatterConnectedState();
}

class _ApexChatterConnectedState extends State<ApexChatterConnected> {
  List<ChatterEntry> _entries = const [];
  bool _loading = true;
  String? _error;
  Timer? _timer;
  ApexWsSubscription? _wsSub;

  @override
  void initState() {
    super.initState();
    _load();
    // Realtime: subscribe to this entity's channel. When the server
    // publishes an activity event, append it to the local list so the
    // user sees it without waiting for the 30s polling cycle.
    _wsSub = ApexWsClient.instance
        .subscribe('entity:${widget.entityType}:${widget.entityId}');
    _wsSub!.events.listen(_onWsEvent);
    // Keep polling as a safety net in case the socket drops and
    // reconnect fails — but throttle it: polling was every 30 s, with
    // WS live we can relax to every 2 minutes.
    final pollEvery = widget.refreshEvery > Duration.zero
        ? Duration(milliseconds: widget.refreshEvery.inMilliseconds * 4)
        : Duration.zero;
    if (pollEvery > Duration.zero) {
      _timer = Timer.periodic(pollEvery, (_) => _load());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _wsSub?.cancel();
    super.dispose();
  }

  void _onWsEvent(Map<String, dynamic> msg) {
    if (!mounted) return;
    final action = msg['action'] as String?;
    final summary = (msg['summary'] as String?) ?? '';
    final author = (msg['user_name'] as String?) ?? 'النظام';
    final ts = DateTime.tryParse(msg['timestamp'] as String? ?? '') ??
        DateTime.now();
    final ChatterEntry entry;
    switch (action) {
      case 'commented':
        entry = ChatterEntry.message(author, summary, ts);
        break;
      case 'note':
        entry = ChatterEntry.note(author, summary, ts);
        break;
      case 'attachment_added':
        entry = ChatterEntry.attachment(author, summary, ts);
        break;
      default:
        entry = ChatterEntry.system(summary, ts);
    }
    // Dedupe by (author+summary+timestamp-second) to avoid double-
    // inserting when the same event arrives via both WS and the
    // next poll fetch.
    final dedupeKey = '${entry.author}|${entry.content}|'
        '${entry.timestamp.millisecondsSinceEpoch ~/ 1000}';
    final alreadyThere = _entries.any((e) {
      final k = '${e.author}|${e.content}|'
          '${e.timestamp.millisecondsSinceEpoch ~/ 1000}';
      return k == dedupeKey;
    });
    if (!alreadyThere) {
      setState(() => _entries = [entry, ..._entries]);
    }
  }

  Uri _listUrl() => Uri.parse(
      '$apiBase/api/v1/activity/${widget.entityType}/${widget.entityId}');

  Uri _postUrl() => Uri.parse(
      '$apiBase/api/v1/activity/${widget.entityType}/${widget.entityId}/comment');

  Map<String, String> get _headers {
    final t = S.token;
    return {
      'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  ChatterEntry _toEntry(Map<String, dynamic> m) {
    final action = m['action'] as String? ?? '';
    final summary = (m['summary'] as String?) ??
        (m['details']?['body'] as String?) ??
        '';
    final author = (m['user_name'] as String?) ?? 'النظام';
    final ts = DateTime.tryParse(m['created_at'] as String? ?? '') ??
        DateTime.now();
    switch (action) {
      case 'commented':
        return ChatterEntry.message(author, summary, ts);
      case 'note':
        return ChatterEntry.note(author, summary, ts);
      case 'attachment_added':
        return ChatterEntry.attachment(author, summary, ts);
      default:
        return ChatterEntry.system(summary, ts);
    }
  }

  Future<void> _load() async {
    try {
      final res = await http.get(_listUrl(), headers: _headers);
      if (!mounted) return;
      if (res.statusCode != 200) {
        setState(() {
          _loading = false;
          _error = 'HTTP ${res.statusCode}';
        });
        return;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final data = (body['data'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _entries = data.map(_toEntry).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _post(String body, {required bool internal}) async {
    // Optimistic insert — user sees their comment immediately.
    final optimistic = internal
        ? ChatterEntry.note(S.uname ?? 'أنا', body, DateTime.now().toUtc())
        : ChatterEntry.message(S.uname ?? 'أنا', body, DateTime.now().toUtc());
    setState(() => _entries = [optimistic, ..._entries]);
    try {
      final res = await http.post(
        _postUrl(),
        headers: _headers,
        body: jsonEncode({
          'body': body,
          'internal': internal,
          'user_id': S.uid,
          'user_name': S.uname,
        }),
      );
      if (res.statusCode != 201) {
        throw Exception('HTTP ${res.statusCode}');
      }
      // Refresh to replace optimistic with server copy.
      await _load();
    } catch (e) {
      if (!mounted) return;
      // Roll back optimistic insert on failure.
      setState(() {
        _entries = _entries.where((e) => e != optimistic).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('فشل إرسال التعليق: $e'),
            duration: const Duration(seconds: 3)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(children: [
              Icon(Icons.warning_amber, size: 14, color: AC.err),
              const SizedBox(width: 6),
              Expanded(
                child: Text('تعذّر التحديث: $_error',
                    style: TextStyle(
                        color: AC.err, fontSize: AppFontSize.xs)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('إعادة'),
                onPressed: _load,
              ),
            ]),
          ),
        ApexChatter(
          entries: _entries,
          onSend: (t) => _post(t, internal: false),
          onLogNote: (t) => _post(t, internal: true),
        ),
      ],
    );
  }
}
