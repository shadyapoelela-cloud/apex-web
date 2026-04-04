import os

m = r'C:\apex_app\apex_finance\lib\main.dart'
with open(m, 'r', encoding='utf-8-sig') as f:
    content = f.read()

# ============================================================
# Fix 1: DashTab._load() - replace HTTP calls with ref.read
# ============================================================

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
      ref.invalidate(currentPlanProvider);
      ref.invalidate(plansProvider);
      ref.invalidate(notificationsProvider);
      final sub = await ref.read(currentPlanProvider.future);
      final plans = await ref.read(plansProvider.future);
      final notifs = await ref.read(notificationsProvider.future);
      if(mounted) setState(() {
        _sub = sub; _plans = plans;
        _notifCount = notifs.where((n) => n['is_read'] != true).length;
        _ld = false;
      });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }"""

if old_dash_load in content:
    content = content.replace(old_dash_load, new_dash_load)
    print('FIX 1: DashTab._load() -> ref.read(providers)')
else:
    print('WARN: DashTab._load() exact pattern not found')
    # Try line-by-line approach
    lines = content.split('\n')
    found = False
    for i, line in enumerate(lines):
        if "_api/subscriptions/me" in line and "r1" in line:
            # Found the HTTP block - replace the 3 HTTP lines + setState block
            # Find the start (try { line)
            start = i - 1
            while start > 0 and 'try {' not in lines[start]:
                start -= 1
            # Find the end (catch line)
            end = i + 1
            while end < len(lines) and 'catch(_)' not in lines[end]:
                end += 1
            end += 1  # include catch line

            new_block = [
                "    try {",
                "      ref.invalidate(currentPlanProvider);",
                "      ref.invalidate(plansProvider);",
                "      ref.invalidate(notificationsProvider);",
                "      final sub = await ref.read(currentPlanProvider.future);",
                "      final plans = await ref.read(plansProvider.future);",
                "      final notifs = await ref.read(notificationsProvider.future);",
                "      if(mounted) setState(() {",
                "        _sub = sub; _plans = plans;",
                "        _notifCount = notifs.where((n) => n['is_read'] != true).length;",
                "        _ld = false;",
                "      });",
                "    } catch(_) { if(mounted) setState(()=> _ld=false); }",
            ]
            lines[start:end] = new_block
            content = '\n'.join(lines)
            print('FIX 1: DashTab._load() -> ref.read(providers) [line-by-line]')
            found = True
            break
    if not found:
        print('ERROR: Could not find DashTab HTTP calls')


# ============================================================
# Fix 2: ClientsTab._load() - replace HTTP call with ref.read
# ============================================================

old_clients_load = """  List _cl=[]; bool _ld=true;       
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {      
    try { final r = await http.get(Uri.parse('$_api/clients'), headers: S.h());
      if(mounted) setState((){  _cl=jsonDecode(r.body); _ld=false; });  
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }"""

new_clients_load = """  List _cl=[]; bool _ld=true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      ref.invalidate(clientsProvider);
      final clients = await ref.read(clientsProvider.future);
      if(mounted) setState(() { _cl = clients; _ld = false; });
    } catch(_) { if(mounted) setState(()=> _ld=false); }
  }"""

if old_clients_load in content:
    content = content.replace(old_clients_load, new_clients_load)
    print('FIX 2: ClientsTab._load() -> ref.read(clientsProvider)')
else:
    print('WARN: ClientsTab._load() exact pattern not found, trying flexible')
    if "_api/clients'" in content and "class _ClientsS" in content:
        # Find the line with _api/clients and replace just the HTTP part
        content = content.replace(
            "try { final r = await http.get(Uri.parse('$_api/clients'), headers: S.h());\n      if(mounted) setState((){  _cl=jsonDecode(r.body); _ld=false; });",
            "try {\n      ref.invalidate(clientsProvider);\n      final clients = await ref.read(clientsProvider.future);\n      if(mounted) setState(() { _cl = clients; _ld = false; });"
        )
        print('FIX 2: ClientsTab._load() -> ref.read [flexible match]')


# ============================================================
# Save
# ============================================================
with open(m, 'w', encoding='utf-8') as f:
    f.write(content)

# Count ref.read usage
ref_reads = content.count('ref.read(')
ref_invalidates = content.count('ref.invalidate(')
print('')
print('ref.read() calls: %d' % ref_reads)
print('ref.invalidate() calls: %d' % ref_invalidates)
print('DONE - run: flutter analyze 2>&1 | Select-String "error" | Measure-Object')
