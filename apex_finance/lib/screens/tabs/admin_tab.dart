import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';
import '../../widgets/apex_widgets.dart';

class AdminTab extends ConsumerStatefulWidget { const AdminTab({super.key}); @override ConsumerState<AdminTab> createState()=>_AdminS(); }
class _AdminS extends ConsumerState<AdminTab> {
  Map<String,dynamic> _stats = {}; List _users = []; bool _ld = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final r1 = await ApiService.adminStats();
      final r2 = await ApiService.adminUsers();
      if(mounted) setState(() {
        _stats = r1.data is Map ? Map<String,dynamic>.from(r1.data) : {};
        final d2 = r2.data; _users = d2 is List ? d2 : [];
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }
  @override Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(title: Text('\u0644\u0648\u062d\u0629 \u0627\u0644\u0625\u062f\u0627\u0631\u0629', style: TextStyle(color: AC.gold)),
      actions: [
        ApexIconButton(icon: Icons.rate_review, color: AC.cyan,
          tooltip: 'المراجع', onPressed: ()=>context.go('/admin/reviewer')),
        ApexIconButton(icon: Icons.verified_user, color: AC.ok,
          tooltip: 'التحقق من مقدمي الخدمات', onPressed: ()=>context.go('/admin/providers/verify')),
        ApexIconButton(icon: Icons.upload_file, color: AC.gold,
          tooltip: 'مستندات مقدمي الخدمات', onPressed: ()=>context.go('/admin/providers/documents')),
        ApexIconButton(icon: Icons.shield, color: AC.gold,
          tooltip: 'الامتثال', onPressed: ()=>context.go('/admin/providers/compliance')),
        ApexIconButton(icon: Icons.psychology, color: AC.gold,
          tooltip: 'قاعدة المعرفة', onPressed: ()=>context.go('/knowledge/console')),
        ApexIconButton(icon: Icons.security, color: AC.gold,
          tooltip: 'سجل التدقيق', onPressed: ()=>context.go('/admin/audit')),
      ]),
    body: _ld ? Center(child: CircularProgressIndicator(color: AC.gold)) :
      RefreshIndicator(onRefresh: _load, color: AC.gold, child: ListView(padding: EdgeInsets.all(14), children: [
        // Stats Grid
        GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.6,
          children: [
            _statCard('\u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u0648\u0646', '${_stats['total_users']??_users.length}', Icons.people, AC.gold),
            _statCard('\u0627\u0644\u0639\u0645\u0644\u0627\u0621', '${_stats['total_clients']??0}', Icons.business, AC.cyan),
            _statCard('\u0645\u0642\u062f\u0645\u0648 \u0627\u0644\u062e\u062f\u0645\u0627\u062a', '${_stats['total_providers']??0}', Icons.work, AC.ok),
            _statCard('\u0627\u0644\u0637\u0644\u0628\u0627\u062a', '${_stats['total_requests']??0}', Icons.assignment, AC.warn),
            _statCard('\u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a', '${_stats['total_feedback']??0}', Icons.feedback, AC.purple),
            _statCard('\u0627\u0644\u062a\u062d\u0644\u064a\u0644\u0627\u062a', '${_stats['total_analyses']??0}', Icons.analytics, AC.info),
          ]),
        SizedBox(height: 16),
        // Quick Actions
        compactCard('\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u0633\u0631\u064a\u0639\u0629', [
          _actionTile('\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u0644\u0627\u062d\u0638\u0627\u062a \u0627\u0644\u0645\u0639\u0631\u0641\u064a\u0629', Icons.rate_review, AC.cyan,
            ()=>context.go('/admin/reviewer')),
          _actionTile('\u062a\u062d\u0642\u0642 \u0645\u0642\u062f\u0645\u064a \u0627\u0644\u062e\u062f\u0645\u0627\u062a', Icons.verified_user, AC.ok,
            ()=>context.go('/admin/providers/verify')),
          _actionTile('\u0625\u062f\u0627\u0631\u0629 \u0627\u0644\u0633\u064a\u0627\u0633\u0627\u062a', Icons.policy, AC.warn,
            ()=>context.go('/admin/policies')),
        ]),
        SizedBox(height: 16),
        // Users List
        compactCard('\u0622\u062e\u0631 \u0627\u0644\u0645\u0633\u062a\u062e\u062f\u0645\u064a\u0646', [
          if(_users.isEmpty) Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0628\u064a\u0627\u0646\u0627\u062a', style: TextStyle(color: AC.ts))
          else ..._users.take(10).map((u) => Padding(padding: EdgeInsets.only(bottom: 8),
            child: Row(children: [
              CircleAvatar(backgroundColor: AC.navy4, radius: 16,
                child: Text((u['display_name']??u['username']??'?')[0], style: TextStyle(color: AC.gold, fontSize: 12))),
              SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['display_name']??u['username']??'', style: TextStyle(color: AC.tp, fontSize: 13)),
                Text('${u['email']??''} \u2022 ${u['plan']??'free'}', style: TextStyle(color: AC.ts, fontSize: 10))])),
              compactBadge(u['status']??'active', u['status']=='active'?AC.ok:AC.err)])))
        ]),
      ])));

  Widget _statCard(String label, String value, IconData icon, Color color) => Container(
    padding: EdgeInsets.all(14),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Row(children: [Icon(icon, color: color, size: 22), Spacer(),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold))]),
      SizedBox(height: 6),
      Text(label, style: TextStyle(color: AC.ts, fontSize: 11))]));

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) =>
    ApexActionTile(label: label, icon: icon, color: color, onTap: onTap);
}

