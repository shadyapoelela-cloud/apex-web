import 'unit3_screen.dart';
import 'unit3_screen.dart';
import 'unit2_screen.dart';
import 'package:flutter/material.dart';
import 'main.dart';
import 'multistage_screen.dart';

class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AC.navy,
      appBar: AppBar(backgroundColor: AC.navy2, elevation: 0,
        title: const Text('الخدمات المالية', style: TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_rounded, color: AC.textSecondary, size: 18), onPressed: () => Navigator.pop(context)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AC.border, height: 1))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('اختر الخدمة المطلوبة', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
          const SizedBox(height: 4),
          const Text('حلول مالية متكاملة مدعومة بالذكاء الاصطناعي', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 13, color: AC.textSecondary, fontFamily: 'Tajawal')),
          const SizedBox(height: 20),
          _UnitCard(unit: '1', title: 'إعداد القوائم المالية', subtitle: 'من ميزان المراجعة إلى قوائم مالية كاملة', icon: Icons.account_balance_rounded, color: AC.gold, features: const ['قائمة الدخل','قائمة المركز المالي','قائمة التدفقات النقدية','تحليل مالي شامل بالذكاء الاصطناعي'], status: 'متاح', statusColor: AC.success, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MultistageScreen()))),
          const SizedBox(height: 14),
          _UnitCard(unit: '2', title: 'إرفاق القوائم المالية المعتمدة', subtitle: 'ارفع قوائمك المعتمدة واحصل على تحليل فوري', icon: Icons.upload_file_rounded, color: AC.cyan, features: const ['رفع قائمة الدخل','رفع الميزانية العمومية','رفع قائمة التدفقات النقدية','تحليل مالي كامل + توصيات'], status: 'متاح', statusColor: AC.success, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Unit2Screen()))),
          const SizedBox(height: 14),
          _UnitCard(unit: '3', title: 'تحليل المبيعات', subtitle: 'نسب ومتوسطات ومؤشرات أداء المبيعات', icon: Icons.trending_up_rounded, color: AC.success, features: const ['مؤشرات أداء المبيعات KPIs','متوسطات ونسب النمو','مقارنات السوق حسب الدولة','تحليل حسب النشاط التجاري'], status: 'متاح', statusColor: AC.success, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Unit3Screen()))),
          const SizedBox(height: 14),
          _UnitCard(unit: '4', title: 'تحليل الجرد', subtitle: 'مقارنة الجرد الفعلي بالمخزني وتحليل الانحرافات', icon: Icons.inventory_2_rounded, color: AC.warning, features: const ['نسب الانحراف في قيمة المخزون','معدل دوران المخزون','عدد أيام المخزون','المخاطر والنصائح'], status: 'قريباً', statusColor: AC.warning, onTap: () => _showSoon(context, 'تحليل الجرد')),
          const SizedBox(height: 24),
          const Text('الخدمات المتقدمة', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
          const SizedBox(height: 4),
          const Text('للشركات والمستثمرين', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 12, color: AC.textSecondary, fontFamily: 'Tajawal')),
          const SizedBox(height: 14),
          _MiniCard(title: 'التحليل الائتماني وجاهزية البنوك', icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF6C5CE7), onTap: () => _showSoon(context, 'التحليل الائتماني')),
          const SizedBox(height: 10),
          _MiniCard(title: 'التدفق النقدي والتوقعات', icon: Icons.auto_graph_rounded, color: const Color(0xFF00B894), onTap: () => _showSoon(context, 'التدفق النقدي')),
          const SizedBox(height: 10),
          _MiniCard(title: 'التقييم ودراسة الجدوى', icon: Icons.assessment_rounded, color: const Color(0xFFE17055), onTap: () => _showSoon(context, 'التقييم ودراسة الجدوى')),
          const SizedBox(height: 10),
          _MiniCard(title: 'المقارنة القطاعية والتنافسية', icon: Icons.compare_arrows_rounded, color: const Color(0xFF0984E3), onTap: () => _showSoon(context, 'المقارنة القطاعية')),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: [AC.gold.withOpacity(0.1), AC.navy3]), borderRadius: BorderRadius.circular(16), border: Border.all(color: AC.gold.withOpacity(0.3))),
            child: Row(children: [const Icon(Icons.arrow_back_ios_rounded, color: AC.gold, size: 14), const Spacer(),
              Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: const [
                Text('استشارة مهنية متخصصة', textDirection: TextDirection.rtl, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AC.gold, fontFamily: 'Tajawal')),
                SizedBox(height: 4),
                Text('فريق من المستشارين الماليين المعتمدين جاهز لمساعدتك', textDirection: TextDirection.rtl, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.4))])),
              const SizedBox(width: 12),
              Container(width: 48, height: 48, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AC.gold, AC.goldDim]), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.support_agent_rounded, color: AC.navy, size: 24))])),
          const SizedBox(height: 40),
        ])));
  }
  void _showSoon(BuildContext context, String title) {
    showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: AC.navy3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AC.border)),
      title: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontFamily: 'Tajawal', color: AC.textPrimary, fontSize: 16)), const SizedBox(width: 8), const Icon(Icons.construction_rounded, color: AC.warning, size: 24)]),
      content: const Text('هذه الخدمة قيد التطوير وستكون متاحة قريباً.', textDirection: TextDirection.rtl, style: TextStyle(color: AC.textSecondary, fontFamily: 'Tajawal', height: 1.6)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً', style: TextStyle(color: AC.gold, fontFamily: 'Tajawal')))]));
  }
}

class _UnitCard extends StatelessWidget {
  final String unit, title, subtitle, status;
  final IconData icon; final Color color, statusColor;
  final List<String> features; final VoidCallback onTap;
  const _UnitCard({required this.unit, required this.title, required this.subtitle, required this.icon, required this.color, required this.features, required this.status, required this.statusColor, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: statusColor.withOpacity(0.3))),
            child: Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontFamily: 'Tajawal', fontWeight: FontWeight.w600))),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AC.textPrimary, fontFamily: 'Tajawal')),
            const SizedBox(height: 2),
            Text(subtitle, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 11, color: AC.textSecondary, fontFamily: 'Tajawal'))]),
          const SizedBox(width: 12),
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.2))),
            child: Center(child: Icon(icon, color: color, size: 24)))]),
        const SizedBox(height: 14),
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.end,
          children: features.map((f) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.15))),
            child: Text(f, style: TextStyle(fontSize: 11, color: color, fontFamily: 'Tajawal')))).toList()),
        const SizedBox(height: 12),
        Container(width: double.infinity, height: 44, decoration: BoxDecoration(color: status == 'متاح' ? color.withOpacity(0.15) : Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10), border: Border.all(color: status == 'متاح' ? color.withOpacity(0.4) : AC.border)),
          child: Center(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.arrow_back_ios_rounded, color: status == 'متاح' ? color : AC.textHint, size: 14), const SizedBox(width: 6),
            Text(status == 'متاح' ? 'ابدأ الآن' : 'قريباً', style: TextStyle(color: status == 'متاح' ? color : AC.textHint, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Tajawal'))])))])));
  }
}

class _MiniCard extends StatelessWidget {
  final String title; final IconData icon; final Color color; final VoidCallback onTap;
  const _MiniCard({required this.title, required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AC.navy3, borderRadius: BorderRadius.circular(12), border: Border.all(color: AC.border)),
      child: Row(children: [
        const Icon(Icons.arrow_back_ios_rounded, color: AC.textHint, size: 14),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AC.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Text('قريباً', style: TextStyle(fontSize: 10, color: AC.warning, fontFamily: 'Tajawal'))),
        const Spacer(),
        Text(title, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AC.textPrimary, fontFamily: 'Tajawal')),
        const SizedBox(width: 10),
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18))])));
  }
}




