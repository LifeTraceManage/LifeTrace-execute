part of 'main.dart';

class Collection extends StatelessWidget {
  const Collection({super.key});

  @override
  Widget build(BuildContext c) => page([
        title('收集'),
        sub('有什么需要记下来？'),
        const SizedBox(height: 11),
        panel(
          Column(children: [
            const TextField(
              maxLines: 3,
              decoration: InputDecoration(hintText: '输入想法、任务、备忘...'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.attach_file_rounded, size: 18),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.mic_none_rounded, size: 18),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.image_outlined, size: 18),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 16,
                backgroundColor: C.teal,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {},
                  icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
                ),
              ),
            ]),
          ]),
          color: C.tealSoft,
        ),
        h('快速收集'),
        Wrap(spacing: 7, runSpacing: 7, children: [
          _Quick(Icons.edit_note_rounded, '文本', C.p, C.ps, () => capture(c, '文本')),
          _Quick(Icons.mic_none_rounded, '语音', C.purple, C.purpleSoft, () => capture(c, '语音')),
          _Quick(Icons.image_outlined, '图片', C.pink, C.pinkSoft, () => capture(c, '图片')),
          _Quick(Icons.link_rounded, '链接', C.teal, C.tealSoft, () => capture(c, '链接')),
          _Quick(Icons.insert_drive_file_outlined, '文件', C.orange, C.orangeSoft, () => capture(c, '文件')),
          _Quick(Icons.lightbulb_outline_rounded, '想法', C.amber, C.amberSoft, () => capture(c, '想法')),
        ]),
        h('Inbox · 7'),
        panel(
          const Column(children: [
            _Inbox(Icons.link_rounded, 'Transformer 新论文', '链接 · 10分钟前'),
            Divider(height: 1),
            _Inbox(Icons.notes_rounded, '明天找导师讨论实验方案', '文本 · 1小时前'),
            Divider(height: 1),
            _Inbox(Icons.image_outlined, 'IMG_2931.jpg', '图片 · 今天'),
            Divider(height: 1),
            _Inbox(Icons.lightbulb_outline_rounded, 'LifeTrace 设计灵感', '想法 · 今天'),
          ]),
        ),
      ]);

  Future<void> capture(BuildContext c, String t) => showModalBottomSheet(
        context: c,
        showDragHandle: true,
        builder: (x) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('新建$t', style: Theme.of(x).textTheme.titleLarge),
            const SizedBox(height: 12),
            const TextField(
              maxLines: 4,
              decoration: InputDecoration(hintText: '记录内容'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(x),
                child: const Text('保存到 Inbox'),
              ),
            ),
          ]),
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
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      );
}

class _Inbox extends StatelessWidget {
  const _Inbox(this.icon, this.title, this.meta);
  final IconData icon;
  final String title;
  final String meta;

  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: C.p),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
              ),
              Text(meta, style: const TextStyle(fontSize: 8.5, color: C.muted)),
            ]),
          ),
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
