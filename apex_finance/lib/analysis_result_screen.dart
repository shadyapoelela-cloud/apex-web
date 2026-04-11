// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api_service.dart';

class AnalysisResultScreen extends StatefulWidget {
  final Map<String,dynamic>? apiData;
  final dynamic pickedFile;
  const AnalysisResultScreen({super.key, this.apiData, this.pickedFile});
  @override State<AnalysisResultScreen> createState() => _AnalysisResultScreenState();
}

class _AnalysisResultScreenState extends State<AnalysisResultScreen> with TickerProviderStateMixin {
  int _tab = 0;
  bool _loadingPdf = false, _loadingExcel = false;
  late AnimationController _scoreAnim;
  late Animation<double> _scoreValue;
  static const _bg=Color(0xFF050D1A);static const _surface=Color(0xFF080F1F);static const _card=Color(0xFF0D1829);static const _gold=Color(0xFFC9A84C);static const _cyan=Color(0xFF00C2E0);static const _success=Color(0xFF2ECC8A);static const _danger=Color(0xFFE05050);static const _warning=Color(0xFFE8A838);static const _border=Color(0x26C9A84C);static const _textPri=Color(0xFFF0EDE6);static const _textSec=Color(0xFF8A8880);
  static const _tabLabels=['الربحية','السيولة','الكفاءة','الرفع المالي'];
  List<dynamic> get _ratios=>widget.apiData?['data']?['ratios']??[];
  List<dynamic> get _insights=>widget.apiData?['data']?['ai_insights']??[];
  double get _score=>((widget.apiData?['data']?['readiness_score'])??0).toDouble();
  String get _label=>widget.apiData?['data']?['readiness_label']??'';
  Map get _summary=>widget.apiData?['data']?['summary']??{};
  List<dynamic> get _warnings=>widget.apiData?['data']?['warnings']??[];
  @override
  void initState(){super.initState();_scoreAnim=AnimationController(vsync:this,duration:const Duration(milliseconds:1200));_scoreValue=Tween<double>(begin:0,end:_score/100).animate(CurvedAnimation(parent:_scoreAnim,curve:Curves.easeOutCubic));Future.delayed(const Duration(milliseconds:300),()=>_scoreAnim.forward());}
  @override void dispose(){_scoreAnim.dispose();super.dispose();}
  List<dynamic> _filteredRatios(int tab){final cats={0:['Gross Profit Margin','Net Profit Margin','EBITDA Margin','Return on Equity','Return on Assets'],1:['Current Ratio','Quick Ratio','Cash Ratio'],2:['Asset Turnover','Days Sales Outstanding','Inventory Days','Working Capital to Assets'],3:['Debt to Equity','Debt to Assets','Interest Coverage','Revenue Growth Rate']};return _ratios.where((r)=>(cats[tab]??[]).contains(r['name_en'])).toList();}
  Color _statusColor(String? s){if(s=='good')return _success;if(s=='warning')return _warning;return _danger;}
  String _fmt(dynamic v){if(v==null)return '—';final n=(v is num)?v.toDouble():double.tryParse(v.toString())??0.0;if(n.abs()>=1e9)return '${(n/1e9).toStringAsFixed(1)}B';if(n.abs()>=1e6)return '${(n/1e6).toStringAsFixed(1)}M';if(n.abs()>=1e3)return '${(n/1e3).toStringAsFixed(1)}K';return n.toStringAsFixed(1);}
  Future<void> _downloadReport(String type)async{if(widget.pickedFile==null)return;setState((){if(type=='pdf')_loadingPdf=true;else _loadingExcel=true;});try{final bytes=await ApiService.downloadReport(type:type,fileBytes:widget.pickedFile.bytes!,fileName:widget.pickedFile.name);if(bytes!=null){final mime=type=='pdf'?'application/pdf':'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';final blob=html.Blob([bytes],mime);final url=html.Url.createObjectUrlFromBlob(blob);(html.document.createElement('a')as html.AnchorElement)..href=url..download=type=='pdf'?'apex_report.pdf':'apex_report.xlsx'..click();html.Url.revokeObjectUrl(url);}}catch(_){}finally{setState((){_loadingPdf=false;_loadingExcel=false;});}}
  @override
  Widget build(BuildContext context){
    return Scaffold(backgroundColor:_bg,
      appBar:AppBar(backgroundColor:_surface,
        title:const Text('نتائج التحليل المالي',style:TextStyle(fontFamily:'Tajawal',color:Color(0xFFF0EDE6),fontSize:16,fontWeight:FontWeight.w700)),
        actions:[TextButton.icon(onPressed:()=>_downloadReport('pdf'),icon:const Icon(Icons.download_rounded,color:Color(0xFFC9A84C),size:18),label:const Text('PDF',style:TextStyle(color:Color(0xFFC9A84C),fontFamily:'Tajawal',fontSize:13)))],
        bottom:PreferredSize(preferredSize:const Size.fromHeight(1),child:Container(color:_border,height:1))),
      body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(children:[
        // ── Score Card ──
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(18),border:Border.all(color:_gold.withValues(alpha: 0.35))),
          child:Row(children:[
            AnimatedBuilder(animation:_scoreValue,builder:(_,__)=>SizedBox(width:88,height:88,child:CustomPaint(painter:_RingPainter(_scoreValue.value,_gold),child:Center(child:Text('${(_scoreValue.value*100).toInt()}',style:const TextStyle(color:Color(0xFFC9A84C),fontSize:22,fontWeight:FontWeight.w900,fontFamily:'Tajawal')))))),
            const SizedBox(width:16),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
              const Text('درجة الجاهزية الاستثمارية',textDirection:TextDirection.rtl,style:TextStyle(fontSize:12,color:Color(0xFF8A8880),fontFamily:'Tajawal')),
              const SizedBox(height:4),
              Text('${_score.toInt()} / 100',style:const TextStyle(fontSize:30,fontWeight:FontWeight.w900,color:Color(0xFFC9A84C),fontFamily:'Tajawal')),
              const SizedBox(height:6),
              if(_label.isNotEmpty)Container(padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),decoration:BoxDecoration(color:_success.withValues(alpha: 0.1),borderRadius:BorderRadius.circular(20),border:Border.all(color:_success.withValues(alpha: 0.3))),child:Text(_label,style:const TextStyle(fontSize:12,color:Color(0xFF2ECC8A),fontFamily:'Tajawal'))),
            ])),
          ])),
        const SizedBox(height:14),
        // ── Warnings ──
        if(_warnings.isNotEmpty)...[
          ..._warnings.map((w){final text=w is String?w:(w['message']??w.toString());return Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.symmetric(horizontal:14,vertical:10),decoration:BoxDecoration(color:_warning.withValues(alpha: 0.08),borderRadius:BorderRadius.circular(10),border:Border.all(color:_warning.withValues(alpha: 0.3))),child:Row(children:[const Icon(Icons.warning_amber_rounded,color:Color(0xFFE8A838),size:16),const SizedBox(width:8),Expanded(child:Text(text,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:12,color:Color(0xFFE8A838),fontFamily:'Tajawal')))]));}),
          const SizedBox(height:8),
        ],
        // ── Summary Cards ──
        Builder(builder:(_){
          final items=<(String,String,Color)>[];
          final rev=_summary['total_revenue']??_summary['revenue'];final np=_summary['net_profit'];final as2=_summary['total_assets'];final eq=_summary['total_equity'];
          if(rev!=null)items.add(('الإيرادات',_fmt(rev),_cyan));if(np!=null)items.add(('صافي الربح',_fmt(np),(np as num)>=0?_success:_danger));if(as2!=null)items.add(('الأصول',_fmt(as2),_gold));if(eq!=null)items.add(('حقوق الملكية',_fmt(eq),_warning));
          if(items.isEmpty)return const SizedBox.shrink();
          return Row(children:items.map((s)=>Expanded(child:Container(margin:const EdgeInsets.only(left:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(12),border:Border.all(color:s.$3.withValues(alpha: 0.25))),child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(s.$1,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:10,color:Color(0xFF8A8880),fontFamily:'Tajawal')),const SizedBox(height:4),Text(s.$2,style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:s.$3,fontFamily:'Tajawal'))])))).toList());
        }),
        const SizedBox(height:14),
        // ── Insights ──
        if(_insights.isNotEmpty)...[
          const Align(alignment:Alignment.centerRight,child:Text('توصيات الذكاء الاصطناعي',textDirection:TextDirection.rtl,style:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Color(0xFFF0EDE6),fontFamily:'Tajawal'))),
          const SizedBox(height:10),
          ..._insights.map((ins){final type=ins['type']??'';final color=type=='strength'?_success:type=='opportunity'?_cyan:_warning;return Padding(padding:const EdgeInsets.only(bottom:8),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withValues(alpha: 0.2))),child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:2),decoration:BoxDecoration(color:color.withValues(alpha: 0.1),borderRadius:BorderRadius.circular(6)),child:Text(type=='strength'?'نقطة قوة':type=='opportunity'?'فرصة':'مخاطرة',style:TextStyle(fontSize:10,color:color,fontFamily:'Tajawal'))),Expanded(child:Text(ins['title']??'',textDirection:TextDirection.rtl,style:TextStyle(fontSize:13,fontWeight:FontWeight.w700,color:color,fontFamily:'Tajawal')))]),const SizedBox(height:6),Text(ins['text']??'',textDirection:TextDirection.rtl,style:const TextStyle(fontSize:12,color:Color(0xFF8A8880),fontFamily:'Tajawal',height:1.5))])));}),
          const SizedBox(height:8),
        ],
        // ── Ratios ──
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:4),decoration:BoxDecoration(color:_gold.withValues(alpha: 0.08),borderRadius:BorderRadius.circular(6),border:Border.all(color:_gold.withValues(alpha: 0.2))),child:Text('${_ratios.length} نسبة',style:const TextStyle(fontSize:11,color:Color(0xFFC9A84C),fontFamily:'Tajawal'))),const Text('النسب المالية',textDirection:TextDirection.rtl,style:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Color(0xFFF0EDE6),fontFamily:'Tajawal'))]),
        const SizedBox(height:10),
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:List.generate(_tabLabels.length,(i)=>GestureDetector(onTap:()=>setState(()=>_tab=i),child:AnimatedContainer(duration:const Duration(milliseconds:180),margin:const EdgeInsets.only(left:8),padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),decoration:BoxDecoration(color:_tab==i?_gold.withValues(alpha: 0.12):_card,borderRadius:BorderRadius.circular(8),border:Border.all(color:_tab==i?_gold:_border)),child:Text(_tabLabels[i],style:TextStyle(fontSize:13,color:_tab==i?_gold:_textSec,fontFamily:'Tajawal'))))))),
        const SizedBox(height:10),
        Container(decoration:BoxDecoration(color:_card,borderRadius:BorderRadius.circular(16),border:Border.all(color:_border)),
          child:_filteredRatios(_tab).isEmpty?const Padding(padding:EdgeInsets.all(24),child:Center(child:Text('لا توجد بيانات',style:TextStyle(color:Color(0xFF8A8880),fontFamily:'Tajawal')))):Column(children:_filteredRatios(_tab).asMap().entries.map((e){
            final r=e.value;final isLast=e.key==_filteredRatios(_tab).length-1;final score=((r['score'])??0).toDouble();final color=_statusColor(r['status']);final value=r['value']?.toString()??'—';final unit=r['unit']??'';
            return Column(children:[
              Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),child:Row(children:[
                // ── أيقونة ! ──
                GestureDetector(onTap:()=>_showDetailPanel(context,r),child:Container(width:28,height:28,decoration:BoxDecoration(color:color.withValues(alpha: 0.12),shape:BoxShape.circle,border:Border.all(color:color.withValues(alpha: 0.4))),child:Center(child:Text('!',style:TextStyle(color:color,fontSize:14,fontWeight:FontWeight.w900))))),
                const SizedBox(width:10),
                Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('$value$unit',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800,color:color,fontFamily:'Tajawal')),const SizedBox(height:4),SizedBox(width:60,child:ClipRRect(borderRadius:BorderRadius.circular(2),child:LinearProgressIndicator(value:(score/100).clamp(0.0,1.0),minHeight:3,backgroundColor:_border,valueColor:AlwaysStoppedAnimation(color))))]),
                const Spacer(),
                Expanded(flex:3,child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(r['name_ar']??'',textDirection:TextDirection.rtl,style:const TextStyle(fontSize:13,color:Color(0xFFF0EDE6),fontWeight:FontWeight.w600,fontFamily:'Tajawal')),const SizedBox(height:2),Text(r['interpretation']??'',textDirection:TextDirection.rtl,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,color:Color(0xFF8A8880),fontFamily:'Tajawal',height:1.4))])),
              ])),
              if(!isLast)Divider(color:_border.withValues(alpha: 0.5),height:1,indent:14,endIndent:14),
            ]);
          }).toList())),
        const SizedBox(height:14),
        // ── Export Buttons ──
        Row(children:[
          Expanded(child:GestureDetector(onTap:_loadingPdf?null:()=>_downloadReport('pdf'),child:Container(height:52,decoration:BoxDecoration(gradient:const LinearGradient(colors:[Color(0xFFC9A84C),Color(0xFF8B6F35)]),borderRadius:BorderRadius.circular(14),boxShadow:[BoxShadow(color:_gold.withValues(alpha: 0.3),blurRadius:16,offset:const Offset(0,4))]),child:Center(child:_loadingPdf?const SizedBox(width:20,height:20,child:CircularProgressIndicator(color:Color(0xFF050D1A),strokeWidth:2)):const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.picture_as_pdf_rounded,color:Color(0xFF050D1A),size:18),SizedBox(width:6),Text('تحميل PDF',style:TextStyle(color:Color(0xFF050D1A),fontSize:14,fontWeight:FontWeight.w700,fontFamily:'Tajawal'))]))))),
          const SizedBox(width:10),
          Expanded(child:GestureDetector(onTap:_loadingExcel?null:()=>_downloadReport('excel'),child:Container(height:52,decoration:BoxDecoration(borderRadius:BorderRadius.circular(14),border:Border.all(color:_cyan.withValues(alpha: 0.4),width:1.5)),child:Center(child:_loadingExcel?const SizedBox(width:20,height:20,child:CircularProgressIndicator(color:Color(0xFF00C2E0),strokeWidth:2)):const Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(Icons.table_chart_rounded,color:Color(0xFF00C2E0),size:18),SizedBox(width:6),Text('تحميل Excel',style:TextStyle(color:Color(0xFF00C2E0),fontSize:14,fontWeight:FontWeight.w600,fontFamily:'Tajawal'))]))))),
        ]),
        const SizedBox(height:40),
      ])));
  }

  void _showDetailPanel(BuildContext context, Map ratio){
    showModalBottomSheet(context:context,backgroundColor:Colors.transparent,isScrollControlled:true,builder:(_)=>DraggableScrollableSheet(initialChildSize:0.72,minChildSize:0.4,maxChildSize:0.95,builder:(_,ctrl)=>Container(decoration:const BoxDecoration(color:Color(0xFF0D1829),borderRadius:BorderRadius.vertical(top:Radius.circular(24))),child:Column(children:[
      const SizedBox(height:10),Container(width:36,height:4,decoration:BoxDecoration(color:_border,borderRadius:BorderRadius.circular(2))),const SizedBox(height:16),
      Padding(padding:const EdgeInsets.symmetric(horizontal:20),child:Row(children:[
        Container(width:44,height:44,decoration:BoxDecoration(color:_statusColor(ratio['status']).withValues(alpha: 0.12),shape:BoxShape.circle,border:Border.all(color:_statusColor(ratio['status']).withValues(alpha: 0.4))),child:Center(child:Text('!',style:TextStyle(color:_statusColor(ratio['status']),fontSize:22,fontWeight:FontWeight.w900)))),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(ratio['name_ar']??'',textDirection:TextDirection.rtl,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:Color(0xFFF0EDE6),fontFamily:'Tajawal')),Text(ratio['name_en']??'',style:const TextStyle(fontSize:12,color:Color(0xFF8A8880),fontFamily:'Tajawal'))])),
      ])),
      const SizedBox(height:14),const Divider(color:Color(0x26C9A84C),height:1),
      Expanded(child:ListView(controller:ctrl,padding:const EdgeInsets.all(20),children:[
        Row(children:[
          Expanded(child:_infoCard('القيمة المحسوبة','${ratio['value']??'—'}${ratio['unit']??''}',_statusColor(ratio['status']))),
          const SizedBox(width:10),
          Expanded(child:_infoCard('درجة التقييم','${((ratio['score']??0)as num).toInt()} / 100',_statusColor(ratio['status']))),
        ]),const SizedBox(height:10),
        Row(children:[
          Expanded(child:_infoCard('مستوى الثقة','${((ratio['confidence']??ratio['score']??0)as num).toStringAsFixed(0)}%',const Color(0xFF2ECC8A))),
          const SizedBox(width:10),
          Expanded(child:_infoCard('مستوى الخطر',(ratio['risk_level']??ratio['status'])=='low'?'منخفض':(ratio['risk_level']??ratio['status'])=='medium'?'متوسط':'مرتفع',const Color(0xFFE8A838))),
        ]),const SizedBox(height:14),
        if((ratio['requires_human_review'])==true)...[Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_danger.withValues(alpha: 0.08),borderRadius:BorderRadius.circular(10),border:Border.all(color:_danger.withValues(alpha: 0.3))),child:const Row(children:[Icon(Icons.person_search_rounded,color:Color(0xFFE05050),size:18),SizedBox(width:8),Expanded(child:Text('هذه النتيجة تتطلب مراجعة بشرية قبل الاعتماد',textDirection:TextDirection.rtl,style:TextStyle(fontSize:12,color:Color(0xFFE05050),fontFamily:'Tajawal')))])),const SizedBox(height:14)],
        if((ratio['interpretation']??'').isNotEmpty)...[_sectionHeader('التفسير'),const SizedBox(height:8),Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFF111E32),borderRadius:BorderRadius.circular(10),border:Border.all(color:_border)),child:Text(ratio['interpretation'],textDirection:TextDirection.rtl,style:const TextStyle(fontSize:13,color:Color(0xFFF0EDE6),fontFamily:'Tajawal',height:1.6))),const SizedBox(height:14)],
        if((ratio['formula']??'').isNotEmpty)...[_sectionHeader('طريقة الحساب'),const SizedBox(height:8),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:_cyan.withValues(alpha: 0.05),borderRadius:BorderRadius.circular(10),border:Border.all(color:_cyan.withValues(alpha: 0.2))),child:Row(children:[const Icon(Icons.functions_rounded,color:Color(0xFF00C2E0),size:16),const SizedBox(width:8),Expanded(child:Text(ratio['formula'],textDirection:TextDirection.rtl,style:const TextStyle(fontSize:12,color:Color(0xFF00C2E0),fontFamily:'Tajawal',fontWeight:FontWeight.w600)))])),const SizedBox(height:14)],
        if((ratio['source_rows'] as List? ?? []).isNotEmpty)...[_sectionHeader('الحسابات المستخدمة'),const SizedBox(height:8),Container(decoration:BoxDecoration(color:const Color(0xFF111E32),borderRadius:BorderRadius.circular(10),border:Border.all(color:_border)),child:Column(children:(ratio['source_rows']as List).asMap().entries.map((e){final row=e.value;final isLast=e.key==(ratio['source_rows']as List).length-1;return Column(children:[Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:8),child:Row(children:[if(row is Map&&row['value']!=null)Text(row['value'].toString(),style:const TextStyle(fontSize:12,color:Color(0xFFC9A84C),fontFamily:'Tajawal',fontWeight:FontWeight.w600)),const Spacer(),Expanded(flex:3,child:Text(row is Map?(row['account_name']??row.toString()):row.toString(),textDirection:TextDirection.rtl,style:const TextStyle(fontSize:12,color:Color(0xFFF0EDE6),fontFamily:'Tajawal')))])),if(!isLast)const Divider(color:Color(0x26C9A84C),height:1,indent:12,endIndent:12)]);}).toList())),const SizedBox(height:14)],
        const SizedBox(height:20),
      ])),
    ]))));
  }

  Widget _infoCard(String label,String value,Color color)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFF111E32),borderRadius:BorderRadius.circular(10),border:Border.all(color:const Color(0x26C9A84C))),child:Column(crossAxisAlignment:CrossAxisAlignment.end,children:[Text(label,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:10,color:Color(0xFF8A8880),fontFamily:'Tajawal')),const SizedBox(height:4),Text(value,style:TextStyle(fontSize:16,fontWeight:FontWeight.w700,color:color,fontFamily:'Tajawal'))]));
  Widget _sectionHeader(String text)=>Row(children:[const Expanded(child:Divider(color:Color(0x26C9A84C))),const SizedBox(width:8),Text(text,textDirection:TextDirection.rtl,style:const TextStyle(fontSize:11,color:Color(0xFF8A8880),fontFamily:'Tajawal')),const SizedBox(width:8),const Expanded(child:Divider(color:Color(0x26C9A84C)))]);
}

class _RingPainter extends CustomPainter {
  final double value; final Color color;
  const _RingPainter(this.value,this.color);
  @override void paint(Canvas canvas,Size size){final center=Offset(size.width/2,size.height/2);final r=size.width/2-6;canvas.drawCircle(center,r,Paint()..color=color.withValues(alpha: 0.1)..strokeWidth=8..style=PaintingStyle.stroke);canvas.drawArc(Rect.fromCircle(center:center,radius:r),-math.pi/2,2*math.pi*value.clamp(0.0,1.0),false,Paint()..color=color..strokeWidth=8..style=PaintingStyle.stroke..strokeCap=StrokeCap.round);}
  @override bool shouldRepaint(_RingPainter old)=>old.value!=value;
}


