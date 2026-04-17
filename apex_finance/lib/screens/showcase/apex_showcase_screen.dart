/// Apex Components Showcase — one-stop demo of every new shared component.
///
/// Reachable via Ctrl+K → "Apex Showcase" or /showcase route.
/// Purpose: let users and reviewers see every new component in isolation
/// without hunting across screens.
library;

import 'package:flutter/material.dart';

import '../../core/apex_auto_save.dart';
import '../../core/apex_data_table.dart';
import '../../core/apex_filter_bar.dart';
import '../../core/apex_form_field.dart';
import '../../core/apex_flexible_columns.dart';
import '../../core/apex_preview_panel.dart';
import '../../core/apex_shimmer.dart';
import '../../core/apex_status_bar.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/design_tokens.dart';
import '../../core/theme.dart';
import '../../core/validators_ui.dart';

class ApexShowcaseScreen extends StatefulWidget {
  const ApexShowcaseScreen({super.key});

  @override
  State<ApexShowcaseScreen> createState() => _ApexShowcaseScreenState();
}

class _ApexShowcaseScreenState extends State<ApexShowcaseScreen> {
  // Sample rows for ApexDataTable demo
  final List<Map<String, dynamic>> _sampleRows = [
    {'id': '1', 'name': 'شركة الأمل', 'balance': 125430.50, 'status': 'نشط'},
    {'id': '2', 'name': 'مؤسسة النجاح', 'balance': 48900.00, 'status': 'معلّق'},
    {'id': '3', 'name': 'شركة الابتكار', 'balance': 250000.00, 'status': 'نشط'},
    {'id': '4', 'name': 'المتجر العصري', 'balance': 15300.75, 'status': 'متأخر'},
    {'id': '5', 'name': 'الورشة الذكية', 'balance': 88200.25, 'status': 'نشط'},
  ];

  ApexFilterState _filterState = const ApexFilterState();
  bool _tableLoading = false;
  final _ibanCtrl = TextEditingController();
  final _vatCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _crCtrl = TextEditingController();

  List<Map<String, dynamic>> get _filtered {
    final q = _filterState.searchText.toLowerCase();
    return _sampleRows.where((r) {
      if (q.isNotEmpty &&
          !r['name'].toString().toLowerCase().contains(q)) {
        return false;
      }
      if (_filterState.activeChipKeys.contains('active_only') &&
          r['status'] != 'نشط') {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _ibanCtrl.dispose();
    _vatCtrl.dispose();
    _amountCtrl.dispose();
    _crCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'معرض مكوّنات APEX',
            actions: [
              ApexToolbarAction(
                label: 'تحميل وهمي',
                icon: Icons.refresh,
                onPressed: () async {
                  setState(() => _tableLoading = true);
                  await Future.delayed(const Duration(seconds: 2));
                  if (mounted) setState(() => _tableLoading = false);
                },
              ),
              ApexToolbarAction(
                label: 'Ctrl+K',
                icon: Icons.keyboard_command_key,
                primary: true,
                onPressed: () {},
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section(
                    '1. ApexDataTable + ApexFilterBar + ApexShimmer',
                    'جدول قابل للفرز + checkboxes + hover + zebra + shimmer loading',
                    _dataTableDemo(),
                  ),
                  _section(
                    '2. ApexShimmer',
                    'Skeleton loaders — Box / Card / Form',
                    _shimmerDemo(),
                  ),
                  _section(
                    '3. ApexFormField + Saudi Validators',
                    'حقول مع semantic validation states (success / error / warning / info)',
                    _formFieldDemo(),
                  ),
                  _section(
                    '4. ApexContextualActions',
                    'شريط الإجراءات السياقي (عند التحديد)',
                    _contextualBarDemo(),
                  ),
                  _section(
                    '5. ApexAutoSave Status',
                    'مؤشر الحفظ التلقائي للنماذج',
                    _autoSaveDemo(),
                  ),
                  _section(
                    '6. ApexStatusBar',
                    'شريط تدفق حالات السجل (Draft → Sent → Paid → ...)',
                    _statusBarDemo(),
                  ),
                  _section(
                    '7. ApexPreviewPanel',
                    'لوحة معاينة يمنى للسجلات (400px) — Xero-style',
                    _previewPanelDemo(),
                  ),
                  _section(
                    '9. ApexFlexibleColumnLayout (3-column)',
                    'SAP Fiori-style master-detail-detail — عمود البداية 25% + التفاصيل 25% + الثانوي 50%',
                    _fclDemo(),
                  ),
                  _section(
                    '8. Command Palette (Cmd+K)',
                    'اضغط Ctrl+K من أي مكان لفتح لوحة الأوامر',
                    _paletteHint(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section wrapper ──

  Widget _section(String title, String subtitle, Widget body) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xxl),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AC.navy4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AC.gold,
              fontSize: AppFontSize.xl,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: TextStyle(color: AC.ts, fontSize: AppFontSize.md),
          ),
          const SizedBox(height: AppSpacing.lg),
          body,
        ],
      ),
    );
  }

  // ── 1. Data Table demo ──
  Widget _dataTableDemo() {
    return Column(
      children: [
        ApexFilterBar(
          chips: const [
            ApexFilterChip(
              key: 'active_only',
              label: 'نشط فقط',
              icon: Icons.check_circle_outline,
            ),
          ],
          onFilterChanged: (s) => setState(() => _filterState = s),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 320,
          child: ApexDataTable<Map<String, dynamic>>(
            loading: _tableLoading,
            showCheckboxes: true,
            columns: [
              ApexColumn(
                key: 'name',
                label: 'العميل',
                flex: 3,
                sortValue: (r) => r['name'].toString(),
                cell: (r) => Text(
                  r['name'].toString(),
                  style: TextStyle(color: AC.tp),
                ),
              ),
              ApexColumn(
                key: 'balance',
                label: 'الرصيد (ر.س)',
                flex: 2,
                numeric: true,
                alignment: AlignmentDirectional.centerEnd,
                sortValue: (r) => r['balance'] as num,
                cell: (r) => Text(
                  formatSarAmount((r['balance'] as num).toDouble()),
                  style: TextStyle(
                    color: AC.tp,
                    fontFamily: 'monospace',
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
              ApexColumn(
                key: 'status',
                label: 'الحالة',
                width: 120,
                sortValue: (r) => r['status'].toString(),
                cell: (r) {
                  final status = r['status'].toString();
                  final color = status == 'نشط'
                      ? AC.ok
                      : status == 'متأخر'
                          ? AC.err
                          : AC.warn;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(color: color, fontSize: AppFontSize.sm),
                    ),
                  );
                },
              ),
            ],
            rows: _filtered,
            onSelectionChanged: (_) {},
          ),
        ),
      ],
    );
  }

  // ── 2. Shimmer demo ──
  Widget _shimmerDemo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Box'),
              SizedBox(height: AppSpacing.sm),
              ApexShimmerBox(height: 40),
              SizedBox(height: AppSpacing.sm),
              ApexShimmerBox(width: 200, height: 14),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        const Expanded(child: ApexShimmerCard()),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: SizedBox(
            height: 200,
            child: ApexShimmerForm(fieldCount: 3),
          ),
        ),
      ],
    );
  }

  // ── 3. Form fields ──
  Widget _formFieldDemo() {
    return Column(
      children: [
        ApexFormField(
          label: 'IBAN سعودي (مثال صحيح: SA03 8000 0000 6080 1016 7519)',
          hint: 'SA…',
          controller: _ibanCtrl,
          validator: validateSaudiIban,
        ),
        const SizedBox(height: AppSpacing.lg),
        ApexFormField(
          label: 'الرقم الضريبي (VAT ZATCA — 15 رقم يبدأ بـ 3 وينتهي بـ 3)',
          hint: '300000000000003',
          controller: _vatCtrl,
          validator: validateSaudiVatNumber,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.lg),
        ApexFormField(
          label: 'مبلغ (ر.س) — فواصل آلاف + حد ٢ عشرية',
          hint: '1,234.56',
          controller: _amountCtrl,
          validator: validateSarAmount,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: AppSpacing.lg),
        ApexFormField(
          label: 'السجل التجاري (10 أرقام، يبدأ بـ 10)',
          hint: '1010000000',
          controller: _crCtrl,
          validator: validateSaudiCR,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  // ── 4. Contextual actions ──
  Widget _contextualBarDemo() {
    return ApexContextualActions(
      count: 3,
      actions: [
        ApexToolbarAction(
          label: 'تصدير',
          icon: Icons.download,
          onPressed: () {},
        ),
        ApexToolbarAction(
          label: 'تغيير الحالة',
          icon: Icons.swap_horiz,
          onPressed: () {},
        ),
        ApexToolbarAction(
          label: 'حذف',
          icon: Icons.delete_outline,
          destructive: true,
          onPressed: () {},
        ),
      ],
      onCancel: () {},
    );
  }

  // ── 5. Auto-save ──
  Widget _autoSaveDemo() {
    return Row(
      children: [
        ApexAutoSaveStatus(
          dirty: false,
          lastSavedAt: DateTime.now().subtract(const Duration(minutes: 2)),
          style: TextStyle(color: AC.ok, fontSize: AppFontSize.md),
        ),
        const SizedBox(width: AppSpacing.xxl),
        ApexAutoSaveStatus(
          dirty: true,
          lastSavedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          style: TextStyle(color: AC.warn, fontSize: AppFontSize.md),
        ),
      ],
    );
  }

  // ── 6. Status bar ──
  Widget _statusBarDemo() {
    return ApexStatusBar(
      steps: const [
        ApexStatusStep(id: 'draft', label: 'مسودة', state: ApexStepState.done),
        ApexStatusStep(id: 'sent', label: 'مُرسلة', state: ApexStepState.done),
        ApexStatusStep(id: 'paid', label: 'مدفوعة', state: ApexStepState.current),
        ApexStatusStep(id: 'archived', label: 'مؤرشفة', state: ApexStepState.upcoming),
      ],
      onStepTap: (step) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tapped: ${step.label}')),
        );
      },
    );
  }

  // ── 7. Preview panel ──
  Widget _previewPanelDemo() {
    return SizedBox(
      height: 400,
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: Text(
                '← لوحة المعاينة',
                style: TextStyle(color: AC.ts, fontSize: AppFontSize.lg),
              ),
            ),
          ),
          ApexPreviewPanel(
            width: 360,
            title: 'فاتورة #INV-2026-0042',
            subtitle: 'شركة الأمل • 2026-04-17',
            statusBadge: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AC.ok.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('مدفوعة',
                  style: TextStyle(color: AC.ok, fontWeight: FontWeight.w600)),
            ),
            actions: [
              ApexToolbarAction(
                label: 'فتح',
                icon: Icons.open_in_new,
                primary: true,
                onPressed: () {},
              ),
              ApexToolbarAction(
                label: 'تحميل PDF',
                icon: Icons.download,
                onPressed: () {},
              ),
            ],
            onClose: () {},
            children: [
              ApexPreviewRow.text('رقم الفاتورة', 'INV-2026-0042'),
              ApexPreviewRow.text('العميل', 'شركة الأمل للتجارة'),
              ApexPreviewRow.text('تاريخ الإصدار', '2026-04-17'),
              ApexPreviewRow.text('تاريخ الاستحقاق', '2026-05-17'),
              ApexPreviewRow(
                label: 'الإجمالي',
                value: Text(
                  '${formatSarAmount(3750.00)} ر.س',
                  style: TextStyle(
                    color: AC.gold,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Divider(),
              Text('الخطوات',
                  style: TextStyle(
                      color: AC.ts, fontSize: AppFontSize.md)),
              const SizedBox(height: AppSpacing.sm),
              ApexStatusBar(
                steps: const [
                  ApexStatusStep(
                      id: 'draft', label: 'مسودة', state: ApexStepState.done),
                  ApexStatusStep(
                      id: 'sent', label: 'مُرسلة', state: ApexStepState.done),
                  ApexStatusStep(
                      id: 'paid', label: 'مدفوعة', state: ApexStepState.current),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 9. Flexible Column Layout ──
  Widget _fclDemo() {
    return SizedBox(
      height: 300,
      child: ApexFlexibleColumnLayout(
        mode: FclMode.endExpanded,
        list: Container(color: AC.navy2, child: Center(child: Text('القائمة', style: TextStyle(color: AC.tp)))),
        detail: Container(color: AC.navy3, child: Center(child: Text('التفاصيل', style: TextStyle(color: AC.tp)))),
        secondary: Container(color: AC.navy2, child: Center(child: Text('ثانوي', style: TextStyle(color: AC.tp)))),
      ),
    );
  }

  // ── 8. Palette hint ──
  Widget _paletteHint() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AC.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.keyboard_command_key, color: AC.gold, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اضغط Ctrl+K (أو Cmd+K على Mac) الآن',
                  style: TextStyle(
                    color: AC.tp,
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '20 أمراً مُسجَّلاً: انتقال، إنشاء، بحث. '
                  'يدعم البحث الفازي مع تطبيع عربي (همزات/تنوين).',
                  style: TextStyle(color: AC.ts, fontSize: AppFontSize.md),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
