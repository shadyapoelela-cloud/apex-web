import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart' show BrowserClient;
import 'core/api_config.dart';
import 'core/auth_guard.dart' show apexAuthRefresh, apexScaffoldMessengerKey;
import 'core/session.dart';
import 'core/company_store.dart';
import 'core/entity_store.dart';

/// Shared HTTP client with `withCredentials = true`.
/// On Flutter web this tells the browser to attach the `apex_token`
/// HttpOnly cookie (issued by POST /auth/login) on every subsequent
/// request. The backend `extract_user_id()` helper now accepts EITHER
/// the Authorization: Bearer header OR the cookie, so the migration
/// is backwards-compatible — existing bearer callers keep working.
///
/// On non-web platforms BrowserClient is a no-op; normal HTTP applies.
final http.Client _httpClient = (() {
  final c = BrowserClient();
  c.withCredentials = true;
  return c;
})();

/// ERR-1 (2026-05-07): centralized handler for 401 responses.
///
/// Triggered from every ApiResult-producing helper when the backend
/// returns 401 (token missing / invalid / expired). Effects, in
/// order:
///   1. Clear local session state (`S.clear()` — token + uid + roles
///      + tenant + entity + permissions, in-memory and localStorage).
///   2. Show a SnackBar via the global `apexScaffoldMessengerKey`:
///      "انتهت جلستك. يرجى تسجيل الدخول مجددًا."
///   3. Bump `apexAuthRefresh`. `appRouter` listens via
///      `refreshListenable`, so GoRouter re-evaluates the auth guard
///      and bounces the user to `/login?return_to=<original path>`.
///
/// Idempotent: once `S.token` is null the handler short-circuits, so
/// concurrent in-flight requests that all hit 401 only run the
/// teardown once.
class _SessionExpiryHandler {
  static bool _handling = false;

  static void handle() {
    if (_handling) return;
    if (S.token == null || S.token!.isEmpty) return;
    _handling = true;
    try {
      S.clear();
      ApiService.clearToken();
      apexScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('انتهت جلستك. يرجى تسجيل الدخول مجددًا.'),
          duration: Duration(seconds: 3),
        ),
      );
      // Bumping the notifier triggers GoRouter's redirect re-evaluation,
      // which now sees `S.token == null` and emits the
      // `/login?return_to=<encoded path>` redirect.
      apexAuthRefresh.value++;
    } finally {
      _handling = false;
    }
  }
}

class ApiService {
  static const _base = apiBase;
  static String? _token;
    static void setToken(String t) => _token = t;
  static void clearToken() => _token = null;
  static bool get isAuthenticated => _token != null;
  static Map<String,String> get _h => {'Content-Type':'application/json', if((_token ?? S.token)!=null)'Authorization':'Bearer ${_token ?? S.token ?? ""}'};

  // ── Admin secret (X-Admin-Secret header) ──
  // Persisted in localStorage so the admin doesn't have to retype it every
  // session. Cleared on logout via S.clear() side-effects elsewhere.
  static String? _adminSecret;
  static String? get adminSecret {
    _adminSecret ??= html.window.localStorage['apex_admin_secret'];
    return _adminSecret;
  }
  static set adminSecret(String? v) {
    _adminSecret = v;
    if (v != null && v.isNotEmpty) {
      html.window.localStorage['apex_admin_secret'] = v;
    } else {
      html.window.localStorage.remove('apex_admin_secret');
    }
  }
  static bool get hasAdminSecret => (adminSecret ?? '').isNotEmpty;
  static Map<String,String> get _ha => {
    ..._h,
    if (hasAdminSecret) 'X-Admin-Secret': adminSecret!,
  };

  // ── Auth ──
  /// G-CLEANUP-2 (Sprint 15): probe whether the current token is still
  /// valid against the backend. Reuses the existing `/users/me`
  /// endpoint (which goes through `Depends(get_current_user)` and
  /// returns 401 on missing / invalid / expired token). Fail-closed:
  /// any non-200 result — including network errors and timeouts —
  /// is treated as invalid, so we err toward forcing the user to
  /// re-login rather than silently trusting a stale localStorage
  /// token. See APEX_BLUEPRINT/09 § 20.1 G-CLEANUP-2.
  static Future<bool> validateToken() async {
    if ((_token ?? S.token) == null) return false;
    try {
      final res = await _httpClient
          .get(Uri.parse('$_base/users/me'), headers: _h)
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<ApiResult> login(String username, String password) => _post('/auth/login', {'username_or_email':username,'password':password});
  static Future<ApiResult> register({required String username, required String email, required String password, String? displayName, String? mobile, String? countryCode}) => _post('/auth/register', {'username':username,'email':email,'password':password,if(displayName!=null)'display_name':displayName,if(mobile!=null)'mobile':mobile,if(countryCode!=null)'mobile_country_code':countryCode});
  static Future<ApiResult> forgotPassword(String email) => _post('/auth/forgot-password', {'email':email});
  static Future<ApiResult> changePassword({required String current, required String newPw, required String confirm}) => _put('/users/me/security/password', {'current_password':current,'new_password':newPw,'confirm_password':confirm});

  // ── 2FA / TOTP (wire-up for the existing backend TOTP service) ──
  /// Generate a fresh TOTP secret + recovery codes. User must scan QR
  /// (or enter secret manually) and then call [totpVerify] with a code
  /// from their authenticator app to activate 2FA.
  static Future<ApiResult> totpSetup() => _post('/auth/totp/setup', const {});

  /// Verify a 6-digit TOTP code (or 8-char recovery code). First
  /// successful call activates 2FA for this user.
  static Future<ApiResult> totpVerify(String code) =>
      _post('/auth/totp/verify', {'code': code});

  /// Disable 2FA after proving knowledge of a current code or recovery
  /// code. Clears the encrypted secret.
  static Future<ApiResult> totpDisable(String code) =>
      _post('/auth/totp/disable', {'code': code});

  /// Lightweight status probe — returns {enabled, enabled_at}.
  static Future<ApiResult> totpStatus() => _get('/auth/totp/status');

  // ── Email verification ──
  /// Send a verification email with a one-time token (24h TTL).
  /// Returns {sent: true, expires_in_hours: 24}.
  static Future<ApiResult> sendEmailVerification() =>
      _post('/auth/email/send-verification', const {});

  /// Consume the token from the email and flip email_verified=true.
  static Future<ApiResult> verifyEmail(String token) =>
      _post('/auth/email/verify', {'token': token});

  /// Status probe — {email, verified}.
  static Future<ApiResult> emailStatus() => _get('/auth/email/status');

  // ── Account ──
  static Future<ApiResult> getProfile() => _get('/users/me');
  static Future<ApiResult> updateProfile(Map b) => _put('/users/me/profile', b);
  static Future<ApiResult> getSecuritySettings() => _get('/users/me/security');
  static Future<ApiResult> getActivityHistory({int limit=20}) => _get('/account/activity?limit=$limit');
  static Future<ApiResult> requestClosure({required String type, String? reason}) => _post('/account/closure', {'type':type,if(reason!=null)'reason':reason});

  // ── Plans ──
  static Future<ApiResult> getPlans() => _get('/plans');
  static Future<ApiResult> getCurrentPlan() => _get('/subscriptions/me');
  static Future<ApiResult> getEntitlements() => _get('/entitlements/me');
  static Future<ApiResult> upgradePlan(String planId) => _post('/subscriptions/upgrade', {'plan_id':planId});
  static Future<ApiResult> upgradePlanByName(String planName) => _post('/subscriptions/upgrade?plan_name=$planName', {});
  static Future<ApiResult> comparePlans() => _get('/plans/compare');

  // ── Legal ──
  static Future<ApiResult> getTerms() => _get('/legal/terms');
  static Future<ApiResult> getPrivacyPolicy() => _get('/legal/privacy');
  static Future<ApiResult> acceptLegal({required String documentType, required String version}) => _post('/legal/accept', {'document_type':documentType,'version':version});
  static Future<ApiResult> getLegalDocuments() => _get('/legal/documents');
  static Future<ApiResult> getLegalPending() => _get('/legal/pending');
  static Future<ApiResult> acceptLegalDoc(String docId) => _post('/legal/accept/$docId', {});
  static Future<ApiResult> acceptAllLegal() => _post('/legal/accept-all', {});

  // ── Clients (aka "الشركات") ──
  // Guest-mode safe: when the backend can't be reached (or returns 401
  // because login is disabled), we transparently fall back to the local
  // CompanyLocalStore so guests can still create & browse their companies.
  static Future<ApiResult> getClientTypes() => _get('/client-types');
  static Future<ApiResult> listNotifications() => _get('/notifications');

  /// Returns the list of companies the user sees. Merges three sources:
  ///   1. Remote /clients (if authenticated & reachable)
  ///   2. Unified EntityStore companies (new hierarchical setup)
  ///   3. Legacy CompanyLocalStore (pre-refactor local companies)
  static Future<ApiResult> listClients() async {
    final entityStoreList = EntityStore.legacyClientsProjection();
    final legacyList = CompanyLocalStore.list();
    final remote = await _get('/clients');
    if (remote.success) {
      final raw = remote.data;
      final list = raw is List
          ? raw.cast<Map<String, dynamic>>()
          : ((raw is Map && raw['clients'] is List)
              ? (raw['clients'] as List).cast<Map<String, dynamic>>()
              : <Map<String, dynamic>>[]);
      final merged = CompanyLocalStore.mergeWithRemote(list);
      final byId = <String, Map<String, dynamic>>{};
      for (final m in [...legacyList, ...merged, ...entityStoreList]) {
        final id = m['id']?.toString();
        if (id != null) byId[id] = m;
      }
      return ApiResult.ok(byId.values.toList());
    }
    // Backend unreachable or 401 — degrade to combined local sources.
    final byId = <String, Map<String, dynamic>>{};
    for (final m in [...legacyList, ...entityStoreList]) {
      final id = m['id']?.toString();
      if (id != null) byId[id] = m;
    }
    return ApiResult.ok(byId.values.toList());
  }

  static Future<ApiResult> getClient(String id) async {
    if (id.startsWith('local_')) {
      final local = CompanyLocalStore.list().firstWhere(
        (c) => c['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      if (local.isEmpty) return ApiResult.error('الشركة غير موجودة');
      return ApiResult.ok(local);
    }
    return _get('/clients/$id');
  }

  static Future<ApiResult> createClient({
    required String clientCode,
    required String name,
    required String clientType,
    String? nameAr,
    String? industry,
    String? country,
    String? currency,
  }) async {
    final body = {
      'client_code': clientCode,
      'name': name,
      'name_ar': nameAr ?? name,
      'client_type_code': clientType,
      if (industry != null) 'industry': industry,
      if (country != null) 'country': country,
      if (currency != null) 'currency': currency,
    };
    final remote = await _post('/clients', body);
    if (remote.success) {
      // Also mirror to local store so list survives a later 401.
      final d = remote.data;
      if (d is Map) {
        CompanyLocalStore.add(Map<String, dynamic>.from(d));
      }
      return remote;
    }
    // Fallback: persist to local store, return a synthetic success.
    final saved = CompanyLocalStore.add(body);
    return ApiResult.ok({
      ...saved,
      '_local_only': true,
      '_notice': 'تم الحفظ محلياً (بدون تسجيل دخول)',
    });
  }

  static Future<ApiResult> updateClient(String id, Map body) async {
    if (id.startsWith('local_')) {
      final updated =
          CompanyLocalStore.update(id, Map<String, dynamic>.from(body));
      if (updated == null) return ApiResult.error('الشركة غير موجودة');
      return ApiResult.ok(updated);
    }
    final remote = await _put('/clients/$id', body);
    if (remote.success) {
      CompanyLocalStore.update(id, Map<String, dynamic>.from(body));
    }
    return remote;
  }


  // ── Client Onboarding (New) ──
  static Future<ApiResult> getLegalEntityTypes() => _get('/legal-entity-types');
  static Future<ApiResult> getSectors() => _get('/sectors');
  static Future<ApiResult> getSubSectors(String mainCode) => _get('/sectors/$mainCode/sub');
  static Future<ApiResult> getOnboardingDraft() => _get('/onboarding/draft');
  static Future<ApiResult> saveOnboardingDraft({required int step, required Map data}) => _post('/onboarding/draft', {'step_completed':step,'draft_data':data});
  static Future<ApiResult> createClientFromOnboarding(Map body) => _post('/clients', body);
  static Future<ApiResult> getClientRequiredDocs(String clientId) => _get('/clients/$clientId/required-documents');
  static Future<ApiResult> getStageNotes(String service, String stage, {String role='all'}) => _get('/stage-notes/$service/$stage?role=$role');

  // ── Archive (New) ──
  static Future<ApiResult> getUserArchive({int page=1}) => _get('/account/archive?page=$page');
  static Future<ApiResult> getClientArchive(String clientId, {int page=1}) => _get('/clients/$clientId/archive?page=$page');
  static Future<ApiResult> attachFromArchive(String itemId, {required String processType, required String processId}) => _post('/archive/items/$itemId/attach', {'target_process_type':processType,'target_process_id':processId});
  static Future<ApiResult> deleteArchiveItem(String id) => _delete('/archive/items/$id');

  // ── Service Catalog (New) ──
  static Future<ApiResult> getServiceCatalog({String? category}) => _get('/services/catalog${category!=null?"?category=$category":""}');
  static Future<ApiResult> getServiceDetail(String code) => _get('/services/catalog/$code');
  static Future<ApiResult> createServiceCase({required String clientId, required String serviceCode}) => _post('/services/cases', {'client_id':clientId,'service_code':serviceCode});
  static Future<ApiResult> getServiceCases({String? clientId}) => _get('/services/cases${clientId!=null?"?client_id=$clientId":""}');

  // ── Audit Service (New) ──
  static Future<ApiResult> getAuditTemplates({String? area}) => _get('/audit/templates${area!=null?"?area=$area":""}');
  static Future<ApiResult> createAuditSample(String caseId, Map body) => _post('/audit/cases/$caseId/samples', body);
  static Future<ApiResult> getAuditSamples(String caseId) => _get('/audit/cases/$caseId/samples');
  static Future<ApiResult> createWorkpaper(String caseId, Map body) => _post('/audit/cases/$caseId/workpapers', body);
  static Future<ApiResult> getWorkpapers(String caseId) => _get('/audit/cases/$caseId/workpapers');
  static Future<ApiResult> createFinding(String caseId, Map body) => _post('/audit/cases/$caseId/findings', body);
  static Future<ApiResult> getFindings(String caseId) => _get('/audit/cases/$caseId/findings');

  // ── COA ──
  static Future<ApiResult> uploadCoa({required String clientId, required List<int> bytes, required String fileName}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/clients/$clientId/coa/upload'));
      request.headers['Authorization']='Bearer ${_token ?? S.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      final res = await request.send();
      final body = await res.stream.bytesToString();
      if(res.statusCode==200) return ApiResult.ok(jsonDecode(body));
      return ApiResult.error(_parseErr(body,res.statusCode));
    } catch(e) { return ApiResult.error('خطأ: $e'); }
  }
  static Future<ApiResult> parseCoa({required String uploadId, required Map<String,String> columnMapping}) => _post('/coa/uploads/$uploadId/parse', {'column_mapping':columnMapping});
  static Future<ApiResult> classifyCoa(String uploadId) => _post('/coa/classify/$uploadId', {});
  static Future<ApiResult> assessCoa(String uploadId) => _post('/coa/uploads/$uploadId/assess', {});
  static Future<ApiResult> approveCoa(String uploadId) => _post('/coa/uploads/$uploadId/approve', {});
  static Future<ApiResult> getCoaAccounts({required String uploadId, int page=1, int pageSize=50}) => _get('/coa/uploads/$uploadId/accounts?page=$page&page_size=$pageSize');
  static Future<ApiResult> getCoaMappingPreview({required String uploadId, int page=1, String? filter}) {
    var url = '/coa/mapping/$uploadId?page=$page&page_size=40';
    if(filter=='low') url+='&confidence_max=0.74';
    if(filter=='unclassified') url+='&confidence_max=0.39';
    return _get(url);
  }
  static Future<ApiResult> bulkApprove({required String uploadId, double minConfidence=0.75}) => _post('/coa/bulk-approve/$uploadId', {'min_confidence':minConfidence});
  static Future<ApiResult> approveAccount(String accountId) => _post('/coa/approve/$accountId', {});
  static Future<ApiResult> getClassificationSummary(String uploadId) => _get('/coa/classification-summary/$uploadId');

  // ── Simulation ──
  static Future<ApiResult> getFinancialSimulation(String uploadId) => _get('/coa/uploads/$uploadId/financial-simulation');
  static Future<ApiResult> getComplianceCheck(String uploadId) => _get('/coa/uploads/$uploadId/compliance-check');
  static Future<ApiResult> getRoadmap(String uploadId) => _get('/coa/uploads/$uploadId/roadmap');
  static Future<ApiResult> postTrialBalanceCheck(String uploadId, Map<String, dynamic> tb) => _post('/coa/uploads/$uploadId/trial-balance-check', tb);

  // ── TB ──
  static Future<ApiResult> uploadTb({required String clientId, required List<int> bytes, required String fileName, String? coaUploadId, String? periodLabel}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/clients/$clientId/tb/upload'));
      request.headers['Authorization']='Bearer ${_token ?? S.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      if(coaUploadId!=null) request.fields['coa_upload_id']=coaUploadId;
      if(periodLabel!=null) request.fields['period_label']=periodLabel;
      final res = await request.send();
      final body = await res.stream.bytesToString();
      if(res.statusCode==200) return ApiResult.ok(jsonDecode(body));
      return ApiResult.error(_parseErr(body,res.statusCode));
    } catch(e) { return ApiResult.error('خطأ: $e'); }
  }
  static Future<ApiResult> bindTb({required String tbUploadId, String? coaUploadId}) => _post('/tb/uploads/$tbUploadId/bind', {if(coaUploadId!=null)'coa_upload_id':coaUploadId});
  static Future<ApiResult> getBindingSummary(String tbUploadId) => _get('/tb/uploads/$tbUploadId/binding-summary');
  static Future<ApiResult> getBindingResults({required String tbUploadId, int page=1, String filter='all'}) {
    var url='/tb/uploads/$tbUploadId/binding-results?page=$page&page_size=30';
    if(filter=='matched') url+='&matched_only=true';
    if(filter=='unmatched') url+='&matched_only=false';
    if(filter=='review') url+='&requires_review=true';
    return _get(url);
  }
  static Future<ApiResult> approveBinding(String tbUploadId) => _post('/tb/uploads/$tbUploadId/approve-binding', {});

  // ── Analysis ──
  static Future<ApiResult> analyzeTrialBalance({required List<int> bytes, required String fileName, String industry='general'}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/analyze/trial-balance?industry=$industry'));
      request.headers['Authorization']='Bearer ${_token ?? S.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      final res = await request.send();
      final body = await res.stream.bytesToString();
      if(res.statusCode==200) return ApiResult.ok(jsonDecode(body));
      return ApiResult.error(_parseErr(body,res.statusCode));
    } catch(e) { return ApiResult.error('خطأ: $e'); }
  }

  // ── Full Analysis ──
  static Future<ApiResult> analyzeFull({required List<int> bytes, required String fileName}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/analyze/full'));
      request.headers['Authorization']='Bearer ${_token ?? S.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      final res = await request.send();
      final body = await res.stream.bytesToString();
      if(res.statusCode==200) return ApiResult.ok(jsonDecode(body));
      return ApiResult.error(_parseErr(body,res.statusCode));
    } catch(e) { return ApiResult.error('خطأ: $e'); }
  }

  // ── Reports ──
  static Future<List<int>?> downloadReport({required String type, required List<int> fileBytes, required String fileName}) async {
    try {
      final endpoint = type == 'pdf' ? '/reports/pdf' : '/reports/excel';
      final request = http.MultipartRequest('POST', Uri.parse('$_base$endpoint'));
      request.headers['Authorization']='Bearer ${_token ?? S.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));
      final res = await request.send();
      if(res.statusCode==200) return await res.stream.toBytes();
      return null;
    } catch(e, st) {
      // ignore: avoid_print
      print('ApiService.downloadSignedInvoice failed: $e\n$st');
      return null;
    }
  }

  // ── Templates ──
  static Future<void> downloadTrialBalanceTemplate({String downloadName = 'نموذج_ميزان_المراجعة.xlsx'}) async {
    try {
      final res = await http.get(Uri.parse('$_base/template/trial-balance'));
      if(res.statusCode==200) {
        final blob = html.Blob([res.bodyBytes],'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        (html.document.createElement('a') as html.AnchorElement)..href=url..download=downloadName..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch(e, st) {
      // ignore: avoid_print
      print('ApiService.downloadTrialBalanceTemplate failed: $e\n$st');
    }
  }

  // ── Knowledge ──
  static Future<ApiResult> submitFeedback({required String clientId, required String feedbackText, required String feedbackCategory, String? coaUploadId}) => _post('/coa/knowledge-feedback', {'client_id':clientId,'feedback_text':feedbackText,'feedback_category':feedbackCategory,if(coaUploadId!=null)'coa_upload_id':coaUploadId});
  static Future<ApiResult> getReviewQueue({String status='submitted'}) => _get('/knowledge-feedback/review-queue?status=$status');

  // ── Providers ──
  static Future<ApiResult> getProviderDocuments(String providerId) => _get('/service-providers/$providerId/documents');
  static Future<ApiResult> verifyProvider(String providerId, Map body) => _put('/service-providers/$providerId/verify', body);

  // ── Marketplace ──
  static Future<ApiResult> getTaskTypes() => _get('/task-types');
  static Future<ApiResult> getTaskDocuments(String requestId) => _get('/service-requests/$requestId/documents');
  static Future<ApiResult> getComplianceStatus(String providerId) => _get('/providers/compliance/$providerId');

  // ── Notifications ──
  static Future<ApiResult> getNotifications() => _get('/notifications');
  static Future<ApiResult> markAllRead() => _post('/notifications/mark-all-read', {});


  // ── Copilot AI ──
  static Future<ApiResult> copilotChat({required String message, String? sessionId, String? clientId}) => _post('/copilot/chat', {'message':message,if(sessionId!=null)'session_id':sessionId,if(clientId!=null)'client_id':clientId});
  static Future<ApiResult> copilotCreateSession({String? clientId, String sessionType='general'}) => _post('/copilot/sessions', {'client_id':clientId,'session_type':sessionType});
  static Future<ApiResult> copilotGetSessions() => _get('/copilot/sessions');
  static Future<ApiResult> copilotGetMessages(String sessionId) => _get('/copilot/sessions/$sessionId/messages');
  static Future<ApiResult> copilotDetectIntent(String message) => _post('/copilot/detect-intent', {'message':message});
  static Future<ApiResult> copilotCloseSession(String sessionId) => _post('/copilot/sessions/$sessionId/close', {});

  // ── Ask APEX — agent with tool-use over the books ──
  /// Natural-language question answered by the Copilot agent.
  /// Wraps POST /api/v1/ai/ask. `history` is an optional list of
  /// prior {"role": "...", "content": "..."} maps for multi-turn.
  static Future<ApiResult> aiAsk(String query, {List<Map<String,dynamic>>? history, int maxTurns=5}) =>
      _post('/api/v1/ai/ask', {'query':query, if(history!=null)'history':history, 'max_turns':maxTurns});

  /// Claude token + cost summary for the calling tenant in the current month.
  /// Wraps GET /api/v1/ai/usage.
  static Future<ApiResult> aiUsage({String? tenantId, String? since}) {
    final qs = <String>[];
    if (tenantId != null) qs.add('tenant_id=${Uri.encodeQueryComponent(tenantId)}');
    if (since != null) qs.add('since=${Uri.encodeQueryComponent(since)}');
    final suffix = qs.isEmpty ? '' : '?${qs.join('&')}';
    return _get('/api/v1/ai/usage$suffix');
  }

  /// List AI suggestions — the pending-approval inbox.
  /// Wraps GET /api/v1/ai/suggestions.
  static Future<ApiResult> aiListSuggestions({String? status, String? source, int limit=50}) {
    final qs = <String>['limit=$limit'];
    if (status != null) qs.add('status=${Uri.encodeQueryComponent(status)}');
    if (source != null) qs.add('source=${Uri.encodeQueryComponent(source)}');
    return _get('/api/v1/ai/suggestions?${qs.join('&')}');
  }

  /// Fetch one AiSuggestion by id.
  static Future<ApiResult> aiGetSuggestion(String id) =>
      _get('/api/v1/ai/suggestions/$id');

  /// Human approves an AI suggestion — flips NEEDS_APPROVAL → APPROVED.
  static Future<ApiResult> aiApproveSuggestion(String id, {String? userId}) =>
      _post('/api/v1/ai/suggestions/$id/approve', {if(userId!=null)'user_id':userId});

  /// Human rejects an AI suggestion.
  static Future<ApiResult> aiRejectSuggestion(String id, {String? userId, String? reason}) =>
      _post('/api/v1/ai/suggestions/$id/reject', {
        if(userId!=null)'user_id':userId,
        if(reason!=null)'reason':reason,
      });

  /// Execute an approved suggestion (advances status → executed/failed).
  static Future<ApiResult> aiExecuteSuggestion(String id) =>
      _post('/api/v1/ai/suggestions/$id/execute', {});

  // ── Pilot: Customers + Sales Invoices ──
  static Future<ApiResult> pilotListCustomers(String tenantId, {String? search, int limit=100}) {
    final qs = <String>['limit=$limit'];
    if (search != null && search.isNotEmpty) qs.add('search=${Uri.encodeQueryComponent(search)}');
    return _get('/api/v1/pilot/tenants/$tenantId/customers?${qs.join('&')}');
  }
  static Future<ApiResult> pilotCreateCustomer(String tenantId, Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/tenants/$tenantId/customers', payload);
  static Future<ApiResult> pilotGetCustomer(String id) =>
      _get('/api/v1/pilot/customers/$id');
  static Future<ApiResult> pilotUpdateCustomer(String id, Map<String, dynamic> patch) =>
      _patch('/api/v1/pilot/customers/$id', patch);
  static Future<ApiResult> pilotCustomerLedger(String id) =>
      _get('/api/v1/pilot/customers/$id/ledger');
  static Future<ApiResult> pilotCreateSalesInvoice(Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/sales-invoices', payload);
  static Future<ApiResult> pilotIssueSalesInvoice(String id) =>
      _post('/api/v1/pilot/sales-invoices/$id/issue', {});
  static Future<ApiResult> pilotListSalesInvoices(String entityId, {String? status, int limit=100}) {
    final qs = <String>['limit=$limit'];
    if (status != null) qs.add('status=${Uri.encodeQueryComponent(status)}');
    return _get('/api/v1/pilot/entities/$entityId/sales-invoices?${qs.join('&')}');
  }
  static Future<ApiResult> pilotRecordCustomerPayment(String invoiceId, Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/sales-invoices/$invoiceId/payment', payload);

  // ── Pilot: Vendors (existing) ──
  static Future<ApiResult> pilotListVendors(String tenantId, {int limit=100}) =>
      _get('/api/v1/pilot/tenants/$tenantId/vendors?limit=$limit');
  static Future<ApiResult> pilotCreateVendor(String tenantId, Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/tenants/$tenantId/vendors', payload);
  // G-FIN-VENDORS-COMPLETE (Sprint 3, 2026-05-09): get + ledger
  // backing the new VendorDetailsScreen 3-tab UI.
  static Future<ApiResult> pilotGetVendor(String id) =>
      _get('/api/v1/pilot/vendors/$id');
  static Future<ApiResult> pilotUpdateVendor(String id, Map<String, dynamic> patch) =>
      _patch('/api/v1/pilot/vendors/$id', patch);
  static Future<ApiResult> pilotVendorLedger(String id) =>
      _get('/api/v1/pilot/vendors/$id/ledger');
  // pilotListPurchaseInvoices already defined further down — see line 681.

  // ── Pilot: Products (existing) ──
  static Future<ApiResult> pilotListProducts(String tenantId, {int limit=100}) =>
      _get('/api/v1/pilot/tenants/$tenantId/products?limit=$limit');
  static Future<ApiResult> pilotCreateProduct(String tenantId, Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/tenants/$tenantId/products', payload);

  // ── Pilot: Journal Entries (existing) ──
  static Future<ApiResult> pilotListJournalEntries(String entityId, {int limit=100}) =>
      _get('/api/v1/pilot/entities/$entityId/journal-entries?limit=$limit');
  static Future<ApiResult> pilotCreateJournalEntry(Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/journal-entries', payload);
  static Future<ApiResult> pilotPostJournalEntry(String jeId) =>
      _post('/api/v1/pilot/journal-entries/$jeId/post', {});
  static Future<ApiResult> pilotGetJournalEntry(String jeId) =>
      _get('/api/v1/pilot/journal-entries/$jeId');

  // ── Pilot: Reports — TB / IS / BS / Cash Flow ──
  // Note: gl_routes uses prefix '/pilot' (no /api/v1) — different from customer_routes.
  static Future<ApiResult> pilotTrialBalance(String entityId, {String? asOf, bool includeZero = false}) {
    final params = <String>[];
    if (asOf != null) params.add('as_of=$asOf');
    if (includeZero) params.add('include_zero=true');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return _get('/pilot/entities/$entityId/reports/trial-balance$qs');
  }
  /// G-FIN-IS-1 (2026-05-08): supports include_zero + compare_period.
  /// Backed by `pilot_gl_postings` (real posted JEs only — no mocks,
  /// no fallbacks). Documented in `docs/INCOME_STATEMENT_DATA_FLOW_2026-05-08.md`.
  static Future<ApiResult> pilotIncomeStatement(
    String entityId, {
    required String startDate,
    required String endDate,
    bool includeZero = false,
    String comparePeriod = 'none',
  }) {
    final params = <String>[
      'start_date=$startDate',
      'end_date=$endDate',
    ];
    if (includeZero) params.add('include_zero=true');
    if (comparePeriod != 'none') params.add('compare_period=$comparePeriod');
    return _get(
      '/pilot/entities/$entityId/reports/income-statement?${params.join('&')}',
    );
  }
  /// G-FIN-BS-1 (2026-05-08): supports compare_as_of + include_zero.
  /// Backed by `pilot_gl_postings` (real posted JEs only — no mocks,
  /// no fallbacks). Documented in
  /// `docs/BALANCE_SHEET_DATA_FLOW_2026-05-08.md`.
  static Future<ApiResult> pilotBalanceSheet(
    String entityId, {
    String? asOf,
    String? compareAsOf,
    bool includeZero = false,
  }) {
    final params = <String>[];
    if (asOf != null) params.add('as_of=$asOf');
    if (compareAsOf != null) params.add('compare_as_of=$compareAsOf');
    if (includeZero) params.add('include_zero=true');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return _get('/pilot/entities/$entityId/reports/balance-sheet$qs');
  }
  /// G-FIN-CF-1 (2026-05-08): supports method + compare_period +
  /// include_zero. Backed by `pilot_gl_postings` (real posted JEs
  /// only — no mocks, no fallbacks). Reconciliation invariant
  /// (opening_cash + net_change = closing_cash) verified server-side
  /// via `is_reconciled`. Documented in
  /// `docs/CASH_FLOW_DATA_FLOW_2026-05-08.md`.
  static Future<ApiResult> pilotCashFlow(
    String entityId, {
    required String startDate,
    required String endDate,
    String method = 'indirect',
    String comparePeriod = 'none',
    bool includeZero = false,
  }) {
    final params = <String>[
      'start_date=$startDate',
      'end_date=$endDate',
    ];
    if (method != 'indirect') params.add('method=$method');
    if (comparePeriod != 'none') params.add('compare_period=$comparePeriod');
    if (includeZero) params.add('include_zero=true');
    return _get(
      '/pilot/entities/$entityId/reports/cash-flow?${params.join('&')}',
    );
  }
  static Future<ApiResult> pilotAccountLedger(String accountId, {String? startDate, String? endDate, int limit = 500}) {
    final params = <String>['limit=$limit'];
    if (startDate != null) params.add('start_date=$startDate');
    if (endDate != null) params.add('end_date=$endDate');
    return _get('/pilot/accounts/$accountId/ledger?${params.join('&')}');
  }
  static Future<ApiResult> pilotJournalEntryDetail(String jeId) =>
      _get('/pilot/journal-entries/$jeId');

  // ── Pilot: Chart of Accounts ──
  static Future<ApiResult> pilotListAccounts(String entityId, {String? category, String? type}) {
    final params = <String>[];
    if (category != null) params.add('category=$category');
    if (type != null) params.add('type=$type');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';
    return _get('/pilot/entities/$entityId/accounts$qs');
  }
  static Future<ApiResult> pilotSeedCoa(String entityId) =>
      _post('/pilot/entities/$entityId/coa/seed', {});
  static Future<ApiResult> pilotSeedFiscalPeriods(String entityId, {required int year}) =>
      _post('/pilot/entities/$entityId/fiscal-periods/seed', {'year': year});

  // ── AI Onboarding (one-call tenant + entity + COA + periods) ──
  static Future<ApiResult> aiOnboardingComplete({
    required String companyName,
    String country = 'sa',
    String? vatNumber,
    String? industry,
    String? email,
  }) => _post('/api/v1/ai/onboarding/complete', {
        'company_name': companyName,
        'country': country,
        if (vatNumber != null) 'vat_number': vatNumber,
        if (industry != null) 'industry': industry,
        if (email != null) 'email': email,
      });
  static Future<ApiResult> aiOnboardingSeedDemo({required String tenantId, required String entityId}) =>
      _post('/api/v1/ai/onboarding/seed-demo', {'tenant_id': tenantId, 'entity_id': entityId});

  // ── Pilot: Purchase cycle ──
  static Future<ApiResult> pilotListPOs(String entityId, {int limit=100}) =>
      _get('/api/v1/pilot/entities/$entityId/purchase-orders?limit=$limit');
  static Future<ApiResult> pilotCreatePO(Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/purchase-orders', payload);
  static Future<ApiResult> pilotApprovePO(String poId) =>
      _post('/api/v1/pilot/purchase-orders/$poId/approve', {});
  static Future<ApiResult> pilotIssuePO(String poId) =>
      _post('/api/v1/pilot/purchase-orders/$poId/issue', {});
  static Future<ApiResult> pilotPOReceipts(String poId) =>
      _get('/api/v1/pilot/purchase-orders/$poId/receipts');
  static Future<ApiResult> pilotListPurchaseInvoices(String entityId, {int limit=100}) =>
      _get('/api/v1/pilot/entities/$entityId/purchase-invoices?limit=$limit');
  static Future<ApiResult> pilotPostPurchaseInvoice(String piId) =>
      _post('/api/v1/pilot/purchase-invoices/$piId/post', {});
  static Future<ApiResult> pilotCreateVendorPayment(Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/vendor-payments', payload);

  // ── Pilot: POS ──
  static Future<ApiResult> pilotListPosSessions(String branchId, {int limit=50}) =>
      _get('/api/v1/pilot/branches/$branchId/pos-sessions?limit=$limit');
  static Future<ApiResult> pilotCreatePosSession(String branchId, Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/branches/$branchId/pos-sessions', payload);
  static Future<ApiResult> pilotClosePosSession(String sessionId, Map<String, dynamic> payload) =>
      _post('/api/v1/pilot/pos-sessions/$sessionId/close', payload);
  static Future<ApiResult> pilotZReport(String sessionId) =>
      _get('/api/v1/pilot/pos-sessions/$sessionId/z-report');
  static Future<ApiResult> pilotListPosTransactions(String sessionId) =>
      _get('/api/v1/pilot/pos-sessions/$sessionId/transactions');
  static Future<ApiResult> pilotPostPosToGL(String posTxnId) =>
      _post('/api/v1/pilot/pos-transactions/$posTxnId/post-to-gl', {});

  // Financial Statements endpoints are declared below (fsTrialBalance / fsIncomeStatement / fsBalanceSheet) — reused.

  // ── HR: Employees (existing) ──
  static Future<ApiResult> hrListEmployees({int limit=100}) => _get('/api/v1/employees?limit=$limit');
  static Future<ApiResult> hrCreateEmployee(Map<String, dynamic> payload) => _post('/api/v1/employees', payload);

  // ── Period close checklist ──
  static Future<ApiResult> periodCloseStart(Map<String, dynamic> body) =>
      _post('/api/v1/ai/period-close/start', body);
  static Future<ApiResult> periodCloseList({String? tenantId, String? entityId}) {
    final qs = <String>[];
    if (tenantId != null) qs.add('tenant_id=${Uri.encodeQueryComponent(tenantId)}');
    if (entityId != null) qs.add('entity_id=${Uri.encodeQueryComponent(entityId)}');
    final suffix = qs.isEmpty ? '' : '?${qs.join('&')}';
    return _get('/api/v1/ai/period-close$suffix');
  }
  static Future<ApiResult> periodCloseGet(String id) =>
      _get('/api/v1/ai/period-close/$id');
  static Future<ApiResult> periodCloseCompleteTask(String taskId, {String? userId, String? notes}) =>
      _post('/api/v1/ai/period-close/tasks/$taskId/complete', {
        if (userId != null) 'user_id': userId,
        if (notes != null) 'notes': notes,
      });

  // ── Onboarding ──
  static Future<ApiResult> onboardingComplete(Map<String, dynamic> body) =>
      _post('/api/v1/ai/onboarding/complete', body);
  static Future<ApiResult> onboardingSeedDemo(String tenantId, String entityId) =>
      _post('/api/v1/ai/onboarding/seed-demo', {'tenant_id': tenantId, 'entity_id': entityId});

  // ── Consolidation (POST ACDOCA-style multi-entity TBs) ──
  // Already declared above as aiConsolidate.

  // ── POS (more methods) ──
  static Future<ApiResult> pilotListBranches(String tenantId) =>
      _get('/api/v1/pilot/tenants/$tenantId/branches');
  static Future<ApiResult> pilotEntityBranches(String entityId) =>
      _get('/api/v1/pilot/entities/$entityId/branches');
  static Future<ApiResult> pilotGoodsReceiptCreate(Map<String, dynamic> body) =>
      _post('/api/v1/pilot/goods-receipts', body);

  // ── SAP Universal Journal ──
  static Future<ApiResult> universalJournalQuery(Map<String, dynamic> filters) =>
      _post('/api/v1/ai/universal-journal/query', filters);
  static Future<ApiResult> documentFlow(String sourceType, String sourceId) =>
      _get('/api/v1/ai/universal-journal/document-flow/$sourceType/$sourceId');

  // ── Audit hash-chain ──
  static Future<ApiResult> aiVerifyAuditChain({int limit=1000}) =>
      _get('/api/v1/ai/audit/chain/verify?limit=$limit');
  static Future<ApiResult> aiListAuditEvents({int limit=50}) =>
      _get('/api/v1/ai/audit/chain/events?limit=$limit');

  // ── Regulatory news ──
  static Future<ApiResult> aiRegulatoryNews({String? jurisdiction, bool onlyFuture=false, int limit=20}) {
    final qs = <String>['limit=$limit', 'only_future=$onlyFuture'];
    if (jurisdiction != null) qs.add('jurisdiction=${Uri.encodeQueryComponent(jurisdiction)}');
    return _get('/api/v1/ai/regulatory-news?${qs.join('&')}');
  }

  // ── Fixed-asset depreciation ──
  static Future<ApiResult> aiDepreciationSchedule(Map<String, dynamic> payload) =>
      _post('/api/v1/ai/fixed-assets/schedule', payload);

  // ── Multi-currency dashboard ──
  static Future<ApiResult> aiMultiCurrencyDashboard({String displayCurrency='SAR'}) =>
      _get('/api/v1/ai/multi-currency/dashboard?display_currency=$displayCurrency');

  // ── Audit workflow ──
  static Future<ApiResult> aiBenford({List<double>? amounts, String? startDate, String? endDate}) =>
      _post('/api/v1/ai/audit/benford', {
        if (amounts != null) 'amounts': amounts,
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
      });
  static Future<ApiResult> aiJeSample({String? startDate, String? endDate, int sampleSize=25, double thresholdAmount=10000}) =>
      _post('/api/v1/ai/audit/je-sample', {
        if (startDate != null) 'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        'sample_size': sampleSize,
        'threshold_amount': thresholdAmount,
      });
  static Future<ApiResult> aiListWorkpapers() => _get('/api/v1/ai/audit/workpapers');
  static Future<ApiResult> aiGetWorkpaper(String id) => _get('/api/v1/ai/audit/workpapers/$id');

  // ── Consolidation ──
  static Future<ApiResult> aiConsolidate(Map<String, dynamic> payload) =>
      _post('/api/v1/ai/consolidation', payload);

  // ── Islamic finance ──
  static Future<ApiResult> aiMurabaha({required double costPrice, required double sellingPrice, required String startDate, required int installments, int periodDays=30}) =>
      _post('/api/v1/ai/islamic/murabaha', {
        'cost_price': costPrice,
        'selling_price': sellingPrice,
        'start_date': startDate,
        'installments': installments,
        'period_days': periodDays,
      });
  static Future<ApiResult> aiIjarah({required double rentalPerPeriod, required int periods, required String startDate, int periodDays=30, double assetValue=0, int usefulLifePeriods=0}) =>
      _post('/api/v1/ai/islamic/ijarah', {
        'rental_per_period': rentalPerPeriod,
        'periods': periods,
        'start_date': startDate,
        'period_days': periodDays,
        'asset_value': assetValue,
        'useful_life_periods': usefulLifePeriods,
      });
  static Future<ApiResult> aiZakah(Map<String, dynamic> inputs) =>
      _post('/api/v1/ai/islamic/zakah', inputs);

  /// List industry-specific COA templates.
  static Future<ApiResult> aiListCoaTemplates() =>
      _get('/api/v1/ai/coa-templates');

  /// Fetch one COA template with its full account list.
  static Future<ApiResult> aiGetCoaTemplate(String id) =>
      _get('/api/v1/ai/coa-templates/$id');

  /// Candidate matches for a bank-feed transaction (AI-assisted rec).
  static Future<ApiResult> aiBankRecSuggestions(String txnId, {int limit=5, double minConfidence=0.30}) =>
      _get('/api/v1/ai/bank-rec/suggestions/$txnId?limit=$limit&min_confidence=$minConfidence');

  /// Batch-auto-apply high-confidence bank matches.
  static Future<ApiResult> aiBankRecAutoMatch({int limit=100, double confidenceFloor=0.95}) =>
      _post('/api/v1/ai/bank-rec/auto-match?limit=$limit&confidence_floor=$confidenceFloor', {});

  /// List unreconciled bank transactions.
  static Future<ApiResult> listBankTransactions({bool unreconciledOnly=true, int limit=200}) =>
      _get('/api/v1/bank-feeds/transactions?unreconciled_only=$unreconciledOnly&limit=$limit');

  /// Mark a bank txn as reconciled against a journal entry or invoice.
  static Future<ApiResult> markBankTxnReconciled(String txnId, {required String entityType, required String entityId}) =>
      _post('/api/v1/bank-feeds/transactions/$txnId/reconcile', {
        'entity_type': entityType,
        'entity_id': entityId,
      });

  /// Upcoming tax / compliance obligations for the next N days.
  static Future<ApiResult> aiTaxTimeline({
    int horizonDays = 120,
    String country = 'sa',
    String vatCadence = 'monthly',
    String? fiscalYearEnd,
    String? csidExpiresAt,
  }) {
    final qs = <String>[
      'horizon_days=$horizonDays',
      'country=${Uri.encodeQueryComponent(country)}',
      'vat_cadence=${Uri.encodeQueryComponent(vatCadence)}',
    ];
    if (fiscalYearEnd != null) qs.add('fiscal_year_end=${Uri.encodeQueryComponent(fiscalYearEnd)}');
    if (csidExpiresAt != null) qs.add('zatca_csid_expires_at=${Uri.encodeQueryComponent(csidExpiresAt)}');
    return _get('/api/v1/ai/tax-timeline?${qs.join('&')}');
  }

    // ── Helpers (use _httpClient so HttpOnly cookies ride along) ──
  // ERR-1 (2026-05-07): every response goes through `_handleResponse`
  // so a 401 anywhere triggers `_SessionExpiryHandler` exactly once.
  static ApiResult _handleResponse(http.Response res) {
    if (res.statusCode == 401) {
      _SessionExpiryHandler.handle();
      return ApiResult.error('انتهت جلستك');
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return ApiResult.ok(jsonDecode(res.body));
    }
    return ApiResult.error(_parseErr(res.body, res.statusCode));
  }

  static Future<ApiResult> _get(String path) async {
    try { final res = await _httpClient.get(Uri.parse('$_base$path'), headers: _h); return _handleResponse(res); } catch (e) { return ApiResult.error('خطأ: $e'); }
  }
  static Future<ApiResult> _post(String path, Map body) async {
    try { final res = await _httpClient.post(Uri.parse('$_base$path'), headers: _h, body: jsonEncode(body)); return _handleResponse(res); } catch (e) { return ApiResult.error('خطأ: $e'); }
  }
  static Future<ApiResult> _put(String path, Map body) async {
    try { final res = await _httpClient.put(Uri.parse('$_base$path'), headers: _h, body: jsonEncode(body)); return _handleResponse(res); } catch (e) { return ApiResult.error('خطأ: $e'); }
  }
  static Future<ApiResult> _delete(String path) async {
    try { final res = await _httpClient.delete(Uri.parse('$_base$path'), headers: _h); return _handleResponse(res); } catch (e) { return ApiResult.error('خطأ: $e'); }
  }
  static Future<ApiResult> _patch(String path, Map body) async {
    try { final res = await _httpClient.patch(Uri.parse('$_base$path'), headers: _h, body: jsonEncode(body)); return _handleResponse(res); } catch (e) { return ApiResult.error('خطأ: $e'); }
  }
  static String _parseErr(String body, int code) { try { final d=jsonDecode(body); return d['detail']??d['message']??'خطأ $code'; } catch(_){return 'خطأ $code';} }

  // ── File Upload ──
  static Future<ApiResult> uploadDocument(String clientId, String docType, List<int> bytes, String fileName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/clients/$clientId/documents'));
      request.headers.addAll(_h);
      request.fields['doc_type'] = docType;
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) return ApiResult.ok(jsonDecode(body));
      return ApiResult.error(_parseErr(body, streamed.statusCode));
    } catch (e) { return ApiResult.error('خطأ: $e'); }
  }

  // ── Admin-secret-gated helpers (used by Wave 1A/1B/1C admin routes) ──
  // ERR-1 (2026-05-07): use the same `_handleResponse` so admin 401s
  // also trigger the session-expiry handler.
  static Future<ApiResult> _adminGet(String path) async {
    try {
      final res = await _httpClient.get(Uri.parse('$_base$path'), headers: _ha);
      return _handleResponse(res);
    } catch (e) { return ApiResult.error('خطأ: $e'); }
  }
  static Future<ApiResult> _adminPost(String path, [Map? body]) async {
    try {
      final res = await _httpClient.post(
        Uri.parse('$_base$path'),
        headers: _ha,
        body: jsonEncode(body ?? const {}),
      );
      return _handleResponse(res);
    } catch (e) { return ApiResult.error('خطأ: $e'); }
  }
  static Future<ApiResult> _adminPatch(String path, Map body) async {
    try {
      final res = await _httpClient.patch(Uri.parse('$_base$path'), headers: _ha, body: jsonEncode(body));
      return _handleResponse(res);
    } catch (e) { return ApiResult.error('خطأ: $e'); }
  }
  static Future<ApiResult> _adminDelete(String path) async {
    try {
      final res = await _httpClient.delete(Uri.parse('$_base$path'), headers: _ha);
      return _handleResponse(res);
    } catch (e) { return ApiResult.error('خطأ: $e'); }
  }

  // ── Workflow Engine + Templates (Wave 1A Phase G + Wave 1C Phase M) ──
  static Future<ApiResult> workflowListRules({String? tenantId}) =>
      _adminGet('/admin/workflow/rules${tenantId != null ? "?tenant_id=$tenantId" : ""}');
  static Future<ApiResult> workflowGetRule(String id) =>
      _adminGet('/admin/workflow/rules/$id');
  static Future<ApiResult> workflowCreateRule(Map body) =>
      _adminPost('/admin/workflow/rules', body);
  static Future<ApiResult> workflowUpdateRule(String id, Map body) =>
      _adminPatch('/admin/workflow/rules/$id', body);
  static Future<ApiResult> workflowDeleteRule(String id) =>
      _adminDelete('/admin/workflow/rules/$id');
  static Future<ApiResult> workflowRunRule(String id, Map payload, {bool dryRun = true}) =>
      _adminPost('/admin/workflow/rules/$id/run', {'payload': payload, 'dry_run': dryRun});
  static Future<ApiResult> workflowStats() => _adminGet('/admin/workflow/stats');
  static Future<ApiResult> workflowListTemplates({String? category}) =>
      _adminGet('/admin/workflow/templates${category != null ? "?category=$category" : ""}');
  static Future<ApiResult> workflowGetTemplate(String id) =>
      _adminGet('/admin/workflow/templates/$id');
  static Future<ApiResult> workflowInstallTemplate(
    String id, {
    Map<String, dynamic>? parameterValues,
    String? tenantId,
    bool enabled = true,
  }) =>
      _adminPost('/admin/workflow/templates/$id/install', {
        'parameter_values': parameterValues ?? const {},
        if (tenantId != null) 'tenant_id': tenantId,
        'enabled': enabled,
      });

  // ── Event Catalog (Wave 1A Phase F) — public, no admin secret needed ──
  static Future<ApiResult> eventsList({String? category}) =>
      _get('/api/v1/events/list${category != null ? "?category=$category" : ""}');
  static Future<ApiResult> eventsCategories() => _get('/api/v1/events/categories');

  // ── Proactive Suggestions (Wave 1G Phase EE) ──
  static Future<ApiResult> suggestionsList({String? tenantId, String? status}) {
    final qs = <String>[];
    if (tenantId != null) qs.add('tenant_id=${Uri.encodeQueryComponent(tenantId)}');
    if (status != null) qs.add('status=$status');
    final s = qs.isEmpty ? '' : '?${qs.join('&')}';
    return _get('/api/v1/suggestions$s');
  }
  static Future<ApiResult> suggestionsDismiss(String id) =>
      _post('/api/v1/suggestions/$id/dismiss', const {});
  static Future<ApiResult> suggestionsApply(String id) =>
      _post('/api/v1/suggestions/$id/apply', const {});
  static Future<ApiResult> suggestionsStats() =>
      _adminGet('/admin/suggestions/stats');

  // ── Custom Roles + Permissions (Wave 1F Phase Y) ──
  static Future<ApiResult> permissionsCatalog({String? category}) =>
      _get('/api/v1/permissions/catalog${category != null ? "?category=$category" : ""}');
  static Future<ApiResult> permissionsCategories() =>
      _get('/api/v1/permissions/categories');
  static Future<ApiResult> rolesList(String tenantId) =>
      _adminGet('/admin/roles?tenant_id=${Uri.encodeQueryComponent(tenantId)}');
  static Future<ApiResult> rolesCreate(Map body) => _adminPost('/admin/roles', body);
  static Future<ApiResult> rolesUpdate(String id, Map body) => _adminPatch('/admin/roles/$id', body);
  static Future<ApiResult> rolesDelete(String id) => _adminDelete('/admin/roles/$id');
  static Future<ApiResult> rolesAssign(String id, String userId) =>
      _adminPost('/admin/roles/$id/assign', {'user_id': userId});
  static Future<ApiResult> rolesRevoke(String id, String userId) =>
      _adminPost('/admin/roles/$id/revoke', {'user_id': userId});
  static Future<ApiResult> rolesEffective(String userId, String tenantId) =>
      _adminGet('/admin/roles/effective?user_id=$userId&tenant_id=$tenantId');

  // ── Recent Events (Wave 1A Phase F admin debug) ──
  static Future<ApiResult> eventsRecent({int limit = 50}) =>
      _adminGet('/admin/events/recent?limit=$limit');

  // ── Approvals Admin Console (Wave 1J Phase MM) ──
  static Future<ApiResult> approvalsAdminList({String? tenantId, String? userId, String? state}) {
    final qs = <String>[];
    if (tenantId != null) qs.add('tenant_id=${Uri.encodeQueryComponent(tenantId)}');
    if (userId != null) qs.add('user_id=${Uri.encodeQueryComponent(userId)}');
    if (state != null) qs.add('state=$state');
    final s = qs.isEmpty ? '' : '?${qs.join('&')}';
    return _adminGet('/admin/approvals$s');
  }
  static Future<ApiResult> approvalsAdminCreate(Map body) => _adminPost('/admin/approvals', body);
  static Future<ApiResult> approvalsAdminCancel(String id, {String? reason}) =>
      _adminDelete('/admin/approvals/$id${reason != null ? "?reason=${Uri.encodeQueryComponent(reason)}" : ""}');
  static Future<ApiResult> approvalsAdminStats() => _adminGet('/admin/approvals/stats');

  // ── Anomaly Live Monitor (Wave 1J Phase NN) ──
  static Future<ApiResult> anomalyBuffer({String? tenantId}) =>
      _adminGet('/admin/anomaly/buffer${tenantId != null ? "?tenant_id=${Uri.encodeQueryComponent(tenantId)}" : ""}');
  static Future<ApiResult> anomalyScan(String tenantId, {bool emitEvents = true}) =>
      _adminPost('/admin/anomaly/scan?tenant_id=${Uri.encodeQueryComponent(tenantId)}&emit_events=$emitEvents');
  static Future<ApiResult> anomalyScanAll({bool emitEvents = true}) =>
      _adminPost('/admin/anomaly/scan-all?emit_events=$emitEvents');
  static Future<ApiResult> anomalyClearBuffer({String? tenantId}) =>
      _adminPost('/admin/anomaly/clear-buffer${tenantId != null ? "?tenant_id=${Uri.encodeQueryComponent(tenantId)}" : ""}');

  // ── Email Inbox Status (Wave 1J Phase OO) ──
  static Future<ApiResult> emailInboxStatus() => _adminGet('/admin/email-inbox/status');
  static Future<ApiResult> emailInboxPoll({int? maxMessages}) =>
      _adminPost('/admin/email-inbox/poll${maxMessages != null ? "?max_messages=$maxMessages" : ""}');

  // ── Industry Packs (Wave 1K Phase PP) ──
  static Future<ApiResult> industryPacksList() => _get('/api/v1/industry-packs');
  static Future<ApiResult> industryPackDetail(String id) =>
      _get('/api/v1/industry-packs/$id');
  static Future<ApiResult> industryPackApplied(String tenantId) =>
      _get('/api/v1/industry-packs/applied?tenant_id=${Uri.encodeQueryComponent(tenantId)}');
  static Future<ApiResult> industryPackApply(String packId, String tenantId,
          {String? appliedBy, String? notes}) =>
      _adminPost(
        '/admin/industry-packs/$packId/apply?tenant_id=${Uri.encodeQueryComponent(tenantId)}',
        {
          if (appliedBy != null) 'applied_by': appliedBy,
          if (notes != null) 'notes': notes,
        },
      );
  static Future<ApiResult> industryPackRemove(String tenantId) =>
      _adminDelete('/admin/industry-packs/applied/$tenantId');
  static Future<ApiResult> industryPackAssignments() =>
      _adminGet('/admin/industry-packs/assignments');
  static Future<ApiResult> industryPackStats() => _adminGet('/admin/industry-packs/stats');
  static Future<ApiResult> industryPackTemplateMap() =>
      _get('/api/v1/industry-packs/template-map');
  static Future<ApiResult> industryPackProvision(String packId, String tenantId) =>
      _adminPost(
        '/admin/industry-packs/$packId/provision?tenant_id=${Uri.encodeQueryComponent(tenantId)}',
      );

  // ── Tenant Directory + Onboarding (Wave 1N Phase TT) ──
  static Future<ApiResult> tenantsList({String? status}) =>
      _get('/api/v1/tenants${status != null ? "?status=$status" : ""}');
  static Future<ApiResult> tenantGet(String tenantId) =>
      _get('/api/v1/tenants/$tenantId');
  static Future<ApiResult> tenantsStats() => _adminGet('/admin/tenants/stats');
  static Future<ApiResult> tenantRegister(Map body) =>
      _adminPost('/admin/tenants', body);
  static Future<ApiResult> tenantUpdate(String tenantId, Map body) =>
      _adminPatch('/admin/tenants/$tenantId', body);
  static Future<ApiResult> tenantDelete(String tenantId) =>
      _adminDelete('/admin/tenants/$tenantId');
  static Future<ApiResult> tenantDeactivate(String tenantId, {String? reason}) =>
      _adminPost(
        '/admin/tenants/$tenantId/deactivate${reason != null ? "?reason=${Uri.encodeQueryComponent(reason)}" : ""}',
      );
  static Future<ApiResult> tenantActivate(String tenantId) =>
      _adminPost('/admin/tenants/$tenantId/activate');
  static Future<ApiResult> tenantOnboard(Map body) =>
      _adminPost('/admin/tenants/onboard', body);

  // ── Workflow Run History (Wave 1O Phase VV) ──
  static Future<ApiResult> workflowRunsList({
    String? ruleId,
    String? tenantId,
    String? eventName,
    String? status,
    int limit = 100,
    int offset = 0,
  }) {
    final qs = <String>[
      'limit=$limit',
      'offset=$offset',
    ];
    if (ruleId != null) qs.add('rule_id=${Uri.encodeQueryComponent(ruleId)}');
    if (tenantId != null) qs.add('tenant_id=${Uri.encodeQueryComponent(tenantId)}');
    if (eventName != null) qs.add('event_name=${Uri.encodeQueryComponent(eventName)}');
    if (status != null) qs.add('status=$status');
    return _adminGet('/admin/workflow/runs?${qs.join('&')}');
  }
  static Future<ApiResult> workflowRunGet(String runId) =>
      _adminGet('/admin/workflow/runs/$runId');
  static Future<ApiResult> workflowRunsStats() =>
      _adminGet('/admin/workflow/runs/stats');
  static Future<ApiResult> workflowRunsClear({String? ruleId}) =>
      _adminDelete('/admin/workflow/runs${ruleId != null ? "?rule_id=${Uri.encodeQueryComponent(ruleId)}" : ""}');

  // ── Activity Feed (Wave 1P Phase WW) ──
  static Future<ApiResult> activityList({
    required String userId,
    String? tenantId,
    bool onlyUnread = false,
    int limit = 50,
    int offset = 0,
  }) {
    final qs = <String>[
      'user_id=${Uri.encodeQueryComponent(userId)}',
      'limit=$limit',
      'offset=$offset',
    ];
    if (tenantId != null) qs.add('tenant_id=${Uri.encodeQueryComponent(tenantId)}');
    if (onlyUnread) qs.add('only_unread=true');
    return _get('/api/v1/activity?${qs.join('&')}');
  }
  static Future<ApiResult> activityMarkRead({
    required String userId,
    String? tenantId,
  }) {
    final qs = <String>['user_id=${Uri.encodeQueryComponent(userId)}'];
    if (tenantId != null) qs.add('tenant_id=${Uri.encodeQueryComponent(tenantId)}');
    return _post('/api/v1/activity/mark-read?${qs.join('&')}', const {});
  }
  static Future<ApiResult> activityStats() => _adminGet('/admin/activity/stats');

  // ── Webhook Subscriptions (Wave 1E Phase T) ──
  static Future<ApiResult> webhooksList({String? tenantId, bool? enabled}) {
    final qs = <String>[];
    if (tenantId != null) qs.add('tenant_id=$tenantId');
    if (enabled != null) qs.add('enabled=$enabled');
    final s = qs.isEmpty ? '' : '?${qs.join('&')}';
    return _adminGet('/admin/webhooks$s');
  }
  static Future<ApiResult> webhooksCreate(Map body) => _adminPost('/admin/webhooks', body);
  static Future<ApiResult> webhooksUpdate(String id, Map body) => _adminPatch('/admin/webhooks/$id', body);
  static Future<ApiResult> webhooksDelete(String id) => _adminDelete('/admin/webhooks/$id');
  static Future<ApiResult> webhooksReset(String id) => _adminPost('/admin/webhooks/$id/reset');
  static Future<ApiResult> webhooksTest(String id, {String event = 'webhook.test', Map? payload}) =>
      _adminPost('/admin/webhooks/$id/test', {'event': event, 'payload': payload ?? const {}});
  static Future<ApiResult> webhooksStats() => _adminGet('/admin/webhooks/stats');

  // ── API Keys (Wave 1F Phase X) ──
  static Future<ApiResult> apiKeysList({String? tenantId, bool includeRevoked = false}) {
    final qs = <String>['include_revoked=$includeRevoked'];
    if (tenantId != null) qs.add('tenant_id=$tenantId');
    return _adminGet('/admin/api-keys?${qs.join('&')}');
  }
  static Future<ApiResult> apiKeysCreate(Map body) => _adminPost('/admin/api-keys', body);
  static Future<ApiResult> apiKeysUpdate(String id, Map body) => _adminPatch('/admin/api-keys/$id', body);
  static Future<ApiResult> apiKeysRevoke(String id, {String? reason}) =>
      _adminPost('/admin/api-keys/$id/revoke', {'reason': reason});
  static Future<ApiResult> apiKeysStats() => _adminGet('/admin/api-keys/stats');

  // ── Comments (Wave 1E Phase U) ──
  static Future<ApiResult> commentsList({
    required String objectType,
    required String objectId,
    String? tenantId,
    bool includeDeleted = false,
  }) {
    final qs = <String>[
      'object_type=${Uri.encodeQueryComponent(objectType)}',
      'object_id=${Uri.encodeQueryComponent(objectId)}',
      'include_deleted=$includeDeleted',
    ];
    if (tenantId != null) qs.add('tenant_id=$tenantId');
    return _get('/api/v1/comments?${qs.join('&')}');
  }
  static Future<ApiResult> commentsAdd({
    required String objectType,
    required String objectId,
    required String authorUserId,
    required String body,
    String? parentId,
    String? tenantId,
    List<String>? extraMentions,
  }) =>
      _post('/api/v1/comments', {
        'object_type': objectType,
        'object_id': objectId,
        'author_user_id': authorUserId,
        'body': body,
        if (parentId != null) 'parent_id': parentId,
        if (tenantId != null) 'tenant_id': tenantId,
        if (extraMentions != null) 'extra_mentions': extraMentions,
      });
  static Future<ApiResult> commentsEdit(String id, String byUserId, String body) =>
      _patch('/api/v1/comments/$id', {'by_user_id': byUserId, 'body': body});
  static Future<ApiResult> commentsDelete(String id, String byUserId) async {
    // Delete with body — re-implement here since _delete doesn't support body.
    try {
      final res = await _httpClient.delete(
        Uri.parse('$_base/api/v1/comments/$id'),
        headers: _h,
        body: jsonEncode({'by_user_id': byUserId}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) return ApiResult.ok(jsonDecode(res.body));
      return ApiResult.error(_parseErr(res.body, res.statusCode));
    } catch (e) {
      return ApiResult.error('خطأ: $e');
    }
  }
  static Future<ApiResult> commentsReact(String id, String userId, String emoji) =>
      _post('/api/v1/comments/$id/react', {'user_id': userId, 'emoji': emoji});

  // ── Module Manager (Wave 1E Phase V) ──
  static Future<ApiResult> modulesCatalog({String? category}) =>
      _get('/api/v1/modules/catalog${category != null ? "?category=$category" : ""}');
  static Future<ApiResult> modulesCategories() => _get('/api/v1/modules/categories');
  static Future<ApiResult> modulesEffective(String tenantId) =>
      _get('/api/v1/modules/effective?tenant_id=$tenantId');
  static Future<ApiResult> modulesSet(String tenantId, String moduleId, bool enabled) =>
      _adminPost('/admin/modules/set', {
        'tenant_id': tenantId,
        'module_id': moduleId,
        'enabled': enabled,
      });
  static Future<ApiResult> modulesReset(String tenantId) =>
      _adminPost('/admin/modules/reset', {'tenant_id': tenantId});
  static Future<ApiResult> modulesStats() => _adminGet('/admin/modules/stats');

  // ── Approval Chains (Wave 1B Phase J) ──
  // /api/v1/approvals/inbox?user_id=...
  // /api/v1/approvals/{id}/approve  {user_id, comment}
  // /api/v1/approvals/{id}/reject   {user_id, comment}
  static Future<ApiResult> approvalsInbox(String userId, {String? tenantId}) {
    final qs = <String>['user_id=${Uri.encodeQueryComponent(userId)}'];
    if (tenantId != null) qs.add('tenant_id=${Uri.encodeQueryComponent(tenantId)}');
    return _get('/api/v1/approvals/inbox?${qs.join('&')}');
  }
  static Future<ApiResult> approvalsGet(String approvalId) =>
      _get('/api/v1/approvals/$approvalId');
  static Future<ApiResult> approvalsApprove(String approvalId, String userId, {String? comment}) =>
      _post('/api/v1/approvals/$approvalId/approve', {
        'user_id': userId,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });
  static Future<ApiResult> approvalsReject(String approvalId, String userId, {String? comment}) =>
      _post('/api/v1/approvals/$approvalId/reject', {
        'user_id': userId,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });

  // ── Cash-Flow Forecast (Wave 1B Phase I) ──
  static Future<ApiResult> forecastCashflow({
    required String tenantId,
    String? entityId,
    int weeks = 4,
    int historyWeeks = 12,
  }) {
    final qs = <String>[
      'tenant_id=${Uri.encodeQueryComponent(tenantId)}',
      'weeks=$weeks',
      'history_weeks=$historyWeeks',
    ];
    if (entityId != null) qs.add('entity_id=${Uri.encodeQueryComponent(entityId)}');
    return _get('/api/v1/forecast/cashflow?${qs.join('&')}');
  }

  // ── Phase 1: Client Readiness + Documents + Approval Gate ──
  static Future<ApiResult> getClientReadiness(String clientId) => _get('/clients/$clientId/readiness');
  static Future<ApiResult> getClientDocuments(String clientId) => _get('/clients/$clientId/documents');
  static Future<ApiResult> updateDocumentStatus(String clientId, String docType, String status, {String? reason}) => _patch('/clients/$clientId/documents/$docType/status', {'status': status, if (reason != null) 'reason': reason});
  static Future<ApiResult> checkApprovalGates(String uploadId) => _get('/coa/uploads/$uploadId/approval-check');

  static Future<ApiResult> adminStats() => _get('/admin/stats');

  // ── Admin ──
  static Future<ApiResult> adminUsers() => _get('/admin/users');
  static Future<ApiResult> adminKnowledgeFeedback() => _get('/knowledge-feedback/review-queue');
  static Future<ApiResult> adminReviewFeedback(String id, Map body) => _post('/knowledge-feedback/$id/review', body);
  static Future<ApiResult> adminProviders() => _get('/service-providers/verification-queue');
  static Future<ApiResult> adminProviderAction(String id, String action) => _post('/service-providers/$id/$action', {});
  static Future<ApiResult> adminAuditEvents({int limit = 100}) => _get('/audit/events?limit=$limit');

  // ── Marketplace ──
  static Future<ApiResult> listMarketplaceProviders() => _get('/marketplace/providers');
  static Future<ApiResult> listMyRequests() => _get('/marketplace/my-requests');
  static Future<ApiResult> createServiceRequest(Map body) => _post('/marketplace/requests', body);

  // ── Service Providers ──
  static Future<ApiResult> getProviderMe() => _get('/service-providers/me');
  static Future<ApiResult> registerProvider(Map body) => _post('/service-providers/register', body);

  // ── Legal Policies ──
  static Future<ApiResult> getLegalPolicies() => _get('/legal/policies');

  // ── Auth Extended ──
  static Future<ApiResult> logout() => _post('/auth/logout', {});
  static Future<ApiResult> resetPassword({required String token, required String newPassword}) => _post('/auth/reset-password', {'token': token, 'new_password': newPassword});

  // ── Users ──
  static Future<ApiResult> updateUser(Map body) => _put('/users/me', body);

  // ── Notifications Extended ──
  static Future<ApiResult> markNotificationsReadAll() => _post('/notifications/read-all', {});
  static Future<ApiResult> getNotificationCount() => _get('/notifications/count');
  static Future<ApiResult> getNotificationsPaged({int pageSize = 50}) => _get('/notifications?page_size=$pageSize');
  static Future<ApiResult> markNotificationRead(String notificationId) => _post('/notifications/mark-read', {'notification_id': notificationId});
  static Future<ApiResult> markNotificationsRead() => _post('/notifications/mark-read', {});
  static Future<ApiResult> getNotificationPreferences() => _get('/notifications/preferences');
  static Future<ApiResult> updateNotificationPreferences({required String notificationType, required bool inApp, required bool email, required bool sms}) => _put('/notifications/preferences', {'notification_type': notificationType, 'in_app': inApp, 'email': email, 'sms': sms});

  // ── Results & Tasks ──
  static Future<ApiResult> getResultDetails(String analysisId) => _get('/results/$analysisId/details');
  static Future<ApiResult> getTaskType(String code) => _get('/task-types/$code');
  static Future<ApiResult> getTaskSubmission(String id) => _get('/task-submissions/$id');
  static Future<ApiResult> createTaskSubmission(Map body) => _post('/task-submissions', body);

  // ── Sessions ──
  static Future<ApiResult> getSessions() => _get('/account/sessions');
  static Future<ApiResult> logoutAllSessions() => _post('/account/sessions/logout-all', {});
  static Future<ApiResult> logoutSession(String id) => _post('/account/sessions/$id/logout', {});

  // ── Knowledge Feedback (non-COA) ──
  static Future<ApiResult> submitKnowledgeFeedback(Map body) => _post('/knowledge-feedback', body);

  // ── Compliance (Journal Entry Sequence + Audit Trail) ──
  static Future<ApiResult> jeReserveNext({required String clientId, required String fiscalYear, String prefix = 'JE'}) =>
      _post('/compliance/je/next', {'client_id': clientId, 'fiscal_year': fiscalYear, 'prefix': prefix});
  static Future<ApiResult> jePeek({required String clientId, required String fiscalYear}) =>
      _get('/compliance/je/peek?client_id=$clientId&fiscal_year=$fiscalYear');
  static Future<ApiResult> auditLog({required String action, String? entityType, String? entityId, Map? before, Map? after, Map? metadata}) =>
      _post('/compliance/audit/log', {
        'action': action,
        if (entityType != null) 'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
        if (before != null) 'before': before,
        if (after != null) 'after': after,
        if (metadata != null) 'metadata': metadata,
      });
  static Future<ApiResult> auditVerify({int limit = 1000}) => _get('/compliance/audit/verify?limit=$limit');

  // ── ZATCA (Fatoora) e-invoice ──
  static Future<ApiResult> zatcaValidateVat(String vatNumber) =>
      _post('/zatca/validate-vat', {'vat_number': vatNumber});
  static Future<ApiResult> zatcaBuildInvoice(Map body) => _post('/zatca/invoice/build', body);
  // ZATCA Arabic rejection translator (Wave 2 PR#4 / PR#5).
  static Future<ApiResult> explainZatcaCode(String code) =>
      _get('/zatca/errors/explain?code=${Uri.encodeQueryComponent(code)}');
  static Future<ApiResult> translateZatcaRejection(Map payload) =>
      _post('/zatca/errors/translate', {'payload': payload});

  // ── Anomaly detector (Wave 3 PR#1). ──
  // Caller supplies transactions; server runs 5 detectors and returns findings.
  static Future<ApiResult> scanAnomalies(List<Map> transactions, {Map<String, dynamic>? options}) =>
      _post('/anomalies/scan', {'transactions': transactions, ...?options});

  // ── ZATCA offline retry queue (Wave 5). ──
  static Future<ApiResult> zatcaQueueStats({String? tenantId}) => _get(
      '/zatca/queue/stats${tenantId != null ? "?tenant_id=${Uri.encodeQueryComponent(tenantId)}" : ""}');
  static Future<ApiResult> zatcaQueueList({String? status, String? tenantId, int limit = 100}) {
    final qp = <String, String>{'limit': '$limit'};
    if (status != null) qp['status'] = status;
    if (tenantId != null) qp['tenant_id'] = tenantId;
    final qs = qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return _get('/zatca/queue?$qs');
  }
  static Future<ApiResult> zatcaQueueDetail(String id) => _get('/zatca/queue/$id');
  static Future<ApiResult> zatcaQueueEnqueue(Map body) => _post('/zatca/queue/enqueue', body);
  static Future<ApiResult> zatcaQueueProcess({bool dryRun = true, int limit = 50}) =>
      _post('/zatca/queue/process', {'dry_run': dryRun, 'limit': limit});

  // ── AI Guardrails (Wave 7 + 8). ──
  static Future<ApiResult> aiGuardrailsStats({String? tenantId}) => _get(
      '/ai/guardrails/stats${tenantId != null ? "?tenant_id=${Uri.encodeQueryComponent(tenantId)}" : ""}');
  static Future<ApiResult> aiGuardrailsList({String? status, String? source, String? tenantId, int limit = 100}) {
    final qp = <String, String>{'limit': '$limit'};
    if (status != null) qp['status'] = status;
    if (source != null) qp['source'] = source;
    if (tenantId != null) qp['tenant_id'] = tenantId;
    final qs = qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return _get('/ai/guardrails?$qs');
  }
  static Future<ApiResult> aiGuardrailsDetail(String id) => _get('/ai/guardrails/$id');
  static Future<ApiResult> aiGuardrailsEvaluate(Map body) => _post('/ai/guardrails/evaluate', body);
  static Future<ApiResult> aiGuardrailsApprove(String id) =>
      _post('/ai/guardrails/$id/approve', const {});
  static Future<ApiResult> aiGuardrailsReject(String id, {String? reason}) =>
      _post('/ai/guardrails/$id/reject', {if (reason != null) 'reason': reason});

  // ── ZATCA CSID lifecycle (Wave 11 + 12). ──
  // Note: no method ever returns the decrypted cert / key — the backend
  // won't expose it over HTTP. These client methods handle metadata +
  // lifecycle transitions only.
  static Future<ApiResult> zatcaCsidStats({String? tenantId}) => _get(
      '/zatca/csid/stats${tenantId != null ? "?tenant_id=${Uri.encodeQueryComponent(tenantId)}" : ""}');
  static Future<ApiResult> zatcaCsidList({
    String? tenantId,
    String? environment,
    String? status,
    int limit = 100,
  }) {
    final qp = <String, String>{'limit': '$limit'};
    if (tenantId != null) qp['tenant_id'] = tenantId;
    if (environment != null) qp['environment'] = environment;
    if (status != null) qp['status'] = status;
    final qs = qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return _get('/zatca/csid?$qs');
  }
  static Future<ApiResult> zatcaCsidExpiringSoon({int days = 30, String? tenantId}) {
    final qp = <String, String>{'days': '$days'};
    if (tenantId != null) qp['tenant_id'] = tenantId;
    final qs = qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return _get('/zatca/csid/expiring-soon?$qs');
  }
  static Future<ApiResult> zatcaCsidDetail(String id) => _get('/zatca/csid/$id');
  static Future<ApiResult> zatcaCsidRevoke(String id, {String? reason}) =>
      _post('/zatca/csid/$id/revoke', {if (reason != null) 'reason': reason});
  static Future<ApiResult> zatcaCsidSweepExpired() =>
      _post('/zatca/csid/sweep-expired', const {});

  // ── Bank Feeds (Wave 13 + 14). ──
  // No method returns decrypted tokens — the backend never exposes
  // them over HTTP. These are metadata + lifecycle operations only.
  static Future<ApiResult> bankFeedsStats({String? tenantId}) => _get(
      '/bank-feeds/stats${tenantId != null ? "?tenant_id=${Uri.encodeQueryComponent(tenantId)}" : ""}');
  static Future<ApiResult> bankFeedsProviders() => _get('/bank-feeds/providers');
  static Future<ApiResult> bankFeedsConnections({
    String? tenantId,
    String? provider,
    String? status,
    int limit = 100,
  }) {
    final qp = <String, String>{'limit': '$limit'};
    if (tenantId != null) qp['tenant_id'] = tenantId;
    if (provider != null) qp['provider'] = provider;
    if (status != null) qp['status'] = status;
    final qs = qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return _get('/bank-feeds/connections?$qs');
  }
  static Future<ApiResult> bankFeedsConnectionDetail(String id) =>
      _get('/bank-feeds/connections/$id');
  static Future<ApiResult> bankFeedsConnect(Map body) =>
      _post('/bank-feeds/connections', body);
  static Future<ApiResult> bankFeedsSync(String id) =>
      _post('/bank-feeds/connections/$id/sync', const {});
  static Future<ApiResult> bankFeedsDisconnect(String id, {String? reason}) =>
      _post('/bank-feeds/connections/$id/disconnect', {if (reason != null) 'reason': reason});
  static Future<ApiResult> bankFeedsTransactions({
    String? tenantId,
    String? connectionId,
    bool unreconciledOnly = false,
    int limit = 200,
  }) {
    final qp = <String, String>{
      'limit': '$limit',
      'unreconciled_only': '$unreconciledOnly',
    };
    if (tenantId != null) qp['tenant_id'] = tenantId;
    if (connectionId != null) qp['connection_id'] = connectionId;
    final qs = qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return _get('/bank-feeds/transactions?$qs');
  }
  static Future<ApiResult> bankFeedsReconcile(String txnId, {
    required String entityType,
    required String entityId,
  }) =>
      _post(
        '/bank-feeds/transactions/$txnId/reconcile',
        {'entity_type': entityType, 'entity_id': entityId},
      );

  // ── AI Bank Reconciliation (Wave 15 backend, Wave 16 UI). ──
  // Scores a bank transaction against candidate entries and optionally
  // routes the top proposal through the Wave 7 AI guardrail. The
  // guardrail persists every decision as an AiSuggestion row; when a
  // row lands in needs_approval, the user approves/rejects it from the
  // AI Guardrails screen (compliance-gov-ai-oversight).
  static Future<ApiResult> bankRecPropose(Map body) =>
      _post('/bank-rec/propose', body);
  static Future<ApiResult> bankRecAutoMatch(Map body) =>
      _post('/bank-rec/auto-match', body);
  // Wave 17 gap fix: dedicated approval endpoint that ALSO calls
  // mark_reconciled. The generic /ai/guardrails/{id}/approve only
  // flips the suggestion status — use this one for bank-rec rows.
  static Future<ApiResult> bankRecApprove(String rowId) =>
      _post('/bank-rec/approve/$rowId', const {});

  // ── Tax: Zakat + VAT calculators ──
  static Future<ApiResult> taxZakatCompute(Map body) => _post('/tax/zakat/compute', body);
  static Future<ApiResult> taxVatReturn(Map body) => _post('/tax/vat/return', body);

  // ── Financial ratios (18 ratios across 5 categories) ──
  static Future<ApiResult> ratiosCompute(Map body) => _post('/ratios/compute', body);

  // ── Depreciation calculator (SL / DDB / SYD) ──
  static Future<ApiResult> depreciationCompute(Map body) => _post('/depreciation/compute', body);

  // ── Cash Flow statement (indirect method) ──
  static Future<ApiResult> cashflowCompute(Map body) => _post('/cashflow/compute', body);

  // ── Loan Amortization schedule ──
  static Future<ApiResult> amortizationCompute(Map body) => _post('/amortization/compute', body);

  // ── Payroll (GOSI + WPS) + Break-even analysis ──
  static Future<ApiResult> payrollCompute(Map body) => _post('/payroll/compute', body);
  static Future<ApiResult> breakevenCompute(Map body) => _post('/breakeven/compute', body);

  // ── Investment appraisal (NPV / IRR / Payback) + Budget variance ──
  static Future<ApiResult> investmentAnalyze(Map body) => _post('/investment/analyze', body);
  static Future<ApiResult> budgetVariance(Map body) => _post('/budget/variance', body);

  // ── Accounting ops: Bank Rec + Inventory + Aging ──
  static Future<ApiResult> bankRecCompute(Map body) => _post('/bank-rec/compute', body);
  static Future<ApiResult> inventoryValuate(Map body) => _post('/inventory/valuate', body);
  static Future<ApiResult> agingReport(Map body) => _post('/aging/report', body);

  // ── Analytics: Working Capital + Health Score ──
  static Future<ApiResult> workingCapitalAnalyze(Map body) => _post('/working-capital/analyze', body);
  static Future<ApiResult> healthScoreCompute(Map body) => _post('/health-score/compute', body);

  // ── OCR: Invoice extraction ──
  static Future<ApiResult> ocrExtractInvoice(String text) =>
      _post('/ocr/invoice/extract', {'text': text});

  // ── Valuation: DSCR + WACC + DCF ──
  static Future<ApiResult> dscrAnalyze(Map body) => _post('/dscr/analyze', body);
  static Future<ApiResult> waccCompute(Map body) => _post('/wacc/compute', body);
  static Future<ApiResult> dcfAnalyze(Map body) => _post('/dcf/analyze', body);

  // ── Journal Entry Builder ──
  static Future<ApiResult> jeBuild(Map body) => _post('/je/build', body);
  static Future<ApiResult> jeTemplates() => _get('/je/templates');
  static Future<ApiResult> jeGetTemplate(String code) => _get('/je/templates/$code');

  // ── Multi-currency FX ──
  static Future<ApiResult> fxConvert(Map body) => _post('/fx/convert', body);
  static Future<ApiResult> fxBatch(Map body) => _post('/fx/batch', body);
  static Future<ApiResult> fxRevalue(Map body) => _post('/fx/revalue', body);
  static Future<ApiResult> fxCurrencies() => _get('/fx/currencies');

  // ── Cost Accounting / Variance ──
  static Future<ApiResult> costVarianceMaterial(Map body) => _post('/cost/variance/material', body);
  static Future<ApiResult> costVarianceLabour(Map body) => _post('/cost/variance/labour', body);
  static Future<ApiResult> costVarianceOverhead(Map body) => _post('/cost/variance/overhead', body);
  static Future<ApiResult> costVarianceComprehensive(Map body) => _post('/cost/variance/comprehensive', body);

  // ── Financial Statements (TB / IS / BS / Close) ──
  static Future<ApiResult> fsTrialBalance(Map body) => _post('/fs/trial-balance', body);
  static Future<ApiResult> fsIncomeStatement(Map body) => _post('/fs/income-statement', body);
  static Future<ApiResult> fsBalanceSheet(Map body) => _post('/fs/balance-sheet', body);
  static Future<ApiResult> fsClosingEntries(Map body) => _post('/fs/closing-entries', body);
  static Future<ApiResult> fsClassifications() => _get('/fs/classifications');

  // ── Full Cash Flow Statement (IAS 7) ──
  static Future<ApiResult> cfsBuild(Map body) => _post('/cfs/build', body);
  static Future<ApiResult> cfsClassifications() => _get('/cfs/classifications');

  // ── Withholding Tax (KSA) ──
  static Future<ApiResult> whtCompute(Map body) => _post('/wht/compute', body);
  static Future<ApiResult> whtBatch(Map body) => _post('/wht/batch', body);
  static Future<ApiResult> whtCategories() => _get('/wht/categories');
  static Future<ApiResult> whtRates() => _get('/wht/rates');

  // ── Consolidation (IFRS 10) ──
  static Future<ApiResult> consolidate(Map body) => _post('/consol/build', body);

  // ── Deferred Tax (IAS 12) ──
  static Future<ApiResult> deferredTaxCompute(Map body) => _post('/dt/compute', body);
  static Future<ApiResult> deferredTaxCategories() => _get('/dt/categories');

  // ── Lease Accounting (IFRS 16) ──
  static Future<ApiResult> leaseBuild(Map body) => _post('/lease/build', body);

  // ── IFRS 15 Revenue Recognition ──
  static Future<ApiResult> revenueRecognise(Map body) => _post('/revenue/recognise', body);

  // ── IAS 19 End-of-Service Benefits ──
  static Future<ApiResult> eosbCompute(Map body) => _post('/eosb/compute', body);
  static Future<ApiResult> eosbReasons() => _get('/eosb/reasons');

  // ── IAS 36 Impairment ──
  static Future<ApiResult> impairmentTest(Map body) => _post('/impairment/test', body);

  // ── IFRS 9 ECL ──
  static Future<ApiResult> eclCompute(Map body) => _post('/ecl/compute', body);
  static Future<ApiResult> eclDefaults() => _get('/ecl/defaults');

  // ── IAS 37 Provisions ──
  static Future<ApiResult> provisionsClassify(Map body) => _post('/provisions/classify', body);
  static Future<ApiResult> provisionsLevels() => _get('/provisions/levels');

  // ── Fixed Assets Register ──
  static Future<ApiResult> fixedAssetBuild(Map body) => _post('/fa/build', body);
  static Future<ApiResult> fixedAssetMethods() => _get('/fa/methods');

  // ── Transfer Pricing ──
  static Future<ApiResult> tpAnalyse(Map body) => _post('/tp/analyse', body);
  static Future<ApiResult> tpMethods() => _get('/tp/methods');

  // ── Extras: IFRS 2/40/41, RETT, P2, VAT-G, Job ──
  static Future<ApiResult> sbpCompute(Map body) => _post('/sbp/compute', body);
  static Future<ApiResult> investmentPropertyCompute(Map body) => _post('/investment-property/compute', body);
  static Future<ApiResult> agricultureCompute(Map body) => _post('/agriculture/compute', body);
  static Future<ApiResult> rettCompute(Map body) => _post('/rett/compute', body);
  static Future<ApiResult> pillarTwoCompute(Map body) => _post('/pillar-two/compute', body);
  static Future<ApiResult> vatGroupCompute(Map body) => _post('/vat-group/compute', body);
  static Future<ApiResult> jobAnalyse(Map body) => _post('/job/analyse', body);
  static Future<ApiResult> extrasEnums() => _get('/extras/enums');

  // ── Quick Analysis (MultipartRequest) ──
  static Future<ApiResult> analyzeQuick({required List<int> bytes, required String fileName, String industry = 'retail'}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/analyze?industry=$industry'));
      request.headers['Authorization'] = 'Bearer ${_token ?? S.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      final res = await request.send();
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) return ApiResult.ok(jsonDecode(body));
      return ApiResult.error(_parseErr(body, res.statusCode));
    } catch (e) { return ApiResult.error('خطأ: $e'); }
  }

  static Future<ApiResult> analyzeReport({required List<int> bytes, required String fileName, String industry = 'retail'}) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_base/analyze/report?industry=$industry'));
      request.headers['Authorization'] = 'Bearer ${_token ?? S.token ?? ""}';
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
      final res = await request.send();
      final body = await res.stream.bytesToString();
      if (res.statusCode == 200) return ApiResult.ok(jsonDecode(body));
      return ApiResult.error(_parseErr(body, res.statusCode));
    } catch (e) { return ApiResult.error('خطأ: $e'); }
  }

  // ── DASH-1: Customizable Dashboard ──
  // All endpoints under /api/v1/dashboard/. The backend wraps responses
  // in {success, data} so .data on the ApiResult matches the rest of
  // the codebase.
  static Future<ApiResult> dashboardWidgets() => _get('/api/v1/dashboard/widgets');
  static Future<ApiResult> dashboardLayout() => _get('/api/v1/dashboard/layout');
  static Future<ApiResult> saveDashboardLayout(List<Map<String, dynamic>> blocks, {String name = 'default'}) =>
      _put('/api/v1/dashboard/layout', {'name': name, 'blocks': blocks});
  static Future<ApiResult> resetDashboardLayout() =>
      _post('/api/v1/dashboard/layout/reset', const {});
  static Future<ApiResult> dashboardBatch({
    String? entityId,
    String? asOfDate,
    required List<String> widgetCodes,
  }) => _post('/api/v1/dashboard/data/batch', {
        if (entityId != null) 'entity_id': entityId,
        if (asOfDate != null) 'as_of_date': asOfDate,
        'widgets': widgetCodes,
      });
  static Future<ApiResult> dashboardWidgetData(String widgetCode, {String? entityId, String? asOfDate}) {
    final qp = <String, String>{};
    if (entityId != null) qp['entity_id'] = entityId;
    if (asOfDate != null) qp['as_of_date'] = asOfDate;
    final qs = qp.isEmpty
        ? ''
        : '?${qp.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    return _get('/api/v1/dashboard/data/$widgetCode$qs');
  }

  /// Returns the URL clients should hit with EventSource. The actual
  /// SSE listener lives in `lib/widgets/dashboard/dashboard_stream.dart`
  /// because Dart's http package is one-shot — long-lived streams need
  /// the `package:web` EventSource (web build) or a custom http client
  /// (native).
  static String dashboardStreamUrl() => '$_base/api/v1/dashboard/stream';

  // Admin-only role-layout endpoints. Frontend gates UI on
  // `manage:dashboard_role` / `lock:dashboard` from token claims;
  // backend re-checks regardless.
  static Future<ApiResult> dashboardRoleLayouts() => _get('/api/v1/dashboard/role-layouts');
  static Future<ApiResult> dashboardSaveRoleLayout(String roleId, List<Map<String, dynamic>> blocks, {String name = 'default'}) =>
      _put('/api/v1/dashboard/role-layouts/$roleId', {'name': name, 'blocks': blocks});
  static Future<ApiResult> dashboardLockRoleLayout(String roleId, bool isLocked) =>
      _post('/api/v1/dashboard/role-layouts/$roleId/lock', {'is_locked': isLocked});

  // ── CoA-1: Chart of Accounts ──
  // 14 endpoints under /api/v1/coa. Same {success, data} envelope as
  // every other ApiResult-returning method here — UI layer unwraps
  // .data the same way it does for the dashboard.

  static Future<ApiResult> coaTree(String entityId, {bool includeInactive = false}) {
    final qp = 'entity_id=${Uri.encodeQueryComponent(entityId)}'
        '${includeInactive ? '&include_inactive=true' : ''}';
    return _get('/api/v1/coa/tree?$qp');
  }

  static Future<ApiResult> coaList(
    String entityId, {
    bool? isActive,
    String? accountClass,
    bool? isPostable,
    bool? isReconcilable,
    String? search,
    int limit = 1000,
    int offset = 0,
  }) {
    final params = <String, String>{
      'entity_id': entityId,
      'limit': '$limit',
      'offset': '$offset',
    };
    if (isActive != null) params['is_active'] = '$isActive';
    if (accountClass != null) params['account_class'] = accountClass;
    if (isPostable != null) params['is_postable'] = '$isPostable';
    if (isReconcilable != null) params['is_reconcilable'] = '$isReconcilable';
    if (search != null && search.isNotEmpty) params['search'] = search;
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _get('/api/v1/coa/list?$qs');
  }

  static Future<ApiResult> coaGet(String id) =>
      _get('/api/v1/coa/$id');
  static Future<ApiResult> coaCreate(Map<String, dynamic> data) =>
      _post('/api/v1/coa/', data);
  static Future<ApiResult> coaUpdate(String id, Map<String, dynamic> data) =>
      _patch('/api/v1/coa/$id', data);
  static Future<ApiResult> coaDelete(String id) =>
      _delete('/api/v1/coa/$id');
  static Future<ApiResult> coaDeactivate(String id, {String? reason}) =>
      _post('/api/v1/coa/$id/deactivate', {if (reason != null) 'reason': reason});
  static Future<ApiResult> coaReactivate(String id) =>
      _post('/api/v1/coa/$id/reactivate', const {});
  static Future<ApiResult> coaMerge({
    required String sourceId,
    required String targetId,
    String? reason,
  }) =>
      _post('/api/v1/coa/merge', {
        'source_id': sourceId,
        'target_id': targetId,
        if (reason != null) 'reason': reason,
      });
  static Future<ApiResult> coaTemplates() =>
      _get('/api/v1/coa/templates');
  static Future<ApiResult> coaImportTemplate(
    String code,
    String entityId, {
    bool overwrite = false,
  }) =>
      _post('/api/v1/coa/templates/$code/import', {
        'entity_id': entityId,
        'overwrite': overwrite,
      });
  static Future<ApiResult> coaChangelog(String id, {int limit = 50}) =>
      _get('/api/v1/coa/$id/changelog?limit=$limit');
  static Future<ApiResult> coaUsage(String id) =>
      _get('/api/v1/coa/$id/usage');

  /// CSV / JSON exports return raw text rather than the JSON envelope —
  /// callers should treat .data as a pre-formatted string.
  static Future<String?> coaExport(String entityId, {String fmt = 'json'}) async {
    try {
      final url = Uri.parse(
          '$_base/api/v1/coa/export?entity_id=${Uri.encodeQueryComponent(entityId)}&fmt=$fmt');
      final res = await _httpClient.get(url, headers: _h);
      if (res.statusCode == 200) return res.body;
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── INV-1: Invoicing ──
  // 21 endpoints under /api/v1/invoicing.

  // Credit notes
  static Future<ApiResult> createCreditNote(Map<String, dynamic> data) =>
      _post('/api/v1/invoicing/credit-notes', data);
  static Future<ApiResult> listCreditNotes({
    String? entityId,
    String? customerId,
    String? vendorId,
    String? status,
    String? cnType,
    String? fromDate,
    String? toDate,
    int limit = 100,
    int offset = 0,
  }) {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (entityId != null) params['entity_id'] = entityId;
    if (customerId != null) params['customer_id'] = customerId;
    if (vendorId != null) params['vendor_id'] = vendorId;
    if (status != null) params['status'] = status;
    if (cnType != null) params['cn_type'] = cnType;
    if (fromDate != null) params['from_date'] = fromDate;
    if (toDate != null) params['to_date'] = toDate;
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _get('/api/v1/invoicing/credit-notes?$qs');
  }
  static Future<ApiResult> getCreditNote(String id) =>
      _get('/api/v1/invoicing/credit-notes/$id');
  static Future<ApiResult> issueCreditNote(String id) =>
      _post('/api/v1/invoicing/credit-notes/$id/issue', const {});
  static Future<ApiResult> applyCreditNote(
    String id, {
    required String targetInvoiceId,
    double? amount,
    String? reason,
  }) =>
      _post('/api/v1/invoicing/credit-notes/$id/apply', {
        'target_invoice_id': targetInvoiceId,
        if (amount != null) 'amount': amount,
        if (reason != null) 'reason': reason,
      });
  static Future<ApiResult> cancelCreditNote(String id, {String? reason}) =>
      _post('/api/v1/invoicing/credit-notes/$id/cancel',
          {if (reason != null) 'reason': reason});

  // Recurring templates
  static Future<ApiResult> createRecurring(Map<String, dynamic> data) =>
      _post('/api/v1/invoicing/recurring', data);
  static Future<ApiResult> listRecurring({
    String? entityId,
    bool? isActive,
    String? invoiceType,
    int limit = 100,
    int offset = 0,
  }) {
    final params = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (entityId != null) params['entity_id'] = entityId;
    if (isActive != null) params['is_active'] = '$isActive';
    if (invoiceType != null) params['invoice_type'] = invoiceType;
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _get('/api/v1/invoicing/recurring?$qs');
  }
  static Future<ApiResult> updateRecurring(String id, Map<String, dynamic> data) =>
      _patch('/api/v1/invoicing/recurring/$id', data);
  static Future<ApiResult> runRecurringNow(String id) =>
      _post('/api/v1/invoicing/recurring/$id/run-now', const {});
  static Future<ApiResult> pauseRecurring(String id) =>
      _post('/api/v1/invoicing/recurring/$id/pause', const {});

  // Aged AR / AP
  static Future<ApiResult> agedAr(String entityId, {String? asOfDate}) {
    final qs = StringBuffer('entity_id=${Uri.encodeQueryComponent(entityId)}');
    if (asOfDate != null) qs.write('&as_of_date=$asOfDate');
    return _get('/api/v1/invoicing/aged-ar?$qs');
  }
  static Future<ApiResult> agedAp(String entityId, {String? asOfDate}) {
    final qs = StringBuffer('entity_id=${Uri.encodeQueryComponent(entityId)}');
    if (asOfDate != null) qs.write('&as_of_date=$asOfDate');
    return _get('/api/v1/invoicing/aged-ap?$qs');
  }

  // Bulk
  static Future<ApiResult> bulkIssueInvoices(List<String> invoiceIds) =>
      _post('/api/v1/invoicing/sales-invoices/bulk/issue',
          {'invoice_ids': invoiceIds});
  static Future<ApiResult> bulkEmailInvoices(List<String> invoiceIds) =>
      _post('/api/v1/invoicing/sales-invoices/bulk/email',
          {'invoice_ids': invoiceIds});

  // Attachments
  static Future<ApiResult> uploadInvoiceAttachment(
    String invoiceId, {
    required String filename,
    required String mimeType,
    required List<int> bytes,
    String invoiceType = 'sales',
  }) {
    final b64 = base64.encode(bytes);
    return _post('/api/v1/invoicing/invoices/$invoiceId/attachments', {
      'invoice_type': invoiceType,
      'filename': filename,
      'mime_type': mimeType,
      'content_b64': b64,
    });
  }
  static Future<ApiResult> listInvoiceAttachments(String invoiceId) =>
      _get('/api/v1/invoicing/invoices/$invoiceId/attachments');
  static Future<ApiResult> deleteInvoiceAttachment(String attachmentId) =>
      _delete('/api/v1/invoicing/attachments/$attachmentId');

  // Write-off
  static Future<ApiResult> writeOffInvoice(
    String invoiceId, {
    required String reason,
    String? writeOffAccountId,
  }) =>
      _post('/api/v1/invoicing/invoices/$invoiceId/write-off', {
        'reason': reason,
        if (writeOffAccountId != null) 'write_off_account_id': writeOffAccountId,
      });

  // PDF — returns raw bytes; callers stream to download.
  static Future<List<int>?> downloadInvoicePdf(
    String invoiceId, {
    bool isPurchase = false,
  }) async {
    try {
      final path = isPurchase
          ? '/api/v1/invoicing/purchase-invoices/$invoiceId/pdf'
          : '/api/v1/invoicing/sales-invoices/$invoiceId/pdf';
      final url = Uri.parse('$_base$path');
      final res = await _httpClient.post(url, headers: _h);
      if (res.statusCode == 200) return res.bodyBytes;
      return null;
    } catch (_) {
      return null;
    }
  }
}


class ApiResult {
  final bool success;
  final dynamic data;
  final String? error;
  const ApiResult._({required this.success, this.data, this.error});
  factory ApiResult.ok(dynamic data) => ApiResult._(success:true, data:data);
  factory ApiResult.error(String error) => ApiResult._(success:false, error:error);
  T? get<T>(String key) { if(data is Map) return data[key] as T?; return null; }
  @override String toString() => success?'ok($data)':'error($error)';

}
