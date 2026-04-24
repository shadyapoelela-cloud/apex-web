/// APEX — Multi-currency dashboard
library;

import 'package:flutter/material.dart';

import '../../api_service.dart';
import '../../core/theme.dart';

class MultiCurrencyScreen extends StatefulWidget {
  const MultiCurrencyScreen({super.key});
  @override
  State<MultiCurrencyScreen> createState() => _MultiCurrencyScreenState();
}

class _MultiCurrencyScreenState extends State<MultiCurrencyScreen> {
  bool _loading = true;
  String _displayCurrency = 'SAR';
  Map<String, dynamic>? _snapshot;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final res = await ApiService.aiMultiCurrencyDashboard(displayCurrency: _displayCurrency);
    if (!mounted) return;
    setState(() {
      _snapshot = (res.data?['data'] as Map?)?.cast<String, dynamic>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AC.navy,
        appBar: AppBar(
          backgroundColor: AC.navy2,
          title: const Text('لوحة العملات المتعددة',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w700)),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          ],
        ),
        body: _loading ? const Center(child: CircularProgressIndicator()) : _body(),
      ),
    );
  }

  Widget _body() {
    if (_snapshot == null) {
      return Center(child: Text('لا توجد بيانات', style: TextStyle(color: AC.ts, fontFamily: 'Tajawal')));
    }
    final positions = (_snapshot!['positions'] as List?) ?? [];
    final total = _snapshot!['total_converted'] ?? 0;
    final exposure = _snapshot!['fx_exposure_pct'] ?? 0;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryCard(total, exposure),
          const SizedBox(height: 14),
          Text('المراكز حسب العملة',
              style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (positions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('لا توجد أرصدة بنكية',
                  style: TextStyle(color: AC.ts, fontFamily: 'Tajawal'))),
            ),
          ...positions.map((p) => _positionRow(p as Map)),
        ],
      ),
    );
  }

  Widget _summaryCard(dynamic total, dynamic exposure) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AC.gold.withValues(alpha: 0.15), AC.gold.withValues(alpha: 0.05)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AC.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي النقدية (${_displayCurrency})',
                    style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5)),
                Text('$total',
                    style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 22, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: AC.gold.withValues(alpha: 0.25)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('التعرّض للصرف الأجنبي',
                    style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 11.5)),
                Text('$exposure%',
                    style: TextStyle(
                      color: (exposure as num) > 30 ? AC.err : AC.ok,
                      fontFamily: 'Tajawal', fontSize: 22, fontWeight: FontWeight.w900,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _positionRow(Map p) {
    final pct = (p['pct_of_total'] ?? 0) as num;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('${p['currency']}',
                    style: TextStyle(color: AC.gold, fontFamily: 'Tajawal', fontSize: 12.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${p['balance_native']} ${p['currency']}',
                    style: TextStyle(color: AC.tp, fontFamily: 'Tajawal', fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              Text('≈ ${p['balance_converted']} ${_displayCurrency}',
                  style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (pct / 100).clamp(0, 1).toDouble(),
            backgroundColor: AC.navy3,
            valueColor: AlwaysStoppedAnimation(AC.gold),
            minHeight: 5,
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text('سعر الصرف: ${p['fx_rate']}',
                  style: TextStyle(color: AC.td, fontFamily: 'Tajawal', fontSize: 10.5)),
              const Spacer(),
              Text('${pct.toStringAsFixed(1)}% من الإجمالي',
                  style: TextStyle(color: AC.ts, fontFamily: 'Tajawal', fontSize: 10.5)),
            ],
          ),
        ],
      ),
    );
  }
}
