import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/session.dart';
import '../../core/theme.dart';

InputDecoration _inp(String l, {IconData? ic}) => InputDecoration(
  labelText: l, prefixIcon: ic != null ? Icon(ic, color: AC.gold, size: 20) : null,
  filled: true, fillColor: AC.navy3, labelStyle: TextStyle(color: AC.ts),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AC.gold)));

// ═══════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  final Map<String,dynamic>? profile;
  const EditProfileScreen({super.key, this.profile});
  @override State<EditProfileScreen> createState() => _EditPS();
}
class _EditPS extends State<EditProfileScreen> {
  late TextEditingController _dn, _org, _job, _city;
  bool _l=false; String? _e; bool _done=false;
  @override void dispose() { _dn.dispose(); _org.dispose(); _job.dispose(); _city.dispose(); super.dispose(); }
  @override void initState() { super.initState();
    _dn=TextEditingController(text: widget.profile?['user']?['display_name']??'');
    _org=TextEditingController(text: widget.profile?['profile']?['organization_name']??'');
    _job=TextEditingController(text: widget.profile?['profile']?['job_title']??'');
    _city=TextEditingController(text: widget.profile?['profile']?['city']??'');
  }
  Future<void> _save() async {
    setState((){ _l=true; _e=null; });
    try {
      final res = await ApiService.updateUser({'display_name':_dn.text.trim(),'organization_name':_org.text.trim(),'job_title':_job.text.trim(),'city':_city.text.trim()});
      if(res.success) { setState(()=> _done=true); }
      else { setState(()=> _e=res.error); }
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0644\u0641 \u0627\u0644\u0634\u062e\u0635\u064a', style: TextStyle(color: AC.gold))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle, color: AC.ok, size: 60), SizedBox(height: 16),
      Text('\u062a\u0645 \u0627\u0644\u062d\u0641\u0638 \u0628\u0646\u062c\u0627\u062d', style: TextStyle(color: AC.tp, fontSize: 18)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: ()=>Navigator.pop(c), child: const Text('\u0631\u062c\u0648\u0639'))])) :
    SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: _dn, decoration: _inp('\u0627\u0644\u0627\u0633\u0645 \u0627\u0644\u0638\u0627\u0647\u0631', ic: Icons.person)),
      const SizedBox(height: 14),
      TextField(controller: _org, decoration: _inp('\u0627\u0644\u0645\u0646\u0638\u0645\u0629', ic: Icons.business)),
      const SizedBox(height: 14),
      TextField(controller: _job, decoration: _inp('\u0627\u0644\u0645\u0633\u0645\u0649 \u0627\u0644\u0648\u0638\u064a\u0641\u064a', ic: Icons.work)),
      const SizedBox(height: 14),
      TextField(controller: _city, decoration: _inp('\u0627\u0644\u0645\u062f\u064a\u0646\u0629', ic: Icons.location_city)),
      if(_e!=null) Padding(padding: EdgeInsets.only(top: 10), child: Text(_e!, style: TextStyle(color: AC.err))),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l?null:_save,
        child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('\u062d\u0641\u0638 \u0627\u0644\u062a\u063a\u064a\u064a\u0631\u0627\u062a')))])));
}

// ═══════════════════════════════════════════════════
// CHANGE PASSWORD (NEW)
// ═══════════════════════════════════════════════════
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override State<ChangePasswordScreen> createState() => _ChPwS();
}
class _ChPwS extends State<ChangePasswordScreen> {
  final _cur=TextEditingController(), _new1=TextEditingController(), _new2=TextEditingController();
  bool _l=false; String? _e; bool _done=false;
  @override void dispose() { _cur.dispose(); _new1.dispose(); _new2.dispose(); super.dispose(); }
  Future<void> _go() async {
    if(_new1.text!=_new2.text) { setState(()=> _e='\u0643\u0644\u0645\u062a\u0627 \u0627\u0644\u0645\u0631\u0648\u0631 \u063a\u064a\u0631 \u0645\u062a\u0637\u0627\u0628\u0642\u062a\u064a\u0646'); return; }
    setState((){ _l=true; _e=null; });
    try {
      final res = await ApiService.changePassword(current: _cur.text, newPw: _new1.text, confirm: _new2.text);
      if(res.success) setState(()=> _done=true);
      else setState(()=> _e=res.error);
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', style: TextStyle(color: AC.gold))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle, color: AC.ok, size: 60), SizedBox(height: 16),
      Text('\u062a\u0645 \u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', style: TextStyle(color: AC.tp, fontSize: 18)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: ()=>Navigator.pop(c), child: const Text('\u0631\u062c\u0648\u0639'))])) :
    SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
      TextField(controller: _cur, obscureText: true, decoration: _inp('\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631 \u0627\u0644\u062d\u0627\u0644\u064a\u0629', ic: Icons.lock)),
      const SizedBox(height: 14),
      TextField(controller: _new1, obscureText: true, decoration: _inp('\u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631 \u0627\u0644\u062c\u062f\u064a\u062f\u0629', ic: Icons.lock_outline)),
      const SizedBox(height: 14),
      TextField(controller: _new2, obscureText: true, decoration: _inp('\u062a\u0623\u0643\u064a\u062f \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', ic: Icons.lock_outline)),
      if(_e!=null) Padding(padding: EdgeInsets.only(top: 10), child: Text(_e!, style: TextStyle(color: AC.err))),
      const SizedBox(height: 22),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _l?null:_go,
        child: _l ? const CircularProgressIndicator(strokeWidth: 2) : const Text('\u062a\u063a\u064a\u064a\u0631')))])));
}

// ═══════════════════════════════════════════════════
// CLOSE ACCOUNT (NEW)
// ═══════════════════════════════════════════════════
class CloseAccountScreen extends StatefulWidget {
  const CloseAccountScreen({super.key});
  @override State<CloseAccountScreen> createState() => _CloseAS();
}
class _CloseAS extends State<CloseAccountScreen> {
  String _type = 'temporary'; String? _e; bool _l=false, _done=false;
  Future<void> _go() async {
    setState((){ _l=true; _e=null; });
    try {
      final res = await ApiService.requestClosure(type: _type);
      if(res.success) setState(()=> _done=true);
      else setState(()=> _e=res.error??'\u062e\u0637\u0623');
    } catch(e){ setState(()=> _e='$e'); }
    finally { if(mounted) setState(()=> _l=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u062d\u0633\u0627\u0628', style: TextStyle(color: AC.err))),
    body: _done ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle, color: AC.ok, size: 60), SizedBox(height: 16),
      Text('\u062a\u0645 \u062a\u0642\u062f\u064a\u0645 \u0637\u0644\u0628 \u0627\u0644\u0625\u063a\u0644\u0627\u0642', style: TextStyle(color: AC.tp, fontSize: 18)),
      const SizedBox(height: 16),
      ElevatedButton(onPressed: (){ S.clear(); context.go('/login'); },
        child: const Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c'))])) :
    SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: AC.err.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [Icon(Icons.warning, color: AC.err), SizedBox(width: 10),
          Expanded(child: Text('\u0647\u0630\u0627 \u0627\u0644\u0625\u062c\u0631\u0627\u0621 \u0644\u0627 \u064a\u0645\u0643\u0646 \u0627\u0644\u062a\u0631\u0627\u062c\u0639 \u0639\u0646\u0647 \u0628\u0633\u0647\u0648\u0644\u0629', style: TextStyle(color: AC.err, fontSize: 13)))])),
      const SizedBox(height: 20),
      Text('\u0646\u0648\u0639 \u0627\u0644\u0625\u063a\u0644\u0627\u0642', style: TextStyle(color: AC.ts, fontSize: 14)),
      const SizedBox(height: 10),
      GestureDetector(onTap: ()=>setState(()=>_type='temporary'),
        child: Container(padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: _type=='temporary'?AC.warn.withValues(alpha: 0.1):AC.navy3,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _type=='temporary'?AC.warn:AC.bdr)),
          child: Row(children: [Icon(_type=='temporary'?Icons.radio_button_checked:Icons.radio_button_off,
            color: _type=='temporary'?AC.warn:AC.ts, size: 18), SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('\u0645\u0624\u0642\u062a', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
              Text('\u064a\u0645\u0643\u0646\u0643 \u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u062a\u0641\u0639\u064a\u0644 \u0644\u0627\u062d\u0642\u0627\u064b', style: TextStyle(color: AC.ts, fontSize: 11))]))]))),
      GestureDetector(onTap: ()=>setState(()=>_type='permanent'),
        child: Container(padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: _type=='permanent'?AC.err.withValues(alpha: 0.1):AC.navy3,
            borderRadius: BorderRadius.circular(10), border: Border.all(color: _type=='permanent'?AC.err:AC.bdr)),
          child: Row(children: [Icon(_type=='permanent'?Icons.radio_button_checked:Icons.radio_button_off,
            color: _type=='permanent'?AC.err:AC.ts, size: 18), SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('\u062f\u0627\u0626\u0645', style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
              Text('\u0633\u064a\u062a\u0645 \u062d\u0630\u0641 \u062d\u0633\u0627\u0628\u0643 \u0646\u0647\u0627\u0626\u064a\u0627\u064b', style: TextStyle(color: AC.ts, fontSize: 11))]))]))),
      if(_e!=null) Padding(padding: EdgeInsets.only(top: 10), child: Text(_e!, style: TextStyle(color: AC.err))),
      const SizedBox(height: 24),
      SizedBox(width: double.infinity, child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: AC.err),
        onPressed: _l?null:_go,
        child: _l ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) :
          const Text('\u062a\u0623\u0643\u064a\u062f \u0625\u063a\u0644\u0627\u0642 \u0627\u0644\u062d\u0633\u0627\u0628', style: TextStyle(color: Colors.white))))])));
}


// ═══════════════════════════════════════════════════
// ADMIN TAB — Platform Dashboard

// ═══════════════════════════════════════════════════════════
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override State<SessionsScreen> createState() => _SessionsScreenState();
}
class _SessionsScreenState extends State<SessionsScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getSessions();
      if (res.success) {
        setState(() => _sessions = res.data['sessions'] ?? []);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _logoutAll() async {
    final res = await ApiService.logoutAllSessions();
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنهاء جميع الجلسات'), backgroundColor: Colors.green));
      _load();
    }
  }

  Future<void> _logoutOne(String id) async {
    final res = await ApiService.logoutSession(id);
    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنهاء الجلسة'), backgroundColor: Colors.green));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        title: Text('الجلسات النشطة'), backgroundColor: AC.navy2,
        actions: [
          TextButton.icon(
            onPressed: _logoutAll,
            icon: Icon(Icons.logout, color: AC.err, size: 18),
            label: Text('إنهاء الكل', style: TextStyle(color: AC.err, fontSize: 12)),
          ),
        ],
      ),
      body: _loading
        ? Center(child: CircularProgressIndicator(color: AC.gold))
        : _sessions.isEmpty
          ? Center(child: Text('لا توجد جلسات نشطة', style: TextStyle(color: AC.ts)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _sessions.length,
              itemBuilder: (_, i) {
                final s = _sessions[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AC.navy3, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AC.bdr),
                  ),
                  child: Row(children: [
                    Icon(Icons.devices, color: AC.cyan, size: 32),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['device_info'] ?? 'جهاز غير معروف',
                          style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('IP: ${s['ip_address'] ?? '—'}',
                          style: TextStyle(color: AC.ts, fontSize: 12)),
                        Text('آخر نشاط: ${s['last_activity']?.toString().substring(0, 16) ?? '—'}',
                          style: TextStyle(color: AC.ts, fontSize: 12)),
                      ],
                    )),
                    IconButton(
                      onPressed: () => _logoutOne(s['id']),
                      icon: Icon(Icons.close, color: AC.err),
                      tooltip: 'إنهاء الجلسة',
                    ),
                  ]),
                );
              },
            ),
    ));
  }
}


// ═══════════════════════════════════════════════════════════
// SPRINT 1 — COA FIRST WORKFLOW SCREENS
// ═══════════════════════════════════════════════════════════


