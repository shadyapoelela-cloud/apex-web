import 'package:flutter/material.dart';
import 'core/theme.dart';

class StepIndicator extends StatelessWidget {
  final int current;
  StepIndicator({super.key, required this.current});
  static Color get _gold => AC.gold;static Color get _success => AC.ok;static Color get _border => AC.bdr;static Color get _textSec => AC.ts;
  static final _steps=['رفع الملف','تأكيد الأعمدة','تصنيف','اعتماد'];
  @override
  Widget build(BuildContext context) => Row(children:List.generate(_steps.length*2-1,(i){
    if(i.isOdd) return Expanded(child:Container(height:1,color:i~/2<current?_success:_border));
    final idx=i~/2; final done=idx<current; final active=idx==current;
    return Column(children:[
      Container(width:28,height:28,decoration:BoxDecoration(shape:BoxShape.circle,color:done?_success.withValues(alpha: 0.15):active?_gold.withValues(alpha: 0.15):Colors.transparent,border:Border.all(color:done?_success:active?_gold:_border,width:active?2:1)),
        child:Center(child:done?Icon(Icons.check_rounded,size:14,color:_success):Text('${idx+1}',style:TextStyle(fontSize:11,color:active?_gold:_textSec,fontWeight:FontWeight.w700)))),
      SizedBox(height:4),
      Text(_steps[idx],style:TextStyle(fontSize:9,color:active?_gold:done?_success:_textSec,fontFamily:'Tajawal')),
    ]);
  }));
}

class HelpCard extends StatelessWidget {
  final IconData icon; final String title, body;
  HelpCard({super.key, required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Container(padding:EdgeInsets.all(14),decoration:BoxDecoration(color:AC.cyan.withValues(alpha: 0.05),borderRadius:BorderRadius.circular(12),border:Border.all(color:AC.cyan.withValues(alpha: 0.2))),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(title,textDirection:TextDirection.rtl,style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:AC.cyan,fontFamily:'Tajawal')),SizedBox(height:4),Text(body,textDirection:TextDirection.rtl,style:TextStyle(fontSize:12,color:AC.ts,fontFamily:'Tajawal',height:1.5))])),SizedBox(width:10),Icon(icon,color:AC.cyan,size:20)]));
}
