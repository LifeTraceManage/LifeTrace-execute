part of 'main.dart';

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsState = ref.watch(goalListProvider);
    final projects =
        ref.watch(projectListProvider).valueOrNull ?? const <ExecutionProject>[];
    final tasks =
        ref.watch(taskListProvider).valueOrNull ?? const <ExecutionTask>[];
    final conflicts =
        ref.watch(goalConflictsProvider).valueOrNull ?? const <GoalConflictUi>[];

    return DetailFrame(
      titleText: '目标',
      actions: [
        IconButton(
          tooltip: '新建目标',
          onPressed: () => _editGoal(context, ref),
          icon: const Icon(Icons.add_rounded, size: 20),
        ),
      ],
      child: page([
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title('长期目标'),
                sub('Goal → Project → Task · 进度由真实项目与任务推导'),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _editGoal(context, ref),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('新建'),
          ),
        ]),
        const SizedBox(height: 12),
        goalsState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => panel(
            Text(
              '目标加载失败：$error',
              style: const TextStyle(fontSize: 9.5, color: C.red),
            ),
            padding: const EdgeInsets.all(12),
          ),
          data: (goals) {
            if (goals.isEmpty) {
              return panel(
                Column(children: [
                  const Icon(Icons.track_changes_rounded, color: C.muted),
                  const SizedBox(height: 7),
                  const Text(
                    '还没有目标',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '目标本身不保存虚假进度，进度由其项目和任务实时计算。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 8.8, color: C.muted),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _editGoal(context, ref),
                    icon: const Icon(Icons.add_rounded, size: 15),
                    label: const Text('创建第一个目标'),
                  ),
                ]),
                padding:
                    const EdgeInsets.symmetric(vertical: 22, horizontal: 14),
              );
            }

            final ordered = [...goals]
              ..sort((a, b) {
                final statusOrder =
                    _goalStatusOrder(a.status).compareTo(_goalStatusOrder(b.status));
                if (statusOrder != 0) return statusOrder;
                final sortOrder = a.sortOrder.compareTo(b.sortOrder);
                if (sortOrder != 0) return sortOrder;
                return b.updatedAt.compareTo(a.updatedAt);
              });

            return Column(children: [
              for (var i = 0; i < ordered.length; i++) ...[
                _GoalCard(
                  goal: ordered[i],
                  progress: goalProjectProgress(
                    ordered[i].id,
                    projects,
                    tasks,
                  ),
                  conflict: _findGoalConflict(conflicts, ordered[i].id),
                  onEdit: () => _editGoal(context, ref, goal: ordered[i]),
                  onDelete: () => _deleteGoal(context, ref, ordered[i]),
                  onKeepServer: (conflictId) => ref
                      .read(goalCommandsProvider)
                      .keepServer(conflictId),
                  onKeepLocal: (conflictId) => ref
                      .read(goalCommandsProvider)
                      .keepLocal(conflictId),
                ),
                if (i != ordered.length - 1) const SizedBox(height: 9),
              ],
            ]);
          },
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.conflict,
    required this.onEdit,
    required this.onDelete,
    required this.onKeepServer,
    required this.onKeepLocal,
  });

  final ExecutionGoal goal;
  final GoalProgress progress;
  final GoalConflictUi? conflict;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Future<void> Function(String conflictId) onKeepServer;
  final Future<void> Function(String conflictId) onKeepLocal;

  @override
  Widget build(BuildContext context) {
    final color = _goalStatusColor(goal.status);
    final conflictValue = conflict;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.track_changes_rounded, size: 20, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    goal.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (goal.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      goal.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 8.8, color: C.muted),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz_rounded, size: 18),
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('编辑目标')),
                PopupMenuItem(value: 'delete', child: Text('删除目标')),
              ],
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            chip(
              _goalStatusText(goal.status),
              bg: color.withValues(alpha: .10),
              fg: color,
            ),
            const SizedBox(width: 6),
            chip(
              goal.targetAt == null
                  ? '未设置目标日期'
                  : '目标 ${_projectDate(goal.targetAt)}',
              bg: C.soft,
              fg: C.muted,
            ),
            const Spacer(),
            Text(
              '${progress.rate}%',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.rate / 100,
              minHeight: 6,
              color: color,
              backgroundColor: C.soft,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${progress.completedProjects}/${progress.projects} 项目完成 · '
                '${progress.completedTasks}/${progress.tasks} 任务完成',
            style: const TextStyle(fontSize: 8.6, color: C.muted),
          ),
          if (conflictValue != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: C.redSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '同步冲突',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: C.red,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    conflictValue.serverDeleted
                        ? '云端版本已删除'
                        : '本地「${conflictValue.localName ?? goal.name}」与云端'
                            '「${conflictValue.serverName ?? '目标'}」发生冲突',
                    style: const TextStyle(fontSize: 8.5, color: C.muted),
                  ),
                  const SizedBox(height: 7),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            onKeepServer(conflictValue.conflictId),
                        child: const Text('保留云端'),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: FilledButton(
                        onPressed: () =>
                            onKeepLocal(conflictValue.conflictId),
                        child: const Text('保留本地'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ],
      ),
      padding: const EdgeInsets.all(12),
      onTap: onEdit,
    );
  }
}

class _TodayGoalsSection extends ConsumerWidget {
  const _TodayGoalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsState = ref.watch(goalListProvider);
    final projects =
        ref.watch(projectListProvider).valueOrNull ?? const <ExecutionProject>[];
    final tasks =
        ref.watch(taskListProvider).valueOrNull ?? const <ExecutionTask>[];

    final goals = (goalsState.valueOrNull ?? const <ExecutionGoal>[])
        .where(
          (goal) =>
              goal.status == ExecutionGoalStatus.active ||
              goal.status == ExecutionGoalStatus.paused,
        )
        .take(3)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        h(
          '目标进度',
          tail: TextButton(
            onPressed: () => push(context, const GoalsScreen()),
            child: Text(goals.isEmpty ? '管理' : '查看全部'),
          ),
        ),
        if (goalsState.isLoading)
          panel(const Center(child: CircularProgressIndicator()))
        else if (goalsState.hasError)
          panel(
            Text(
              '目标读取失败：${goalsState.error}',
              style: const TextStyle(fontSize: 9, color: C.red),
            ),
          )
        else if (goals.isEmpty)
          panel(
            Row(children: [
              const Icon(
                Icons.track_changes_outlined,
                size: 17,
                color: C.muted,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '还没有进行中的目标。',
                  style: TextStyle(fontSize: 9.2, color: C.muted),
                ),
              ),
              TextButton(
                onPressed: () => push(context, const GoalsScreen()),
                child: const Text('创建'),
              ),
            ]),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          )
        else
          for (final goal in goals)
            _TodayGoalTile(
              goal: goal,
              progress: goalProjectProgress(goal.id, projects, tasks),
              onTap: () => push(context, const GoalsScreen()),
            ),
      ],
    );
  }
}

class _TodayGoalTile extends StatelessWidget {
  const _TodayGoalTile({
    required this.goal,
    required this.progress,
    required this.onTap,
  });

  final ExecutionGoal goal;
  final GoalProgress progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _goalStatusColor(goal.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white,
            child: Icon(Icons.track_changes_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress.rate / 100,
                    minHeight: 4,
                    color: color,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${progress.projects} 项目 · '
                      '${progress.completedTasks}/${progress.tasks} 任务',
                  style: const TextStyle(fontSize: 8.2, color: C.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            '${progress.rate}%',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ]),
      ),
    );
  }
}

Future<void> _editGoal(
  BuildContext context,
  WidgetRef ref, {
  ExecutionGoal? goal,
}) async {
  final nameController = TextEditingController(text: goal?.name ?? '');
  final descriptionController =
      TextEditingController(text: goal?.description ?? '');
  var status = goal?.status ?? ExecutionGoalStatus.active;
  DateTime? targetAt = DateTime.tryParse(goal?.targetAt ?? '')?.toLocal();

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
            TextField(
              controller: nameController,
              autofocus: goal == null,
              decoration: const InputDecoration(labelText: '目标名称'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '描述'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ExecutionGoalStatus>(
              initialValue: status,
              decoration: const InputDecoration(labelText: '状态'),
              items: ExecutionGoalStatus.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(_goalStatusText(item)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setSheetState(() => status = value);
              },
            ),
            const SizedBox(height: 10),
            _DateField(
              label: '目标日期',
              value: targetAt,
              onPick: () async {
                final value = await _pickDateTime(sheetContext, targetAt);
                if (value != null) setSheetState(() => targetAt = value);
              },
              onClear: targetAt == null
                  ? null
                  : () => setSheetState(() => targetAt = null),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  try {
                    final commands = ref.read(goalCommandsProvider);
                    if (goal == null) {
                      final created = await commands.create(
                        name: nameController.text,
                        description: descriptionController.text,
                        targetAt: targetAt?.toUtc().toIso8601String(),
                      );
                      if (status != ExecutionGoalStatus.active) {
                        await commands.update(
                          goal: created,
                          status: status,
                        );
                      }
                    } else {
                      await commands.update(
                        goal: goal,
                        name: nameController.text,
                        description: descriptionController.text,
                        status: status,
                        targetAt: targetAt?.toUtc().toIso8601String(),
                        clearDescription:
                            descriptionController.text.trim().isEmpty,
                        clearTargetAt:
                            targetAt == null && goal.targetAt != null,
                      );
                    }
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  } catch (error) {
                    if (sheetContext.mounted) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text(error.toString())),
                      );
                    }
                  }
                },
                child: Text(goal == null ? '创建目标' : '保存目标'),
              ),
            ),
          ]),
        ),
      ),
    ),
  );

  nameController.dispose();
  descriptionController.dispose();
}

Future<void> _deleteGoal(
  BuildContext context,
  WidgetRef ref,
  ExecutionGoal goal,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除目标'),
      content: const Text(
        '目标会删除，关联项目会保留并自动解除目标归属；这些变化都会进入同步队列。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  try {
    await ref.read(goalCommandsProvider).delete(goal);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

ExecutionGoal? _findGoal(List<ExecutionGoal> goals, String? goalId) {
  if (goalId == null) return null;
  for (final goal in goals) {
    if (goal.id == goalId) return goal;
  }
  return null;
}

GoalConflictUi? _findGoalConflict(
  List<GoalConflictUi> conflicts,
  String goalId,
) {
  for (final conflict in conflicts) {
    if (conflict.goalId == goalId) return conflict;
  }
  return null;
}

int _goalStatusOrder(ExecutionGoalStatus status) => switch (status) {
      ExecutionGoalStatus.active => 0,
      ExecutionGoalStatus.paused => 1,
      ExecutionGoalStatus.completed => 2,
      ExecutionGoalStatus.cancelled => 3,
    };

String _goalStatusText(ExecutionGoalStatus status) => switch (status) {
      ExecutionGoalStatus.active => '进行中',
      ExecutionGoalStatus.paused => '已暂停',
      ExecutionGoalStatus.completed => '已完成',
      ExecutionGoalStatus.cancelled => '已取消',
    };

Color _goalStatusColor(ExecutionGoalStatus status) => switch (status) {
      ExecutionGoalStatus.active => C.p,
      ExecutionGoalStatus.paused => C.orange,
      ExecutionGoalStatus.completed => C.green,
      ExecutionGoalStatus.cancelled => C.muted,
    };
