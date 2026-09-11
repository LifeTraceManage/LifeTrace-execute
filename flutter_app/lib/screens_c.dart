// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

part of 'main.dart';

class Collection extends StatefulWidget {
  const Collection({super.key});

  @override
  State<Collection> createState() => _CollectionState();
}

class _CollectionState extends State<Collection> {
  int inboxFilter = 0;

  static const inboxItems = <({
    IconData icon,
    String title,
    String type,
    String time,
    String preview,
    Color color,
    Color background,
    bool important,
  })>[
    (
      icon: Icons.link_rounded,
      title: 'Transformer 新论文',
      type: '链接',
      time: '10分钟前',
      preview: 'Set-membership estimation 与预测控制相关资料，稍后归档到 Academic Research。',
      color: C.teal,
      background: C.tealSoft,
      important: true,
    ),
    (
      icon: Icons.notes_rounded,
      title: '明天找导师讨论实验方案',
      type: '文本',
      time: '1小时前',
      preview: '重点确认扰动集合预测的理论边界，以及实验对比是否足够完整。',
      color: C.p,
      background: C.ps,
      important: true,
    ),
    (
      icon: Icons.image_outlined,
      title: 'IMG_2931.jpg',
      type: '图片',
      time: '今天',
      preview: '会议白板照片 · 1 张图片',
      color: C.pink,
      background: C.pinkSoft,
      important: false,
    ),
    (
      icon: Icons.lightbulb_outline_rounded,
      title: 'LifeTrace 设计灵感',
      type: '想法',
      time: '今天',
      preview: '把收集箱做成真正的临时工作区，而不是一串等待清理的文本。',
      color: C.amber,
      background: C.amberSoft,
      important: false,
    ),
  ];

  @override
  Widget build(BuildContext c) {
    final visible = switch (inboxFilter) {
      1 => inboxItems.where((item) => item.important).toList(growable: false),
      2 => inboxItems.where((item) => item.type == '图片' || item.type == '链接').toList(growable: false),
      _ => inboxItems,
    };

    return page([
      Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('收集'),
            sub('先记下来，再决定它属于哪里'),
          ]),
        ),
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: C.tealSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.inbox_rounded, color: C.teal, size: 19),
        ),
      ]),
      const SizedBox(height: 12),
      _CaptureComposer(onCapture: capture),
      h('快速收集'),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _Quick(Icons.edit_note_rounded, '文本', C.p, C.ps, () => capture(c, '文本')),
        _Quick(Icons.mic_none_rounded, '语音', C.purple, C.purpleSoft, () => capture(c, '语音')),
        _Quick(Icons.image_outlined, '图片', C.pink, C.pinkSoft, () => capture(c, '图片')),
        _Quick(Icons.link_rounded, '链接', C.teal, C.tealSoft, () => capture(c, '链接')),
        _Quick(Icons.insert_drive_file_outlined, '文件', C.orange, C.orangeSoft, () => capture(c, '文件')),
        _Quick(Icons.lightbulb_outline_rounded, '想法', C.amber, C.amberSoft, () => capture(c, '想法')),
      ]),
      const SizedBox(height: 16),
      const _InboxOverview(),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(
          child: Text(
            'Inbox',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '${visible.length} 条待整理',
          style: const TextStyle(fontSize: 8.8, color: C.muted),
        ),
      ]),
      const SizedBox(height: 8),
      _InboxFilters(
        selected: inboxFilter,
        onChanged: (value) => setState(() => inboxFilter = value),
      ),
      const SizedBox(height: 10),
      for (final item in visible)
        _InboxCard(
          icon: item.icon,
          title: item.title,
          type: item.type,
          time: item.time,
          preview: item.preview,
          color: item.color,
          background: item.background,
          important: item.important,
          onTap: () => push(
            c,
            InboxDetail(
              icon: item.icon,
              title: item.title,
              type: item.type,
              time: item.time,
              preview: item.preview,
              color: item.color,
              background: item.background,
            ),
          ),
        ),
    ]);
  }

  Future<void> capture(BuildContext c, String t) => showModalBottomSheet(
        context: c,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (x) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            20 + MediaQuery.of(x).viewInsets.bottom,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: C.tealSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.add_rounded, color: C.teal),
              ),
              const SizedBox(width: 9),
              Text('新建$t', style: Theme.of(x).textTheme.titleLarge),
            ]),
            const SizedBox(height: 12),
            const TextField(
              maxLines: 4,
              decoration: InputDecoration(hintText: '记录内容'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(x),
                icon: const Icon(Icons.inbox_rounded, size: 16),
                label: const Text('保存到 Inbox'),
              ),
            ),
          ]),
        ),
      );
}

class _CaptureComposer extends StatelessWidget {
  const _CaptureComposer({required this.onCapture});
  final Future<void> Function(BuildContext, String) onCapture;

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [C.tealSoft, Colors.white],
          ),
          border: Border.all(color: C.teal.withValues(alpha: .12)),
        ),
        child: Column(children: [
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '输入想法、任务、备忘...',
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 9),
          Row(children: [
            _CaptureIcon(
              icon: Icons.attach_file_rounded,
              color: C.orange,
              background: C.orangeSoft,
              onTap: () => onCapture(c, '文件'),
            ),
            const SizedBox(width: 6),
            _CaptureIcon(
              icon: Icons.mic_none_rounded,
              color: C.purple,
              background: C.purpleSoft,
              onTap: () => onCapture(c, '语音'),
            ),
            const SizedBox(width: 6),
            _CaptureIcon(
              icon: Icons.image_outlined,
              color: C.pink,
              background: C.pinkSoft,
              onTap: () => onCapture(c, '图片'),
            ),
            const Spacer(),
            Container(
              height: 33,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: C.teal,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Row(children: [
                Icon(Icons.send_rounded, size: 14, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  '收集',
                  style: TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ]),
            ),
          ]),
        ]),
      );
}

class _CaptureIcon extends StatelessWidget {
  const _CaptureIcon({
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 33,
          height: 33,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.color, this.background, this.tap);
  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback tap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 96,
          height: 68,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 9.3, fontWeight: FontWeight.w800, color: color),
            ),
          ]),
        ),
      );
}

class _InboxOverview extends StatelessWidget {
  const _InboxOverview();

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.ink,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(fit: StackFit.expand, children: [
              const CircularProgressIndicator(
                value: .43,
                strokeWidth: 6,
                color: C.teal,
                backgroundColor: Color(0xff313b4f),
              ),
              const Center(
                child: Text(
                  '3/7',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '收集箱需要整理',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              SizedBox(height: 3),
              Text(
                '今天还有 4 条内容等待归类',
                style: TextStyle(fontSize: 8.8, color: Colors.white60),
              ),
              SizedBox(height: 8),
              Row(children: [
                _InboxStatDot(color: C.teal, label: '2 链接'),
                SizedBox(width: 10),
                _InboxStatDot(color: C.pink, label: '1 图片'),
                SizedBox(width: 10),
                _InboxStatDot(color: C.amber, label: '1 想法'),
              ]),
            ]),
          ),
        ]),
      );
}

class _InboxStatDot extends StatelessWidget {
  const _InboxStatDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext c) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.white70)),
      ]);
}

class _InboxFilters extends StatelessWidget {
  const _InboxFilters({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext c) {
    const labels = ['全部', '重点', '媒体'];
    const icons = [Icons.grid_view_rounded, Icons.star_outline_rounded, Icons.perm_media_outlined];
    return Row(
      children: List.generate(labels.length, (i) {
        final active = selected == i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: active ? C.tealSoft : C.soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icons[i], size: 13, color: active ? C.teal : C.muted),
                  const SizedBox(width: 5),
                  Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 8.8,
                      fontWeight: FontWeight.w800,
                      color: active ? C.teal : C.muted,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({
    required this.icon,
    required this.title,
    required this.type,
    required this.time,
    required this.preview,
    required this.color,
    required this.background,
    required this.important,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String type;
  final String time;
  final String preview;
  final Color color;
  final Color background;
  final bool important;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withValues(alpha: .12)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (important) const Icon(Icons.star_rounded, size: 13, color: C.amber),
                ]),
                const SizedBox(height: 3),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.7, color: C.muted, height: 1.35),
                ),
                const SizedBox(height: 7),
                Row(children: [
                  chip(type, bg: background, fg: color),
                  const SizedBox(width: 6),
                  Text(time, style: const TextStyle(fontSize: 8, color: C.muted)),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 15, color: color.withValues(alpha: .72)),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

class InboxDetail extends StatelessWidget {
  const InboxDetail({
    super.key,
    required this.icon,
    required this.title,
    required this.type,
    required this.time,
    required this.preview,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String title;
  final String type;
  final String time;
  final String preview;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext c) => DetailFrame(
        titleText: 'Inbox',
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert_rounded, size: 19)),
        ],
        child: page([
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, size: 21, color: color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Wrap(spacing: 6, children: [
                    chip(type, bg: Colors.white, fg: color),
                    chip(time, bg: Colors.white, fg: C.muted),
                  ]),
                ]),
              ),
            ]),
          ),
          h('内容'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.border),
            ),
            child: Text(
              preview,
              style: const TextStyle(fontSize: 10.3, color: C.muted, height: 1.5),
            ),
          ),
          h('整理到'),
          Row(children: [
            Expanded(child: _InboxDestination(Icons.check_box_outlined, '任务', C.p, C.ps)),
            const SizedBox(width: 7),
            Expanded(child: _InboxDestination(Icons.folder_outlined, '项目', C.purple, C.purpleSoft)),
            const SizedBox(width: 7),
            Expanded(child: _InboxDestination(Icons.calendar_month_outlined, '日历', C.orange, C.orangeSoft)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _InboxDestination(Icons.notes_rounded, '备忘', C.teal, C.tealSoft)),
            const SizedBox(width: 7),
            Expanded(child: _InboxDestination(Icons.archive_outlined, '归档', C.muted, C.soft)),
            const SizedBox(width: 7),
            Expanded(child: _InboxDestination(Icons.delete_outline_rounded, '删除', C.red, C.redSoft)),
          ]),
          h('建议'),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.purpleSoft, C.ps]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: Colors.white,
                child: Icon(Icons.auto_awesome_rounded, size: 16, color: C.purple),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('建议整理到项目', style: TextStyle(fontSize: 10.2, fontWeight: FontWeight.w900)),
                  Text('根据内容语义，可以关联到当前项目或转成下一步任务。', style: TextStyle(fontSize: 8.5, color: C.muted)),
                ]),
              ),
            ]),
          ),
        ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
      );
}

class _InboxDestination extends StatelessWidget {
  const _InboxDestination(this.icon, this.label, this.color, this.background);
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext c) => Container(
        height: 64,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 8.7, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

class Review extends StatefulWidget {
  const Review({super.key});
  @override
  State<Review> createState() => _ReviewState();
}

class _ReviewState extends State<Review> {
  int mood = 3;

  @override
  Widget build(BuildContext c) => DetailFrame(
        titleText: '9月9日 · 星期三',
        child: page([
          title('今日复盘'),
          const SizedBox(height: 2),
          sub('今天过得怎么样？'),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              5,
              (i) => InkWell(
                onTap: () => setState(() => mood = i),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: i == mood ? C.pinkSoft : C.soft,
                  child: Text(
                    ['☹', '🙁', '😐', '🙂', '😊'][i],
                    style: TextStyle(fontSize: i == mood ? 18 : 15),
                  ),
                ),
              ),
            ),
          ),
          h('今日完成'),
          const Text(
            '8 / 11 Tasks',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const ClipRRect(
            borderRadius: BorderRadius.all(Radius.circular(5)),
            child: LinearProgressIndicator(
              value: .73,
              minHeight: 6,
              backgroundColor: C.soft,
              color: C.green,
            ),
          ),
          h('今天做得好的事情'),
          const TextField(maxLines: 3, decoration: InputDecoration(hintText: '...')),
          h('今天可以改进什么？'),
          const TextField(maxLines: 3, decoration: InputDecoration(hintText: '...')),
          h('明天最重要的一件事'),
          panel(
            const Row(children: [
              Icon(Icons.check_box_outline_blank_rounded, size: 17, color: C.muted),
              SizedBox(width: 8),
              Text(
                '完成论文实验设计',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ]),
            padding: const EdgeInsets.all(10),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('完成今日复盘'),
            ),
          ),
        ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
      );
}

class Profile extends ConsumerWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider);
    final connected = session.valueOrNull != null;
    final cloud = session.valueOrNull;
    final name = cloud?.displayName?.trim().isNotEmpty == true
        ? cloud!.displayName!
        : cloud?.email.split('@').first ?? 'LifeTrace';
    final email = cloud?.email ?? '未连接账户';

    return DetailFrame(
      titleText: '我的',
      child: page([
        Row(children: [
          const CircleAvatar(
            radius: 23,
            backgroundColor: C.purpleSoft,
            child: Icon(Icons.person, color: C.purple),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              Text(email, style: const TextStyle(fontSize: 9, color: C.muted)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => push(c, const CloudConnection()),
          child: Row(children: [
            Icon(
              connected ? Icons.cloud_done_rounded : Icons.cloud_off_outlined,
              size: 14,
              color: connected ? C.green : C.muted,
            ),
            const SizedBox(width: 6),
            Text(
              connected ? 'LifeTrace Cloud 已连接' : 'LifeTrace Cloud 未连接',
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 15, color: C.muted),
          ]),
        ),
        h('账户'),
        panel(
          const Column(children: [
            _Setting(Icons.person_outline_rounded, '个人资料'),
            Divider(height: 1),
            _Setting(Icons.lock_outline_rounded, '账户与安全'),
            Divider(height: 1),
            _Setting(Icons.devices_outlined, '设备管理'),
          ]),
        ),
        h('LifeTrace'),
        panel(
          Column(children: [
            _Setting(
              Icons.cloud_sync_outlined,
              '同步与数据',
              onTap: () => push(c, const CloudConnection()),
            ),
            const Divider(height: 1),
            const _Setting(Icons.notifications_none_rounded, '通知'),
            const Divider(height: 1),
            const _Setting(Icons.palette_outlined, '外观'),
          ]),
        ),
        h('应用'),
        panel(
          const Column(children: [
            _Setting(Icons.settings_outlined, '通用'),
            Divider(height: 1),
            _Setting(Icons.info_outline_rounded, '关于'),
          ]),
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
    );
  }
}

class CloudConnection extends ConsumerStatefulWidget {
  const CloudConnection({super.key});

  @override
  ConsumerState<CloudConnection> createState() => _CloudConnectionState();
}

class _CloudConnectionState extends ConsumerState<CloudConnection> {
  final baseUrl = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final deviceName = TextEditingController(text: 'Android Device');
  bool busy = false;
  String? error;

  @override
  void dispose() {
    baseUrl.dispose();
    email.dispose();
    password.dispose();
    deviceName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final sessionState = ref.watch(currentSessionProvider);
    final session = sessionState.valueOrNull;
    return DetailFrame(
      titleText: 'LifeTrace Cloud',
      child: page([
        if (sessionState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (session != null)
          ..._connected(c, session)
        else
          ..._disconnected(c),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
    );
  }

  List<Widget> _connected(BuildContext c, dynamic session) {
    final syncState = ref.watch(taskSyncControllerProvider);
    final pending = ref.watch(taskPendingSyncCountProvider).valueOrNull ?? 0;
    final blocked = ref.watch(taskBlockedSyncCountProvider).valueOrNull ?? 0;
    final conflicts = ref.watch(taskConflictsProvider).valueOrNull?.length ?? 0;
    return [
      Row(children: [
        const CircleAvatar(
          radius: 19,
          backgroundColor: C.greenSoft,
          child: Icon(Icons.cloud_done_rounded, color: C.green, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Cloud 已连接',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            Text(
              session.email as String,
              style: const TextStyle(fontSize: 9.5, color: C.muted),
            ),
          ]),
        ),
      ]),
      h('连接'),
      panel(
        Column(children: [
          _InfoRow('服务地址', session.baseUrl as String),
          const Divider(height: 1),
          _InfoRow('会话', session.sessionId as String),
          const Divider(height: 1),
          _InfoRow('协议', 'Sync v${session.protocolVersion} · Schema ${session.schemaVersion}'),
        ]),
      ),
      h('任务同步'),
      Row(children: [
        chip('待上传 $pending', bg: pending > 0 ? C.ps : C.soft, fg: pending > 0 ? C.p : C.muted),
        const SizedBox(width: 6),
        chip('阻塞 $blocked', bg: blocked > 0 ? const Color(0xffffe9e9) : C.soft, fg: blocked > 0 ? C.red : C.muted),
        const SizedBox(width: 6),
        chip('冲突 $conflicts', bg: conflicts > 0 ? const Color(0xfffff3df) : C.soft, fg: conflicts > 0 ? C.orange : C.muted),
      ]),
      if (syncState.hasError) ...[
        const SizedBox(height: 9),
        Text(
          '同步失败：${syncState.error}。本地任务仍保存在设备中。',
          style: const TextStyle(fontSize: 9.5, color: C.red),
        ),
      ],
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: syncState.isLoading
              ? null
              : () => ref.read(taskSyncControllerProvider.notifier).syncNow(),
          icon: syncState.isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.sync_rounded, size: 17),
          label: Text(syncState.isLoading ? '正在同步' : '立即同步'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy ? null : _logout,
          child: const Text('断开连接'),
        ),
      ),
    ];
  }

  List<Widget> _disconnected(BuildContext c) => [
        const Text(
          '连接你的 LifeTrace Cloud',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          '任务仍采用 Local-first；登录后会执行 Snapshot → Push → Pull，并处理版本冲突。',
          style: TextStyle(fontSize: 10, color: C.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: baseUrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Cloud 地址',
            hintText: 'https://your-cloud.example.com',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '邮箱'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '密码'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: deviceName,
          decoration: const InputDecoration(labelText: '设备名称'),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(fontSize: 9.5, color: C.red)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy ? null : _login,
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('连接 Cloud'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '仅接受 HTTPS 服务 origin，不要填写 /api/v1/... 路径。凭据使用平台安全存储保存。',
          style: TextStyle(fontSize: 8.8, color: C.muted),
        ),
      ];

  Future<void> _login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(cloudCommandsProvider).login(
            baseUrl: baseUrl.text,
            email: email.text,
            password: password.text,
            deviceName: deviceName.text.trim().isEmpty ? 'Android Device' : deviceName.text.trim(),
          );
      await ref.read(taskSyncControllerProvider.notifier).syncNow();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(cloudCommandsProvider).logout();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 56,
            child: Text(label, style: const TextStyle(fontSize: 9.5, color: C.muted)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      );
}

class _Setting extends StatelessWidget {
  const _Setting(this.icon, this.label, {this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            Icon(icon, size: 16, color: C.muted),
            const SizedBox(width: 9),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 16, color: C.muted),
          ]),
        ),
      );
}

class DetailFrame extends StatelessWidget {
  const DetailFrame({
    required this.child,
    this.titleText = '',
    this.leading = Icons.arrow_back,
    this.actions = const [],
    super.key,
  });

  final Widget child;
  final String titleText;
  final IconData leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: C.bg,
        body: SafeArea(
          child: Column(children: [
            SizedBox(
              height: 42,
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(c),
                  icon: Icon(leading, size: 18),
                ),
                Expanded(
                  child: Text(
                    titleText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ),
                const SizedBox(width: 4),
              ]),
            ),
            Expanded(child: child),
            const SizedBox(height: 5),
          ]),
        ),
      );
}

void push(BuildContext c, Widget w) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));
