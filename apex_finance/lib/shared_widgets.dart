import 'package:flutter/material.dart';

class StepIndicator extends StatelessWidget {
  final int current;
  const StepIndicator({super.key, required this.current});
  static const _gold=Color(0xFFC9A84C);static const _success=Color(0xFF2ECC8A);static const _border=Color(0x26C9A84C);static const _textSec=Color(0xFF8A8880);
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

class HelpCard extends StatelessWidget {
  final IconData icon; final String title, body;
  const HelpCard({super.key, required this.icon, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF00C2E0).withOpacity(0.05),borderRadius:BorderRadius.circular(12),border:Border.all(color:const Color(0xFF00C2E0).withOpacity(0.2))),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(title,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:Color(0xFF00C2E0),fontFamily:'Tajawal')),const SizedBox(height:4),Text(body,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:12,color:Color(0xFF8A8880),fontFamily:'Tajawal',height:1.5))])),const SizedBox(width:10),Icon(icon,color:const Color(0xFF00C2E0),size:20)]));
}
