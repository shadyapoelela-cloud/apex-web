class ApexConfig {
  static const Map<String, double> qualityWeights = {
    'completeness': 0.25, 'consistency': 0.20, 'naming': 0.15,
    'duplication': 0.15, 'reporting': 0.15, 'mapping': 0.10,
  };
  static const int autoApproveConfidence = 85;
  static const int minQualityForApproval = 70;
  static const int minCompletenessForTB = 80;
  static const int minReportingForTB = 60;
  static const int lowConfidenceThreshold = 60;
  static const int maxFileSizeMB = 10;
  static const int minRows = 5;
  static const List<Map<String, String>> entityTypes = [
    {'id': 'llc', 'ar': 'شركة ذات مسؤولية محدودة', 'en': 'LLC'},
    {'id': 'closed_jsc', 'ar': 'شركة مساهمة مقفلة', 'en': 'Closed JSC'},
    {'id': 'sole_prop', 'ar': 'مؤسسة فردية', 'en': 'Sole Proprietorship'},
    {'id': 'public_jsc', 'ar': 'شركة مساهمة عامة', 'en': 'Public JSC'},
    {'id': 'partnership', 'ar': 'شركة تضامن', 'en': 'Partnership'},
    {'id': 'foreign_branch', 'ar': 'فرع شركة أجنبية', 'en': 'Foreign Branch'},
    {'id': 'professional', 'ar': 'شركة مهنية', 'en': 'Professional Co.'},
    {'id': 'nonprofit', 'ar': 'جمعية / مؤسسة غير ربحية', 'en': 'Non-profit'},
  ];
  static const List<String> regions = [
    'الرياض','مكة المكرمة','المدينة المنورة','المنطقة الشرقية',
    'القصيم','عسير','تبوك','حائل','الحدود الشمالية',
    'جازان','نجران','الباحة','الجوف',
  ];
  static const List<String> coaStages = [
    'upload','parse','classify','quality','review','approve','ready'
  ];
}