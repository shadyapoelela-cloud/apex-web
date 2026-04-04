import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'coa_mapping_screen.dart';

class CoaUploadScreen extends StatefulWidget {
  final String clientId;
  final String clientName;
  const CoaUploadScreen({super.key, required this.clientId, required this.clientName});
  @override
  State<CoaUploadScreen> createState() => _CoaUploadScreenState();
}

class _CoaUploadScreenState extends State<CoaUploadScreen> {
  bool _uploading = false;
  bool _fileSelected = false;
  String _fileName = '';
  String _errorMsg = '';
  FilePickerResult? _picked;

  static const _bg      = Color(0xFF050D1A);
  static const _surface = Color(0xFF080F1F);
  static const _gold    = Color(0xFFC9A84C);
  static const _cyan    = Color(0xFF00C2E0);
  static const _success = Color(0xFF2ECC8A);
  static const _danger  = Color(0xFFE05050);
  static const _border  = Color(0x26C9A84C);
  static const _textPri = Color(0xFFF0EDE6);
  static const _textSec = Color(0xFF8A8880);
  static const _base    = 'https://apex-api-ootk.onrender.com';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx','xls','csv']);
    if (result != null && result.files.isNotEmpty) {
      setState(() { _fileSelected=true; _fileName=result.files.first.name; _picked=result; _errorMsg=''; });
    }
  }

  Future<void> _uploadCoa() async {
    if (_picked == null) return;
    setState(() { _uploading=true; _errorMsg=''; });
    try {
      final uri = Uri.parse('$_base/clients/${widget.clientId}/coa/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', _picked!.files.first.bytes!, filename: _picked!.files.first.name));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        final data = jsonDecode(body) as Map<String,dynamic>;
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => CoaMappingScreen(uploadData: data, clientId: widget.clientId, clientName: widget.clientName, pickedFile: _picked!.files.first)));
      } else {
        final err = jsonDecode(body);
        setState(() => _errorMsg = err['detail'] ?? err['message'] ?? 'فشل الرفع');
      }
    } catch (e) { setState(() => _errorMsg = 'خطأ: $e'); }
    finally { setState(() => _uploading = false); }
  }

  Future<void> _downloadTemplate() async {
    try {
      final res = await http.get(Uri.parse('$_base/template/trial-balance'));
      if (res.statusCode == 200) {
        final blob = html.Blob([res.bodyBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        (html.document.createElement('a') as html.AnchorElement)..href=url..download='نموذج_شجرة_الحسابات.xlsx'..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _surface,
        title: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('رفع شجرة الحسابات', style: TextStyle(fontFamily:'Tajawal', color:_textPri, fontSize:15, fontWeight:FontWeight.w700)),
          Text(widget.clientName, style: const TextStyle(fontFamily:'Tajawal', color:_textSec, fontSize:12)),
        ]),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color:_border,height:1))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
        StepIndicator(current: 0),
        const SizedBox(height:20),
        HelpCard(icon:Icons.account_tree_rounded, title:'لماذا نبدأ بشجرة الحسابات؟', body:'شجرة الحسابات هي المرجع الأساسي لتصنيف كل بند مالي. البدء منها يرفع دقة التحليل ويقلل أخطاء التفسير التلقائي.'),
        const SizedBox(height:16),
        StepCard(step:'1', color:_cyan, title:'حمّل النموذج المعتمد', subtitle:'Excel جاهز للتعبئة',
          child: ActionBtn(label:'تحميل نموذج شجرة الحسابات', icon:Icons.download_rounded, color:_cyan, onTap:_downloadTemplate)),
        const SizedBox(height:14),
        StepCard(step:'2', color:_gold, title:'ارفع ملف شجرة حساباتك', subtitle:'xlsx / xls / csv — 15MB',
          child: Column(children: [
            if (_fileSelected) ...[
              Container(padding:const EdgeInsets.all(12),
                decoration:BoxDecoration(color:_gold.withOpacity(0.07), borderRadius:BorderRadius.circular(10), border:Border.all(color:_gold.withOpacity(0.3))),
                child: Row(children:[
                  const Icon(Icons.description_rounded, color:_gold, size:20), const SizedBox(width:10),
                  Expanded(child:Text(_fileName, textDirection:TextDirection.rtl, style:const TextStyle(color:_textPri,fontSize:13,fontFamily:'Tajawal'), overflow:TextOverflow.ellipsis)),
                  GestureDetector(onTap:()=>setState(()=>_fileSelected=false), child:const Icon(Icons.close,color:_textSec,size:18)),
                ])), const SizedBox(height:10)],
            ActionBtn(label:_fileSelected?'تغيير الملف':'اختر ملف شجرة الحسابات', icon:Icons.attach_file_rounded, color:_gold, outlined:_fileSelected, onTap:_pickFile),
          ])),
        const SizedBox(height:14),
        if (_errorMsg.isNotEmpty)
          Container(margin:const EdgeInsets.only(bottom:14), padding:const EdgeInsets.all(12),
            decoration:BoxDecoration(color:_danger.withOpacity(0.08), borderRadius:BorderRadius.circular(10), border:Border.all(color:_danger.withOpacity(0.3))),
            child:Row(children:[const Icon(Icons.error_outline_rounded,color:_danger,size:16), const SizedBox(width:8), Expanded(child:Text(_errorMsg, textDirection:TextDirection.rtl, style:const TextStyle(fontSize:12,color:_danger,fontFamily:'Tajawal')))])),
        GestureDetector(
          onTap: (_fileSelected && !_uploading) ? _uploadCoa : null,
          child: AnimatedContainer(duration:const Duration(milliseconds:200), width:double.infinity, height:56,
            decoration: BoxDecoration(
              gradient:(_fileSelected&&!_uploading)?const LinearGradient(colors:[Color(0xFFC9A84C),Color(0xFF8B6F35)]):null,
              color:(!_fileSelected||_uploading)?Colors.white.withOpacity(0.05):null,
              borderRadius:BorderRadius.circular(14),
              border:(!_fileSelected||_uploading)?Border.all(color:Colors.white.withOpacity(0.1)):null,
              boxShadow:(_fileSelected&&!_uploading)?[BoxShadow(color:_gold.withOpacity(0.3),blurRadius:16,offset:const Offset(0,4))]:[]),
            child: Center(child: _uploading
              ? const SizedBox(width:22,height:22,child:CircularProgressIndicator(color:Color(0xFF050D1A),strokeWidth:2.5))
              : Row(mainAxisAlignment:MainAxisAlignment.center, children:[
                  Icon(Icons.upload_rounded, color:_fileSelected?const Color(0xFF050D1A):Colors.white24, size:20), const SizedBox(width:8),
                  Text('رفع وتحليل الأعمدة', style:TextStyle(color:_fileSelected?const Color(0xFF050D1A):Colors.white24, fontSize:15, fontWeight:FontWeight.w700, fontFamily:'Tajawal'))])))),
        const SizedBox(height:40),
      ])));
  }
}

class StepIndicator extends StatelessWidget {
  final int current;
  const StepIndicator({required this.current});
  static const _gold=Color(0xFFC9A84C); static const _success=Color(0xFF2ECC8A); static const _border=Color(0x26C9A84C); static const _textSec=Color(0xFF8A8880);
  static const _steps=['رفع الملف','تأكيد الأعمدة','تصنيف','اعتماد'];
  @override
  Widget build(BuildContext context) => Row(children:List.generate(_steps.length*2-1,(i){
    if(i.isOdd) return Expanded(child:Container(height:1,color:i~/2<current?_success:_border));
    final idx=i~/2; final done=idx<current; final active=idx==current;
    return Column(children:[
      Container(width:28,height:28,decoration:BoxDecoration(shape:BoxShape.circle,color:done?_success.withOpacity(0.15):active?_gold.withOpacity(0.15):Colors.transparent,border:Border.all(color:done?_success:active?_gold:_border,width:active?2:1)),
        child:Center(child:done?const Icon(Icons.check_rounded,size:14,color:Color(0xFF2ECC8A)):Text('${idx+1}',style:TextStyle(fontSize:11,color:active?_gold:_textSec,fontWeight:FontWeight.w700)))),
      const SizedBox(height:4),
      Text(_steps[idx],style:TextStyle(fontSize:9,color:active?_gold:done?_success:_textSec,fontFamily:'Tajawal')),
    ]);
  }));
}

class StepCard extends StatelessWidget {
  final String step,title,subtitle; final Color color; final Widget child;
  const StepCard({required this.step,required this.title,required this.subtitle,required this.color,required this.child});
  @override Widget build(BuildContext context) => Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:const Color(0xFF0D1829),borderRadius:BorderRadius.circular(16),border:Border.all(color:color.withOpacity(0.3))),
    child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
      Row(children:[Container(width:30,height:30,decoration:BoxDecoration(color:color.withOpacity(0.1),borderRadius:BorderRadius.circular(8),border:Border.all(color:color.withOpacity(0.3))),child:Center(child:Text(step,style:TextStyle(color:color,fontSize:14,fontWeight:FontWeight.w900)))),const Spacer(),
        Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(title,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700,color:Color(0xFFF0EDE6),fontFamily:'Tajawal')),Text(subtitle,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:11,color:Color(0xFF8A8880),fontFamily:'Tajawal'))]),
        const SizedBox(width:10),Container(width:38,height:38,decoration:BoxDecoration(color:color.withOpacity(0.07),borderRadius:BorderRadius.circular(10)),child:Icon(Icons.folder_open_rounded,color:color,size:18))]),
      const SizedBox(height:14), child]));
}

class HelpCard extends StatelessWidget {
  final IconData icon; final String title,body;
  const HelpCard({required this.icon,required this.title,required this.body});
  @override Widget build(BuildContext context) => Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF00C2E0).withOpacity(0.05),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFF00C2E0).withOpacity(0.2))),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(title,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:Color(0xFF00C2E0),fontFamily:'Tajawal')),const SizedBox(height:4),Text(body,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:12,color:Color(0xFF8A8880),fontFamily:'Tajawal',height:1.5))])),const SizedBox(width:10),Icon(icon,color:const Color(0xFF00C2E0),size:20)]));
}

class ActionBtn extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback? onTap; final bool outlined;
  const ActionBtn({required this.label,required this.icon,required this.color,this.onTap,this.outlined=false});
  @override Widget build(BuildContext context) => GestureDetector(onTap:onTap,child:Container(width:double.infinity,height:46,decoration:BoxDecoration(color:outlined?Colors.transparent:color.withOpacity(0.12),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(0.4),width:1.5)),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:color,size:17),const SizedBox(width:8),Text(label,style:TextStyle(color:color,fontSize:13,fontWeight:FontWeight.w600,fontFamily:'Tajawal'))])));
}

