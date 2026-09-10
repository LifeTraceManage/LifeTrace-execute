import 'dart:async';
import 'package:flutter/material.dart';

void main()=>runApp(const LifeTracePreviewApp());

abstract final class C{
  static const p=Color(0xff2563eb), ps=Color(0xffeaf1ff), ink=Color(0xff18212f),
  muted=Color(0xff6b7280), bg=Color(0xfffafbff), surface=Colors.white,
  soft=Color(0xfff4f6fa), border=Color(0xffe4e7ec), orange=Color(0xfff59e0b),
  os=Color(0xfffff4e5), green=Color(0xff16a36a), red=Color(0xffdc4c4c);
}

class LifeTracePreviewApp extends StatelessWidget{
  const LifeTracePreviewApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'LifeTrace Execute',
    theme:ThemeData(
      useMaterial3:true,scaffoldBackgroundColor:C.bg,
      colorScheme:const ColorScheme.light(primary:C.p,surface:C.surface,onSurface:C.ink,outline:C.border,error:C.red),
      textTheme:const TextTheme(
        headlineMedium:TextStyle(fontSize:28,fontWeight:FontWeight.w800,height:1.15),
        titleLarge:TextStyle(fontSize:22,fontWeight:FontWeight.w800),
        titleMedium:TextStyle(fontSize:16,fontWeight:FontWeight.w700),
        bodyMedium:TextStyle(fontSize:13),
      ),
      inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:C.soft,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none)),
      filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
        minimumSize:const Size(0,52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)))),
      navigationBarTheme:const NavigationBarThemeData(height:72,backgroundColor:C.surface,indicatorColor:C.ps),
    ),home:const Shell());
}

class Shell extends StatefulWidget{const Shell({super.key});@override State<Shell> createState()=>_ShellState();}
class _ShellState extends State<Shell>{
  int i=0;
  final pages=const [Today(),Tasks(),Projects(),Calendar(),Collection()];
  @override Widget build(BuildContext c)=>Scaffold(
    body:SafeArea(bottom:false,child:IndexedStack(index:i,children:pages)),
    bottomNavigationBar:NavigationBar(selectedIndex:i,onDestinationSelected:(v)=>setState(()=>i=v),destinations:const[
      NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home_rounded),label:'今天'),
      NavigationDestination(icon:Icon(Icons.checklist_rounded),label:'任务'),
      NavigationDestination(icon:Icon(Icons.folder_outlined),selectedIcon:Icon(Icons.folder_rounded),label:'项目'),
      NavigationDestination(icon:Icon(Icons.calendar_month_outlined),selectedIcon:Icon(Icons.calendar_month_rounded),label:'日历'),
      NavigationDestination(icon:Icon(Icons.inbox_outlined),selectedIcon:Icon(Icons.inbox_rounded),label:'收集'),
    ]));
}

Widget scroll(List<Widget> x,{EdgeInsets p=const EdgeInsets.fromLTRB(20,18,20,28)})=>
  ListView(padding:p,physics:const BouncingScrollPhysics(),children:x);
Widget section(BuildContext c,String s,{Widget? tail})=>Padding(
  padding:const EdgeInsets.only(top:22,bottom:10),child:Row(children:[
  Expanded(child:Text(s,style:Theme.of(c).textTheme.titleMedium)),if(tail!=null)tail]));
Widget card(Widget child,{Color color=C.surface,VoidCallback? tap,EdgeInsets p=const EdgeInsets.all(16)}){
  final w=Container(padding:p,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(18),border:Border.all(color:C.border)),child:child);
  return tap==null?w:InkWell(borderRadius:BorderRadius.circular(18),onTap:tap,child:w);
}
Widget pill(String s,{Color bg=C.soft,Color fg=C.muted})=>Container(
  padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(999)),
  child:Text(s,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:fg)));

class Today extends StatelessWidget{
  const Today({super.key});
  @override Widget build(BuildContext c){
    final n=DateTime.now(), names=['一','二','三','四','五','六','日'];
    return scroll([
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${n.month}月${n.day}日 · 星期${names[n.weekday-1]}',style:const TextStyle(fontSize:12,color:C.muted,fontWeight:FontWeight.w600)),
          const SizedBox(height:6),Text('早上好，Alex',style:Theme.of(c).textTheme.headlineMedium)])),
        InkWell(borderRadius:BorderRadius.circular(30),onTap:()=>push(c,const Profile()),child:const CircleAvatar(
          radius:22,backgroundColor:C.ps,child:Icon(Icons.person_rounded,color:C.p))),
      ]),
      const SizedBox(height:22),const WeekStrip(),const SizedBox(height:22),
      card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Row(children:[Icon(Icons.bolt_rounded,size:18,color:C.p),SizedBox(width:6),
          Text('TODAY FOCUS',style:TextStyle(letterSpacing:1.1,fontSize:11,fontWeight:FontWeight.w800,color:C.p))]),
        const SizedBox(height:14),Text('完成 LifeTrace Execute 任务闭环',style:Theme.of(c).textTheme.titleLarge),
        const SizedBox(height:10),Wrap(spacing:7,runSpacing:7,children:[
          pill('LifeTrace Execute',bg:Colors.white,fg:C.p),pill('高优先级',bg:const Color(0xffffeded),fg:C.red),pill('18:00 截止',bg:Colors.white)]),
        const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton.icon(
          onPressed:()=>push(c,const Focus()),icon:const Icon(Icons.timer_rounded),label:const Text('开始专注'))),
      ]),color:C.ps,p:const EdgeInsets.all(18)),
      section(c,'今日概览'),card(const Row(children:[
        Expanded(child:_Metric('8','待办')),VerticalDivider(width:1),Expanded(child:_Metric('3','已完成')),
        VerticalDivider(width:1),Expanded(child:_Metric('95m','专注'))])),
      section(c,'时间线'),
      _Timeline('10:00','完善 Execute 前端','进行中 · 预计 45 分钟',true,()=>push(c,const TaskDetail())),
      _Timeline('11:00','整理项目里程碑','LifeTrace Execute',false,()=>push(c,const ProjectDetail())),
      _Timeline('14:00','论文实验记录','Academic · 预计 60 分钟',false,()=>push(c,const TaskDetail())),
      section(c,'今日任务',tail:TextButton(onPressed:(){},child:const Text('查看全部'))),
      card(Column(children:[
        TaskRow('补充交互说明','LifeTrace · 今天 18:00',priority:true,tap:()=>push(c,const TaskDetail())),
        const Divider(height:1),TaskRow('完成英语练习','Personal · 20 分钟',tap:()=>push(c,const TaskDetail()))])),
      section(c,'今日复盘'),
      card(const Row(children:[CircleAvatar(backgroundColor:Colors.white,child:Icon(Icons.auto_awesome_rounded,color:C.orange)),
        SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('用 2 分钟结束今天',style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:4),
          Text('记录收获、问题与明日第一优先级',style:TextStyle(fontSize:11,color:C.muted))])),
        Icon(Icons.chevron_right_rounded,color:C.orange)]),color:C.os,tap:()=>push(c,const Review())),
    ]);
  }
}
class _Metric extends StatelessWidget{const _Metric(this.n,this.s);final String n,s;
 @override Widget build(BuildContext c)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text(n,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800)),Text(s,style:const TextStyle(fontSize:11,color:C.muted,fontWeight:FontWeight.w600))]);}

class WeekStrip extends StatelessWidget{
 const WeekStrip({super.key});
 @override Widget build(BuildContext c){final n=DateTime.now(), mon=DateTime(n.year,n.month,n.day-(n.weekday-1));const w=['一','二','三','四','五','六','日'];
 return Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:List.generate(7,(i){
  final d=mon.add(Duration(days:i)),sel=d.year==n.year&&d.month==n.month&&d.day==n.day;
  return Semantics(button:false,child:SizedBox(width:42,child:Column(children:[
    Text(w[i],style:const TextStyle(fontSize:11,color:C.muted,fontWeight:FontWeight.w600)),const SizedBox(height:7),
    Container(width:34,height:34,alignment:Alignment.center,decoration:BoxDecoration(color:sel?C.p:Colors.transparent,borderRadius:BorderRadius.circular(12)),
    child:Text('${d.day}',style:TextStyle(fontSize:14,fontWeight:sel?FontWeight.w800:FontWeight.w600,color:sel?Colors.white:C.ink)))])));
 }));}
}

class _Timeline extends StatelessWidget{
 const _Timeline(this.time,this.title,this.meta,this.active,this.tap);final String time,title,meta;final bool active;final VoidCallback tap;
 @override Widget build(BuildContext c)=>InkWell(borderRadius:BorderRadius.circular(14),onTap:tap,child:Padding(
  padding:const EdgeInsets.symmetric(vertical:8),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
   SizedBox(width:48,child:Text(time,style:TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:active?C.p:C.muted))),
   Column(children:[Container(width:10,height:10,margin:const EdgeInsets.only(top:3),decoration:BoxDecoration(color:active?C.p:C.border,shape:BoxShape.circle)),
    Container(width:2,height:43,color:C.border)]),const SizedBox(width:12),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w700)),const SizedBox(height:3),Text(meta,style:const TextStyle(fontSize:11,color:C.muted))]))])));}

class TaskRow extends StatelessWidget{
 const TaskRow(this.title,this.meta,{super.key,this.done=false,this.priority=false,this.tap});final String title,meta;final bool done,priority;final VoidCallback? tap;
 @override Widget build(BuildContext c)=>InkWell(borderRadius:BorderRadius.circular(14),onTap:tap,child:Padding(
  padding:const EdgeInsets.symmetric(vertical:10),child:Row(children:[
   Icon(done?Icons.check_circle_rounded:Icons.circle_outlined,size:22,color:done?C.green:C.border),const SizedBox(width:12),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Expanded(child:Text(title,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:14,fontWeight:FontWeight.w700,decoration:done?TextDecoration.lineThrough:null))),
     if(priority)const Icon(Icons.flag_rounded,size:16,color:C.red)]),const SizedBox(height:4),Text(meta,style:const TextStyle(fontSize:11,color:C.muted))])),
   const SizedBox(width:8),const Icon(Icons.chevron_right_rounded,color:C.muted)])));}

enum TF{all,today,soon,waiting}
class Tasks extends StatefulWidget{const Tasks({super.key});@override State<Tasks> createState()=>_TasksState();}
class _TasksState extends State<Tasks>{
 TF f=TF.all;
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:C.bg,
  floatingActionButton:FloatingActionButton(backgroundColor:C.p,foregroundColor:Colors.white,onPressed:()=>composer(c),child:const Icon(Icons.add_rounded)),
  body:scroll([
   Text('任务',style:Theme.of(c).textTheme.headlineMedium),const SizedBox(height:16),
   const TextField(decoration:InputDecoration(hintText:'搜索任务',prefixIcon:Icon(Icons.search_rounded),suffixIcon:Icon(Icons.tune_rounded))),
   const SizedBox(height:14),SingleChildScrollView(scrollDirection:Axis.horizontal,child:SegmentedButton<TF>(
    showSelectedIcon:false,segments:const[
     ButtonSegment(value:TF.all,label:Text('全部')),ButtonSegment(value:TF.today,label:Text('今天')),
     ButtonSegment(value:TF.soon,label:Text('即将到期')),ButtonSegment(value:TF.waiting,label:Text('等待中'))],
    selected:{f},onSelectionChanged:(v)=>setState(()=>f=v.first))),
   section(c,'今天 · 4'),card(Column(children:[
    TaskRow('完善 Execute 前端','LifeTrace · 18:00 · 高优先级',priority:true,tap:()=>push(c,const TaskDetail())),const Divider(height:1),
    TaskRow('整理项目里程碑','LifeTrace · 今天',tap:()=>push(c,const TaskDetail())),const Divider(height:1),
    TaskRow('论文实验记录','Academic · 今天',tap:()=>push(c,const TaskDetail())),const Divider(height:1),
    TaskRow('完成英语练习','Personal · 20 分钟',tap:()=>push(c,const TaskDetail()))])),
   section(c,'稍后 · 3'),card(Column(children:[
    TaskRow('补充周报','明天',tap:()=>push(c,const TaskDetail())),const Divider(height:1),TaskRow('查看同步冲突','本周',tap:()=>push(c,const TaskDetail()))]))
  ]));
 Future<void> composer(BuildContext c)=>showModalBottomSheet(context:c,isScrollControlled:true,showDragHandle:true,builder:(x)=>Padding(
  padding:EdgeInsets.fromLTRB(20,0,20,20+MediaQuery.of(x).viewInsets.bottom),child:Column(mainAxisSize:MainAxisSize.min,children:[
   const TextField(autofocus:true,decoration:InputDecoration(hintText:'任务标题')),const SizedBox(height:12),
   const TextField(maxLines:3,decoration:InputDecoration(hintText:'描述')),const SizedBox(height:16),
   SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(x),child:const Text('保存任务')))])));
}

class TaskDetail extends StatefulWidget{const TaskDetail({super.key});@override State<TaskDetail> createState()=>_TaskDetailState();}
class _TaskDetailState extends State<TaskDetail>{
 bool a=true,b=false;
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:C.bg,appBar:AppBar(backgroundColor:C.bg,title:const Text('任务详情'),actions:[
  IconButton(onPressed:(){},icon:const Icon(Icons.more_horiz_rounded))]),
  body:scroll([
   Text('完善 LifeTrace Execute 前端',style:Theme.of(c).textTheme.headlineMedium),const SizedBox(height:8),
   const Text('把完整执行闭环的 UI、状态和交互说明补齐。',style:TextStyle(color:C.muted)),
   section(c,'属性'),card(const Column(children:[
    Prop(Icons.folder_outlined,'项目','LifeTrace Execute'),Divider(height:1),Prop(Icons.priority_high_rounded,'优先级','高',red:true),Divider(height:1),
    Prop(Icons.event_outlined,'计划时间','9月10日 10:00'),Divider(height:1),Prop(Icons.flag_outlined,'截止时间','9月10日 18:00'),Divider(height:1),
    Prop(Icons.notifications_none_rounded,'提醒','提前 30 分钟'),Divider(height:1),Prop(Icons.repeat_rounded,'重复','不重复')])),
   section(c,'子任务'),card(Column(children:[
    CheckboxListTile(contentPadding:EdgeInsets.zero,value:a,title:const Text('整理 Today 页面'),controlAffinity:ListTileControlAffinity.leading,onChanged:(v)=>setState(()=>a=v??false)),
    const Divider(height:1),CheckboxListTile(contentPadding:EdgeInsets.zero,value:b,title:const Text('补充交互说明'),controlAffinity:ListTileControlAffinity.leading,onChanged:(v)=>setState(()=>b=v??false))])),
   const SizedBox(height:24),SizedBox(width:double.infinity,child:FilledButton.icon(onPressed:()=>push(c,const Focus()),icon:const Icon(Icons.timer_rounded),label:const Text('开始专注')))
  ],p:const EdgeInsets.fromLTRB(20,8,20,30)));
}
class Prop extends StatelessWidget{
 const Prop(this.icon,this.label,this.value,{super.key,this.red=false});final IconData icon;final String label,value;final bool red;
 @override Widget build(BuildContext c)=>ListTile(contentPadding:EdgeInsets.zero,leading:Icon(icon,color:C.muted),title:Text(label,style:const TextStyle(fontWeight:FontWeight.w600)),
  trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(value,style:TextStyle(fontSize:12,color:red?C.red:C.muted)),const SizedBox(width:3),
   const Icon(Icons.chevron_right_rounded,size:18,color:C.muted)]),onTap:(){});}

class Focus extends StatefulWidget{const Focus({super.key});@override State<Focus> createState()=>_FocusState();}
class _FocusState extends State<Focus>{
 static const total=1500;int left=total;Timer? t;bool run=false;
 @override void dispose(){t?.cancel();super.dispose();}
 void toggle(){if(run){t?.cancel();setState(()=>run=false);return;}t=Timer.periodic(const Duration(seconds:1),(_){
  if(left<=0){t?.cancel();setState(()=>run=false);}else{setState(()=>left--);}});setState(()=>run=true);}
 String get time=>'${(left~/60).toString().padLeft(2,'0')}:${(left%60).toString().padLeft(2,'0')}';
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:C.bg,appBar:AppBar(backgroundColor:C.bg,title:const Text('专注')),body:scroll([
  Text('完善 LifeTrace Execute 前端',style:Theme.of(c).textTheme.titleLarge,textAlign:TextAlign.center),const SizedBox(height:5),
  const Text('LifeTrace Execute',textAlign:TextAlign.center,style:TextStyle(color:C.muted,fontSize:12)),const SizedBox(height:44),
  Center(child:SizedBox(width:238,height:238,child:Stack(fit:StackFit.expand,children:[
   CircularProgressIndicator(value:(1-left/total).clamp(.02,1).toDouble(),strokeWidth:12,backgroundColor:C.ps,strokeCap:StrokeCap.round),
   Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(time,style:const TextStyle(fontSize:48,fontWeight:FontWeight.w800,letterSpacing:-1.5)),
    const SizedBox(height:6),Text(run?'专注中':'准备开始',style:const TextStyle(color:C.muted,fontWeight:FontWeight.w700))]))]))),
  const SizedBox(height:36),Row(children:[Expanded(child:FilledButton.icon(onPressed:toggle,icon:Icon(run?Icons.pause_rounded:Icons.play_arrow_rounded),label:Text(run?'暂停':'开始'))),
   const SizedBox(width:12),Expanded(child:OutlinedButton.icon(onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.stop_rounded),label:const Text('结束')))]),
  section(c,'本次专注'),card(const Column(children:[MetricRow('已专注','18 分钟'),Divider(height:1),MetricRow('今日累计','1 小时 35 分钟'),Divider(height:1),MetricRow('今日番茄','3')]))
 ]));
}
class MetricRow extends StatelessWidget{const MetricRow(this.a,this.b,{super.key});final String a,b;
 @override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.symmetric(vertical:13),child:Row(children:[
  Expanded(child:Text(a,style:const TextStyle(color:C.muted))),Text(b,style:const TextStyle(fontWeight:FontWeight.w800))]));}

enum PF{all,active,paused,done}
class Projects extends StatefulWidget{const Projects({super.key});@override State<Projects> createState()=>_ProjectsState();}
class _ProjectsState extends State<Projects>{PF f=PF.active;
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:C.bg,floatingActionButton:FloatingActionButton(
  backgroundColor:C.p,foregroundColor:Colors.white,onPressed:(){},child:const Icon(Icons.add_rounded)),body:scroll([
   Text('项目',style:Theme.of(c).textTheme.headlineMedium),const SizedBox(height:16),
   SingleChildScrollView(scrollDirection:Axis.horizontal,child:SegmentedButton<PF>(showSelectedIcon:false,segments:const[
    ButtonSegment(value:PF.all,label:Text('全部')),ButtonSegment(value:PF.active,label:Text('进行中')),
    ButtonSegment(value:PF.paused,label:Text('暂停')),ButtonSegment(value:PF.done,label:Text('完成'))],selected:{f},onSelectionChanged:(v)=>setState(()=>f=v.first))),
   const SizedBox(height:18),
   ProjectCard('LifeTrace Execute','12 个任务 · 7 已完成','下一里程碑：完整任务闭环',.58,()=>push(c,const ProjectDetail())),
   const SizedBox(height:12),ProjectCard('Academic Research','8 个任务 · 3 已完成','下一里程碑：理论方案定稿',.38,()=>push(c,const ProjectDetail())),
   const SizedBox(height:12),ProjectCard('Personal Growth','5 个任务 · 2 已完成','英语与健身',.40,()=>push(c,const ProjectDetail()))
 ]));}
class ProjectCard extends StatelessWidget{
 const ProjectCard(this.name,this.meta,this.mile,this.progress,this.tap,{super.key});final String name,meta,mile;final double progress;final VoidCallback tap;
 @override Widget build(BuildContext c)=>card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Row(children:[Container(width:38,height:38,decoration:BoxDecoration(color:C.ps,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.folder_rounded,color:C.p)),
   const SizedBox(width:12),Expanded(child:Text(name,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800))),const Icon(Icons.chevron_right_rounded,color:C.muted)]),
  const SizedBox(height:15),LinearProgressIndicator(value:progress,minHeight:7,backgroundColor:C.ps),const SizedBox(height:9),
  Text(meta,style:const TextStyle(fontSize:11,color:C.muted)),const SizedBox(height:3),Text(mile,style:const TextStyle(fontSize:11,color:C.muted))
 ]),tap:tap,p:const EdgeInsets.all(18));}

class ProjectDetail extends StatelessWidget{
 const ProjectDetail({super.key});
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:C.bg,appBar:AppBar(backgroundColor:C.bg,title:const Text('项目详情')),body:scroll([
  Text('LifeTrace Execute',style:Theme.of(c).textTheme.headlineMedium),const SizedBox(height:6),const Text('构建个人执行与复盘中心',style:TextStyle(color:C.muted)),
  const SizedBox(height:20),card(const Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('总体进度',style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:12),LinearProgressIndicator(value:.58,minHeight:8,backgroundColor:C.ps),
   SizedBox(height:9),Text('7 / 12 已完成 · 本周预计完成 3 项',style:TextStyle(fontSize:11,color:C.muted))])),
  section(c,'里程碑'),card(const Column(children:[Prop(Icons.flag_rounded,'任务闭环','进行中 · 9月12日'),Divider(height:1),Prop(Icons.outlined_flag_rounded,'项目闭环','未开始 · 9月18日')])),
  section(c,'项目任务'),card(Column(children:[
   TaskRow('完善 Today 页面','今天',tap:()=>push(c,const TaskDetail())),const Divider(height:1),
   TaskRow('补充同步冲突 UI','明天',tap:()=>push(c,const TaskDetail())),const Divider(height:1),TaskRow('完成 FocusSession','本周',tap:()=>push(c,const TaskDetail()))]))
 ],p:const EdgeInsets.fromLTRB(20,8,20,30)));}

class Calendar extends StatefulWidget{const Calendar({super.key});@override State<Calendar> createState()=>_CalendarState();}
class _CalendarState extends State<Calendar>{DateTime d=DateTime.now();
 @override Widget build(BuildContext c){final first=DateTime(d.year,d.month,1),days=DateTime(d.year,d.month+1,0).day,lead=first.weekday-1;
 return scroll([
  Row(children:[Expanded(child:Text('日历',style:Theme.of(c).textTheme.headlineMedium)),IconButton(onPressed:()=>setState(()=>d=DateTime.now()),icon:const Icon(Icons.today_rounded))]),
  const SizedBox(height:10),Row(children:[Expanded(child:Text('${d.year}年${d.month}月',style:Theme.of(c).textTheme.titleLarge)),
   IconButton(onPressed:()=>setState(()=>d=DateTime(d.year,d.month-1,1)),icon:const Icon(Icons.chevron_left_rounded)),
   IconButton(onPressed:()=>setState(()=>d=DateTime(d.year,d.month+1,1)),icon:const Icon(Icons.chevron_right_rounded))]),
  const SizedBox(height:12),Row(children:[for(final x in ['一','二','三','四','五','六','日']) Expanded(child:Center(child:Text(x,style:const TextStyle(fontSize:11,color:C.muted))))]),
  const SizedBox(height:8),GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,mainAxisExtent:46),
   itemCount:lead+days,itemBuilder:(_,i){if(i<lead){return const SizedBox.shrink();}final day=i-lead+1,sel=d.day==day,event={10,12,18,25}.contains(day);
    return InkWell(borderRadius:BorderRadius.circular(12),onTap:()=>setState(()=>d=DateTime(d.year,d.month,day)),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
     Container(width:32,height:30,alignment:Alignment.center,decoration:BoxDecoration(color:sel?C.p:Colors.transparent,borderRadius:BorderRadius.circular(10)),
      child:Text('$day',style:TextStyle(fontSize:13,fontWeight:sel?FontWeight.w800:FontWeight.w600,color:sel?Colors.white:C.ink))),
     const SizedBox(height:2),Container(width:4,height:4,decoration:BoxDecoration(shape:BoxShape.circle,color:event?C.orange:Colors.transparent))]));}),
  section(c,'${d.month}月${d.day}日'),card(const Column(children:[
   Agenda('10:00','完善 Execute 前端','任务 · 45 分钟'),Divider(height:1),Agenda('14:00','论文实验记录','任务 · 60 分钟'),Divider(height:1),Agenda('18:00','Today 页面截止','提醒')])),
  section(c,'近期重要日期'),card(const Row(children:[Icon(Icons.cake_outlined,color:C.orange),SizedBox(width:12),
   Expanded(child:Text('9月18日 · 重要日期',style:TextStyle(fontWeight:FontWeight.w700))),Icon(Icons.chevron_right_rounded,color:C.orange)]),color:C.os)
 ]);}
}
class Agenda extends StatelessWidget{const Agenda(this.time,this.title,this.meta,{super.key});final String time,title,meta;
 @override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
  SizedBox(width:54,child:Text(time,style:const TextStyle(color:C.p,fontWeight:FontWeight.w800,fontSize:12))),
  Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),const SizedBox(height:3),
   Text(meta,style:const TextStyle(fontSize:11,color:C.muted))]))]));}

class Collection extends StatelessWidget{
 const Collection({super.key});
 @override Widget build(BuildContext c){const a=[(Icons.edit_note_rounded,'文字'),(Icons.image_outlined,'图片'),(Icons.mic_none_rounded,'语音'),
  (Icons.link_rounded,'链接'),(Icons.attach_file_rounded,'文件'),(Icons.lightbulb_outline_rounded,'灵感')];
 return scroll([
  Text('收集',style:Theme.of(c).textTheme.headlineMedium),section(c,'快速收集'),
  GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:3,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.2,children:[
   for(final x in a)InkWell(borderRadius:BorderRadius.circular(16),onTap:()=>capture(c,x.$2),child:Container(decoration:BoxDecoration(color:C.surface,borderRadius:BorderRadius.circular(16),border:Border.all(color:C.border)),
    child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(x.$1,color:C.p),const SizedBox(height:8),Text(x.$2,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w700))]))) ]),
  section(c,'Inbox · 4'),card(const Column(children:[
   Inbox(Icons.notes_rounded,'完善任务时间跟踪方案','文字 · 10:08'),Divider(height:1),Inbox(Icons.image_outlined,'界面参考截图','图片 · 昨天'),Divider(height:1),
   Inbox(Icons.lightbulb_outline_rounded,'论文灵感：扰动集合','灵感 · 昨天'),Divider(height:1),Inbox(Icons.attach_file_rounded,'产品需求文档','文件 · 本周')]))
 ]);}
 Future<void> capture(BuildContext c,String type)=>showModalBottomSheet(context:c,showDragHandle:true,builder:(x)=>Padding(padding:const EdgeInsets.fromLTRB(20,0,20,24),
  child:Column(mainAxisSize:MainAxisSize.min,children:[Text('新建$type',style:Theme.of(x).textTheme.titleLarge),const SizedBox(height:16),
   TextField(maxLines:type=='文字'||type=='灵感'?5:2,decoration:const InputDecoration(hintText:'记录内容')),const SizedBox(height:16),
   SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(x),child:const Text('保存到 Inbox')))])));
}
class Inbox extends StatelessWidget{const Inbox(this.icon,this.title,this.meta,{super.key});final IconData icon;final String title,meta;
 @override Widget build(BuildContext c)=>ListTile(contentPadding:EdgeInsets.zero,leading:Icon(icon,color:C.p),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w700)),
  subtitle:Text(meta),trailing:const Icon(Icons.chevron_right_rounded));}

class Review extends StatefulWidget{const Review({super.key});@override State<Review> createState()=>_ReviewState();}
class _ReviewState extends State<Review>{int m=2;
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:C.bg,appBar:AppBar(backgroundColor:C.bg,title:const Text('今日复盘')),body:scroll([
  Text('今天完成得怎么样？',style:Theme.of(c).textTheme.headlineMedium),const SizedBox(height:18),
  Row(children:List.generate(4,(i){const l=['很差','一般','不错','很好'];final s=i==m;return Expanded(child:Padding(padding:EdgeInsets.only(right:i==3?0:8),
   child:InkWell(borderRadius:BorderRadius.circular(14),onTap:()=>setState(()=>m=i),child:AnimatedContainer(duration:const Duration(milliseconds:150),padding:const EdgeInsets.symmetric(vertical:12),
    alignment:Alignment.center,decoration:BoxDecoration(color:s?C.ps:C.surface,borderRadius:BorderRadius.circular(14),border:Border.all(color:s?C.p:C.border)),
    child:Text(l[i],style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:s?C.p:C.muted))))));})),
  section(c,'今日数据'),card(const Column(children:[MetricRow('完成任务','6 / 8'),Divider(height:1),MetricRow('专注时间','1 小时 35 分钟'),Divider(height:1),MetricRow('推进项目','2 个')])),
  section(c,'记录'),const TextField(maxLines:4,decoration:InputDecoration(labelText:'今天做得好的地方',hintText:'记录有效方法和值得保持的行为')),const SizedBox(height:12),
  const TextField(maxLines:4,decoration:InputDecoration(labelText:'可以改进的地方',hintText:'记录阻塞、分心和需要调整的地方')),const SizedBox(height:12),
  const TextField(decoration:InputDecoration(labelText:'明天最重要的一件事',hintText:'写下明日第一优先级')),const SizedBox(height:22),
  SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('保存今日复盘')))
 ],p:const EdgeInsets.fromLTRB(20,8,20,30)));}

class Profile extends StatelessWidget{
 const Profile({super.key});
 @override Widget build(BuildContext c)=>Scaffold(backgroundColor:C.bg,appBar:AppBar(backgroundColor:C.bg,title:const Text('我的')),body:scroll([
  card(const Row(children:[CircleAvatar(radius:26,backgroundColor:Colors.white,child:Icon(Icons.person_rounded,color:C.p)),SizedBox(width:14),
   Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Alex',style:TextStyle(fontSize:18,fontWeight:FontWeight.w800)),SizedBox(height:4),
    Text('LifeTrace Cloud 已连接',style:TextStyle(fontSize:11,color:C.muted))])),Icon(Icons.cloud_done_rounded,color:C.green)]),color:C.ps),
  section(c,'账号与数据'),card(const Column(children:[
   Setting(Icons.cloud_outlined,'云同步','刚刚同步 · 正常'),Divider(height:1),Setting(Icons.devices_outlined,'设备','2 台设备'),Divider(height:1),
   Setting(Icons.notifications_none_rounded,'通知','提醒已开启'),Divider(height:1),Setting(Icons.palette_outlined,'外观','跟随系统'),Divider(height:1),
   Setting(Icons.storage_outlined,'数据与备份','本地优先')])),
  section(c,'其他'),card(const Setting(Icons.info_outline_rounded,'关于 LifeTrace','版本与开源信息'))
 ],p:const EdgeInsets.fromLTRB(20,8,20,30)));}
class Setting extends StatelessWidget{const Setting(this.icon,this.label,this.value,{super.key});final IconData icon;final String label,value;
 @override Widget build(BuildContext c)=>ListTile(contentPadding:EdgeInsets.zero,leading:Icon(icon,color:C.muted),title:Text(label,style:const TextStyle(fontWeight:FontWeight.w700)),
  subtitle:Text(value,style:const TextStyle(fontSize:11)),trailing:const Icon(Icons.chevron_right_rounded,color:C.muted),onTap:(){});}

void push(BuildContext c,Widget w)=>Navigator.of(c).push(MaterialPageRoute(builder:(_)=>w));
