class S {
  static String? token, uid, uname, dname, plan, email;
  static List<String> roles = [];
  static Map<String, String> h() => {'Authorization': 'Bearer ${token ?? ""}'};
  static Map<String, String> hj() => {'Authorization': 'Bearer ${token ?? ""}', 'Content-Type': 'application/json'};
  static void clear() { token = null; uid = null; uname = null; dname = null; plan = null; email = null; roles = []; }
  static String planAr() {
    const m = {'free': 'مجاني', 'pro': 'احترافي', 'business': 'أعمال', 'expert': 'خبير', 'enterprise': 'مؤسسي'};
    return m[plan] ?? plan ?? 'مجاني';
  }
}
