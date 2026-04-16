import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart' as intl;

// Color scheme for APEX Platform
class AppColors {
  static const navy = Color(0xFF050D1A);
  static const navyLight = Color(0xFF0A1628);
  static const navyMid = Color(0xFF111D2E);
  static const gold = Color(0xFFC9A84C);
  static const goldLight = Color(0xFFD4B96A);
  static const textColor = Color(0xFFE8E0D0);
  static const textMid = Color(0xFF9A917F);
  static const textDim = Color(0xFF6B6355);
  static const cardBg = Color(0xFF0D1825);
  static const borderColor = Color(0x1FC9A84C);
  static const greenC = Color(0xFF34D399);
  static const redC = Color(0xFFF87171);
  static const blueC = Color(0xFF60A5FA);
  static const orangeC = Color(0xFFFBBF24);
  static const purpleC = Color(0xFFA78BFA);
}

class CoaJourneyScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const CoaJourneyScreen({
    Key? key,
    required this.clientId,
    required this.clientName,
  }) : super(key: key);

  @override
  State<CoaJourneyScreen> createState() => _CoaJourneyScreenState();
}

class _CoaJourneyScreenState extends State<CoaJourneyScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int currentStage = 0; // 0=Upload stage (gold), completed stages=cyan
  bool _isUploading = false;
  String _uploadedFileName = '';

  // Mock data structures
  List<AccountData> accounts = [];
  QualityMetrics qualityMetrics = QualityMetrics();
  ReviewData reviewData = ReviewData();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initializeMockData();
  }

  void _initializeMockData() {
    // Mock accounts data
    accounts = [
      AccountData(
        code: '1000',
        name: 'Cash at Hand',
        classification: 'Asset',
        section: 'Current Assets',
        balance: 150000.00,
        confidence: 98.5,
        status: 'Approved',
      ),
      AccountData(
        code: '1100',
        name: 'Bank Account',
        classification: 'Asset',
        section: 'Current Assets',
        balance: 450000.00,
        confidence: 97.2,
        status: 'Approved',
      ),
      AccountData(
        code: '2000',
        name: 'Accounts Payable',
        classification: 'Liability',
        section: 'Current Liabilities',
        balance: 280000.00,
        confidence: 95.8,
        status: 'Review',
      ),
      AccountData(
        code: '3000',
        name: 'Share Capital',
        classification: 'Equity',
        section: 'Equity',
        balance: 1000000.00,
        confidence: 99.1,
        status: 'Approved',
      ),
      AccountData(
        code: '4000',
        name: 'Sales Revenue',
        classification: 'Income',
        section: 'Revenue',
        balance: 2500000.00,
        confidence: 92.3,
        status: 'Flagged',
      ),
    ];

    qualityMetrics = QualityMetrics(
      overallScore: 96.2,
      completeness: 98,
      consistency: 95,
      naming: 93,
      duplication: 97,
      reporting: 94,
      mapping: 96,
    );

    reviewData = ReviewData(
      totalAccounts: 5,
      approvedCount: 3,
      reviewCount: 1,
      flaggedCount: 1,
    );
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
        backgroundColor: AppColors.navy,
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(),

              // 7-Stage Pipeline
              _buildStagePipeline(),

              // Tab content
              _buildTabContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      color: AppColors.navyMid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_forward, color: AppColors.gold),
                tooltip: 'رجوع',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'مرحلة اعتماد شجرة الحسابات',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Text(
                '\${widget.clientName} • ',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMid,
                ),
              ),
              Text(
                'معرف العميل: \${widget.clientId}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMid,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isUploading ? null : () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx', 'xls', 'csv'],
                  allowMultiple: false,
                  withData: true,
                );
                if (result != null && result.files.isNotEmpty) {
                  final file = result.files.first;
                  if (mounted) {
                    setState(() { _isUploading = true; _uploadedFileName = file.name; });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('جاري تحليل: \${file.name}...'),
                        backgroundColor: AppColors.gold,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    // Parse the CSV/Excel file
                    await _parseUploadedFile(file);
                  }
                }
              } catch (e) {
                if (mounted) {
                  setState(() { _isUploading = false; });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('خطأ في اختيار الملف: \$e'),
                      backgroundColor: AppColors.redC,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.upload_file, size: 20),
            label: Text(_isUploading ? 'جاري التحليل...' : currentStage > 0 ? 'تم الرفع — إعادة الرفع' : 'رفع شجرة حسابات (Excel / CSV)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.navy,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }




  // Windows-1256 to Unicode lookup table (0x80-0xFF)
  static const List<int> _cp1256 = [
    0x20AC,0x067E,0x201A,0x0192,0x201E,0x2026,0x2020,0x2021,
    0x02C6,0x2030,0x0679,0x2039,0x0152,0x0686,0x0698,0x0688,
    0x06AF,0x2018,0x2019,0x201C,0x201D,0x2022,0x2013,0x2014,
    0x06A9,0x2122,0x0691,0x203A,0x0153,0x200C,0x200D,0x06BA,
    0x00A0,0x060C,0x00A2,0x00A3,0x00A4,0x00A5,0x00A6,0x00A7,
    0x00A8,0x00A9,0x06BE,0x00AB,0x00AC,0x00AD,0x00AE,0x00AF,
    0x00B0,0x00B1,0x00B2,0x00B3,0x00B4,0x00B5,0x00B6,0x00B7,
    0x00B8,0x00B9,0x061B,0x00BB,0x00BC,0x00BD,0x00BE,0x061F,
    0x06C1,0x0621,0x0622,0x0623,0x0624,0x0625,0x0626,0x0627,
    0x0628,0x0629,0x062A,0x062B,0x062C,0x062D,0x062E,0x062F,
    0x0630,0x0631,0x0632,0x0633,0x0634,0x0635,0x0636,0x00D7,
    0x0637,0x0638,0x0639,0x063A,0x0640,0x0641,0x0642,0x0643,
    0x00E0,0x0644,0x00E2,0x0645,0x0646,0x0647,0x0648,0x00E7,
    0x00E8,0x00E9,0x00EA,0x00EB,0x0649,0x064A,0x00EE,0x00EF,
    0x064B,0x064C,0x064D,0x064E,0x00F4,0x064F,0x0650,0x00F7,
    0x0651,0x00F9,0x0652,0x00FB,0x00FC,0x200E,0x200F,0x06D2,
  ];

  String _decodeBytes(Uint8List bytes) {
    // Strip BOM if present
    int offset = 0;
    if (bytes.length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF) {
      offset = 3; // UTF-8 BOM
    } else if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      offset = 2; // UTF-16 LE BOM â€” try as UTF-8 anyway
    }

    final trimmed = offset > 0 ? bytes.sublist(offset) : bytes;

    // Try UTF-8 first
    try {
      final result = utf8.decode(trimmed);
      // Check if result has Arabic characters (U+0600-U+06FF range)
      bool hasArabic = result.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
      bool hasReplacement = result.contains('\uFFFD');
      if (hasArabic && !hasReplacement) {
        return result;
      }
    } catch (_) {}

    // Fallback: Windows-1256 decoding
    final buffer = StringBuffer();
    for (final byte in trimmed) {
      if (byte < 0x80) {
        buffer.writeCharCode(byte);
      } else {
        buffer.writeCharCode(_cp1256[byte - 0x80]);
      }
    }
    return buffer.toString();
  }

  Future<void> _parseUploadedFile(dynamic file) async {
    try {
      final bytes = file.bytes as Uint8List?;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('\u0644\u0627 \u064a\u0645\u0643\u0646 \u0642\u0631\u0627\u0621\u0629 \u0627\u0644\u0645\u0644\u0641'), backgroundColor: AppColors.redC),
          );
          setState(() { _isUploading = false; });
        }
        return;
      }

      // Decode with encoding detection (UTF-8 â†’ Windows-1256 fallback)
      final content = _decodeBytes(bytes);

      // Normalize line endings
      final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      List<List<dynamic>> rows;
      try {
        rows = const CsvToListConverter(shouldParseNumbers: true, eol: '\n').convert(normalized);
      } catch (_) {
        // Try with different separator (semicolon for some locales)
        try {
          rows = const CsvToListConverter(fieldDelimiter: ';', shouldParseNumbers: true, eol: '\n').convert(normalized);
        } catch (_) {
          rows = [];
        }
      }

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('\u0627\u0644\u0645\u0644\u0641 \u0641\u0627\u0631\u063a \u0623\u0648 \u063a\u064a\u0631 \u0635\u0627\u0644\u062d'), backgroundColor: AppColors.redC),
          );
          setState(() { _isUploading = false; });
        }
        return;
      }

      // First row is headers
      final headers = rows.first.map((h) => h.toString().trim().toLowerCase()).toList();
      final dataRows = rows.skip(1).where((r) => r.isNotEmpty && r.any((c) => c.toString().trim().isNotEmpty)).toList();

      // Map columns â€” flexible header matching (Arabic + English)
      int codeCol = _findCol(headers, ['code', 'account_code', 'account code', 'acc_code', '\u0631\u0642\u0645 \u0627\u0644\u062d\u0633\u0627\u0628', '\u0627\u0644\u0631\u0642\u0645', '\u0631\u0645\u0632', '\u0631\u0642\u0645', '\u0643\u0648\u062f']);
      int nameCol = _findCol(headers, ['name', 'account_name', 'account name', 'acc_name', 'description', '\u0627\u0633\u0645 \u0627\u0644\u062d\u0633\u0627\u0628', '\u0627\u0644\u0627\u0633\u0645', '\u0627\u0644\u062d\u0633\u0627\u0628', '\u0627\u0644\u0648\u0635\u0641', '\u0628\u064a\u0627\u0646']);
      int classCol = _findCol(headers, ['classification', 'class', 'type', 'account_type', '\u0627\u0644\u062a\u0635\u0646\u064a\u0641', '\u0627\u0644\u0646\u0648\u0639']);
      int sectionCol = _findCol(headers, ['section', 'category', 'group', '\u0627\u0644\u0642\u0633\u0645', '\u0627\u0644\u0641\u0626\u0629', '\u0627\u0644\u0645\u062c\u0645\u0648\u0639\u0629']);
      int balanceCol = _findCol(headers, ['balance', 'amount', 'debit', 'credit', '\u0627\u0644\u0631\u0635\u064a\u062f', '\u0627\u0644\u0645\u0628\u0644\u063a']);

      // Fallback: positional mapping if no headers match
      if (codeCol < 0 && nameCol < 0) {
        if (headers.length >= 2) {
          codeCol = 0;
          nameCol = 1;
          classCol = headers.length > 2 ? 2 : -1;
          sectionCol = headers.length > 3 ? 3 : -1;
          balanceCol = headers.length > 4 ? 4 : -1;
        }
      }

      List<AccountData> parsed = [];
      for (final row in dataRows) {
        try {
          String code = codeCol >= 0 && codeCol < row.length ? row[codeCol].toString().trim() : '';
          String name = nameCol >= 0 && nameCol < row.length ? row[nameCol].toString().trim() : '';
          String classification = classCol >= 0 && classCol < row.length ? row[classCol].toString().trim() : '\u063a\u064a\u0631 \u0645\u0635\u0646\u0641';
          String section = sectionCol >= 0 && sectionCol < row.length ? row[sectionCol].toString().trim() : '\u0639\u0627\u0645';
          double balance = 0;
          if (balanceCol >= 0 && balanceCol < row.length) {
            final bVal = row[balanceCol];
            if (bVal is num) {
              balance = bVal.toDouble();
            } else {
              balance = double.tryParse(bVal.toString().replaceAll(',', '').replaceAll(' ', '').replaceAll('\u00A0', '')) ?? 0;
            }
          }

          if (code.isNotEmpty || name.isNotEmpty) {
            parsed.add(AccountData(
              code: code.isNotEmpty ? code : '${parsed.length + 1}',
              name: name.isNotEmpty ? name : '\u062d\u0633\u0627\u0628 ${parsed.length + 1}',
              classification: classification,
              section: section,
              balance: balance,
              confidence: 95.0,
              status: 'Review',
            ));
          }
        } catch (_) {
          // Skip malformed rows
        }
      }

      if (mounted) {
        setState(() {
          if (parsed.isNotEmpty) {
            accounts = parsed;
            currentStage = 1; // Advance to Analysis stage
          }
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u062a\u0645 \u0627\u0633\u062a\u064a\u0631\u0627\u062f ${parsed.length} \u062d\u0633\u0627\u0628 \u0645\u0646 $_uploadedFileName'),
            backgroundColor: AppColors.greenC,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isUploading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u062e\u0637\u0623 \u0641\u064a \u062a\u062d\u0644\u064a\u0644 \u0627\u0644\u0645\u0644\u0641: $e'),
            backgroundColor: AppColors.redC,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  int _findCol(List<String> headers, List<String> candidates) {
    for (final c in candidates) {
      final idx = headers.indexWhere((h) => h.contains(c));
      if (idx >= 0) return idx;
    }
    return -1;
  }


  Widget _buildStagePipeline() {
    final stages = [
      ('الرفع', Icons.cloud_upload),
      ('التحليل', Icons.assessment),
      ('التصنيف', Icons.category),
      ('الجودة', Icons.check_circle),
      ('المراجعة', Icons.visibility),
      ('الموافقة', Icons.done_all),
      ('جاهز للتوازن', Icons.verified),
    ];

    return Container(
      padding: EdgeInsets.all(24),
      color: AppColors.navyLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مسار العملية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              children: List.generate(
                stages.length * 2 - 1,
                (index) {
                  if (index.isEven) {
                    int stageIndex = index ~/ 2;
                    return _buildStageNode(
                      label: stages[stageIndex].$1,
                      icon: stages[stageIndex].$2,
                      isComplete: stageIndex < currentStage,
                      isCurrent: stageIndex == currentStage,
                    );
                  } else {
                    int connectorIndex = index ~/ 2;
                    bool isComplete = connectorIndex < currentStage;
                    return _buildConnector(isComplete);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageNode({
    required String label,
    required IconData icon,
    required bool isComplete,
    required bool isCurrent,
  }) {
    Color bgColor;
    Color textCol;
    Color shadowCol;

    if (isComplete) {
      bgColor = const Color(0xFF22D3EE);
      textCol = Colors.white;
      shadowCol = const Color(0xFF22D3EE).withOpacity(0.3);
    } else if (isCurrent) {
      bgColor = AppColors.gold;
      textCol = AppColors.navy;
      shadowCol = AppColors.gold.withOpacity(0.5);
    } else {
      bgColor = AppColors.navyMid;
      textCol = AppColors.textDim;
      shadowCol = Colors.transparent;
    }

    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bgColor,
            boxShadow: [
              BoxShadow(
                color: shadowCol,
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: isComplete
                ? Icon(Icons.check, color: textCol, size: 28)
                : Icon(icon, color: textCol, size: 28),
          ),
        ),
        SizedBox(height: 12),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isCurrent ? AppColors.gold : AppColors.textMid,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(bool isComplete) {
    return Container(
      width: 40,
      height: 4,
      margin: EdgeInsets.only(bottom: 26),
      color: isComplete ? const Color(0xFF22D3EE) : AppColors.textDim.withOpacity(0.3),
    );
  }

  Widget _buildTabContent() {
    return Container(
      color: AppColors.navy,
      child: Column(
        children: [
          // Tab bar
          Container(
            color: AppColors.navyLight,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.gold,
              unselectedLabelColor: AppColors.textMid,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: AppColors.gold, width: 3),
              ),
              tabs: const [
                Tab(text: 'النظرة العامة'),
                Tab(text: 'الحسابات'),
                Tab(text: 'الجودة'),
                Tab(text: 'المراجعة'),
                Tab(text: 'الشجرة'),
              ],
            ),
          ),

          // Tab content
          Container(
            color: AppColors.navy,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAccountsTab(),
                _buildQualityTab(),
                _buildReviewTab(),
                _buildTreeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stats cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard('إجمالي الحسابات', '${accounts.length}', AppColors.blueC),
              _buildStatCard('الحسابات المعتمدة', '${accounts.where((a) => a.status == 'Approved').length}', AppColors.greenC),
              _buildStatCard('قيد المراجعة', '${accounts.where((a) => a.status == 'Review').length}', AppColors.orangeC),
              _buildStatCard('الحسابات المعلمة', '${accounts.where((a) => a.status == 'Flagged').length}', AppColors.redC),
            ],
          ),

          SizedBox(height: 32),

          // Classification distribution
          Text(
            'توزيع التصنيفات',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 16),
          _buildClassificationChart(),

          SizedBox(height: 32),

          // Confidence circle
          Text(
            'متوسط مستوى الثقة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 16),
          _buildConfidenceCircle(),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMid,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationChart() {
    Map<String, int> classificationCount = {};
    for (var account in accounts) {
      classificationCount[account.classification] =
          (classificationCount[account.classification] ?? 0) + 1;
    }

    final colors = [AppColors.blueC, AppColors.greenC, AppColors.orangeC, AppColors.purpleC];
    int colorIndex = 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: classificationCount.entries.map((e) {
          Color barColor = colors[colorIndex++ % colors.length];
          return Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: barColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textColor,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  '${e.value}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConfidenceCircle() {
    double avgConfidence = accounts.isNotEmpty
        ? accounts.map((a) => a.confidence).reduce((a, b) => a + b) / accounts.length
        : 0;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                children: [
                  CircularProgressIndicator(
                    value: avgConfidence / 100,
                    strokeWidth: 8,
                    backgroundColor: AppColors.navyMid,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.goldLight),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${avgConfidence.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gold,
                          ),
                        ),
                        Text(
                          'مستوى الثقة',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMid,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'جودة البيانات ممتازة',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.greenC,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true,
            child: Row(
              children: [
                _buildFilterChip('الكل', null),
                SizedBox(width: 8),
                _buildFilterChip('معتمد', 'Approved'),
                SizedBox(width: 8),
                _buildFilterChip('قيد المراجعة', 'Review'),
                SizedBox(width: 8),
                _buildFilterChip('معلم', 'Flagged'),
              ],
            ),
          ),

          SizedBox(height: 20),

          // Accounts table
          _buildAccountsTable(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.gold),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.gold,
        ),
      ),
    );
  }

  Widget _buildAccountsTable() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith(
            (_) => AppColors.navyMid,
          ),
          dataRowColor: MaterialStateColor.resolveWith(
            (_) => AppColors.cardBg,
          ),
          headingTextStyle: TextStyle(
            color: AppColors.gold,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          dataTextStyle: TextStyle(
            color: AppColors.textColor,
            fontSize: 12,
          ),
          columns: [
            DataColumn(label: Text('الكود')),
            DataColumn(label: Text('اسم الحساب')),
            DataColumn(label: Text('التصنيف')),
            DataColumn(label: Text('القسم')),
            DataColumn(label: Text('الرصيد')),
            DataColumn(label: Text('الثقة')),
            DataColumn(label: Text('الحالة')),
          ],
          rows: accounts.map((account) {
            Color statusColor = AppColors.greenC;
            if (account.status == 'Review') statusColor = AppColors.orangeC;
            if (account.status == 'Flagged') statusColor = AppColors.redC;

            return DataRow(
              cells: [
                DataCell(Text(account.code)),
                DataCell(Text(account.name)),
                DataCell(Text(account.classification)),
                DataCell(Text(account.section)),
                DataCell(
                  Text(
                    intl.NumberFormat('#,##0.00', 'ar_SA').format(account.balance),
                  ),
                ),
                DataCell(
                  Text(
                    '${account.confidence.toStringAsFixed(1)}%',
                    style: TextStyle(color: AppColors.gold),
                  ),
                ),
                DataCell(
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      border: Border.all(color: statusColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusArabic(account.status),
                      style: TextStyle(color: statusColor, fontSize: 11),
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildQualityTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Overall quality score
          Text(
            'درجة الجودة الإجمالية',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 16),
          _buildQualityScoreCircle(qualityMetrics.overallScore),

          SizedBox(height: 32),

          // Dimension meters
          Text(
            'أبعاد الجودة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 16),
          _buildQualityMeter('الاكتمال', qualityMetrics.completeness),
          SizedBox(height: 16),
          _buildQualityMeter('الاتساق', qualityMetrics.consistency),
          SizedBox(height: 16),
          _buildQualityMeter('التسمية', qualityMetrics.naming),
          SizedBox(height: 16),
          _buildQualityMeter('الازدواجية', qualityMetrics.duplication),
          SizedBox(height: 16),
          _buildQualityMeter('الإبلاغ', qualityMetrics.reporting),
          SizedBox(height: 16),
          _buildQualityMeter('المطابقة', qualityMetrics.mapping),

          SizedBox(height: 32),

          // Warnings and recommendations
          _buildWarningsSection(),
        ],
      ),
    );
  }

  Widget _buildQualityScoreCircle(double score) {
    Color scoreColor = score >= 95 ? AppColors.greenC :
                       score >= 85 ? AppColors.orangeC : AppColors.redC;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            children: [
              CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 10,
                backgroundColor: AppColors.navyMid,
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${score.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      'من 100',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualityMeter(String label, double value) {
    Color meterColor = value >= 95 ? AppColors.greenC :
                       value >= 85 ? AppColors.orangeC : AppColors.redC;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: meterColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 6,
              backgroundColor: AppColors.navyMid,
              valueColor: AlwaysStoppedAnimation<Color>(meterColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningsSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.redC.withOpacity(0.1),
        border: Border.all(color: AppColors.redC.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: AppColors.redC, size: 20),
              SizedBox(width: 8),
              Text(
                'تنبيهات وتوصيات',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.redC,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '• حساب "إيرادات المبيعات" قد يحتاج مراجعة إضافية بسبب تقلب البيانات',
            style: TextStyle(fontSize: 12, color: AppColors.textColor),
          ),
          SizedBox(height: 8),
          Text(
            '• تأكد من تطابق أسماء الحسابات مع المعايير المحاسبية المحلية',
            style: TextStyle(fontSize: 12, color: AppColors.textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary stats
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                'الحسابات المعتمدة',
                '${reviewData.approvedCount}',
                AppColors.greenC,
              ),
              _buildStatCard(
                'قيد المراجعة',
                '${reviewData.reviewCount}',
                AppColors.orangeC,
              ),
            ],
          ),

          SizedBox(height: 32),

          // Review checklist
          Text(
            'قائمة التحقق من الموافقة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 16),
          _buildApprovalChecklist(),

          SizedBox(height: 32),

          // Review cards
          Text(
            'الحسابات قيد المراجعة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.goldLight,
            ),
          ),
          SizedBox(height: 16),
          _buildReviewCards(),
        ],
      ),
    );
  }

  Widget _buildApprovalChecklist() {
    final checklist = [
      ('جميع الحسابات مصنفة', true),
      ('درجة جودة أعلى من 90%', true),
      ('لا توجد ازدواجيات', true),
      ('تم مراجعة جميع الحسابات المعلمة', false),
      ('الموافقة من المسؤول المالي', false),
    ];

    return Column(
      children: checklist.map((item) {
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: AppColors.borderColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.$2 ? AppColors.greenC : AppColors.navyMid,
                  border: Border.all(
                    color: item.$2 ? AppColors.greenC : AppColors.textDim,
                  ),
                ),
                child: item.$2
                    ? Center(
                        child: Icon(Icons.check, color: Colors.white, size: 12),
                      )
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.$1,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textColor,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReviewCards() {
    var reviewAccounts = accounts
        .where((a) => a.status == 'Review' || a.status == 'Flagged')
        .toList();

    if (reviewAccounts.isEmpty) {
      return Container(
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          border: Border.all(color: AppColors.borderColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'لا توجد حسابات قيد المراجعة',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMid,
          ),
        ),
      );
    }

    return Column(
      children: reviewAccounts.map((account) {
        Color statusColor = account.status == 'Flagged' ? AppColors.redC : AppColors.orangeC;

        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            border: Border.all(color: statusColor.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${account.code} - ${account.name}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      border: Border.all(color: statusColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getStatusArabic(account.status),
                      style: TextStyle(color: statusColor, fontSize: 11),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                'التصنيف: ${account.classification} • القسم: ${account.section}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMid,
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الثقة: ${account.confidence.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.goldLight,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'رفض',
                          style: TextStyle(color: AppColors.redC),
                        ),
                      ),
                      SizedBox(width: 8),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          'قبول',
                          style: TextStyle(color: AppColors.greenC),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTreeTab() {
    final classGroups = <String, List<AccountData>>{};
    for (var account in accounts) {
      if (!classGroups.containsKey(account.classification)) {
        classGroups[account.classification] = [];
      }
      classGroups[account.classification]!.add(account);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: classGroups.entries.map((entry) {
          return _buildTreeNode(entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  Widget _buildTreeNode(String classification, List<AccountData> accounts) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border.all(color: AppColors.borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        title: Text(
          classification,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.gold,
          ),
        ),
        subtitle: Text(
          '${accounts.length} حسابات',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMid,
          ),
        ),
        textColor: AppColors.gold,
        collapsedTextColor: AppColors.gold,
        iconColor: AppColors.gold,
        collapsedIconColor: AppColors.gold,
        backgroundColor: AppColors.navyMid,
        collapsedBackgroundColor: AppColors.cardBg,
        children: accounts.map((account) {
          return Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.navyMid),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        account.code,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMid,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  account.section,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.goldLight,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getStatusArabic(String status) {
    switch (status) {
      case 'Approved':
        return 'معتمد';
      case 'Review':
        return 'قيد المراجعة';
      case 'Flagged':
        return 'معلم';
      default:
        return status;
    }
  }
}

// Data models
class AccountData {
  final String code;
  final String name;
  final String classification;
  final String section;
  final double balance;
  final double confidence;
  final String status;

  AccountData({
    required this.code,
    required this.name,
    required this.classification,
    required this.section,
    required this.balance,
    required this.confidence,
    required this.status,
  });
}

class QualityMetrics {
  final double overallScore;
  final double completeness;
  final double consistency;
  final double naming;
  final double duplication;
  final double reporting;
  final double mapping;

  QualityMetrics({
    this.overallScore = 0,
    this.completeness = 0,
    this.consistency = 0,
    this.naming = 0,
    this.duplication = 0,
    this.reporting = 0,
    this.mapping = 0,
  });
}

class ReviewData {
  final int totalAccounts;
  final int approvedCount;
  final int reviewCount;
  final int flaggedCount;

  ReviewData({
    this.totalAccounts = 0,
    this.approvedCount = 0,
    this.reviewCount = 0,
    this.flaggedCount = 0,
  });
}
