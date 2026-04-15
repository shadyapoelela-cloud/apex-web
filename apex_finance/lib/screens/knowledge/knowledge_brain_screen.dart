import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

class KnowledgeBrainScreen extends StatefulWidget {
  const KnowledgeBrainScreen({super.key});
  @override State<KnowledgeBrainScreen> createState() => _KBState();
}

class _KBState extends State<KnowledgeBrainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  final _authorities = [
    {
      'code': 'SOCPA', 'name': '\u0627\u0644\u0645\u0639\u0627\u064a\u064a\u0631 \u0627\u0644\u0645\u062d\u0627\u0633\u0628\u064a\u0629 \u0627\u0644\u0633\u0639\u0648\u062f\u064a\u0629',
      'desc': '\u0645\u0639\u0627\u064a\u064a\u0631 \u0627\u0644\u0645\u062d\u0627\u0633\u0628\u0629 \u0627\u0644\u0635\u0627\u062f\u0631\u0629 \u0639\u0646 \u0627\u0644\u0647\u064a\u0626\u0629 \u0627\u0644\u0633\u0639\u0648\u062f\u064a\u0629 \u0644\u0644\u0645\u062d\u0627\u0633\u0628\u064a\u0646',
      'tags': ['\u0645\u0639\u0627\u064a\u064a\u0631', '\u0645\u062d\u0627\u0633\u0628\u0629', 'IFRS'],
      'color': 0xFF2ECC8A, 'icon': Icons.account_balance,
    },
    {
      'code': 'ZATCA', 'name': '\u0646\u0638\u0627\u0645 \u0627\u0644\u0632\u0643\u0627\u0629 \u0648\u0627\u0644\u062f\u062e\u0644',
      'desc': '\u0623\u0646\u0638\u0645\u0629 \u0648\u0644\u0648\u0627\u0626\u062d \u0647\u064a\u0626\u0629 \u0627\u0644\u0632\u0643\u0627\u0629 \u0648\u0627\u0644\u0636\u0631\u064a\u0628\u0629 \u0648\u0627\u0644\u062c\u0645\u0627\u0631\u0643',
      'tags': ['\u0636\u0631\u064a\u0628\u0629', '\u0632\u0643\u0627\u0629', '\u0641\u0648\u062a\u0631\u0629'],
      'color': 0xFFF0A500, 'icon': Icons.gavel,
    },
    {
      'code': 'MoC', 'name': '\u0646\u0638\u0627\u0645 \u0627\u0644\u0634\u0631\u0643\u0627\u062a \u0627\u0644\u0633\u0639\u0648\u062f\u064a',
      'desc': '\u0623\u062d\u0643\u0627\u0645 \u0627\u0644\u062a\u0623\u0633\u064a\u0633 \u0648\u0627\u0644\u0625\u062f\u0627\u0631\u0629 \u0648\u0627\u0644\u062a\u0635\u0641\u064a\u0629 \u0644\u062c\u0645\u064a\u0639 \u0623\u0646\u0648\u0627\u0639 \u0627\u0644\u0634\u0631\u0643\u0627\u062a',
      'tags': ['\u062d\u0648\u0643\u0645\u0629', '\u062a\u0623\u0633\u064a\u0633', '\u0634\u0631\u0643\u0627\u062a'],
      'color': 0xFF00C2E0, 'icon': Icons.business,
    },
    {
      'code': 'ISA', 'name': '\u0645\u0639\u0627\u064a\u064a\u0631 \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u062f\u0648\u0644\u064a\u0629',
      'desc': '\u0627\u0644\u0645\u0639\u0627\u064a\u064a\u0631 \u0627\u0644\u062f\u0648\u0644\u064a\u0629 \u0644\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0627\u0644\u0645\u0639\u062a\u0645\u062f\u0629 \u0645\u0646 SOCPA',
      'tags': ['\u0645\u0631\u0627\u062c\u0639\u0629', '\u062a\u062f\u0642\u064a\u0642', 'ISA'],
      'color': 0xFFC9A84C, 'icon': Icons.checklist,
    },
    {
      'code': 'IFRS', 'name': '\u0627\u0644\u0645\u0639\u0627\u064a\u064a\u0631 \u0627\u0644\u062f\u0648\u0644\u064a\u0629 \u0644\u0644\u062a\u0642\u0627\u0631\u064a\u0631 \u0627\u0644\u0645\u0627\u0644\u064a\u0629',
      'desc': '\u0627\u0644\u0645\u0639\u0627\u064a\u064a\u0631 \u0627\u0644\u062f\u0648\u0644\u064a\u0629 \u0644\u0625\u0639\u062f\u0627\u062f \u0627\u0644\u062a\u0642\u0627\u0631\u064a\u0631 \u0627\u0644\u0645\u0627\u0644\u064a\u0629',
      'tags': ['\u0645\u0639\u0627\u064a\u064a\u0631', '\u062a\u0642\u0627\u0631\u064a\u0631', '\u062f\u0648\u0644\u064a\u0629'],
      'color': 0xFFE05050, 'icon': Icons.public,
    },
    {
      'code': 'CMA', 'name': '\u0647\u064a\u0626\u0629 \u0633\u0648\u0642 \u0627\u0644\u0645\u0627\u0644',
      'desc': '\u0623\u0646\u0638\u0645\u0629 \u0648\u0644\u0648\u0627\u0626\u062d \u0647\u064a\u0626\u0629 \u0627\u0644\u0633\u0648\u0642 \u0627\u0644\u0645\u0627\u0644\u064a\u0629 \u0648\u0627\u0644\u0625\u0641\u0635\u0627\u062d',
      'tags': ['\u0627\u0633\u062a\u062b\u0645\u0627\u0631', '\u0625\u0641\u0635\u0627\u062d', '\u0633\u0648\u0642'],
      'color': 0xFF9B59B6, 'icon': Icons.trending_up,
    },
  ];

  final _domains = [
    {
      'name': '\u0627\u0644\u0645\u062d\u0627\u0633\u0628\u0629', 'icon': Icons.calculate, 'count': 45,
      'desc': '\u0645\u0639\u0627\u064a\u064a\u0631 \u0627\u0644\u0639\u0631\u0636 \u0648\u0627\u0644\u0625\u0641\u0635\u0627\u062d \u0648\u0627\u0644\u0642\u064a\u0627\u0633',
    },
    {
      'name': '\u0627\u0644\u0636\u0631\u0627\u0626\u0628 \u0648\u0627\u0644\u0632\u0643\u0627\u0629', 'icon': Icons.receipt, 'count': 32,
      'desc': '\u0636\u0631\u064a\u0628\u0629 \u0627\u0644\u0642\u064a\u0645\u0629 \u0627\u0644\u0645\u0636\u0627\u0641\u0629 \u0648\u0627\u0644\u0632\u0643\u0627\u0629 \u0648\u0627\u0644\u0641\u0648\u062a\u0631\u0629 \u0627\u0644\u0625\u0644\u0643\u062a\u0631\u0648\u0646\u064a\u0629',
    },
    {
      'name': '\u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629', 'icon': Icons.fact_check, 'count': 28,
      'desc': '\u0625\u062c\u0631\u0627\u0621\u0627\u062a \u0627\u0644\u0645\u0631\u0627\u062c\u0639\u0629 \u0648\u0627\u0644\u062a\u062f\u0642\u064a\u0642 \u0648\u0627\u0644\u0639\u064a\u0646\u0627\u062a',
    },
    {
      'name': '\u0627\u0644\u062a\u0645\u0648\u064a\u0644', 'icon': Icons.account_balance, 'count': 18,
      'desc': '\u062c\u0627\u0647\u0632\u064a\u0629 \u0627\u0644\u062a\u0645\u0648\u064a\u0644 \u0648\u0634\u0631\u0648\u0637 \u0627\u0644\u0628\u0646\u0648\u0643 \u0648\u0627\u0644\u0645\u0633\u062a\u062b\u0645\u0631\u064a\u0646',
    },
    {
      'name': '\u0627\u0644\u0627\u0645\u062a\u062b\u0627\u0644', 'icon': Icons.verified, 'count': 22,
      'desc': '\u0627\u0644\u0627\u0644\u062a\u0632\u0627\u0645 \u0627\u0644\u062a\u0646\u0638\u064a\u0645\u064a \u0648\u0627\u0644\u0642\u0627\u0646\u0648\u0646\u064a',
    },
    {
      'name': '\u0627\u0644\u062d\u0648\u0643\u0645\u0629', 'icon': Icons.shield, 'count': 15,
      'desc': '\u0646\u0638\u0627\u0645 \u0627\u0644\u0634\u0631\u0643\u0627\u062a \u0648\u0627\u0644\u0625\u062f\u0627\u0631\u0629 \u0648\u0627\u0644\u0631\u0642\u0627\u0628\u0629',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(
        backgroundColor: AC.navy2,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: const Color(0xFFE91E63).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.psychology, color: Color(0xFFE91E63), size: 20),
          ),
          SizedBox(width: 10),
          Text('\u0627\u0644\u0639\u0642\u0644 \u0627\u0644\u0645\u0639\u0631\u0641\u064a', style: TextStyle(color: AC.tp, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        actions: [
          ApexIconButton(icon: Icons.smart_toy, color: AC.gold, tooltip: 'Apex Copilot', onPressed: () => context.push('/copilot')),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AC.gold,
          labelColor: AC.gold,
          unselectedLabelColor: AC.ts,
          tabs: const [
            Tab(text: '\u0627\u0644\u0645\u0631\u0627\u062c\u0639', icon: Icon(Icons.account_balance, size: 18)),
            Tab(text: '\u0627\u0644\u0645\u062c\u0627\u0644\u0627\u062a', icon: Icon(Icons.category, size: 18)),
            Tab(text: '\u0627\u0644\u0628\u062d\u062b', icon: Icon(Icons.search, size: 18)),
          ],
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: ApexHeroSection(
            title: '\u0627\u0644\u0642\u0627\u0639\u062f\u0629 \u0627\u0644\u0645\u0639\u0631\u0641\u064a\u0629',
            description: '\u0627\u0644\u0645\u0639\u0627\u064a\u064a\u0631 \u0648\u0627\u0644\u0623\u0646\u0638\u0645\u0629 \u0648\u0627\u0644\u0645\u0631\u0627\u062c\u0639 \u0627\u0644\u0645\u0647\u0646\u064a\u0629 \u0641\u064a \u0645\u0643\u0627\u0646 \u0648\u0627\u062d\u062f',
            icon: Icons.psychology_rounded,
          ),
        ),
        Expanded(child: TabBarView(controller: _tabController, children: [
          _buildAuthoritiesTab(),
          _buildDomainsTab(),
          _buildSearchTab(),
        ])),
      ]),
    );
  }

  Widget _buildAuthoritiesTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: _authorities.length,
      itemBuilder: (ctx, i) {
        final a = _authorities[i];
        final color = Color(a['color'] as int);
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))]),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(a['icon'] as IconData, color: color, size: 22),
            ),
            title: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(a['code'] as String, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              SizedBox(width: 8),
              Expanded(child: Text(a['name'] as String, style: TextStyle(color: AC.tp, fontSize: 13, fontWeight: FontWeight.bold))),
            ]),
            subtitle: Text(a['desc'] as String, style: TextStyle(color: AC.ts, fontSize: 11)),
            iconColor: AC.ts,
            children: [
              Padding(padding: EdgeInsets.all(14), child: Column(children: [
                Wrap(spacing: 6, runSpacing: 6, children: (a['tags'] as List).map<Widget>((t) => Chip(
                  label: Text(t, style: TextStyle(color: AC.tp, fontSize: 10)),
                  backgroundColor: AC.navy4, side: BorderSide(color: color.withValues(alpha: 0.3)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact,
                )).toList()),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(side: BorderSide(color: color)),
                    icon: Icon(Icons.article, color: color, size: 16),
                    label: Text('\u0627\u0644\u0645\u0648\u0627\u062f', style: TextStyle(color: color, fontSize: 12)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(side: BorderSide(color: color)),
                    icon: Icon(Icons.rule, color: color, size: 16),
                    label: Text('\u0627\u0644\u0642\u0648\u0627\u0639\u062f', style: TextStyle(color: color, fontSize: 12)),
                  )),
                ]),
              ])),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDomainsTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.3),
      itemCount: _domains.length,
      itemBuilder: (ctx, i) {
        final d = _domains[i];
        return Container(
          decoration: BoxDecoration(color: AC.navy2, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: Offset(0, 3))]),
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(18),
            child: Padding(padding: EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(d['icon'] as IconData, color: AC.gold, size: 24),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AC.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('', style: TextStyle(color: AC.gold, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ]),
              Spacer(),
              Text(d['name'] as String, style: TextStyle(color: AC.tp, fontWeight: FontWeight.bold, fontSize: 13)),
              SizedBox(height: 4),
              Text(d['desc'] as String, style: TextStyle(color: AC.ts, fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
            ])),
          ),
        );
      },
    );
  }

  Widget _buildSearchTab() {
    return Padding(padding: EdgeInsets.all(14), child: Column(children: [
      TextField(
        controller: _searchCtrl,
        style: TextStyle(color: AC.tp),
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: '\u0627\u0628\u062d\u062b \u0641\u064a \u0627\u0644\u0642\u0627\u0639\u062f\u0629 \u0627\u0644\u0645\u0639\u0631\u0641\u064a\u0629...',
          hintStyle: TextStyle(color: AC.ts),
          prefixIcon: Icon(Icons.search, color: AC.gold),
          filled: true, fillColor: AC.navy3,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AC.gold)),
        ),
        onChanged: (v) => setState(() => _searchQuery = v),
      ),
      SizedBox(height: 16),
      Expanded(child: _searchQuery.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.search, color: AC.ts, size: 48),
            SizedBox(height: 12),
            Text('\u0627\u0628\u062d\u062b \u0639\u0646 \u0645\u0639\u0627\u064a\u064a\u0631\u060c \u0642\u0648\u0627\u0639\u062f\u060c \u0623\u0646\u0638\u0645\u0629\u060c \u0645\u0641\u0627\u0647\u064a\u0645', style: TextStyle(color: AC.ts, fontSize: 13)),
          ]))
        : ListView(children: _authorities.where((a) =>
            (a['name'] as String).contains(_searchQuery) ||
            (a['desc'] as String).contains(_searchQuery) ||
            (a['code'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (a['tags'] as List).any((t) => t.toString().contains(_searchQuery))
          ).map((a) {
            final color = Color(a['color'] as int);
            return ListTile(
              leading: Icon(a['icon'] as IconData, color: color),
              title: Text(a['name'] as String, style: TextStyle(color: AC.tp, fontSize: 13)),
              subtitle: Text(a['code'] as String, style: TextStyle(color: color, fontSize: 11)),
              trailing: Icon(Icons.chevron_right, color: AC.ts),
              onTap: () {},
            );
          }).toList()),
      ),
    ]));
  }

  @override
  void dispose() { _tabController.dispose(); _searchCtrl.dispose(); super.dispose(); }
}
