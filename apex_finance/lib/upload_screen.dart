import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'api_service.dart';

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
  static const _navy=Color(0xFF050D1A);static const _navy2=Color(0xFF080F1F);static const _navy3=Color(0xFF0D1829);static const _gold=Color(0xFFC9A84C);static const _border=Color(0x26C9A84C);static const _textPrimary=Color(0xFFF0EDE6);static const _textSecondary=Color(0xFF8A8880);static const _success=Color(0xFF2ECC8A);static const _cyan=Color(0xFF00C2E0);

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
    }catch(e){if(mounted){setState(()=>_analyzing=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('خطأ: $e'),backgroundColor:Colors.red));}}
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(backgroundColor:_navy,
      appBar:AppBar(backgroundColor:_navy2,
        title:const Text('رفع القوائم المالية',style:TextStyle(fontFamily:'Tajawal',color:Color(0xFFF0EDE6))),
        bottom:PreferredSize(preferredSize:const Size.fromHeight(1),child:Container(color:_border,height:1))),
      body:SingleChildScrollView(padding:const EdgeInsets.all(20),child:Column(children:[
        // ── خطوة 1 ──
        _card('1','حمّل نموذج ميزان المراجعة','نموذج Excel معتمد',Icons.download_rounded,_cyan,
          _btn('تحميل النموذج المعتمد',Icons.download_rounded,_cyan,_downloadTemplate)),
        const SizedBox(height:16),
        // ── خطوة 2 ──
        _card('2','ارفع الميزان بعد التعبئة','xlsx فقط',Icons.upload_file_rounded,_gold,
          Column(children:[
            if(_fileSelected)...[Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_gold.withOpacity(0.08),borderRadius:BorderRadius.circular(10),border:Border.all(color:_gold.withOpacity(0.3))),child:Row(children:[const Icon(Icons.description_rounded,color:Color(0xFFC9A84C),size:20),const SizedBox(width:10),Expanded(child:Text(_fileName,textDirection:TextDirection.rtl,style:const TextStyle(color:Color(0xFFF0EDE6),fontSize:13,fontFamily:'Tajawal'),overflow:TextOverflow.ellipsis)),GestureDetector(onTap:()=>setState((){_fileSelected=false;_fileName='';_pickedFile=null;_done=false;}),child:const Icon(Icons.close,color:Color(0xFF8A8880),size:18))])),const SizedBox(height:10)],
            _btn(_fileSelected?'تغيير الملف':'اختر ملف Excel',Icons.attach_file_rounded,_gold,_pickFile,outlined:_fileSelected),
          ])),
        const SizedBox(height:16),
        // ── خطوة 3 ──
        _card('3','إعداد القوائم المالية','قائمة الدخل + المركز المالي + التدفقات',Icons.analytics_rounded,_success,
          _analyzing?Column(children:[Text('جاري الإعداد...',textDirection:TextDirection.rtl,style:const TextStyle(color:Color(0xFFF0EDE6),fontSize:14,fontFamily:'Tajawal')),const SizedBox(height:12),ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(value:_progress,minHeight:8,backgroundColor:_navy3,valueColor:const AlwaysStoppedAnimation<Color>(Color(0xFF2ECC8A)))),const SizedBox(height:6),Text('${(_progress*100).toInt()}% اكتمل',style:const TextStyle(color:Color(0xFF2ECC8A),fontSize:12,fontFamily:'Tajawal'))])
          :_done?Column(children:[
            Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:_success.withOpacity(0.08),borderRadius:BorderRadius.circular(12),border:Border.all(color:_success.withOpacity(0.3))),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[const Text('تم إعداد القوائم المالية بنجاح!',textDirection:TextDirection.rtl,style:TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:Color(0xFF2ECC8A),fontFamily:'Tajawal')),const SizedBox(height:2),Text(_fileName,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:12,color:Color(0xFF8A8880),fontFamily:'Tajawal'))])),const SizedBox(width:12),const Icon(Icons.check_circle_rounded,color:Color(0xFF2ECC8A),size:32)])),
            const SizedBox(height:12),
            GestureDetector(
              onTap:()=>context.push('/analysis/result', extra: {'apiData': _apiResult, 'pickedFile': _pickedFile?.files.first}),
              child:Container(width:double.infinity,height:54,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFC9A84C),Color(0xFF8B6F35)]),borderRadius:BorderRadius.circular(14),boxShadow:[BoxShadow(color:_gold.withOpacity(0.3),blurRadius:16,offset:const Offset(0,4))]),child:const Center(child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.bar_chart_rounded,color:Color(0xFF050D1A),size:20),SizedBox(width:8),Text('عرض نتائج التحليل',style:TextStyle(color:Color(0xFF050D1A),fontSize:16,fontWeight:FontWeight.w700,fontFamily:'Tajawal'))])))),
            const SizedBox(height:10),
            GestureDetector(
              onTap:()=>context.push('/coa/upload', extra: {'clientId': 'test-001', 'clientName': 'عميل تجريبي'}),
              child:Container(width:double.infinity,height:48,decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),border:Border.all(color:_cyan.withOpacity(0.4),width:1.5)),child:const Center(child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.account_tree_rounded,color:Color(0xFF00C2E0),size:18),SizedBox(width:8),Text('رفع شجرة الحسابات (COA)',style:TextStyle(color:Color(0xFF00C2E0),fontSize:14,fontWeight:FontWeight.w600,fontFamily:'Tajawal'))])))),
          ])
          :_btn(_fileSelected?'إعداد القوائم المالية':'ارفع الملف أولاً',Icons.analytics_rounded,_success,_fileSelected?_analyzeFile:null,disabled:!_fileSelected)),
        const SizedBox(height:40),
      ])));
  }

  Widget _card(String step,String title,String subtitle,IconData icon,Color color,Widget child)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:_navy3,borderRadius:BorderRadius.circular(16),border:Border.all(color:color.withOpacity(0.3))),child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Row(children:[Container(width:32,height:32,decoration:BoxDecoration(color:color.withOpacity(0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:color.withOpacity(0.3))),child:Center(child:Text(step,style:TextStyle(color:color,fontSize:14,fontWeight:FontWeight.w900)))),const Spacer(),Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(title,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w700,color:Color(0xFFF0EDE6),fontFamily:'Tajawal')),Text(subtitle,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:12,color:Color(0xFF8A8880),fontFamily:'Tajawal'))]),const SizedBox(width:10),Container(width:40,height:40,decoration:BoxDecoration(color:color.withOpacity(0.08),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:20))]),const SizedBox(height:14),child]));

  Widget _btn(String label,IconData icon,Color color,VoidCallback? onTap,{bool outlined=false,bool disabled=false})=>GestureDetector(onTap:disabled?null:onTap,child:Container(width:double.infinity,height:48,decoration:BoxDecoration(color:disabled?Colors.white.withOpacity(0.05):outlined?Colors.transparent:color.withOpacity(0.15),borderRadius:BorderRadius.circular(12),border:Border.all(color:disabled?Colors.white.withOpacity(0.1):color.withOpacity(0.4),width:1.5)),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:disabled?Colors.white24:color,size:18),const SizedBox(width:8),Text(label,style:TextStyle(color:disabled?Colors.white24:color,fontSize:14,fontWeight:FontWeight.w600,fontFamily:'Tajawal'))])));
}

