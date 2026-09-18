part of 'main.dart';

class Collection extends StatelessWidget{const Collection({super.key});@override Widget build(BuildContext c)=>page([
  title('收集'),sub('有什么需要记下来？'),const SizedBox(height:11),panel(Column(children:[const TextField(maxLines:3,decoration:InputDecoration(hintText:'输入想法、任务、备忘...')),const SizedBox(height:8),Row(children:[IconButton(onPressed:(){},icon:const Icon(Icons.attach_file_rounded,size:18)),IconButton(onPressed:(){},icon:const Icon(Icons.mic_none_rounded,size:18)),IconButton(onPressed:(){},icon:const Icon(Icons.image_outlined,size:18)),const Spacer(),CircleAvatar(radius:16,backgroundColor:C.p,child:IconButton(padding:EdgeInsets.zero,onPressed:(){},icon:const Icon(Icons.send_rounded,size:15,color:Colors.white)))])]),color:C.soft),
  h('快速收集'),Wrap(spacing:7,runSpacing:7,children:[_Quick(Icons.edit_note_rounded,'文本',()=>capture(c,'文本')),_Quick(Icons.mic_none_rounded,'语音',()=>capture(c,'语音')),_Quick(Icons.image_outlined,'图片',()=>capture(c,'图片')),_Quick(Icons.link_rounded,'链接',()=>capture(c,'链接')),_Quick(Icons.insert_drive_file_outlined,'文件',()=>capture(c,'文件')),_Quick(Icons.lightbulb_outline_rounded,'想法',()=>capture(c,'想法'))]),
  h('Inbox · 7'),panel(const Column(children:[_Inbox(Icons.link_rounded,'Transformer 新论文','链接 · 10分钟前'),Divider(height:1),_Inbox(Icons.notes_rounded,'明天找导师讨论实验方案','文本 · 1小时前'),Divider(height:1),_Inbox(Icons.image_outlined,'IMG_2931.jpg','图片 · 今天'),Divider(height:1),_Inbox(Icons.lightbulb_outline_rounded,'LifeTrace 设计灵感','想法 · 今天')]))
]);Future<void> capture(BuildContext c,String t)=>showModalBottomSheet(context:c,showDragHandle:true,builder:(x)=>Padding(padding:const EdgeInsets.fromLTRB(16,0,16,20),child:Column(mainAxisSize:MainAxisSize.min,children:[Text('新建$t',style:Theme.of(x).textTheme.titleLarge),const SizedBox(height:12),const TextField(maxLines:4,decoration:InputDecoration(hintText:'记录内容')),const SizedBox(height:12),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(x),child:const Text('保存到 Inbox')))])));}
class _Quick extends StatelessWidget{const _Quick(this.icon,this.label,this.tap);final IconData icon;final String label;final VoidCallback tap;@override Widget build(BuildContext c)=>InkWell(onTap:tap,borderRadius:BorderRadius.circular(9),child:Container(width:96,padding:const EdgeInsets.symmetric(vertical:9),decoration:BoxDecoration(color:C.soft,borderRadius:BorderRadius.circular(9)),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,size:15,color:C.p),const SizedBox(width:5),Text(label,style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w700))])));}
class _Inbox extends StatelessWidget{const _Inbox(this.icon,this.title,this.meta);final IconData icon;final String title,meta;@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Row(children:[Icon(icon,size:16,color:C.p),const SizedBox(width:9),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w800)),Text(meta,style:const TextStyle(fontSize:8.5,color:C.muted))]))]));}

class Review extends StatefulWidget{const Review({super.key});@override State<Review> createState()=>_ReviewState();}
class _ReviewState extends State<Review>{int mood=3;@override Widget build(BuildContext c)=>DetailFrame(titleText:'9月9日 · 星期三',child:page([
  title('今日复盘'),const SizedBox(height:2),sub('今天过得怎么样？'),const SizedBox(height:10),
  Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:List.generate(5,(i)=>InkWell(onTap:()=>setState(()=>mood=i),child:CircleAvatar(radius:18,backgroundColor:i==mood?C.ps:C.soft,child:Text(['☹','🙁','😐','🙂','😊'][i],style:TextStyle(fontSize:i==mood?18:15))))),),
  h('今日完成'),const Text('8 / 11 Tasks',style:TextStyle(fontSize:11.5,fontWeight:FontWeight.w900)),const SizedBox(height:6),const ClipRRect(borderRadius:BorderRadius.all(Radius.circular(5)),child:LinearProgressIndicator(value:.73,minHeight:6,backgroundColor:C.soft)),
  h('今天做得好的事情'),const TextField(maxLines:3,decoration:InputDecoration(hintText:'...')),h('今天可以改进什么？'),const TextField(maxLines:3,decoration:InputDecoration(hintText:'...')),h('明天最重要的一件事'),panel(const Row(children:[Icon(Icons.check_box_outline_blank_rounded,size:17,color:C.muted),SizedBox(width:8),Text('完成论文实验设计',style:TextStyle(fontSize:10.5,fontWeight:FontWeight.w700))]),padding:const EdgeInsets.all(10)),
  const SizedBox(height:14),SizedBox(width:double.infinity,child:FilledButton(onPressed:()=>Navigator.pop(c),child:const Text('完成今日复盘')))
],padding:const EdgeInsets.fromLTRB(14,4,14,18)));
}

class Profile extends StatelessWidget{const Profile({super.key});@override Widget build(BuildContext c)=>DetailFrame(titleText:'我的',child:page([
  const Row(children:[CircleAvatar(radius:23,backgroundColor:C.ps,child:Icon(Icons.person,color:C.p)),SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Alex',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)),Text('alex@example.com',style:TextStyle(fontSize:9,color:C.muted))]))]),
  const SizedBox(height:10),const Row(children:[Icon(Icons.cloud_done_rounded,size:14,color:C.green),SizedBox(width:6),Text('LifeTrace Cloud 已连接',style:TextStyle(fontSize:9.5,fontWeight:FontWeight.w700)),Spacer(),Text('刚刚同步',style:TextStyle(fontSize:8.5,color:C.muted))]),
  h('账户'),panel(const Column(children:[_Setting(Icons.person_outline_rounded,'个人资料'),Divider(height:1),_Setting(Icons.lock_outline_rounded,'账户与安全'),Divider(height:1),_Setting(Icons.devices_outlined,'设备管理')])),
  h('LifeTrace'),panel(const Column(children:[_Setting(Icons.cloud_sync_outlined,'同步与数据'),Divider(height:1),_Setting(Icons.notifications_none_rounded,'通知'),Divider(height:1),_Setting(Icons.palette_outlined,'外观')])),
  h('应用'),panel(const Column(children:[_Setting(Icons.settings_outlined,'通用'),Divider(height:1),_Setting(Icons.info_outline_rounded,'关于')])),
],padding:const EdgeInsets.fromLTRB(14,4,14,18)));
}
class _Setting extends StatelessWidget{const _Setting(this.icon,this.label);final IconData icon;final String label;@override Widget build(BuildContext c)=>Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Row(children:[Icon(icon,size:16,color:C.muted),const SizedBox(width:9),Text(label,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700)),const Spacer(),const Icon(Icons.chevron_right_rounded,size:16,color:C.muted)]));}

class DetailFrame extends StatelessWidget{
  const DetailFrame({required this.child,this.titleText='',this.leading=Icons.arrow_back,this.actions=const [],super.key});
  final Widget child; final String titleText; final IconData leading; final List<Widget> actions;
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:C.bg,body:Column(children:[const PhoneStatusBar(),SizedBox(height:42,child:Row(children:[IconButton(onPressed:()=>Navigator.maybePop(c),icon:Icon(leading,size:18)),Expanded(child:Text(titleText,textAlign:TextAlign.center,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900))),SizedBox(width:48,child:Row(mainAxisAlignment:MainAxisAlignment.end,children:actions)),const SizedBox(width:4)])),Expanded(child:child),const SizedBox(height:5)]));
}

void push(BuildContext c, Widget w) => Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));
