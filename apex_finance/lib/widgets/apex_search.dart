import 'package:flutter/material.dart';
import '../core/theme.dart';

class ApexSearch extends SearchDelegate<String> {
  @override String get searchFieldLabel => 'بحث في APEX...';
  @override ThemeData appBarTheme(BuildContext context) => ThemeData.dark().copyWith(
    appBarTheme: AppBarTheme(backgroundColor: AC.navy2),
    inputDecorationTheme: InputDecorationTheme(hintStyle: TextStyle(color: AC.ts)),
  );
  @override List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  @override Widget buildResults(BuildContext context) => _buildList(context);
  @override Widget buildSuggestions(BuildContext context) => _buildList(context);
  Widget _buildList(BuildContext context) {
      final items = [
        {'ن': 'الرئيسية', 'r': '/home'},
        {'ن': 'Apex Copilot', 'r': '/copilot'},
        {'ن': 'الشركات', 'r': '/clients'},
        {'ن': 'شجرة الحسابات', 'r': '/home'},
        {'ن': 'ميزان المراجعة', 'r': '/financial-ops'},
        {'ن': 'القوائم المالية', 'r': '/financial-ops'},
        {'ن': 'التحليل المالي', 'r': '/home'},
        {'ن': 'المراجعة المحاسبية', 'r': '/audit-workflow'},
        {'ن': 'سوق الخدمات', 'r': '/home'},
        {'ن': 'العقل المعرفي', 'r': '/knowledge-brain'},
        {'ن': 'الأرشيف', 'r': '/archive'},
        {'ن': 'الإعدادات', 'r': '/settings'},
      ];
    final filtered = query.isEmpty ? items : items.where((i) => (i['ن'] as String).contains(query)).toList();
    return Container(color: AC.navy, child: ListView(children: filtered.map((i) => ListTile(
      trailing: Icon(Icons.arrow_forward_ios, color: AC.ts, size: 14),
      title: Text(i['ن'] as String, textAlign: TextAlign.right, style: TextStyle(color: AC.tp, fontSize: 14)),
      onTap: () { close(context, ''); },
    )).toList()));
  }
}
