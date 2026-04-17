/// APEX Inline Editable Cell — Odoo 18 / Pennylane-style click-to-edit.
///
/// Wraps any display widget so that a double-click (or long-press on touch)
/// swaps it out for an editor. Call [onSubmit] with the parsed new value
/// when the user presses Enter or the field loses focus. Press Escape to
/// discard. The widget is deliberately lightweight — it does NOT handle
/// persistence; the caller decides what to do with the returned value
/// (typically: PATCH to the API, optimistically update the row).
///
/// Supports text, number (with locale-aware parsing), and enum / dropdown
/// cells out of the box. For fancier editors (date picker, typeahead),
/// pass a custom [editorBuilder].
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';
import 'theme.dart';

enum ApexInlineEditorKind { text, number, dropdown }

class ApexInlineEditable<T> extends StatefulWidget {
  /// What the cell looks like when not editing.
  final Widget display;

  /// The current value. If null, the editor starts empty.
  final T? value;

  /// Called with the new parsed value on submit. Return `true` to accept,
  /// `false` to reject (editor stays open with the entered text). If the
  /// future rejects, editor also stays open.
  final Future<bool> Function(T newValue)? onSubmit;

  /// Static kind — picks a sensible default editor.
  final ApexInlineEditorKind kind;

  /// Required when kind == dropdown.
  final List<T>? options;
  final String Function(T)? optionLabel;

  /// Escape hatch for fancy editors. Return a widget that handles its own
  /// submit/cancel and calls [controller.submit] / [controller.cancel].
  final Widget Function(ApexInlineEditController<T> controller)? editorBuilder;

  /// Optional validator — called before onSubmit. Return null = valid, a
  /// string = error message shown in a tooltip below the editor.
  final String? Function(T value)? validator;

  const ApexInlineEditable({
    super.key,
    required this.display,
    required this.value,
    this.onSubmit,
    this.kind = ApexInlineEditorKind.text,
    this.options,
    this.optionLabel,
    this.editorBuilder,
    this.validator,
  });

  @override
  State<ApexInlineEditable<T>> createState() => _ApexInlineEditableState<T>();
}

class ApexInlineEditController<T> {
  final void Function(T value) submit;
  final VoidCallback cancel;
  const ApexInlineEditController({required this.submit, required this.cancel});
}

class _ApexInlineEditableState<T> extends State<ApexInlineEditable<T>> {
  bool _editing = false;
  bool _busy = false;
  String? _error;
  late final TextEditingController _text;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: _valueToText(widget.value));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _valueToText(T? v) {
    if (v == null) return '';
    if (widget.kind == ApexInlineEditorKind.dropdown &&
        widget.optionLabel != null) {
      return widget.optionLabel!(v);
    }
    return v.toString();
  }

  T? _parseText(String raw) {
    if (widget.kind == ApexInlineEditorKind.number) {
      // Accept Arabic and Latin digits + decimal separators.
      final latin = raw
          .replaceAll('،', ',')
          .replaceAll('٫', '.')
          .replaceAllMapped(RegExp(r'[٠-٩]'), (m) {
            const ar = '٠١٢٣٤٥٦٧٨٩';
            return ar.indexOf(m[0]!).toString();
          })
          .replaceAll(',', '');
      final n = num.tryParse(latin);
      return n as T?;
    }
    return raw as T?;
  }

  Future<void> _commit(T v) async {
    final err = widget.validator?.call(v);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final cb = widget.onSubmit;
    if (cb == null) {
      setState(() => _editing = false);
      return;
    }
    setState(() => _busy = true);
    try {
      final ok = await cb(v);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (ok) {
          _editing = false;
          _error = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _error = null;
      _text.text = _valueToText(widget.value);
    });
  }

  void _enter() {
    if (widget.onSubmit == null) return;
    setState(() {
      _editing = true;
      _text.text = _valueToText(widget.value);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return Semantics(
        label: 'خلية قابلة للتعديل. انقر مرتين للتحرير.',
        button: widget.onSubmit != null,
        child: GestureDetector(
          onDoubleTap: _enter,
          onLongPress: _enter,
          behavior: HitTestBehavior.opaque,
          child: widget.display,
        ),
      );
    }

    if (widget.editorBuilder != null) {
      return widget.editorBuilder!(ApexInlineEditController<T>(
        submit: _commit,
        cancel: _cancel,
      ));
    }

    if (widget.kind == ApexInlineEditorKind.dropdown &&
        widget.options != null) {
      return DropdownButton<T>(
        value: widget.value,
        isDense: true,
        items: [
          for (final opt in widget.options!)
            DropdownMenuItem(
              value: opt,
              child: Text(widget.optionLabel?.call(opt) ?? opt.toString()),
            ),
        ],
        onChanged: _busy ? null : (v) { if (v != null) _commit(v); },
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _cancel,
      },
      child: Focus(
        child: TextField(
          controller: _text,
          focusNode: _focus,
          enabled: !_busy,
          autofocus: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: AC.gold, width: 1),
            ),
            errorText: _error,
            suffixIcon: _busy
                ? const Padding(
                    padding: EdgeInsets.all(6),
                    child: SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          keyboardType: widget.kind == ApexInlineEditorKind.number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          style: const TextStyle(fontSize: AppFontSize.sm),
          onSubmitted: (raw) {
            final parsed = _parseText(raw);
            if (parsed == null && raw.isNotEmpty) {
              setState(() => _error = 'قيمة غير صالحة');
              return;
            }
            if (parsed != null) _commit(parsed);
          },
          onTapOutside: (_) {
            if (!_busy && _editing) _cancel();
          },
        ),
      ),
    );
  }
}
