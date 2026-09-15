part of 'main.dart';

class Habits extends ConsumerWidget {
  const Habits({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitActivityListProvider);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: const Text('习惯'),
        backgroundColor: C.bg,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: C.p,
        foregroundColor: Colors.white,
        onPressed: () => unawaited(_editHabit(context, ref)),
        child: const Icon(Icons.add_rounded),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => page([
          h('习惯数据加载失败'),
          panel(
            Text(
              '$error',
              style: const TextStyle(fontSize: 10, color: C.red),
            ),
          ),
        ]),
        data: (activities) {
          final active = activities
              .where((activity) => !activity.isArchived)
              .toList(growable: false);
          final archived = activities
              .where((activity) => activity.isArchived)
              .toList(growable: false);
          return page([
            panel(
              Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: C.greenSoft,
                    child: Icon(
                      Icons.track_changes_rounded,
                      size: 18,
                      color: C.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      active.isEmpty
                          ? '创建第一个可持续追踪的习惯'
                          : '正在追踪 ${active.length} 个习惯',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            h('进行中 · ${active.length}'),
            if (active.isEmpty)
              panel(
                const Text(
                  '暂无进行中的习惯。点击右下角 + 创建。',
                  style: TextStyle(fontSize: 9.5, color: C.muted),
                ),
              )
            else
              for (final activity in active)
                _HabitManageTile(
                  activity: activity,
                  onEdit: () => unawaited(
                    _editHabit(context, ref, activity: activity),
                  ),
                  onArchive: () => unawaited(
                    _setHabitArchived(
                      context,
                      ref,
                      activity,
                      archived: true,
                    ),
                  ),
                ),
            if (archived.isNotEmpty) ...[
              h('已归档 · ${archived.length}'),
              for (final activity in archived)
                _HabitManageTile(
                  activity: activity,
                  onEdit: () => unawaited(
                    _editHabit(context, ref, activity: activity),
                  ),
                  onArchive: () => unawaited(
                    _setHabitArchived(
                      context,
                      ref,
                      activity,
                      archived: false,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 70),
          ]);
        },
      ),
    );
  }
}

class _HabitManageTile extends StatelessWidget {
  const _HabitManageTile({
    required this.activity,
    required this.onEdit,
    required this.onArchive,
  });

  final HabitActivity activity;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final target = activity.normalTarget;
    final targetText = target == null
        ? '仅打卡'
        : '${target == target.roundToDouble() ? target.toInt() : target} '
            '${activity.unit}';
    final schedule = activity.targetDays.isEmpty
        ? '每天'
        : activity.targetDays.map(_weekdayShort).join(' · ');

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor:
                  activity.isArchived ? C.soft : C.greenSoft,
              child: Icon(
                activity.isArchived
                    ? Icons.inventory_2_outlined
                    : Icons.repeat_rounded,
                size: 16,
                color: activity.isArchived ? C.muted : C.green,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.name,
                    style: const TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$targetText · $schedule',
                    style: const TextStyle(fontSize: 8.6, color: C.muted),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: '习惯操作',
              onSelected: (value) {
                if (value == 'edit') {
                  onEdit();
                } else {
                  onArchive();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('编辑'),
                ),
                PopupMenuItem(
                  value: activity.isArchived ? 'restore' : 'archive',
                  child: Text(activity.isArchived ? '恢复' : '归档'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _setHabitArchived(
  BuildContext context,
  WidgetRef ref,
  HabitActivity activity, {
  required bool archived,
}) async {
  try {
    await ref
        .read(habitCommandsProvider)
        .setArchived(activity, archived: archived);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('更新习惯失败：$error')),
    );
  }
}

Future<void> _editHabit(
  BuildContext context,
  WidgetRef ref, {
  HabitActivity? activity,
}) async {
  final name = TextEditingController(text: activity?.name ?? '');
  final unit = TextEditingController(
    text: activity?.unit ??
        (activity?.activityType == HabitWireValues.activityDuration
            ? '分钟'
            : '次'),
  );
  final target = TextEditingController(
    text: activity?.normalTarget == null
        ? ''
        : _formatHabitNumber(activity!.normalTarget!),
  );
  final description =
      TextEditingController(text: activity?.description ?? '');
  var type = activity?.activityType ?? HabitWireValues.activityCompletion;
  var targetDays = <int>{...?activity?.targetDays};
  var saving = false;

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> save() async {
            if (saving) return;
            final cleanName = name.text.trim();
            final cleanUnit = unit.text.trim();
            if (cleanName.isEmpty || cleanUnit.isEmpty) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: Text('名称和单位不能为空')),
              );
              return;
            }
            final targetText = target.text.trim();
            final normalTarget =
                targetText.isEmpty ? null : double.tryParse(targetText);
            if (targetText.isNotEmpty &&
                (normalTarget == null ||
                    !normalTarget.isFinite ||
                    normalTarget < 0)) {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                const SnackBar(content: Text('目标值必须是非负数字')),
              );
              return;
            }

            setSheetState(() => saving = true);
            try {
              final commands = ref.read(habitCommandsProvider);
              if (activity == null) {
                await commands.createActivity(
                  name: cleanName,
                  activityType: type,
                  unit: cleanUnit,
                  normalTarget: normalTarget,
                  targetDays: targetDays.toList()..sort(),
                  description: description.text,
                );
              } else {
                await commands.updateActivity(
                  activity: activity,
                  name: cleanName,
                  activityType: type,
                  unit: cleanUnit,
                  normalTarget: normalTarget,
                  targetDays: targetDays.toList()..sort(),
                  description: description.text,
                );
              }
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            } catch (error) {
              if (!sheetContext.mounted) return;
              setSheetState(() => saving = false);
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(content: Text('保存习惯失败：$error')),
              );
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                14,
                16,
                16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity == null ? '新建习惯' : '编辑习惯',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: name,
                      autofocus: activity == null,
                      decoration: const InputDecoration(labelText: '名称'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: '类型'),
                      items: const [
                        DropdownMenuItem(
                          value: HabitWireValues.activityCompletion,
                          child: Text('完成型'),
                        ),
                        DropdownMenuItem(
                          value: HabitWireValues.activityDuration,
                          child: Text('时长型'),
                        ),
                        DropdownMenuItem(
                          value: HabitWireValues.activityCount,
                          child: Text('计数型'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) => setSheetState(() {
                                type = value ?? type;
                                if (type ==
                                        HabitWireValues.activityCompletion &&
                                    unit.text.trim().isEmpty) {
                                  unit.text = '次';
                                }
                              }),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: target,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '目标值（可选）',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: unit,
                            decoration:
                                const InputDecoration(labelText: '单位'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    const Text(
                      '执行日（不选择表示每天）',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: List.generate(7, (index) {
                        final day = index + 1;
                        return FilterChip(
                          label: Text(_weekdayShort(day)),
                          selected: targetDays.contains(day),
                          onSelected: saving
                              ? null
                              : (selected) => setSheetState(() {
                                    if (selected) {
                                      targetDays.add(day);
                                    } else {
                                      targetDays.remove(day);
                                    }
                                  }),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: '说明（可选）'),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving ? null : save,
                        child: Text(saving ? '保存中...' : '保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  } finally {
    name.dispose();
    unit.dispose();
    target.dispose();
    description.dispose();
  }
}

String _weekdayShort(int weekday) => switch (weekday) {
      DateTime.monday => '一',
      DateTime.tuesday => '二',
      DateTime.wednesday => '三',
      DateTime.thursday => '四',
      DateTime.friday => '五',
      DateTime.saturday => '六',
      DateTime.sunday => '日',
      _ => '?',
    };

String _formatHabitNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

class _TodayHabitsSection extends ConsumerWidget {
  const _TodayHabitsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityState = ref.watch(habitActivityListProvider);
    final conflictState = ref.watch(habitConflictsProvider);
    final logState = ref.watch(todayHabitLogListProvider);
    final entries = buildTodayHabitEntries(
      activities: activityState.valueOrNull ?? const [],
      logs: logState.valueOrNull ?? const [],
      date: DateTime.now(),
    );
    final completed = entries.where((entry) => entry.completed).length;
    final loading = activityState.isLoading || logState.isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        h(
          '今日习惯',
          tail: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loading ? '同步中' : '$completed/${entries.length}',
                style: const TextStyle(fontSize: 9, color: C.muted),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => push(context, const Habits()),
                child: const Text(
                  '管理',
                  style: TextStyle(
                    fontSize: 9,
                    color: C.p,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        if ((conflictState.valueOrNull ?? const <HabitConflictUi>[]).isNotEmpty) ...[
          for (final conflict
              in conflictState.valueOrNull ?? const <HabitConflictUi>[])
            _TodayHabitConflictTile(conflict: conflict),
          const SizedBox(height: 5),
        ],
        if (loading)
          panel(const Center(child: CircularProgressIndicator()))
        else if (activityState.hasError || logState.hasError)
          panel(
            const Text(
              '习惯数据暂时无法读取，本地数据不会丢失。',
              style: TextStyle(fontSize: 9.2, color: C.red),
            ),
          )
        else if (entries.isEmpty)
          panel(
            const Text(
              '今天没有需要打卡的习惯。',
              style: TextStyle(fontSize: 9.2, color: C.muted),
            ),
          )
        else
          for (final entry in entries)
            _TodayHabitTile(
              entry: entry,
              onToggle: () => unawaited(
                _toggleTodayHabit(context, ref, entry),
              ),
            ),
      ],
    );
  }
}

Future<void> _toggleTodayHabit(
  BuildContext context,
  WidgetRef ref,
  TodayHabitEntry entry,
) async {
  try {
    await ref.read(habitCommandsProvider).toggleToday(entry);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('习惯打卡失败：$error')),
    );
  }
}

class _TodayHabitConflictTile extends ConsumerWidget {
  const _TodayHabitConflictTile({required this.conflict});

  final HabitConflictUi conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLog = conflict.entityType == DriftHabitRepository.logEntityType;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: C.redSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.red.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isLog ? '习惯打卡存在同步冲突' : '习惯定义存在同步冲突',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: C.red,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            conflict.serverDeleted
                ? '云端已删除 · ${conflict.reason}'
                : conflict.reason,
            style: const TextStyle(fontSize: 8.5, color: C.muted),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => unawaited(
                  _resolveHabitConflict(
                    context,
                    ref,
                    conflict.conflictId,
                    keepLocal: false,
                  ),
                ),
                child: const Text('保留云端'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => unawaited(
                  _resolveHabitConflict(
                    context,
                    ref,
                    conflict.conflictId,
                    keepLocal: true,
                  ),
                ),
                child: const Text('保留本地'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _resolveHabitConflict(
  BuildContext context,
  WidgetRef ref,
  String conflictId, {
  required bool keepLocal,
}) async {
  try {
    final commands = ref.read(habitCommandsProvider);
    if (keepLocal) {
      await commands.keepLocal(conflictId);
    } else {
      await commands.keepServer(conflictId);
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('处理习惯同步冲突失败：$error')),
    );
  }
}

class _TodayHabitTile extends StatelessWidget {
  const _TodayHabitTile({
    required this.entry,
    required this.onToggle,
  });

  final TodayHabitEntry entry;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final activity = entry.activity;
    final target = activity.normalTarget ?? activity.minimumTarget;
    final targetText = target == null
        ? activity.targetPeriod
        : '${target == target.roundToDouble() ? target.toInt() : target} '
            '${activity.unit}';
    final subtitle = entry.completed
        ? '已完成 · $targetText'
        : entry.log == null
            ? '目标 · $targetText'
            : '进行中 · ${entry.value ?? 0} ${activity.unit}';

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: entry.completed ? C.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: entry.completed
                ? C.green.withValues(alpha: .22)
                : C.border,
          ),
        ),
        child: Row(children: [
          Icon(
            entry.completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 21,
            color: entry.completed ? C.green : C.muted,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  style: TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                    decoration:
                        entry.completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 8.5, color: C.muted),
                ),
              ],
            ),
          ),
          Text(
            entry.completed ? '撤销' : '完成',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: entry.completed ? C.green : C.p,
            ),
          ),
        ]),
      ),
    );
  }
}
