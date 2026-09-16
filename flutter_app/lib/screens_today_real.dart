part of 'main.dart';

class _TodayRealHero extends StatelessWidget {
  const _TodayRealHero({
    required this.now,
    required this.userName,
    required this.snapshot,
    required this.focusStats,
    required this.onProfile,
  });

  final DateTime now;
  final String? userName;
  final TodaySnapshot snapshot;
  final FocusTodayStats focusStats;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final percent = (snapshot.completionRate * 100).round();
    final greeting = todayGreeting(now);
    final greetingText =
        userName == null || userName!.isEmpty ? greeting : '$greeting，$userName';
    final streakLabel = focusStats.streakDays > 0
        ? '连续 ${focusStats.streakDays} 天'
        : '专注 ${focusStats.completedRounds} 轮';

    return Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _todayDateText(now),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: C.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    greetingText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.4,
                    ),
                  ),
                  const Spacer(),
                  Row(children: [
                    _HeroTag(
                      Icons.bolt_rounded,
                      streakLabel,
                      C.orange,
                    ),
                    const SizedBox(width: 6),
                    _HeroTag(
                      Icons.check_rounded,
                      '${snapshot.completedActionCount} 已完成',
                      C.green,
                    ),
                  ]),
                ],
              ),
            ),
            InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(40),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 66,
                  height: 66,
                  child: Stack(fit: StackFit.expand, children: [
                    CircularProgressIndicator(
                      value: snapshot.completionRate,
                      strokeWidth: 5,
                      color: C.purple,
                      backgroundColor: Colors.white,
                    ),
                    const Center(
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person_rounded,
                          color: C.purple,
                          size: 25,
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(
                  '今日 $percent%',
                  style: const TextStyle(fontSize: 8.5, color: C.muted),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _TodayRealWeek extends StatelessWidget {
  const _TodayRealWeek({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final today = DateTime(now.year, now.month, now.day);
    final monday = startOfLocalWeek(today);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          final date = monday.add(Duration(days: index));
          final selected = isSameLocalDay(date, today);
          return SizedBox(
            width: 39,
            child: Column(children: [
              Text(
                weekdays[index],
                style: const TextStyle(fontSize: 8, color: C.muted),
              ),
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
                  date.day.toString(),
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
                  color: selected ? C.p : C.border,
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

class _TodayRealInlineStats extends StatelessWidget {
  const _TodayRealInlineStats({required this.snapshot});

  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: _MiniMetric(
            Icons.check_circle_outline_rounded,
            snapshot.pendingTasks.length.toString(),
            snapshot.overdueTaskCount > 0
                ? '待完成·${snapshot.overdueTaskCount}逾期'
                : '待完成',
            C.p,
            C.ps,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _MiniMetric(
            Icons.calendar_month_rounded,
            snapshot.calendarEventCount.toString(),
            '日程',
            C.orange,
            C.orangeSoft,
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: _MiniMetric(
            Icons.local_fire_department_outlined,
            '${snapshot.completedHabitCount}/${snapshot.habitDueCount}',
            '习惯',
            C.green,
            C.greenSoft,
          ),
        ),
      ]);
}

String _todayDateText(DateTime value) {
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  final local = value.toLocal();
  return '${local.month}月${local.day}日 · 星期${weekdays[local.weekday - 1]}';
}

String _todayTimelineTime(TodayTimelineEntry entry, DateTime now) {
  if (entry.allDay) return '全天';
  if (!isSameLocalDay(entry.start, now)) return '延续';
  final hh = entry.start.hour.toString().padLeft(2, '0');
  final mm = entry.start.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _todayTimelineMeta(TodayTimelineEntry entry) {
  final subtitle = entry.subtitle?.trim();
  if (subtitle != null && subtitle.isNotEmpty) return subtitle;
  return entry.kind == TodayTimelineKind.task ? '计划任务' : '日程';
}

Color _todayTimelineColor(TodayTimelineEntry entry) =>
    entry.kind == TodayTimelineKind.task ? C.purple : C.orange;

IconData _todayTimelineIcon(TodayTimelineEntry entry) =>
    entry.kind == TodayTimelineKind.task
        ? Icons.task_alt_rounded
        : Icons.event_rounded;

bool _todayTimelineActive(TodayTimelineEntry entry, DateTime now) {
  final task = entry.task;
  if (task != null) return task.status == ExecutionTaskStatus.inProgress;
  final end = entry.end;
  if (end == null) return false;
  final current = now.toLocal();
  return !current.isBefore(entry.start) && current.isBefore(end);
}

Future<void> _openTodayTimelineEntry(
  BuildContext context,
  WidgetRef ref,
  TodayTimelineEntry entry,
) async {
  final task = entry.task;
  if (task != null) {
    push(context, TaskDetail(task: task));
    return;
  }
  final event = entry.event;
  if (event == null) return;
  await _editCalendarEvent(
    context,
    ref,
    initialDate: entry.start,
    event: event,
  );
}

String _todayPendingMeta(TodayPendingTask entry) {
  final parts = <String>[];
  final project = entry.projectName?.trim();
  if (project != null && project.isNotEmpty) parts.add(project);
  if (entry.overdue) {
    parts.add('已逾期');
  } else {
    final scheduled = DateTime.tryParse(entry.task.scheduledAt ?? '')?.toLocal();
    final due = DateTime.tryParse(entry.task.dueAt ?? '')?.toLocal();
    final value = scheduled ?? due;
    if (value != null) {
      final hh = value.hour.toString().padLeft(2, '0');
      final mm = value.minute.toString().padLeft(2, '0');
      parts.add('$hh:$mm');
    } else if (entry.task.status == ExecutionTaskStatus.inProgress) {
      parts.add('进行中');
    }
  }
  parts.add(_priorityText(entry.task.priority));
  return parts.join(' · ');
}

Color _todayTaskColor(ExecutionTask task) => switch (task.priority) {
      ExecutionTaskPriority.urgent => C.red,
      ExecutionTaskPriority.high => C.orange,
      ExecutionTaskPriority.normal => C.sky,
      ExecutionTaskPriority.low => C.teal,
    };
