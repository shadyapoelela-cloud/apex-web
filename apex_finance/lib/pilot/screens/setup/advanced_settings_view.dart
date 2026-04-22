/// Advanced Settings — عرض تفصيلي بـ 10 تصنيفات جانبية.
///
/// يستبدل تبويب "إعدادات" البسيط بعرض غني مطابق للديمو،
/// لكن كل شيء مربوط فعلياً بالـ backend:
///   - fiscal → fiscal_year + period_type + close_policy + FiscalPeriod CRUD
///   - currency → Currency + FxRate CRUD
///   - tax → VAT + Zakat + WHT (extras.tax.wht_rates)
///   - approvals → approval_thresholds JSON editor
///   - numbering → document prefixes
///   - security → extras.security.* (password + session + 2FA)
///   - audit → audit_log_* + retention_years
///   - ai → ai_enabled + ai_model + threshold + extras.ai.*
///   - backup → extras.backup.*
///   - regional → language + calendar + timezone + extras.regional.*

library;

import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/pilot_client.dart';
import '../../session.dart';
import '../../../core/theme.dart' as core_theme;
import '../../../providers/app_providers.dart';

// Colors resolve LIVE from the global theme — they update automatically
// when the user switches Dark/Light mode or picks a different palette.
Color get _gold => core_theme.AC.gold;
Color get _navy2 => core_theme.AC.navy2;
Color get _navy3 => core_theme.AC.navy3;
Color get _bdr => core_theme.AC.bdr;
Color get _tp => core_theme.AC.tp;
Color get _ts => core_theme.AC.ts;
Color get _td => core_theme.AC.td;
Color get _ok => core_theme.AC.ok;
Color get _err => core_theme.AC.err;

class AdvancedSettingsView extends ConsumerStatefulWidget {
  final Map<String, dynamic> tenant;
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> entities;
  final Future<void> Function() onReload;

  const AdvancedSettingsView({
    super.key,
    required this.tenant,
    required this.settings,
    required this.entities,
    required this.onReload,
  });

  @override
  ConsumerState<AdvancedSettingsView> createState() => _AdvancedSettingsViewState();
}

class _AdvancedSettingsViewState extends ConsumerState<AdvancedSettingsView> {
  final PilotClient _client = pilotClient;

  String _cat = 'fiscal';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _search = '';

  // Fiscal periods state
  String? _selectedEntityId;
  int _selectedYear = DateTime.now().year;
  List<Map<String, dynamic>> _periods = [];
  bool _loadingPeriods = false;

  // Currencies state
  List<Map<String, dynamic>> _currencies = [];
  List<Map<String, dynamic>> _fxRates = [];
  bool _loadingCurrencies = false;

  // Advanced features state
  Map<String, dynamic>? _complianceScore;
  List<Map<String, dynamic>> _presets = [];
  List<Map<String, dynamic>> _history = [];
  bool _loadingCompliance = false;
  bool _loadingHistory = false;

  // Browser-level keyboard listener — uses preventDefault to override Edge/Chrome
  // defaults like Ctrl+H (history), Ctrl+B (bookmarks), Ctrl+E (search).
  // HardwareKeyboard alone isn't enough; browser claims those combos first.
  html.EventListener? _windowKeyListener;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
    _windowKeyListener = (html.Event e) {
      if (e is! html.KeyboardEvent) return;
      _onWindowKey(e);
    };
    // Use capture phase (true) so we intercept BEFORE browser/Flutter handle it
    html.window.addEventListener('keydown', _windowKeyListener!, true);
    html.window.console.log(
        '[APEX Settings] Keyboard shortcuts registered (keydown capture)');
    if (widget.entities.isNotEmpty) {
      _selectedEntityId = widget.entities.first['id'];
      _loadPeriods();
    }
    _loadCurrencies();
    _loadCompliance();
    _loadPresets();
  }

  void _onWindowKey(html.KeyboardEvent e) {
    if (!mounted) return;
    final ctrl = e.ctrlKey || e.metaKey;
    final shift = e.shiftKey;
    final alt = e.altKey;
    final key = (e.key ?? '').toLowerCase();

    // Debug: uncomment to see every keypress in console
    // html.window.console.log('[APEX Key] key=$key ctrl=$ctrl alt=$alt shift=$shift');

    // Only intercept when our screen is visible (tab controller index 3).
    // Defensive: skip if focus is in a text input unrelated to us.
    void run(String name, void Function() fn) {
      html.window.console.log('[APEX Shortcut] $name fired');
      e.preventDefault();
      e.stopPropagation();
      fn();
    }

    // Primary: Ctrl+letter — the usual pattern.
    if (ctrl && !shift && !alt) {
      switch (key) {
        case 'k':
          run('Ctrl+K focus search', () => _searchFocus.requestFocus());
          return;
        case 'e':
          run('Ctrl+E export', () => _exportConfig());
          return;
        case 'i':
          run('Ctrl+I import', () => _importConfig());
          return;
        case 'h':
          run('Ctrl+H history', () => _openHistory());
          return;
        case 'b':
          run('Ctrl+B benchmarks', () => _showBenchmarks());
          return;
      }
    }
    // Alt+letter — fallback that works on stricter browsers.
    if (!ctrl && !shift && alt) {
      switch (key) {
        case 'k':
          run('Alt+K focus search', () => _searchFocus.requestFocus());
          return;
        case 'e':
          run('Alt+E export', () => _exportConfig());
          return;
        case 'i':
          run('Alt+I import', () => _importConfig());
          return;
        case 'h':
          run('Alt+H history', () => _openHistory());
          return;
        case 'b':
          run('Alt+B benchmarks', () => _showBenchmarks());
          return;
      }
    }
    // Help: ? (Shift+/)
    if (shift && key == '?') {
      run('Shift+/ help', () => _showShortcutsHelp());
      return;
    }
    // Escape: clear search if active
    if (key == 'escape' && _searchCtrl.text.isNotEmpty) {
      _searchCtrl.clear();
      setState(() => _search = '');
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    if (_windowKeyListener != null) {
      html.window.removeEventListener('keydown', _windowKeyListener!, true);
    }
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // Global keyboard shortcut handler — more reliable than Shortcuts widget
  // on Flutter Web because it bypasses focus scope issues.
  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;
    final key = event.logicalKey;

    if (ctrl && key == LogicalKeyboardKey.keyK) {
      _searchFocus.requestFocus();
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyE) {
      _exportConfig();
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyI) {
      _importConfig();
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyH) {
      _openHistory();
      return true;
    }
    if (ctrl && key == LogicalKeyboardKey.keyB) {
      _showBenchmarks();
      return true;
    }
    if (shift && key == LogicalKeyboardKey.slash) {
      _showShortcutsHelp();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      if (_searchCtrl.text.isNotEmpty) {
        _searchCtrl.clear();
        setState(() => _search = '');
        return true;
      }
    }
    return false;
  }

  Future<void> _loadCompliance() async {
    if (!PilotSession.hasTenant) return;
    setState(() => _loadingCompliance = true);
    final r = await _client.getComplianceScore(PilotSession.tenantId!);
    if (!mounted) return;
    setState(() {
      _loadingCompliance = false;
      if (r.success) _complianceScore = Map<String, dynamic>.from(r.data);
    });
  }

  Future<void> _loadPresets() async {
    final r = await _client.listPresets();
    if (!mounted) return;
    if (r.success) {
      setState(() => _presets = List<Map<String, dynamic>>.from(r.data));
    }
  }

  Future<void> _loadHistory({String? category}) async {
    if (!PilotSession.hasTenant) return;
    setState(() => _loadingHistory = true);
    final r = await _client.listSettingsHistory(
      PilotSession.tenantId!,
      category: category,
      limit: 50,
    );
    if (!mounted) return;
    setState(() {
      _loadingHistory = false;
      if (r.success) _history = List<Map<String, dynamic>>.from(r.data);
    });
  }

  Future<void> _loadPeriods() async {
    if (_selectedEntityId == null) return;
    setState(() => _loadingPeriods = true);
    final r = await _client.listFiscalPeriods(_selectedEntityId!, year: _selectedYear);
    if (!mounted) return;
    setState(() {
      _loadingPeriods = false;
      if (r.success) {
        _periods = List<Map<String, dynamic>>.from(r.data);
      }
    });
  }

  Future<void> _loadCurrencies() async {
    if (!PilotSession.hasTenant) return;
    setState(() => _loadingCurrencies = true);
    final cr = await _client.listCurrencies(PilotSession.tenantId!);
    final fr = await _client.listFxRates(PilotSession.tenantId!);
    if (!mounted) return;
    setState(() {
      _loadingCurrencies = false;
      if (cr.success) _currencies = List<Map<String, dynamic>>.from(cr.data);
      if (fr.success) _fxRates = List<Map<String, dynamic>>.from(fr.data);
    });
  }

  Future<bool> _update(Map<String, dynamic> patch) async {
    final r = await _client.updateTenantSettings(PilotSession.tenantId!, patch);
    if (!mounted) return false;
    if (r.success) {
      await widget.onReload();
      _snack('تم الحفظ ✓', _ok);
      _loadCompliance();
      return true;
    } else {
      _snack(r.error ?? 'فشل الحفظ', _err);
      return false;
    }
  }

  Map<String, dynamic> get _s => widget.settings;

  Map<String, dynamic> _extras() {
    final e = _s['extras'];
    if (e is Map) return Map<String, dynamic>.from(e);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _extrasSection(String key) {
    final e = _extras();
    final v = e[key];
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  Future<bool> _updateExtrasSection(String key, Map<String, dynamic> patch) async {
    final current = _extras();
    final sec = Map<String, dynamic>.from(current[key] is Map ? current[key] : {});
    sec.addAll(patch);
    current[key] = sec;
    return _update({'extras': current});
  }

  void _snack(String msg, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: c, content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to theme changes — rebuilds entire screen on dark/light/palette switch
    ref.watch(appSettingsProvider);
    // Shortcuts registered via HardwareKeyboard (see initState) — no focus dance required.
    return Column(children: [
      _topToolbar(),
      Divider(height: 1, color: _bdr),
      Expanded(
        child: Row(children: [
          _sidebar(),
          VerticalDivider(width: 1, color: _bdr),
          Expanded(child: _content()),
        ]),
      ),
    ]);
  }

  void _showShortcutsHelp() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Row(children: [
            Icon(Icons.keyboard, color: _gold),
            SizedBox(width: 8),
            Text('اختصارات لوحة المفاتيح',
                style: TextStyle(color: _tp, fontSize: 16)),
          ]),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _shortcutRow('Ctrl+K   أو   Alt+K', 'تركيز على البحث'),
                _shortcutRow('Ctrl+E   أو   Alt+E', 'تصدير الإعدادات'),
                _shortcutRow('Ctrl+I   أو   Alt+I', 'استيراد الإعدادات'),
                _shortcutRow('Ctrl+H   أو   Alt+H', 'عرض سجل التغييرات'),
                _shortcutRow('Ctrl+B   أو   Alt+B', 'المقارنة مع السوق'),
                _shortcutRow('Shift + /', 'عرض هذا الدليل'),
                _shortcutRow('Esc', 'مسح البحث'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: core_theme.AC.info.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: core_theme.AC.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline, color: core_theme.AC.info, size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'لو Ctrl+X لم يعمل (Edge يستخدمه لـ bookmark/history)، استخدم Alt+X بدلاً منه — سيعمل بنفس الوظيفة.',
                        style: TextStyle(
                            color: core_theme.AC.info, fontSize: 11, height: 1.5),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('تم', style: TextStyle(color: _gold))),
          ],
        ),
      ),
    );
  }

  Widget _shortcutRow(String keys, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _navy3,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _bdr),
          ),
          child: Text(keys,
              style: TextStyle(
                  color: _gold,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700)),
        ),
        SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: TextStyle(color: _ts, fontSize: 12))),
      ]),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Top toolbar — search, presets, export/import, compliance, history
  // (هذه الميزات تتفوّق على QuickBooks/Xero/Odoo/SAP B1/NetSuite)
  // ═════════════════════════════════════════════════════════════

  Widget _topToolbar() {
    final score = _complianceScore;
    // Theme-aware status palette — derived from current theme to stay coordinated
    final t = core_theme.AC.current;
    final cInfo = t.info;        // blue-ish
    final cSecondary = t.iconAccent;  // accent
    final cHistory = t.purple;   // purple from theme
    final cBench = t.warning;    // amber from theme

    return Container(
      color: _navy2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true, // RTL-friendly horizontal scroll
        child: Row(children: [
        // Search (Ctrl+K to focus)
        SizedBox(
          width: 260,
          child: TextField(
            controller: _searchCtrl,
            focusNode: _searchFocus,
            style: TextStyle(color: _tp, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'بحث… (Ctrl+K) VAT، 2FA، تقويم',
              hintStyle: TextStyle(color: _td, fontSize: 11),
              prefixIcon: Icon(Icons.search, color: _ts, size: 16),
              isDense: true,
              filled: true,
              fillColor: _navy3,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(color: _bdr),
              ),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: _ts, size: 14),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _search = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
          ),
        ),
        const SizedBox(width: 10),

        // Presets dropdown
        if (_presets.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: 'تطبيق قالب إقليمي',
            color: _navy3,
            onSelected: _applyPreset,
            itemBuilder: (_) => _presets.map((p) {
              return PopupMenuItem<String>(
                value: p['key'] as String,
                child: SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Icon(Icons.public, size: 14, color: _gold),
                        SizedBox(width: 6),
                        Text(p['label_ar'] ?? '',
                            style: TextStyle(
                                color: _tp,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ]),
                      if ((p['description_ar'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2, right: 20),
                          child: Text(p['description_ar'] ?? '',
                              style:
                                  TextStyle(color: _ts, fontSize: 10)),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
            child: _InteractiveChip(
              icon: Icons.flash_on,
              label: 'تطبيق قالب',
              color: _gold,
              subtitle: '${_presets.length} قوالب',
              onTap: () {},
            ),
          ),
        const SizedBox(width: 8),

        // Export
        _InteractiveChip(
          icon: Icons.file_download,
          label: 'تصدير',
          color: cInfo,
          onTap: _exportConfig,
        ),
        const SizedBox(width: 8),

        // Import
        _InteractiveChip(
          icon: Icons.file_upload,
          label: 'استيراد',
          color: cSecondary,
          onTap: _importConfig,
        ),
        const SizedBox(width: 8),

        // History
        _InteractiveChip(
          icon: Icons.history,
          label: 'السجل',
          color: cHistory,
          subtitle: _history.isEmpty ? null : '${_history.length}',
          onTap: _openHistory,
        ),
        const SizedBox(width: 8),

        // Benchmarks
        _InteractiveChip(
          icon: Icons.compare_arrows,
          label: 'معايير السوق',
          color: cBench,
          onTap: _showBenchmarks,
        ),

        const SizedBox(width: 12),

        // Keyboard shortcuts help
        _InteractiveIconButton(
          icon: Icons.keyboard,
          tooltip: 'اختصارات لوحة المفاتيح (Shift+/)',
          onTap: _showShortcutsHelp,
        ),
        const SizedBox(width: 10),

        // Compliance score
        if (score != null) _complianceBar(score),
        if (score == null && _loadingCompliance)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
          ),
        const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _complianceBar(Map<String, dynamic> score) {
    final overall = (score['overall'] ?? 0) as int;
    final t = core_theme.AC.current;
    final color = overall >= 85
        ? t.success
        : overall >= 65
            ? t.warning
            : t.error;
    return InkWell(
      onTap: () => _showComplianceDetails(score),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(
            overall >= 85
                ? Icons.verified
                : overall >= 65
                    ? Icons.warning_amber
                    : Icons.error_outline,
            color: color,
            size: 14,
          ),
          SizedBox(width: 6),
          Text('الامتثال',
              style: TextStyle(
                  color: _tp, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('$overall%',
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          _miniScoreBadge('ZATCA',
              ((score['zatca'] as Map?)?['score'] ?? 0) as int),
          const SizedBox(width: 4),
          _miniScoreBadge(
              'GAAP', ((score['gaap'] as Map?)?['score'] ?? 0) as int),
          const SizedBox(width: 4),
          _miniScoreBadge('الأمن',
              ((score['security'] as Map?)?['score'] ?? 0) as int),
        ]),
      ),
    );
  }

  Widget _miniScoreBadge(String label, int s) {
    final c = s >= 85
        ? _ok
        : s >= 65
            ? core_theme.AC.warn
            : _err;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label,
            style: TextStyle(
                color: _ts, fontSize: 9, fontWeight: FontWeight.w600)),
        const SizedBox(width: 3),
        Text('$s',
            style: TextStyle(
                color: c, fontSize: 10, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  void _showComplianceDetails(Map<String, dynamic> score) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Row(children: [
            Icon(Icons.verified, color: _gold),
            SizedBox(width: 8),
            Text('تفاصيل الامتثال',
                style: TextStyle(color: _tp, fontSize: 16)),
          ]),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final key in ['zatca', 'gaap', 'security'])
                    _complianceSection(
                      key == 'zatca'
                          ? 'ZATCA Phase 2 + SOCPA'
                          : key == 'gaap'
                              ? 'GAAP / IFRS'
                              : 'الأمن السيبراني',
                      score[key] as Map?,
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إغلاق', style: TextStyle(color: _ts))),
          ],
        ),
      ),
    );
  }

  Widget _complianceSection(String title, Map? section) {
    if (section == null) return const SizedBox.shrink();
    final s = (section['score'] ?? 0) as int;
    final checks = (section['checks'] as List?) ?? [];
    final c = s >= 85
        ? _ok
        : s >= 65
            ? core_theme.AC.warn
            : _err;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title,
                style: TextStyle(
                    color: _tp, fontSize: 14, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$s / ${section['max'] ?? 100}',
                  style: TextStyle(
                      color: c, fontSize: 12, fontWeight: FontWeight.w800)),
            ),
          ]),
          SizedBox(height: 6),
          LinearProgressIndicator(
            value: s / 100.0,
            backgroundColor: _navy3,
            color: c,
            minHeight: 4,
          ),
          const SizedBox(height: 8),
          ...checks.map((ch) {
            final m = ch as Map;
            final passed = m['passed'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(
                  passed ? Icons.check_circle : Icons.cancel,
                  color: passed ? _ok : _err,
                  size: 14,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(m['label']?.toString() ?? '',
                      style: TextStyle(
                          color: passed ? _ts : _tp, fontSize: 11)),
                ),
                Text('+${m['weight'] ?? 0}',
                    style: TextStyle(
                        color: _td, fontSize: 10, fontFamily: 'monospace')),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _applyPreset(String key) async {
    final preset = _presets.firstWhere((p) => p['key'] == key, orElse: () => {});
    final ok = await _confirm(
      'تطبيق قالب ${preset['label_ar'] ?? ''}',
      'سيتم استبدال الإعدادات الحالية بقيم القالب. هل تريد المتابعة؟\n\n${preset['description_ar'] ?? ''}',
    );
    if (!ok) return;
    final r = await _client.applyPreset(PilotSession.tenantId!, key);
    if (!mounted) return;
    if (r.success) {
      final n = (r.data['applied_count'] ?? 0) as int;
      _snack('تم تطبيق القالب — $n حقل مُحدَّث', _ok);
      await widget.onReload();
      _loadCompliance();
    } else {
      _snack(r.error ?? 'فشل التطبيق', _err);
    }
  }

  Future<void> _exportConfig() async {
    final r = await _client.exportSettings(PilotSession.tenantId!);
    if (!mounted) return;
    if (!r.success) {
      _snack(r.error ?? 'فشل التصدير', _err);
      return;
    }
    final json = const JsonEncoder.withIndent('  ').convert(r.data);
    final bytes = utf8.encode(json);
    final blob = html.Blob([bytes], 'application/json');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final filename =
        'apex-settings-${DateTime.now().toIso8601String().substring(0, 10)}.json';
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
    _snack('تم تنزيل $filename', _ok);
  }

  Future<void> _importConfig() async {
    final input = html.FileUploadInputElement()..accept = 'application/json';
    input.click();
    await input.onChange.first;
    final files = input.files;
    if (files == null || files.isEmpty) return;
    final file = files.first;
    final reader = html.FileReader();
    reader.readAsText(file);
    await reader.onLoad.first;
    final text = reader.result as String;
    Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(text));
    } catch (_) {
      _snack('ملف JSON غير صالح', _err);
      return;
    }
    if (payload['schema_version'] != 1) {
      _snack('إصدار schema غير مدعوم', _err);
      return;
    }
    final ok = await _confirm(
      'استيراد إعدادات',
      'سيتم استبدال الإعدادات الحالية بما في الملف.\nتصدير بتاريخ: ${payload['exported_at'] ?? '—'}\n\nهل تريد المتابعة؟',
    );
    if (!ok) return;
    final r = await _client.importSettings(PilotSession.tenantId!, payload);
    if (!mounted) return;
    if (r.success) {
      final n = (r.data['applied_count'] ?? 0) as int;
      _snack('تم الاستيراد — $n حقل مُحدَّث', _ok);
      await widget.onReload();
      _loadCompliance();
    } else {
      _snack(r.error ?? 'فشل الاستيراد', _err);
    }
  }

  Future<void> _openHistory() async {
    await _loadHistory();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Row(children: [
            Icon(Icons.history, color: _gold),
            SizedBox(width: 8),
            Text('سجل التغييرات',
                style: TextStyle(color: _tp, fontSize: 16)),
            const Spacer(),
            Text('${_history.length} سجل',
                style: TextStyle(color: _ts, fontSize: 11)),
          ]),
          content: SizedBox(
            width: 720,
            height: 480,
            child: _loadingHistory
                ? Center(
                    child: CircularProgressIndicator(color: _gold))
                : _history.isEmpty
                    ? Center(
                        child: Text('لا توجد تغييرات مسجّلة بعد',
                            style: TextStyle(color: _td)))
                    : ListView.separated(
                        itemCount: _history.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 6, color: _bdr),
                        itemBuilder: (_, i) => _historyEntry(_history[i]),
                      ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إغلاق', style: TextStyle(color: _ts))),
          ],
        ),
      ),
    );
  }

  Widget _historyEntry(Map<String, dynamic> h) {
    final cat = h['category']?.toString() ?? 'other';
    final changes = (h['changes'] as List?) ?? [];
    final when = h['changed_at']?.toString() ?? '';
    final by = h['changed_by_name']?.toString() ?? 'system';
    final note = h['note']?.toString();
    final isRollback = h['rolled_back_from_id'] != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (isRollback ? core_theme.AC.info : _gold)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                isRollback ? '↶ استعادة' : _categoryLabel(cat),
                style: TextStyle(
                  color: isRollback ? core_theme.AC.info : _gold,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SizedBox(width: 8),
            Text('بواسطة: $by',
                style: TextStyle(color: _ts, fontSize: 11)),
            const Spacer(),
            if (!isRollback)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: core_theme.AC.info,
                  side: BorderSide(color: core_theme.AC.info.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 24),
                ),
                onPressed: () => _rollbackEntry(h),
                icon: const Icon(Icons.undo, size: 12),
                label: Text('استعادة', style: TextStyle(fontSize: 10)),
              ),
            const SizedBox(width: 8),
            Text(
                when.length >= 19
                    ? when.substring(0, 19).replaceAll('T', ' ')
                    : when,
                style: TextStyle(
                    color: _td, fontSize: 10, fontFamily: 'monospace')),
          ]),
          if (note != null && note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 4),
              child: Text(note,
                  style: TextStyle(
                      color: _ts,
                      fontSize: 11,
                      fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 4),
          ...changes.take(5).map((c) {
            final m = c as Map;
            return Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Row(children: [
                Icon(Icons.arrow_forward, color: _td, size: 10),
                SizedBox(width: 4),
                Text(m['field']?.toString() ?? '',
                    style: TextStyle(
                        color: _ts,
                        fontSize: 11,
                        fontFamily: 'monospace')),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    _trunc(m['old']?.toString() ?? '—'),
                    style: TextStyle(
                        color: _err,
                        fontSize: 10,
                        fontFamily: 'monospace',
                        decoration: TextDecoration.lineThrough),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.east, color: _td, size: 10),
                SizedBox(width: 4),
                Flexible(
                  child: Text(
                    _trunc(m['new']?.toString() ?? '—'),
                    style: TextStyle(
                        color: _ok,
                        fontSize: 10,
                        fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            );
          }),
          if (changes.length > 5)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text('+ ${changes.length - 5} تغيير إضافي',
                  style: TextStyle(color: _td, fontSize: 10)),
            ),
        ],
      ),
    );
  }

  String _trunc(String s) => s.length > 40 ? '${s.substring(0, 37)}...' : s;

  Future<void> _rollbackEntry(Map<String, dynamic> h) async {
    final cat = _categoryLabel(h['category']?.toString() ?? 'other');
    final nChanges = (h['changes'] as List?)?.length ?? 0;
    final ok = await _confirm(
      'استعادة التغيير',
      'سيتم استرجاع $nChanges حقل إلى قيمها السابقة (تصنيف: $cat).\nهل أنت متأكد؟',
    );
    if (!ok) return;
    final r = await _client.rollbackSettingsChange(
        PilotSession.tenantId!, h['id'] as String);
    if (!mounted) return;
    if (r.success) {
      _snack('تم استرجاع ${r.data['reverted_count']} حقل', _ok);
      Navigator.of(context).pop(); // close history dialog
      await widget.onReload();
      _loadCompliance();
    } else {
      _snack(r.error ?? 'فشل الاستعادة', _err);
    }
  }

  Future<void> _showBenchmarks() async {
    final r = await _client.getBenchmarks(PilotSession.tenantId!);
    if (!mounted) return;
    if (!r.success) {
      _snack(r.error ?? 'فشل تحميل المعايير', _err);
      return;
    }
    final b = Map<String, dynamic>.from(r.data);
    final rows = List<Map<String, dynamic>>.from(b['rows'] ?? []);
    final alignment = (b['alignment_pct'] ?? 0) as int;
    final color = alignment >= 80
        ? _ok
        : alignment >= 60
            ? core_theme.AC.warn
            : _err;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Row(children: [
            Icon(Icons.compare_arrows, color: _gold),
            SizedBox(width: 8),
            Text('المقارنة مع متوسط السوق',
                style: TextStyle(color: _tp, fontSize: 16)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$alignment%',
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          content: SizedBox(
            width: 720,
            height: 480,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _navy3,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(children: [
                    Icon(Icons.public, color: _gold.withValues(alpha: 0.7), size: 14),
                    SizedBox(width: 6),
                    Text(
                      '${b['country_label']} · قطاع التجزئة · ${b['matches']}/${b['total_checks']} إعدادات متوافقة',
                      style: TextStyle(color: _ts, fontSize: 12),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 6),
                    itemBuilder: (_, i) => _benchmarkRow(rows[i]),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إغلاق', style: TextStyle(color: _ts))),
          ],
        ),
      ),
    );
  }

  Widget _benchmarkRow(Map<String, dynamic> r) {
    final matches = r['matches'] == true;
    final field = r['field']?.toString() ?? '';
    final cur = r['current_value']?.toString() ?? '—';
    final bench = r['benchmark_value']?.toString() ?? '—';
    final adoption = (r['adoption_pct'] ?? 0) as int;
    final note = r['note']?.toString() ?? '';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: matches
              ? _ok.withValues(alpha: 0.3)
              : core_theme.AC.warn.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              matches ? Icons.check_circle : Icons.info_outline,
              color: matches ? _ok : core_theme.AC.warn,
              size: 14,
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(_benchLabel(field),
                  style: TextStyle(
                      color: _tp,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: core_theme.AC.info.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('$adoption% من السوق',
                  style: TextStyle(
                      color: core_theme.AC.info,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          SizedBox(height: 4),
          Row(children: [
            Expanded(
              child: Text('لديك: $cur',
                  style: TextStyle(
                      color: matches ? _ok : _err,
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ),
            Icon(Icons.arrow_forward, color: _td, size: 10),
            SizedBox(width: 6),
            Expanded(
              child: Text('السوق: $bench',
                  style: TextStyle(
                      color: _gold,
                      fontSize: 11,
                      fontFamily: 'monospace')),
            ),
          ]),
          if (note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(note,
                  style: TextStyle(
                      color: _td,
                      fontSize: 10,
                      fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  String _benchLabel(String key) => switch (key) {
        'default_vat_rate' => 'نسبة VAT',
        'accounting_method' => 'طريقة المحاسبة',
        'close_lock_policy' => 'سياسة الإقفال',
        'retention_years' => 'مدة الاحتفاظ',
        'fiscal_year_start_month' => 'بداية السنة المالية',
        'password_min_length' => 'طول كلمة المرور الأدنى',
        'force_2fa' => 'المصادقة الثنائية',
        'backup_frequency_hours' => 'تكرار النسخ الاحتياطي',
        _ => key,
      };

  String _categoryLabel(String c) => switch (c) {
        'fiscal' => 'فترات',
        'currency' => 'عملات',
        'tax' => 'ضرائب',
        'approvals' => 'اعتمادات',
        'numbering' => 'ترقيم',
        'security' => 'أمن',
        'audit' => 'تدقيق',
        'ai' => 'AI',
        'backup' => 'نسخ',
        'regional' => 'إقليمي',
        'branding' => 'هوية',
        'preset' => 'قالب',
        'import' => 'استيراد',
        _ => c,
      };

  // ═════════════════════════════════════════════════════════════
  // Sidebar
  // ═════════════════════════════════════════════════════════════

  Widget _sidebar() {
    // Each category has a list of searchable keywords (bilingual)
    final cats = <(String, String, IconData, Color, List<String>)>[
      (
        'fiscal',
        'السنة المالية والفترات',
        Icons.calendar_month,
        core_theme.AC.info,
        ['fiscal', 'year', 'period', 'close', 'سنة', 'مالية', 'فترة', 'إقفال',
         'retention', 'احتفاظ', 'lenient'],
      ),
      (
        'currency',
        'العملات والصرف',
        Icons.currency_exchange,
        core_theme.AC.ok,
        ['currency', 'fx', 'rate', 'عملة', 'صرف', 'sar', 'usd', 'aed', 'eur'],
      ),
      (
        'tax',
        'الضرائب والزكاة',
        Icons.receipt_long,
        _gold,
        ['tax', 'vat', 'zakat', 'wht', 'zatca', 'ضريبة', 'زكاة', 'استقطاع',
         'مضافة'],
      ),
      (
        'approvals',
        'حدود الاعتماد',
        Icons.approval,
        core_theme.AC.purple,
        ['approval', 'limit', 'threshold', 'اعتماد', 'موافقة', 'حد', 'dual',
         'مزدوج'],
      ),
      (
        'numbering',
        'ترقيم المستندات',
        Icons.pin,
        core_theme.AC.warn,
        ['number', 'prefix', 'je', 'inv', 'po', 'bill', 'ترقيم', 'بادئة',
         'فاتورة', 'قيد'],
      ),
      (
        'security',
        'الأمن والصلاحيات',
        Icons.security,
        core_theme.AC.err,
        ['security', 'password', '2fa', 'biometric', 'fido', 'session',
         'lockout', 'login', 'أمن', 'كلمة مرور', 'جلسة', 'مصادقة'],
      ),
      (
        'audit',
        'تدقيق السجلات',
        Icons.history_edu,
        core_theme.AC.purple,
        ['audit', 'log', 'retention', 'worm', 'archive', 'تدقيق', 'سجل',
         'أرشيف', 'احتفاظ'],
      ),
      (
        'ai',
        'إعدادات AI',
        Icons.smart_toy,
        core_theme.AC.err,
        ['ai', 'claude', 'anthropic', 'copilot', 'anomaly', 'threshold',
         'ذكاء', 'اصطناعي', 'مطابقة', 'نموذج'],
      ),
      (
        'backup',
        'النسخ الاحتياطي',
        Icons.backup,
        core_theme.AC.info,
        ['backup', 'restore', 'encryption', 'نسخة', 'احتياطية', 'استعادة',
         'تشفير'],
      ),
      (
        'regional',
        'الإعدادات الإقليمية',
        Icons.public,
        core_theme.AC.info,
        ['region', 'language', 'calendar', 'timezone', 'hijri', 'gregorian',
         'work week', 'date format', 'لغة', 'تقويم', 'هجري', 'منطقة'],
      ),
      (
        'theme',
        'الهوية البصرية (Theme)',
        Icons.palette,
        Colors.deepOrange,
        ['theme', 'color', 'palette', 'dark', 'light', 'هوية', 'ألوان',
         'سمة', 'فاتح', 'داكن'],
      ),
    ];
    final filtered = _search.isEmpty
        ? cats
        : cats.where((c) {
            final q = _search.toLowerCase();
            return c.$2.toLowerCase().contains(q) ||
                c.$5.any((k) => k.toLowerCase().contains(q));
          }).toList();
    return Container(
      width: 260,
      color: _navy2,
      child: filtered.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('لا نتائج',
                    style: TextStyle(color: _td, fontSize: 12)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: filtered.map((c) {
                final selected = c.$1 == _cat;
          return InkWell(
            onTap: () => setState(() => _cat = c.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? c.$4.withValues(alpha: 0.12) : null,
                border: BorderDirectional(
                  end: BorderSide(
                    color: selected ? c.$4 : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: c.$4.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(c.$3, color: c.$4, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(c.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? _tp : _ts,
                      )),
                ),
                if (selected)
                  Icon(Icons.chevron_left, color: c.$4, size: 16),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // Content router
  // ═════════════════════════════════════════════════════════════

  Widget _content() {
    final body = switch (_cat) {
      'fiscal' => _fiscalCategory(),
      'currency' => _currencyCategory(),
      'tax' => _taxCategory(),
      'approvals' => _approvalsCategory(),
      'numbering' => _numberingCategory(),
      'security' => _securityCategory(),
      'audit' => _auditCategory(),
      'ai' => _aiCategory(),
      'backup' => _backupCategory(),
      'regional' => _regionalCategory(),
      _ => _themeCategory(),
    };
    return Container(
      color: _navy3,
      padding: const EdgeInsets.all(18),
      child: body,
    );
  }

  // ═════════════════════════════════════════════════════════════
  // 1. FISCAL
  // ═════════════════════════════════════════════════════════════

  Widget _fiscalCategory() {
    final s = _s;
    final warnings = <Widget>[];
    if ((s['retention_years'] ?? 0) < 7) {
      warnings.add(_warningBanner(
        'ZATCA يتطلّب الاحتفاظ بالسجلات 7 سنوات على الأقل',
        'الإعداد الحالي: ${s['retention_years'] ?? 0} سنة — ارفعه إلى 7 فأكثر لتجنّب مخالفات هيئة الزكاة.',
        _err,
      ));
    }
    if (s['close_lock_policy'] == 'lenient' &&
        (s['lenient_days'] ?? 0) > 30) {
      warnings.add(_warningBanner(
        'أيام السماح > 30 قد تُضعف الرقابة',
        'الإعداد الحالي: ${s['lenient_days']} يوم. توصية: ≤ 30 يوماً.',
        core_theme.AC.warn,
      ));
    }
    if (s['accounting_method'] == 'cash') {
      warnings.add(_warningBanner(
        'الطريقة النقدية — لا تتوافق مع IFRS/SOCPA للشركات الكبيرة',
        'للأعمال التي يتجاوز إيرادها 40 مليون ر.س، يُفرَض "استحقاق" وفق SOCPA.',
        core_theme.AC.warn,
      ));
    }
    return ListView(children: [
      if (warnings.isNotEmpty) ...[
        ...warnings,
        const SizedBox(height: 10),
      ],
      _sectionHeader('السنة المالية', Icons.calendar_month, core_theme.AC.info),
      _numRow(
        'شهر بداية السنة',
        (s['fiscal_year_start_month'] ?? 1) as int,
        (v) => _update({'fiscal_year_start_month': v}),
        min: 1,
        max: 12,
        hint: 'الشهر الذي تبدأ فيه السنة المالية',
      ),
      _numRow(
        'يوم بداية السنة',
        (s['fiscal_year_start_day'] ?? 1) as int,
        (v) => _update({'fiscal_year_start_day': v}),
        min: 1,
        max: 31,
      ),
      _dropdownRow<String>(
        'نوع الفترة',
        (s['period_type'] ?? 'monthly') as String,
        const [
          DropdownMenuItem(value: 'monthly', child: Text('شهرية (12 فترة)')),
          DropdownMenuItem(value: '4-4-5', child: Text('4-4-5 (13 فترة)')),
          DropdownMenuItem(value: 'quarterly', child: Text('ربعية (4 فترات)')),
        ],
        (v) => _update({'period_type': v}),
      ),
      _dropdownRow<String>(
        'طريقة المحاسبة',
        (s['accounting_method'] ?? 'accrual') as String,
        const [
          DropdownMenuItem(value: 'accrual', child: Text('استحقاق')),
          DropdownMenuItem(value: 'cash', child: Text('نقدي')),
        ],
        (v) => _update({'accounting_method': v}),
      ),
      const SizedBox(height: 18),
      _sectionHeader('سياسة الإقفال', Icons.lock, core_theme.AC.info),
      _dropdownRow<String>(
        'سياسة القفل بعد الإقفال',
        (s['close_lock_policy'] ?? 'hard') as String,
        const [
          DropdownMenuItem(value: 'hard', child: Text('صارم — لا تعديل')),
          DropdownMenuItem(value: 'soft', child: Text('مرن — تعديل بسجل')),
          DropdownMenuItem(value: 'lenient', child: Text('متساهل لأيام محددة')),
        ],
        (v) => _update({'close_lock_policy': v}),
      ),
      _numRow(
        'أيام السماح بعد الإقفال (lenient فقط)',
        (s['lenient_days'] ?? 0) as int,
        (v) => _update({'lenient_days': v}),
        min: 0,
        max: 90,
      ),
      _numRow(
        'فترة الاحتفاظ بالسجلات (سنوات)',
        (s['retention_years'] ?? 7) as int,
        (v) => _update({'retention_years': v}),
        min: 1,
        max: 30,
        hint: 'ZATCA يتطلّب 7 سنوات كحد أدنى',
      ),
      const SizedBox(height: 18),
      _sectionHeader('الفترات المالية', Icons.event, core_theme.AC.info),
      _periodsPanel(),
    ]);
  }

  Widget _periodsPanel() {
    if (widget.entities.isEmpty) {
      return _emptyCard('لا توجد كيانات لعرض فتراتها');
    }
    return Column(children: [
      Row(children: [
        Expanded(
          child: _dropdownBox<String>(
            'الكيان',
            _selectedEntityId ?? widget.entities.first['id'],
            widget.entities
                .map((e) => DropdownMenuItem(
                      value: e['id'] as String,
                      child: Text('${e['code']} — ${e['name_ar'] ?? ''}',
                          style: const TextStyle(fontSize: 12)),
                    ))
                .toList(),
            (v) {
              setState(() => _selectedEntityId = v);
              _loadPeriods();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _dropdownBox<int>(
            'السنة',
            _selectedYear,
            List.generate(6, (i) {
              final y = DateTime.now().year - 2 + i;
              return DropdownMenuItem(value: y, child: Text('$y'));
            }),
            (v) {
              setState(() => _selectedYear = v);
              _loadPeriods();
            },
          ),
        ),
        SizedBox(width: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _gold.withValues(alpha: 0.4)),
            foregroundColor: _gold,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onPressed: _seedPeriods,
          icon: const Icon(Icons.auto_awesome, size: 14),
          label: Text('بذر فترات $_selectedYear',
              style: const TextStyle(fontSize: 11)),
        ),
      ]),
      SizedBox(height: 10),
      if (_loadingPeriods)
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: _gold)),
        )
      else if (_periods.isEmpty)
        _emptyCard('لا توجد فترات — اضغط "بذر فترات $_selectedYear"')
      else
        ..._periods.map((p) => _periodCard(p)),
    ]);
  }

  Widget _periodCard(Map<String, dynamic> p) {
    final status = p['status']?.toString() ?? 'open';
    final color = switch (status) {
      'open' => _ok,
      'closing' || 'submitted' => core_theme.AC.warn,
      'closed' => core_theme.AC.td,
      _ => _ts,
    };
    final icon = switch (status) {
      'open' => Icons.lock_open,
      'closing' || 'submitted' => Icons.lock_clock,
      'closed' => Icons.lock,
      _ => Icons.circle_outlined,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            '${p['name'] ?? '—'}',
            style: TextStyle(
                color: _tp, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '${p['start_date'] ?? ''} → ${p['end_date'] ?? ''}',
          style: TextStyle(
              color: _ts, fontSize: 10, fontFamily: 'monospace'),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _periodStatusLabel(status),
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color),
          ),
        ),
        if (status == 'open') ...[
          const SizedBox(width: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: core_theme.AC.warn,
              side: BorderSide(color: core_theme.AC.warn.withValues(alpha: 0.4)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
            onPressed: () => _closePeriod(p),
            icon: const Icon(Icons.lock, size: 12),
            label: Text('إقفال', style: TextStyle(fontSize: 10)),
          ),
        ],
      ]),
    );
  }

  String _periodStatusLabel(String s) => switch (s) {
        'open' => 'مفتوحة',
        'closing' => 'قيد الإقفال',
        'submitted' => 'مُرسلة',
        'closed' => 'مُقفلة',
        _ => s,
      };

  Future<void> _seedPeriods() async {
    if (_selectedEntityId == null) return;
    final r = await _client.seedFiscalPeriods(_selectedEntityId!, _selectedYear);
    if (!mounted) return;
    if (r.success) {
      _snack('تم بذر فترات $_selectedYear', _ok);
      _loadPeriods();
    } else {
      _snack(r.error ?? 'فشل البذر', _err);
    }
  }

  Future<void> _closePeriod(Map<String, dynamic> p) async {
    final ok = await _confirm('إقفال الفترة "${p['name']}"',
        'بعد الإقفال لا يمكن إضافة قيود جديدة لهذه الفترة (حسب سياسة الإقفال).');
    if (!ok) return;
    final r = await _client.closePeriod(p['id'] as String, 'system');
    if (!mounted) return;
    if (r.success) {
      _snack('تم الإقفال', _ok);
      _loadPeriods();
    } else {
      _snack(r.error ?? 'فشل الإقفال', _err);
    }
  }

  // ═════════════════════════════════════════════════════════════
  // 2. CURRENCY
  // ═════════════════════════════════════════════════════════════

  Widget _currencyCategory() {
    final s = _s;
    return ListView(children: [
      _sectionHeader('العملة الأساسية', Icons.currency_exchange, core_theme.AC.ok),
      _infoRow(
        'العملة الأساسية',
        (s['base_currency'] ?? 'SAR') as String,
        hint: 'العملة الرئيسية لجميع القيود — تُعدّل بتغيير الإعداد',
        onEdit: _editBaseCurrency,
      ),
      const SizedBox(height: 18),
      _sectionHeader('العملات المُفعّلة', Icons.language, core_theme.AC.ok),
      _currenciesPanel(),
      const SizedBox(height: 18),
      _sectionHeader('أسعار الصرف (FX)', Icons.swap_horiz, core_theme.AC.ok),
      _fxRatesPanel(),
    ]);
  }

  Widget _currenciesPanel() {
    if (_loadingCurrencies) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: _gold)),
      );
    }
    return Column(children: [
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _gold.withValues(alpha: 0.4)),
            foregroundColor: _gold,
          ),
          onPressed: _addCurrency,
          icon: const Icon(Icons.add, size: 14),
          label: Text('إضافة عملة', style: TextStyle(fontSize: 11)),
        ),
      ),
      const SizedBox(height: 8),
      if (_currencies.isEmpty)
        _emptyCard('لا توجد عملات — اضغط "إضافة عملة"')
      else
        ..._currencies.map((c) => _currencyCard(c)),
    ]);
  }

  Widget _currencyCard(Map<String, dynamic> c) {
    final isBase = c['is_base_currency'] == true;
    final active = c['is_active'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        if ((c['emoji_flag'] ?? '').toString().isNotEmpty)
          Text(c['emoji_flag'] as String, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: core_theme.AC.ok.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(c['code'] ?? '',
              style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  color: core_theme.AC.ok)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(c['name_ar'] ?? c['name_en'] ?? '',
                  style: TextStyle(color: _tp, fontSize: 13)),
              Text(
                'رمز: ${c['symbol'] ?? '—'} · ${c['decimal_places'] ?? 2} خانة',
                style: TextStyle(color: _ts, fontSize: 10),
              ),
            ],
          ),
        ),
        if (isBase)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsetsDirectional.only(end: 6),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('أساسية',
                style: TextStyle(
                    fontSize: 9, color: _gold, fontWeight: FontWeight.w700)),
          ),
        Switch(
          value: active,
          onChanged: null,
          activeColor: _gold,
          activeTrackColor: _gold.withValues(alpha: 0.3),
        ),
      ]),
    );
  }

  Widget _fxRatesPanel() {
    final byPair = <String, Map<String, dynamic>>{};
    for (final r in _fxRates) {
      final key = '${r['from_currency']}→${r['to_currency']}';
      final existing = byPair[key];
      if (existing == null ||
          (r['effective_date']?.toString() ?? '')
                  .compareTo(existing['effective_date']?.toString() ?? '') >
              0) {
        byPair[key] = r;
      }
    }
    final latest = byPair.values.toList()
      ..sort((a, b) =>
          (a['from_currency'] ?? '').toString().compareTo(b['from_currency'] ?? ''));

    return Column(children: [
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _gold.withValues(alpha: 0.4)),
            foregroundColor: _gold,
          ),
          onPressed: _addFxRate,
          icon: const Icon(Icons.add, size: 14),
          label: Text('إضافة سعر صرف', style: TextStyle(fontSize: 11)),
        ),
      ),
      const SizedBox(height: 8),
      if (latest.isEmpty)
        _emptyCard('لا توجد أسعار صرف مسجّلة')
      else
        ...latest.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _navy2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _bdr),
              ),
              child: Row(children: [
                Icon(Icons.trending_up, color: core_theme.AC.ok, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '1 ${r['from_currency']} = ${r['rate']} ${r['to_currency']}',
                    style: TextStyle(
                      color: _tp,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                Text(
                  '${r['effective_date'] ?? ''} · ${r['rate_type'] ?? ''}',
                  style: TextStyle(color: _ts, fontSize: 10),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: core_theme.AC.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r['source'] ?? 'manual',
                    style: TextStyle(
                      color: core_theme.AC.info,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ]),
            )),
    ]);
  }

  Future<void> _editBaseCurrency() async {
    final current = (_s['base_currency'] ?? 'SAR') as String;
    String sel = current;
    final options = _currencies.isNotEmpty
        ? _currencies.map((c) => c['code'] as String).toList()
        : const ['SAR', 'AED', 'USD', 'EUR'];
    final ok = await _dialog<bool>(
      'العملة الأساسية',
      (setS) => DropdownButtonFormField<String>(
        value: sel,
        decoration: _inputDecoration('العملة'),
        dropdownColor: _navy3,
        style: TextStyle(color: _tp, fontSize: 13),
        items: options
            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
            .toList(),
        onChanged: (v) => setS(() => sel = v!),
      ),
    );
    if (ok != true) return;
    await _update({'base_currency': sel});
  }

  Future<void> _addCurrency() async {
    final codeCtrl = TextEditingController();
    final nameArCtrl = TextEditingController();
    final nameEnCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    final flagCtrl = TextEditingController();
    int decimals = 2;
    final ok = await _dialog<bool>(
      'إضافة عملة',
      (setS) => Column(mainAxisSize: MainAxisSize.min, children: [
        _dialogField(codeCtrl, 'الرمز (ISO-4217 مثل USD)'),
        _dialogField(nameArCtrl, 'الاسم بالعربية'),
        _dialogField(nameEnCtrl, 'الاسم بالإنجليزية'),
        _dialogField(symbolCtrl, 'الرمز (مثل \$)'),
        _dialogField(flagCtrl, 'Emoji علم (اختياري)'),
        DropdownButtonFormField<int>(
          value: decimals,
          decoration: _inputDecoration('الخانات العشرية'),
          dropdownColor: _navy3,
          style: TextStyle(color: _tp, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 0, child: Text('0')),
            DropdownMenuItem(value: 2, child: Text('2')),
            DropdownMenuItem(value: 3, child: Text('3 (KWD/BHD)')),
          ],
          onChanged: (v) => setS(() => decimals = v!),
        ),
      ]),
    );
    if (ok != true || codeCtrl.text.trim().isEmpty) return;
    final r = await _client.createCurrency(PilotSession.tenantId!, {
      'code': codeCtrl.text.trim().toUpperCase(),
      'name_ar': nameArCtrl.text.trim(),
      'name_en': nameEnCtrl.text.trim().isEmpty
          ? nameArCtrl.text.trim()
          : nameEnCtrl.text.trim(),
      'symbol': symbolCtrl.text.trim(),
      'emoji_flag': flagCtrl.text.trim(),
      'decimal_places': decimals,
      'is_active': true,
    });
    if (!mounted) return;
    if (r.success) {
      _snack('تمت إضافة العملة', _ok);
      _loadCurrencies();
    } else {
      _snack(r.error ?? 'فشل', _err);
    }
  }

  Future<void> _addFxRate() async {
    final rateCtrl = TextEditingController();
    String fromC = (_s['base_currency'] ?? 'SAR') as String;
    String toC = 'USD';
    String rateType = 'spot';
    DateTime date = DateTime.now();
    final options = _currencies.isNotEmpty
        ? _currencies.map((c) => c['code'] as String).toList()
        : const ['SAR', 'USD', 'EUR', 'AED', 'KWD'];
    final ok = await _dialog<bool>(
      'إضافة سعر صرف',
      (setS) => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: fromC,
              decoration: _inputDecoration('من'),
              dropdownColor: _navy3,
              style: TextStyle(color: _tp, fontSize: 13),
              items: options
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setS(() => fromC = v!),
            ),
          ),
          SizedBox(width: 6),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: toC,
              decoration: _inputDecoration('إلى'),
              dropdownColor: _navy3,
              style: TextStyle(color: _tp, fontSize: 13),
              items: options
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setS(() => toC = v!),
            ),
          ),
        ]),
        _dialogField(rateCtrl, 'السعر (1 من = ? إلى)'),
        DropdownButtonFormField<String>(
          value: rateType,
          decoration: _inputDecoration('النوع'),
          dropdownColor: _navy3,
          style: TextStyle(color: _tp, fontSize: 13),
          items: const [
            DropdownMenuItem(value: 'spot', child: Text('فوري (Spot)')),
            DropdownMenuItem(value: 'avg_month', child: Text('متوسط شهري')),
            DropdownMenuItem(value: 'closing', child: Text('إقفال')),
          ],
          onChanged: (v) => setS(() => rateType = v!),
        ),
      ]),
    );
    if (ok != true || rateCtrl.text.trim().isEmpty) return;
    final r = await _client.createFxRate(PilotSession.tenantId!, {
      'from_currency': fromC,
      'to_currency': toC,
      'rate': double.tryParse(rateCtrl.text.trim()) ?? 1.0,
      'rate_type': rateType,
      'effective_date': date.toIso8601String().substring(0, 10),
      'source': 'manual',
    });
    if (!mounted) return;
    if (r.success) {
      _snack('تمت الإضافة', _ok);
      _loadCurrencies();
    } else {
      _snack(r.error ?? 'فشل', _err);
    }
  }

  // ═════════════════════════════════════════════════════════════
  // 3. TAX
  // ═════════════════════════════════════════════════════════════

  Widget _taxCategory() {
    final s = _s;
    final tenant = widget.tenant;
    final features = (tenant['features'] is Map)
        ? Map<String, dynamic>.from(tenant['features'])
        : <String, dynamic>{};
    final wht = _extrasSection('tax')['wht_rates'] is Map
        ? Map<String, dynamic>.from(_extrasSection('tax')['wht_rates'])
        : <String, dynamic>{};

    final warnings = <Widget>[];
    if ((tenant['primary_vat_number'] ?? '').toString().isEmpty) {
      warnings.add(_warningBanner(
        'الرقم الضريبي (VAT) غير مُدخَل',
        'لن تتمكّن من إصدار فواتير متوافقة مع ZATCA. أدخله من تبويب "الشركة الأم".',
        _err,
      ));
    }
    if (tenant['primary_country'] == 'SA' &&
        (s['default_vat_rate'] ?? 0) != 15) {
      warnings.add(_warningBanner(
        'نسبة VAT السعودية الحالية 15% — الإعداد الحالي مختلف',
        'الإعداد الحالي: ${s['default_vat_rate']}% — تأكد أن هذا صحيح لنشاطك.',
        core_theme.AC.warn,
      ));
    }
    if (tenant['primary_country'] == 'SA' && features['zatca'] != true) {
      warnings.add(_warningBanner(
        'ميزة ZATCA غير مُفعّلة في هذا المستأجر',
        'الإصدار الإلكتروني للفواتير مطلوب قانونياً في السعودية — فعّله من شاشة الميزات.',
        _err,
      ));
    }

    return ListView(children: [
      if (warnings.isNotEmpty) ...[
        ...warnings,
        SizedBox(height: 10),
      ],
      _sectionHeader('ضريبة القيمة المضافة (VAT)', Icons.percent, _gold),
      _numRow(
        'النسبة الأساسية (%)',
        (s['default_vat_rate'] ?? 15) as int,
        (v) => _update({'default_vat_rate': v}),
        min: 0,
        max: 100,
        suffix: '%',
      ),
      _infoRow(
        'الرقم الضريبي',
        tenant['primary_vat_number']?.toString() ?? '—',
        hint: 'من بيانات الشركة الأم — يُعدّل هناك',
      ),
      _infoRow(
        'ZATCA Phase',
        features['zatca'] == true ? 'Phase 2 (Integration)' : 'غير مُفعّل',
      ),
      SizedBox(height: 18),
      _sectionHeader('الزكاة', Icons.star, _gold),
      _numRow(
        'نسبة الزكاة (basis points)',
        (s['zakat_rate_bp'] ?? 250) as int,
        (v) => _update({'zakat_rate_bp': v}),
        min: 0,
        max: 10000,
        hint: '250 BP = 2.5% (المعدّل السعودي)',
      ),
      _infoRow(
        'النسبة المعروضة',
        '${((s['zakat_rate_bp'] ?? 250) as int) / 100}%',
      ),
      SizedBox(height: 18),
      _sectionHeader('ضريبة الاستقطاع (WHT)', Icons.money_off, _gold),
      _numRow(
        'خدمات فنية (%)',
        (wht['services'] ?? 5) is int
            ? wht['services'] ?? 5
            : int.tryParse(wht['services'].toString()) ?? 5,
        (v) => _updateExtrasSection(
            'tax', {'wht_rates': {...wht, 'services': v}}),
        min: 0,
        max: 30,
        suffix: '%',
      ),
      _numRow(
        'إيجار (%)',
        wht['rent'] ?? 5,
        (v) => _updateExtrasSection('tax', {'wht_rates': {...wht, 'rent': v}}),
        min: 0,
        max: 30,
        suffix: '%',
      ),
      _numRow(
        'عمولات (%)',
        wht['commissions'] ?? 15,
        (v) => _updateExtrasSection(
            'tax', {'wht_rates': {...wht, 'commissions': v}}),
        min: 0,
        max: 30,
        suffix: '%',
      ),
      _numRow(
        'أخرى (الافتراضية) (%)',
        wht['other'] ?? 20,
        (v) => _updateExtrasSection('tax', {'wht_rates': {...wht, 'other': v}}),
        min: 0,
        max: 30,
        suffix: '%',
      ),
    ]);
  }

  // ═════════════════════════════════════════════════════════════
  // 4. APPROVALS
  // ═════════════════════════════════════════════════════════════

  Widget _approvalsCategory() {
    final t = (_s['approval_thresholds'] is Map)
        ? Map<String, dynamic>.from(_s['approval_thresholds'])
        : <String, dynamic>{};
    final jeTiers = (t['je'] is List) ? List<Map<String, dynamic>>.from(t['je']) : <Map<String, dynamic>>[];
    final poTiers = (t['po'] is List) ? List<Map<String, dynamic>>.from(t['po']) : <Map<String, dynamic>>[];

    return ListView(children: [
      _approvalsSectionHeader('حدود اعتماد قيود اليومية (JE)', () => _addTier('je', jeTiers)),
      if (jeTiers.isEmpty)
        _emptyCard('لا توجد مستويات — أضف مستوى')
      else
        ...jeTiers.asMap().entries.map((e) =>
            _approvalTierCard('je', e.key, e.value, jeTiers)),
      const SizedBox(height: 18),
      _approvalsSectionHeader('حدود اعتماد أوامر الشراء (PO)', () => _addTier('po', poTiers)),
      if (poTiers.isEmpty)
        _emptyCard('لا توجد مستويات — أضف مستوى')
      else
        ...poTiers.asMap().entries.map((e) =>
            _approvalTierCard('po', e.key, e.value, poTiers)),
    ]);
  }

  Widget _approvalsSectionHeader(String title, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(children: [
        Container(width: 4, height: 20, color: core_theme.AC.purple),
        const SizedBox(width: 10),
        Icon(Icons.approval, color: core_theme.AC.purple, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: core_theme.AC.purple)),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _gold,
            side: BorderSide(color: _gold.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          ),
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 12),
          label: Text('إضافة مستوى', style: TextStyle(fontSize: 10)),
        ),
      ]),
    );
  }

  Widget _approvalTierCard(String kind, int index, Map<String, dynamic> tier, List<Map<String, dynamic>> tiers) {
    final max = tier['max'];
    final maxLabel = max == null ? '∞' : _fmtMoney(max);
    final dual = tier['dual_approval'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: core_theme.AC.purple.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text('L${tier['level'] ?? index + 1}',
              style: TextStyle(
                  color: core_theme.AC.purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('حتى $maxLabel',
                  style: TextStyle(
                      color: _tp, fontSize: 12, fontWeight: FontWeight.w700)),
              Text(tier['role']?.toString() ?? '—',
                  style: TextStyle(color: _ts, fontSize: 10)),
            ],
          ),
        ),
        if (dual)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('اعتماد مزدوج',
                style: TextStyle(
                    color: _gold, fontSize: 9, fontWeight: FontWeight.w700)),
          ),
        SizedBox(width: 6),
        IconButton(
          icon: Icon(Icons.edit, color: _ts, size: 16),
          onPressed: () => _editTier(kind, index, tier, tiers),
        ),
        IconButton(
          icon: Icon(Icons.delete, color: _err, size: 16),
          onPressed: () => _deleteTier(kind, index, tiers),
        ),
      ]),
    );
  }

  Future<void> _addTier(String kind, List<Map<String, dynamic>> tiers) async {
    await _editTier(kind, -1, {
      'max': 100000,
      'role': 'manager',
      'level': tiers.length + 1,
      'dual_approval': false,
    }, tiers);
  }

  Future<void> _editTier(String kind, int index, Map<String, dynamic> t,
      List<Map<String, dynamic>> tiers) async {
    final maxCtrl =
        TextEditingController(text: t['max']?.toString() ?? '');
    final roleCtrl =
        TextEditingController(text: t['role']?.toString() ?? '');
    int level = (t['level'] ?? tiers.length + 1) as int;
    bool dual = t['dual_approval'] == true;
    bool unlimited = t['max'] == null;
    final ok = await _dialog<bool>(
      index == -1 ? 'مستوى جديد' : 'تعديل المستوى L$level',
      (setS) => Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('بلا سقف (∞)',
              style: TextStyle(color: _tp, fontSize: 13)),
          value: unlimited,
          activeColor: _gold,
          onChanged: (v) => setS(() {
            unlimited = v;
            if (v) maxCtrl.text = '';
          }),
        ),
        if (!unlimited) _dialogField(maxCtrl, 'السقف (ر.س)'),
        _dialogField(roleCtrl, 'الدور المطلوب (accountant/cfo/ceo...)'),
        DropdownButtonFormField<int>(
          value: level,
          decoration: _inputDecoration('المستوى'),
          dropdownColor: _navy3,
          style: TextStyle(color: _tp, fontSize: 13),
          items: List.generate(
            6,
            (i) => DropdownMenuItem(value: i + 1, child: Text('L${i + 1}')),
          ),
          onChanged: (v) => setS(() => level = v!),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('اعتماد مزدوج (موافقة اثنين)',
              style: TextStyle(color: _tp, fontSize: 13)),
          value: dual,
          activeColor: _gold,
          onChanged: (v) => setS(() => dual = v),
        ),
      ]),
    );
    if (ok != true) return;
    final newTier = <String, dynamic>{
      'max': unlimited ? null : (int.tryParse(maxCtrl.text.trim()) ?? 0),
      'role': roleCtrl.text.trim(),
      'level': level,
      'dual_approval': dual,
    };
    final list = List<Map<String, dynamic>>.from(tiers);
    if (index == -1) {
      list.add(newTier);
    } else {
      list[index] = newTier;
    }
    list.sort((a, b) {
      final am = a['max'] == null ? double.infinity : (a['max'] as num).toDouble();
      final bm = b['max'] == null ? double.infinity : (b['max'] as num).toDouble();
      return am.compareTo(bm);
    });
    final current = (_s['approval_thresholds'] is Map)
        ? Map<String, dynamic>.from(_s['approval_thresholds'])
        : <String, dynamic>{};
    current[kind] = list;
    await _update({'approval_thresholds': current});
  }

  Future<void> _deleteTier(String kind, int index, List<Map<String, dynamic>> tiers) async {
    final ok = await _confirm('حذف المستوى', 'هل أنت متأكد من الحذف؟');
    if (!ok) return;
    final list = List<Map<String, dynamic>>.from(tiers);
    list.removeAt(index);
    final current = (_s['approval_thresholds'] is Map)
        ? Map<String, dynamic>.from(_s['approval_thresholds'])
        : <String, dynamic>{};
    current[kind] = list;
    await _update({'approval_thresholds': current});
  }

  // ═════════════════════════════════════════════════════════════
  // 5. NUMBERING
  // ═════════════════════════════════════════════════════════════

  Widget _numberingCategory() {
    final s = _s;
    return ListView(children: [
      _sectionHeader('ترقيم المستندات', Icons.pin, core_theme.AC.warn),
      _prefixRow('قيود اليومية (JE)', s['je_prefix'] ?? 'JE',
          (v) => _update({'je_prefix': v})),
      _prefixRow('فواتير البيع (Invoice)', s['invoice_prefix'] ?? 'INV',
          (v) => _update({'invoice_prefix': v})),
      _prefixRow('فواتير الشراء (Bill)', s['bill_prefix'] ?? 'VB',
          (v) => _update({'bill_prefix': v})),
      _prefixRow('أوامر الشراء (PO)', s['po_prefix'] ?? 'PO',
          (v) => _update({'po_prefix': v})),
      _prefixRow('إشعارات الدائن (CN)', s['cn_prefix'] ?? 'CN',
          (v) => _update({'cn_prefix': v})),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: core_theme.AC.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: core_theme.AC.info.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.info_outline, color: core_theme.AC.info, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'التنسيق: {PREFIX}-YYYY-##### (مثال: ${s['je_prefix'] ?? 'JE'}-2026-00001)',
              style: TextStyle(
                color: core_theme.AC.info,
                fontSize: 11,
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _prefixRow(String label, String value, Future<bool> Function(String) onSave) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Text(label,
              style: TextStyle(color: _tp, fontSize: 12)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: core_theme.AC.warn.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '$value-YYYY-#####',
            style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: core_theme.AC.warn,
                fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          icon: Icon(Icons.edit, color: _ts, size: 14),
          onPressed: () async {
            final ctrl = TextEditingController(text: value);
            final ok = await _dialog<bool>(
              'تعديل $label',
              (setS) => TextField(
                controller: ctrl,
                style: TextStyle(
                    color: _tp, fontSize: 14, fontFamily: 'monospace'),
                decoration: _inputDecoration('البادئة (3-10 حروف)'),
              ),
            );
            if (ok == true && ctrl.text.trim().isNotEmpty) {
              await onSave(ctrl.text.trim().toUpperCase());
            }
            ctrl.dispose();
          },
        ),
      ]),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // 6. SECURITY (in extras.security)
  // ═════════════════════════════════════════════════════════════

  Widget _securityCategory() {
    final sec = _extrasSection('security');
    final pwd = sec['password'] is Map ? Map<String, dynamic>.from(sec['password']) : <String, dynamic>{};
    final sess = sec['session'] is Map ? Map<String, dynamic>.from(sec['session']) : <String, dynamic>{};
    final login = sec['login'] is Map ? Map<String, dynamic>.from(sec['login']) : <String, dynamic>{};

    final warnings = <Widget>[];
    final minLen = (pwd['min_length'] ?? 0) as int;
    if (minLen < 12) {
      warnings.add(_warningBanner(
        'طول كلمة المرور الأدنى < 12 حرف',
        'توصية NIST: 12 حرف على الأقل. الإعداد الحالي: $minLen — عدّله لتحسين درجة الأمان.',
        minLen < 8 ? _err : core_theme.AC.warn,
      ));
    }
    if (sess['force_2fa'] != true) {
      warnings.add(_warningBanner(
        '2FA غير مُفروض على كل المستخدمين',
        'المصادقة الثنائية تقلّل 99.9% من اختراقات الحسابات (Microsoft Research).',
        core_theme.AC.warn,
      ));
    }
    final idle = (sess['idle_timeout_minutes'] ?? 0) as int;
    if (idle == 0 || idle > 60) {
      warnings.add(_warningBanner(
        'انتهاء الجلسة > 60 دقيقة أو غير مُحدّد',
        'جلسات طويلة تزيد خطر سرقة الجلسة — وصيتنا ≤ 30 دقيقة.',
        core_theme.AC.warn,
      ));
    }
    final maxAttempts = (login['max_attempts'] ?? 0) as int;
    if (maxAttempts == 0 || maxAttempts > 10) {
      warnings.add(_warningBanner(
        'حد محاولات الدخول غير مُحدّد أو > 10',
        'اضبط ≤ 5 محاولات للحماية من brute force.',
        core_theme.AC.warn,
      ));
    }

    return ListView(children: [
      if (warnings.isNotEmpty) ...[
        ...warnings,
        const SizedBox(height: 10),
      ],
      _sectionHeader('المصادقة الثنائية', Icons.security, core_theme.AC.err),
      _switchRow(
        'تفعيل 2FA لكل المستخدمين',
        sess['force_2fa'] == true,
        (v) => _updateExtrasSection('security', {
          'session': {...sess, 'force_2fa': v}
        }),
      ),
      _switchRow(
        'السماح بالمصادقة البيومترية (Touch/Face)',
        sess['allow_biometric'] != false,
        (v) => _updateExtrasSection('security', {
          'session': {...sess, 'allow_biometric': v}
        }),
      ),
      _switchRow(
        'السماح بمفتاح FIDO2 (Hardware Key)',
        sess['allow_fido2'] == true,
        (v) => _updateExtrasSection('security', {
          'session': {...sess, 'allow_fido2': v}
        }),
      ),
      const SizedBox(height: 18),
      _sectionHeader('سياسة كلمات المرور', Icons.password, core_theme.AC.err),
      _numRow(
        'الحد الأدنى للطول',
        (pwd['min_length'] ?? 12) as int,
        (v) => _updateExtrasSection('security', {
          'password': {...pwd, 'min_length': v}
        }),
        min: 6,
        max: 64,
        suffix: ' حرف',
      ),
      _switchRow(
        'تتطلب حرف كبير',
        pwd['require_upper'] != false,
        (v) => _updateExtrasSection('security', {
          'password': {...pwd, 'require_upper': v}
        }),
      ),
      _switchRow(
        'تتطلب حرف صغير',
        pwd['require_lower'] != false,
        (v) => _updateExtrasSection('security', {
          'password': {...pwd, 'require_lower': v}
        }),
      ),
      _switchRow(
        'تتطلب رقم',
        pwd['require_digit'] != false,
        (v) => _updateExtrasSection('security', {
          'password': {...pwd, 'require_digit': v}
        }),
      ),
      _switchRow(
        'تتطلب رمز خاص',
        pwd['require_symbol'] != false,
        (v) => _updateExtrasSection('security', {
          'password': {...pwd, 'require_symbol': v}
        }),
      ),
      _numRow(
        'مدة الصلاحية (يوم)',
        (pwd['expire_days'] ?? 90) as int,
        (v) => _updateExtrasSection('security', {
          'password': {...pwd, 'expire_days': v}
        }),
        min: 0,
        max: 365,
        hint: '0 = بلا انتهاء',
      ),
      _numRow(
        'عدم تكرار آخر X كلمات مرور',
        (pwd['no_repeat_last'] ?? 12) as int,
        (v) => _updateExtrasSection('security', {
          'password': {...pwd, 'no_repeat_last': v}
        }),
        min: 0,
        max: 30,
      ),
      const SizedBox(height: 18),
      _sectionHeader('الجلسات', Icons.timer, core_theme.AC.err),
      _numRow(
        'انتهاء الجلسة عند الخمول (دقيقة)',
        (sess['idle_timeout_minutes'] ?? 30) as int,
        (v) => _updateExtrasSection('security', {
          'session': {...sess, 'idle_timeout_minutes': v}
        }),
        min: 5,
        max: 480,
      ),
      _numRow(
        'حد الجلسات المتزامنة',
        (sess['max_concurrent'] ?? 3) as int,
        (v) => _updateExtrasSection('security', {
          'session': {...sess, 'max_concurrent': v}
        }),
        min: 1,
        max: 10,
      ),
      const SizedBox(height: 18),
      _sectionHeader('حماية تسجيل الدخول', Icons.lock_person, core_theme.AC.err),
      _numRow(
        'حد محاولات الفشل قبل الإغلاق',
        (login['max_attempts'] ?? 5) as int,
        (v) => _updateExtrasSection('security', {
          'login': {...login, 'max_attempts': v}
        }),
        min: 3,
        max: 20,
      ),
      _numRow(
        'مدة الإغلاق بعد الفشل (دقيقة)',
        (login['lockout_minutes'] ?? 15) as int,
        (v) => _updateExtrasSection('security', {
          'login': {...login, 'lockout_minutes': v}
        }),
        min: 1,
        max: 1440,
      ),
    ]);
  }

  // ═════════════════════════════════════════════════════════════
  // 7. AUDIT
  // ═════════════════════════════════════════════════════════════

  Widget _auditCategory() {
    final s = _s;
    final archive = _extrasSection('audit')['archive'] is Map
        ? Map<String, dynamic>.from(_extrasSection('audit')['archive'])
        : <String, dynamic>{};
    return ListView(children: [
      _sectionHeader('مستوى تفصيل السجل', Icons.history_edu, core_theme.AC.purple),
      _switchRow(
        'تسجيل كل قراءة للبيانات (كثيف)',
        s['audit_log_reads'] == true,
        (v) => _update({'audit_log_reads': v}),
      ),
      _switchRow(
        'تسجيل التعديلات (قبل/بعد)',
        s['audit_log_writes'] != false,
        (v) => _update({'audit_log_writes': v}),
      ),
      _switchRow(
        'تسجيل محاولات الوصول الفاشلة',
        s['audit_log_failures'] != false,
        (v) => _update({'audit_log_failures': v}),
      ),
      const SizedBox(height: 18),
      _sectionHeader('الاحتفاظ', Icons.archive, core_theme.AC.purple),
      _numRow(
        'مدة الاحتفاظ الرقمية (سنة)',
        (s['retention_years'] ?? 7) as int,
        (v) => _update({'retention_years': v}),
        min: 1,
        max: 30,
        hint: 'ZATCA يتطلّب 7 سنوات على الأقل',
      ),
      _dropdownRow<String>(
        'أرشفة خارجية بعد',
        (archive['after'] ?? 'never') as String,
        const [
          DropdownMenuItem(value: 'never', child: Text('بدون أرشفة')),
          DropdownMenuItem(value: '1y', child: Text('سنة')),
          DropdownMenuItem(value: '2y', child: Text('سنتين')),
          DropdownMenuItem(value: '3y', child: Text('3 سنوات')),
        ],
        (v) => _updateExtrasSection('audit', {
          'archive': {...archive, 'after': v}
        }),
      ),
      _dropdownRow<String>(
        'موقع الأرشفة',
        (archive['location'] ?? 's3') as String,
        const [
          DropdownMenuItem(value: 's3', child: Text('AWS S3')),
          DropdownMenuItem(value: 'glacier', child: Text('AWS Glacier')),
          DropdownMenuItem(value: 'gcs', child: Text('Google Cloud Storage')),
          DropdownMenuItem(value: 'azure', child: Text('Azure Blob')),
        ],
        (v) => _updateExtrasSection('audit', {
          'archive': {...archive, 'location': v}
        }),
      ),
      _switchRow(
        'سجل دائم غير قابل للتعديل (WORM)',
        archive['worm'] == true,
        (v) => _updateExtrasSection('audit', {
          'archive': {...archive, 'worm': v}
        }),
      ),
    ]);
  }

  // ═════════════════════════════════════════════════════════════
  // 8. AI
  // ═════════════════════════════════════════════════════════════

  Widget _aiCategory() {
    final s = _s;
    final ai = _extrasSection('ai');
    return ListView(children: [
      _sectionHeader('نموذج AI', Icons.smart_toy, core_theme.AC.err),
      _switchRow(
        'تفعيل ميزات الذكاء الاصطناعي',
        s['ai_enabled'] != false,
        (v) => _update({'ai_enabled': v}),
      ),
      _dropdownRow<String>(
        'النموذج الافتراضي',
        (s['ai_model'] ?? 'claude-opus-4-7') as String,
        const [
          DropdownMenuItem(
              value: 'claude-opus-4-7', child: Text('Claude Opus 4.7 (الأعلى دقة)')),
          DropdownMenuItem(
              value: 'claude-sonnet-4-6', child: Text('Claude Sonnet 4.6 (متوازن)')),
          DropdownMenuItem(
              value: 'claude-haiku-4-5-20251001',
              child: Text('Claude Haiku 4.5 (الأسرع)')),
          DropdownMenuItem(value: 'none', child: Text('بدون AI')),
        ],
        (v) => _update({'ai_model': v}),
      ),
      _numRow(
        'حد الثقة المطلوب (basis points)',
        (s['ai_confidence_threshold_bp'] ?? 8500) as int,
        (v) => _update({'ai_confidence_threshold_bp': v}),
        min: 5000,
        max: 9900,
        hint: '8500 BP = 85% — المطابقات تُقبل تلقائياً فوق هذا الحد',
      ),
      const SizedBox(height: 18),
      _sectionHeader('تفعيل المزايا', Icons.toggle_on, core_theme.AC.err),
      _switchRow(
        'كاشف الشذوذ في القيود',
        ai['anomaly_detection'] != false,
        (v) => _updateExtrasSection('ai', {'anomaly_detection': v}),
      ),
      _switchRow(
        'المطابقات الذكية (Bank/AR/AP)',
        ai['smart_matching'] != false,
        (v) => _updateExtrasSection('ai', {'smart_matching': v}),
      ),
      _switchRow(
        'المحلل المالي (رؤى دورية)',
        ai['analyst'] != false,
        (v) => _updateExtrasSection('ai', {'analyst': v}),
      ),
      _switchRow(
        'Copilot في كل شاشة',
        ai['copilot'] != false,
        (v) => _updateExtrasSection('ai', {'copilot': v}),
      ),
      _switchRow(
        'اقتراح قيود تلقائية (Auto-JE)',
        ai['auto_suggest_je'] == true,
        (v) => _updateExtrasSection('ai', {'auto_suggest_je': v}),
      ),
    ]);
  }

  // ═════════════════════════════════════════════════════════════
  // 9. BACKUP (in extras.backup)
  // ═════════════════════════════════════════════════════════════

  Widget _backupCategory() {
    final b = _extrasSection('backup');
    final lastAt = b['last_at']?.toString() ?? '—';

    final warnings = <Widget>[];
    if ((b['frequency_hours'] ?? 0) == 0) {
      warnings.add(_warningBanner(
        'لا يوجد جدول نسخ احتياطي مُعَد',
        'اضبط تكرار النسخ (4 ساعات موصى بها) لحماية بياناتك.',
        _err,
      ));
    }
    if (b['encryption'] == false) {
      warnings.add(_warningBanner(
        'التشفير غير مُفعّل',
        'النسخ بدون تشفير تُعرّض بياناتك للاختراق إذا سُرِقت وسائل التخزين.',
        _err,
      ));
    }
    if ((b['location'] ?? '') == 'local') {
      warnings.add(_warningBanner(
        'التخزين محلي فقط — لا يحمي من فشل الخادم',
        'يُنصح بموقع سحابي (S3/GCS) أو نسختين جغرافيتين.',
        core_theme.AC.warn,
      ));
    }

    return ListView(children: [
      if (warnings.isNotEmpty) ...[
        ...warnings,
        const SizedBox(height: 10),
      ],
      _sectionHeader('النسخ الاحتياطي', Icons.backup, core_theme.AC.info),
      _numRow(
        'التكرار (ساعة)',
        (b['frequency_hours'] ?? 4) as int,
        (v) => _updateExtrasSection('backup', {'frequency_hours': v}),
        min: 1,
        max: 168,
        hint: '4 ساعات = 6 نسخ يومياً',
      ),
      _numRow(
        'الاحتفاظ النشط (يوم)',
        (b['retention_days'] ?? 90) as int,
        (v) => _updateExtrasSection('backup', {'retention_days': v}),
        min: 7,
        max: 3650,
      ),
      _dropdownRow<String>(
        'موقع التخزين',
        (b['location'] ?? 'local') as String,
        const [
          DropdownMenuItem(value: 'local', child: Text('محلي (القرص)')),
          DropdownMenuItem(value: 's3', child: Text('AWS S3')),
          DropdownMenuItem(
              value: 's3_multi', child: Text('AWS S3 (نسختان جغرافيتان)')),
          DropdownMenuItem(value: 'gcs', child: Text('Google Cloud Storage')),
          DropdownMenuItem(value: 'azure', child: Text('Azure Blob')),
        ],
        (v) => _updateExtrasSection('backup', {'location': v}),
      ),
      _switchRow(
        'تشفير AES-256 end-to-end',
        b['encryption'] != false,
        (v) => _updateExtrasSection('backup', {'encryption': v}),
      ),
      _switchRow(
        'نسخ المرفقات مع البيانات',
        b['include_attachments'] != false,
        (v) => _updateExtrasSection('backup', {'include_attachments': v}),
      ),
      const SizedBox(height: 18),
      _sectionHeader('الاختبار والاستعادة', Icons.verified, core_theme.AC.info),
      _infoRow(
        'آخر نسخة احتياطية',
        lastAt,
        hint: 'يُحدّث تلقائياً بعد كل نسخة',
      ),
      _infoRow(
        'آخر اختبار استعادة',
        b['last_restore_test']?.toString() ?? 'لم يُختبر',
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: core_theme.AC.warn.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: core_theme.AC.warn.withValues(alpha: 0.4)),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber, color: core_theme.AC.warn, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'الاختبار الدوري للاستعادة يُنصَح به شهرياً لضمان سلامة النسخ.',
              style: TextStyle(color: core_theme.AC.warn, fontSize: 11),
            ),
          ),
        ]),
      ),
    ]);
  }

  // ═════════════════════════════════════════════════════════════
  // 10. REGIONAL
  // ═════════════════════════════════════════════════════════════

  Widget _regionalCategory() {
    final s = _s;
    final r = _extrasSection('regional');
    return ListView(children: [
      _sectionHeader('اللغة والمنطقة الزمنية', Icons.public, core_theme.AC.info),
      _dropdownRow<String>(
        'اللغة الافتراضية',
        (s['default_language'] ?? 'ar-SA') as String,
        const [
          DropdownMenuItem(value: 'ar-SA', child: Text('العربية (السعودية)')),
          DropdownMenuItem(value: 'ar-AE', child: Text('العربية (الإمارات)')),
          DropdownMenuItem(value: 'ar-EG', child: Text('العربية (مصر)')),
          DropdownMenuItem(value: 'en-US', child: Text('English (US)')),
          DropdownMenuItem(value: 'en-GB', child: Text('English (UK)')),
        ],
        (v) => _update({'default_language': v}),
      ),
      _dropdownRow<String>(
        'التقويم',
        (s['default_calendar'] ?? 'gregorian') as String,
        const [
          DropdownMenuItem(value: 'gregorian', child: Text('ميلادي')),
          DropdownMenuItem(value: 'hijri', child: Text('هجري')),
          DropdownMenuItem(
              value: 'both', child: Text('ميلادي + هجري (مزدوج)')),
        ],
        (v) => _update({'default_calendar': v}),
      ),
      _dropdownRow<String>(
        'المنطقة الزمنية',
        (s['default_timezone'] ?? 'Asia/Riyadh') as String,
        const [
          DropdownMenuItem(
              value: 'Asia/Riyadh', child: Text('Asia/Riyadh (UTC+3)')),
          DropdownMenuItem(value: 'Asia/Dubai', child: Text('Asia/Dubai (UTC+4)')),
          DropdownMenuItem(
              value: 'Asia/Kuwait', child: Text('Asia/Kuwait (UTC+3)')),
          DropdownMenuItem(
              value: 'Asia/Qatar', child: Text('Asia/Qatar (UTC+3)')),
          DropdownMenuItem(
              value: 'Asia/Bahrain', child: Text('Asia/Bahrain (UTC+3)')),
          DropdownMenuItem(
              value: 'Africa/Cairo', child: Text('Africa/Cairo (UTC+2)')),
          DropdownMenuItem(value: 'UTC', child: Text('UTC (Z)')),
        ],
        (v) => _update({'default_timezone': v}),
      ),
      const SizedBox(height: 18),
      _sectionHeader('أسبوع العمل', Icons.calendar_today, core_theme.AC.info),
      _workWeekEditor(r['work_week'] is List
          ? List<dynamic>.from(r['work_week'])
          : [true, true, true, true, false, false, true]),
      const SizedBox(height: 18),
      _sectionHeader('التنسيق', Icons.format_align_right, core_theme.AC.info),
      _dropdownRow<String>(
        'تنسيق التاريخ',
        (r['date_format'] ?? 'yyyy-MM-dd') as String,
        const [
          DropdownMenuItem(
              value: 'yyyy-MM-dd', child: Text('YYYY-MM-DD (ISO)')),
          DropdownMenuItem(
              value: 'dd/MM/yyyy', child: Text('DD/MM/YYYY (عربي)')),
          DropdownMenuItem(
              value: 'MM/dd/yyyy', child: Text('MM/DD/YYYY (US)')),
        ],
        (v) => _updateExtrasSection('regional', {'date_format': v}),
      ),
      _dropdownRow<String>(
        'الفاصل العشري',
        (r['decimal_separator'] ?? '.') as String,
        const [
          DropdownMenuItem(value: '.', child: Text('نقطة (1,234.56)')),
          DropdownMenuItem(value: ',', child: Text('فاصلة (1.234,56)')),
        ],
        (v) => _updateExtrasSection('regional', {'decimal_separator': v}),
      ),
      _switchRow(
        'استخدام أرقام عربية (٠١٢٣)',
        r['arabic_digits'] == true,
        (v) => _updateExtrasSection('regional', {'arabic_digits': v}),
      ),
    ]);
  }

  Widget _workWeekEditor(List<dynamic> week) {
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final w = List<bool>.from(week.map((e) => e == true));
    while (w.length < 7) {
      w.add(false);
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(7, (i) {
          final on = w[i];
          return InkWell(
            onTap: () {
              final next = List<bool>.from(w);
              next[i] = !on;
              _updateExtrasSection('regional', {'work_week': next});
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: on ? core_theme.AC.info.withValues(alpha: 0.15) : _navy3,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: on ? core_theme.AC.info : _bdr,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                  on ? Icons.check_circle : Icons.circle_outlined,
                  color: on ? core_theme.AC.info : _td,
                  size: 12,
                ),
                SizedBox(width: 4),
                Text(days[i],
                    style: TextStyle(
                      color: on ? _tp : _ts,
                      fontSize: 11,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    )),
              ]),
            ),
          );
        }),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // 11. THEME (الهوية البصرية) — ربط بنظام core/theme.dart الموجود
  // ═════════════════════════════════════════════════════════════

  Widget _themeCategory() {
    return Consumer(builder: (ctx, ref, _) {
      final settings = ref.watch(appSettingsProvider);
      final currentFamily = core_theme.themeFamilyOf(settings.themeId);
      final isDark = settings.isDarkMode;
      return ListView(children: [
        _sectionHeader('الوضع (Mode)', Icons.brightness_6, Colors.deepOrange),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: _modeCard(
              icon: Icons.light_mode,
              title: 'فاتح',
              subtitle: 'مناسب للإضاءة القوية',
              active: !isDark,
              onTap: () {
                html.window.console.log('[APEX Theme] toggleDarkMode(false)');
                ref.read(appSettingsProvider.notifier).toggleDarkMode(false);
                final newSettings = ref.read(appSettingsProvider);
                html.window.console
                    .log('[APEX Theme] new themeId: ${newSettings.themeId}');
                setState(() {});
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _modeCard(
              icon: Icons.dark_mode,
              title: 'داكن',
              subtitle: 'أريح للعين في الليل',
              active: isDark,
              onTap: () {
                html.window.console.log('[APEX Theme] toggleDarkMode(true)');
                ref.read(appSettingsProvider.notifier).toggleDarkMode(true);
                final newSettings = ref.read(appSettingsProvider);
                html.window.console
                    .log('[APEX Theme] new themeId: ${newSettings.themeId}');
                setState(() {});
              },
            ),
          ),
        ]),
        const SizedBox(height: 18),
        _sectionHeader('اللون الأساسي (Palette)',
            Icons.palette, Colors.deepOrange),
        const SizedBox(height: 4),
        _warningBanner(
          'التبديل الفوري',
          'يُطبَّق على كل شاشات النظام مباشرة ويُحفظ لجلسات قادمة.',
          Colors.deepOrange,
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: core_theme.apexThemeFamilies.map((fam) {
            final selected = fam.id == currentFamily;
            return _paletteCard(fam, selected, () {
              html.window.console.log('[APEX Theme] setThemeFamily: ${fam.id}');
              ref.read(appSettingsProvider.notifier).setThemeFamily(fam.id);
              final newSettings = ref.read(appSettingsProvider);
              html.window.console.log(
                  '[APEX Theme] new themeId=${newSettings.themeId} gold=${core_theme.AC.gold.value.toRadixString(16)}');
              setState(() {});
            });
          }).toList(),
        ),
        const SizedBox(height: 20),
        _sectionHeader(
            'معاينة الهوية الحالية', Icons.visibility, Colors.deepOrange),
        _themePreviewLive(),
      ]);
    });
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? _gold.withValues(alpha: 0.1) : _navy2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? _gold : _bdr,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: active ? _gold : _ts, size: 22),
              const Spacer(),
              if (active)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      color: _gold, shape: BoxShape.circle),
                  child: Icon(Icons.check,
                      color: core_theme.AC.tp, size: 12),
                ),
            ]),
            SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    color: active ? _gold : _tp,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 2),
            Text(subtitle,
                style: TextStyle(color: _ts, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _paletteCard(
      core_theme.ApexThemeFamily fam, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _navy2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? fam.preview : _bdr,
            width: selected ? 3 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: fam.preview,
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2), width: 2),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
            SizedBox(height: 8),
            Text(fam.nameAr,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: _tp,
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _themePreviewLive() {
    // Uses the ACTIVE AC colors so user sees exactly what the app looks like.
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: core_theme.AC.navy,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: core_theme.AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.dashboard, color: core_theme.AC.gold, size: 20),
            const SizedBox(width: 8),
            Text('لوحة البيانات',
                style: TextStyle(
                    color: core_theme.AC.tp,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: core_theme.AC.gold,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('زر أساسي',
                  style: TextStyle(
                      color: core_theme.AC.btnFg,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: core_theme.AC.navy2,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: core_theme.AC.bdr),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('نص أساسي واضح',
                    style: TextStyle(
                        color: core_theme.AC.tp, fontSize: 13)),
                const SizedBox(height: 4),
                Text('نص ثانوي أقل حدة',
                    style: TextStyle(
                        color: core_theme.AC.ts, fontSize: 12)),
                const SizedBox(height: 4),
                Text('نص خافت — hint/placeholder',
                    style: TextStyle(
                        color: core_theme.AC.td, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _livePill('نجح', core_theme.AC.ok),
            _livePill('تحذير', core_theme.AC.warn),
            _livePill('خطأ', core_theme.AC.err),
            _livePill('معلومة', core_theme.AC.info),
          ]),
        ],
      ),
    );
  }

  Widget _livePill(String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: c, fontSize: 11, fontWeight: FontWeight.w700)),
      );

  // ═════════════════════════════════════════════════════════════
  // Shared UI helpers
  // ═════════════════════════════════════════════════════════════

  Widget _warningBanner(String title, String detail, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(
          color == _err ? Icons.error_outline : Icons.warning_amber,
          color: color,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(detail,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.85),
                      fontSize: 10,
                      height: 1.4)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(children: [
        Container(width: 4, height: 20, color: color),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color)),
      ]),
    );
  }

  Widget _infoRow(String label, String value,
      {VoidCallback? onEdit, String? hint}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: _tp, fontSize: 12, fontWeight: FontWeight.w700)),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(hint,
                      style: TextStyle(color: _td, fontSize: 10)),
                ),
            ],
          ),
        ),
        Expanded(
          child: Text(value,
              style: TextStyle(
                  color: _gold, fontSize: 12, fontWeight: FontWeight.w700),
              textAlign: TextAlign.end),
        ),
        if (onEdit != null)
          IconButton(
            icon: Icon(Icons.edit, color: _ts, size: 14),
            onPressed: onEdit,
          ),
      ]),
    );
  }

  Widget _switchRow(String label, bool value, Future<bool> Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(color: _tp, fontSize: 12)),
        ),
        Switch(
          value: value,
          onChanged: (v) => onChanged(v),
          activeColor: _gold,
          activeTrackColor: _gold.withValues(alpha: 0.3),
        ),
      ]),
    );
  }

  Widget _numRow(String label, int value, Future<bool> Function(int) onSave,
      {int min = 0, int max = 999999, String? suffix, String? hint}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: _tp, fontSize: 12, fontWeight: FontWeight.w700)),
              if (hint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(hint,
                      style: TextStyle(color: _td, fontSize: 10)),
                ),
            ],
          ),
        ),
        Text('$value${suffix ?? ''}',
            style: TextStyle(
                color: _gold,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace')),
        IconButton(
          icon: Icon(Icons.edit, color: _ts, size: 14),
          onPressed: () async {
            final ctrl = TextEditingController(text: value.toString());
            final ok = await _dialog<bool>(
              label,
              (setS) => TextField(
                controller: ctrl,
                keyboardType: TextInputType.number,
                style: TextStyle(
                    color: _tp, fontSize: 14, fontFamily: 'monospace'),
                decoration: _inputDecoration(
                    'أدخل قيمة بين $min و $max${suffix ?? ''}'),
              ),
            );
            if (ok == true) {
              final parsed = int.tryParse(ctrl.text.trim());
              if (parsed != null && parsed >= min && parsed <= max) {
                await onSave(parsed);
              } else {
                _snack('القيمة خارج النطاق المسموح', _err);
              }
            }
            ctrl.dispose();
          },
        ),
      ]),
    );
  }

  Widget _dropdownRow<T>(String label, T value,
      List<DropdownMenuItem<T>> items, Future<bool> Function(T) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr),
      ),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: Text(label,
              style: TextStyle(
                  color: _tp, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<T>(
            value: value,
            isDense: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: _navy3,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: _bdr),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: _bdr),
                borderRadius: const BorderRadius.all(Radius.circular(6)),
              ),
            ),
            dropdownColor: _navy3,
            style: TextStyle(color: _tp, fontSize: 12),
            items: items,
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ]),
    );
  }

  Widget _dropdownBox<T>(String label, T value,
      List<DropdownMenuItem<T>> items, ValueChanged<T> onChanged) {
    return DropdownButtonFormField<T>(
      value: value,
      isDense: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _ts, fontSize: 11),
        filled: true,
        fillColor: _navy2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: _bdr),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _bdr),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
      ),
      dropdownColor: _navy3,
      style: TextStyle(color: _tp, fontSize: 12),
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  Widget _emptyCard(String msg) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _navy2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _bdr, style: BorderStyle.solid),
      ),
      alignment: Alignment.center,
      child: Text(msg,
          style: TextStyle(color: _ts, fontSize: 12),
          textAlign: TextAlign.center),
    );
  }

  Widget _dialogField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextField(
          controller: c,
          style: TextStyle(color: _tp, fontSize: 13),
          decoration: _inputDecoration(label),
        ),
      );

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _ts, fontSize: 12),
        filled: true,
        fillColor: _navy3,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: _bdr),
          borderRadius: BorderRadius.circular(6),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _bdr),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: _gold),
          borderRadius: BorderRadius.circular(6),
        ),
      );

  Future<T?> _dialog<T>(String title,
      Widget Function(void Function(void Function()) setS) builder) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: _navy2,
            title: Text(title, style: TextStyle(color: _tp, fontSize: 14)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(child: builder(setS)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('إلغاء', style: TextStyle(color: _ts)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: core_theme.AC.tp),
                onPressed: () => Navigator.pop(ctx, true as T),
                child: Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _navy2,
          title: Text(title, style: TextStyle(color: _tp, fontSize: 14)),
          content: Text(msg, style: TextStyle(color: _ts, fontSize: 12)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: TextStyle(color: _ts)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _err, foregroundColor: _tp),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('تأكيد'),
            ),
          ],
        ),
      ),
    );
    return r == true;
  }

  String _fmtMoney(dynamic v) {
    final n = v is num ? v : num.tryParse(v.toString()) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toString();
  }
}

// Dart import guard for jsonEncode availability if ever used
// ignore: unused_element
void _jsonAvailableGuard() => jsonEncode({'ok': true});

// ═════════════════════════════════════════════════════════════
// Interactive chips — theme-aware + hover/press states
// ═════════════════════════════════════════════════════════════

class _InteractiveChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String? subtitle;
  final VoidCallback onTap;

  const _InteractiveChip({
    required this.icon,
    required this.label,
    required this.color,
    this.subtitle,
    required this.onTap,
  });

  @override
  State<_InteractiveChip> createState() => _InteractiveChipState();
}

class _InteractiveChipState extends State<_InteractiveChip> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    final bgAlpha = _pressed
        ? 0.30
        : _hover
            ? 0.20
            : 0.12;
    final borderAlpha = _hover ? 0.6 : 0.3;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: c.withValues(alpha: bgAlpha),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: c.withValues(alpha: borderAlpha)),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: c.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AnimatedScale(
              scale: _hover ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: Icon(widget.icon, color: c, size: 14),
            ),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                color: c,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (widget.subtitle != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  widget.subtitle!,
                  style: TextStyle(
                    color: c,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _InteractiveIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _InteractiveIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_InteractiveIconButton> createState() => _InteractiveIconButtonState();
}

class _InteractiveIconButtonState extends State<_InteractiveIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final gold = core_theme.AC.gold;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _hover
                  ? gold.withValues(alpha: 0.15)
                  : core_theme.AC.navy3,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _hover ? gold : core_theme.AC.bdr,
                width: _hover ? 1.5 : 1,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              widget.icon,
              color: _hover ? gold : core_theme.AC.ts,
              size: 15,
            ),
          ),
        ),
      ),
    );
  }
}
