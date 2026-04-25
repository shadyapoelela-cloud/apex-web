import 'dart:convert';
import 'dart:html' as html;

class S {
  static String? _token, uid, uname, dname, plan, email;
  static String? tenantId, entityId;
  static String? get savedTenantId => tenantId ?? html.window.localStorage['apex_tenant_id'];
  static String? get savedEntityId => entityId ?? html.window.localStorage['apex_entity_id'];
  static void setActiveScope({required String tenant, required String entity}) {
    tenantId = tenant;
    entityId = entity;
    html.window.localStorage['apex_tenant_id'] = tenant;
    html.window.localStorage['apex_entity_id'] = entity;
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
  static String get liveToken => html.window.localStorage['apex_token'] ?? '';
  static void clear() {
    token=null; uid=null; uname=null; dname=null; plan=null; email=null; roles=[];
    tenantId=null; entityId=null;
    final st = html.window.localStorage;
    st.remove('apex_token'); st.remove('apex_uid'); st.remove('apex_uname');
    st.remove('apex_dname'); st.remove('apex_plan'); st.remove('apex_email');
    st.remove('apex_roles'); st.remove('apex_tenant_id'); st.remove('apex_entity_id');
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
