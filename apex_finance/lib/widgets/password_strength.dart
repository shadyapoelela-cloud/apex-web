import 'package:flutter/material.dart';
import '../../core/theme.dart';

class PasswordStrengthMeter extends StatelessWidget {
  final String password;
  const PasswordStrengthMeter({super.key, required this.password});

  int get _strength {
    int s = 0;
    if (password.length >= 8) s++;
    if (password.length >= 12) s++;
    if (RegExp(r'[A-Z]').hasMatch(password)) s++;
    if (RegExp(r'[0-9]').hasMatch(password)) s++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) s++;
    return s;
  }

  String get _label => ['\u0636\u0639\u064a\u0641\u0629 \u062c\u062f\u0627\u064b', '\u0636\u0639\u064a\u0641\u0629', '\u0645\u0642\u0628\u0648\u0644\u0629', '\u062c\u064a\u062f\u0629', '\u0642\u0648\u064a\u0629'][_strength.clamp(0, 4)];
  Color get _color => [AC.err, AC.err, AC.warn, AC.ok, AC.cyan][_strength.clamp(0, 4)];

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Row(children: List.generate(5, (i) => Expanded(child: Container(
        height: 4, margin: const EdgeInsets.only(left: 3),
        decoration: BoxDecoration(color: i < _strength ? _color : AC.navy4, borderRadius: BorderRadius.circular(2)),
      )))),
      const SizedBox(height: 4),
      Text(_label, style: TextStyle(color: _color, fontSize: 11)),
    ]);
  }
}
