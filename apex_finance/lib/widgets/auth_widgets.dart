import 'package:flutter/material.dart';

class AC {
  static const gold = Color(0xFFC9A84C);
  static const navy3 = Color(0xFF0D1829);
  static const tp = Color(0xFFF0EDE6);
  static const ts = Color(0xFF8A8880);
  static const ok = Color(0xFF2ECC8A);
  static const warn = Color(0xFFF0A500);
  static const err = Color(0xFFE05050);
}

/// Password field with show/hide toggle eye icon
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;
  const PasswordField({super.key, required this.controller, this.label = 'كلمة المرور', this.onSubmitted});
  @override State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    obscureText: _obscure,
    style: const TextStyle(color: Colors.white),
    onSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      labelText: widget.label,
      prefixIcon: const Icon(Icons.lock_outline, color: AC.gold, size: 20),
      suffixIcon: IconButton(
        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AC.ts, size: 20),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
      filled: true, fillColor: AC.navy3,
      labelStyle: const TextStyle(color: AC.ts),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold)),
    ),
  );
}

/// Password strength indicator bar
class PasswordStrengthBar extends StatelessWidget {
  final String password;
  const PasswordStrengthBar({super.key, required this.password});

  int get _strength {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return score;
  }

  String get _label {
    if (_strength <= 0) return '';
    if (_strength == 1) return 'ضعيفة جداً';
    if (_strength == 2) return 'ضعيفة';
    if (_strength == 3) return 'متوسطة';
    if (_strength == 4) return 'قوية';
    return 'قوية جداً';
  }

  Color get _color {
    if (_strength <= 0) return Colors.transparent;
    if (_strength == 1) return AC.err;
    if (_strength == 2) return AC.warn;
    if (_strength == 3) return Colors.orange;
    if (_strength == 4) return AC.ok;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) => password.isEmpty ? const SizedBox() : Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(children: [
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(value: _strength / 5, minHeight: 4,
          backgroundColor: AC.navy3, valueColor: AlwaysStoppedAnimation(_color)))),
      const SizedBox(width: 8),
      Text(_label, style: TextStyle(color: _color, fontSize: 11)),
    ]),
  );
}

/// Phone number field with country code selector
class PhoneFieldWithCountryCode extends StatefulWidget {
  final TextEditingController phoneController;
  final ValueChanged<String>? onCountryChanged;
  const PhoneFieldWithCountryCode({super.key, required this.phoneController, this.onCountryChanged});
  @override State<PhoneFieldWithCountryCode> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneFieldWithCountryCode> {
  String _countryCode = '+966';

  static const _codes = [
    {'code': '+966', 'name': 'SA'},
    {'code': '+971', 'name': 'AE'},
    {'code': '+973', 'name': 'BH'},
    {'code': '+968', 'name': 'OM'},
    {'code': '+965', 'name': 'KW'},
    {'code': '+974', 'name': 'QA'},
    {'code': '+20', 'name': 'EG'},
    {'code': '+962', 'name': 'JO'},
    {'code': '+1', 'name': 'US'},
    {'code': '+44', 'name': 'UK'},
  ];

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: _countryCode,
        dropdownColor: AC.navy3,
        style: const TextStyle(color: AC.tp, fontSize: 14),
        items: _codes.map((c) => DropdownMenuItem(
          value: c['code'] as String,
          child: Text((c['name'] as String) + ' ' + (c['code'] as String), style: const TextStyle(fontSize: 13)),
        )).toList(),
        onChanged: (v) {
          setState(() => _countryCode = v!);
          widget.onCountryChanged?.call(v!);
        },
      )),
    ),
    const SizedBox(width: 10),
    Expanded(child: TextField(
      controller: widget.phoneController,
      keyboardType: TextInputType.phone,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: 'رقم الجوال',
        prefixIcon: const Icon(Icons.phone, color: AC.gold, size: 20),
        filled: true, fillColor: AC.navy3,
        labelStyle: const TextStyle(color: AC.ts),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AC.gold)),
      ),
    )),
  ]);
}
