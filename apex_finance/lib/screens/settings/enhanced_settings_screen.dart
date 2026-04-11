import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../core/session.dart';
import '../../api_service.dart';
import '../../providers/app_providers.dart';

class EnhancedSettingsScreen extends ConsumerStatefulWidget {
  const EnhancedSettingsScreen({super.key});
  @override ConsumerState<EnhancedSettingsScreen> createState() => _SettState();
}

class _SettState extends ConsumerState<EnhancedSettingsScreen> {
  bool _notifications = true;
  bool _emailNotifs = true;
  bool _smsNotifs = false;
  bool _twoFactor = false;
  String _region = 'SA';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  String _name = '';
  String _email = '';
  String _mobile = '';

  Future<void> _loadProfile() async {
    _name = S.dname ?? S.uname ?? '';
    _email = S.email ?? '';
    try {
      final r = await ApiService.getProfile();
      if (r.success && r.data is Map) {
        final d = r.data as Map;
        setState(() {
          _name = d['display_name'] ?? d['username'] ?? _name;
          _email = d['email'] ?? _email;
          _mobile = d['mobile'] ?? '';
        });
      }
    } catch (_) {}
  }

  void _logout() {
    S.clear();
    ApiService.setToken('');
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: const Text('\u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u062d\u0633\u0627\u0628', style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _sectionCard('\u0627\u0644\u0645\u0639\u0644\u0648\u0645\u0627\u062a \u0627\u0644\u0634\u062e\u0635\u064a\u0629', Icons.person, [
          _infoRow('\u0627\u0644\u0627\u0633\u0645', _name.isNotEmpty ? _name : '--'),
          _infoRow('\u0627\u0644\u0628\u0631\u064a\u062f', _email.isNotEmpty ? _email : '--'),
          _infoRow('\u0627\u0644\u062c\u0648\u0627\u0644', _mobile.isNotEmpty ? _mobile : '--'),
          _editButton('\u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0644\u0641 \u0627\u0644\u0634\u062e\u0635\u064a', onTap: () => context.push('/profile/edit', extra: {'display_name': _name, 'email': _email, 'mobile': _mobile})),
        ]),
        _sectionCard('\u0627\u0644\u0623\u0645\u0627\u0646', Icons.security, [
          _toggleRow('\u0627\u0644\u0645\u0635\u0627\u062f\u0642\u0629 \u0627\u0644\u062b\u0646\u0627\u0626\u064a\u0629', _twoFactor, (v) => setState(() => _twoFactor = v)),
          _infoRow('\u0637\u0631\u064a\u0642\u0629 \u0627\u0644\u0645\u0635\u0627\u062f\u0642\u0629', '\u0628\u0631\u064a\u062f \u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a \u2022 Google \u2022 \u0627\u0644\u062c\u0648\u0627\u0644'),
          _editButton('\u062a\u063a\u064a\u064a\u0631 \u0643\u0644\u0645\u0629 \u0627\u0644\u0645\u0631\u0648\u0631', onTap: () => context.push('/password/change')),
        ]),
        _sectionCard('\u0627\u0644\u0625\u0634\u0639\u0627\u0631\u0627\u062a', Icons.notifications, [
          _toggleRow('\u0625\u0634\u0639\u0627\u0631\u0627\u062a \u0627\u0644\u062a\u0637\u0628\u064a\u0642', _notifications, (v) => setState(() => _notifications = v)),
          _toggleRow('\u0625\u0634\u0639\u0627\u0631\u0627\u062a \u0627\u0644\u0628\u0631\u064a\u062f', _emailNotifs, (v) => setState(() => _emailNotifs = v)),
          _toggleRow('\u0625\u0634\u0639\u0627\u0631\u0627\u062a SMS', _smsNotifs, (v) => setState(() => _smsNotifs = v)),
        ]),
        _sectionCard('\u0627\u0644\u0645\u0646\u0637\u0642\u0629 \u0648\u0627\u0644\u0644\u063a\u0629', Icons.language, [
          _dropdownRow('\u0627\u0644\u0644\u063a\u0629', ref.watch(appSettingsProvider).language, {'\u0627\u0644\u0639\u0631\u0628\u064a\u0629': 'ar', 'English': 'en'}, (v) => ref.read(appSettingsProvider.notifier).setLanguage(v!)),
          _dropdownRow('\u0627\u0644\u0645\u0646\u0637\u0642\u0629', _region, {'\u0627\u0644\u0633\u0639\u0648\u062f\u064a\u0629': 'SA', '\u0627\u0644\u0625\u0645\u0627\u0631\u0627\u062a': 'AE', '\u0645\u0635\u0631': 'EG'}, (v) => setState(() => _region = v!)),
        ]),
        _sectionCard('\u0627\u0644\u0645\u0638\u0647\u0631', Icons.palette, [
          _toggleRow('\u0627\u0644\u0648\u0636\u0639 \u0627\u0644\u062f\u0627\u0643\u0646', ref.watch(appSettingsProvider).isDarkMode, (v) => ref.read(appSettingsProvider.notifier).toggleDarkMode(v)),
        ]),
        const SizedBox(height: 20),
        Center(child: TextButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, color: AC.err),
          label: const Text('\u062a\u0633\u062c\u064a\u0644 \u0627\u0644\u062e\u0631\u0648\u062c', style: TextStyle(color: AC.err)),
        )),
      ]),
    );
  }

  Widget _sectionCard(String title, IconData icon, List<Widget> children) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, color: AC.gold, size: 20),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: AC.gold, fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
      const Divider(color: AC.bdr, height: 20),
      ...children,
    ]),
  );

  Widget _infoRow(String key, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(key, style: const TextStyle(color: AC.ts, fontSize: 13)),
      Text(val, style: const TextStyle(color: AC.tp, fontSize: 13)),
    ]),
  );

  Widget _toggleRow(String label, bool value, Function(bool) onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AC.tp, fontSize: 13)),
      Switch(value: value, onChanged: onChanged, activeColor: AC.gold),
    ]),
  );

  Widget _dropdownRow(String label, String value, Map<String, String> opts, Function(String?) onChanged) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AC.tp, fontSize: 13)),
      DropdownButton<String>(
        value: value,
        dropdownColor: AC.navy2,
        style: const TextStyle(color: AC.tp, fontSize: 13),
        underline: const SizedBox(),
        items: opts.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList(),
        onChanged: onChanged,
      ),
    ]),
  );

  Widget _editButton(String text, {VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: SizedBox(width: double.infinity, child: OutlinedButton(
      onPressed: onTap ?? () {},
      style: OutlinedButton.styleFrom(side: const BorderSide(color: AC.gold)),
      child: Text(text, style: const TextStyle(color: AC.gold, fontSize: 12)),
    )),
  );
}
