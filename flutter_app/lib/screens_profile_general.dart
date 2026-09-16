part of 'main.dart';

class GeneralSettingsScreen extends ConsumerStatefulWidget {
  const GeneralSettingsScreen({super.key});

  @override
  ConsumerState<GeneralSettingsScreen> createState() =>
      _GeneralSettingsScreenState();
}

class _GeneralSettingsScreenState extends ConsumerState<GeneralSettingsScreen> {
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(focusTimerStateProvider);
    final timer = state.valueOrNull;

    return DetailFrame(
      titleText: '通用',
      child: page([
        Row(children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: C.tealSoft,
            child: Icon(Icons.settings_outlined, color: C.teal, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title('应用行为'),
                const SizedBox(height: 2),
                sub('复用现有持久化状态，不维护第二份重复配置'),
              ],
            ),
          ),
        ]),
        h('默认专注模式'),
        state.when(
          loading: () => panel(
            const Center(child: CircularProgressIndicator()),
          ),
          error: (value, _) => panel(
            Text(
              '专注设置读取失败：$value',
              style: const TextStyle(fontSize: 9.2, color: C.red),
            ),
          ),
          data: (value) {
            if (value == null) {
              return panel(
                const Text(
                  '连接 LifeTrace Cloud 后会创建当前用户的本地专注状态。',
                  style: TextStyle(fontSize: 9.2, color: C.muted),
                ),
              );
            }
            final editable = value.isIdle && !busy;
            return panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择 Focus 默认时长',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.isIdle
                        ? '该模式保存在真实 FocusTimerState 中，并会跨重置保留。'
                        : '当前计时正在进行，结束或重置后才能切换模式。',
                    style: const TextStyle(
                      fontSize: 8.6,
                      color: C.muted,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<FocusMode>(
                      segments: const [
                        ButtonSegment(
                          value: FocusMode.short,
                          label: Text('25 / 5'),
                          icon: Icon(Icons.timer_outlined, size: 15),
                        ),
                        ButtonSegment(
                          value: FocusMode.long,
                          label: Text('50 / 10'),
                          icon: Icon(Icons.hourglass_bottom_rounded, size: 15),
                        ),
                      ],
                      selected: {value.mode},
                      onSelectionChanged: editable
                          ? (values) => _setMode(values.single)
                          : null,
                    ),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(11),
            );
          },
        ),
        h('数据与同步行为'),
        panel(
          const Column(
            children: [
              _InfoRow('数据模式', 'Local-first'),
              Divider(height: 1),
              _InfoRow('写入顺序', '本地 Entity + Outbox'),
              Divider(height: 1),
              _InfoRow('同步协议', 'Snapshot → Push → Pull'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        panel(
          const Text(
            '核心数据与同步策略属于 LifeTrace Execute 的一致性约束，不作为普通开关暴露，避免关闭后破坏 Local-first / multi-device 语义。',
            style: TextStyle(fontSize: 8.8, color: C.muted, height: 1.45),
          ),
          padding: EdgeInsets.all(10),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(
            error!,
            style: const TextStyle(fontSize: 9, color: C.red),
          ),
        ],
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }

  Future<void> _setMode(FocusMode mode) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(focusCommandsProvider).setMode(mode);
    } catch (value) {
      if (mounted) setState(() => error = value.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
