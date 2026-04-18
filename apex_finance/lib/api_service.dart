import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'core/api_config.dart';
import 'core/session.dart';

class ApiService {
  static const _base = apiBase;
  static String? _token;
    static void setToken(String t) => _token = t;
  static void clearToken() => _token = null;
  static bool get isAuthenticated => _token != null;
  static Map<String,String> get _h => {'Content-Type':'application/json', if((_token ?? S.token)!=null)'Authorization':'Bearer ${_token ?? S.token ?? ""}'};

  // ── Auth ──
  static Future<ApiResult> login(String username, String password) => _post('/auth/login', {'username_or_email':username,'password':password});
  static Future<ApiResult> register({required String username, required String email, required String password, String? displayName, String? mobile, String? countryCode}) => _post('/auth/register', {'username':username,'email':email,'password':password,if(displayName!=null)'display_name':displayName,if(mobile!=null)'mobile':mobile,if(countryCode!=null)'mobile_country_code':countryCode});
  static Future<ApiResult> forgotPassword(String email) => _post('/auth/forgot-password', {'email':email});
  static Future<ApiResult> changePassword({required String current, required String newPw, required String confirm}) => _put('/users/me/security/password', {'current_password':current,'new_password':newPw,'confirm_password':confirm});

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

  // ── Clients ──
  static Future<ApiResult> getClientTypes() => _get('/client-types');
  static Future<ApiResult> listNotifications() => _get('/notifications');
  static Future<ApiResult> listClients() => _get('/clients');
  static Future<ApiResult> getClient(String id) => _get('/clients/$id');
  static Future<ApiResult> createClient({required String clientCode, required String name, required String clientType, String? nameAr, String? industry, String? country, String? currency}) => _post('/clients', {'client_code':clientCode,'name':name,'name_ar':nameAr ?? name,'client_type_code':clientType,if(industry!=null)'industry':industry,if(country!=null)'country':country,if(currency!=null)'currency':currency});
  static Future<ApiResult> updateClient(String id, Map body) => _put('/clients/$id', body);


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

    // ── Helpers ──
  static Future<ApiResult> _get(String path) async {
    try { final res=await http.get(Uri.parse('$_base$path'),headers:_h); if(res.statusCode==200)return ApiResult.ok(jsonDecode(res.body)); return ApiResult.error(_parseErr(res.body,res.statusCode)); } catch(e){return ApiResult.error('خطأ: $e');}
  }
  static Future<ApiResult> _post(String path, Map body) async {
    try { final res=await http.post(Uri.parse('$_base$path'),headers:_h,body:jsonEncode(body)); if(res.statusCode>=200&&res.statusCode<300)return ApiResult.ok(jsonDecode(res.body)); return ApiResult.error(_parseErr(res.body,res.statusCode)); } catch(e){return ApiResult.error('خطأ: $e');}
  }
  static Future<ApiResult> _put(String path, Map body) async {
    try { final res=await http.put(Uri.parse('$_base$path'),headers:_h,body:jsonEncode(body)); if(res.statusCode>=200&&res.statusCode<300)return ApiResult.ok(jsonDecode(res.body)); return ApiResult.error(_parseErr(res.body,res.statusCode)); } catch(e){return ApiResult.error('خطأ: $e');}
  }
  static Future<ApiResult> _delete(String path) async {
    try { final res=await http.delete(Uri.parse('$_base$path'),headers:_h); if(res.statusCode>=200&&res.statusCode<300)return ApiResult.ok(jsonDecode(res.body)); return ApiResult.error(_parseErr(res.body,res.statusCode)); } catch(e){return ApiResult.error('خطأ: $e');}
  }
  static Future<ApiResult> _patch(String path, Map body) async {
    try { final res=await http.patch(Uri.parse('$_base$path'),headers:_h,body:jsonEncode(body)); if(res.statusCode>=200&&res.statusCode<300)return ApiResult.ok(jsonDecode(res.body)); return ApiResult.error(_parseErr(res.body,res.statusCode)); } catch(e){return ApiResult.error('???: $e');}
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
