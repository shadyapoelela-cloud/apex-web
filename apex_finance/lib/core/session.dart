import 'dart:convert';
import 'dart:html' as html;

import '../api_service.dart';
import '../pilot/session.dart';

class S {
  static String? _token, uid, uname, dname, plan, email;
  static String? tenantId, entityId;

  // G-ENTITY-SELLER-INFO (2026-05-11): in-memory seller identity
  // cache. Loaded by `fetchEntitySellerInfo()` and read by the POS
  // receipt + sales-invoice QR builder. Backed by localStorage
  // (`pilot.seller_vat`, `pilot.seller_name_ar`, `pilot.seller_address_ar`)
  // so a page refresh keeps the values around for the next sale.
  // Nullable because legacy entities haven't filled them yet — callers
  // MUST keep fallback placeholders so the QR still renders.
  static String? _cachedSellerVat;
  static String? _cachedSellerNameAr;
  static String? _cachedSellerAddressAr;
  // G-LEGACY-KEY-AUDIT (2026-05-09): canonical key is `pilot.tenant_id`.
  // Fall back through both localStorage keys (pilot first, then
  // legacy) so screens that still read S.savedTenantId see whatever
  // was written through PilotSession or any pre-pilot session
  // writer. The PilotSession.tenantId setter keeps both keys in
  // sync going forward; this fallback chain handles read-time
  // drift detection from earlier sessions.
  static String? get savedTenantId =>
      tenantId ??
      html.window.localStorage['pilot.tenant_id'] ??
      html.window.localStorage['apex_tenant_id'];
  static String? get savedEntityId =>
      entityId ??
      html.window.localStorage['pilot.entity_id'] ??
      html.window.localStorage['apex_entity_id'];

  /// G-ENTITY-SELLER-INFO: ZATCA-rendered VAT number for the active
  /// entity. Read order: in-memory cache → localStorage. Callers
  /// MUST treat null as "fall back to the placeholder" so the QR
  /// still renders (Phase-1 just needs *something* in tag 2, even if
  /// it's wrong; better wrong than absent until the user fills in
  /// the real value via entity settings).
  static String? get savedSellerVatNumber =>
      _cachedSellerVat ??
      html.window.localStorage['pilot.seller_vat'];
  static set savedSellerVatNumber(String? v) {
    _cachedSellerVat = (v != null && v.isNotEmpty) ? v : null;
    final st = html.window.localStorage;
    if (_cachedSellerVat != null) {
      st['pilot.seller_vat'] = _cachedSellerVat!;
    } else {
      st.remove('pilot.seller_vat');
    }
  }

  /// G-ENTITY-SELLER-INFO: Arabic legal name displayed on ZATCA QR
  /// receipts. Falls back to placeholder when null.
  static String? get savedSellerNameAr =>
      _cachedSellerNameAr ??
      html.window.localStorage['pilot.seller_name_ar'];
  static set savedSellerNameAr(String? v) {
    _cachedSellerNameAr = (v != null && v.isNotEmpty) ? v : null;
    final st = html.window.localStorage;
    if (_cachedSellerNameAr != null) {
      st['pilot.seller_name_ar'] = _cachedSellerNameAr!;
    } else {
      st.remove('pilot.seller_name_ar');
    }
  }

  /// G-ENTITY-SELLER-INFO: optional Phase-2 readiness — Arabic legal
  /// address for the simplified-tax invoice. Not rendered in Phase-1
  /// QR but persisted for future use.
  static String? get savedSellerAddressAr =>
      _cachedSellerAddressAr ??
      html.window.localStorage['pilot.seller_address_ar'];
  static set savedSellerAddressAr(String? v) {
    _cachedSellerAddressAr = (v != null && v.isNotEmpty) ? v : null;
    final st = html.window.localStorage;
    if (_cachedSellerAddressAr != null) {
      st['pilot.seller_address_ar'] = _cachedSellerAddressAr!;
    } else {
      st.remove('pilot.seller_address_ar');
    }
  }

  /// G-ENTITY-SELLER-INFO: fetches the active entity from the backend
  /// and caches the three seller-info fields. Fire-and-forget from
  /// the POS + sales-details screens in `initState` — the next sale
  /// or QR render picks up real values without blocking the UI.
  /// Silent on failure: the placeholder fallback ensures the QR keeps
  /// rendering even if the API is unreachable.
  static Future<void> fetchEntitySellerInfo() async {
    final eid = savedEntityId;
    if (eid == null || eid.isEmpty) return;
    try {
      final res = await ApiService.pilotGetEntity(eid);
      if (!res.success) return;
      final data = res.data;
      if (data is! Map) return;
      final map = data.cast<String, dynamic>();
      final vat = map['seller_vat_number'];
      final nameAr = map['seller_name_ar'];
      final addrAr = map['seller_address_ar'];
      if (vat is String && vat.isNotEmpty) savedSellerVatNumber = vat;
      if (nameAr is String && nameAr.isNotEmpty) savedSellerNameAr = nameAr;
      if (addrAr is String && addrAr.isNotEmpty) {
        savedSellerAddressAr = addrAr;
      }
    } catch (_) {
      // Network or parse error — keep whatever was cached / fall back
      // to placeholders. Never surface as a user-visible error since
      // it's a background refresh.
    }
  }

  /// DASH-1.1: cached effective permission set for the active user.
  /// Populated from JWT claims after login, plus refreshed whenever the
  /// dashboard fetches /widgets (the catalog response is permission-scoped
  /// so the resulting code-set lower-bounds what we know the user can do).
  /// Reads fall back to localStorage so a refresh doesn't clobber the
  /// permission gate before the next API call.
  static List<String> userPerms = const [];
  static List<String> get savedUserPerms {
    if (userPerms.isNotEmpty) return userPerms;
    final raw = html.window.localStorage['apex_user_perms'];
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        userPerms = decoded.cast<String>();
        return userPerms;
      }
    } catch (_) {/* fall through */}
    return raw.split(',').where((p) => p.isNotEmpty).toList();
  }
  static set savedUserPerms(List<String> v) {
    userPerms = List.unmodifiable(v);
    html.window.localStorage['apex_user_perms'] = jsonEncode(userPerms);
  }
  static bool hasPerm(String perm) {
    if (perm == 'read:dashboard' && (token ?? '').isNotEmpty) return true;
    return savedUserPerms.contains(perm);
  }
  static void setActiveScope({required String tenant, required String entity}) {
    tenantId = tenant;
    entityId = entity;
    // G-LEGACY-KEY-AUDIT (2026-05-09): route through PilotSession's
    // setter so BOTH `pilot.tenant_id` AND `apex_tenant_id` stay in
    // sync. Pre-fix this method wrote only the legacy key, so any
    // PilotSession-canonical reader got a stale value.
    PilotSession.tenantId = tenant;
    PilotSession.entityId = entity;
  }
  static String? get token {
    _token ??= html.window.localStorage['apex_token'];
    return (_token != null && _token!.isNotEmpty) ? _token : null;
  }
  static set token(String? v) {
    _token = v;
    if (v != null && v.isNotEmpty) {
      html.window.localStorage['apex_token'] = v;
    } else {
      html.window.localStorage.remove('apex_token');
    }
  }
  static List<String> roles = [];

  /// True when the current user has APEX-staff privileges.
  /// Demo screens, admin tooling, and unfinished sprint demos are gated on this.
  static bool get isPlatformAdmin =>
      roles.contains('platform_admin') || roles.contains('super_admin');

  static String get liveToken => html.window.localStorage['apex_token'] ?? '';
  static void clear() {
    token=null; uid=null; uname=null; dname=null; plan=null; email=null; roles=[];
    tenantId=null; entityId=null;
    userPerms = const [];
    // G-ENTITY-SELLER-INFO: clear cached seller identity too so the
    // next user logging in on the same browser doesn't inherit the
    // previous tenant's ZATCA seller info.
    _cachedSellerVat = null;
    _cachedSellerNameAr = null;
    _cachedSellerAddressAr = null;
    final st = html.window.localStorage;
    st.remove('apex_token'); st.remove('apex_uid'); st.remove('apex_uname');
    st.remove('apex_dname'); st.remove('apex_plan'); st.remove('apex_email');
    st.remove('apex_roles'); st.remove('apex_tenant_id'); st.remove('apex_entity_id');
    st.remove('apex_user_perms');
    st.remove('pilot.seller_vat');
    st.remove('pilot.seller_name_ar');
    st.remove('pilot.seller_address_ar');
    // G-LEGACY-KEY-AUDIT (2026-05-09): clear the new pilot.* keys
    // too. Pre-fix, S.clear() wiped only the legacy keys — the
    // 401 interceptor (api_service.dart:51) and any other caller
    // of S.clear() would leave pilot.tenant_id behind, so the next
    // user logging in on the same browser would see hasTenant=true
    // with the previous user's tenantId. PilotSession.clear() is
    // idempotent (safe to call when already cleared).
    PilotSession.clear();
  }
  static String planAr() {
    const m = {'free':'مجاني','pro':'احترافي','business':'أعمال','expert':'خبير','enterprise':'مؤسسي'};
    return m[plan] ?? plan ?? 'مجاني';
  }

  static void save() {
    final st = html.window.localStorage;
    if (token != null) st['apex_token'] = token!;
    if (uid != null) st['apex_uid'] = uid!;
    if (uname != null) st['apex_uname'] = uname!;
    if (dname != null) st['apex_dname'] = dname!;
    if (plan != null) st['apex_plan'] = plan!;
    if (email != null) st['apex_email'] = email!;
    st['apex_roles'] = roles.join(',');
  }
  static bool restore() {
    final st = html.window.localStorage;
    if (st['apex_token'] == null || st['apex_token']!.isEmpty) return false;
    token = st['apex_token']; uid = st['apex_uid'];
    uname = st['apex_uname']; dname = st['apex_dname'];
    plan = st['apex_plan']; email = st['apex_email'];
    final r = st['apex_roles'];
    if (r != null && r.isNotEmpty) {
      try { roles = List<String>.from(jsonDecode(r)); }
      catch(_) { roles = r.split(','); }
    }
    return true;
  }
}
