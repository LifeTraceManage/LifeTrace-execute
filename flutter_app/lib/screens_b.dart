part of 'main.dart';

class Focus extends StatefulWidget { const Focus({super.key}); @override State<Focus> createState()=>_FocusState(); }
class _FocusState extends State<Focus>{ static const total=1500; int left=total; Timer? t; bool run=true; @override void dispose(){t?.cancel();super.dispose();} void toggle(){if(run){t?.cancel();setState(()=>run=false);}else{t=Timer.periodic(const Duration(seconds:1),(_){if(left>0)setState(()=>left--);});setState(()=>run=true);}} String get ts=>'${(left~/60).toString().padLeft(2,'0')}:${(left%60).toString().padLeft(2,'0')}'; @override Widget build(BuildContext c)=>DetailFrame(titleText:'专注中',leading:Icons.close,actions:const [Icon(Icons.more_vert_rounded,size:19)],child:page([
  const SizedBox(height:12),Center(child:SizedBox(width:208,height:208,child:Stack(fit:StackFit.expand,children:[const CircularProgressIndicator(value:.86,strokeWidth:8,color:C.purple,backgroundColor:C.purpleSoft,strokeCap:StrokeCap.round),Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(ts,style:const TextStyle(fontSize:37,fontWeight:FontWeight.w900,letterSpacing:-1)),const SizedBox(height:4),const Text('🌿 专注工作',style:TextStyle(fontSize:10,color:C.muted))]))]))),
  const SizedBox(height:15),panel(const Row(children:[Icon(Icons.favorite_rounded,color:C.red,size:14),SizedBox(width:7),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('完成论文实验设计',style:TextStyle(fontSize:11.5,fontWeight:FontWeight.w800)),Text('Academic Research · P1',style:TextStyle(fontSize:9,color:C.muted))]))]),color:C.purpleSoft,padding:const EdgeInsets.all(10)),
  const SizedBox(height:18),Row(mainAxisAlignment:MainAxisAlignment.center,children:[_RoundAction(Icons.replay_rounded,'放弃',()=>setState(()=>left=total)),const SizedBox(width:24),InkWell(onTap:toggle,child:CircleAvatar(radius:29,backgroundColor:C.purple,child:Icon(run?Icons.pause_rounded:Icons.play_arrow_rounded,color:Colors.white,size:30))),const SizedBox(width:24),_RoundAction(Icons.skip_next_rounded,'跳过',()=>Navigator.pop(c))]),
  const SizedBox(height:20),const Row(children:[Expanded(child:_StatBox('今日专注','2h 15m')),SizedBox(width:7),Expanded(child:_StatBox('番茄次数','4')),SizedBox(width:7),Expanded(child:_StatBox('连续天数','7'))]),
  const SizedBox(height:12),Row(children:[Expanded(child:panel(const Column(children:[Icon(Icons.music_note_outlined,size:16,color:C.muted),SizedBox(height:4),Text('白噪音',style:TextStyle(fontSize:9)),Text('放松',style:TextStyle(fontSize:8,color:C.p))]),padding:const EdgeInsets.symmetric(vertical:9))),const SizedBox(width:7),Expanded(child:panel(const Column(children:[Icon(Icons.center_focus_strong_outlined,size:16,color:C.muted),SizedBox(height:4),Text('专注模式',style:TextStyle(fontSize:9)),Text('开启',style:TextStyle(fontSize:8,color:C.p))]),padding:const EdgeInsets.symmetric(vertical:9))),const SizedBox(width:7),Expanded(child:panel(const Column(children:[Icon(Icons.notifications_none_rounded,size:16,color:C.muted),SizedBox(height:4),Text('提醒',style:TextStyle(fontSize:9)),Text('关闭',style:TextStyle(fontSize:8,color:C.muted))]),padding:const EdgeInsets.symmetric(vertical:9)))])
],padding:const EdgeInsets.fromLTRB(16,0,16,15)));
}
class _RoundAction extends StatelessWidget{const _RoundAction(this.icon,this.label,this.tap);final IconData icon;final String label;final VoidCallback tap;@override Widget build(BuildContext c)=>Column(children:[InkWell(onTap:tap,child:CircleAvatar(radius:20,backgroundColor:C.soft,child:Icon(icon,size:19,color:C.ink))),const SizedBox(height:5),Text(label,style:const TextStyle(fontSize:8.5,color:C.muted))]);}
class _StatBox extends StatelessWidget{const _StatBox(this.label,this.value);final String label,value;@override Widget build(BuildContext c)=>panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:8.5,color:C.muted)),const SizedBox(height:3),Text(value,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900))]),padding:const EdgeInsets.all(9));}

class Projects extends StatefulWidget{const Projects({super.key});@override State<Projects> createState()=>_ProjectsState();}
class _ProjectsState extends State<Projects>{int f=0;@override Widget build(BuildContext c)=>page([
  Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[title('项目'),sub('目标与进度')])),IconButton(onPressed:(){},icon:const Icon(Icons.add,size:19))]),const SizedBox(height:9),_Tabs(labels:const ['全部','进行中','已暂停','已完成'],selected:f,onTap:(v)=>setState(()=>f=v)),const SizedBox(height:12),
  _Project('LifeTrace','个人管理平台',.72,'12 个任务 · 8 已完成','9 月 30 日',C.orange,()=>push(c,const ProjectDetail())),const SizedBox(height:9),
  _Project('Academic Research','Quadrotor + SMF + MPC',.55,'8 个任务 · 3 已完成','10 月 15 日',C.p,()=>push(c,const ProjectDetail())),const SizedBox(height:9),
  _Project('个人成长','健康 · 学习 · 生活',.30,'6 个任务 · 2 已完成','12 月 31 日',C.teal,()=>push(c,const ProjectDetail())),const SizedBox(height:9),
  _Project('开源项目','有意义的开源贡献',.40,'4 个任务 · 1 已完成','10 月 1 日',C.purple,()=>push(c,const ProjectDetail())),
]);}
class _Project extends StatelessWidget {
  const _Project(this.name, this.subt, this.progress, this.meta, this.date, this.color, this.tap);
  final String name, subt, meta, date;
  final double progress;
  final Color color;
  final VoidCallback tap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .16)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(Icons.folder_rounded, size: 21, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(subt, style: const TextStyle(fontSize: 9, color: C.muted)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: color.withValues(alpha: .10),
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.checklist_rounded, size: 12, color: color),
              const SizedBox(width: 4),
              Text(meta, style: const TextStyle(fontSize: 8.7, color: C.muted)),
              const Spacer(),
              const Icon(Icons.flag_outlined, size: 11, color: C.muted),
              const SizedBox(width: 3),
              Text(date, style: const TextStyle(fontSize: 8.7, color: C.muted)),
            ]),
          ]),
        ),
      );
}

class ProjectDetail extends StatelessWidget{const ProjectDetail({super.key});@override Widget build(BuildContext c)=>DetailFrame(titleText:'',actions:const [Icon(Icons.more_vert_rounded,size:19)],child:page([
  title('LifeTrace Execute'),const SizedBox(height:3),sub('Android execution center'),const SizedBox(height:12),ClipRRect(borderRadius:BorderRadius.circular(4),child:const LinearProgressIndicator(value:.72,minHeight:6,backgroundColor:C.soft)),const SizedBox(height:4),const Align(alignment:Alignment.centerRight,child:Text('72%',style:TextStyle(fontSize:9,color:C.muted))),
  const SizedBox(height:10),const Row(children:[Expanded(child:_BigMetric('12','任务总数')),SizedBox(width:7),Expanded(child:_BigMetric('8','已完成')),SizedBox(width:7),Expanded(child:_BigMetric('4','待完成'))]),
  h('下一步'),panel(Column(children:[_TaskLine('完成 UI 重构','',tap:()=>push(c,const TaskDetail())),const Divider(height:1),_TaskLine('接入 Project Repository','',tap:()=>push(c,const TaskDetail())),const Divider(height:1),_TaskLine('添加 E2E Test','',tap:()=>push(c,const TaskDetail()))])),
  h('里程碑'),const _Milestone('9月10日','UI architecture'),const _Milestone('9月15日','Project / Calendar'),const _Milestone('9月25日','Release candidate'),
],padding:const EdgeInsets.fromLTRB(14,4,14,18)));
}
class _BigMetric extends StatelessWidget{const _BigMetric(this.n,this.s);final String n,s;@override Widget build(BuildContext c)=>panel(Column(children:[Text(n,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900,color:C.p)),Text(s,style:const TextStyle(fontSize:8.5,color:C.muted))]),padding:const EdgeInsets.symmetric(vertical:10));}
class _Milestone extends StatelessWidget{const _Milestone(this.date,this.name);final String date,name;@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Container(width:6,height:6,decoration:const BoxDecoration(shape:BoxShape.circle,color:C.p)),const SizedBox(width:9),SizedBox(width:55,child:Text(date,style:const TextStyle(fontSize:9,color:C.muted))),Text(name,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700))]));}

class Calendar extends StatefulWidget{const Calendar({super.key});@override State<Calendar> createState()=>_CalendarState();}
class _CalendarState extends State<Calendar>{int sel=9;@override Widget build(BuildContext c)=>Scaffold(backgroundColor:C.bg,floatingActionButton:FloatingActionButton.small(backgroundColor:C.orange,foregroundColor:Colors.white,onPressed:(){},child:const Icon(Icons.add)),body:page([
  Row(children:[Expanded(child:title('日历')),IconButton(onPressed:(){},icon:const Icon(Icons.more_vert_rounded,size:18))]),const SizedBox(height:5),
  Row(children:[const Expanded(child:Text('2026年 9月',style:TextStyle(fontSize:13,fontWeight:FontWeight.w900))),chip('月',bg:C.orangeSoft,fg:C.orange),const SizedBox(width:5),chip('周'),const SizedBox(width:5),chip('日程')]),const SizedBox(height:9),
  Row(children:['一','二','三','四','五','六','日'].map((x)=>Expanded(child:Center(child:Text(x,style:const TextStyle(fontSize:8,color:C.muted))))).toList()),const SizedBox(height:4),
  Container(
    padding:const EdgeInsets.symmetric(vertical:6),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(14),border:Border.all(color:C.border)),
    child:GridView.builder(
      shrinkWrap:true,
      physics:const NeverScrollableScrollPhysics(),
      gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:7,mainAxisExtent:38),
      itemCount:35,
      itemBuilder:(_,i){
        const start=1;
        final day=i-start+1;
        if(day<1||day>30)return const SizedBox.shrink();
        final s=day==sel;
        final eventColor=s
            ? Colors.white
            : switch(day){
                3||11||17=>C.teal,
                7||22=>C.purple,
                9||15||28=>C.orange,
                12||25=>C.red,
                _=>Colors.transparent,
              };
        return InkWell(
          onTap:()=>setState(()=>sel=day),
          child:Center(
            child:Container(
              width:29,
              height:33,
              alignment:Alignment.center,
              decoration:BoxDecoration(
                color:s?C.orange:Colors.transparent,
                borderRadius:BorderRadius.circular(9),
              ),
              child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
                Text('$day',style:TextStyle(fontSize:9.5,fontWeight:s?FontWeight.w900:FontWeight.w600,color:s?Colors.white:C.ink)),
                const SizedBox(height:2),
                Container(width:4,height:4,decoration:BoxDecoration(shape:BoxShape.circle,color:eventColor)),
              ]),
            ),
          ),
        );
      },
    ),
  ),
  h('9月9日 · 今天'),const _Agenda('09:00',C.p,'工作','日程 · 1 小时'),const _Agenda('14:30',C.teal,'项目会议','会议 · 1 小时'),const _Agenda('19:00',C.teal,'健身','个人 · 1小时'),const _Agenda('22:30',C.red,'论文实验截止','任务 · 高优先级'),
]));}
class _Agenda extends StatelessWidget {
  const _Agenda(this.time, this.color, this.name, this.meta);
  final String time, name, meta;
  final Color color;

  @override
  Widget build(BuildContext c) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 40,
            child: Text(time, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: color)),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              Text(meta, style: const TextStyle(fontSize: 8.7, color: C.muted)),
            ]),
          ),
        ]),
      );
}
