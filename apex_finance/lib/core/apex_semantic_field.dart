/// APEX Semantic Field — SAP Fiori-style real-time validation.
///
/// Drop-in TextFormField that switches its border + icon color based on
/// the validator's live return:
///   • null or empty → idle (neutral grey)
///   • ValidationState.info → blue  (hint / optional note)
///   • ValidationState.warning → amber (non-blocking)
///   • ValidationState.error → red (submit blocked)
///   • ValidationState.ok → green (field is valid and populated)
///
/// Validation runs on every change, debounced 250 ms. The field exposes
/// its current state via [controller] so the submit button can gate
/// enabling. Pass in existing [Validator] callbacks from
/// `validators_ui.dart` directly — they just need to return either null
/// (success) or a `ValidationResult`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'theme.dart';

enum ValidationLevel { idle, info, warning, error, ok }

class ValidationResult {
  final ValidationLevel level;
  final String? message;
  const ValidationResult(this.level, [this.message]);

  static const idle = ValidationResult(ValidationLevel.idle);
  static const ok = ValidationResult(ValidationLevel.ok);
  factory ValidationResult.info(String m) => ValidationResult(ValidationLevel.info, m);
  factory ValidationResult.warn(String m) => ValidationResult(ValidationLevel.warning, m);
  factory ValidationResult.error(String m) => ValidationResult(ValidationLevel.error, m);
}

typedef SemanticValidator = ValidationResult Function(String value);

class ApexSemanticField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController? controller;
  final SemanticValidator? validator;
  final bool required;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  final void Function(String)? onChanged;
  final ValueChanged<ValidationResult>? onValidation;

  const ApexSemanticField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.validator,
    this.required = false,
    this.keyboardType,
    this.prefixIcon,
    this.onChanged,
    this.onValidation,
  });

  @override
  State<ApexSemanticField> createState() => _ApexSemanticFieldState();
}

class _ApexSemanticFieldState extends State<ApexSemanticField> {
  late final TextEditingController _c;
  ValidationResult _state = ValidationResult.idle;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _c = widget.controller ?? TextEditingController();
    _c.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _c.removeListener(_onChanged);
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  void _onChanged() {
    widget.onChanged?.call(_c.text);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _runValidator);
  }

  void _runValidator() {
    if (!mounted) return;
    final v = _c.text;
    ValidationResult next;
    if (v.isEmpty) {
      next = widget.required
          ? ValidationResult.error('مطلوب')
          : ValidationResult.idle;
    } else {
      final vr = widget.validator?.call(v);
      next = vr ?? ValidationResult.ok;
    }
    if (next.level != _state.level || next.message != _state.message) {
      setState(() => _state = next);
      widget.onValidation?.call(next);
    }
  }

  Color _colorFor(ValidationLevel lvl) {
    switch (lvl) {
      case ValidationLevel.error:
        return AC.err;
      case ValidationLevel.warning:
        return Colors.amber.shade700;
      case ValidationLevel.info:
        return AC.gold;
      case ValidationLevel.ok:
        return AC.ok;
      case ValidationLevel.idle:
        return AC.bdr;
    }
  }

  IconData? _iconFor(ValidationLevel lvl) {
    switch (lvl) {
      case ValidationLevel.error:
        return Icons.error_outline;
      case ValidationLevel.warning:
        return Icons.warning_amber_outlined;
      case ValidationLevel.info:
        return Icons.info_outline;
      case ValidationLevel.ok:
        return Icons.check_circle_outline;
      case ValidationLevel.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(_state.level);
    final suffix = _iconFor(_state.level);
    return Semantics(
      label: widget.label,
      textField: true,
      child: TextFormField(
        controller: _c,
        keyboardType: widget.keyboardType,
        decoration: InputDecoration(
          labelText: widget.required ? '${widget.label} *' : widget.label,
          hintText: widget.hint,
          prefixIcon: widget.prefixIcon == null
              ? null
              : Icon(widget.prefixIcon, color: color),
          suffixIcon: suffix == null
              ? null
              : Icon(suffix, color: color, size: 18),
          errorText: _state.level == ValidationLevel.error
              ? _state.message
              : null,
          helperText: _state.level == ValidationLevel.warning ||
                  _state.level == ValidationLevel.info
              ? _state.message
              : null,
          helperStyle: TextStyle(color: color, fontSize: AppFontSize.xs),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: color, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(color: color, width: 2),
          ),
        ),
      ),
    );
  }
}
