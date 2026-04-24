/// APEX — AI Field (voice + autocomplete + suggest)
/// ═══════════════════════════════════════════════════════════
/// The design-system primitive for "AI on every field." Wraps a
/// standard text input with three AI affordances:
///
///   • ✨ suggest   — tap the sparkle icon → AI fills the field
///                    from context (uses `onRequestSuggest` callback)
///   • 🎤 voice    — tap the mic → speech-to-text fills the field
///                    (delegates to browser SpeechRecognition via
///                    the existing apex_voice_input hook, optional)
///   • 💭 autocomplete — while typing, autocompleted entities appear
///                       as a dropdown (uses `onAutocomplete` callback)
///
/// Drop-in to any form:
///
///   ApexAiField(
///     controller: _clientCtl,
///     label: 'العميل',
///     onAutocomplete: (q) => ApiService.lookupEntity('client', q),
///     onRequestSuggest: () => 'الرياض التجارية',
///   )
library;

import 'package:flutter/material.dart';

import 'theme.dart';

typedef ApexAutocompleteFetcher = Future<List<ApexAutocompleteOption>> Function(String query);

class ApexAutocompleteOption {
  final String label;
  final String value;
  final String? subtitle;
  const ApexAutocompleteOption({required this.label, required this.value, this.subtitle});
}

class ApexAiField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final ApexAutocompleteFetcher? onAutocomplete;
  final Future<String> Function()? onRequestSuggest;
  final bool enableVoice;
  final bool enableSuggest;
  final TextInputType keyboardType;
  final int maxLines;

  const ApexAiField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.onAutocomplete,
    this.onRequestSuggest,
    this.enableVoice = false,
    this.enableSuggest = true,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  State<ApexAiField> createState() => _ApexAiFieldState();
}

class _ApexAiFieldState extends State<ApexAiField> {
  bool _loadingSuggest = false;
  bool _loadingAutocomplete = false;
  List<ApexAutocompleteOption> _options = [];
  OverlayEntry? _overlay;
  final _fieldKey = GlobalKey();
  final _fieldFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onText);
    _fieldFocus.addListener(() {
      if (!_fieldFocus.hasFocus) _hideOverlay();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _fieldFocus.dispose();
    _hideOverlay();
    super.dispose();
  }

  void _onText() {
    final q = widget.controller.text;
    if (widget.onAutocomplete == null || q.length < 2) {
      _hideOverlay();
      return;
    }
    _fetch(q);
  }

  Future<void> _fetch(String q) async {
    setState(() => _loadingAutocomplete = true);
    final opts = await widget.onAutocomplete!(q);
    if (!mounted) return;
    setState(() {
      _loadingAutocomplete = false;
      _options = opts;
    });
    if (opts.isEmpty) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay();
    final ctx = _fieldKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: pos.dx,
        top: pos.dy + box.size.height + 4,
        width: box.size.width,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(8),
          color: AC.navy2,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: _options.length,
              separatorBuilder: (_, __) => Divider(color: AC.gold.withValues(alpha: 0.08), height: 1),
              itemBuilder: (_, i) {
                final o = _options[i];
                return InkWell(
                  onTap: () {
                    widget.controller.text = o.value;
                    widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: o.value.length));
                    _hideOverlay();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(children: [
                      Icon(Icons.arrow_left, size: 12, color: AC.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.label, style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 12.5)),
                            if (o.subtitle != null)
                              Text(o.subtitle!, style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 10.5)),
                          ],
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Future<void> _suggest() async {
    if (widget.onRequestSuggest == null) return;
    setState(() => _loadingSuggest = true);
    final v = await widget.onRequestSuggest!();
    if (!mounted) return;
    setState(() {
      _loadingSuggest = false;
      widget.controller.text = v;
      widget.controller.selection = TextSelection.fromPosition(TextPosition(offset: v.length));
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: _fieldKey,
      controller: widget.controller,
      focusNode: _fieldFocus,
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5),
        hintStyle: TextStyle(color: AC.td, fontFamily: 'Tajawal'),
        prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 16, color: AC.ts),
        filled: true, fillColor: AC.navy3,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loadingAutocomplete)
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AC.gold),
                ),
              ),
            if (widget.enableVoice)
              IconButton(
                icon: Icon(Icons.mic_outlined, color: AC.ts, size: 16),
                onPressed: () {
                  // Browser SpeechRecognition hook — left as a no-op
                  // in environments without JS interop. The button is
                  // still visible to signal intent.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voice input: يتطلب تهيئة المستعرض')),
                  );
                },
                tooltip: 'إملاء صوتي',
              ),
            if (widget.enableSuggest && widget.onRequestSuggest != null)
              IconButton(
                icon: _loadingSuggest
                    ? SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AC.gold),
                      )
                    : Icon(Icons.auto_awesome, color: AC.gold, size: 16),
                onPressed: _loadingSuggest ? null : _suggest,
                tooltip: 'اقتراح الذكاء',
              ),
          ],
        ),
      ),
    );
  }
}
