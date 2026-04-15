import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../api_service.dart';
import '../../core/theme.dart';
import '../../core/ui_components.dart';

// ════════════════════════════════════════
// APEX Client Detail Screen v5.2 — Visual Alignment
// ════════════════════════════════════════
// يطابق النموذج المرجعي apex-phase1.jsx (ClientDetailPage)
// Header + 3 info cards + Service Status Grid + Next Step + 4 tabs

Color get navy => AC.navy;
Color get navyLight => AC.navy3;
Color get navyMid => AC.navy4;
Color get gold => AC.gold;
Color get goldLight => AC.goldLight;
Color get textColor => AC.tp;
Color get textMid => AC.ts;
Color get textDim => AC.td;
Color get cardBg => AC.navy3;
Color get borderColor => AC.bdr;
Color get greenC => AC.ok;
Color get blueC => AC.info;
Color get orangeC => AC.warn;
Color get redC => AC.err;
Color get purpleC => AC.purple;

class ClientDetailScreen extends StatefulWidget {
  final String clientId;
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
      final res = await ApiService.getClientReadiness(widget.clientId);
      if (res.success) {
        setState(() {
          readinessData = res.data;
          isLoadingReadiness = false;
        });
      }
    } catch (e) {
      setState(() {
        readinessData = {
          'status': 'documents_pending',
          'cr_number': 'CR-2024-001',
          'tax_id': 'TAX-1234567',
          'created_date': '2024-01-15',
          'coa_status': 'قيد المراجعة',
          'sector': 'التجزئة',
          'type': 'شركة ذات مسؤولية محدودة',
        };
        isLoadingReadiness = false;
      });
    }
  }

  Future<void> _loadDocuments() async {
    try {
      final res = await ApiService.getClientDocuments(widget.clientId);
      if (res.success) {
        setState(() {
          documentsData = res.data is List ? List<Map<String, dynamic>>.from(res.data) : [];
          isLoadingDocuments = false;
        });
      }
    } catch (e) {
      setState(() {
        documentsData = [
          {'name': 'السجل التجاري', 'required': true, 'status': 'accepted', 'uploaded_date': '2024-01-20', 'expiry_date': '2025-01-20'},
          {'name': 'شهادة التسجيل الضريبي', 'required': true, 'status': 'uploaded', 'uploaded_date': '2024-01-22', 'expiry_date': null},
          {'name': 'كشف حساب بنكي', 'required': true, 'status': 'missing', 'uploaded_date': null, 'expiry_date': null},
          {'name': 'محاضر مجلس الإدارة', 'required': false, 'status': 'missing', 'uploaded_date': null, 'expiry_date': null},
          {'name': 'العنوان الوطني', 'required': true, 'status': 'accepted', 'uploaded_date': '2024-01-18', 'expiry_date': null},
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
              _buildClientJourneyFlow(),
              _buildInfoCards(),
              _buildServiceStatusGrid(),
              _buildNextStepCard(),
              _buildTabBar(),
              _buildTabContent(),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════
  // HEADER — matching reference model
  // ════════════════════════════════════════
  Widget _buildHeader() {
    final statusLine = [
      'نشط',
      readinessData['sector'] ?? 'التجزئة',
      readinessData['type'] ?? 'شركة',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: ApexHeroSection(
        title: widget.clientName,
        description: statusLine,
        icon: Icons.business_rounded,
        actions: [
          apexPill('نشط', color: greenC, filled: true),
          apexPill(readinessData['sector'] ?? 'التجزئة', color: blueC),
          apexPill(readinessData['type'] ?? 'شركة', color: textMid),
          apexSecondaryButton('تعديل', () => _showEditClientDialog(), icon: Icons.edit),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // CLIENT JOURNEY — step flow at top
  // ════════════════════════════════════════
  Widget _buildClientJourneyFlow() {
    final coaStatus = readinessData['coa_status'] ?? '';
    int currentStep = 0;
    if (coaStatus == 'معتمد') {
      currentStep = 3;
    } else if (coaStatus == 'قيد المراجعة') {
      currentStep = 2;
    } else if (coaStatus.isNotEmpty && coaStatus != 'pending' && coaStatus != 'لم يبدأ') {
      currentStep = 1;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: apexStepFlow(
        steps: ['إنشاء عميل', 'رفع COA', 'مراجعة', 'ميزان المراجعة', 'القوائم المالية'],
        currentStep: currentStep,
      ),
    );
  }

  // ════════════════════════════════════════
  // 3 INFO CARDS — matching reference model
  // ════════════════════════════════════════
  Widget _buildInfoCards() {
    final coaStatus = readinessData['coa_status'] ?? 'لم يبدأ';
    final coaTint = coaStatus == 'معتمد' ? ApexTint.green : (coaStatus == 'قيد المراجعة' ? ApexTint.amber : ApexTint.red);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: apexTintedCard(
              tint: ApexTint.amber,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                Row(children: [
                  Icon(Icons.description, color: gold, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('السجل التجاري', style: TextStyle(color: textDim, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(readinessData['cr_number'] ?? 'N/A',
                        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                ]),
              ],
            ),
          ),
          Expanded(
            child: apexTintedCard(
              tint: ApexTint.blue,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                Row(children: [
                  Icon(Icons.calendar_today, color: blueC, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('تاريخ الإنشاء', style: TextStyle(color: textDim, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(readinessData['created_date'] ?? 'N/A',
                        style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ])),
                ]),
              ],
            ),
          ),
          Expanded(
            child: apexTintedCard(
              tint: coaTint,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              children: [
                Row(children: [
                  Icon(Icons.account_tree, color: orangeC, size: 18),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('حالة COA', style: TextStyle(color: textDim, fontSize: 11)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Text(coaStatus,
                          style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(width: 6),
                      apexPill(coaStatus == 'معتمد' ? 'تم' : (coaStatus == 'قيد المراجعة' ? 'جارٍ' : 'بانتظار'),
                          color: coaStatus == 'معتمد' ? greenC : (coaStatus == 'قيد المراجعة' ? orangeC : textDim)),
                    ]),
                  ])),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // SERVICE STATUS GRID — 5 services matching reference
  // ════════════════════════════════════════
  Widget _buildServiceStatusGrid() {
    final coaStatus = readinessData['coa_status'] ?? 'pending';
    final services = [
      _ServiceItem('شجرة الحسابات', coaStatus == 'معتمد' ? 'approved' : (coaStatus == 'قيد المراجعة' ? 'review' : 'pending'), true),
      _ServiceItem('ميزان المراجعة', coaStatus == 'معتمد' ? 'ready' : 'pending', false),
      _ServiceItem('القوائم المالية', 'pending', false),
      _ServiceItem('التحليل المالي', 'pending', false),
      _ServiceItem('الامتثال والجاهزية', 'pending', false),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AC.navy2,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('حالة الخدمات',
                style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: services.map((s) {
                final sColor = _serviceStatusColor(s.status);
                final sLabel = _serviceStatusLabel(s.status);
                return Expanded(
                  child: GestureDetector(
                    onTap: s.clickable ? () {
                      context.push('/coa/journey', extra: {
                        'clientId': '${widget.clientId}',
                        'clientName': widget.clientName,
                      });
                    } : null,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(16),
                      decoration: apexSelectableDecoration(
                        isSelected: s.clickable,
                        activeColor: sColor,
                      ),
                      child: Column(
                        children: [
                          Text(s.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 10),
                          apexPill(sLabel, color: sColor),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _serviceStatusColor(String status) {
    switch (status) {
      case 'approved': return greenC;
      case 'review': return orangeC;
      case 'ready': return blueC;
      default: return textDim;
    }
  }

  String _serviceStatusLabel(String status) {
    switch (status) {
      case 'approved': return 'معتمد';
      case 'review': return 'مراجعة';
      case 'ready': return 'جاهز';
      default: return 'قريبًا';
    }
  }

  // ════════════════════════════════════════
  // NEXT STEP CARD — matching reference model
  // ════════════════════════════════════════
  Widget _buildNextStepCard() {
    final coaStatus = readinessData['coa_status'] ?? '';
    final hasCoA = coaStatus.isNotEmpty && coaStatus != 'pending' && coaStatus != 'لم يبدأ';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          if (!hasCoA)
            apexNoticeBanner(
              title: 'خطوة مطلوبة',
              text: 'لم يتم رفع شجرة الحسابات بعد — يرجى رفع الملف لبدء المسار المالي للعميل.',
              tint: ApexTint.amber,
            ),
          ApexNextStepCard(
            description: hasCoA ? 'متابعة رحلة شجرة الحسابات' : 'رفع شجرة الحسابات لبدء المسار المالي',
            buttonLabel: hasCoA ? 'متابعة COA' : 'رفع COA',
            icon: Icons.auto_awesome,
            onPressed: () {
              context.push('/coa/journey', extra: {
                'clientId': '${widget.clientId}',
                'clientName': widget.clientName,
              });
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // TAB BAR — pill style matching COA screens
  // ════════════════════════════════════════
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Container(
        decoration: BoxDecoration(
          color: navyMid,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: gold.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: gold.withValues(alpha: 0.3)),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: gold,
          unselectedLabelColor: textDim,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          dividerHeight: 0,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline, size: 16), text: 'البيانات'),
            Tab(icon: Icon(Icons.folder_outlined, size: 16), text: 'المستندات'),
            Tab(icon: Icon(Icons.hub, size: 16), text: 'الخدمات'),
            Tab(icon: Icon(Icons.history, size: 16), text: 'النشاط'),
          ],
        ),
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

  // ════════════════════════════════════════
  // TAB 1: INFO
  // ════════════════════════════════════════
  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: apexTintedCard(
                  tint: ApexTint.blue,
                  title: 'المعلومات الأساسية',
                  children: [
                    _infoRow('النوع', readinessData['type'] ?? 'شركة'),
                    _infoRow('القطاع', readinessData['sector'] ?? 'التجزئة'),
                    _infoRowWithPill('الحالة', 'نشط', greenC),
                    _infoRow('الموقع', 'الرياض'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: apexTintedCard(
                  tint: ApexTint.green,
                  title: 'الاتصال والموقع',
                  children: [
                    _infoRow('البريد الإلكتروني', 'info@company.com'),
                    _infoRow('الهاتف', '+966 11 123 4567'),
                    _infoRow('العنوان', 'الرياض، المملكة العربية السعودية'),
                    _infoRow('الموقع الجغرافي', '24.7136° N, 46.6753° E'),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textMid, fontSize: 12)),
          Text(value, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _infoRowWithPill(String label, String value, Color pillColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textMid, fontSize: 12)),
          apexPill(value, color: pillColor, filled: true),
        ],
      ),
    );
  }

  Widget _buildReadinessFlow() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مسار الجاهزية',
              style: TextStyle(color: goldLight, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          apexStepFlow(
            steps: ['تهيئة', 'المستندات', 'جاهز لـ COA', 'COA جارية', 'جاهز لـ TB'],
            currentStep: 1,
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════
  // TAB 2: DOCUMENTS
  // ════════════════════════════════════════
  Widget _buildDocumentsTab() {
    int mandatory = documentsData.where((d) => d['required'] == true).length;
    int uploaded = documentsData.where((d) => d['status'] != 'missing').length;
    final pct = mandatory > 0 ? uploaded / mandatory : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('المستندات المطلوبة',
                      style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('$uploaded من $mandatory مكتملة',
                      style: TextStyle(color: textMid, fontSize: 12)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: gold.withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.folder_open, color: gold, size: 16),
                  const SizedBox(width: 6),
                  Text('ارفع من الزر المقابل لكل مستند',
                    style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          apexGradientProgress(
            value: pct,
            label: 'نسبة الاكتمال',
            startColor: pct >= 1.0 ? greenC : null,
            endColor: pct >= 1.0 ? greenC : null,
          ),
          const SizedBox(height: 20),
          ...documentsData.map((doc) => _documentCard(doc)),
          ApexTableLegend(items: [
            MapEntry('مقبول', greenC),
            MapEntry('مرفوع', blueC),
            MapEntry('مرفوض', redC),
            MapEntry('منتهي', orangeC),
            MapEntry('مفقود', textDim),
          ]),
        ],
      ),
    );
  }

  Widget _documentCard(Map<String, dynamic> doc) {
    final statusColor = _docStatusColor(doc['status']);
    final statusLabel = _docStatusLabel(doc['status']);
    final statusIcon = _docStatusIcon(doc['status']);
    final isMissing = doc['status'] == 'missing';
    final isUploaded = doc['status'] == 'uploaded' || doc['status'] == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AC.navy2,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AC.bdr.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 3))],
        border: isMissing ? Border.all(color: gold.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(statusIcon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(doc['name'], style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600))),
                    if (doc['required'] == true) ...[
                      const SizedBox(width: 6),
                      Text('*', style: TextStyle(color: redC, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  doc['uploaded_date'] != null ? 'تم الرفع: ${doc['uploaded_date']}' : 'لم يتم الرفع بعد',
                  style: TextStyle(color: textDim, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Text(statusLabel,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          // Per-document action button
          isMissing
            ? apexPrimaryButton('رفع', () => _uploadDocForType(doc['name']), icon: Icons.upload_file)
            : apexSecondaryButton(
                isUploaded ? 'عرض' : 'إعادة',
                () => _viewDoc(doc['name']),
                icon: isUploaded ? Icons.visibility : Icons.refresh,
              ),
        ],
      ),
    );
  }

  void _uploadDocForType(String docName) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'xlsx', 'xls', 'csv', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      
      // Show uploading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('جاري رفع ${file.name}...'),
            backgroundColor: navy));
      }

      // Upload to API
      final res = await ApiService.uploadDocument(widget.clientId, docName, file.bytes!, file.name);
      if (res.success) {
        _loadDocuments();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم رفع ${file.name} بنجاح'),
              backgroundColor: navy));
        }
      } else {
        throw Exception(res.error ?? 'خطأ في الرفع');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الرفع: $e'),
            backgroundColor: navy));
      }
    }
  }

  Widget _uploadFormatBtn(BuildContext ctx, String docName, String format, IconData icon) {
    return InkWell(
      onTap: () {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('جاري رفع $docName ($format)...'),
          backgroundColor: navy,
        ));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withValues(alpha: 0.25)),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: gold, size: 28),
          const SizedBox(height: 6),
          Text(format, style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  void _viewDoc(String docName) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('عرض $docName — قريباً'),
      backgroundColor: navy,
    ));
  }

  void _showEditClientDialog() {
    final nameCtrl = TextEditingController(text: widget.clientName);
    final sectorCtrl = TextEditingController(text: readinessData['sector'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: gold.withValues(alpha: 0.3))),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('تعديل بيانات العميل', style: TextStyle(color: gold, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameCtrl, style: TextStyle(color: textColor),
              decoration: InputDecoration(labelText: 'اسم العميل', labelStyle: TextStyle(color: textMid),
                filled: true, fillColor: navyMid, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
            const SizedBox(height: 12),
            TextField(controller: sectorCtrl, style: TextStyle(color: textColor),
              decoration: InputDecoration(labelText: 'القطاع', labelStyle: TextStyle(color: textMid),
                filled: true, fillColor: navyMid, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              apexSecondaryButton('إلغاء', () => Navigator.pop(ctx)),
              const SizedBox(width: 12),
              apexPrimaryButton('حفظ', () async {
                  Navigator.pop(ctx);
                  try {
                    await ApiService.updateClient(widget.clientId, {'name_ar': nameCtrl.text, 'sector': sectorCtrl.text});
                    _loadReadiness();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم التحديث بنجاح'), backgroundColor: navy));
                  } catch (_) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ في التحديث'), backgroundColor: navy));
                  }
                }),
            ]),
          ]),
        ),
      ),
    );
  }

  Color _docStatusColor(String status) {
    switch (status) {
      case 'accepted': return greenC;
      case 'uploaded': return blueC;
      case 'rejected': return redC;
      case 'expired': return orangeC;
      default: return textDim;
    }
  }

  String _docStatusLabel(String status) {
    switch (status) {
      case 'accepted': return 'مقبول';
      case 'uploaded': return 'مرفوع';
      case 'rejected': return 'مرفوض';
      case 'expired': return 'منتهي';
      default: return 'مفقود';
    }
  }

  IconData _docStatusIcon(String status) {
    switch (status) {
      case 'accepted': return Icons.check_circle_outline;
      case 'uploaded': return Icons.cloud_done;
      case 'rejected': return Icons.cancel_outlined;
      case 'expired': return Icons.timer_off;
      default: return Icons.insert_drive_file_outlined;
    }
  }

  // ════════════════════════════════════════
  // TAB 3: SERVICES (detailed)
  // ════════════════════════════════════════
  Widget _buildServicesTab() {
    final services = [
      _DetailedService('شجرة الحسابات', 'COA', 'تحليل وتصنيف الدليل المحاسبي', greenC, Icons.account_tree, 'قيد المراجعة'),
      _DetailedService('ميزان المراجعة', 'TB', 'التحقق من صحة الأرصدة المحاسبية', blueC, Icons.balance, 'بعد COA'),
      _DetailedService('القوائم المالية', 'Statements', 'إعداد الميزانية وقائمة الدخل', orangeC, Icons.assessment, 'بعد TB'),
      _DetailedService('التحليل المالي', 'Analysis', 'النسب المالية والمؤشرات', purpleC, Icons.analytics, 'بعد Statements'),
      _DetailedService('الامتثال والجاهزية', 'Compliance', 'التأكد من الجاهزية النظامية', gold, Icons.shield, 'متوازي'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ...services.map((s) {
            final tint = s.color == greenC ? ApexTint.green
                : s.color == blueC ? ApexTint.blue
                : s.color == orangeC ? ApexTint.amber
                : s.color == purpleC ? ApexTint.violet
                : ApexTint.amber;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: apexTintedCard(
                tint: tint,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: s.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(s.icon, color: s.color, size: 22),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(s.label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Text(s.labelEn, style: TextStyle(color: textDim, fontSize: 11)),
                            ]),
                            const SizedBox(height: 4),
                            Text(s.desc, style: TextStyle(color: textDim, fontSize: 11)),
                          ],
                        ),
                      ),
                      apexPill(s.status, color: s.color),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
          // Financial pathway
          _buildFinancialPathway(),
        ],
      ),
    );
  }

  Widget _buildFinancialPathway() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('مسار السنة المالية',
            style: TextStyle(color: goldLight, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ApexChecklist(items: [
          ApexCheckItem('جمع الوثائق', CheckStatus.done),
          ApexCheckItem('المراجعة المالية', CheckStatus.pending),
          ApexCheckItem('إعداد الميزانية', CheckStatus.blocked),
          ApexCheckItem('الإقفال النهائي', CheckStatus.blocked),
        ]),
      ],
    );
  }

  // ════════════════════════════════════════
  // TAB 4: ACTIVITY TIMELINE
  // ════════════════════════════════════════
  Widget _buildActivityTab() {
    final activities = [
      ('تم اعتماد شجرة حسابات العميل', 'الجودة: 87% — جميع الحسابات معتمدة', 'قبل ساعتين', Icons.check_circle_outline, greenC),
      ('تم رفع شهادة التسجيل الضريبي', 'المستند بانتظار المراجعة', 'قبل 4 ساعات', Icons.upload_file, blueC),
      ('تم إنشاء ملف العميل', 'بيانات أساسية + معلومات الاتصال', 'أمس', Icons.person_add, gold),
      ('فحص الامتثال — ناجح', 'جميع المستندات الإلزامية سارية', 'قبل يومين', Icons.shield, greenC),
      ('تحديث بيانات الاتصال', 'تم تحديث البريد الإلكتروني ورقم الهاتف', 'قبل 3 أيام', Icons.edit, orangeC),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: activities.map((a) => apexFeedItem(
          title: a.$1,
          subtitle: a.$2,
          time: a.$3,
          icon: a.$4,
          accentColor: a.$5,
        )).toList(),
      ),
    );
  }

  // ════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════
  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Data Classes ───
class _InfoItem {
  final String label, value;
  final IconData icon;
  final Color color;
  _InfoItem(this.label, this.value, this.icon, this.color);
}

class _ServiceItem {
  final String label, status;
  final bool clickable;
  _ServiceItem(this.label, this.status, this.clickable);
}

class _DetailedService {
  final String label, labelEn, desc, status;
  final Color color;
  final IconData icon;
  _DetailedService(this.label, this.labelEn, this.desc, this.color, this.icon, this.status);
}
