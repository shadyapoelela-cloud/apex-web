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
    } catch(_) { return null; }
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
    } catch(_) {}
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
