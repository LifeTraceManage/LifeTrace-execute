// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

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
  _Project('LifeTrace','个人管理平台',.72,'12 个任务 · 8 已完成','9 月 30 日',C.orange,()=>push(c,const ProjectDetail(name:'LifeTrace',subtitle:'个人管理平台',progress:.72,total:12,done:8,due:'9 月 30 日',color:C.orange))),const SizedBox(height:9),
  _Project('Academic Research','Quadrotor + SMF + MPC',.55,'8 个任务 · 3 已完成','10 月 15 日',C.p,()=>push(c,const ProjectDetail(name:'Academic Research',subtitle:'Quadrotor + SMF + MPC',progress:.55,total:8,done:3,due:'10 月 15 日',color:C.p))),const SizedBox(height:9),
  _Project('个人成长','健康 · 学习 · 生活',.30,'6 个任务 · 2 已完成','12 月 31 日',C.teal,()=>push(c,const ProjectDetail(name:'个人成长',subtitle:'健康 · 学习 · 生活',progress:.30,total:6,done:2,due:'12 月 31 日',color:C.teal))),const SizedBox(height:9),
  _Project('开源项目','有意义的开源贡献',.40,'4 个任务 · 1 已完成','10 月 1 日',C.purple,()=>push(c,const ProjectDetail(name:'开源项目',subtitle:'有意义的开源贡献',progress:.40,total:4,done:1,due:'10 月 1 日',color:C.purple))),
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

class ProjectDetail extends StatelessWidget {
  const ProjectDetail({
    super.key,
    required this.name,
    required this.subtitle,
    required this.progress,
    required this.total,
    required this.done,
    required this.due,
    required this.color,
  });

  final String name;
  final String subtitle;
  final double progress;
  final int total;
  final int done;
  final String due;
  final Color color;

  int get remaining => total - done;

  List<(String, String, Color)> get nextSteps => switch (name) {
        'Academic Research' => [
            ('完成稳定性证明', '今天 · P1', C.red),
            ('补齐扰动集合实验', '明天 · P2', C.orange),
            ('整理消融实验结果', '本周', C.p),
          ],
        '个人成长' => [
            ('完成本周四次训练', '本周 · 2/4', C.teal),
            ('英语口语练习', '今天 · 30 min', C.orange),
            ('整理本周复盘', '周日', C.purple),
          ],
        '开源项目' => [
            ('处理待合并 PR', '今天', C.purple),
            ('补充 README 文档', '本周', C.sky),
            ('发布下一个版本', '10 月 1 日', C.orange),
          ],
        _ => [
            ('完成 Flutter UI 重构', '今天 · P1', C.red),
            ('接入 Project Repository', '本周 · P2', C.orange),
            ('补齐端到端测试', '发布前', C.p),
          ],
      };

  @override
  Widget build(BuildContext c) => DetailFrame(
        titleText: '项目详情',
        actions: [
          IconButton(
            tooltip: '更多',
            onPressed: () {},
            icon: const Icon(Icons.more_vert_rounded, size: 19),
          ),
        ],
        child: page([
          _ProjectHero(
            name: name,
            subtitle: subtitle,
            progress: progress,
            due: due,
            color: color,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: _ProjectMetric(
                icon: Icons.check_circle_rounded,
                value: '$done',
                label: '已完成',
                color: C.green,
                background: C.greenSoft,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _ProjectMetric(
                icon: Icons.pending_actions_rounded,
                value: '$remaining',
                label: '待完成',
                color: C.orange,
                background: C.orangeSoft,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _ProjectMetric(
                icon: Icons.format_list_bulleted_rounded,
                value: '$total',
                label: '任务总数',
                color: color,
                background: color.withValues(alpha: .10),
              ),
            ),
          ]),
          h('快捷操作'),
          Row(children: [
            Expanded(
              child: _ProjectAction(
                icon: Icons.add_task_rounded,
                label: '新增任务',
                color: color,
                onTap: () {},
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _ProjectAction(
                icon: Icons.play_circle_outline_rounded,
                label: '开始专注',
                color: C.purple,
                onTap: () => push(c, const Focus()),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _ProjectAction(
                icon: Icons.calendar_month_rounded,
                label: '看日程',
                color: C.teal,
                onTap: () {},
              ),
            ),
          ]),
          h('下一步', tail: chip('${nextSteps.length} 项', bg: color.withValues(alpha: .10), fg: color)),
          for (final step in nextSteps)
            _ProjectTaskTile(
              title: step.$1,
              meta: step.$2,
              color: step.$3,
              onTap: () => push(c, const TaskDetail()),
            ),
          h('里程碑'),
          _ProjectTimeline(color: color, name: name),
          h('项目节奏'),
          _ProjectPulse(color: color, progress: progress, done: done, remaining: remaining),
        ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
      );
}

class _ProjectHero extends StatelessWidget {
  const _ProjectHero({
    required this.name,
    required this.subtitle,
    required this.progress,
    required this.due,
    required this.color,
  });

  final String name;
  final String subtitle;
  final double progress;
  final String due;
  final Color color;

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: .16), Colors.white],
          ),
          border: Border.all(color: color.withValues(alpha: .14)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.folder_rounded, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 9, color: C.muted)),
                  ]),
                ),
              ]),
              const SizedBox(height: 13),
              Wrap(spacing: 6, runSpacing: 6, children: [
                chip('进行中', bg: Colors.white, fg: color),
                chip('截止 $due', bg: Colors.white, fg: C.muted),
              ]),
            ]),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 7,
                color: color,
                backgroundColor: Colors.white,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
                  ),
                  const Text('进度', style: TextStyle(fontSize: 8, color: C.muted)),
                ]),
              ),
            ]),
          ),
        ]),
      );
}

class _ProjectMetric extends StatelessWidget {
  const _ProjectMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 7),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: const TextStyle(fontSize: 8.2, color: C.muted)),
        ]),
      );
}

class _ProjectAction extends StatelessWidget {
  const _ProjectAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 8.7, fontWeight: FontWeight.w800, color: color)),
          ]),
        ),
      );
}

class _ProjectTaskTile extends StatelessWidget {
  const _ProjectTaskTile({
    required this.title,
    required this.meta,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String meta;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withValues(alpha: .13)),
          ),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.task_alt_rounded, size: 16, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(meta, style: const TextStyle(fontSize: 8.5, color: C.muted)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: color.withValues(alpha: .7)),
          ]),
        ),
      );
}

class _ProjectTimeline extends StatelessWidget {
  const _ProjectTimeline({required this.color, required this.name});

  final Color color;
  final String name;

  @override
  Widget build(BuildContext c) {
    final items = switch (name) {
      'Academic Research' => [
          ('9月12日', '理论方案冻结', true),
          ('9月25日', '仿真与消融实验', false),
          ('10月15日', '论文初稿完成', false),
        ],
      '个人成长' => [
          ('9月', '稳定训练习惯', true),
          ('10月', '英语口语阶段目标', false),
          ('12月', '年度复盘', false),
        ],
      '开源项目' => [
          ('9月15日', '功能冻结', true),
          ('9月24日', 'Release Candidate', false),
          ('10月1日', '正式发布', false),
        ],
      _ => [
          ('9月10日', 'Flutter UI architecture', true),
          ('9月18日', 'Project / Calendar parity', false),
          ('9月30日', 'Release candidate', false),
        ],
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final item = items[i];
          final last = i == items.length - 1;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 22,
              child: Column(children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.$3 ? color : Colors.white,
                    border: Border.all(color: color, width: 2),
                  ),
                ),
                if (!last)
                  Container(
                    width: 2,
                    height: 31,
                    color: color.withValues(alpha: .20),
                  ),
              ]),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      item.$2,
                      style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(item.$1, style: const TextStyle(fontSize: 8.5, color: C.muted)),
                ]),
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

class _ProjectPulse extends StatelessWidget {
  const _ProjectPulse({
    required this.color,
    required this.progress,
    required this.done,
    required this.remaining,
  });

  final Color color;
  final double progress;
  final int done;
  final int remaining;

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.soft,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('本周推进', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900)),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: color),
            ),
          ]),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: color,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 9),
          Row(children: [
            _PulseDot(color: C.green, label: '$done 已完成'),
            const SizedBox(width: 12),
            _PulseDot(color: C.orange, label: '$remaining 待推进'),
          ]),
        ]),
      );
}

class _PulseDot extends StatelessWidget {
  const _PulseDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext c) => Row(children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 8.5, color: C.muted)),
      ]);
}

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
