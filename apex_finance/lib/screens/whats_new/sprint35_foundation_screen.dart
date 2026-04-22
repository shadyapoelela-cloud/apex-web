/// Sprint 35-36 Foundation demo screen.
///
/// Shows the "power-user" fixes from the UX blueprint:
///   • Inline editing of list cells (Odoo 18 style)
///   • Alt+1..9 keyboard shortcuts
///   • Sticky toolbar + frozen headers (already in ApexDataTable)
///   • Saved filter views hook
library;

import 'package:flutter/material.dart';

import '../../core/apex_data_table.dart';
import '../../core/apex_inline_editable.dart';
import '../../core/apex_recent_items.dart';
import '../../core/apex_saved_views.dart';
import '../../core/apex_semantic_field.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/theme.dart' as core_theme;

class Sprint35FoundationScreen extends StatefulWidget {
  const Sprint35FoundationScreen({super.key});

  @override
  State<Sprint35FoundationScreen> createState() =>
      _Sprint35FoundationScreenState();
}

class _Sprint35FoundationScreenState extends State<Sprint35FoundationScreen> {
  // Filter state for the saved-views demo.
  Map<String, dynamic> _filters = {'status': 'all', 'min_amount': 0};

  @override
  void initState() {
    super.initState();
    // Demonstrate the "recently visited" rail by recording this screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ApexRecentItems.record(
        route: '/sprint35-foundation',
        label: 'ديمو Sprint 35-36',
        icon: Icons.bolt,
      );
    });
  }

  // In-memory invoice list — editable inline.
  final List<_Invoice> _rows = List.generate(12, (i) {
    return _Invoice(
      number: 'INV-${(1000 + i).toString()}',
      client: [
        'شركة الرياض للتجارة',
        'مؤسسة النجم الذهبي',
        'المتحدة للمقاولات',
        'آفاق التقنية',
      ][i % 4],
      amount: 1250.0 + i * 370.5,
      status: ['draft', 'sent', 'paid', 'overdue'][i % 4],
    );
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          const ApexStickyToolbar(title: '🏗️ Sprint 35-36: الأساس'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _banner(),
                  const SizedBox(height: AppSpacing.xl),
                  _shortcutCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _savedViewsCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _validationCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _recentItemsCard(),
                  const SizedBox(height: AppSpacing.xl),
                  _inlineEditCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner() => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AC.gold.withValues(alpha: 0.25), AC.navy2],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.bolt, color: core_theme.AC.warn, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('الأساس — 8 بنود من مخطط UX/UI',
                      style: TextStyle(
                          color: AC.tp,
                          fontSize: AppFontSize.xl,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'تحرير مضمّن + اختصارات Alt+1..9 + شريط ثابت + رؤوس مجمّدة + حفظ تلقائي + تحقق لحظي + عروض مرشّحات + اختصارات وحدات.',
                    style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _shortcutCard() => _card(
        icon: Icons.keyboard_alt_outlined,
        title: 'اختصارات Alt + أرقام',
        body: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: const [
            _ShortcutChip(key_: 'Alt+1', label: 'الرئيسية'),
            _ShortcutChip(key_: 'Alt+2', label: 'لوحة التحكم'),
            _ShortcutChip(key_: 'Alt+3', label: 'قيود اليومية'),
            _ShortcutChip(key_: 'Alt+4', label: 'ZATCA'),
            _ShortcutChip(key_: 'Alt+5', label: 'VAT'),
            _ShortcutChip(key_: 'Alt+6', label: 'مطابقة بنكية'),
            _ShortcutChip(key_: 'Alt+7', label: 'Copilot'),
            _ShortcutChip(key_: 'Alt+8', label: 'المعرفة'),
            _ShortcutChip(key_: 'Alt+9', label: 'ما الجديد'),
            _ShortcutChip(key_: 'Ctrl+K', label: 'Command Palette'),
          ],
        ),
      );

  Widget _savedViewsCard() => _card(
        icon: Icons.bookmark_outline,
        title: 'عروض مرشّحات محفوظة (Saved Views)',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'متصل بـ /api/v1/saved-views — احفظ مجموعة المرشّحات الحالية واستعدها بنقرة واحدة. اضغط "+" لحفظ، ضغطة مطوّلة للحذف.',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AC.navy3,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AC.bdr),
              ),
              child: ApexSavedViewsBar(
                screen: 'sprint35_demo_invoices',
                currentPayload: _filters,
                onApply: (view) {
                  setState(() => _filters = view.payload);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('طُبِّق "${view.name}"'),
                    duration: const Duration(seconds: 2),
                  ));
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'المرشّحات النشطة: ${_filters.toString()}',
              style: TextStyle(
                  color: AC.td,
                  fontSize: AppFontSize.xs,
                  fontFamily: 'monospace'),
            ),
          ],
        ),
      );

  Widget _validationCard() => _card(
        icon: Icons.rule_folder_outlined,
        title: 'تحقق لحظي بألوان دلالية (SAP Fiori style)',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'لكل حقل حدود ملوّنة حسب حالة التحقق: رمادي=خامل، أزرق=معلومة، أصفر=تحذير، أحمر=خطأ، أخضر=صالح.',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
            const SizedBox(height: AppSpacing.md),
            ApexSemanticField(
              label: 'رقم ضريبي (VAT/TRN)',
              hint: '15 رقماً لـ VAT السعودي أو UAE',
              required: true,
              keyboardType: TextInputType.number,
              prefixIcon: Icons.receipt_long,
              validator: (v) {
                if (v.length < 10) {
                  return ValidationResult.warn('أكمل الرقم...');
                }
                if (v.length == 15 && RegExp(r'^\d+$').hasMatch(v)) {
                  return ValidationResult.ok;
                }
                if (!RegExp(r'^\d+$').hasMatch(v)) {
                  return ValidationResult.error('أرقام فقط');
                }
                return ValidationResult.warn('يجب أن يكون 15 رقماً');
              },
            ),
            const SizedBox(height: AppSpacing.md),
            ApexSemanticField(
              label: 'IBAN',
              hint: 'SA...',
              prefixIcon: Icons.account_balance,
              validator: (v) {
                final cleaned = v.replaceAll(' ', '').toUpperCase();
                if (cleaned.length < 4) {
                  return ValidationResult.info('ابدأ بـ رمز الدولة (SA/AE)');
                }
                if (!cleaned.startsWith(RegExp(r'^(SA|AE)'))) {
                  return ValidationResult.error('يجب أن يبدأ بـ SA أو AE');
                }
                if (cleaned.startsWith('SA') && cleaned.length != 24) {
                  return ValidationResult.warn(
                      'IBAN السعودي 24 حرفاً (الحالي ${cleaned.length})');
                }
                if (cleaned.startsWith('AE') && cleaned.length != 23) {
                  return ValidationResult.warn(
                      'IBAN الإماراتي 23 حرفاً (الحالي ${cleaned.length})');
                }
                return ValidationResult.ok;
              },
            ),
          ],
        ),
      );

  Widget _recentItemsCard() => _card(
        icon: Icons.history,
        title: 'الزيارات الأخيرة (Recently Visited)',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'آخر 5 شاشات فتحتَها — محفوظة في localStorage وتعود بعد الإنعاش. جرّب زيارة بعض الشاشات ثم عُد:',
              style: TextStyle(color: AC.ts, fontSize: AppFontSize.sm),
            ),
            const SizedBox(height: AppSpacing.md),
            const ApexRecentRail(horizontal: true),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final it in const [
                  ('/showcase', 'معرض المكونات', Icons.view_headline),
                  ('/whats-new', 'ما الجديد', Icons.rocket_launch),
                  ('/uae-corp-tax', 'UAE Tax', Icons.account_balance),
                  ('/startup-metrics', 'مقاييس', Icons.trending_up),
                  ('/industry-packs', 'حزم الصناعات', Icons.factory),
                ])
                  OutlinedButton.icon(
                    icon: Icon(it.$3, size: 16),
                    label: Text(it.$2),
                    onPressed: () {
                      ApexRecentItems.record(
                        route: it.$1,
                        label: it.$2,
                        icon: it.$3,
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      );

  Widget _inlineEditCard() => _card(
        icon: Icons.edit_note,
        title: 'تحرير مضمّن — انقر مرتين على أي خلية',
        body: ApexDataTable<_Invoice>(
          columns: [
            ApexColumn<_Invoice>(
              key: 'number',
              label: 'رقم الفاتورة',
              cell: (r) => Text(r.number),
              sortValue: (r) => r.number,
              width: 130,
            ),
            ApexColumn<_Invoice>(
              key: 'client',
              label: 'العميل',
              cell: (r) => ApexInlineEditable<String>(
                value: r.client,
                display: Text(r.client,
                    style: TextStyle(color: AC.tp),
                    overflow: TextOverflow.ellipsis),
                onSubmit: (v) async {
                  setState(() => r.client = v);
                  return true;
                },
              ),
              sortValue: (r) => r.client,
              flex: 2,
            ),
            ApexColumn<_Invoice>(
              key: 'amount',
              label: 'المبلغ',
              numeric: true,
              cell: (r) => ApexInlineEditable<num>(
                value: r.amount,
                kind: ApexInlineEditorKind.number,
                display: Text(r.amount.toStringAsFixed(2),
                    style: TextStyle(
                        color: AC.gold,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()])),
                validator: (v) =>
                    v <= 0 ? 'يجب أن يكون المبلغ أكبر من صفر' : null,
                onSubmit: (v) async {
                  setState(() => r.amount = v.toDouble());
                  return true;
                },
              ),
              sortValue: (r) => r.amount,
              width: 140,
            ),
            ApexColumn<_Invoice>(
              key: 'status',
              label: 'الحالة',
              cell: (r) => ApexInlineEditable<String>(
                value: r.status,
                kind: ApexInlineEditorKind.dropdown,
                options: const ['draft', 'sent', 'paid', 'overdue'],
                optionLabel: _statusLabel,
                display: _statusBadge(r.status),
                onSubmit: (v) async {
                  setState(() => r.status = v);
                  return true;
                },
              ),
              sortValue: (r) => r.status,
              width: 130,
            ),
          ],
          rows: _rows,
        ),
      );

  Widget _card(
          {required IconData icon,
          required String title,
          required Widget body}) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AC.bdr),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AC.gold, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Text(title,
                  style: TextStyle(
                      color: AC.tp,
                      fontSize: AppFontSize.lg,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: AppSpacing.md),
            body,
          ],
        ),
      );

  Widget _statusBadge(String s) {
    final (color, label) = switch (s) {
      'paid' => (AC.ok, 'مدفوعة'),
      'sent' => (AC.gold, 'مُرسلة'),
      'overdue' => (AC.err, 'متأخرة'),
      _ => (AC.ts, 'مسودة'),
    };
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: AppFontSize.xs,
              fontWeight: FontWeight.w600)),
    );
  }

  static String _statusLabel(String s) => switch (s) {
        'paid' => 'مدفوعة',
        'sent' => 'مُرسلة',
        'overdue' => 'متأخرة',
        _ => 'مسودة',
      };
}

class _Invoice {
  String number;
  String client;
  double amount;
  String status;
  _Invoice({
    required this.number,
    required this.client,
    required this.amount,
    required this.status,
  });
}

class _ShortcutChip extends StatelessWidget {
  // `key` is reserved by Flutter Widget — use `key_` in the const ctor.
  final String key_;
  final String label;
  const _ShortcutChip({required this.key_, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AC.bdr),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AC.gold.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(key_,
              style: TextStyle(
                  color: AC.gold,
                  fontSize: AppFontSize.xs,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(label, style: TextStyle(color: AC.tp, fontSize: AppFontSize.sm)),
      ]),
    );
  }
}
