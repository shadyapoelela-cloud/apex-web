/// APEX Wave 63 — Document Vault / DMS.
/// Route: /app/platform/docs/vault
///
/// Centralized document management with folders, versioning,
/// and access control.
library;

import 'package:flutter/material.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});
  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  String _currentFolder = 'root';
  String _search = '';

  final _folders = const [
    _Folder('root', null, 'الجذر', 0, []),
    _Folder('finance', 'root', '📁 المالية', 248, ['finance/invoices', 'finance/contracts', 'finance/tax']),
    _Folder('finance/invoices', 'finance', '  📄 الفواتير', 124, []),
    _Folder('finance/contracts', 'finance', '  📄 العقود', 48, []),
    _Folder('finance/tax', 'finance', '  📄 الضرائب', 76, []),
    _Folder('hr', 'root', '📁 الموارد البشرية', 185, ['hr/employees', 'hr/policies']),
    _Folder('hr/employees', 'hr', '  📄 ملفات الموظفين', 152, []),
    _Folder('hr/policies', 'hr', '  📄 السياسات', 33, []),
    _Folder('compliance', 'root', '📁 الامتثال', 92, []),
    _Folder('audit', 'root', '📁 المراجعة', 416, []),
    _Folder('legal', 'root', '📁 القانونية', 64, []),
    _Folder('board', 'root', '📁 مجلس الإدارة', 28, []),
  ];

  final _allDocs = const [
    _Doc('D-2026-0412', 'تقرير المراجعة السنوي 2025.pdf', 'pdf', 'audit', 4.2, '2026-04-18', 'د. عبدالله السهلي', 3, ['موقّع', 'معتمد']),
    _Doc('D-2026-0398', 'فاتورة INV-2026-0512 — أرامكو.pdf', 'pdf', 'finance/invoices', 0.3, '2026-04-12', 'النظام', 1, ['مدفوع']),
    _Doc('D-2026-0385', 'خطاب ارتباط NEOM.docx', 'docx', 'audit', 0.6, '2026-04-08', 'سارة الدوسري', 5, ['مسوّدة']),
    _Doc('D-2026-0380', 'سياسة المشتريات 2026.pdf', 'pdf', 'hr/policies', 1.1, '2026-04-05', 'لينا البكري', 2, ['معتمد', 'ساري']),
    _Doc('D-2026-0372', 'محضر اجتماع المجلس Q1.pdf', 'pdf', 'board', 0.8, '2026-03-28', 'أمين السر', 1, ['موقّع', 'سرّي']),
    _Doc('D-2026-0365', 'عقد SAP License 2025-2027.pdf', 'pdf', 'finance/contracts', 2.4, '2025-04-01', 'قسم القانونية', 1, ['موقّع', 'ساري']),
    _Doc('D-2026-0342', 'إقرار VAT — مارس 2026.xlsx', 'xlsx', 'finance/tax', 0.2, '2026-04-02', 'فهد الشمري', 1, ['مُقدَّم']),
    _Doc('D-2026-0334', 'قوائم مالية مدققة 2024.pdf', 'pdf', 'finance', 3.8, '2025-03-15', 'PwC', 1, ['معتمد']),
    _Doc('D-2026-0321', 'سجل تجاري محدّث.pdf', 'pdf', 'legal', 0.5, '2026-01-10', 'قسم القانونية', 2, ['ساري']),
    _Doc('D-2026-0310', 'دليل الموظف 2026.pdf', 'pdf', 'hr/policies', 5.2, '2026-01-01', 'الموارد البشرية', 4, ['معتمد', 'ساري']),
    _Doc('D-2026-0298', 'مطالبة تأمين طبي #1842.pdf', 'pdf', 'hr/employees', 1.5, '2026-03-15', 'أحمد العتيبي', 1, ['قيد المراجعة']),
    _Doc('D-2026-0285', 'تحليل منافسين Q1.pptx', 'pptx', 'root', 8.5, '2026-04-10', 'الاستراتيجية', 3, ['سرّي']),
  ];

  List<_Doc> get _visibleDocs {
    if (_search.isNotEmpty) {
      return _allDocs.where((d) => d.name.contains(_search)).toList();
    }
    if (_currentFolder == 'root') return _allDocs;
    return _allDocs.where((d) => d.folder.startsWith(_currentFolder)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 300, child: _buildSidebar()),
        Expanded(
          child: Column(
            children: [
              _buildHero(),
              _buildSearchBar(),
              Expanded(child: _buildDocList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return Container(
      margin: const EdgeInsets.only(left: 20, top: 20, bottom: 20, right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                const Icon(Icons.folder, color: Color(0xFFD4AF37), size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('المجلدات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900))),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.create_new_folder, size: 18, color: Color(0xFFD4AF37)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: [
                _folderRow('root', 'جميع الوثائق', _allDocs.length, Icons.inbox),
                const Divider(height: 1),
                for (final f in _folders.where((f) => f.id != 'root'))
                  _folderRow(f.id, f.name, f.count, Icons.folder),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _folderRow(String id, String name, int count, IconData icon) {
    final selected = _currentFolder == id;
    return InkWell(
      onTap: () => setState(() => _currentFolder = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD4AF37).withOpacity(0.12) : null,
          border: Border(
            right: BorderSide(
              color: selected ? const Color(0xFFD4AF37) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? const Color(0xFFD4AF37) : Colors.black87,
                  )),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      margin: const EdgeInsets.only(left: 10, top: 20, right: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF37474F), Color(0xFF546E7A)]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_shared, color: Colors.white, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('خزانة الوثائق',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text('إدارة مركزية للوثائق · نسخ · صلاحيات · سجل التعديلات',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          _heroKpi('وثائق', '1,267', Icons.description),
          const SizedBox(width: 10),
          _heroKpi('مساحة', '24.8 GB', Icons.storage),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.cloud_upload, size: 16),
            label: const Text('رفع جديد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroKpi(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 10, top: 12, right: 20),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'ابحث في الوثائق بالاسم أو المحتوى...',
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _search = ''),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
        onChanged: (v) => setState(() => _search = v),
      ),
    );
  }

  Widget _buildDocList() {
    return ListView(
      padding: const EdgeInsets.only(left: 10, top: 12, right: 20, bottom: 20),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.grey.shade100,
          child: const Row(
            children: [
              SizedBox(width: 28),
              Expanded(flex: 4, child: Text('الاسم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              Expanded(flex: 2, child: Text('المجلد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              Expanded(child: Text('الحجم', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              Expanded(flex: 2, child: Text('آخر تعديل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              Expanded(flex: 2, child: Text('بواسطة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              Expanded(flex: 2, child: Text('علامات', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
              SizedBox(width: 80),
            ],
          ),
        ),
        for (final d in _visibleDocs)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12.withOpacity(0.5))),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _typeColor(d.type).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      d.type.toUpperCase(),
                      style: TextStyle(color: _typeColor(d.type), fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(d.id, style: const TextStyle(fontSize: 10, color: Colors.black54, fontFamily: 'monospace')),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(d.folder, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ),
                Expanded(child: Text('${d.sizeMb} MB', style: const TextStyle(fontSize: 11, fontFamily: 'monospace'))),
                Expanded(
                  flex: 2,
                  child: Text(d.modified, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                ),
                Expanded(flex: 2, child: Text(d.author, style: const TextStyle(fontSize: 11))),
                Expanded(
                  flex: 2,
                  child: Wrap(
                    spacing: 4,
                    children: [
                      for (final t in d.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: _tagColor(t).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(t, style: TextStyle(fontSize: 9, color: _tagColor(t), fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.download, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.share, size: 14),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                      if (d.versions > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text('v${d.versions}',
                              style: const TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'pdf':
        return Colors.red;
      case 'docx':
        return Colors.blue;
      case 'xlsx':
        return Colors.green;
      case 'pptx':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _tagColor(String t) {
    switch (t) {
      case 'معتمد':
      case 'مدفوع':
      case 'ساري':
      case 'موقّع':
      case 'مُقدَّم':
        return Colors.green;
      case 'مسوّدة':
      case 'قيد المراجعة':
        return Colors.orange;
      case 'سرّي':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _Folder {
  final String id;
  final String? parent;
  final String name;
  final int count;
  final List<String> children;
  const _Folder(this.id, this.parent, this.name, this.count, this.children);
}

class _Doc {
  final String id;
  final String name;
  final String type;
  final String folder;
  final double sizeMb;
  final String modified;
  final String author;
  final int versions;
  final List<String> tags;
  const _Doc(this.id, this.name, this.type, this.folder, this.sizeMb, this.modified, this.author, this.versions, this.tags);
}
