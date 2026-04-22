/// APEX Platform — Journal Entries Screen
/// ═══════════════════════════════════════════════════════════════
/// Lets a user:
///  - peek the current JE counter for a (client, fiscal-year)
///  - reserve the next gap-free JE number (ZATCA-compliant)
///
/// The counter is strictly monotonic per (client, fiscal_year).
/// Numbers that fail to post must NOT be reused — this is ZATCA-correct.
library;

import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/apex_sticky_toolbar.dart';
import '../../core/theme.dart';

class JournalEntriesScreen extends StatefulWidget {
  const JournalEntriesScreen({super.key});
  @override
  State<JournalEntriesScreen> createState() => _JournalEntriesScreenState();
}

class _JournalEntriesScreenState extends State<JournalEntriesScreen> {
  final _clientC = TextEditingController();
  final _yearC = TextEditingController(text: DateTime.now().year.toString());
  String _prefix = 'JE';
  static final List<String> _prefixes = ['JE', 'ADJ', 'CLR', 'OPE', 'REV'];

  String? _error;
  bool _loading = false;
  Map<String, dynamic>? _peekData;
  final List<Map<String, dynamic>> _reserved = [];

  @override
  void dispose() {
    _clientC.dispose();
    _yearC.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_clientC.text.trim().isEmpty) return 'معرّف العميل مطلوب';
    final y = _yearC.text.trim();
    if (y.length != 4 || int.tryParse(y) == null) {
      return 'السنة المالية يجب أن تكون 4 أرقام';
    }
    return null;
  }

  Future<void> _peek() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiService.jePeek(
        clientId: _clientC.text.trim(),
        fiscalYear: _yearC.text.trim(),
      );
      if (r.success && r.data is Map) {
        setState(() => _peekData = (r.data['data'] ?? r.data) as Map<String, dynamic>);
      } else {
        setState(() => _error = r.error ?? 'فشل الاستعلام');
      }
    } catch (e) {
      setState(() => _error = 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reserve() async {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiService.jeReserveNext(
        clientId: _clientC.text.trim(),
        fiscalYear: _yearC.text.trim(),
        prefix: _prefix,
      );
      if (r.success && r.data is Map) {
        final d = (r.data['data'] ?? r.data) as Map<String, dynamic>;
        setState(() {
          _reserved.insert(0, d);
          _peekData = {
            'client_id': d['client_id'],
            'fiscal_year': d['fiscal_year'],
            'last_number': d['sequence'],
            'prefix': d['prefix'],
          };
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AC.ok,
              content: Text('تم حجز الرقم ${d['number']}',
                style: const TextStyle(color: Colors.white)),
            ),
          );
        }
      } else {
        setState(() => _error = r.error ?? 'فشل حجز الرقم');
      }
    } catch (e) {
      setState(() => _error = 'خطأ: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      body: Column(
        children: [
          ApexStickyToolbar(
            title: 'أرقام القيود (ZATCA)',
            actions: [
              ApexToolbarAction(
                label: 'استعلام',
                icon: Icons.search,
                onPressed: _loading ? null : _peek,
              ),
            ],
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _infoBanner(),
                  const SizedBox(height: 16),
                  _inputCard(),
                  const SizedBox(height: 16),
                  if (_error != null) _errorBanner(_error!),
                  const SizedBox(height: 8),
                  if (_peekData != null) _peekCard(),
                  const SizedBox(height: 16),
                  _reservedList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AC.gold.withValues(alpha: 0.06),
      border: Border.all(color: AC.gold.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(Icons.shield_outlined, color: AC.gold, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'الترقيم متسلسل بدون فجوات — مطلب هيئة الزكاة والضريبة (ZATCA Phase 2). '
            'الأرقام المحجوزة لا تُعاد حتى لو لم تُرحَّل.',
            style: TextStyle(color: AC.tp, fontSize: 12, height: 1.5),
          ),
        ),
      ],
    ),
  );

  Widget _inputCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AC.navy2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AC.bdr),
    ),
    child: Column(
      children: [
        TextField(
          controller: _clientC,
          style: TextStyle(color: AC.tp),
          decoration: _input('معرّف العميل (UUID أو Code)', Icons.business),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _yearC,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: TextStyle(color: AC.tp),
                decoration: _input('السنة المالية', Icons.calendar_today).copyWith(counterText: ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _prefix,
                decoration: _input('بادئة الترقيم', Icons.tag),
                dropdownColor: AC.navy2,
                style: TextStyle(color: AC.tp, fontSize: 14),
                items: _prefixes.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) { if (v != null) setState(() => _prefix = v); },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _peek,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('اطلّع على العدّاد (Peek)'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _reserve,
                icon: _loading
                    ? const SizedBox(height: 16, width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.confirmation_number),
                label: const Text('احجز الرقم التالي'),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _peekCard() {
    final p = _peekData!;
    final seq = p['last_number'] ?? 0;
    final prefix = p['prefix'] ?? _prefix;
    final year = p['fiscal_year'] ?? '';
    final nextHint = '$prefix-$year-${(seq + 1).toString().padLeft(5, "0")}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AC.bdr),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('حالة العدّاد', style: TextStyle(color: AC.gold, fontWeight: FontWeight.w700)),
          Divider(color: AC.bdr, height: 18),
          _kv('العميل', (p['client_id'] ?? '').toString()),
          _kv('السنة المالية', year.toString()),
          _kv('آخر رقم محجوز', seq.toString(), vc: AC.goldText),
          _kv('الرقم التالي المتوقّع', nextHint, vc: AC.ok),
        ],
      ),
    );
  }

  Widget _reservedList() {
    if (_reserved.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'لا توجد أرقام محجوزة في هذه الجلسة بعد',
            style: TextStyle(color: AC.ts, fontSize: 13),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('أرقام محجوزة في هذه الجلسة (${_reserved.length})',
            style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700)),
        ),
        ..._reserved.map((e) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AC.navy2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AC.bdr),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AC.ok, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${e['number']}',
                      style: TextStyle(color: AC.tp, fontWeight: FontWeight.w700, fontSize: 15)),
                    Text('تسلسل: ${e['sequence']}  ·  ${e['client_id']}',
                      style: TextStyle(color: AC.ts, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _errorBanner(String msg) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AC.err.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AC.err.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, color: AC.err, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(color: AC.err, fontSize: 13))),
      ],
    ),
  );

  InputDecoration _input(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: AC.goldText, size: 20),
    filled: true,
    fillColor: AC.navy3,
    labelStyle: TextStyle(color: AC.ts),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AC.goldText),
    ),
  );

  Widget _kv(String k, String v, {Color? vc}) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: TextStyle(color: AC.ts, fontSize: 13)),
        Flexible(
          child: Text(v,
            style: TextStyle(color: vc ?? AC.tp, fontSize: 13, fontFamily: 'monospace'),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}
