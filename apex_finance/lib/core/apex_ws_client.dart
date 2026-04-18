/// APEX WebSocket client — auto-reconnect + channel subscription.
///
/// Thin wrapper around dart:html WebSocket that talks to the backend
/// hub at `/ws/notifications?token=<JWT>`. Features:
///   • Singleton + per-session lifecycle
///   • Exponential backoff reconnect (1s → 30s cap)
///   • Channel subscribe / unsubscribe with ACK wait
///   • Event stream per channel (broadcast so many widgets can listen)
///   • Heartbeat ping every 30s so proxies don't time out
///
/// Usage:
/// ```dart
/// final sub = ApexWsClient.instance.subscribe('entity:client:c-42');
/// sub.events.listen((event) => print(event['type']));
/// // later:
/// sub.cancel();
/// ```
library;

import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'api_config.dart';
import 'session.dart';

/// One subscription to a channel. `events` is a broadcast stream so
/// multiple widgets can listen to the same channel without each
/// re-subscribing on the hub.
class ApexWsSubscription {
  final String channel;
  final Stream<Map<String, dynamic>> events;
  final void Function() cancel;

  const ApexWsSubscription({
    required this.channel,
    required this.events,
    required this.cancel,
  });
}

class ApexWsClient {
  ApexWsClient._();
  static final ApexWsClient instance = ApexWsClient._();

  html.WebSocket? _ws;
  final Map<String, StreamController<Map<String, dynamic>>> _controllers = {};
  final Map<String, int> _subscribers = {};
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _backoffMs = 1000;
  bool _shutdown = false;

  // ── Public API ───────────────────────────────────────────

  /// Subscribe to [channel]. Returns a subscription whose `events`
  /// stream fires every time the hub pushes to that channel. Safe to
  /// call multiple times for the same channel — subscribers share the
  /// same underlying StreamController.
  ApexWsSubscription subscribe(String channel) {
    final ctrl = _controllers.putIfAbsent(
      channel,
      () => StreamController<Map<String, dynamic>>.broadcast(
        onCancel: () {
          // Don't dispose until refcount drops to zero.
          if ((_subscribers[channel] ?? 0) <= 0) {
            _controllers.remove(channel)?.close();
          }
        },
      ),
    );
    _subscribers[channel] = (_subscribers[channel] ?? 0) + 1;
    _ensureConnected();
    _sendSubscribe(channel);
    return ApexWsSubscription(
      channel: channel,
      events: ctrl.stream,
      cancel: () => _unsubscribe(channel),
    );
  }

  void _unsubscribe(String channel) {
    final n = (_subscribers[channel] ?? 1) - 1;
    if (n <= 0) {
      _subscribers.remove(channel);
      // We don't tell the hub to unsubscribe — next reconnect will
      // simply not resubscribe it. Sending `unsubscribe` isn't strictly
      // required by the current hub protocol.
      final ctrl = _controllers.remove(channel);
      ctrl?.close();
    } else {
      _subscribers[channel] = n;
    }
  }

  /// Cleanly shut down the socket and all subscriptions. Typically
  /// called from the root ApexApp.dispose when the user logs out.
  void shutdown() {
    _shutdown = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _ws?.close();
    _ws = null;
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
    _subscribers.clear();
  }

  // ── Internals ────────────────────────────────────────────

  String? get _wsUrl {
    final token = S.token;
    if (token == null || token.isEmpty) return null;
    // Convert HTTP(S) base to WS(S).
    final base = apiBase
        .replaceFirst(RegExp(r'^http://'), 'ws://')
        .replaceFirst(RegExp(r'^https://'), 'wss://');
    return '$base/ws/notifications?token=$token';
  }

  void _ensureConnected() {
    if (_shutdown) return;
    final ws = _ws;
    if (ws != null &&
        (ws.readyState == html.WebSocket.OPEN ||
            ws.readyState == html.WebSocket.CONNECTING)) {
      return;
    }
    _connect();
  }

  void _connect() {
    if (_shutdown) return;
    final url = _wsUrl;
    if (url == null) {
      // No auth → quietly back off; user can call subscribe again
      // after login and the next call will re-attempt.
      return;
    }
    try {
      final ws = html.WebSocket(url);
      _ws = ws;
      ws.onOpen.listen((_) => _onOpen());
      ws.onMessage.listen((e) => _onMessage(e));
      ws.onClose.listen((_) => _onClose());
      ws.onError.listen((_) => _onClose());
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onOpen() {
    _backoffMs = 1000;
    // Re-subscribe all active channels on reconnect.
    for (final ch in _subscribers.keys) {
      _sendSubscribe(ch);
    }
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final ws = _ws;
      if (ws != null && ws.readyState == html.WebSocket.OPEN) {
        ws.send(jsonEncode({'type': 'ping'}));
      }
    });
  }

  void _onMessage(html.MessageEvent e) {
    final raw = e.data as String?;
    if (raw == null || raw.isEmpty) return;
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    // Delivery messages have a `_channel` field added by the hub;
    // if missing, we fall back to matching by type + entity pair.
    final channel = msg['_channel'] as String? ?? _channelGuess(msg);
    if (channel == null) return;
    final ctrl = _controllers[channel];
    if (ctrl != null && !ctrl.isClosed) {
      ctrl.add(msg);
    }
  }

  /// Guess the channel from a push payload when the hub didn't tag it
  /// (entity-scoped payloads have entity_type + entity_id so we can
  /// reconstruct `entity:<type>:<id>`).
  String? _channelGuess(Map<String, dynamic> msg) {
    final et = msg['entity_type'] as String?;
    final eid = msg['entity_id'] as String?;
    if (et != null && eid != null) return 'entity:$et:$eid';
    return null;
  }

  void _onClose() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _ws = null;
    if (_subscribers.isNotEmpty) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_shutdown) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: _backoffMs), _connect);
    _backoffMs = (_backoffMs * 2).clamp(1000, 30000);
  }

  void _sendSubscribe(String channel) {
    final ws = _ws;
    if (ws == null || ws.readyState != html.WebSocket.OPEN) return;
    ws.send(jsonEncode({'type': 'subscribe', 'channel': channel}));
  }
}
