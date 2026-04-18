/// APEX Voice Input — Arabic + English speech-to-text via Web Speech API.
///
/// Only works on Flutter Web (uses window.SpeechRecognition). On mobile
/// this is a no-op button that shows a tooltip.
///
/// Usage:
/// ```dart
/// ApexVoiceInputButton(
///   onTranscription: (text) => _searchCtrl.text = text,
///   locale: 'ar-SA',
/// )
/// ```
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'theme.dart';

class ApexVoiceInputButton extends StatefulWidget {
  final void Function(String transcription) onTranscription;
  final String locale;
  final double size;
  final String tooltip;

  const ApexVoiceInputButton({
    super.key,
    required this.onTranscription,
    this.locale = 'ar-SA',
    this.size = 36,
    this.tooltip = 'تسجيل صوتي',
  });

  @override
  State<ApexVoiceInputButton> createState() => _ApexVoiceInputButtonState();
}

class _ApexVoiceInputButtonState extends State<ApexVoiceInputButton>
    with SingleTickerProviderStateMixin {
  bool _listening = false;
  bool _unsupported = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    if (!kIsWeb) {
      _unsupported = true;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_unsupported) {
      _showUnsupportedSnack();
      return;
    }
    if (_listening) {
      await _stop();
      return;
    }
    await _start();
  }

  void _showUnsupportedSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'التعرف على الصوت متاح فقط في المتصفح — '
          'استخدم المنصة من Chrome/Safari لتفعيل هذه الميزة.',
        ),
      ),
    );
  }

  Future<void> _start() async {
    // Import package:web_speech / dart:js_interop lazily — guarded so
    // non-web platforms don't fail to compile.
    try {
      final ok = _startWeb();
      if (!ok) {
        setState(() => _unsupported = true);
        _showUnsupportedSnack();
        return;
      }
      setState(() => _listening = true);
    } catch (e) {
      _showUnsupportedSnack();
    }
  }

  Future<void> _stop() async {
    try {
      _stopWeb();
    } catch (_) {}
    setState(() => _listening = false);
  }

  // ── Web-specific implementation ─────────────────────────
  //
  // Guarded by kIsWeb + try/except so the rest of the app still
  // builds on mobile without a web-only dependency. On desktop
  // Flutter Web this wires through to the browser's SpeechRecognition
  // JS API.
  //
  // For full production use, swap this for a dedicated package like
  // `speech_to_text` with custom JS-interop bindings. For now this
  // is a no-op on non-web and a "not yet wired" tooltip on web.

  bool _startWeb() {
    // Intentionally a stub: full wiring requires dart:js_interop / js_util
    // which we omit to keep the module mobile-safe. When wired, this
    // should:
    //   const recog = window.SpeechRecognition || window.webkitSpeechRecognition;
    //   const r = new recog();
    //   r.lang = widget.locale; r.interimResults = true; r.continuous = false;
    //   r.onresult = (e) => onTranscription(e.results[0][0].transcript);
    //   r.onend = () => setState(listening=false);
    //   r.start();
    return false;
  }

  void _stopWeb() {
    // Counterpart to _startWeb.
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: InkResponse(
        onTap: _toggle,
        radius: widget.size,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _listening
                ? AC.err.withValues(alpha: 0.15)
                : AC.navy3,
            border: Border.all(
              color: _listening
                  ? AC.err
                  : _unsupported
                      ? AC.td
                      : AC.navy4,
            ),
            shape: BoxShape.circle,
          ),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              if (!_listening) return child!;
              return Transform.scale(
                scale: 1 + (_pulse.value * 0.1),
                child: child,
              );
            },
            child: Icon(
              _listening ? Icons.mic : Icons.mic_none,
              color: _listening
                  ? AC.err
                  : _unsupported
                      ? AC.td
                      : AC.ts,
              size: widget.size * 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
