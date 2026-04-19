/// APEX V5.2 — Form Wizard Template (T3 from 10-round synthesis).
///
/// Multi-step form with progress indicator, validation per step, and
/// "Save as Draft" support — used for:
///   - Onboarding Journeys
///   - Tax Return Builder
///   - M&A Deal Room
///   - Audit Engagement Planning
///
/// Inspired by:
///   - Xero onboarding (step-by-step wizard)
///   - QuickBooks tax guide
///   - Workday guided flows (journey with sidebar)
library;

import 'package:flutter/material.dart';

class WizardStep {
  final String labelAr;
  final String? descriptionAr;
  final IconData icon;
  final Widget Function(BuildContext) builder;

  /// Return null if step is valid, or error message if invalid.
  final String? Function()? validate;

  const WizardStep({
    required this.labelAr,
    required this.icon,
    required this.builder,
    this.descriptionAr,
    this.validate,
  });
}

class FormWizardTemplate extends StatefulWidget {
  final String titleAr;
  final String? subtitleAr;
  final List<WizardStep> steps;
  final VoidCallback? onSaveDraft;
  final Future<bool> Function()? onSubmit;
  final VoidCallback? onCancel;

  const FormWizardTemplate({
    super.key,
    required this.titleAr,
    required this.steps,
    this.subtitleAr,
    this.onSaveDraft,
    this.onSubmit,
    this.onCancel,
  });

  @override
  State<FormWizardTemplate> createState() => _FormWizardTemplateState();
}

class _FormWizardTemplateState extends State<FormWizardTemplate> {
  int _currentStep = 0;
  bool _isSubmitting = false;

  static const _gold = Color(0xFFD4AF37);
  static const _navy = Color(0xFF1A237E);

  void _next() {
    // Validate current step
    final err = widget.steps[_currentStep].validate?.call();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
      return;
    }
    if (_currentStep < widget.steps.length - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prev() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  Future<void> _submit() async {
    if (widget.onSubmit == null) return;
    // Validate final step
    final err = widget.steps[_currentStep].validate?.call();
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    final ok = await widget.onSubmit!();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الحفظ بنجاح'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 900;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F6F5),
        body: Column(
          children: [
            _buildHeader(),
            if (isNarrow) _buildStepperHorizontal(),
            Expanded(
              child: Row(
                children: [
                  if (!isNarrow) _buildStepperSidebar(),
                  if (!isNarrow) const VerticalDivider(width: 1),
                  Expanded(child: _buildStepContent()),
                ],
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: widget.onCancel ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.titleAr,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                if (widget.subtitleAr != null)
                  Text(widget.subtitleAr!,
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
          Text(
            'الخطوة ${_currentStep + 1} من ${widget.steps.length}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperSidebar() {
    return Container(
      width: 260,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        itemCount: widget.steps.length,
        itemBuilder: (ctx, i) {
          final step = widget.steps[i];
          final done = i < _currentStep;
          final active = i == _currentStep;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: active
                  ? _gold.withOpacity(0.08)
                  : (done ? Colors.green.withOpacity(0.04) : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: active
                    ? _gold
                    : (done ? Colors.green.withOpacity(0.3) : Colors.grey.shade200),
                width: active ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: done
                        ? Colors.green
                        : (active ? _gold : Colors.grey.shade200),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                                color: active ? Colors.white : Colors.black54,
                                fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.labelAr,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                            color: active ? _navy : Colors.black87),
                      ),
                      if (step.descriptionAr != null)
                        Text(step.descriptionAr!,
                            style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepperHorizontal() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LinearProgressIndicator(
        value: (_currentStep + 1) / widget.steps.length,
        minHeight: 6,
        backgroundColor: Colors.grey.shade200,
        color: _gold,
      ),
    );
  }

  Widget _buildStepContent() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.steps[_currentStep].icon, color: _gold, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.steps[_currentStep].labelAr,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _navy),
                ),
              ),
            ],
          ),
          if (widget.steps[_currentStep].descriptionAr != null) ...[
            const SizedBox(height: 4),
            Text(widget.steps[_currentStep].descriptionAr!,
                style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],
          const SizedBox(height: 20),
          Expanded(child: widget.steps[_currentStep].builder(context)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final isLast = _currentStep == widget.steps.length - 1;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (widget.onSaveDraft != null)
            OutlinedButton.icon(
              onPressed: widget.onSaveDraft,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('حفظ كمسودة'),
            ),
          const Spacer(),
          if (_currentStep > 0)
            OutlinedButton.icon(
              onPressed: _prev,
              icon: const Icon(Icons.arrow_forward, size: 16), // RTL-forward = previous
              label: const Text('السابق'),
            ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : (isLast ? _submit : _next),
            style: FilledButton.styleFrom(backgroundColor: _gold),
            icon: _isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(isLast ? Icons.check_circle : Icons.arrow_back, size: 16), // RTL-back = next
            label: Text(isLast ? 'إتمام' : 'التالي'),
          ),
        ],
      ),
    );
  }
}
