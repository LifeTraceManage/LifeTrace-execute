part of 'main.dart';

class Today extends StatelessWidget {
  const Today({super.key});

  @override
  Widget build(BuildContext c) => page([
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              sub('9月9日 · 星期三'),
              const SizedBox(height: 3),
              title('晚上好，Alex'),
            ]),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => push(c, const Profile()),
            child: const CircleAvatar(
              radius: 19,
              backgroundColor: C.ps,
              child: Icon(Icons.person, color: C.p, size: 20),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        const _Week(),
        const SizedBox(height: 11),
        panel(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'TODAY FOCUS',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: C.p),
            ),
            const SizedBox(height: 8),
            const Row(children: [
              Icon(Icons.favorite_rounded, size: 14, color: C.red),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  '完成论文实验设计',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ]),
            const Padding(
              padding: EdgeInsets.only(left: 21, top: 3),
              child: Text('♙ Academic Research', style: TextStyle(fontSize: 9.5, color: C.muted)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 21, top: 3),
              child: Text('今天 23:00  ·  高优先级', style: TextStyle(fontSize: 9.5, color: C.muted)),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => push(c, const Focus()),
                icon: const Icon(Icons.play_arrow_rounded, size: 17),
                label: const Text('开始专注', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
          color: C.ps,
        ),
        h('今天'),
        const _InlineStats(),
        h('现在'),
        _TimeItem('19:00', '健身', '胸 + 三头', active: true, tap: () => push(c, const TaskDetail())),
        h('接下来'),
        _TimeItem('21:00', '修改实验代码', '', tap: () => push(c, const TaskDetail())),
        _TimeItem('22:30', '英语学习', '', tap: () => push(c, const TaskDetail())),
        h('任务', tail: const Text('2项', style: TextStyle(fontSize: 9, color: C.muted))),
        _TaskLine('修复 MPC 仿真', 'Academic · 今天', tap: () => push(c, const TaskDetail())),
        _TaskLine('完成周报', '工作 · 明天', tap: () => push(c, const TaskDetail())),
      ]);
}

class _Week extends StatelessWidget {
  const _Week();

  @override
  Widget build(BuildContext c) {
    const ds = ['7', '8', '9', '10', '11', '12', '13'];
    const ws = ['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final selected = i == 2;
        return SizedBox(
          width: 37,
          child: Column(children: [
            Text(ws[i], style: const TextStyle(fontSize: 8, color: C.muted)),
            const SizedBox(height: 4),
            Container(
              width: 29,
              height: 29,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? C.p : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                ds[i],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : C.ink,
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }
}

class _InlineStats extends StatelessWidget {
  const _InlineStats();

  @override
  Widget build(BuildContext c) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Text('5', style: TextStyle(color: C.p, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(' 待完成  ·  ', style: TextStyle(fontSize: 10, color: C.muted)),
          Text('2', style: TextStyle(color: C.p, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(' 日程  ·  ', style: TextStyle(fontSize: 10, color: C.muted)),
          Text('1', style: TextStyle(color: C.p, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(' 习惯', style: TextStyle(fontSize: 10, color: C.muted)),
        ]),
      );
}

class _TimeItem extends StatelessWidget {
  const _TimeItem(this.time, this.name, this.meta, {this.active = false, this.tap});

  final String time;
  final String name;
  final String meta;
  final bool active;
  final VoidCallback? tap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 45, child: Text(time, style: const TextStyle(fontSize: 10, color: C.muted))),
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? C.p : Colors.white,
                border: Border.all(color: active ? C.p : C.muted),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                if (meta.isNotEmpty) Text(meta, style: const TextStyle(fontSize: 9.5, color: C.muted)),
              ]),
            ),
            if (active) chip('进行中', bg: const Color(0xffe8f8ef), fg: C.green),
          ]),
        ),
      );
}

class _TaskLine extends StatelessWidget {
  const _TaskLine(this.name, this.meta, {this.tap});

  final String name;
  final String meta;
  final VoidCallback? tap;

  @override
  Widget build(BuildContext c) => InkWell(
        onTap: tap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            const Icon(Icons.circle_outlined, size: 17, color: C.muted),
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                Text(meta, style: const TextStyle(fontSize: 9.5, color: C.muted)),
              ]),
            ),
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
    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: C.p,
        foregroundColor: Colors.white,
        onPressed: () => _composer(c),
        child: const Icon(Icons.add),
      ),
      body: tasks.when(
        loading: () => page([
          _header(),
          const SizedBox(height: 80),
          const Center(child: CircularProgressIndicator()),
        ]),
        error: (error, stack) => page([
          _header(),
          h('任务数据加载失败'),
          panel(Text('$error', style: const TextStyle(fontSize: 10.5, color: C.red))),
        ]),
        data: (allTasks) {
          final visible = allTasks.where(_matches).toList(growable: false);
          return page([
            _header(),
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

  Widget _header() => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            title('任务'),
            sub('Local-first · 修改会先保存到本机'),
          ]),
        ),
        const Icon(Icons.cloud_done_outlined, size: 18, color: C.green),
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
              value: priority,
              decoration: const InputDecoration(labelText: '优先级'),
              items: ExecutionTaskPriority.values
                  .map((item) => DropdownMenuItem(value: item, child: Text(_priorityText(item))))
                  .toList(),
              onChanged: (value) {
                if (value != null) setSheetState(() => priority = value);
              },
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
    );

    titleController.dispose();
    descriptionController.dispose();
  }
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
            _Prop(Icons.schedule_rounded, '时间', task?.scheduledAt ?? task?.dueAt ?? '未设置'),
            const Divider(height: 1),
            _Prop(Icons.priority_high_rounded, '优先级', _priorityText(priority)),
            const Divider(height: 1),
            _Prop(Icons.folder_outlined, '项目', task?.projectId ?? '未归属'),
            const Divider(height: 1),
            const _Prop(Icons.notifications_none_rounded, '提醒', '待 M4 接入'),
            const Divider(height: 1),
            const _Prop(Icons.repeat_rounded, '重复', '待 M4 接入'),
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

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + MediaQuery.of(sheetContext).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: '标题')),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '描述'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ExecutionTaskPriority>(
              value: priority,
              decoration: const InputDecoration(labelText: '优先级'),
              items: ExecutionTaskPriority.values
                  .map((item) => DropdownMenuItem(value: item, child: Text(_priorityText(item))))
                  .toList(),
              onChanged: (value) {
                if (value != null) setSheetState(() => priority = value);
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final updated = await ref.read(taskCommandsProvider).update(
                        task: task,
                        title: titleController.text,
                        description: descriptionController.text,
                        priority: priority,
                      );
                  if (mounted) setState(() => current = updated);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
                child: const Text('保存修改'),
              ),
            ),
          ]),
        ),
      ),
    );

    titleController.dispose();
    descriptionController.dispose();
  }
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
  if (task.scheduledAt != null) parts.add(task.scheduledAt!);
  if (task.dueAt != null) parts.add('截止 ${task.dueAt}');
  if (task.status == ExecutionTaskStatus.waiting) parts.add('等待中');
  if (parts.isEmpty) parts.add('本地任务');
  return parts.join(' · ');
}
