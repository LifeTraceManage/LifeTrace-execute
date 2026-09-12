// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

part of 'main.dart';

class Today extends ConsumerWidget {
  const Today({super.key});

  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final importantDateState = ref.watch(importantDateListProvider);
    final now = DateTime.now();
    final upcoming = importantDatesForRange(
      importantDateState.valueOrNull ?? const <ExecutionImportantDate>[],
      start: now,
      end: now.add(const Duration(days: 90)),
    ).take(3).toList(growable: false);

    return page([
      _TodayHero(onProfile: () => push(c, const Profile())),
      const SizedBox(height: 13),
      const _Week(),
      const SizedBox(height: 13),
      _FocusHero(onStart: () => push(c, const Focus())),
      h('今日概览'),
      const _InlineStats(),
      h('时间线'),
      _TimeItem(
        '19:00',
        '健身',
        '胸 + 三头',
        color: C.green,
        icon: Icons.fitness_center_rounded,
        active: true,
        tap: () => push(c, const TaskDetail()),
      ),
      _TimeItem(
        '21:00',
        '修改实验代码',
        'Academic Research',
        color: C.purple,
        icon: Icons.code_rounded,
        tap: () => push(c, const TaskDetail()),
      ),
      _TimeItem(
        '22:30',
        '英语学习',
        '个人成长',
        color: C.orange,
        icon: Icons.menu_book_rounded,
        tap: () => push(c, const TaskDetail()),
      ),
      h(
        '待完成',
        tail: const Text(
          '2项',
          style: TextStyle(fontSize: 9, color: C.muted),
        ),
      ),
      _TaskLine(
        '修复 MPC 仿真',
        'Academic · 今天',
        accent: C.purple,
        icon: Icons.science_outlined,
        tap: () => push(c, const TaskDetail()),
      ),
      _TaskLine(
        '完成周报',
        '工作 · 明天',
        accent: C.sky,
        icon: Icons.work_outline_rounded,
        tap: () => push(c, const TaskDetail()),
      ),
      h(
        '近期重要日期',
        tail: Text(
          importantDateState.isLoading ? '同步中' : '${upcoming.length}项',
          style: const TextStyle(fontSize: 9, color: C.muted),
        ),
      ),
      if (importantDateState.isLoading)
        panel(const Center(child: CircularProgressIndicator()))
      else if (upcoming.isEmpty)
        panel(
          const Text(
            '未来 90 天没有启用的重要日期。',
            style: TextStyle(fontSize: 9.2, color: C.muted),
          ),
        )
      else
        for (final occurrence in upcoming)
          _TodayImportantDateTile(
            occurrence: occurrence,
            onTap: () => _editImportantDate(
              c,
              ref,
              item: occurrence.source,
            ),
          ),
      h('每日复盘'),
      panel(
        Row(children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: C.pinkSoft,
            child: Icon(Icons.auto_stories_outlined, size: 18, color: C.pink),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '记录今天，准备明天',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  '心情 · 精力 · 完成率 · 明日重点',
                  style: TextStyle(fontSize: 8.8, color: C.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: C.muted),
        ]),
        onTap: () => push(c, const Review()),
      ),
    ]);
  }
}

class _TodayImportantDateTile extends StatelessWidget {
  const _TodayImportantDateTile({
    required this.occurrence,
    required this.onTap,
  });

  final ImportantDateOccurrence occurrence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = occurrence.source;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = occurrence.localDate.difference(today).inDays;
    final countdown = days == 0 ? '今天' : days == 1 ? '明天' : '${days}天后';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: C.pinkSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(
              _importantDateKindIcon(item.kind),
              size: 15,
              color: C.pink,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatImportantDate(occurrence.localDate)} · '
                  '${_importantDateSourceText(item)}',
                  style: const TextStyle(fontSize: 8.5, color: C.muted),
                ),
              ],
            ),
          ),
          chip(countdown, bg: Colors.white, fg: C.pink),
        ]),
      ),
    );
  }
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.onProfile});

  final VoidCallback onProfile;

  @override
  Widget build(BuildContext c) => Container(
        height: 116,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffedf4ff), Color(0xfff6efff)],
          ),
        ),
        child: Stack(children: [
          Positioned(
            right: -22,
            top: -28,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.purple.withValues(alpha: .08),
              ),
            ),
          ),
          Positioned(
            right: 34,
            bottom: -40,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: C.p.withValues(alpha: .07),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 13, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                    '9月9日 · 星期三',
                    style: TextStyle(fontSize: 9.5, color: C.muted, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '晚上好，Alex',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -.4),
                  ),
                  const Spacer(),
                  Row(children: [
                    _HeroTag(Icons.bolt_rounded, '连续 7 天', C.orange),
                    const SizedBox(width: 6),
                    _HeroTag(Icons.check_rounded, '8 已完成', C.green),
                  ]),
                ]),
              ),
              InkWell(
                onTap: onProfile,
                borderRadius: BorderRadius.circular(40),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 66,
                    height: 66,
                    child: Stack(fit: StackFit.expand, children: [
                      const CircularProgressIndicator(
                        value: .73,
                        strokeWidth: 5,
                        color: C.purple,
                        backgroundColor: Colors.white,
                      ),
                      const Center(
                        child: CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person_rounded, color: C.purple, size: 25),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  const Text('今日 73%', style: TextStyle(fontSize: 8.5, color: C.muted)),
                ]),
              ),
            ]),
          ),
        ]),
      );
}

class _HeroTag extends StatelessWidget {
  const _HeroTag(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .86),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _FocusHero extends StatelessWidget {
  const _FocusHero({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff6f58e8), Color(0xff4d7df4)],
          ),
          boxShadow: [
            BoxShadow(
              color: C.purple.withValues(alpha: .16),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Icon(Icons.auto_awesome_rounded, size: 13, color: Colors.white70),
                SizedBox(width: 5),
                Text(
                  'TODAY FOCUS',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: .9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white70,
                  ),
                ),
              ]),
              const SizedBox(height: 9),
              const Text(
                '完成论文实验设计',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Academic Research  ·  23:00 截止',
                style: TextStyle(fontSize: 9, color: Colors.white70),
              ),
              const SizedBox(height: 11),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'P1 高优先级',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 7),
                const Text('预计 50 min', style: TextStyle(fontSize: 8.5, color: Colors.white70)),
              ]),
            ]),
          ),
          InkWell(
            onTap: onStart,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .96),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: C.purple, size: 30),
            ),
          ),
        ]),
      );
}

class _Week extends StatelessWidget {
  const _Week();

  @override
  Widget build(BuildContext c) {
    const ds = ['7', '8', '9', '10', '11', '12', '13'];
    const ws = ['一', '二', '三', '四', '五', '六', '日'];
    const dots = [C.sky, C.teal, C.purple, C.orange, C.red, C.green, C.pink];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final selected = i == 2;
          return SizedBox(
            width: 39,
            child: Column(children: [
              Text(ws[i], style: const TextStyle(fontSize: 8, color: C.muted)),
              const SizedBox(height: 4),
              Container(
                width: 29,
                height: 29,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? C.p : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ds[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: selected ? Colors.white : C.ink,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: selected ? 12 : 5,
                height: 3,
                decoration: BoxDecoration(
                  color: dots[i],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ]),
          );
        }),
      ),
    );
  }
}

class _InlineStats extends StatelessWidget {
  const _InlineStats();

  @override
  Widget build(BuildContext c) => const Row(children: [
        Expanded(
          child: _MiniMetric(
            Icons.check_circle_outline_rounded,
            '5',
            '待完成',
            C.p,
            C.ps,
          ),
        ),
        SizedBox(width: 7),
        Expanded(
          child: _MiniMetric(
            Icons.calendar_month_rounded,
            '2',
            '日程',
            C.orange,
            C.orangeSoft,
          ),
        ),
        SizedBox(width: 7),
        Expanded(
          child: _MiniMetric(
            Icons.local_fire_department_outlined,
            '1',
            '习惯',
            C.green,
            C.greenSoft,
          ),
        ),
      ]);
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric(this.icon, this.value, this.label, this.color, this.background);
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
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 7),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color),
            ),
            Text(label, style: const TextStyle(fontSize: 8.5, color: C.muted)),
          ]),
        ]),
      );
}

class _TimeItem extends StatelessWidget {
  const _TimeItem(
    this.time,
    this.name,
    this.meta, {
    this.color = C.p,
    this.icon = Icons.circle,
    this.active = false,
    this.tap,
  });

  final String time;
  final String name;
  final String meta;
  final Color color;
  final IconData icon;
  final bool active;
  final VoidCallback? tap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            SizedBox(
              width: 42,
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                  color: active ? color : C.muted,
                ),
              ),
            ),
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 11.3, fontWeight: FontWeight.w800)),
                if (meta.isNotEmpty)
                  Text(meta, style: const TextStyle(fontSize: 8.8, color: C.muted)),
              ]),
            ),
            if (active) chip('进行中', bg: C.greenSoft, fg: C.green),
          ]),
        ),
      );
}

class _TaskLine extends StatelessWidget {
  const _TaskLine(
    this.name,
    this.meta, {
    this.accent = C.p,
    this.icon = Icons.check_rounded,
    this.tap,
  });

  final String name;
  final String meta;
  final Color accent;
  final IconData icon;
  final VoidCallback? tap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: C.border),
          ),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 15, color: accent),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w800)),
                Text(meta, style: const TextStyle(fontSize: 8.8, color: C.muted)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: accent.withValues(alpha: .75)),
          ]),
        ),
      );
}

class Tasks extends ConsumerStatefulWidget {
  const Tasks({super.key});

  @override
  ConsumerState<Tasks> createState() => _TasksState();
}

class _TasksState extends ConsumerState<Tasks> {
  int filter = 0;
  String query = '';

  @override
  Widget build(BuildContext c) {
    final tasks = ref.watch(taskListProvider);
    final session = ref.watch(currentSessionProvider);
    final connected = kIsWeb || session.valueOrNull != null;
    final pending = ref.watch(taskPendingSyncCountProvider).valueOrNull ?? 0;
    final blocked = ref.watch(taskBlockedSyncCountProvider).valueOrNull ?? 0;
    final conflicts = ref.watch(taskConflictsProvider).valueOrNull ?? const <TaskConflictUi>[];
    final syncState = ref.watch(taskSyncControllerProvider);

    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: C.p,
        foregroundColor: Colors.white,
        onPressed: connected ? () => _composer(c) : () => push(c, const CloudConnection()),
        child: Icon(connected ? Icons.add : Icons.cloud_outlined),
      ),
      body: tasks.when(
        loading: () => page([
          _header(connected, pending, blocked, syncState.isLoading),
          const SizedBox(height: 80),
          const Center(child: CircularProgressIndicator()),
        ]),
        error: (error, stack) => page([
          _header(connected, pending, blocked, syncState.isLoading),
          h('任务数据加载失败'),
          panel(Text('$error', style: const TextStyle(fontSize: 10.5, color: C.red))),
        ]),
        data: (allTasks) {
          final visible = allTasks.where(_matches).toList(growable: false);
          return page([
            _header(connected, pending, blocked, syncState.isLoading),
            const SizedBox(height: 10),
            _TaskOverview(allTasks),
            if (!connected) ...[
              const SizedBox(height: 10),
              panel(
                Row(children: [
                  const Icon(Icons.cloud_off_outlined, size: 18, color: C.muted),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      '连接 LifeTrace Cloud 后即可创建和同步任务',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    onPressed: () => push(c, const CloudConnection()),
                    child: const Text('连接'),
                  ),
                ]),
                color: C.soft,
              ),
            ],
            if (syncState.hasError) ...[
              const SizedBox(height: 8),
              Text(
                '同步失败：${syncState.error}。本地任务不会丢失。',
                style: const TextStyle(fontSize: 9.2, color: C.red),
              ),
            ],
            if (conflicts.isNotEmpty) ...[
              h('需要处理的同步冲突 · ${conflicts.length}'),
              for (final conflict in conflicts) _ConflictRow(conflict),
            ],
            const SizedBox(height: 10),
            TextField(
              onChanged: (value) => setState(() => query = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: '搜索任务...',
                prefixIcon: Icon(Icons.search_rounded, size: 18),
                suffixIcon: Icon(Icons.tune_rounded, size: 17, color: C.sky),
              ),
            ),
            const SizedBox(height: 9),
            _Tabs(
              labels: const ['全部', '今天', '即将到期', '等待中'],
              selected: filter,
              onTap: (value) => setState(() => filter = value),
            ),
            h(
              '任务 · ${visible.length}',
              tail: chip('卡片视图', bg: C.skySoft, fg: C.sky),
            ),
            if (visible.isEmpty)
              const _TaskEmptyState()
            else
              Column(
                children: [
                  for (final task in visible)
                    _TaskRow(
                      task,
                      onTap: () => push(c, TaskDetail(task: task)),
                      onToggle: () => ref.read(taskCommandsProvider).toggleDone(task),
                    ),
                ],
              ),
          ]);
        },
      ),
    );
  }

  Widget _header(bool connected, int pending, int blocked, bool syncing) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('任务'),
            sub(
              connected
                  ? 'Local-first · 待同步 $pending${blocked > 0 ? ' · 阻塞 $blocked' : ''}'
                  : 'Local-first · 尚未连接 Cloud',
            ),
          ]),
        ),
        if (connected && !kIsWeb)
          IconButton(
            tooltip: '立即同步',
            onPressed: syncing
                ? null
                : () => ref.read(taskSyncControllerProvider.notifier).syncNow(),
            icon: syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    blocked > 0 ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                    size: 18,
                    color: blocked > 0 ? C.orange : C.green,
                  ),
          )
        else
          Icon(
            connected ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
            size: 18,
            color: connected ? C.green : C.muted,
          ),
      ]);

  bool _matches(ExecutionTask task) {
    if (query.isNotEmpty) {
      final haystack = '${task.title} ${task.description ?? ''}'.toLowerCase();
      if (!haystack.contains(query)) return false;
    }
    if (filter == 3) return task.status == ExecutionTaskStatus.waiting;
    if (filter == 0) return true;

    final source = task.scheduledAt ?? task.dueAt;
    if (source == null) return false;
    final value = DateTime.tryParse(source)?.toLocal();
    if (value == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(value.year, value.month, value.day);
    final days = date.difference(today).inDays;
    if (filter == 1) return days == 0;
    return days >= 0 && days <= 3;
  }

  Future<void> _composer(BuildContext c) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    var priority = ExecutionTaskPriority.normal;
    DateTime? scheduledAt;
    DateTime? dueAt;

    await showModalBottomSheet<void>(
      context: c,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleController,
                autofocus: true,
                decoration: const InputDecoration(hintText: '任务标题'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: '描述'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<ExecutionTaskPriority>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: '优先级'),
                items: ExecutionTaskPriority.values
                    .map((item) => DropdownMenuItem(value: item, child: Text(_priorityText(item))))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setSheetState(() => priority = value);
                },
              ),
              const SizedBox(height: 10),
              _DateField(
                label: '计划时间',
                value: scheduledAt,
                onPick: () async {
                  final value = await _pickDateTime(sheetContext, scheduledAt);
                  if (value != null) setSheetState(() => scheduledAt = value);
                },
                onClear: scheduledAt == null ? null : () => setSheetState(() => scheduledAt = null),
              ),
              const SizedBox(height: 8),
              _DateField(
                label: '截止时间',
                value: dueAt,
                onPick: () async {
                  final value = await _pickDateTime(sheetContext, dueAt);
                  if (value != null) setSheetState(() => dueAt = value);
                },
                onClear: dueAt == null ? null : () => setSheetState(() => dueAt = null),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      await ref.read(taskCommandsProvider).create(
                            title: titleController.text,
                            description: descriptionController.text,
                            priority: priority,
                            scheduledAt: scheduledAt?.toUtc().toIso8601String(),
                            dueAt: dueAt?.toUtc().toIso8601String(),
                          );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (error) {
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text('$error')),
                      );
                    }
                  },
                  child: const Text('保存任务'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }
}

class _TaskOverview extends StatelessWidget {
  const _TaskOverview(this.tasks);
  final List<ExecutionTask> tasks;

  @override
  Widget build(BuildContext c) {
    final done = tasks.where((task) => task.isDone).length;
    final urgent = tasks.where((task) => task.priority == ExecutionTaskPriority.urgent).length;
    final waiting = tasks.where((task) => task.status == ExecutionTaskStatus.waiting).length;
    final ratio = tasks.isEmpty ? 0.0 : done / tasks.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [C.skySoft, C.ps],
        ),
      ),
      child: Row(children: [
        SizedBox(
          width: 58,
          height: 58,
          child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(
              value: ratio,
              strokeWidth: 6,
              color: C.sky,
              backgroundColor: Colors.white,
            ),
            Center(
              child: Text(
                '${(ratio * 100).round()}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: C.sky),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              '任务节奏',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _CountBadge(Icons.check_rounded, '$done 完成', C.green, C.greenSoft),
              _CountBadge(Icons.flag_rounded, '$urgent P1', C.red, C.redSoft),
              _CountBadge(Icons.hourglass_bottom_rounded, '$waiting 等待', C.orange, C.orangeSoft),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.icon, this.label, this.color, this.background);
  final IconData icon;
  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: color)),
        ]),
      );
}

class _ConflictRow extends ConsumerWidget {
  const _ConflictRow(this.conflict);
  final TaskConflictUi conflict;

  @override
  Widget build(BuildContext c, WidgetRef ref) => panel(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            conflict.localTitle ?? '本地任务',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            conflict.serverDeleted
                ? '云端版本：已删除'
                : '云端版本：${conflict.serverTitle ?? '内容已更新'}',
            style: const TextStyle(fontSize: 9.2, color: C.muted),
          ),
          if (conflict.reason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(conflict.reason, style: const TextStyle(fontSize: 8.8, color: C.muted)),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => ref
                    .read(taskSyncControllerProvider.notifier)
                    .keepLocal(conflict.conflictId),
                child: const Text('保留本地'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonal(
                onPressed: () => ref
                    .read(taskSyncControllerProvider.notifier)
                    .keepServer(conflict.conflictId),
                child: const Text('使用云端'),
              ),
            ),
          ]),
        ]),
        color: const Color(0xfffffbf3),
      );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.labels, required this.selected, required this.onTap});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext c) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            labels.length,
            (i) => Padding(
              padding: const EdgeInsets.only(right: 7),
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(8),
                child: chip(
                  labels[i],
                  bg: i == selected ? C.ps : C.soft,
                  fg: i == selected ? C.p : C.muted,
                ),
              ),
            ),
          ),
        ),
      );
}

class _TaskEmptyState extends StatelessWidget {
  const _TaskEmptyState();

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: C.skySoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.white,
            child: Icon(Icons.task_alt_rounded, color: C.sky, size: 25),
          ),
          SizedBox(height: 9),
          Text('这里很清爽', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
          SizedBox(height: 3),
          Text('暂无符合条件的任务', style: TextStyle(fontSize: 9.2, color: C.muted)),
        ]),
      );
}

class _TaskRow extends StatelessWidget {
  const _TaskRow(this.task, {required this.onTap, required this.onToggle});

  final ExecutionTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext c) {
    final urgent = task.priority == ExecutionTaskPriority.urgent;
    final high = task.priority == ExecutionTaskPriority.high;
    final waiting = task.status == ExecutionTaskStatus.waiting;

    final accent = task.isDone
        ? C.green
        : waiting
            ? C.purple
            : urgent
                ? C.red
                : high
                    ? C.orange
                    : C.sky;
    final tint = task.isDone
        ? C.greenSoft
        : waiting
            ? C.purpleSoft
            : urgent
                ? C.redSoft
                : high
                    ? C.orangeSoft
                    : C.skySoft;
    final icon = task.isDone
        ? Icons.done_all_rounded
        : waiting
            ? Icons.hourglass_bottom_rounded
            : urgent
                ? Icons.local_fire_department_rounded
                : high
                    ? Icons.flag_rounded
                    : Icons.task_alt_rounded;
    final priority = switch (task.priority) {
      ExecutionTaskPriority.urgent => 'P1',
      ExecutionTaskPriority.high => 'P2',
      ExecutionTaskPriority.normal => '普通',
      ExecutionTaskPriority.low => '低',
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(10, 10, 9, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: accent.withValues(alpha: .12)),
          boxShadow: [
            BoxShadow(
              color: C.ink.withValues(alpha: .035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(alignment: Alignment.center, children: [
                Icon(icon, size: 18, color: accent),
                if (!task.isDone)
                  Positioned(
                    right: 5,
                    bottom: 5,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.4),
                      ),
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.7,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      decoration: task.isDone ? TextDecoration.lineThrough : null,
                      color: task.isDone ? C.muted : C.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                chip(priority, bg: tint, fg: accent),
              ]),
              if ((task.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 8.8, color: C.muted),
                ),
              ],
              const SizedBox(height: 7),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.soft,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Row(children: [
                    Icon(Icons.schedule_rounded, size: 10, color: accent),
                    const SizedBox(width: 4),
                    Text(
                      _taskMeta(task),
                      style: const TextStyle(fontSize: 8.2, color: C.muted, fontWeight: FontWeight.w700),
                    ),
                  ]),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded, size: 17, color: accent.withValues(alpha: .72)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class TaskDetail extends ConsumerStatefulWidget {
  const TaskDetail({super.key, this.task});

  final ExecutionTask? task;

  @override
  ConsumerState<TaskDetail> createState() => _TaskDetailState();
}

class _TaskDetailState extends ConsumerState<TaskDetail> {
  ExecutionTask? current;
  bool a = true;
  bool b = false;
  bool c2 = false;

  @override
  void initState() {
    super.initState();
    current = widget.task;
  }

  @override
  Widget build(BuildContext c) {
    final task = current;
    final displayTitle = task?.title ?? '完成 LifeTrace Execute UI';
    final description = task?.description ?? 'Flutter 重构正式客户端，并保持 Local-first 与 LifeTrace Cloud 的行为兼容。';
    final priority = task?.priority ?? ExecutionTaskPriority.urgent;
    final status = task?.status ?? ExecutionTaskStatus.inProgress;
    final completed = task?.isDone == true;
    final reminderItems = task == null
        ? const <ExecutionReminder>[]
        : ref
                .watch(
                  remindersForSubjectProvider(
                    ReminderSubjectKey(
                      subjectType: ReminderSubjectTypes.task,
                      subjectId: task.id,
                    ),
                  ),
                )
                .valueOrNull ??
            const <ExecutionReminder>[];
    final reminder = _activeReminder(reminderItems);
    final reminderConflicts =
        ref.watch(reminderConflictsProvider).valueOrNull ??
            const <ReminderConflictUi>[];
    ReminderConflictUi? reminderConflict;
    for (final conflict in reminderConflicts) {
      if (reminderItems.any((item) => item.id == conflict.reminderId)) {
        reminderConflict = conflict;
        break;
      }
    }

    final accent = completed
        ? C.green
        : switch (priority) {
            ExecutionTaskPriority.urgent => C.red,
            ExecutionTaskPriority.high => C.orange,
            ExecutionTaskPriority.normal => C.sky,
            ExecutionTaskPriority.low => C.teal,
          };
    final tint = completed
        ? C.greenSoft
        : switch (priority) {
            ExecutionTaskPriority.urgent => C.redSoft,
            ExecutionTaskPriority.high => C.orangeSoft,
            ExecutionTaskPriority.normal => C.skySoft,
            ExecutionTaskPriority.low => C.tealSoft,
          };

    return DetailFrame(
      titleText: '任务详情',
      actions: [
        if (task != null)
          IconButton(
            tooltip: '删除任务',
            onPressed: () async {
              await ref.read(reminderCommandsProvider).cancelForSubject(
                    subjectType: ReminderSubjectTypes.task,
                    subjectId: task.id,
                  );
              await ref.read(taskCommandsProvider).delete(task);
              if (c.mounted) Navigator.pop(c);
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
          )
        else
          const Icon(Icons.more_vert_rounded, size: 19),
      ],
      child: page([
        _TaskDetailHero(
          title: displayTitle,
          description: description,
          accent: accent,
          tint: tint,
          completed: completed,
          priority: _priorityBadge(priority),
          status: _statusText(status),
          onToggle: task == null
              ? null
              : () async {
                  final updated =
                      await ref.read(taskCommandsProvider).toggleDone(task);
                  if (updated.isDone) {
                    await ref.read(reminderCommandsProvider).cancelForSubject(
                          subjectType: ReminderSubjectTypes.task,
                          subjectId: task.id,
                        );
                  }
                  if (mounted) setState(() => current = updated);
                },
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _TaskMetaTile(
              icon: Icons.event_available_rounded,
              label: '计划时间',
              value: _formatTaskDate(task?.scheduledAt),
              color: C.sky,
              background: C.skySoft,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TaskMetaTile(
              icon: Icons.flag_rounded,
              label: '截止时间',
              value: _formatTaskDate(task?.dueAt),
              color: C.red,
              background: C.redSoft,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _TaskMetaTile(
              icon: Icons.bolt_rounded,
              label: '优先级',
              value: _priorityText(priority),
              color: accent,
              background: tint,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _TaskMetaTile(
              icon: Icons.folder_rounded,
              label: '项目',
              value: task?.projectId ?? '未归属',
              color: C.purple,
              background: C.purpleSoft,
            ),
          ),
        ]),
        h('说明'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: C.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: C.soft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.notes_rounded, size: 17, color: C.muted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                description,
                style: const TextStyle(fontSize: 10.2, color: C.muted, height: 1.45),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          if (task != null) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _edit(c, task),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('编辑任务'),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: () => push(c, const Focus()),
              icon: const Icon(Icons.play_arrow_rounded, size: 17),
              label: const Text('开始专注'),
            ),
          ),
        ]),
        h('子任务'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: C.purpleSoft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Row(children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(fit: StackFit.expand, children: [
                  const CircularProgressIndicator(
                    value: 1 / 3,
                    strokeWidth: 5,
                    color: C.purple,
                    backgroundColor: Colors.white,
                  ),
                  const Center(
                    child: Text(
                      '1/3',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: C.purple),
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('推进任务步骤', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900)),
                  SizedBox(height: 2),
                  Text('完成一个小步骤，比盯着大任务更轻松', style: TextStyle(fontSize: 8.8, color: C.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            _SubtaskTile(
              value: a,
              label: '分析现有页面',
              color: C.green,
              background: C.greenSoft,
              onChanged: (v) => setState(() => a = v),
            ),
            const SizedBox(height: 7),
            _SubtaskTile(
              value: b,
              label: '完成 UI Design',
              color: C.purple,
              background: C.pinkSoft,
              onChanged: (v) => setState(() => b = v),
            ),
            const SizedBox(height: 7),
            _SubtaskTile(
              value: c2,
              label: 'Flutter 实现',
              color: C.sky,
              background: C.skySoft,
              onChanged: (v) => setState(() => c2 = v),
            ),
          ]),
        ),
        if (task != null) ...[
          h('提醒'),
          if (reminderConflict != null) ...[
            _ReminderConflictBanner(conflict: reminderConflict),
            const SizedBox(height: 8),
          ],
          InkWell(
            onTap: completed
                ? null
                : () => _editReminder(
                      c,
                      ref,
                      subjectType: ReminderSubjectTypes.task,
                      subjectId: task.id,
                      subjectTitle: task.title,
                      suggestedAt: _suggestTaskReminder(task),
                      existing: reminder,
                    ),
            borderRadius: BorderRadius.circular(13),
            child: Opacity(
              opacity: completed ? .55 : 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(
                  color: C.orangeSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.notifications_none_rounded,
                      size: 16,
                      color: C.orange,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder == null ? '设置提醒' : '已设置提醒',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          completed
                              ? '已完成任务不会继续触发提醒'
                              : reminder == null
                                  ? '点击选择提醒时间'
                                  : _formatReminderTime(reminder),
                          style:
                              const TextStyle(fontSize: 8.5, color: C.muted),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: C.orange,
                  ),
                ]),
              ),
            ),
          ),
        ],
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 20)),
    );
  }

  Future<void> _edit(BuildContext context, ExecutionTask task) async {
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description ?? '');
    var priority = task.priority;
    var status = task.status;
    DateTime? scheduledAt = DateTime.tryParse(task.scheduledAt ?? '')?.toLocal();
    DateTime? dueAt = DateTime.tryParse(task.dueAt ?? '')?.toLocal();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: '标题')),
              const SizedBox(height: 10),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '描述'),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<ExecutionTaskStatus>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: '状态'),
                    items: ExecutionTaskStatus.values
                        .map((item) => DropdownMenuItem(value: item, child: Text(_statusText(item))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setSheetState(() => status = value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<ExecutionTaskPriority>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: '优先级'),
                    items: ExecutionTaskPriority.values
                        .map((item) => DropdownMenuItem(value: item, child: Text(_priorityText(item))))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) setSheetState(() => priority = value);
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              _DateField(
                label: '计划时间',
                value: scheduledAt,
                onPick: () async {
                  final value = await _pickDateTime(sheetContext, scheduledAt);
                  if (value != null) setSheetState(() => scheduledAt = value);
                },
                onClear: scheduledAt == null ? null : () => setSheetState(() => scheduledAt = null),
              ),
              const SizedBox(height: 8),
              _DateField(
                label: '截止时间',
                value: dueAt,
                onPick: () async {
                  final value = await _pickDateTime(sheetContext, dueAt);
                  if (value != null) setSheetState(() => dueAt = value);
                },
                onClear: dueAt == null ? null : () => setSheetState(() => dueAt = null),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      final updated = await ref.read(taskCommandsProvider).update(
                            task: task,
                            title: titleController.text,
                            description: descriptionController.text,
                            clearDescription: descriptionController.text.trim().isEmpty,
                            status: status,
                            priority: priority,
                            scheduledAt: scheduledAt?.toUtc().toIso8601String(),
                            dueAt: dueAt?.toUtc().toIso8601String(),
                            clearScheduledAt: scheduledAt == null,
                            clearDueAt: dueAt == null,
                          );
                      if (mounted) setState(() => current = updated);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (error) {
                      if (!sheetContext.mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text('$error')),
                      );
                    }
                  },
                  child: const Text('保存修改'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }
}

class _TaskDetailHero extends StatelessWidget {
  const _TaskDetailHero({
    required this.title,
    required this.description,
    required this.accent,
    required this.tint,
    required this.completed,
    required this.priority,
    required this.status,
    this.onToggle,
  });

  final String title;
  final String description;
  final Color accent;
  final Color tint;
  final bool completed;
  final String priority;
  final String status;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tint, Colors.white],
          ),
          border: Border.all(color: accent.withValues(alpha: .14)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: accent,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                  color: completed ? C.muted : C.ink,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            chip(priority, bg: Colors.white, fg: accent),
            chip(status, bg: Colors.white, fg: C.green),
            if (completed) chip('已完成', bg: C.greenSoft, fg: C.green),
          ]),
        ]),
      );
}

class _TaskMetaTile extends StatelessWidget {
  const _TaskMetaTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext c) => Container(
        height: 76,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: color),
            ),
            const Spacer(),
            Icon(Icons.more_horiz_rounded, size: 14, color: color.withValues(alpha: .65)),
          ]),
          const Spacer(),
          Text(label, style: const TextStyle(fontSize: 8.2, color: C.muted)),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: color),
          ),
        ]),
      );
}

class _SubtaskTile extends StatelessWidget {
  const _SubtaskTile({
    required this.value,
    required this.label,
    required this.color,
    required this.background,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final Color color;
  final Color background;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(children: [
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: value ? background : C.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                value ? Icons.check_rounded : Icons.circle_outlined,
                size: 15,
                color: value ? color : C.muted,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10.2,
                  fontWeight: FontWeight.w800,
                  color: value ? C.muted : C.ink,
                  decoration: value ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ]),
        ),
      );
}

class _ReminderConflictBanner extends ConsumerWidget {
  const _ReminderConflictBanner({required this.conflict});

  final ReminderConflictUi conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: C.redSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            '提醒存在同步冲突',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            conflict.serverDeleted ? '云端提醒已删除' : conflict.reason,
            style: const TextStyle(fontSize: 8.5, color: C.muted),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => ref
                    .read(reminderCommandsProvider)
                    .keepServer(conflict.conflictId),
                child: const Text('保留云端'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: () => ref
                    .read(reminderCommandsProvider)
                    .keepLocal(conflict.conflictId),
                child: const Text('保留本地'),
              ),
            ),
          ]),
        ]),
      );
}

ExecutionReminder? _activeReminder(List<ExecutionReminder> reminders) {
  for (final reminder in reminders.reversed) {
    if (reminder.status == ExecutionReminderStatus.scheduled) return reminder;
  }
  return null;
}

DateTime _suggestTaskReminder(ExecutionTask task) {
  final now = DateTime.now();
  for (final raw in [task.scheduledAt, task.dueAt]) {
    final value = DateTime.tryParse(raw ?? '')?.toLocal();
    if (value != null && value.isAfter(now)) return value;
  }
  return now.add(const Duration(hours: 1));
}

String _formatReminderTime(ExecutionReminder reminder) {
  final value = DateTime.parse(reminder.effectiveTriggerAt).toLocal();
  return _formatDateTime(value);
}

Future<void> _editReminder(
  BuildContext context,
  WidgetRef ref, {
  required String subjectType,
  required String subjectId,
  required String subjectTitle,
  required DateTime suggestedAt,
  ExecutionReminder? existing,
}) async {
  DateTime triggerAt = existing == null
      ? suggestedAt
      : DateTime.parse(existing.effectiveTriggerAt).toLocal();
  if (!triggerAt.isAfter(DateTime.now())) {
    triggerAt = DateTime.now().add(const Duration(hours: 1));
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              existing == null ? '设置提醒' : '调整提醒',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subjectTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: C.muted),
            ),
          ),
          const SizedBox(height: 12),
          _DateField(
            label: '提醒时间',
            value: triggerAt,
            onPick: () async {
              final value = await _pickDateTime(sheetContext, triggerAt);
              if (value != null) setSheetState(() => triggerAt = value);
            },
          ),
          const SizedBox(height: 14),
          Row(children: [
            if (existing != null) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(reminderCommandsProvider).cancel(existing);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                  child: const Text('取消提醒'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(reminderCommandsProvider).schedule(
                          subjectType: subjectType,
                          subjectId: subjectId,
                          triggerAt: triggerAt,
                          title: subjectTitle,
                          body: 'LifeTrace Execute 提醒',
                        );
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text('$error')),
                      );
                    }
                  }
                },
                child: Text(existing == null ? '创建提醒' : '保存提醒'),
              ),
            ),
          ]),
        ]),
      ),
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext c) => Container(
        decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Expanded(
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: const TextStyle(fontSize: 8.5, color: C.muted)),
                  const SizedBox(height: 2),
                  Text(
                    value == null ? '未设置' : _formatDateTime(value!),
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: '清除',
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 16),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.schedule_rounded, size: 16, color: C.muted),
            ),
        ]),
      );
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initial) async {
  final now = DateTime.now();
  final start = initial ?? now;
  final date = await showDatePicker(
    context: context,
    initialDate: start,
    firstDate: DateTime(now.year - 2),
    lastDate: DateTime(now.year + 10),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(start),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String _priorityBadge(ExecutionTaskPriority priority) => switch (priority) {
      ExecutionTaskPriority.urgent => 'P1',
      ExecutionTaskPriority.high => 'P2',
      ExecutionTaskPriority.normal => 'P3',
      ExecutionTaskPriority.low => 'P4',
    };

String _priorityText(ExecutionTaskPriority priority) => switch (priority) {
      ExecutionTaskPriority.urgent => '紧急',
      ExecutionTaskPriority.high => '高',
      ExecutionTaskPriority.normal => '普通',
      ExecutionTaskPriority.low => '低',
    };

String _statusText(ExecutionTaskStatus status) => switch (status) {
      ExecutionTaskStatus.todo => '待办',
      ExecutionTaskStatus.inProgress => '进行中',
      ExecutionTaskStatus.waiting => '等待中',
      ExecutionTaskStatus.done => '已完成',
    };

String _taskMeta(ExecutionTask task) {
  final parts = <String>[];
  if (task.projectId != null) parts.add('项目');
  if (task.scheduledAt != null) parts.add('计划 ${_formatTaskDate(task.scheduledAt)}');
  if (task.dueAt != null) parts.add('截止 ${_formatTaskDate(task.dueAt)}');
  if (task.status == ExecutionTaskStatus.waiting) parts.add('等待中');
  if (parts.isEmpty) parts.add('本地任务');
  return parts.join(' · ');
}

String _formatTaskDate(String? raw) {
  if (raw == null) return '未设置';
  final value = DateTime.tryParse(raw)?.toLocal();
  return value == null ? raw : _formatDateTime(value);
}

String _formatDateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.month}月${value.day}日 ${two(value.hour)}:${two(value.minute)}';
}
