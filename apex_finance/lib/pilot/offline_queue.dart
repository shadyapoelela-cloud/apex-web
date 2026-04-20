/// Offline Queue — يخزّن العمليات عند انقطاع الإنترنت ويزامن لاحقاً.
///
/// Wave O — يمنع شلل POS عند انقطاع الإنترنت.
///
/// المعمارية:
///   • IndexedDB لتخزين queue (عبر localStorage fallback)
///   • كل operation = {id, endpoint, method, body, timestamp, retries}
///   • عند rejected connection: إضافة للـ queue + عرض snackbar
///   • عند عودة الاتصال: workers يُعالج الـ queue (FIFO) ويُرسلها
///   • conflict resolution: server wins — لو duplicated تُرفض بأمان
///
/// يستعمل localStorage كـ simple store (IndexedDB overhead غير مبرر
/// لـ queue بسيطة أقل من 100 عملية).
library;

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

import 'api/pilot_client.dart';
import '../api_service.dart' show ApiResult;

const String _kQueueKey = 'apex.offline_queue';
const String _kLastSyncKey = 'apex.last_sync_at';

/// عملية معلّقة في الـ queue
class PendingOp {
  final String id;
  final String endpoint; // مثال: /pilot/pos-transactions
  final String method;   // POST, PATCH, PUT
  final Map<String, dynamic> body;
  final DateTime createdAt;
  int retries;
  String? lastError;

  PendingOp({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.body,
    required this.createdAt,
    this.retries = 0,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'body': body,
        'created_at': createdAt.toIso8601String(),
        'retries': retries,
        'last_error': lastError,
      };

  factory PendingOp.fromJson(Map<String, dynamic> j) => PendingOp(
        id: j['id'] as String,
        endpoint: j['endpoint'] as String,
        method: j['method'] as String,
        body: Map<String, dynamic>.from(j['body'] as Map),
        createdAt: DateTime.parse(j['created_at'] as String),
        retries: (j['retries'] as num?)?.toInt() ?? 0,
        lastError: j['last_error'] as String?,
      );
}

/// OfflineQueue — singleton manages pending operations
class OfflineQueue extends ChangeNotifier {
  static final OfflineQueue _instance = OfflineQueue._internal();
  factory OfflineQueue() => _instance;
  OfflineQueue._internal() {
    _loadFromStorage();
    // listen for online/offline
    html.window.onOnline.listen((_) {
      _isOnline = true;
      notifyListeners();
      trySync();
    });
    html.window.onOffline.listen((_) {
      _isOnline = false;
      notifyListeners();
    });
    _isOnline = html.window.navigator.onLine ?? true;
  }

  List<PendingOp> _queue = [];
  bool _isOnline = true;
  bool _syncing = false;
  DateTime? _lastSyncAt;

  List<PendingOp> get queue => List.unmodifiable(_queue);
  bool get isOnline => _isOnline;
  bool get hasPending => _queue.isNotEmpty;
  bool get isSyncing => _syncing;
  DateTime? get lastSyncAt => _lastSyncAt;

  void _loadFromStorage() {
    try {
      final raw = html.window.localStorage[_kQueueKey];
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw) as List;
      _queue = list
          .map((e) => PendingOp.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('[OfflineQueue] load failed: $e');
      _queue = [];
    }
    try {
      final ts = html.window.localStorage[_kLastSyncKey];
      if (ts != null) _lastSyncAt = DateTime.tryParse(ts);
    } catch (_) {}
  }

  void _saveToStorage() {
    try {
      html.window.localStorage[_kQueueKey] =
          jsonEncode(_queue.map((e) => e.toJson()).toList());
      if (_lastSyncAt != null) {
        html.window.localStorage[_kLastSyncKey] =
            _lastSyncAt!.toIso8601String();
      }
    } catch (e) {
      // ignore: avoid_print
      print('[OfflineQueue] save failed: $e');
    }
  }

  /// إضافة عملية للـ queue (عند فشل الطلب المباشر)
  void enqueue({
    required String endpoint,
    required String method,
    required Map<String, dynamic> body,
  }) {
    final op = PendingOp(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      endpoint: endpoint,
      method: method,
      body: body,
      createdAt: DateTime.now(),
    );
    _queue.add(op);
    _saveToStorage();
    notifyListeners();
  }

  /// تجربة sync للـ queue (يُستدعى عند عودة الاتصال أو يدوياً)
  Future<int> trySync() async {
    if (!_isOnline || _syncing || _queue.isEmpty) return 0;
    _syncing = true;
    notifyListeners();

    int successCount = 0;
    final toRemove = <String>[];

    for (final op in List.of(_queue)) {
      try {
        final r = await _execute(op);
        if (r.success) {
          successCount++;
          toRemove.add(op.id);
        } else {
          op.retries++;
          op.lastError = r.error;
          // بعد 5 محاولات فاشلة، نرفعها للـ user يحلها يدوياً
          if (op.retries > 5) {
            // ignore: avoid_print
            print(
                '[OfflineQueue] op ${op.id} failed ${op.retries} times: ${op.lastError}');
          }
        }
      } catch (e) {
        op.retries++;
        op.lastError = e.toString();
      }
    }

    _queue.removeWhere((op) => toRemove.contains(op.id));
    _lastSyncAt = DateTime.now();
    _saveToStorage();
    _syncing = false;
    notifyListeners();
    return successCount;
  }

  /// تنفيذ العملية عبر الـ client المناسب
  Future<ApiResult> _execute(PendingOp op) async {
    // نوجّه العملية حسب الـ endpoint
    // هذا Simplified — في production سنستخدم http.post مباشرة
    // مع URL = apiBase + op.endpoint
    final client = pilotClient;
    switch (op.endpoint) {
      case '/pilot/pos-transactions':
        return client.createPosTransaction(op.body);
      case '/pilot/stock/movements':
        return client.recordStockMovement(op.body);
      case '/pilot/journal-entries':
        return client.createJournalEntry(op.body);
      case '/pilot/purchase-orders':
        return client.createPurchaseOrder(op.body);
      case '/pilot/purchase-invoices':
        return client.createPurchaseInvoice(op.body);
      case '/pilot/vendor-payments':
        return client.createVendorPayment(op.body);
      default:
        return ApiResult.error(
            'Offline endpoint not supported: ${op.endpoint}');
    }
  }

  /// مسح العملية يدوياً (للـ failed-forever)
  void remove(String opId) {
    _queue.removeWhere((op) => op.id == opId);
    _saveToStorage();
    notifyListeners();
  }

  /// مسح الـ queue كلياً (خطر — للـ debugging فقط)
  void clear() {
    _queue = [];
    _saveToStorage();
    notifyListeners();
  }

  /// ملخص سريع للعرض في UI
  String get statusText {
    if (_syncing) return 'جاري المزامنة...';
    if (!_isOnline) return 'غير متصل — ${_queue.length} عملية معلّقة';
    if (_queue.isNotEmpty) return '${_queue.length} عملية في الانتظار';
    if (_lastSyncAt != null) {
      final diff = DateTime.now().difference(_lastSyncAt!);
      if (diff.inMinutes < 1) return 'متزامن الآن';
      if (diff.inHours < 1) return 'متزامن منذ ${diff.inMinutes} دقيقة';
      return 'متزامن منذ ${diff.inHours} ساعة';
    }
    return 'متصل';
  }
}
