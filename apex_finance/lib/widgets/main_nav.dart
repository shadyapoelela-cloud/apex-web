import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api_service.dart';
import '../providers/app_providers.dart';
import '../core/apex_ask_panel.dart' show openApexAskPanel;
import '../core/session.dart';
import '../core/theme.dart';
import '../core/ui_components.dart';
import '../main.dart' show ClientsTab, AnalysisTab, MarketTab, ProviderTab, AccountTab, AdminTab;
import '../screens/dashboard/enhanced_dashboard.dart';
import 'apex_search.dart';

Widget quickServiceBtn(BuildContext c, String label, IconData icon, int tabIdx) => Padding(
    padding: EdgeInsets.only(left: 8),
    child: ActionChip(
      avatar: Icon(icon, color: AC.goldText, size: 16),
      label: Text(label, style: TextStyle(color: AC.tp, fontSize: 11)),
      backgroundColor: AC.navy3,
      side: BorderSide(color: AC.bdr),
      onPressed: () {
        final nav = c.findAncestorStateOfType<_MainNavS>();
        if (nav != null) nav.setState(() => nav._i = tabIdx);
      },
    ),
  );


class MainNav extends ConsumerStatefulWidget {
  const MainNav({super.key});
  @override ConsumerState<MainNav> createState() => _MainNavS();
}
class _MainNavS extends ConsumerState<MainNav> {
  int _i = 0;
  bool _dr = false;
  List _cl = [];
  List<String> _activeClients = [];
  final _bizKey = GlobalKey();
  final _notifKey = GlobalKey();
  List _notifs = [];
  double _fabX = 20;
  double _fabY = 100;
  String _clientLabel = '\u0644\u0645 \u064a\u062a\u0645 \u0627\u062e\u062a\u064a\u0627\u0631 \u0639\u0645\u064a\u0644';
  int _hoveredDrawerIndex = -1;
  @override
  void initState() {
    super.initState();
      Future.delayed(const Duration(milliseconds: 500), () {
      if(S.token!=null) ApiService.setToken(S.token!);
      ApiService.listClients().then((r) { if (r.success && mounted) { final d = r.data; setState(() => _cl = d is List ? d : []); } });
      ApiService.getNotifications().then((r) { if (r.success && mounted) { final d = r.data; setState(() => _notifs = d is List ? d : []); } });
      if (mounted) setState(() {});
    });
  }


  @override Widget build(BuildContext c) {
    _drawerItemCounter = 0;
    final tabs = [EnhancedDashboard(
          onSwitchToClients: () => setState(() => _i = 1),
          onCreateClient: () {
            setState(() => _i = 1);
            // Trigger create wizard after tab switch
          },
          onNavigateToCoa: _goToCoa,
        ), ClientsTab(), AnalysisTab(), const MarketTab(), const ProviderTab(), const AccountTab(), const AdminTab()];
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(children: [
        Container(padding: EdgeInsets.only(top: 40, left: 16, right: 16, bottom: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AC.navy2, AC.navy2.withValues(alpha: 0.95)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            border: Border(bottom: BorderSide(color: AC.gold.withValues(alpha: 0.12), width: 0.5)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            ApexLogo(fontSize: 18, onTap: () => setState(() => _i = 0)),
            _appBarDivider(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(color: AC.navy3.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
            // ── اسأل أبكس — AI agent sidebar (Ctrl+/ shortcut) ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AC.gold.withValues(alpha: 0.22), AC.gold.withValues(alpha: 0.08)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AC.gold.withValues(alpha: 0.45)),
              ),
              child: ApexIconButton(
                icon: Icons.auto_awesome,
                tooltip: 'اسأل أبكس (Ctrl+/)',
                onPressed: () => openApexAskPanel(context),
              ),
            ),
            ApexIconButton(icon: Icons.search, tooltip: 'البحث في المنصة', onPressed: () {
              showSearch(context: context, delegate: ApexSearch());
            }),
            Builder(key: _bizKey, builder: (btnCtx) => ApexIconButton(icon: Icons.business, tooltip: 'تبديل الشركة النشطة',
              showBadge: _activeClients.isNotEmpty, badgeColor: AC.ok,
              onPressed: () {
                final RenderBox btn = btnCtx.findRenderObject() as RenderBox;
                final Offset pos = btn.localToGlobal(Offset.zero);
                final Size sz = btn.size;
                showMenu<String>(
                  context: context,
                  color: AC.navy2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AC.gold, width: 0.5)),
                  position: RelativeRect.fromLTRB(pos.dx, pos.dy + sz.height, MediaQuery.of(context).size.width - pos.dx - 250, 0),
                  items: _cl.isEmpty
                    ? [PopupMenuItem<String>(value: '', enabled: false, child: Text('\u0644\u0627 \u064a\u0648\u062c\u062f \u0639\u0645\u0644\u0627\u0621', style: TextStyle(color: AC.ts, fontSize: 12)))]
                    : _cl.take(10).map((cl) {
                        final name = (cl['name_ar'] ?? cl['name'] ?? '') as String;
                        final sel = _activeClients.contains(name);
                        return PopupMenuItem<String>(
                          value: name,
                          height: 40,
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Text(name, style: TextStyle(color: sel ? AC.gold : AC.tp, fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                            SizedBox(width: 8),
                            Icon(sel ? Icons.check_box : Icons.check_box_outline_blank, color: sel ? AC.gold : AC.ts, size: 18),
                          ]),
                        );
                      }).toList(),
                ).then((v) { if (v != null && v.isNotEmpty) setState(() { if (_activeClients.contains(v)) _activeClients.remove(v); else _activeClients.add(v); }); });
              },
            )),

            Builder(key: _notifKey, builder: (notifCtx) => ApexIconButton(
              icon: Icons.notifications_outlined,
              tooltip: 'الإشعارات والتنبيهات',
              showBadge: _notifs.any((n) => n['is_read'] != true),
              badgeColor: AC.gold,
              onPressed: () {
                final RenderBox btn = notifCtx.findRenderObject() as RenderBox;
                final Offset pos = btn.localToGlobal(Offset.zero);
                final Size sz = btn.size;
                showMenu<String>(
                  context: context,
                  color: AC.navy2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AC.gold, width: 0.5)),
                  position: RelativeRect.fromLTRB(pos.dx, pos.dy + sz.height, MediaQuery.of(context).size.width - pos.dx - 300, 0),
                  items: _notifs.isEmpty
                    ? [PopupMenuItem<String>(value: '', enabled: false, child: Text('\u0644\u0627 \u062a\u0648\u062c\u062f \u0625\u0634\u0639\u0627\u0631\u0627\u062a', style: TextStyle(color: AC.ts, fontSize: 12)))]
                    : [
                      ..._notifs.take(8).map((n) {
                        final unread = n['is_read'] != true;
                        final title = (n['title'] ?? n['message'] ?? '') as String;
                        return PopupMenuItem<String>(
                          value: n['id']?.toString() ?? '',
                          height: 44,
                          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Expanded(child: Text(title, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: TextStyle(color: unread ? AC.gold : AC.tp, fontSize: 11, fontWeight: unread ? FontWeight.bold : FontWeight.normal))),
                            SizedBox(width: 8),
                            Icon(unread ? Icons.circle : Icons.circle_outlined, color: unread ? AC.gold : AC.ts, size: 8),
                          ]),
                        );
                      }),
                      PopupMenuItem<String>(value: 'all', height: 36, child: Center(child: Text('\u0639\u0631\u0636 \u0627\u0644\u0643\u0644', style: TextStyle(color: AC.gold, fontSize: 11, fontWeight: FontWeight.bold)))),
                    ],
                ).then((v) { if (v == 'all') context.go('/notifications'); });
              },
            )),
            ])),
            _appBarDivider(),
            _buildThemePicker(),
            _buildLangToggle(),
            Spacer(),
            MouseRegion(
              onEnter: (_) => setState(() => _hovUserSection = 1),
              onExit: (_) => setState(() => _hovUserSection = 0),
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => context.push('/settings'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _hovUserSection == 1 ? AC.gold.withValues(alpha: 0.06) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _hovUserSection == 1 ? AC.gold.withValues(alpha: 0.15) : Colors.transparent,
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(S.dname?.isNotEmpty == true ? S.dname! : (S.uname ?? 'User'),
                        style: TextStyle(color: _hovUserSection == 1 ? AC.gold : AC.tp.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w500, letterSpacing: 0.2)),
                      SizedBox(height: 2),
                      Text(_activeClients.isEmpty ? _clientLabel : _activeClients.join(' , '),
                        style: TextStyle(color: AC.ts.withValues(alpha: 0.7), fontSize: 10)),
                    ]),
                    SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: AC.gold.withValues(alpha: _hovUserSection == 1 ? 0.15 : 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: Text(
                        (S.dname?.isNotEmpty == true ? S.dname! : (S.uname ?? 'U'))[0].toUpperCase(),
                        style: TextStyle(color: AC.gold, fontSize: 14, fontWeight: FontWeight.bold),
                      )),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
        Expanded(child: Stack(children: [
          Row(children: [
            Expanded(child: tabs[_i]),
            if (_dr) MouseRegion(onExit: (_) => setState(() => _dr = false),
              child: SizedBox(width: 260,
                child: ClipRRect(
                  child: Container(
                  decoration: BoxDecoration(
                    color: AC.navy2.withValues(alpha: 0.92),
                    border: Border(left: BorderSide(color: AC.bdr.withValues(alpha: 0.3))),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: Offset(-4, 0))],
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Material(color: Colors.transparent,
                child: Column(children: [

                  Expanded(child: ListView(padding: EdgeInsets.zero, children: [
        ExpansionTile(
          trailing: Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: EdgeInsets.symmetric(horizontal: 16),
          title: Text('الأساسي', textAlign: TextAlign.right, style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          initiallyExpanded: true,
          children: [
          _drawerItem(Icons.dashboard_rounded, 'الرئيسية', () { setState(() { _i = 0; _dr = false; }); }, isActive: _i == 0),
          _drawerItem(Icons.smart_toy, 'Apex Copilot', () { context.push('/copilot'); setState(() => _dr = false); }, isGold: true),
          _drawerItem(Icons.apartment_rounded, 'الشركات', () { setState(() { _i = 1; _dr = false; }); }, isActive: _i == 1),
          ],
        ),
        ExpansionTile(
          trailing: Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: EdgeInsets.symmetric(horizontal: 16),
          title: Text('المسار المالي', textAlign: TextAlign.right, style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          initiallyExpanded: true,
          children: [
          _drawerItem(Icons.account_tree, 'شجرة الحسابات COA', () => _goToCoa(), isGold: true),
          _drawerItem(Icons.table_chart, 'ميزان المراجعة TB', () { context.push('/financial-ops'); setState(() => _dr = false); }),
          _drawerItem(Icons.receipt_long, 'القوائم المالية', () { context.push('/financial-ops'); setState(() => _dr = false); }),
          _drawerItem(Icons.analytics_rounded, 'التحليل المالي', () { setState(() { _i = 2; _dr = false; }); }, isActive: _i == 2),
          ],
        ),
        ExpansionTile(
          trailing: Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: EdgeInsets.symmetric(horizontal: 16),
          title: Text('الجاهزية والامتثال', textAlign: TextAlign.right, style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          children: [
          _drawerItem(Icons.shield_rounded, 'الجاهزية التمويلية', () { _comingSoon(); }),
          _drawerItem(Icons.checklist_rounded, 'الامتثال', () { _comingSoon(); }),
          _drawerItem(Icons.workspace_premium, 'الأهلية الترخيصية', () { _comingSoon(); }),
          _drawerItem(Icons.volunteer_activism, 'الدعم والحوافز', () { _comingSoon(); }),
          _drawerItem(Icons.gavel_rounded, 'المراجعة المحاسبية والقانونية', () { context.push('/audit-workflow'); setState(() => _dr = false); }),
          ],
        ),
        // ── الذكاء الاصطناعي — new AI surfaces ──
        ExpansionTile(
          trailing: Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: EdgeInsets.symmetric(horizontal: 16),
          initiallyExpanded: true,
          title: Text('الذكاء الاصطناعي', textAlign: TextAlign.right, style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          children: [
          _drawerItem(Icons.auto_awesome, 'اسأل أبكس', () { openApexAskPanel(context); setState(() => _dr = false); }, isGold: true),
          _drawerItem(Icons.hub_outlined, 'مركز الذكاء الاصطناعي', () { context.push('/admin/ai-console'); setState(() => _dr = false); }),
          _drawerItem(Icons.inbox_outlined, 'صندوق الاقتراحات', () { context.push('/admin/ai-suggestions'); setState(() => _dr = false); }),
          _drawerItem(Icons.event_note_outlined, 'التقويم الضريبي', () { context.push('/compliance/tax-timeline'); setState(() => _dr = false); }),
          ],
        ),
        ExpansionTile(
          trailing: Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: EdgeInsets.symmetric(horizontal: 16),
          title: Text('السوق', textAlign: TextAlign.right, style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          children: [
          _drawerItem(Icons.store_rounded, 'سوق الخدمات', () { setState(() { _i = 3; _dr = false; }); }, isActive: _i == 3),
          _drawerItem(Icons.work_rounded, 'مقدمو الخدمات', () { context.push('/provider-kanban'); setState(() => _dr = false); }),
          _drawerItem(Icons.menu_book, 'Bookkeeping', () { _comingSoon(); }),
          ],
        ),
        ExpansionTile(
          trailing: Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: EdgeInsets.symmetric(horizontal: 16),
          title: Text('التقارير والمعرفة', textAlign: TextAlign.right, style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          children: [
          _drawerItem(Icons.bar_chart_rounded, 'التقارير', () { _comingSoon(); }),
          _drawerItem(Icons.folder_outlined, 'الأرشيف', () { context.go('/archive'); setState(() => _dr = false); }),
          _drawerItem(Icons.psychology, 'العقل المعرفي', () { context.push('/knowledge-brain'); setState(() => _dr = false); }),
          _drawerItem(Icons.admin_panel_settings, 'Reviewer Console', () { context.go('/admin/reviewer'); setState(() => _dr = false); }),
          ],
        ),
        ExpansionTile(
          trailing: Icon(Icons.expand_more, color: AC.ts, size: 18),
          tilePadding: EdgeInsets.symmetric(horizontal: 16),
          title: Text('الإدارة', textAlign: TextAlign.right, style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.w700)),
          children: [
          _drawerItem(Icons.settings, 'الإدارة والإعدادات', () { context.push('/settings'); setState(() => _dr = false); }),
          _drawerItem(Icons.diamond_outlined, 'الحساب والاشتراكات', () { setState(() { _i = 5; _dr = false; }); }, isActive: _i == 5),
          ],
        ),
                  ])),
                ]),
              ),
            )),
          ))),
            if (!_dr) MouseRegion(onEnter: (_) => setState(() => _dr = true),
              child: Container(width: 8, color: Colors.transparent)),
          ]),
          if (_dr) Positioned(left: 0, top: 0, bottom: 0, right: 260,
            child: GestureDetector(onTap: () => setState(() => _dr = false), behavior: HitTestBehavior.translucent, child: const SizedBox.expand())),
          Positioned(right: _fabX, bottom: _fabY,
            child: GestureDetector(
              onPanUpdate: (d) => setState(() { _fabX = (_fabX - d.delta.dx).clamp(0, 300); _fabY = (_fabY - d.delta.dy).clamp(0, 600); }),
              child: ApexGlowFAB(
                icon: Icons.smart_toy,
                tooltip: 'Apex Copilot — المساعد الذكي',
                onPressed: () => context.go('/copilot'),
              ),
            ),
          ),
        ])),
      ]),
    );
  }




  /// Smart COA navigation — checks top-bar client selection (v6.7)
  void _goToCoa() {
    setState(() => _dr = false);
    if (_activeClients.isEmpty) {
      _showCoaDialog(
        '\u062a\u062d\u062f\u064a\u062f \u0639\u0645\u064a\u0644',
        '\u0628\u0631\u062c\u0627\u0621 \u062a\u062d\u062f\u064a\u062f \u0639\u0645\u064a\u0644 \u0645\u0646 \u0627\u0644\u0642\u0627\u0626\u0645\u0629 \u0627\u0644\u0639\u0644\u0648\u064a\u0629 \u0623\u0648\u0644\u0627\u064b',
        Icons.person_search,
      );
      return;
    }
    if (_activeClients.length > 1) {
      _showCoaDialog(
        '\u062a\u062d\u062f\u064a\u062f \u0639\u0645\u064a\u0644 \u0648\u0627\u062d\u062f',
        '\u0628\u0631\u062c\u0627\u0621 \u062a\u062d\u062f\u064a\u062f \u0639\u0645\u064a\u0644 \u0648\u0627\u062d\u062f \u0641\u0642\u0637 \u0644\u0641\u062a\u062d \u0634\u062c\u0631\u0629 \u0627\u0644\u062d\u0633\u0627\u0628\u0627\u062a',
        Icons.warning_amber_rounded,
      );
      return;
    }
    final selectedName = _activeClients.first;
    final client = _cl.firstWhere(
      (c) => (c['name_ar'] ?? c['name'] ?? '') == selectedName,
      orElse: () => null,
    );
    if (client != null) {
      context.push('/coa/journey', extra: {
        'clientId': (client['id'] ?? client['client_code'] ?? '1').toString(),
        'clientName': client['name_ar'] ?? client['name'] ?? '',
      });
    } else {
      _showCoaDialog(
        '\u062e\u0637\u0623',
        '\u0644\u0645 \u064a\u062a\u0645 \u0627\u0644\u0639\u062b\u0648\u0631 \u0639\u0644\u0649 \u0628\u064a\u0627\u0646\u0627\u062a \u0627\u0644\u0639\u0645\u064a\u0644',
        Icons.error_outline,
      );
    }
  }

  void _showCoaDialog(String title, String message, IconData icon) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AC.navy3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AC.bdr, width: 1),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: AC.gold, size: 48),
            SizedBox(height: 16),
            Text(title, style: TextStyle(color: AC.gold, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: AC.tp, fontSize: 14, height: 1.5)),
            SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AC.gold,
                foregroundColor: AC.navy,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('\u062d\u0633\u0646\u0627\u064b', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
        ),
      ),
    );
  }


  Widget _appBarDivider() => Container(
    width: 1, height: 20,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [AC.bdr.withValues(alpha: 0.0), AC.bdr.withValues(alpha: 0.4), AC.bdr.withValues(alpha: 0.0)],
      ),
    ),
  );

  int _hovUserSection = 0;

  void _comingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('قريبًا — هذه الخدمة قيد التطوير'),
        backgroundColor: AC.navy2, duration: Duration(seconds: 2)));
    setState(() => _dr = false);
  }

  int _drawerItemCounter = 0;
  Widget _drawerItem(IconData icon, String label, VoidCallback onTap, {bool isGold = false, bool isActive = false}) {
    final idx = _drawerItemCounter++;
    final hovered = _hoveredDrawerIndex == idx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) { setState(() => _hoveredDrawerIndex = idx); },
        onExit: (_) { setState(() => _hoveredDrawerIndex = -1); },
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            transform: hovered ? (Matrix4.identity()..translate(-2.0, 0.0)) : Matrix4.identity(),
            decoration: BoxDecoration(
              color: isActive
                  ? AC.gold.withValues(alpha: 0.10)
                  : hovered
                      ? AC.gold.withValues(alpha: 0.06)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AC.gold.withValues(alpha: 0.25)
                    : hovered
                        ? AC.gold.withValues(alpha: 0.12)
                        : Colors.transparent,
              ),
              boxShadow: hovered ? [
                BoxShadow(color: AC.gold.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(-2, 0)),
              ] : null,
            ),
            child: Row(children: [
              // Active indicator bar
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3, height: 20,
                decoration: BoxDecoration(
                  color: isActive ? AC.gold : (hovered ? AC.gold.withValues(alpha: 0.4) : Colors.transparent),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(label, textAlign: TextAlign.right, style: TextStyle(
                color: isGold || isActive ? AC.gold : (hovered ? AC.goldLight : AC.tp),
                fontSize: 13,
                fontWeight: isGold || isActive || hovered ? FontWeight.w600 : FontWeight.normal,
              ))),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: (isGold || isActive || hovered) ? AC.gold.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: hovered ? [
                    BoxShadow(color: AC.gold.withValues(alpha: 0.10), blurRadius: 6),
                  ] : null,
                ),
                child: AnimatedScale(
                  scale: hovered ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AnimatedRotation(
                    turns: hovered ? -0.02 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: Icon(icon, color: isGold || isActive ? AC.gold : (hovered ? AC.goldLight : AC.ts), size: 18),
                  ),
                ),
              ),
              // Arrow slides + fades on hover
              AnimatedSlide(
                offset: Offset(0, hovered ? 0.0 : 0.3),
                duration: const Duration(milliseconds: 200),
                child: AnimatedOpacity(
                  opacity: hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.chevron_right, color: AC.gold.withValues(alpha: 0.5), size: 14),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Theme Picker ──
  final _themeKey = GlobalKey();
  String? _previewThemeId; // for hover preview — null means no preview active
  String? _savedThemeId;   // original theme to restore on hover exit

  Widget _buildThemePicker() {
    final currentId = ref.watch(appSettingsProvider).themeId;
    final isDark = currentId.endsWith('_dark');
    final currentFamily = themeFamilyOf(currentId);
    final isAr = ref.watch(appSettingsProvider).language == 'ar';
    return ApexIconButton(
      key: _themeKey,
      icon: Icons.palette_outlined,
      size: 20,
      tooltip: isAr ? 'تغيير السمة' : 'Change Theme',
      onPressed: () {
        final RenderBox btn = _themeKey.currentContext!.findRenderObject() as RenderBox;
        final Offset pos = btn.localToGlobal(Offset.zero);
        final Size sz = btn.size;
        _savedThemeId = currentId;

        showDialog(
          context: context,
          barrierColor: Colors.transparent,
          builder: (ctx) => Stack(children: [
            // Dismiss layer
            Positioned.fill(child: GestureDetector(onTap: () {
              // Restore original theme on dismiss
              if (_savedThemeId != null) {
                ref.read(appSettingsProvider.notifier).setTheme(_savedThemeId!);
              }
              _previewThemeId = null;
              _savedThemeId = null;
              Navigator.of(ctx).pop();
            })),
            // Picker overlay
            Positioned(
              left: pos.dx - 100,
              top: pos.dy + sz.height + 6,
              child: Material(
                color: Colors.transparent,
                child: StatefulBuilder(builder: (ctx2, setLocal) {
                  return MouseRegion(
                    onExit: (_) {
                      // Restore when leaving the entire picker
                      if (_savedThemeId != null && _previewThemeId != null) {
                        ref.read(appSettingsProvider.notifier).setTheme(_savedThemeId!);
                        _previewThemeId = null;
                        if (mounted) setState(() {});
                      }
                    },
                    child: Container(
                      width: 240,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AC.navy2,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AC.gold.withValues(alpha: 0.25)),
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8)),
                          BoxShadow(color: AC.gold.withValues(alpha: 0.06), blurRadius: 40),
                        ],
                      ),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        // ── Dark / Light Toggle ──
                        GestureDetector(
                          onTap: () {
                            ref.read(appSettingsProvider.notifier).toggleDarkMode(!isDark);
                            _savedThemeId = ref.read(appSettingsProvider).themeId;
                            Navigator.of(ctx).pop();
                            _previewThemeId = null;
                            _savedThemeId = null;
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AC.navy3,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.light_mode_rounded, color: !isDark ? AC.gold : AC.td, size: 18),
                              const SizedBox(width: 8),
                              Text(isAr ? 'فاتح' : 'Light',
                                style: TextStyle(color: !isDark ? AC.gold : AC.td, fontSize: 12, fontWeight: !isDark ? FontWeight.bold : FontWeight.normal)),
                              const SizedBox(width: 12),
                              Container(
                                width: 40, height: 22,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: isDark ? AC.gold.withValues(alpha: 0.25) : AC.navy4,
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 200),
                                  alignment: isDark ? Alignment.centerLeft : Alignment.centerRight,
                                  child: Container(
                                    width: 18, height: 18, margin: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDark ? AC.gold : AC.ts,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.dark_mode_rounded, color: isDark ? AC.gold : AC.td, size: 18),
                              const SizedBox(width: 8),
                              Text(isAr ? 'داكن' : 'Dark',
                                style: TextStyle(color: isDark ? AC.gold : AC.td, fontSize: 12, fontWeight: isDark ? FontWeight.bold : FontWeight.normal)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Divider(color: AC.bdr, height: 1),
                        const SizedBox(height: 6),
                        // ── 4 Theme Families with hover preview ──
                        ...apexThemeFamilies.map((f) {
                          final isSelected = currentFamily == f.id && _previewThemeId == null;
                          final isPreviewing = _previewThemeId != null && themeFamilyOf(_previewThemeId!) == f.id;
                          return MouseRegion(
                            onEnter: (_) {
                              // Live preview: apply this family's theme temporarily
                              final previewId = themeIdFor(f.id, isDark);
                              _previewThemeId = previewId;
                              ref.read(appSettingsProvider.notifier).setTheme(previewId);
                              setLocal(() {});
                              if (mounted) setState(() {});
                            },
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () {
                                // Confirm this theme
                                ref.read(appSettingsProvider.notifier).setThemeFamily(f.id);
                                _previewThemeId = null;
                                _savedThemeId = null;
                                Navigator.of(ctx).pop();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                margin: const EdgeInsets.symmetric(vertical: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: (isSelected || isPreviewing) ? f.preview.withValues(alpha: 0.12) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (isSelected || isPreviewing) ? f.preview.withValues(alpha: 0.5) : Colors.transparent,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                                  if (isSelected) Icon(Icons.check_circle_rounded, color: f.preview, size: 16),
                                  if (isSelected) const SizedBox(width: 8),
                                  Expanded(child: Text(isAr ? f.nameAr : f.nameEn,
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      color: (isSelected || isPreviewing) ? f.preview : AC.tp, fontSize: 13,
                                      fontWeight: (isSelected || isPreviewing) ? FontWeight.bold : FontWeight.w500))),
                                  const SizedBox(width: 10),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: isPreviewing ? 26 : 22, height: isPreviewing ? 26 : 22,
                                    decoration: BoxDecoration(
                                      color: f.preview, shape: BoxShape.circle,
                                      border: Border.all(color: (isSelected || isPreviewing) ? f.preview : AC.ts.withValues(alpha: 0.5), width: (isSelected || isPreviewing) ? 2.5 : 1.5),
                                      boxShadow: (isSelected || isPreviewing) ? [BoxShadow(color: f.preview.withValues(alpha: 0.5), blurRadius: 12)] : null,
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          );
                        }),
                      ]),
                    ),
                  );
                }),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── Language Toggle ──
  Widget _buildLangToggle() {
    final isAr = ref.watch(appSettingsProvider).language == 'ar';
    return _AppBarPill(
      label: isAr ? 'EN' : 'ع',
      onTap: () => ref.read(appSettingsProvider.notifier).setLanguage(isAr ? 'en' : 'ar'),
      tooltip: isAr ? 'Switch to English' : 'التبديل للعربية',
    );
  }
}

class _AppBarPill extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final String? tooltip;
  const _AppBarPill({required this.label, required this.onTap, this.tooltip});
  @override
  State<_AppBarPill> createState() => _AppBarPillState();
}

class _AppBarPillState extends State<_AppBarPill> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final pill = MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          transform: _hov ? (Matrix4.identity()..scale(1.08)) : Matrix4.identity(),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hov ? AC.gold.withValues(alpha: 0.18) : AC.gold.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hov ? AC.gold.withValues(alpha: 0.5) : AC.gold.withValues(alpha: 0.25)),
            boxShadow: _hov ? [BoxShadow(color: AC.gold.withValues(alpha: 0.12), blurRadius: 8)] : null,
          ),
          child: Text(widget.label, style: TextStyle(
            color: AC.gold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          )),
        ),
      ),
    );
    if (widget.tooltip != null) return Tooltip(message: widget.tooltip!, preferBelow: false, child: pill);
    return pill;
  }
}
