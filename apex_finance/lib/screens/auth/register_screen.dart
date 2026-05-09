import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../../widgets/form_helpers.dart';
// G-AUTH-TENANT-PERSIST (2026-05-09): see app_providers.dart.
import '../../pilot/session.dart';

class RegScreen extends StatefulWidget {
  const RegScreen({super.key});
  @override State<RegScreen> createState() => _RegS();
}
class _RegS extends State<RegScreen> {
  final _un=TextEditingController(),_em=TextEditingController(),_dn=TextEditingController(),_pw=TextEditingController();
  bool _l=false; String? _e;
  @override
  void dispose() {
    _un.dispose();
    _em.dispose();
    _dn.dispose();
    _pw.dispose();
    super.dispose();
  }
  Future<void> _go() async {
    setState((){ _l=true; _e=null; });
    try {
      final res = await ApiService.register(username: _un.text.trim(), email: _em.text.trim(), displayName: _dn.text.trim(), password: _pw.text);
      if(res.success) {
        final d = res.data;
        S.token=d['tokens']['access_token']; S.uid=d['user']['id'];
        S.uname=d['user']['username']; S.dname=d['user']['display_name'];
        S.plan=d['user']['plan']; S.email=d['user']['email'];
        // G-AUTH-TENANT-PERSIST (2026-05-09): persist tenant_id from
        // ERR-2 auto-tenant so the wizard's hasTenant branch fires.
        final tenantId = d['user']['tenant_id'];
        if (tenantId is String && tenantId.isNotEmpty) {
          PilotSession.tenantId = tenantId;
        }
        ApiService.setToken(S.token!);
        S.save();
        if(mounted) context.go('/home');
      } else { setState(()=> _e=res.error??'خطأ'); }
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('إنشاء حساب', style: TextStyle(color: AC.gold))),
    body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400), child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller:_un, decoration:apexInputDecoration('اسم المستخدم *', ic: Icons.alternate_email)),
        SizedBox(height:12), TextField(controller:_em, decoration:apexInputDecoration('البريد الإلكتروني *', ic: Icons.email_outlined)),
        SizedBox(height:12), TextField(controller:_dn, decoration:apexInputDecoration('الاسم الظاهر *', ic: Icons.badge_outlined)),
        SizedBox(height:12), TextField(controller:_pw, obscureText:true, decoration:apexInputDecoration('كلمة المرور *', ic: Icons.lock_outline)),
        if(_e!=null) Padding(padding:EdgeInsets.only(top:10), child:Text(_e!, style:TextStyle(color:AC.err, fontSize:12))),
        const SizedBox(height:22),
        SizedBox(width:double.infinity, child: ElevatedButton(onPressed:_l?null:_go,
          child: _l ? const CircularProgressIndicator(strokeWidth:2) : const Text('إنشاء الحساب'))),
      ])))));
}
