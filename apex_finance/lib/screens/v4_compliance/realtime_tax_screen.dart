/// APEX V5.1 — Real-time Tax Demo Screen.
///
/// Showcases the ApexV5RealtimeTax component with:
///   - Live calculation as user types
///   - 8 preset scenarios to test (click to fill)
///   - Arabic explain panel
///   - Export / Apply actions
///
/// Route: /app/compliance/tax/realtime
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

import '../../core/v5/apex_v5_realtime_tax.dart';
import '../../core/v5/apex_v5_undo_toast.dart';

class RealtimeTaxScreen extends StatefulWidget {
  const RealtimeTaxScreen({super.key});

  @override
  State<RealtimeTaxScreen> createState() => _RealtimeTaxScreenState();
}

class _RealtimeTaxScreenState extends State<RealtimeTaxScreen> {
  GccTaxBreakdown? _latest;
  int _taxCalculatorKey = 0;
  final _scenarios = <_Scenario>[
    _Scenario(
      title: 'فاتورة خدمات سعودية للشركات',
      amount: 10000,
      country: 'KSA',
      itemType: 'service',
      customerType: 'business',
    ),
    _Scenario(
      title: 'فاتورة سلع إماراتية',
      amount: 50000,
      country: 'UAE',
      itemType: 'good',
      customerType: 'business',
    ),
    _Scenario(
      title: 'خدمة استشارية — مورد غير مقيم',
      amount: 25000,
      country: 'KSA',
      itemType: 'service',
      customerType: 'non_resident',
    ),
    _Scenario(
      title: 'خدمة مالية معفاة',
      amount: 100000,
      country: 'KSA',
      itemType: 'financial',
      customerType: 'business',
    ),
    _Scenario(
      title: 'فندق دبي',
      amount: 3000,
      country: 'UAE',
      itemType: 'hospitality',
      customerType: 'individual',
    ),
    _Scenario(
      title: 'عقار في البحرين',
      amount: 500000,
      country: 'BH',
      itemType: 'real_estate',
      customerType: 'business',
    ),
    _Scenario(
      title: 'تعليم (معفى)',
      amount: 40000,
      country: 'KSA',
      itemType: 'education',
      customerType: 'individual',
    ),
    _Scenario(
      title: 'خدمة رقمية من غير مقيم',
      amount: 8500,
      country: 'UAE',
      itemType: 'digital',
      customerType: 'non_resident',
    ),
  ];

  _Scenario? _activeScenario;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [core_theme.AC.info, core_theme.AC.ok],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.public, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الأولى عالمياً — حاسبة ضرائب الخليج الفورية',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'VAT · WHT · Zakat · الطوابع · البلدية · 6 دول · تتحسّب مباشرة أثناء الكتابة',
                        style: TextStyle(color: core_theme.AC.ts, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.star, size: 12, color: core_theme.AC.warn),
                      SizedBox(width: 4),
                      Text(
                        'World-First',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Body — 2 columns on wide screens
          LayoutBuilder(
            builder: (ctx, constraints) {
              final wide = constraints.maxWidth > 1000;
              return wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: ApexV5RealtimeTax(
                            key: ValueKey(_taxCalculatorKey),
                            initialAmount: _activeScenario?.amount ?? 10000,
                            initialCountry: _activeScenario?.country ?? 'KSA',
                            initialItemType: _activeScenario?.itemType ?? 'service',
                            initialCustomerType: _activeScenario?.customerType ?? 'business',
                            onChanged: (b) {
                              setState(() => _latest = b);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildSidePanel()),
                      ],
                    )
                  : Column(
                      children: [
                        ApexV5RealtimeTax(
                          key: ValueKey(_taxCalculatorKey),
                          initialAmount: _activeScenario?.amount ?? 10000,
                          initialCountry: _activeScenario?.country ?? 'KSA',
                          initialItemType: _activeScenario?.itemType ?? 'service',
                          initialCustomerType: _activeScenario?.customerType ?? 'business',
                          onChanged: (b) => setState(() => _latest = b),
                        ),
                        const SizedBox(height: 16),
                        _buildSidePanel(),
                      ],
                    );
            },
          ),

          const SizedBox(height: 20),

          // Competitive advantage table
          _buildCompetitiveTable(),
        ],
      ),
    );
  }

  Widget _buildSidePanel() {
    return Column(
      children: [
        _buildScenarios(),
        const SizedBox(height: 12),
        _buildActions(),
      ],
    );
  }

  Widget _buildScenarios() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flash_on, size: 16, color: core_theme.AC.warn),
              SizedBox(width: 6),
              Text(
                'جرّب سيناريو جاهز',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final s in _scenarios)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ScenarioRow(
                scenario: s,
                isActive: _activeScenario == s,
                onTap: () {
                  setState(() {
                    _activeScenario = s;
                    _taxCalculatorKey++;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final canApply = _latest != null && _latest!.total > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تطبيق النتيجة',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canApply
                  ? () {
                      ApexV5UndoToast.show(
                        context,
                        messageAr:
                            'تم إضافة الضريبة إلى الفاتورة — ${_latest!.total.toStringAsFixed(2)} ر.س',
                        onUndo: () {},
                      );
                    }
                  : null,
              icon: const Icon(Icons.receipt_long, size: 16),
              label: Text('تطبيق على فاتورة جديدة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: core_theme.AC.gold,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canApply
                  ? () {
                      ApexV5UndoToast.show(
                        context,
                        messageAr: 'تم تصدير الحساب (PDF)',
                      );
                    }
                  : null,
              icon: const Icon(Icons.download, size: 16),
              label: Text('تصدير PDF'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                ApexV5UndoToast.show(
                  context,
                  messageAr: 'Claude يشرح هذا الحساب بالتفصيل...',
                  icon: Icons.auto_awesome,
                  color: core_theme.AC.purple,
                );
              },
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: Text('اطلب شرحاً من الذكاء'),
              style: TextButton.styleFrom(
                foregroundColor: core_theme.AC.purple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompetitiveTable() {
    final rows = [
      _CompRow('الحساب الفوري أثناء الكتابة', {'APEX': true, 'Avalara': true, 'Vertex': true, 'Wafeq': false, 'Qoyod': false, 'Odoo': false}),
      _CompRow('جميع دول الخليج (6 دول)', {'APEX': true, 'Avalara': false, 'Vertex': true, 'Wafeq': true, 'Qoyod': true, 'Odoo': false}),
      _CompRow('ZATCA Phase 2 integration', {'APEX': true, 'Avalara': false, 'Vertex': false, 'Wafeq': true, 'Qoyod': true, 'Odoo': false}),
      _CompRow('Zakat basis calculation', {'APEX': true, 'Avalara': false, 'Vertex': false, 'Wafeq': true, 'Qoyod': true, 'Odoo': false}),
      _CompRow('WHT للمورّدين غير المقيمين', {'APEX': true, 'Avalara': false, 'Vertex': true, 'Wafeq': false, 'Qoyod': false, 'Odoo': false}),
      _CompRow('التحاسب العكسي تلقائياً', {'APEX': true, 'Avalara': true, 'Vertex': true, 'Wafeq': false, 'Qoyod': false, 'Odoo': false}),
      _CompRow('شرح عربي لكل حساب', {'APEX': true, 'Avalara': false, 'Vertex': false, 'Wafeq': false, 'Qoyod': false, 'Odoo': false}),
      _CompRow('رسم البلدية (UAE)', {'APEX': true, 'Avalara': false, 'Vertex': true, 'Wafeq': false, 'Qoyod': false, 'Odoo': false}),
      _CompRow('رسم الطوابع (BH/OM)', {'APEX': true, 'Avalara': false, 'Vertex': false, 'Wafeq': false, 'Qoyod': false, 'Odoo': false}),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emoji_events, size: 18, color: core_theme.AC.warn),
              SizedBox(width: 6),
              Text(
                'لماذا APEX أفضل من الجميع؟',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            columnWidths: const {
              0: FlexColumnWidth(3),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: core_theme.AC.tp.withValues(alpha: 0.04)),
                children: [
                  const _CompHeader(label: 'الميزة'),
                  _CompHeader(label: 'APEX', color: core_theme.AC.gold),
                  const _CompHeader(label: 'Avalara'),
                  const _CompHeader(label: 'Vertex'),
                  const _CompHeader(label: 'Wafeq'),
                  const _CompHeader(label: 'Qoyod'),
                  const _CompHeader(label: 'Odoo'),
                ],
              ),
              for (final r in rows)
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                      child: Text(
                        r.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    _CompCell(r.values['APEX'] ?? false, highlighted: true),
                    _CompCell(r.values['Avalara'] ?? false),
                    _CompCell(r.values['Vertex'] ?? false),
                    _CompCell(r.values['Wafeq'] ?? false),
                    _CompCell(r.values['Qoyod'] ?? false),
                    _CompCell(r.values['Odoo'] ?? false),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Scenario {
  final String title;
  final double amount;
  final String country;
  final String itemType;
  final String customerType;

  _Scenario({
    required this.title,
    required this.amount,
    required this.country,
    required this.itemType,
    required this.customerType,
  });
}

class _ScenarioRow extends StatefulWidget {
  final _Scenario scenario;
  final bool isActive;
  final VoidCallback onTap;

  const _ScenarioRow({
    required this.scenario,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_ScenarioRow> createState() => _ScenarioRowState();
}

class _ScenarioRowState extends State<_ScenarioRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isActive
                ? core_theme.AC.gold.withValues(alpha: 0.15)
                : _hover
                    ? core_theme.AC.tp.withValues(alpha: 0.03)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: widget.isActive
                ? Border.all(color: core_theme.AC.gold.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.isActive ? Icons.check_circle : Icons.play_circle_outline,
                size: 14,
                color: widget.isActive ? core_theme.AC.gold : core_theme.AC.ts,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.scenario.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${widget.scenario.amount.toStringAsFixed(0)} ر.س',
                style: TextStyle(
                  fontSize: 11,
                  color: core_theme.AC.ts,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompRow {
  final String label;
  final Map<String, bool> values;
  _CompRow(this.label, this.values);
}

class _CompHeader extends StatelessWidget {
  final String label;
  final Color? color;

  const _CompHeader({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color ?? core_theme.AC.tp,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _CompCell extends StatelessWidget {
  final bool value;
  final bool highlighted;

  const _CompCell(this.value, {this.highlighted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: highlighted
          ? BoxDecoration(
              color: core_theme.AC.gold.withValues(alpha: 0.06),
              border: Border(
                left: BorderSide(color: core_theme.AC.gold.withValues(alpha: 0.2)),
                right: BorderSide(color: core_theme.AC.gold.withValues(alpha: 0.2)),
              ),
            )
          : null,
      child: Icon(
        value ? Icons.check : Icons.close,
        size: 16,
        color: value
            ? (highlighted ? core_theme.AC.ok : core_theme.AC.ok)
            : core_theme.AC.td,
      ),
    );
  }
}
