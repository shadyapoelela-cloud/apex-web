/// APEX Pilot — Multi-tenant Retail ERP API Client
/// ═════════════════════════════════════════════════════════════════════
/// Thin client class that maps every `/pilot/*` endpoint (121 total)
/// onto typed Dart methods. All responses come back as `ApiResult`
/// (same type used by the legacy ApiService).
///
/// Organized by domain:
///   1. Tenant / Entity / Branch
///   2. Currency / FX
///   3. RBAC (Permissions / Roles / Members / Access grants)
///   4. Catalog (Categories / Brands / Attributes / Products / Variants / Barcodes)
///   5. Warehouses + Stock (Levels / Movements)
///   6. Price Lists + Lookup
///   7. POS (Sessions / Transactions / Payments / Cash Drawer)
///   8. GL (CoA / Fiscal Periods / Journal Entries / Postings / Reports)
///   9. Compliance (ZATCA / GOSI / WPS / UAE CT / VAT Return)
///
/// Usage:
///   final client = PilotClient();
///   final r = await client.listProducts(tenantId);
///   if (r.success) { ... }

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import '../../api_service.dart' show ApiResult;
import '../../core/api_config.dart';
import '../../core/session.dart';

class PilotClient {
  static const _base = apiBase;

  // ── Headers ─────────────────────────────────────────────────
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (S.token != null) 'Authorization': 'Bearer ${S.token}',
      };

  Map<String, String> _adminHeaders(String adminSecret) => {
        ..._headers,
        'X-Admin-Secret': adminSecret,
      };

  // ── Generic HTTP primitives ────────────────────────────────
  Future<ApiResult> _get(String path) async {
    try {
      final r = await http
          .get(Uri.parse('$_base$path'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _parse(r);
    } catch (e) {
      return ApiResult.error('اتصال: $e');
    }
  }

  Future<ApiResult> _post(String path, [Object? body]) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_base$path'),
            headers: _headers,
            body: body == null ? '{}' : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));
      return _parse(r);
    } catch (e) {
      return ApiResult.error('اتصال: $e');
    }
  }

  Future<ApiResult> _patch(String path, Object body) async {
    try {
      final r = await http
          .patch(Uri.parse('$_base$path'),
              headers: _headers, body: jsonEncode(body))
          .timeout(const Duration(seconds: 30));
      return _parse(r);
    } catch (e) {
      return ApiResult.error('اتصال: $e');
    }
  }

  Future<ApiResult> _delete(String path) async {
    try {
      final r = await http
          .delete(Uri.parse('$_base$path'), headers: _headers)
          .timeout(const Duration(seconds: 30));
      return _parse(r);
    } catch (e) {
      return ApiResult.error('اتصال: $e');
    }
  }

  ApiResult _parse(http.Response r) {
    final code = r.statusCode;
    if (code >= 200 && code < 300) {
      if (r.body.isEmpty) return ApiResult.ok(null);
      try {
        return ApiResult.ok(jsonDecode(r.body));
      } catch (_) {
        return ApiResult.ok(r.body);
      }
    }
    // attempt to extract {detail: ...}
    try {
      final j = jsonDecode(r.body);
      if (j is Map) {
        final d = j['detail'] ?? j['error'] ?? j['message'];
        if (d != null) return ApiResult.error(d.toString());
      }
    } catch (_) {}
    return ApiResult.error('HTTP $code: ${r.body.isEmpty ? "-" : r.body.substring(0, r.body.length.clamp(0, 200))}');
  }

  // ═════════════════════════════════════════════════════════════
  // 1. TENANT / ENTITY / BRANCH
  // ═════════════════════════════════════════════════════════════

  Future<ApiResult> createTenant(Map<String, dynamic> body) =>
      _post('/pilot/tenants', body);
  Future<ApiResult> listTenants(String adminSecret) async {
    try {
      final r = await http
          .get(Uri.parse('$_base/pilot/tenants'),
              headers: _adminHeaders(adminSecret))
          .timeout(const Duration(seconds: 30));
      return _parse(r);
    } catch (e) {
      return ApiResult.error('اتصال: $e');
    }
  }
  Future<ApiResult> getTenant(String tid) => _get('/pilot/tenants/$tid');
  Future<ApiResult> updateTenant(String tid, Map<String, dynamic> body) =>
      _patch('/pilot/tenants/$tid', body);
  Future<ApiResult> getTenantSettings(String tid) =>
      _get('/pilot/tenants/$tid/settings');
  Future<ApiResult> updateTenantSettings(String tid, Map<String, dynamic> body) =>
      _patch('/pilot/tenants/$tid/settings', body);

  // Advanced settings — history, export/import, presets, compliance
  Future<ApiResult> listSettingsHistory(String tid,
          {String? category, int limit = 50}) =>
      _get('/pilot/tenants/$tid/settings/history?limit=$limit'
          '${category != null ? '&category=$category' : ''}');
  Future<ApiResult> exportSettings(String tid) =>
      _get('/pilot/tenants/$tid/settings/export');
  Future<ApiResult> importSettings(String tid, Map<String, dynamic> snapshot) =>
      _post('/pilot/tenants/$tid/settings/import', snapshot);
  Future<ApiResult> listPresets() => _get('/pilot/settings/presets');
  Future<ApiResult> applyPreset(String tid, String presetKey) =>
      _post('/pilot/tenants/$tid/settings/apply-preset?preset_key=$presetKey',
          const {});
  Future<ApiResult> getComplianceScore(String tid) =>
      _get('/pilot/tenants/$tid/settings/compliance-score');
  Future<ApiResult> getBenchmarks(String tid) =>
      _get('/pilot/tenants/$tid/settings/benchmarks');
  Future<ApiResult> rollbackSettingsChange(String tid, String logId) =>
      _post('/pilot/tenants/$tid/settings/history/$logId/rollback', const {});

  Future<ApiResult> listEntities(String tid) =>
      _get('/pilot/tenants/$tid/entities');
  Future<ApiResult> createEntity(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/entities', body);
  Future<ApiResult> getEntity(String eid) => _get('/pilot/entities/$eid');
  Future<ApiResult> updateEntity(String eid, Map<String, dynamic> body) =>
      _patch('/pilot/entities/$eid', body);
  Future<ApiResult> deleteEntity(String eid) => _delete('/pilot/entities/$eid');

  Future<ApiResult> listBranches(String eid) =>
      _get('/pilot/entities/$eid/branches');
  Future<ApiResult> createBranch(String eid, Map<String, dynamic> body) =>
      _post('/pilot/entities/$eid/branches', body);
  Future<ApiResult> getBranch(String bid) => _get('/pilot/branches/$bid');
  Future<ApiResult> updateBranch(String bid, Map<String, dynamic> body) =>
      _patch('/pilot/branches/$bid', body);
  Future<ApiResult> deleteBranch(String bid) => _delete('/pilot/branches/$bid');

  // ═════════════════════════════════════════════════════════════
  // 2. CURRENCY / FX
  // ═════════════════════════════════════════════════════════════

  Future<ApiResult> listCurrencies(String tid) =>
      _get('/pilot/tenants/$tid/currencies');
  Future<ApiResult> createCurrency(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/currencies', body);

  Future<ApiResult> listFxRates(String tid) =>
      _get('/pilot/tenants/$tid/fx-rates');
  Future<ApiResult> createFxRate(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/fx-rates', body);
  Future<ApiResult> getLatestFxRate(
          String tid, String from, String to) =>
      _get('/pilot/tenants/$tid/fx-rates/latest?from=$from&to=$to');

  // ═════════════════════════════════════════════════════════════
  // 3. RBAC — Permissions / Roles / Members / Access
  // ═════════════════════════════════════════════════════════════

  Future<ApiResult> listPermissions({String? category}) => _get(
      '/pilot/permissions${category != null ? "?category=$category" : ""}');

  Future<ApiResult> listRoles(String tid) =>
      _get('/pilot/tenants/$tid/roles');
  Future<ApiResult> createRole(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/roles', body);
  Future<ApiResult> getRole(String rid) => _get('/pilot/roles/$rid');
  Future<ApiResult> updateRole(String rid, Map<String, dynamic> body) =>
      _patch('/pilot/roles/$rid', body);

  Future<ApiResult> listMembers(String tid, {bool activeOnly = true}) =>
      _get('/pilot/tenants/$tid/members?active_only=$activeOnly');
  Future<ApiResult> inviteMember(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/members', body);
  Future<ApiResult> getMember(String tid, String uid) =>
      _get('/pilot/tenants/$tid/members/$uid');
  Future<ApiResult> updateMember(
          String tid, String uid, Map<String, dynamic> body) =>
      _patch('/pilot/tenants/$tid/members/$uid', body);
  Future<ApiResult> removeMember(String tid, String uid, {String? reason}) =>
      _delete(
          '/pilot/tenants/$tid/members/$uid${reason != null ? "?reason=$reason" : ""}');

  Future<ApiResult> grantEntityAccess(
          String tid, String uid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/members/$uid/entity-access', body);
  Future<ApiResult> grantBranchAccess(
          String tid, String uid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/members/$uid/branch-access', body);
  Future<ApiResult> revokeEntityAccess(String tid, String gid,
          {String? reason}) =>
      _delete(
          '/pilot/tenants/$tid/entity-access/$gid${reason != null ? "?reason=$reason" : ""}');
  Future<ApiResult> revokeBranchAccess(String tid, String gid) =>
      _delete('/pilot/tenants/$tid/branch-access/$gid');
  Future<ApiResult> getEffectivePermissions(String tid, String uid) =>
      _get('/pilot/tenants/$tid/members/$uid/effective-permissions');

  // ═════════════════════════════════════════════════════════════
  // 4. CATALOG — Categories / Brands / Attributes / Products / Variants / Barcodes
  // ═════════════════════════════════════════════════════════════

  Future<ApiResult> listCategories(String tid,
          {String? parentId, bool includeInactive = false}) =>
      _get(
          '/pilot/tenants/$tid/categories?include_inactive=$includeInactive${parentId != null ? "&parent_id=$parentId" : ""}');
  Future<ApiResult> createCategory(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/categories', body);
  Future<ApiResult> updateCategory(String cid, Map<String, dynamic> body) =>
      _patch('/pilot/categories/$cid', body);

  Future<ApiResult> listBrands(String tid) =>
      _get('/pilot/tenants/$tid/brands');
  Future<ApiResult> createBrand(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/brands', body);

  Future<ApiResult> listAttributes(String tid) =>
      _get('/pilot/tenants/$tid/attributes');
  Future<ApiResult> createAttribute(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/attributes', body);
  Future<ApiResult> addAttributeValue(String aid, Map<String, dynamic> body) =>
      _post('/pilot/attributes/$aid/values', body);

  Future<ApiResult> listProducts(
    String tid, {
    String? status,
    String? categoryId,
    String? brandId,
    String? search,
    int limit = 100,
    int offset = 0,
  }) {
    final qp = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (status != null) 'status': status,
      if (categoryId != null) 'category_id': categoryId,
      if (brandId != null) 'brand_id': brandId,
      if (search != null) 'q': search,
    };
    final qs = qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return _get('/pilot/tenants/$tid/products?$qs');
  }
  Future<ApiResult> createProduct(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/products', body);
  Future<ApiResult> getProduct(String pid) => _get('/pilot/products/$pid');
  Future<ApiResult> updateProduct(String pid, Map<String, dynamic> body) =>
      _patch('/pilot/products/$pid', body);
  Future<ApiResult> deleteProduct(String pid) => _delete('/pilot/products/$pid');

  Future<ApiResult> listVariants(String pid) =>
      _get('/pilot/products/$pid/variants');
  Future<ApiResult> createVariant(String pid, Map<String, dynamic> body) =>
      _post('/pilot/products/$pid/variants', body);

  Future<ApiResult> listBarcodes(String vid) =>
      _get('/pilot/variants/$vid/barcodes');
  Future<ApiResult> createBarcode(String vid, Map<String, dynamic> body) =>
      _post('/pilot/variants/$vid/barcodes', body);
  Future<ApiResult> scanBarcode(String tid, String barcodeValue) =>
      _get('/pilot/tenants/$tid/barcode/$barcodeValue');

  // ═════════════════════════════════════════════════════════════
  // 5. WAREHOUSES + STOCK
  // ═════════════════════════════════════════════════════════════

  Future<ApiResult> listWarehouses(String bid) =>
      _get('/pilot/branches/$bid/warehouses');
  Future<ApiResult> createWarehouse(String bid, Map<String, dynamic> body) =>
      _post('/pilot/branches/$bid/warehouses', body);
  Future<ApiResult> updateWarehouse(String wid, Map<String, dynamic> body) =>
      _patch('/pilot/warehouses/$wid', body);
  Future<ApiResult> deleteWarehouse(String wid) =>
      _delete('/pilot/warehouses/$wid');

  Future<ApiResult> getWarehouseStock(String wid) =>
      _get('/pilot/warehouses/$wid/stock');
  Future<ApiResult> getVariantStock(String vid) =>
      _get('/pilot/variants/$vid/stock');
  Future<ApiResult> recordStockMovement(Map<String, dynamic> body) =>
      _post('/pilot/stock/movements', body);
  Future<ApiResult> listWarehouseMovements(String wid,
      {String? variantId, int limit = 100}) {
    final qs = 'limit=$limit${variantId != null ? "&variant_id=$variantId" : ""}';
    return _get('/pilot/warehouses/$wid/movements?$qs');
  }

  // ═════════════════════════════════════════════════════════════
  // 6. PRICE LISTS + LOOKUP
  // ═════════════════════════════════════════════════════════════

  Future<ApiResult> listPriceLists(String tid,
          {bool activeOnly = true, String? kind, String? scope}) =>
      _get(
          '/pilot/tenants/$tid/price-lists?active_only=$activeOnly${kind != null ? "&kind=$kind" : ""}${scope != null ? "&scope=$scope" : ""}');
  Future<ApiResult> createPriceList(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/price-lists', body);
  Future<ApiResult> getPriceList(String plid) =>
      _get('/pilot/price-lists/$plid');
  Future<ApiResult> updatePriceList(String plid, Map<String, dynamic> body) =>
      _patch('/pilot/price-lists/$plid', body);
  Future<ApiResult> deletePriceList(String plid) =>
      _delete('/pilot/price-lists/$plid');
  Future<ApiResult> activatePriceList(String plid,
          {String? approvedByUserId}) =>
      _post('/pilot/price-lists/$plid/activate',
          {if (approvedByUserId != null) 'approved_by_user_id': approvedByUserId});
  Future<ApiResult> archivePriceList(String plid) =>
      _post('/pilot/price-lists/$plid/archive');
  Future<ApiResult> listPriceListItems(String plid) =>
      _get('/pilot/price-lists/$plid/items');
  Future<ApiResult> addPriceListItem(String plid, Map<String, dynamic> body) =>
      _post('/pilot/price-lists/$plid/items', body);
  Future<ApiResult> updatePriceListItem(
          String iid, Map<String, dynamic> body) =>
      _patch('/pilot/price-list-items/$iid', body);
  Future<ApiResult> deletePriceListItem(String iid) =>
      _delete('/pilot/price-list-items/$iid');
  Future<ApiResult> bulkPriceListItems(
          String plid, Map<String, dynamic> body) =>
      _post('/pilot/price-lists/$plid/items/bulk', body);

  Future<ApiResult> priceLookup({
    required String tenantId,
    required String variantId,
    String? branchId,
    String qty = '1',
    String? atTime,
    String? customerGroupCode,
  }) {
    final qp = <String, String>{
      'tenant_id': tenantId,
      'variant_id': variantId,
      'qty': qty,
      if (branchId != null) 'branch_id': branchId,
      if (atTime != null) 'at_time': atTime,
      if (customerGroupCode != null) 'customer_group_code': customerGroupCode,
    };
    final qs = qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return _get('/pilot/price-lookup?$qs');
  }

  // ═════════════════════════════════════════════════════════════
  // 7. POS
  // ═════════════════════════════════════════════════════════════

  Future<ApiResult> openPosSession(String bid, Map<String, dynamic> body) =>
      _post('/pilot/branches/$bid/pos-sessions', body);
  Future<ApiResult> listPosSessions(String bid, {String? status, int limit = 50}) =>
      _get(
          '/pilot/branches/$bid/pos-sessions?limit=$limit${status != null ? "&status=$status" : ""}');
  Future<ApiResult> getPosSession(String sid) =>
      _get('/pilot/pos-sessions/$sid');
  Future<ApiResult> closePosSession(String sid, Map<String, dynamic> body) =>
      _post('/pilot/pos-sessions/$sid/close', body);
  Future<ApiResult> getZReport(String sid) =>
      _get('/pilot/pos-sessions/$sid/z-report');

  Future<ApiResult> createPosTransaction(Map<String, dynamic> body) =>
      _post('/pilot/pos-transactions', body);
  Future<ApiResult> listSessionTransactions(String sid,
      {String? kind, String? status, int limit = 100}) {
    final qp = <String, String>{
      'limit': '$limit',
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/pos-sessions/$sid/transactions?$qs');
  }
  Future<ApiResult> getPosTransaction(String tid) =>
      _get('/pilot/pos-transactions/$tid');
  Future<ApiResult> voidPosTransaction(
          String tid, Map<String, dynamic> body) =>
      _post('/pilot/pos-transactions/$tid/void', body);

  Future<ApiResult> listCashMovements(String sid) =>
      _get('/pilot/pos-sessions/$sid/cash-movements');
  Future<ApiResult> addCashMovement(String sid, Map<String, dynamic> body) =>
      _post('/pilot/pos-sessions/$sid/cash-movements', body);

  // ═════════════════════════════════════════════════════════════
  // 8. GL — Chart of Accounts, Periods, Journal Entries, Reports
  // ═════════════════════════════════════════════════════════════

  Future<ApiResult> seedCoa(String eid) =>
      _post('/pilot/entities/$eid/coa/seed');
  Future<ApiResult> listAccounts(String eid,
      {String? category, String? type, bool includeInactive = false}) {
    final qp = <String, String>{
      'include_inactive': '$includeInactive',
      if (category != null) 'category': category,
      if (type != null) 'type': type,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/entities/$eid/accounts?$qs');
  }
  Future<ApiResult> createAccount(String eid, Map<String, dynamic> body) =>
      _post('/pilot/entities/$eid/accounts', body);
  Future<ApiResult> updateAccount(String accId, Map<String, dynamic> body) =>
      _patch('/pilot/accounts/$accId', body);
  Future<ApiResult> deleteAccount(String accId) =>
      _delete('/pilot/accounts/$accId');
  Future<ApiResult> accountLedger(String accId,
      {String? startDate, String? endDate, int limit = 500}) {
    final qp = <String, String>{
      'limit': '$limit',
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/accounts/$accId/ledger?$qs');
  }
  Future<ApiResult> cashFlow(String eid, String startDate, String endDate) =>
      _get('/pilot/entities/$eid/reports/cash-flow'
          '?start_date=$startDate&end_date=$endDate');
  Future<ApiResult> comparativeReport(String eid,
      {required String reportType,
      required String currentStart,
      required String currentEnd,
      String? priorStart,
      String? priorEnd}) {
    final qp = <String, String>{
      'report_type': reportType,
      'current_start': currentStart,
      'current_end': currentEnd,
      if (priorStart != null) 'prior_start': priorStart,
      if (priorEnd != null) 'prior_end': priorEnd,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/entities/$eid/reports/comparative?$qs');
  }

  Future<ApiResult> seedFiscalPeriods(String eid, int year) =>
      _post('/pilot/entities/$eid/fiscal-periods/seed', {'year': year});
  Future<ApiResult> listFiscalPeriods(String eid, {int? year, String? status}) {
    final qp = <String, String>{
      if (year != null) 'year': '$year',
      if (status != null) 'status': status,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/entities/$eid/fiscal-periods${qs.isEmpty ? "" : "?$qs"}');
  }
  Future<ApiResult> closePeriod(String pid, String userId) =>
      _post('/pilot/fiscal-periods/$pid/close', {'closed_by_user_id': userId});

  Future<ApiResult> createJournalEntry(Map<String, dynamic> body) =>
      _post('/pilot/journal-entries', body);

  /// AI — رفع مستند (PDF/صورة) عبر multipart/form-data.
  /// Used by _JeAiReader and the inline manual form's AI quick bar.
  /// Returns a proposed journal entry the user can review + save.
  Future<ApiResult> aiReadDocument(String entityId, html.File file) async {
    try {
      // Read file as bytes via FileReader (web-only)
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final bytes = Uint8List.fromList(
        (reader.result as List).cast<int>(),
      );
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/pilot/entities/$entityId/ai/read-document'),
      );
      if (S.token != null) {
        req.headers['Authorization'] = 'Bearer ${S.token}';
      }
      req.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name,
        contentType: _mediaTypeFor(file.type, file.name),
      ));
      final streamed = await req.send().timeout(const Duration(seconds: 90));
      final r = await http.Response.fromStream(streamed);
      return _parse(r);
    } catch (e) {
      return ApiResult.error('فشل رفع المستند: $e');
    }
  }

  // Build MediaType from the browser-provided MIME (or guess from ext)
  MediaType _mediaTypeFor(String? mime, String name) {
    if (mime != null && mime.contains('/')) {
      final parts = mime.split('/');
      return MediaType(parts[0], parts[1]);
    }
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'png':
        return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  /// AI — اقتراح بيان (memo) من سطور القيد.
  /// [lines] كل عنصر يحوي account_id/account_code/account_name/debit/credit.
  /// يُرجع {"suggested_memo": "...", "confidence": 0.85}.
  Future<ApiResult> aiSuggestMemo({
    required List<Map<String, dynamic>> lines,
    String kind = 'manual',
    String? reference,
    String? date,
  }) =>
      _post('/pilot/ai/suggest-memo', {
        'lines': lines,
        'kind': kind,
        if (reference != null && reference.isNotEmpty) 'reference': reference,
        if (date != null) 'date': date,
        'language': 'ar',
      });

  /// AI — استخراج قيد يومية من مستند via JSON+base64 (alternative to multipart).
  Future<ApiResult> extractJeFromDocument(
    String entityId, {
    required String fileBase64,
    required String mediaType,
    String? filename,
  }) =>
      _post('/pilot/entities/$entityId/ai/extract-je', {
        'file_base64': fileBase64,
        'media_type': mediaType,
        if (filename != null) 'filename': filename,
      });

  /// AI — فحص حالة الخدمة (هل ANTHROPIC_API_KEY مُعدّ؟).
  Future<ApiResult> aiHealth() => _get('/pilot/ai/health');

  Future<ApiResult> listJournalEntries(
    String eid, {
    String? status,
    String? kind,
    String? periodId,
    String? sourceType,
    int limit = 100,
  }) {
    final qp = <String, String>{
      'limit': '$limit',
      if (status != null) 'status': status,
      if (kind != null) 'kind': kind,
      if (periodId != null) 'period_id': periodId,
      if (sourceType != null) 'source_type': sourceType,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/entities/$eid/journal-entries?$qs');
  }
  Future<ApiResult> getJournalEntry(String jid) =>
      _get('/pilot/journal-entries/$jid');
  Future<ApiResult> postJournalEntry(String jid) =>
      _post('/pilot/journal-entries/$jid/post');
  Future<ApiResult> reverseJournalEntry(String jid, Map<String, dynamic> body) =>
      _post('/pilot/journal-entries/$jid/reverse', body);

  Future<ApiResult> postPosToGl(String posTxnId) =>
      _post('/pilot/pos-transactions/$posTxnId/post-to-gl');

  Future<ApiResult> trialBalance(String eid,
      {String? asOf, bool includeZero = false}) {
    final qp = <String, String>{
      'include_zero': '$includeZero',
      if (asOf != null) 'as_of': asOf,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/entities/$eid/reports/trial-balance?$qs');
  }
  Future<ApiResult> incomeStatement(
          String eid, String startDate, String endDate) =>
      _get(
          '/pilot/entities/$eid/reports/income-statement?start_date=$startDate&end_date=$endDate');
  Future<ApiResult> balanceSheet(String eid, {String? asOf}) => _get(
      '/pilot/entities/$eid/reports/balance-sheet${asOf != null ? "?as_of=$asOf" : ""}');

  // ═════════════════════════════════════════════════════════════
  // 9. COMPLIANCE — ZATCA / GOSI / WPS / UAE CT / VAT Return
  // ═════════════════════════════════════════════════════════════

  // ZATCA
  Future<ApiResult> zatcaOnboard(String eid,
          {String environment = 'developer_portal', bool simulate = true}) =>
      _post(
          '/pilot/entities/$eid/zatca/onboard?environment=$environment&simulate=$simulate');
  Future<ApiResult> listZatcaOnboardings(String eid) =>
      _get('/pilot/entities/$eid/zatca/onboarding');
  Future<ApiResult> submitPosToZatca(String posTxnId, {bool simulate = true}) =>
      _post(
          '/pilot/pos-transactions/$posTxnId/zatca/submit?simulate=$simulate');
  Future<ApiResult> listZatcaSubmissions(String eid,
          {String? status, int limit = 100}) =>
      _get(
          '/pilot/entities/$eid/zatca/submissions?limit=$limit${status != null ? "&status=$status" : ""}');
  Future<ApiResult> decodeZatcaQr(String qrBase64) =>
      _get('/pilot/zatca/decode-qr?qr=${Uri.encodeQueryComponent(qrBase64)}');

  // GOSI
  Future<ApiResult> gosiRates() => _get('/pilot/gosi/rates');
  Future<ApiResult> gosiCalculate({required bool isSaudi, required String wage}) =>
      _post('/pilot/gosi/calculate?is_saudi=$isSaudi&wage=$wage');
  Future<ApiResult> createGosiRegistration(Map<String, dynamic> body) =>
      _post('/pilot/gosi/registrations', body);
  Future<ApiResult> listGosiRegistrations(String eid, {bool activeOnly = true}) =>
      _get('/pilot/entities/$eid/gosi/registrations?active_only=$activeOnly');
  Future<ApiResult> recordGosiContribution(
          String rid, Map<String, dynamic> body) =>
      _post('/pilot/gosi/registrations/$rid/contributions', body);

  // WPS
  Future<ApiResult> createWpsBatch(Map<String, dynamic> body) =>
      _post('/pilot/wps/batches', body);
  Future<ApiResult> listWpsBatches(String eid) =>
      _get('/pilot/entities/$eid/wps/batches');
  String wpsSifDownloadUrl(String batchId) =>
      '$_base/pilot/wps/batches/$batchId/sif';

  // UAE CT
  Future<ApiResult> uaeCtCalculate({
    required String grossRevenue,
    String exemptRevenue = '0',
    String qualifyingFzRevenue = '0',
    String deductibleExpenses = '0',
    String withholdingCredit = '0',
  }) {
    final qp = {
      'gross_revenue': grossRevenue,
      'exempt_revenue': exemptRevenue,
      'qualifying_fz_revenue': qualifyingFzRevenue,
      'deductible_expenses': deductibleExpenses,
      'withholding_credit': withholdingCredit,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _post('/pilot/uae-ct/calculate?$qs');
  }
  Future<ApiResult> createUaeCtFiling(Map<String, dynamic> body) =>
      _post('/pilot/uae-ct/filings', body);
  Future<ApiResult> listUaeCtFilings(String eid) =>
      _get('/pilot/entities/$eid/uae-ct/filings');

  // VAT Return
  Future<ApiResult> previewVatReturn({
    required String entityId,
    required int year,
    required int periodNumber,
    String periodType = 'quarterly',
  }) =>
      _get(
          '/pilot/vat-returns/preview?entity_id=$entityId&year=$year&period_number=$periodNumber&period_type=$periodType');
  Future<ApiResult> generateVatReturn(Map<String, dynamic> body) =>
      _post('/pilot/vat-returns/generate', body);
  Future<ApiResult> listVatReturns(String eid) =>
      _get('/pilot/entities/$eid/vat-returns');

  // ═════════════════════════════════════════════════════════════
  // 10. PURCHASING — Vendors / PO / GRN / Purchase Invoices / Payments
  // ═════════════════════════════════════════════════════════════

  // Vendors
  Future<ApiResult> listVendors(String tid,
      {String? kind, bool activeOnly = true, String? search}) {
    final qp = <String, String>{
      'active_only': '$activeOnly',
      if (kind != null) 'kind': kind,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/tenants/$tid/vendors?$qs');
  }
  Future<ApiResult> createVendor(String tid, Map<String, dynamic> body) =>
      _post('/pilot/tenants/$tid/vendors', body);
  Future<ApiResult> getVendor(String vid) => _get('/pilot/vendors/$vid');
  Future<ApiResult> updateVendor(String vid, Map<String, dynamic> body) =>
      _patch('/pilot/vendors/$vid', body);
  Future<ApiResult> vendorLedger(String vid) =>
      _get('/pilot/vendors/$vid/ledger');

  // Purchase Orders
  Future<ApiResult> createPurchaseOrder(Map<String, dynamic> body) =>
      _post('/pilot/purchase-orders', body);
  Future<ApiResult> listPurchaseOrders(String eid,
      {String? status, String? vendorId, int limit = 100}) {
    final qp = <String, String>{
      'limit': '$limit',
      if (status != null) 'status': status,
      if (vendorId != null) 'vendor_id': vendorId,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/entities/$eid/purchase-orders?$qs');
  }
  Future<ApiResult> getPurchaseOrder(String poId) =>
      _get('/pilot/purchase-orders/$poId');
  Future<ApiResult> approvePurchaseOrder(String poId, String userId) =>
      _post('/pilot/purchase-orders/$poId/approve',
          {'approved_by_user_id': userId});
  Future<ApiResult> issuePurchaseOrder(String poId) =>
      _post('/pilot/purchase-orders/$poId/issue');

  // Goods Receipts (GRN)
  Future<ApiResult> createGoodsReceipt(Map<String, dynamic> body) =>
      _post('/pilot/goods-receipts', body);
  Future<ApiResult> listGoodsReceipts(String poId) =>
      _get('/pilot/purchase-orders/$poId/receipts');
  Future<ApiResult> getGoodsReceipt(String grnId) =>
      _get('/pilot/goods-receipts/$grnId');

  // Purchase Invoices
  Future<ApiResult> createPurchaseInvoice(Map<String, dynamic> body) =>
      _post('/pilot/purchase-invoices', body);
  Future<ApiResult> postPurchaseInvoice(String piId) =>
      _post('/pilot/purchase-invoices/$piId/post');
  Future<ApiResult> listPurchaseInvoices(String eid,
      {String? status, String? vendorId, int limit = 100}) {
    final qp = <String, String>{
      'limit': '$limit',
      if (status != null) 'status': status,
      if (vendorId != null) 'vendor_id': vendorId,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/entities/$eid/purchase-invoices?$qs');
  }
  Future<ApiResult> getPurchaseInvoice(String piId) =>
      _get('/pilot/purchase-invoices/$piId');

  // Vendor Payments
  Future<ApiResult> createVendorPayment(Map<String, dynamic> body) =>
      _post('/pilot/vendor-payments', body);
  Future<ApiResult> listVendorPayments(String eid,
      {String? vendorId, int limit = 100}) {
    final qp = <String, String>{
      'limit': '$limit',
      if (vendorId != null) 'vendor_id': vendorId,
    };
    final qs = qp.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/pilot/entities/$eid/vendor-payments?$qs');
  }

  // ═════════════════════════════════════════════════════════════
  // 11. ATTACHMENTS — polymorphic ملفات مرفقة بأي كيان
  // ═════════════════════════════════════════════════════════════

  Future<ApiResult> createAttachment(Map<String, dynamic> body) =>
      _post('/pilot/attachments', body);

  Future<ApiResult> listAttachments(String parentType, String parentId) =>
      _get(
          '/pilot/attachments?parent_type=$parentType&parent_id=$parentId');

  Future<ApiResult> deleteAttachment(String id) =>
      _delete('/pilot/attachments/$id');

  Future<ApiResult> lockAttachment(String id, String reason) => _post(
      '/pilot/attachments/$id/lock?reason=${Uri.encodeQueryComponent(reason)}');

  // ── Health ─────────────────────────────────────────────────
  Future<ApiResult> health() => _get('/pilot/health');
}

/// Singleton instance for convenience.
final pilotClient = PilotClient();
