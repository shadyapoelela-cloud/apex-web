import os

m = r'C:\apex_app\apex_finance\lib\main.dart'
with open(m, 'r', encoding='utf-8-sig') as f:
    content = f.read()

# ============================================================
# Fix 1: DashTab - convert to ConsumerStatefulWidget
# ============================================================

old_dash_widget = "class DashTab extends StatefulWidget { const DashTab({super.key}); @override State<DashTab> createState()=>_DashS(); }"
new_dash_widget = "class DashTab extends ConsumerStatefulWidget { const DashTab({super.key}); @override ConsumerState<DashTab> createState()=>_DashS(); }"

old_dash_state = "class _DashS extends State<DashTab> {"
new_dash_state = "class _DashS extends ConsumerState<DashTab> {"

if old_dash_widget in content:
    content = content.replace(old_dash_widget, new_dash_widget)
    print('FIX 1a: DashTab -> ConsumerStatefulWidget')
else:
    print('WARN: DashTab widget pattern not found')

if old_dash_state in content:
    content = content.replace(old_dash_state, new_dash_state, 1)
    print('FIX 1b: _DashS -> ConsumerState')
else:
    print('WARN: _DashS state pattern not found')

# Replace DashTab._load() HTTP calls with Riverpod providers
old_dash_load = """  Map<String,dynamic>? _sub; List _plans=[]; bool _ld=true; int _notifCount=0;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {      
    try {
      final r1 = await http.get(Uri.parse('$_api/subscriptions/me'), headers: S.h());
      final r2 = await http.get(Uri.parse('$_api/plans'));
      final r3 = await http.get(Uri.parse('$_api/notifications'), headers: S.h());
      if(mounted) setState(() {     
        _sub = jsonDecode(r1.body); _plans = jsonDecode(r2.body);       
        try { final nots = jsonDecode(r3.body); if(nots is List) _notifCount = nots.where((n)=>n['is_read']!=true).length; } catch(_){}
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }"""

new_dash_load = """  Map<String,dynamic>? _sub; List _plans=[]; bool _ld=true; int _notifCount=0;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final subAsync = ref.refresh(currentPlanProvider);
      final plansAsync = ref.refresh(plansProvider);
      final notifAsync = ref.refresh(notificationsProvider);
      final sub = await subAsync.last;
      final plans = await plansAsync.last;
      final notifs = await notifAsync.last;
      if(mounted) setState(() {
        _sub = sub.valueOrNull; _plans = plans.valueOrNull ?? [];
        final nl = notifs.valueOrNull ?? [];
        _notifCount = nl.where((n) => n['is_read'] != true).length;
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }"""

if old_dash_load in content:
    content = content.replace(old_dash_load, new_dash_load)
    print('FIX 1c: DashTab._load() -> Riverpod providers')
else:
    print('WARN: DashTab._load() pattern not found - will use simple approach')
    # Simpler approach: just convert the class declarations, keep HTTP calls
    # The consumer conversion alone is still valuable for future migration
    pass


# ============================================================
# Fix 2: ClientsTab - convert to ConsumerStatefulWidget
# ============================================================

old_clients_widget = "class ClientsTab extends StatefulWidget { const ClientsTab({super.key}); @override State<ClientsTab> createState()=>_ClientsS(); }"
new_clients_widget = "class ClientsTab extends ConsumerStatefulWidget { const ClientsTab({super.key}); @override ConsumerState<ClientsTab> createState()=>_ClientsS(); }"

old_clients_state = "class _ClientsS extends State<ClientsTab> {"
new_clients_state = "class _ClientsS extends ConsumerState<ClientsTab> {"

if old_clients_widget in content:
    content = content.replace(old_clients_widget, new_clients_widget)
    print('FIX 2a: ClientsTab -> ConsumerStatefulWidget')
else:
    print('WARN: ClientsTab widget pattern not found')

if old_clients_state in content:
    content = content.replace(old_clients_state, new_clients_state, 1)
    print('FIX 2b: _ClientsS -> ConsumerState')
else:
    print('WARN: _ClientsS state pattern not found')


# ============================================================
# Fix 3: NotificationsScreen (old one at L281) - convert
# ============================================================

old_notif_widget = "class NotificationsScreen extends StatefulWidget {"
new_notif_widget = "class NotificationsScreen extends ConsumerStatefulWidget {"

old_notif_state = "class _NotifS extends State<NotificationsScreen> {"
new_notif_state = "class _NotifS extends ConsumerState<NotificationsScreen> {"

if old_notif_widget in content:
    content = content.replace(old_notif_widget, new_notif_widget, 1)
    print('FIX 3a: NotificationsScreen -> ConsumerStatefulWidget')

if old_notif_state in content:
    content = content.replace(old_notif_state, new_notif_state, 1)
    print('FIX 3b: _NotifS -> ConsumerState')


# ============================================================
# Fix 4: AnalysisTab - convert
# ============================================================

old_analysis_widget = "class AnalysisTab extends StatefulWidget { const AnalysisTab({super.key}); @override State<AnalysisTab> createState()=>_AnalysisS(); }"
new_analysis_widget = "class AnalysisTab extends ConsumerStatefulWidget { const AnalysisTab({super.key}); @override ConsumerState<AnalysisTab> createState()=>_AnalysisS(); }"

old_analysis_state = "class _AnalysisS extends State<AnalysisTab> {"
new_analysis_state = "class _AnalysisS extends ConsumerState<AnalysisTab> {"

if old_analysis_widget in content:
    content = content.replace(old_analysis_widget, new_analysis_widget)
    print('FIX 4a: AnalysisTab -> ConsumerStatefulWidget')

if old_analysis_state in content:
    content = content.replace(old_analysis_state, new_analysis_state, 1)
    print('FIX 4b: _AnalysisS -> ConsumerState')


# ============================================================
# Fix 5: MarketTab - convert
# ============================================================

old_market_widget = "class MarketTab extends StatefulWidget { const MarketTab({super.key}); @override State<MarketTab> createState()=>_MarketS(); }"
new_market_widget = "class MarketTab extends ConsumerStatefulWidget { const MarketTab({super.key}); @override ConsumerState<MarketTab> createState()=>_MarketS(); }"

old_market_state = "class _MarketS extends State<MarketTab> {"
new_market_state = "class _MarketS extends ConsumerState<MarketTab> {"

if old_market_widget in content:
    content = content.replace(old_market_widget, new_market_widget)
    print('FIX 5a: MarketTab -> ConsumerStatefulWidget')

if old_market_state in content:
    content = content.replace(old_market_state, new_market_state, 1)
    print('FIX 5b: _MarketS -> ConsumerState')


# ============================================================
# Fix 6: AccountTab - convert
# ============================================================

old_acc_widget = "class AccountTab extends StatefulWidget { const AccountTab({super.key}); @override State<AccountTab> createState()=>_AccS(); }"
new_acc_widget = "class AccountTab extends ConsumerStatefulWidget { const AccountTab({super.key}); @override ConsumerState<AccountTab> createState()=>_AccS(); }"

old_acc_state = "class _AccS extends State<AccountTab> {"
new_acc_state = "class _AccS extends ConsumerState<AccountTab> {"

if old_acc_widget in content:
    content = content.replace(old_acc_widget, new_acc_widget)
    print('FIX 6a: AccountTab -> ConsumerStatefulWidget')

if old_acc_state in content:
    content = content.replace(old_acc_state, new_acc_state, 1)
    print('FIX 6b: _AccS -> ConsumerState')


# ============================================================
# Fix 7: AdminTab - convert
# ============================================================

old_admin_widget = "class AdminTab extends StatefulWidget { const AdminTab({super.key}); @override State<AdminTab> createState()=>_AdminS(); }"
new_admin_widget = "class AdminTab extends ConsumerStatefulWidget { const AdminTab({super.key}); @override ConsumerState<AdminTab> createState()=>_AdminS(); }"

old_admin_state = "class _AdminS extends State<AdminTab> {"
new_admin_state = "class _AdminS extends ConsumerState<AdminTab> {"

if old_admin_widget in content:
    content = content.replace(old_admin_widget, new_admin_widget)
    print('FIX 7a: AdminTab -> ConsumerStatefulWidget')

if old_admin_state in content:
    content = content.replace(old_admin_state, new_admin_state, 1)
    print('FIX 7b: _AdminS -> ConsumerState')


# ============================================================
# Ensure Riverpod import exists
# ============================================================
if 'flutter_riverpod' not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';",
        1
    )
    print('Added flutter_riverpod import')

if 'app_providers.dart' not in content:
    content = content.replace(
        "import 'package:flutter_riverpod/flutter_riverpod.dart';",
        "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'providers/app_providers.dart';",
        1
    )
    print('Added app_providers import')

# ============================================================
# Save
# ============================================================
with open(m, 'w', encoding='utf-8') as f:
    f.write(content)

# Count changes
changes = content.count('ConsumerState<') + content.count('ConsumerStatefulWidget')
print('')
print('Total ConsumerState/ConsumerStatefulWidget references: %d' % changes)
print('DONE - run: flutter analyze 2>&1 | Select-String "error" | Measure-Object')
