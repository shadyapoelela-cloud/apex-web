/// APEX — Saudi Payment Methods Grid
/// ═══════════════════════════════════════════════════════════════════════
/// Standard payment-method picker for Saudi market. Order matters:
///   1. Mada (most-used in KSA)
///   2. STC Pay
///   3. Apple Pay
///   4. Visa/Mastercard
///   5. Cash
///   6. Bank Transfer
///
/// Per gap analysis P2 #14 — no SMB competitor offers all four natively.
library;

import 'package:flutter/material.dart';
import 'theme.dart';

enum ApexPaymentMethod { mada, stcPay, applePay, card, cash, bankTransfer }

class ApexPaymentMethodOption {
  final ApexPaymentMethod method;
  final String label;
  final String iconText;
  final Color color;
  const ApexPaymentMethodOption({
    required this.method,
    required this.label,
    required this.iconText,
    required this.color,
  });
}

class ApexSaudiPaymentGrid extends StatelessWidget {
  final ApexPaymentMethod? selected;
  final ValueChanged<ApexPaymentMethod>? onSelected;
  final List<ApexPaymentMethod> enabled;

  const ApexSaudiPaymentGrid({
    super.key,
    this.selected,
    this.onSelected,
    this.enabled = const [
      ApexPaymentMethod.mada,
      ApexPaymentMethod.stcPay,
      ApexPaymentMethod.applePay,
      ApexPaymentMethod.card,
      ApexPaymentMethod.cash,
      ApexPaymentMethod.bankTransfer,
    ],
  });

  static const List<ApexPaymentMethodOption> _allOptions = [
    ApexPaymentMethodOption(
      method: ApexPaymentMethod.mada,
      label: 'مدى',
      iconText: 'مدى',
      color: Color(0xFF84BD00), // Mada green
    ),
    ApexPaymentMethodOption(
      method: ApexPaymentMethod.stcPay,
      label: 'STC Pay',
      iconText: 'STC',
      color: Color(0xFF4F0080), // STC purple
    ),
    ApexPaymentMethodOption(
      method: ApexPaymentMethod.applePay,
      label: 'Apple Pay',
      iconText: '',
      color: Colors.black,
    ),
    ApexPaymentMethodOption(
      method: ApexPaymentMethod.card,
      label: 'بطاقة',
      iconText: '💳',
      color: Color(0xFF1A1F71), // Visa blue
    ),
    ApexPaymentMethodOption(
      method: ApexPaymentMethod.cash,
      label: 'نقداً',
      iconText: '💵',
      color: Color(0xFF2E7D32),
    ),
    ApexPaymentMethodOption(
      method: ApexPaymentMethod.bankTransfer,
      label: 'تحويل بنكي',
      iconText: '🏦',
      color: Color(0xFF1565C0),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final options = _allOptions.where((o) => enabled.contains(o.method)).toList();
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      childAspectRatio: 1.2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: options.map((opt) => _PaymentTile(
        option: opt,
        selected: opt.method == selected,
        onTap: () => onSelected?.call(opt.method),
      )).toList(),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final ApexPaymentMethodOption option;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? option.color.withValues(alpha: 0.20) : AC.navy2,
          border: Border.all(
              color: selected ? option.color : AC.bdr,
              width: selected ? 2 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: option.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: option.method == ApexPaymentMethod.applePay
                  ? const Icon(Icons.apple, color: Colors.white, size: 18)
                  : Text(
                      option.iconText,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              option.label,
              style: TextStyle(
                  color: AC.tp,
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
