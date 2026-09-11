part of 'main.dart';

class Today extends StatelessWidget {
  const Today({super.key});

  @override
  Widget build(BuildContext c) => page([
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
        h('待完成', tail: const Text('2项', style: TextStyle(fontSize: 9, color: C.muted))),
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
      ]);
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
              ),
            ),
            const SizedBox(height: 9),
            _Tabs(
              labels: const ['全部', '今天', '即将到期', '等待中'],
              selected: filter,
              onTap: (value) => setState(() => filter = value),
            ),
            h('任务 · ${visible.length}'),
            if (visible.isEmpty)
              panel(
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('暂无符合条件的任务', style: TextStyle(fontSize: 10.5, color: C.muted)),
                  ),
                ),
              )
            else
              panel(
                Column(
                  children: [
                    for (var index = 0; index < visible.length; index++) ...[
                      _TaskRow(
                        visible[index],
                        onTap: () => push(c, TaskDetail(task: visible[index])),
                        onToggle: () => ref.read(taskCommandsProvider).toggleDone(visible[index]),
                      ),
                      if (index != visible.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
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

class _TaskRow extends StatelessWidget {
  const _TaskRow(this.task, {required this.onTap, required this.onToggle});

  final ExecutionTask task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext c) {
    final badge = switch (task.priority) {
      ExecutionTaskPriority.urgent => 'P1',
      ExecutionTaskPriority.high => 'P2',
      ExecutionTaskPriority.normal => '',
      ExecutionTaskPriority.low => '',
    };
    final color = task.priority == ExecutionTaskPriority.urgent ? C.red : C.orange;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              task.isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: task.isDone ? C.green : C.muted,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                task.title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  decoration: task.isDone ? TextDecoration.lineThrough : null,
                  color: task.isDone ? C.muted : C.ink,
                ),
              ),
              Text(_taskMeta(task), style: const TextStyle(fontSize: 9.2, color: C.muted)),
            ]),
          ),
          if (badge.isNotEmpty) chip(badge, bg: color.withValues(alpha: .12), fg: color),
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

    return DetailFrame(
      titleText: '',
      actions: [
        if (task != null)
          IconButton(
            tooltip: '删除任务',
            onPressed: () async {
              await ref.read(taskCommandsProvider).delete(task);
              if (c.mounted) Navigator.pop(c);
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
          )
        else
          const Icon(Icons.more_vert_rounded, size: 19),
      ],
      child: page([
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: task == null
                ? null
                : () async {
                    final updated = await ref.read(taskCommandsProvider).toggleDone(task);
                    if (mounted) setState(() => current = updated);
                  },
            child: Icon(
              task?.isDone == true ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 21,
              color: task?.isDone == true ? C.green : C.p,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(displayTitle, style: Theme.of(c).textTheme.titleLarge)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 5, children: [
          chip(_priorityBadge(priority), bg: const Color(0xffffe9e9), fg: C.red),
          if (task?.projectId != null) chip('项目', bg: C.ps, fg: C.p),
          chip(_statusText(status), bg: const Color(0xffe8f8ef), fg: C.green),
        ]),
        h('描述'),
        Text(description, style: const TextStyle(fontSize: 10.5, color: C.muted)),
        h('属性'),
        panel(
          Column(children: [
            _Prop(Icons.event_available_outlined, '计划', _formatTaskDate(task?.scheduledAt)),
            const Divider(height: 1),
            _Prop(Icons.flag_outlined, '截止', _formatTaskDate(task?.dueAt)),
            const Divider(height: 1),
            _Prop(Icons.priority_high_rounded, '优先级', _priorityText(priority)),
            const Divider(height: 1),
            _Prop(Icons.folder_outlined, '项目', task?.projectId ?? '未归属'),
            const Divider(height: 1),
            const _Prop(Icons.notifications_none_rounded, '提醒', '待 Calendar 阶段接入'),
          ]),
        ),
        if (task != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _edit(c, task),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('编辑任务'),
            ),
          ),
        ],
        h('子任务   1/3'),
        panel(
          Column(children: [
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: a,
              title: const Text('分析现有页面', style: TextStyle(fontSize: 11)),
              onChanged: (v) => setState(() => a = v ?? false),
            ),
            const Divider(height: 1),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: b,
              title: const Text('完成 UI Design', style: TextStyle(fontSize: 11)),
              onChanged: (v) => setState(() => b = v ?? false),
            ),
            const Divider(height: 1),
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: c2,
              title: const Text('Flutter 实现', style: TextStyle(fontSize: 11)),
              onChanged: (v) => setState(() => c2 = v ?? false),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => push(c, const Focus()),
            icon: const Icon(Icons.play_arrow_rounded, size: 17),
            label: const Text('开始专注'),
          ),
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
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

class _Prop extends StatelessWidget {
  const _Prop(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 15, color: C.muted),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: C.muted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 15, color: C.muted),
        ]),
      );
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
