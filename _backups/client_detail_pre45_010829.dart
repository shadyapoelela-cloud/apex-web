import 'package:flutter/material.dart';
import '../extracted/coa_screens.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// APEX Platform Client Detail Screen - RTL Arabic-First Design
// Navy + Gold Theme with integrated API calls

const Color navy = Color(0xFF050D1A);
const Color navyMid = Color(0xFF111D2E);
const Color gold = Color(0xFFC9A84C);
const Color textColor = Color(0xFFE8E0D0);
const Color textMid = Color(0xFF9A917F);
const Color textDim = Color(0xFF6B6355);
const Color cardBg = Color(0xFF0D1825);
const Color greenC = Color(0xFF34D399);
const Color blueC = Color(0xFF60A5FA);
const Color orangeC = Color(0xFFFBBF24);
const Color redC = Color(0xFFF87171);
const Color purpleC = Color(0xFFA78BFA);

class ClientDetailScreen extends StatefulWidget {
  final int clientId;
  final String clientName;

  const ClientDetailScreen({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Data models
  Map<String, dynamic> readinessData = {};
  List<Map<String, dynamic>> documentsData = [];
  bool isLoadingReadiness = true;
  bool isLoadingDocuments = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadReadiness();
    _loadDocuments();
  }

  Future<void> _loadReadiness() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.apexplatform.com/clients/${widget.clientId}/readiness'),
      );
      if (response.statusCode == 200) {
        setState(() {
          readinessData = jsonDecode(response.body);
          isLoadingReadiness = false;
        });
      }
    } catch (e) {
      // Fallback mock data
      setState(() {
        readinessData = {
          'status': 'documents_pending',
          'cr_number': 'CR-2024-001',
          'tax_id': 'TAX-1234567',
          'created_date': '2024-01-15',
          'coa_status': 'pending',
        };
        isLoadingReadiness = false;
      });
    }
  }

  Future<void> _loadDocuments() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.apexplatform.com/clients/${widget.clientId}/documents'),
      );
      if (response.statusCode == 200) {
        setState(() {
          documentsData = List<Map<String, dynamic>>.from(jsonDecode(response.body));
          isLoadingDocuments = false;
        });
      }
    } catch (e) {
      // Fallback mock data
      setState(() {
        documentsData = [
          {
            'name': 'Commercial Registration',
            'required': true,
            'status': 'uploaded',
            'uploaded_date': '2024-01-20',
            'expiry_date': '2025-01-20',
          },
          {
            'name': 'VAT Certificate',
            'required': true,
            'status': 'missing',
            'uploaded_date': null,
            'expiry_date': null,
          },
          {
            'name': 'Bank Statement',
            'required': true,
            'status': 'accepted',
            'uploaded_date': '2024-01-18',
            'expiry_date': null,
          },
          {
            'name': 'Board Minutes',
            'required': true,
            'status': 'rejected',
            'uploaded_date': '2024-01-10',
            'expiry_date': null,
          },
        ];
        isLoadingDocuments = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: navy,
        body: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              _buildTabContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: navyMid,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.clientName,
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'English Name',
                    style: TextStyle(
                      color: textMid,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gold,
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.clientName.isNotEmpty ? widget.clientName[0] : 'C',
                  style: const TextStyle(
                    color: navy,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusBadges(),
          const SizedBox(height: 16),
          _buildQuickInfoCards(),
        ],
      ),
    );
  }

  Widget _buildStatusBadges() {
    return Wrap(
      textDirection: TextDirection.rtl,
      spacing: 8,
      runSpacing: 8,
      children: [
        _badgeWidget('نشط', greenC),
        _badgeWidget('جاهز للوثائق', orangeC),
        _badgeWidget('التجزئة', blueC),
        _badgeWidget('شركة', purpleC),
      ],
    );
  }

  Widget _badgeWidget(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildQuickInfoCards() {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _quickInfoCard('رقم السجل', readinessData['cr_number'] ?? 'N/A', gold),
        _quickInfoCard('رقم الضريبة', readinessData['tax_id'] ?? 'N/A', greenC),
        _quickInfoCard('تاريخ الإنشاء', readinessData['created_date'] ?? 'N/A', blueC),
        _quickInfoCard('COA', readinessData['coa_status'] ?? 'قيد الانتظار', orangeC),
      ],
    );
  }

  Widget _quickInfoCard(String label, String value, Color accentColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border(right: BorderSide(color: accentColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: textMid,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: navyMid,
      child: TabBar(
        controller: _tabController,
        indicatorColor: gold,
        indicatorWeight: 3,
        labelColor: gold,
        unselectedLabelColor: textMid,
        tabs: const [
          Tab(text: 'البيانات'),
          Tab(text: 'المستندات'),
          Tab(text: 'الخدمات'),
          Tab(text: 'النشاط'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return SizedBox(
      height: 600,
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(),
          _buildDocumentsTab(),
          _buildServicesTab(),
          _buildActivityTab(),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _infoCard(
                  'المعلومات الأساسية',
                  [
                    ('النوع', 'شركة'),
                    ('القطاع', 'التجزئة'),
                    ('الحالة', 'نشط'),
                    ('الموقع', 'الرياض'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _infoCard(
                  'الاتصال والموقع',
                  [
                    ('البريد الإلكتروني', 'info@company.com'),
                    ('الهاتف', '+966 11 123 4567'),
                    ('العنوان', 'الرياض، المملكة العربية السعودية'),
                    ('الموقع الجغرافي', '24.7136° N, 46.6753° E'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildReadinessFlow(),
        ],
      ),
    );
  }

  Widget _infoCard(String title, List<(String, String)> items) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textDim.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: gold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              textDirection: TextDirection.rtl,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.$1,
                  style: TextStyle(color: textMid, fontSize: 12),
                ),
                Text(
                  item.$2,
                  style: const TextStyle(color: textColor, fontSize: 12),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildReadinessFlow() {
    final steps = [
      ('not_ready', 'غير جاهز'),
      ('documents_pending', 'الوثائق المعلقة'),
      ('ready_for_coa', 'جاهز للمراجع'),
      ('coa_in_progress', 'المراجع جارية'),
      ('ready_for_tb', 'جاهز للميزانية'),
    ];

    String currentStatus = readinessData['status'] ?? 'not_ready';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: gold, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مسار الجاهزية',
            style: TextStyle(
              color: gold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: steps.asMap().entries.map((entry) {
              int idx = entry.key;
              var step = entry.value;
              bool isActive = steps.indexWhere((s) => s.$1 == currentStatus) >= idx;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? gold : textDim.withOpacity(0.3),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          color: isActive ? navy : textMid,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isActive ? textColor : textMid,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    int mandatory = documentsData.where((d) => d['required'] == true).length;
    int uploaded = documentsData.where((d) => d['status'] != 'missing').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            textDirection: TextDirection.rtl,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'المستندات المطلوبة',
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$uploaded من $mandatory مكتملة',
                    style: TextStyle(
                      color: textMid,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: const Text('تحميل'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gold,
                  foregroundColor: navy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: uploaded / mandatory,
            backgroundColor: textDim.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(gold),
            minHeight: 6,
          ),
          const SizedBox(height: 16),
          ...documentsData.map((doc) => _documentCard(doc)),
        ],
      ),
    );
  }

  Widget _documentCard(Map<String, dynamic> doc) {
    Color statusColor = _statusColor(doc['status']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          right: BorderSide(color: statusColor, width: 4),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        textDirection: TextDirection.rtl,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      doc['name'],
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (doc['required'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: redC.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'إلزامي',
                          style: TextStyle(
                            color: redC,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  doc['uploaded_date'] != null
                      ? 'تم التحميل: ${doc['uploaded_date']}'
                      : 'لم يتم التحميل',
                  style: TextStyle(
                    color: textMid,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _statusLabel(doc['status']),
              style: TextStyle(
                color: statusColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    return {
      'uploaded': blueC,
      'accepted': greenC,
      'rejected': redC,
      'missing': textMid,
      'expired': orangeC,
    }[status] ?? textMid;
  }

  String _statusLabel(String status) {
    return {
      'uploaded': 'مرفوع',
      'accepted': 'مقبول',
      'rejected': 'مرفوض',
      'missing': 'مفقود',
      'expired': 'منتهي',
    }[status] ?? 'غير معروف';
  }

  Widget _buildServicesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              textDirection: TextDirection.ltr,
              children: [
                _serviceCard('COA', 'المراجعة', greenC, onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CoaJourneyScreen(
                      clientId: widget.clientId.toString(),
                      clientName: widget.clientName,
                    ),
                  ));
                }),
                _serviceCard('TB', 'الميزانية', blueC),
                _serviceCard('Statements', 'البيانات', orangeC),
                _serviceCard('Analysis', 'التحليل', purpleC),
                _serviceCard('Compliance', 'الامتثال', gold),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gold.withOpacity(0.2), gold.withOpacity(0.05)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: gold, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الخطوة التالية',
                  style: TextStyle(
                    color: gold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'يرجى تقديم الوثائق المتبقية',
                  style: const TextStyle(
                    color: textColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CoaJourneyScreen(
                        clientId: widget.clientId.toString(),
                        clientName: widget.clientName,
                      ),
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: navy,
                  ),
                  child: const Text('عرض التفاصيل'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildFinancialPathway(),
        ],
      ),
    );
  }

  Widget _serviceCard(String title, String subtitle, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.check, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: textMid,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildFinancialPathway() {
    final steps = [
      ('جمع الوثائق', 'تم'),
      ('المراجعة المالية', 'جارية'),
      ('إعداد الميزانية', 'قيد الانتظار'),
      ('الإقفال النهائي', 'قيد الانتظار'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textDim.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مسار السنة المالية',
            style: TextStyle(
              color: gold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((entry) {
            int idx = entry.key;
            var step = entry.value;
            bool isCompleted = step.$2 == 'تم';
            bool isInProgress = step.$2 == 'جارية';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? greenC
                          : isInProgress
                              ? gold
                              : textDim.withOpacity(0.3),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      isCompleted ? Icons.check : Icons.circle,
                      color: isCompleted ? navy : textMid,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.$1,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          step.$2,
                          style: TextStyle(
                            color: textMid,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActivityTab() {
    final activities = [
      ('تم تحميل الوثائق', 'قبل ساعتين', Icons.file_upload, greenC),
      ('تم إنشاء الحساب', 'قبل يوم', Icons.person_add, blueC),
      ('تم التصديق', 'قبل 3 أيام', Icons.verified, greenC),
      ('تم الطلب', 'قبل أسبوع', Icons.assignment, orangeC),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ...activities.asMap().entries.map((entry) {
            int idx = entry.key;
            var activity = entry.value;
            bool isLast = idx == activities.length - 1;

            return Row(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activity.$4.withOpacity(0.2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        activity.$3,
                        color: activity.$4,
                        size: 20,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        color: textDim.withOpacity(0.3),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity.$1,
                          style: const TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.$2,
                          style: TextStyle(
                            color: textMid,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
