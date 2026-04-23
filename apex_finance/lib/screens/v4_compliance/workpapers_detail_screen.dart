/// APEX Wave 23 — Audit Workpapers (detailed view).
///
/// CaseWare-class workpaper management: index tree, lead schedules,
/// tick marks, cross-references, roll-forward.
///
/// Route: /app/audit/fieldwork/workpapers (overrides Audit Analytics wave)
library;

import 'package:flutter/material.dart';
import '../../core/theme.dart' as core_theme;

class WorkpapersDetailScreen extends StatefulWidget {
  const WorkpapersDetailScreen({super.key});

  @override
  State<WorkpapersDetailScreen> createState() => _WorkpapersDetailScreenState();
}

class _WorkpapersDetailScreenState extends State<WorkpapersDetailScreen> {
  String _selectedFile = 'A-100';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 280, child: _buildIndexTree()),
        const VerticalDivider(width: 1),
        Expanded(child: _buildWorkpaperView()),
      ],
    );
  }

  Widget _buildIndexTree() {
    return Container(
      color: const Color(0xFFF9FAFB),
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                const Icon(Icons.folder, size: 16, color: Color(0xFF4A148C)),
                const SizedBox(width: 6),
                const Text(
                  'شجرة أوراق العمل',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, size: 14),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
          _treeFolder('A — التخطيط', expanded: true, children: [
            _treeFile('A-100', 'خطاب الارتباط', 'مكتمل', core_theme.AC.ok),
            _treeFile('A-200', 'الأهمية النسبية', 'مكتمل', core_theme.AC.ok),
            _treeFile('A-300', 'تقييم المخاطر', 'مراجعة', core_theme.AC.warn),
          ]),
          _treeFolder('B — الفحص', expanded: true, children: [
            _treeFile('B-100', 'الموجودات — النقدية', 'مكتمل', core_theme.AC.ok),
            _treeFile('B-110', 'مطابقة البنك', 'قيد التنفيذ', core_theme.AC.info),
            _treeFile('B-200', 'الذمم المدينة', 'مكتمل', core_theme.AC.ok),
            _treeFile('B-210', 'تقادم الذمم', 'قيد التنفيذ', core_theme.AC.info),
            _treeFile('B-300', 'المخزون', 'بحاجة بدء', const Color(0xFF6B7280)),
            _treeFile('B-400', 'الأصول الثابتة', 'بحاجة بدء', const Color(0xFF6B7280)),
          ]),
          _treeFolder('C — الالتزامات', children: [
            _treeFile('C-100', 'الذمم الدائنة', 'بحاجة بدء', const Color(0xFF6B7280)),
            _treeFile('C-200', 'المخصصات', 'بحاجة بدء', const Color(0xFF6B7280)),
          ]),
          _treeFolder('D — حقوق الملكية', children: [
            _treeFile('D-100', 'رأس المال', 'بحاجة بدء', const Color(0xFF6B7280)),
          ]),
          _treeFolder('E — الإيرادات والمصروفات', children: [
            _treeFile('E-100', 'اختبارات الإيرادات', 'بحاجة بدء', const Color(0xFF6B7280)),
          ]),
          _treeFolder('Z — إصدار التقرير', children: [
            _treeFile('Z-100', 'مسودة التقرير', 'بحاجة بدء', const Color(0xFF6B7280)),
          ]),
        ],
      ),
    );
  }

  Widget _treeFolder(String name, {bool expanded = false, required List<Widget> children}) {
    return ExpansionTile(
      initiallyExpanded: expanded,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      leading: const Icon(Icons.folder, size: 14, color: Color(0xFF4A148C)),
      title: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      children: children,
    );
  }

  Widget _treeFile(String id, String name, String status, Color color) {
    final active = _selectedFile == id;
    return Padding(
      padding: const EdgeInsets.only(right: 32, left: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFile = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF4A148C).withValues(alpha: 0.1) : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file,
                size: 12,
                color: active ? const Color(0xFF4A148C) : core_theme.AC.ts,
              ),
              const SizedBox(width: 6),
              Text(
                id,
                style: TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w700,
                  color: active ? const Color(0xFF4A148C) : core_theme.AC.ts,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkpaperView() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            border: Border(bottom: BorderSide(color: core_theme.AC.tp.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              const Icon(Icons.description, color: Color(0xFF4A148C), size: 18),
              const SizedBox(width: 8),
              Text(
                '$_selectedFile — ${_fileName()}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 12),
              _statusBadge(),
              const Spacer(),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Roll-Forward'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.attach_file, size: 14),
                label: const Text('إرفاق دليل'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.check, size: 14),
                label: const Text('تأشير Completed'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A148C),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _workpaperSection('البيانات الأساسية', [
                  _field('العميل', 'SABIC'),
                  _field('السنة المالية', '2026'),
                  _field('نوع الفحص', 'مراجعة مالية كاملة'),
                  _field('المُعِد', 'خالد أحمد'),
                  _field('المراجع', 'سارة محمود'),
                  _field('الشريك', 'د. عبدالله السالم'),
                ]),
                _workpaperSection('الأهداف', [
                  _bullet('التأكد من اكتمال الأرصدة النقدية والبنكية'),
                  _bullet('مطابقة جميع الحسابات الجارية'),
                  _bullet('التحقق من القيود المؤجّلة والمعلّقة'),
                  _bullet('تقييم مخاطر غسل الأموال'),
                ]),
                _workpaperSection('المخاطر المُحدَّدة', [
                  _riskItem('مخاطر الاكتمال', 'متوسطة', core_theme.AC.warn),
                  _riskItem('مخاطر التقييم', 'منخفضة', core_theme.AC.ok),
                  _riskItem('مخاطر الغش', 'منخفضة', core_theme.AC.ok),
                ]),
                _workpaperSection('إجراءات الفحص', [
                  _procItem('الحصول على كشف حساب بنكي من كل حساب نشط', true),
                  _procItem('مطابقة الأرصدة مع ميزان المراجعة', true),
                  _procItem('فحص المعاملات غير المكتشفة', true),
                  _procItem('تأكيد الحسابات المغلقة', false),
                  _procItem('Benford\'s Law على جميع المعاملات', false),
                ]),
                _workpaperSection('علامات التأشير (Tick Marks)', [
                  _tickMark('✓', 'تم التحقق من الأصل'),
                  _tickMark('✗', 'فارق — يحتاج تفسير'),
                  _tickMark('◊', 'ذكرت في الإدارة'),
                  _tickMark('◯', 'متابعة مطلوبة'),
                  _tickMark('★', 'بند نتيجة'),
                ]),
                _workpaperSection('النتائج', [
                  _finding('NF-001', 'فارق 3,200 ر.س في حساب البنك 6080', 'متوسطة'),
                  _finding('NF-002', 'مُطالبات بدون مستند لـ 12,500 ر.س', 'عالية'),
                  _finding('NF-003', 'قيد عكسي لم يُسجَّل', 'منخفضة'),
                ]),
                _workpaperSection('الخلاصة', [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: core_theme.AC.ok.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: core_theme.AC.ok.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      'الأرصدة النقدية والبنكية مؤكّدة · النتائج لا تمنع إبداء الرأي ·\n'
                      'يوصَى بمتابعة النقاط الثلاث في رسالة الإدارة.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: core_theme.AC.ok),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fileName() {
    switch (_selectedFile) {
      case 'A-100': return 'خطاب الارتباط';
      case 'A-200': return 'الأهمية النسبية';
      case 'B-100': return 'الموجودات — النقدية';
      case 'B-110': return 'مطابقة البنك';
      case 'B-200': return 'الذمم المدينة';
      default: return 'ورقة عمل';
    }
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: core_theme.AC.ok.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 11, color: core_theme.AC.ok),
          SizedBox(width: 4),
          Text('مكتمل', style: TextStyle(fontSize: 11, color: core_theme.AC.ok, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _workpaperSection(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF4A148C))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: core_theme.AC.tp.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(fontSize: 12, color: core_theme.AC.ts))),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF4A148C))),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _riskItem(String name, String level, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.warning, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
            child: Text(level, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _procItem(String proc, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: done ? core_theme.AC.ok : core_theme.AC.ts,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              proc,
              style: TextStyle(fontSize: 12, decoration: done ? TextDecoration.lineThrough : null, color: done ? core_theme.AC.ts : core_theme.AC.tp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tickMark(String symbol, String meaning) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF4A148C).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(symbol, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF4A148C))),
          ),
          const SizedBox(width: 10),
          Text(meaning, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _finding(String id, String desc, String severity) {
    final color = severity == 'عالية'
        ? const Color(0xFFB91C1C)
        : severity == 'متوسطة'
            ? core_theme.AC.warn
            : core_theme.AC.info;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
            child: Text(id, style: TextStyle(fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(desc, style: const TextStyle(fontSize: 12))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(3)),
            child: Text(severity, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
