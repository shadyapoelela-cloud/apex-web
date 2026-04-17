/// APEX Offline Queue — client side of PWA offline sync.
///
/// Philosophy: every mutating action goes through the queue first. Online
/// requests flush immediately; offline ones persist until the connection
/// returns. The server provides idempotency via `op_id`, so at-least-once
/// delivery from the client is safe.
///
/// Storage:
///   • Web: localStorage under 'apex_offline_queue_v1' (SharedPreferences
///     uses localStorage under the hood — simple + portable).
///   • Mobile: SharedPreferences (same API).
///
/// NOTE: this does NOT replace API calls — it's a thin wrapper the caller
/// opts into for specific mutating endpoints. GET/read-only calls skip
/// the queue entirely.
///
/// Usage:
/// ```dart
/// final queue = ApexOfflineQueue.instance;
/// await queue.enqueue(OfflineOp(
///   entityType: 'invoice',
///   verb: 'create',
///   payload: {'client_id': 'c1', 'amount': 1500},
/// ));
/// // Later, when online:
/// final results = await queue.flush(send: (op) => api.push(op));
/// ```
library;

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const String _kQueueKey = 'apex_offline_queue_v1';
const int _kMaxQueueSize = 1000;  // protect from runaway client growth

class OfflineOp {
  final String opId;
  final String entityType;
  final String? entityId;
  final String verb;          // 'create' | 'update' | 'delete'
  final Map<String, dynamic> payload;
  final DateTime clientTimestamp;

  OfflineOp({
    String? opId,
    required this.entityType,
    this.entityId,
    required this.verb,
    required this.payload,
    DateTime? clientTimestamp,
  })  : opId = opId ?? _uuid(),
        clientTimestamp = clientTimestamp ?? DateTime.now().toUtc();

  static String _uuid() {
    // Simple UUID4 — no need to pull a package.
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = (now * 1103515245 + 12345) & 0x7fffffff;
    return '${now.toRadixString(16)}-${rand.toRadixString(16)}';
  }

  Map<String, dynamic> toJson() => {
        'op_id': opId,
        'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
        'verb': verb,
        'payload': payload,
        'client_timestamp': clientTimestamp.toIso8601String(),
      };

  static OfflineOp fromJson(Map<String, dynamic> j) => OfflineOp(
        opId: j['op_id'] as String,
        entityType: j['entity_type'] as String,
        entityId: j['entity_id'] as String?,
        verb: j['verb'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        clientTimestamp: DateTime.parse(j['client_timestamp'] as String),
      );
}

enum OpDeliveryStatus { pending, applied, conflict, rejected, superseded }

class ApexOfflineQueue {
  ApexOfflineQueue._();
  static final ApexOfflineQueue instance = ApexOfflineQueue._();

  /// Add an operation to the queue. If the client is online, callers
  /// typically call `flush()` immediately after.
  Future<void> enqueue(OfflineOp op) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueueKey);
    final list = raw == null
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    if (list.length >= _kMaxQueueSize) {
      // Drop oldest — shouldn't happen in practice.
      list.removeAt(0);
    }
    list.add(op.toJson());
    await prefs.setString(_kQueueKey, jsonEncode(list));
  }

  /// Peek at what's queued without sending.
  Future<List<OfflineOp>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueueKey);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(OfflineOp.fromJson).toList();
  }

  /// Drop an op from the queue by id.
  Future<void> remove(String opId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueueKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    list.removeWhere((o) => o['op_id'] == opId);
    await prefs.setString(_kQueueKey, jsonEncode(list));
  }

  /// Drain the queue, sending ops to the server via [send]. Each op
  /// acknowledged as APPLIED / REJECTED / SUPERSEDED is removed from
  /// the queue. CONFLICT items stay so the user can retry / reconcile.
  Future<List<FlushResult>> flush({
    required Future<Map<String, dynamic>> Function(List<OfflineOp> ops) sendBatch,
  }) async {
    final ops = await pending();
    if (ops.isEmpty) return const [];

    // Batch up to 50 at a time (server's max_length is 100).
    const chunk = 50;
    final results = <FlushResult>[];
    for (var i = 0; i < ops.length; i += chunk) {
      final slice = ops.sublist(i, i + chunk > ops.length ? ops.length : i + chunk);
      try {
        final body = await sendBatch(slice);
        final list = (body['data'] as List).cast<Map<String, dynamic>>();
        for (final r in list) {
          final status = _parseStatus(r['status'] as String);
          results.add(FlushResult(
            opId: r['op_id'] as String,
            status: status,
            result: r['result'] as Map<String, dynamic>?,
            error: r['error'] as String?,
          ));
          if (status != OpDeliveryStatus.conflict) {
            await remove(r['op_id'] as String);
          }
        }
      } catch (e) {
        // Network failure — leave queue intact, retry next time.
        for (final op in slice) {
          results.add(FlushResult(
            opId: op.opId,
            status: OpDeliveryStatus.pending,
            error: 'network: $e',
          ));
        }
        // Stop flushing — assume offline again
        break;
      }
    }
    return results;
  }

  Future<int> count() async => (await pending()).length;

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kQueueKey);
  }

  OpDeliveryStatus _parseStatus(String s) {
    return switch (s) {
      'applied' => OpDeliveryStatus.applied,
      'conflict' => OpDeliveryStatus.conflict,
      'rejected' => OpDeliveryStatus.rejected,
      'superseded' => OpDeliveryStatus.superseded,
      _ => OpDeliveryStatus.pending,
    };
  }
}

class FlushResult {
  final String opId;
  final OpDeliveryStatus status;
  final Map<String, dynamic>? result;
  final String? error;

  FlushResult({
    required this.opId,
    required this.status,
    this.result,
    this.error,
  });
}
