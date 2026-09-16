part of 'main.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final preferencesState = ref.watch(notificationPreferencesProvider);

    return DetailFrame(
      titleText: '通知',
      child: page([
        Row(children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: C.orangeSoft,
            child: Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: C.orange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title('设备通知'),
                const SizedBox(height: 2),
                sub('当前设备本地偏好 · 不改变 Cloud 业务数据'),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        preferencesState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (value, _) => panel(
            Text(
              '通知偏好读取失败：$value',
              style: const TextStyle(fontSize: 9.2, color: C.red),
            ),
          ),
          data: (preferences) => Column(children: [
            panel(
              Column(children: [
                _NotificationPreferenceRow(
                  icon: Icons.alarm_rounded,
                  title: '任务与日历提醒',
                  description: '控制 execution.reminder 在本机的系统通知排程',
                  value: preferences.remindersEnabled,
                  enabled: !busy,
                  onChanged: (value) => _setReminders(value),
                ),
                const Divider(height: 1),
                _NotificationPreferenceRow(
                  icon: Icons.timer_outlined,
                  title: '专注阶段提醒',
                  description: '控制番茄钟专注完成与休息结束通知',
                  value: preferences.focusEnabled,
                  enabled: !busy,
                  onChanged: (value) => _setFocus(value),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            panel(
              const Text(
                '关闭通知只会取消本机已经排程的系统通知。Reminder、FocusSession 和计时状态仍保留在 Local-first 数据层，并继续按原规则同步。',
                style: TextStyle(
                  fontSize: 8.8,
                  color: C.muted,
                  height: 1.45,
                ),
              ),
              padding: const EdgeInsets.all(10),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _requestPermission,
                icon: const Icon(Icons.security_rounded, size: 16),
                label: const Text('重新请求系统通知权限'),
              ),
            ),
          ]),
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

  Future<void> _setReminders(bool value) async {
    await _run(
      () => ref
          .read(notificationSettingsCommandsProvider)
          .setRemindersEnabled(value),
    );
  }

  Future<void> _setFocus(bool value) async {
    await _run(
      () => ref.read(notificationSettingsCommandsProvider).setFocusEnabled(value),
    );
  }

  Future<void> _requestPermission() async {
    await _run(() async {
      final allowed = await ref
          .read(reminderNotificationBridgeProvider)
          .service
          .requestPermission();
      if (!allowed) throw StateError('系统拒绝了通知权限');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (value) {
      if (mounted) setState(() => error = value.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _NotificationPreferenceRow extends StatelessWidget {
  const _NotificationPreferenceRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: value ? C.ps : C.soft,
            child: Icon(
              icon,
              size: 16,
              color: value ? C.p : C.muted,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.3,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 8.4,
                    color: C.muted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ]),
      );
}
