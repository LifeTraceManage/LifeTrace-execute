part of 'main.dart';

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
          tail: Text(
            loading ? '同步中' : '$completed/${entries.length}',
            style: const TextStyle(fontSize: 9, color: C.muted),
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
