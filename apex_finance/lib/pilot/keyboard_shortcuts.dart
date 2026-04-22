/// APEX Pilot — Keyboard Shortcuts
///
/// Phase 4.1 — اختصارات لوحة المفاتيح عالمياً (كل الشاشات)
///
/// تُطبَّق على مستوى Scaffold بـ Shortcuts + Actions widgets.
///
/// المعيار العالمي:
///   • NetSuite: Alt+N (new), Ctrl+S (save), Ctrl+F (find)
///   • Odoo: Alt+N, Alt+S, Ctrl+K (navigation)
///   • Shopify: J/K (nav), N (new), / (search)
///
/// اخترنا مزيجاً:
///   • Ctrl+K — Command palette (cmd_k_palette موجود)
///   • Ctrl+S — حفظ الـ dialog الحالي
///   • Ctrl+N — إنشاء جديد
///   • Ctrl+/ — مساعدة
///   • Escape — إغلاق dialog
///   • F2 — تعديل العنصر المحدد
///   • F5 — refresh
///   • Ctrl+P — طباعة
///   • Ctrl+E — export Excel
///   • Alt+L — فتح اللغة
library;

import 'package:flutter/material.dart';
import '../core/theme.dart' as core_theme;
import 'package:flutter/services.dart';

/// Intents — يُستخدمون في ActionHandler
class SaveIntent extends Intent {
  const SaveIntent();
}

class NewItemIntent extends Intent {
  const NewItemIntent();
}

class RefreshIntent extends Intent {
  const RefreshIntent();
}

class PrintIntent extends Intent {
  const PrintIntent();
}

class ExportIntent extends Intent {
  const ExportIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class EditIntent extends Intent {
  const EditIntent();
}

class HelpIntent extends Intent {
  const HelpIntent();
}

/// Global shortcuts map — تُضاف لكل Scaffold عبر Shortcuts widget.
final Map<ShortcutActivator, Intent> pilotShortcuts = <ShortcutActivator, Intent>{
  // Save
  SingleActivator(LogicalKeyboardKey.keyS, control: true): const SaveIntent(),
  // New item
  SingleActivator(LogicalKeyboardKey.keyN, control: true): const NewItemIntent(),
  // Refresh
  SingleActivator(LogicalKeyboardKey.f5): const RefreshIntent(),
  // Print
  SingleActivator(LogicalKeyboardKey.keyP, control: true): const PrintIntent(),
  // Export Excel
  SingleActivator(LogicalKeyboardKey.keyE, control: true): const ExportIntent(),
  // Search
  SingleActivator(LogicalKeyboardKey.slash): const SearchIntent(),
  // Edit selected
  SingleActivator(LogicalKeyboardKey.f2): const EditIntent(),
  // Help
  SingleActivator(LogicalKeyboardKey.slash, control: true): const HelpIntent(),
};

/// Helper widget — يلف الشاشة بـ shortcuts + actions
class PilotShortcutScope extends StatelessWidget {
  final Widget child;
  final VoidCallback? onSave;
  final VoidCallback? onNew;
  final VoidCallback? onRefresh;
  final VoidCallback? onPrint;
  final VoidCallback? onExport;
  final VoidCallback? onSearch;
  final VoidCallback? onEdit;
  final VoidCallback? onHelp;

  const PilotShortcutScope({
    super.key,
    required this.child,
    this.onSave,
    this.onNew,
    this.onRefresh,
    this.onPrint,
    this.onExport,
    this.onSearch,
    this.onEdit,
    this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: pilotShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          if (onSave != null)
            SaveIntent: CallbackAction<SaveIntent>(onInvoke: (_) {
              onSave!();
              return null;
            }),
          if (onNew != null)
            NewItemIntent: CallbackAction<NewItemIntent>(onInvoke: (_) {
              onNew!();
              return null;
            }),
          if (onRefresh != null)
            RefreshIntent: CallbackAction<RefreshIntent>(onInvoke: (_) {
              onRefresh!();
              return null;
            }),
          if (onPrint != null)
            PrintIntent: CallbackAction<PrintIntent>(onInvoke: (_) {
              onPrint!();
              return null;
            }),
          if (onExport != null)
            ExportIntent: CallbackAction<ExportIntent>(onInvoke: (_) {
              onExport!();
              return null;
            }),
          if (onSearch != null)
            SearchIntent: CallbackAction<SearchIntent>(onInvoke: (_) {
              onSearch!();
              return null;
            }),
          if (onEdit != null)
            EditIntent: CallbackAction<EditIntent>(onInvoke: (_) {
              onEdit!();
              return null;
            }),
          if (onHelp != null)
            HelpIntent: CallbackAction<HelpIntent>(onInvoke: (_) {
              onHelp!();
              return null;
            }),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );
  }
}

/// عرض لوحة اختصارات — dialog يفتح عند Ctrl+/
void showShortcutsHelp(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: core_theme.AC.navy2,
        title: Row(children: [
          Icon(Icons.keyboard, color: core_theme.AC.gold),
          SizedBox(width: 8),
          Text('اختصارات لوحة المفاتيح',
              style: TextStyle(color: Colors.white)),
        ]),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _kbRow('Ctrl + K', 'لوحة الأوامر (Command Palette)'),
              _kbRow('Ctrl + S', 'حفظ'),
              _kbRow('Ctrl + N', 'إنشاء جديد'),
              _kbRow('F5', 'تحديث'),
              _kbRow('Ctrl + P', 'طباعة / PDF'),
              _kbRow('Ctrl + E', 'تصدير Excel'),
              _kbRow('/', 'بحث'),
              _kbRow('F2', 'تعديل العنصر المحدّد'),
              _kbRow('Escape', 'إغلاق'),
              _kbRow('Ctrl + /', 'عرض هذه النافذة'),
            ],
          ),
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: core_theme.AC.gold,
                foregroundColor: core_theme.AC.tp),
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    ),
  );
}

Widget _kbRow(String keys, String action) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: core_theme.AC.navy3,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0x55FFFFFF)),
        ),
        child: Text(keys,
            style: TextStyle(
                color: core_theme.AC.gold,
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700)),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Text(action,
            style: TextStyle(color: core_theme.AC.ts, fontSize: 13)),
      ),
    ]),
  );
}
