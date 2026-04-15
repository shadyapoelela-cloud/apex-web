import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'api_service.dart';
import 'core/theme.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});
  @override State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _fileSelected=false,_analyzing=false,_done=false;
  double _progress=0;
  String _fileName='';
  Map<String,dynamic>? _apiResult;
  FilePickerResult? _pickedFile;
  static Color get _navy=>AC.navy;static Color get _navy2=>AC.navy2;static Color get _navy3=>AC.navy3;static Color get _gold=>AC.gold;static Color get _border=>AC.bdr;static Color get _textPrimary=>AC.tp;static Color get _textSecondary=>AC.ts;static Color get _success=>AC.ok;static Color get _cyan=>AC.cyan;

  Future<void> _downloadTemplate()async{await ApiService.downloadTrialBalanceTemplate();}

  Future<void> _pickFile()async{final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['xlsx','xls']);if(result!=null&&result.files.isNotEmpty){setState((){_fileSelected=true;_fileName=result.files.first.name;_pickedFile=result;_done=false;_apiResult=null;});}}

  Future<void> _analyzeFile()async{
    if(_pickedFile==null)return;
    setState((){_analyzing=true;_progress=0;});
    try{
      for(int i=1;i<=4;i++){await Future.delayed(const Duration(milliseconds:400));if(mounted)setState(()=>_progress=i/10);}
      final result=await ApiService.analyzeFull(bytes:_pickedFile!.files.first.bytes!,fileName:_pickedFile!.files.first.name);
      for(int i=5;i<=10;i++){await Future.delayed(const Duration(milliseconds:200));if(mounted)setState(()=>_progress=i/10);}
      if(result.success){_apiResult=result.data;if(mounted)setState((){_analyzing=false;_done=true;});}
      else{throw Exception(result.error??'خطأ');}
    }catch(e){if(mounted){setState(()=>_analyzing=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('خطأ: $e'),backgroundColor:AC.err));}}
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(backgroundColor:_navy,
      appBar:AppBar(backgroundColor:_navy2,
        title:Text('رفع القوائم المالية',style:TextStyle(fontFamily:'Tajawal',color:AC.tp)),
        bottom:PreferredSize(preferredSize:Size.fromHeight(1),child:Container(color:_border,height:1))),
      body:SingleChildScrollView(padding:EdgeInsets.all(20),child:Column(children:[
        // ── خطوة 1 ──
        _card('1','حمّل نموذج ميزان المراجعة','نموذج Excel معتمد',Icons.download_rounded,_cyan,
          _btn('تحميل النموذج المعتمد',Icons.download_rounded,_cyan,_downloadTemplate)),
        SizedBox(height:16),
        // ── خطوة 2 ──
        _card('2','ارفع الميزان بعد التعبئة','xlsx فقط',Icons.upload_file_rounded,_gold,
          Column(children:[
            if(_fileSelected)...[Container(padding:EdgeInsets.all(12),decoration:BoxDecoration(color:_gold.withValues(alpha: 0.08),borderRadius:BorderRadius.circular(10),border:Border.all(color:_gold.withValues(alpha: 0.3))),child:Row(children:[Icon(Icons.description_rounded,color:AC.gold,size:20),SizedBox(width:10),Expanded(child:Text(_fileName,textDirection:TextDirection.rtl,style:TextStyle(color:AC.tp,fontSize:13,fontFamily:'Tajawal'),overflow:TextOverflow.ellipsis)),GestureDetector(onTap:()=>setState((){_fileSelected=false;_fileName='';_pickedFile=null;_done=false;}),child:Icon(Icons.close,color:AC.ts,size:18))])),SizedBox(height:10)],
            _btn(_fileSelected?'تغيير الملف':'اختر ملف Excel',Icons.attach_file_rounded,_gold,_pickFile,outlined:_fileSelected),
          ])),
        SizedBox(height:16),
        // ── خطوة 3 ──
        _card('3','إعداد القوائم المالية','قائمة الدخل + المركز المالي + التدفقات',Icons.analytics_rounded,_success,
          _analyzing?Column(children:[Text('جاري الإعداد...',textDirection:TextDirection.rtl,style:TextStyle(color:AC.tp,fontSize:14,fontFamily:'Tajawal')),SizedBox(height:12),ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:_progress,minHeight:8,backgroundColor:_navy3,valueColor:AlwaysStoppedAnimation<Color>(_success))),SizedBox(height:6),Text('${(_progress*100).toInt()}% اكتمل',style:TextStyle(color:_success,fontSize:12,fontFamily:'Tajawal'))])
          :_done?Column(children:[
            Container(padding:EdgeInsets.all(14),decoration:BoxDecoration(color:_success.withValues(alpha: 0.08),borderRadius:BorderRadius.circular(12),border:Border.all(color:_success.withValues(alpha: 0.3))),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text('تم إعداد القوائم المالية بنجاح!',textDirection:TextDirection.rtl,style:TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:_success,fontFamily:'Tajawal')),SizedBox(height:2),Text(_fileName,textDirection:TextDirection.rtl,style:TextStyle(fontSize:12,color:AC.ts,fontFamily:'Tajawal'))])),SizedBox(width:12),Icon(Icons.check_circle_rounded,color:_success,size:32)])),
            SizedBox(height:12),
            GestureDetector(
              onTap:()=>context.push('/analysis/result', extra: {'apiData': _apiResult, 'pickedFile': _pickedFile?.files.first}),
              child:Container(width:double.infinity,height:54,decoration:BoxDecoration(gradient:LinearGradient(colors:[AC.gold,AC.gold.withValues(alpha: 0.7)]),borderRadius:BorderRadius.circular(14),boxShadow:[BoxShadow(color:_gold.withValues(alpha: 0.3),blurRadius:16,offset:Offset(0,4))]),child:Center(child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.bar_chart_rounded,color:AC.navy,size:20),SizedBox(width:8),Text('عرض نتائج التحليل',style:TextStyle(color:AC.navy,fontSize:16,fontWeight:FontWeight.w700,fontFamily:'Tajawal'))])))),
            const SizedBox(height:10),
            GestureDetector(
              onTap:()=>context.push('/coa/upload', extra: {'clientId': 'test-001', 'clientName': 'عميل تجريبي'}),
              child:Container(width:double.infinity,height:48,decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),border:Border.all(color:_cyan.withValues(alpha: 0.4),width:1.5)),child:Center(child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.account_tree_rounded,color:_cyan,size:18),SizedBox(width:8),Text('رفع شجرة الحسابات (COA)',style:TextStyle(color:_cyan,fontSize:14,fontWeight:FontWeight.w600,fontFamily:'Tajawal'))])))),
          ])
          :_btn(_fileSelected?'إعداد القوائم المالية':'ارفع الملف أولاً',Icons.analytics_rounded,_success,_fileSelected?_analyzeFile:null,disabled:!_fileSelected)),
        SizedBox(height:40),
      ])));
  }

  Widget _card(String step,String title,String subtitle,IconData icon,Color color,Widget child)=>Container(padding:EdgeInsets.all(16),decoration:BoxDecoration(color:_navy3,borderRadius:BorderRadius.circular(16),border:Border.all(color:color.withValues(alpha: 0.3))),child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Row(children:[Container(width:32,height:32,decoration:BoxDecoration(color:color.withValues(alpha: 0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:color.withValues(alpha: 0.3))),child:Center(child:Text(step,style:TextStyle(color:color,fontSize:14,fontWeight:FontWeight.w900)))),Spacer(),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(title,textDirection:TextDirection.rtl,style:TextStyle(fontSize:15,fontWeight:FontWeight.w700,color:AC.tp,fontFamily:'Tajawal')),Text(subtitle,textDirection:TextDirection.rtl,style:TextStyle(fontSize:12,color:AC.ts,fontFamily:'Tajawal'))]),SizedBox(width:10),Container(width:40,height:40,decoration:BoxDecoration(color:color.withValues(alpha: 0.08),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:20))]),SizedBox(height:14),child]));

  Widget _btn(String label,IconData icon,Color color,VoidCallback? onTap,{bool outlined=false,bool disabled=false})=>GestureDetector(onTap:disabled?null:onTap,child:Container(width:double.infinity,height:48,decoration:BoxDecoration(color:disabled?AC.tp.withValues(alpha: 0.05):outlined?Colors.transparent:color.withValues(alpha: 0.15),borderRadius:BorderRadius.circular(12),border:Border.all(color:disabled?AC.tp.withValues(alpha: 0.1):color.withValues(alpha: 0.4),width:1.5)),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:disabled?AC.td:color,size:18),const SizedBox(width:8),Text(label,style:TextStyle(color:disabled?AC.td:color,fontSize:14,fontWeight:FontWeight.w600,fontFamily:'Tajawal'))])));
}

