part of 'main.dart';

class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key, this.weekStart});

  final String? weekStart;

  @override
  ConsumerState<WeeklyReviewScreen> createState() =>
      _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  final completionSummary = TextEditingController();
  final bestThing = TextEditingController();
  final problem = TextEditingController();
  final improvement = TextEditingController();
  final nextWeekPriority = TextEditingController();
  final note = TextEditingController();

  late String selectedWeekStart;
  String? _hydratedToken;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    selectedWeekStart =
        widget.weekStart ?? reviewWeekFor(DateTime.now()).startKey;
  }

  @override
  void dispose() {
    completionSummary.dispose();
    bestThing.dispose();
    problem.dispose();
    improvement.dispose();
    nextWeekPriority.dispose();
    note.dispose();
    super.dispose();
  }

  void _hydrate(WeeklyReview? review) {
    final token = review == null
        ? 'empty:$selectedWeekStart'
        : '${review.id}:${review.updatedAt}';
    if (_hydratedToken == token) return;
    _hydratedToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        completionSummary.text = review?.completionSummary ?? '';
        bestThing.text = review?.bestThing ?? '';
        problem.text = review?.problem ?? '';
        improvement.text = review?.improvement ?? '';
        nextWeekPriority.text = review?.nextWeekPriority ?? '';
        note.text = review?.note ?? '';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentWeek = ref.watch(currentReviewWeekProvider);
    final range = reviewWeekFromStartKey(selectedWeekStart);
    final reviewState =
        ref.watch(weeklyReviewForWeekProvider(selectedWeekStart));
    final review = reviewState.valueOrNull;
    _hydrate(review);

    final taskState = ref.watch(taskListProvider);
    final focusState = ref.watch(focusSessionListProvider);
    final tasks = taskState.valueOrNull ?? const <ExecutionTask>[];
    final focusSessions =
        focusState.valueOrNull ?? const <ExecutionFocusSession>[];
    final liveStats = calculateWeeklyReviewStats(
      tasks: tasks,
      focusSessions: focusSessions,
      weekStart: selectedWeekStart,
    );

    final useLiveStats =
        selectedWeekStart == currentWeek.startKey || review == null;
    final completed = useLiveStats
        ? liveStats.completed
        : review?.completedTaskCount ?? 0;
    final total =
        useLiveStats ? liveStats.total : review?.totalTaskCount ?? 0;
    final score = useLiveStats
        ? liveStats.completionScore
        : review?.completionScore;
    final focusSeconds =
        useLiveStats ? liveStats.focusSeconds : review?.focusSeconds ?? 0;
    final summarySuggestion = useLiveStats
        ? weeklyCompletionSummarySuggestion(liveStats)
        : review?.completionSummary;
    final nextSuggestion =
        useLiveStats ? liveStats.nextWeekSuggestion : review?.nextWeekPriority;

    final allConflicts =
        ref.watch(weeklyReviewConflictsProvider).valueOrNull ??
            const <WeeklyReviewConflictUi>[];
    final conflicts = allConflicts
        .where(
          (conflict) =>
              conflict.weekStart == null ||
              conflict.weekStart == selectedWeekStart,
        )
        .toList(growable: false);

    final canGoNext = range.start.isBefore(currentWeek.start);

    return DetailFrame(
      titleText: '周复盘',
      child: page([
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title('本周复盘'),
                const SizedBox(height: 2),
                sub(
                  review == null
                      ? '用真实任务与专注数据回顾这一周'
                      : '已保存，可继续编辑；历史统计保持保存时快照',
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => push(context, const WeeklyReviewHistory()),
            icon: const Icon(Icons.history_rounded, size: 15),
            label: const Text('历史'),
          ),
          if (review != null)
            chip('已保存', bg: C.greenSoft, fg: C.green),
        ]),
        const SizedBox(height: 10),
        panel(
          Row(children: [
            IconButton(
              tooltip: '上一周',
              onPressed: () => _moveWeek(-7),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _pickWeek(context, currentWeek),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(children: [
                    Text(
                      _weeklyReviewRangeLabel(range),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedWeekStart == currentWeek.startKey
                          ? '当前周'
                          : '点击选择任意日期定位到所在周',
                      style: const TextStyle(
                        fontSize: 8.5,
                        color: C.muted,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            IconButton(
              tooltip: '下一周',
              onPressed: canGoNext ? () => _moveWeek(7) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
        ),
        if (reviewState.hasError) ...[
          const SizedBox(height: 8),
          Text(
            '周复盘读取失败：${reviewState.error}',
            style: const TextStyle(fontSize: 9.5, color: C.red),
          ),
        ],
        if (conflicts.isNotEmpty) ...[
          h('同步冲突'),
          for (final conflict in conflicts)
            _WeeklyReviewConflictCard(conflict: conflict),
        ],
        h('本周数据'),
        Row(children: [
          Expanded(
            child: _WeeklyReviewStatCard(
              icon: Icons.check_circle_outline_rounded,
              label: '任务完成',
              value: '$completed / $total',
              color: C.green,
              background: C.greenSoft,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _WeeklyReviewStatCard(
              icon: Icons.analytics_outlined,
              label: '完成率',
              value: score == null ? '-' : '${(score * 100).round()}%',
              color: C.p,
              background: C.ps,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _WeeklyReviewStatCard(
              icon: Icons.timer_outlined,
              label: '专注',
              value: _focusDuration(focusSeconds),
              color: C.purple,
              background: C.purpleSoft,
            ),
          ),
        ]),
        if ((taskState.isLoading || focusState.isLoading) &&
            useLiveStats) ...[
          const SizedBox(height: 6),
          const Text(
            '正在读取本周任务与专注记录…',
            style: TextStyle(fontSize: 8.5, color: C.muted),
          ),
        ],
        h('本周完成摘要'),
        TextField(
          controller: completionSummary,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: summarySuggestion ?? '概括本周完成的关键事项',
            prefixIcon: const Icon(Icons.fact_check_outlined, size: 17),
          ),
        ),
        h('本周收获'),
        TextField(
          controller: bestThing,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '哪些做法、结果或经验值得保留？',
          ),
        ),
        h('问题'),
        TextField(
          controller: problem,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '本周最大的阻碍、偏差或问题是什么？',
          ),
        ),
        h('改进'),
        TextField(
          controller: improvement,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '下周准备怎样调整方法或节奏？',
          ),
        ),
        h('下周重点'),
        TextField(
          controller: nextWeekPriority,
          decoration: InputDecoration(
            hintText: nextSuggestion ?? '写下下周唯一最重要的事情',
            prefixIcon: const Icon(Icons.flag_outlined, size: 17),
          ),
        ),
        h('补充记录'),
        TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '可选：其他需要保留的周度记录',
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: saving
                ? null
                : () => _save(
                      context,
                      range: range,
                      completed: completed,
                      total: total,
                      score: score,
                      focusSeconds: focusSeconds,
                      summarySuggestion: summarySuggestion,
                      nextSuggestion: nextSuggestion,
                    ),
            child: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(review == null ? '保存周复盘' : '更新周复盘'),
          ),
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
    );
  }

  void _moveWeek(int days) {
    final current = reviewWeekFromStartKey(selectedWeekStart);
    final next = current.start.add(Duration(days: days));
    setState(() {
      selectedWeekStart = reviewWeekDateKey(next);
      _hydratedToken = null;
    });
  }

  Future<void> _pickWeek(
    BuildContext context,
    ReviewWeekRange currentWeek,
  ) async {
    final selected = reviewWeekFromStartKey(selectedWeekStart);
    final picked = await showDatePicker(
      context: context,
      initialDate: selected.start,
      firstDate: DateTime(2020, 1, 1),
      lastDate: currentWeek.end,
    );
    if (picked == null) return;
    final week = reviewWeekFor(picked);
    if (!mounted) return;
    setState(() {
      selectedWeekStart = week.startKey;
      _hydratedToken = null;
    });
  }

  Future<void> _save(
    BuildContext context, {
    required ReviewWeekRange range,
    required int completed,
    required int total,
    required double? score,
    required int focusSeconds,
    required String? summarySuggestion,
    required String? nextSuggestion,
  }) async {
    setState(() => saving = true);
    try {
      await ref.read(weeklyReviewCommandsProvider).save(
            weekStart: range.startKey,
            weekEnd: range.endKey,
            completedTaskCount: completed,
            totalTaskCount: total,
            focusSeconds: focusSeconds,
            completionScore: score,
            completionSummary: completionSummary.text.trim().isEmpty
                ? summarySuggestion
                : completionSummary.text,
            bestThing: bestThing.text,
            problem: problem.text,
            improvement: improvement.text,
            nextWeekPriority: nextWeekPriority.text.trim().isEmpty
                ? nextSuggestion
                : nextWeekPriority.text,
            note: note.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('周复盘已保存并加入同步队列')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }
}

class _WeeklyReviewConflictCard extends ConsumerWidget {
  const _WeeklyReviewConflictCard({required this.conflict});

  final WeeklyReviewConflictUi conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) => panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${conflict.weekStart ?? '未知周'} 的周复盘存在版本冲突',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              conflict.serverDeleted ? '云端版本已删除' : conflict.reason,
              style: const TextStyle(fontSize: 8.8, color: C.muted),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref
                      .read(weeklyReviewCommandsProvider)
                      .keepServer(conflict.conflictId),
                  child: const Text('保留云端'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => ref
                      .read(weeklyReviewCommandsProvider)
                      .keepLocal(conflict.conflictId),
                  child: const Text('保留本地'),
                ),
              ),
            ]),
          ],
        ),
        color: C.redSoft,
      );
}

class _WeeklyReviewStatCard extends StatelessWidget {
  const _WeeklyReviewStatCard({
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(fontSize: 8.2, color: C.muted),
            ),
          ],
        ),
      );
}

class WeeklyReviewHistory extends ConsumerWidget {
  const WeeklyReviewHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(weeklyReviewListProvider);
    return DetailFrame(
      titleText: '周复盘历史',
      child: state.when(
        loading: () => page([
          const SizedBox(height: 90),
          const Center(child: CircularProgressIndicator()),
        ]),
        error: (error, _) => page([
          h('读取失败'),
          panel(
            Text(
              '$error',
              style: const TextStyle(fontSize: 9.5, color: C.red),
            ),
          ),
        ]),
        data: (reviews) => page([
          Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '每周复盘记录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '历史 Task / Focus 统计使用保存时快照',
                    style: TextStyle(fontSize: 8.8, color: C.muted),
                  ),
                ],
              ),
            ),
            chip('${reviews.length} 周', bg: C.purpleSoft, fg: C.purple),
          ]),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            panel(
              const Column(children: [
                Icon(Icons.calendar_view_week_outlined, color: C.muted),
                SizedBox(height: 6),
                Text(
                  '还没有周复盘',
                  style: TextStyle(fontSize: 9.5, color: C.muted),
                ),
              ]),
              padding: const EdgeInsets.all(18),
            )
          else
            for (final review in reviews)
              _WeeklyReviewHistoryTile(
                review: review,
                onTap: () => push(
                  context,
                  WeeklyReviewHistoryDetail(review: review),
                ),
              ),
        ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
      ),
    );
  }
}

class _WeeklyReviewHistoryTile extends StatelessWidget {
  const _WeeklyReviewHistoryTile({
    required this.review,
    required this.onTap,
  });

  final WeeklyReview review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final range = reviewWeekFromStartKey(review.weekStart);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: C.border),
        ),
        child: Row(children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: C.purpleSoft,
            child: Icon(
              Icons.date_range_outlined,
              size: 17,
              color: C.purple,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _weeklyReviewRangeLabel(range),
                  style: const TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${review.completedTaskCount ?? 0} / '
                  '${review.totalTaskCount ?? 0} Tasks'
                  '${review.completionScore == null ? '' : ' · ${(review.completionScore! * 100).round()}%'}'
                  ' · 专注 ${_focusDuration(review.focusSeconds ?? 0)}',
                  style: const TextStyle(fontSize: 8.6, color: C.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 17, color: C.muted),
        ]),
      ),
    );
  }
}

class WeeklyReviewHistoryDetail extends ConsumerWidget {
  const WeeklyReviewHistoryDetail({
    super.key,
    required this.review,
  });

  final WeeklyReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = reviewWeekFromStartKey(review.weekStart);
    return DetailFrame(
      titleText: _weeklyReviewRangeLabel(range),
      child: page([
        Row(children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: C.purpleSoft,
            child: Icon(
              Icons.calendar_view_week_rounded,
              color: C.purple,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '周复盘',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                ),
                Text(
                  '保存时统计快照',
                  style: TextStyle(fontSize: 8.8, color: C.muted),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => push(
              context,
              WeeklyReviewScreen(weekStart: review.weekStart),
            ),
            icon: const Icon(Icons.edit_outlined, size: 15),
            label: const Text('编辑'),
          ),
        ]),
        h('本周数据'),
        Row(children: [
          Expanded(
            child: _WeeklyReviewStatCard(
              icon: Icons.check_circle_outline_rounded,
              label: '任务完成',
              value:
                  '${review.completedTaskCount ?? 0} / ${review.totalTaskCount ?? 0}',
              color: C.green,
              background: C.greenSoft,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _WeeklyReviewStatCard(
              icon: Icons.analytics_outlined,
              label: '完成率',
              value: review.completionScore == null
                  ? '-'
                  : '${(review.completionScore! * 100).round()}%',
              color: C.p,
              background: C.ps,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _WeeklyReviewStatCard(
              icon: Icons.timer_outlined,
              label: '专注',
              value: _focusDuration(review.focusSeconds ?? 0),
              color: C.purple,
              background: C.purpleSoft,
            ),
          ),
        ]),
        if ((review.completionSummary ?? '').isNotEmpty) ...[
          h('本周完成摘要'),
          panel(Text(review.completionSummary!)),
        ],
        if ((review.bestThing ?? '').isNotEmpty) ...[
          h('本周收获'),
          panel(Text(review.bestThing!)),
        ],
        if ((review.problem ?? '').isNotEmpty) ...[
          h('问题'),
          panel(Text(review.problem!)),
        ],
        if ((review.improvement ?? '').isNotEmpty) ...[
          h('改进'),
          panel(Text(review.improvement!)),
        ],
        if ((review.nextWeekPriority ?? '').isNotEmpty) ...[
          h('下周重点'),
          panel(
            Row(children: [
              const Icon(Icons.flag_outlined, size: 16, color: C.purple),
              const SizedBox(width: 8),
              Expanded(child: Text(review.nextWeekPriority!)),
            ]),
            color: C.purpleSoft,
          ),
        ],
        if ((review.note ?? '').isNotEmpty) ...[
          h('补充记录'),
          panel(Text(review.note!)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await ref.read(weeklyReviewCommandsProvider).delete(review);
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('删除这条周复盘'),
          ),
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
    );
  }
}

String _weeklyReviewRangeLabel(ReviewWeekRange range) =>
    '${range.start.month}月${range.start.day}日 - '
    '${range.end.month}月${range.end.day}日';
