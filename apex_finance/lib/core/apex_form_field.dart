/// APEX Form Field — TextFormField wrapper with semantic states + real-time
/// validation colors.
///
/// Source: SAP Fiori semantic validation colors, Stripe form validation.
///
/// States:
///   - none   → neutral
///   - success → green border + check
///   - warning → orange border + warn icon
///   - error   → red border + X icon
///   - info    → blue border + info icon
library;

import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'theme.dart';

enum ApexFieldState { none, success, warning, error, info }

class ApexFormField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? helperText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool validateOnType;
  final TextInputType keyboardType;
  final bool obscureText;
  final int? maxLength;
  final Widget? prefix;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  const ApexFormField({
    super.key,
    this.label,
    this.hint,
    this.helperText,
    this.controller,
    this.validator,
    this.validateOnType = true,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLength,
    this.prefix,
    this.suffix,
    this.onChanged,
  });

  @override
  State<ApexFormField> createState() => _ApexFormFieldState();
}

class _ApexFormFieldState extends State<ApexFormField> {
  ApexFieldState _state = ApexFieldState.none;
  String? _errorText;
  bool _touched = false;

  void _runValidation(String value) {
    if (widget.validator == null) return;
    if (!widget.validateOnType && !_touched) return;
    final err = widget.validator!(value);
    setState(() {
      _errorText = err;
      _state = err == null
          ? (value.isEmpty ? ApexFieldState.none : ApexFieldState.success)
          : ApexFieldState.error;
    });
  }

  Color _borderColor() {
    return switch (_state) {
      ApexFieldState.success => AC.ok,
      ApexFieldState.warning => AC.warn,
      ApexFieldState.error => AC.err,
      ApexFieldState.info => AC.cyan,
      ApexFieldState.none => AC.navy4,
    };
  }

  IconData? _stateIcon() {
    return switch (_state) {
      ApexFieldState.success => Icons.check_circle_outline,
      ApexFieldState.warning => Icons.warning_amber_outlined,
      ApexFieldState.error => Icons.error_outline,
      ApexFieldState.info => Icons.info_outline,
      ApexFieldState.none => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor();
    final stateIcon = _stateIcon();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              color: AC.ts,
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: widget.obscureText,
            maxLength: widget.maxLength,
            keyboardType: widget.keyboardType,
            style: TextStyle(color: AC.tp, fontSize: AppFontSize.lg),
            onChanged: (v) {
              widget.onChanged?.call(v);
              _runValidation(v);
            },
            onTap: () => _touched = true,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(color: AC.td),
              filled: false,
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              prefixIcon: widget.prefix,
              suffixIcon: stateIcon != null
                  ? Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Icon(stateIcon, color: borderColor, size: 18),
                    )
                  : widget.suffix,
            ),
            validator: (v) {
              final err = widget.validator?.call(v);
              _errorText = err;
              return err;
            },
          ),
        ),
        if (_errorText != null || widget.helperText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _errorText ?? widget.helperText!,
            style: TextStyle(
              color: _errorText != null ? AC.err : AC.td,
              fontSize: AppFontSize.sm,
            ),
          ),
        ],
      ],
    );
  }
}
