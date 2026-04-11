import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../../core/theme.dart';

class NotificationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> notification;
  const NotificationDetailScreen({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, title: Text('\u062a\u0641\u0627\u0635\u064a\u0644 \u0627\u0644\u0625\u0634\u0639\u0627\u0631', style: TextStyle(color: AC.tp))),
      body: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: EdgeInsets.all(16), decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(14), border: Border.all(color: AC.bdr)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: AC.cyan.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.notifications, color: AC.cyan, size: 22)),
              const SizedBox(width: 12),
              Expanded(child: Text(notification['title'] ?? notification['message'] ?? '', style: TextStyle(color: AC.tp, fontSize: 15, fontWeight: FontWeight.bold))),
            ]),
            Divider(color: AC.bdr, height: 20),
            Text(notification['message'] ?? notification['body'] ?? '', style: TextStyle(color: AC.tp, fontSize: 13, height: 1.6), textDirection: TextDirection.rtl),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(notification['created_at'] ?? '', style: TextStyle(color: AC.ts, fontSize: 11)),
              Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: notification['is_read'] == true ? AC.ok.withValues(alpha: 0.12) : AC.warn.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(notification['is_read'] == true ? '\u0645\u0642\u0631\u0648\u0621' : '\u062c\u062f\u064a\u062f', style: TextStyle(color: notification['is_read'] == true ? AC.ok : AC.warn, fontSize: 10))),
            ]),
          ])),
        const SizedBox(height: 14),
        if (notification['is_read'] != true) SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: () async { await ApiService.markAllRead(); Navigator.pop(context); },
          style: ElevatedButton.styleFrom(backgroundColor: AC.gold),
          icon: Icon(Icons.done_all, color: AC.navy),
          label: Text('\u062a\u0645 \u0627\u0644\u0642\u0631\u0627\u0621\u0629', style: TextStyle(color: AC.navy)),
        )),
      ])),
    );
  }
}
