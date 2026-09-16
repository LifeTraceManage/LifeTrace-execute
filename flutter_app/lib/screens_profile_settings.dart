part of 'main.dart';

class NotificationSettings extends ConsumerWidget {
  const NotificationSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);

    return DetailFrame(
      titleText: '通知',
      child: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => page([
          panel(Text('设置读取失败：$error')),
        ]),
        data: (value) => page([
          h('系统通知'),
          panel(
            Column(children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('启用 LifeTrace 通知'),
                subtitle: const Text('关闭后任务、日历和专注通知都不会投递到系统通知栏'),
                value: value.notificationsEnabled,
                onChanged: (enabled) =>
                    _setNotificationMaster(context, ref, enabled),
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('任务与日历提醒'),
                subtitle: const Text('控制 Reminder 产生的 Android 本地通知'),
                value: value.reminderNotificationsEnabled,
                onChanged: value.notificationsEnabled
                    ? (enabled) =>
                        _setReminderNotifications(ref, enabled)
                    : null,
              ),
              const Divider(height: 1),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('专注阶段提醒'),
                subtitle: const Text('专注结束和休息结束时发送通知'),
                value: value.focusNotificationsEnabled,
                onChanged: value.notificationsEnabled
                    ? (enabled) =>
                        _setFocusNotifications(ref, enabled)
                    : null,
              ),
            ]),
          ),
          panel(
            const Text(
              '这些设置只控制本机通知投递，不删除 Reminder、Calendar Event 或 FocusSession 数据，也不会影响 Cloud Sync。',
              style: TextStyle(fontSize: 8.8, color: C.muted, height: 1.4),
            ),
            padding: const EdgeInsets.all(10),
          ),
        ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
      ),
    );
  }

  Future<void> _setNotificationMaster(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    if (enabled && !kIsWeb) {
      final allowed = await ref
          .read(reminderNotificationBridgeProvider)
          .service
          .requestPermission();
      if (!allowed) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('系统通知权限未开启')),
          );
        }
        return;
      }
    }
    await ref
        .read(appPreferencesCommandsProvider)
        .setNotificationsEnabled(enabled);
    await _reconcileNotifications(ref);
  }

  Future<void> _setReminderNotifications(
    WidgetRef ref,
    bool enabled,
  ) async {
    await ref
        .read(appPreferencesCommandsProvider)
        .setReminderNotificationsEnabled(enabled);
    await ref.read(reminderCommandsProvider).reconcile();
  }

  Future<void> _setFocusNotifications(
    WidgetRef ref,
    bool enabled,
  ) async {
    await ref
        .read(appPreferencesCommandsProvider)
        .setFocusNotificationsEnabled(enabled);
    await ref.read(focusCommandsProvider).reconcile();
  }

  Future<void> _reconcileNotifications(WidgetRef ref) async {
    await ref.read(reminderCommandsProvider).reconcile();
    await ref.read(focusCommandsProvider).reconcile();
  }
}

class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);

    return DetailFrame(
      titleText: '外观',
      child: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => page([panel(Text('设置读取失败：$error'))]),
        data: (value) => page([
          h('界面密度'),
          panel(
            Column(
              children: [
                RadioListTile<UiDensityPreference>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('紧凑'),
                  subtitle: const Text('提高信息密度，适合小屏和高频操作'),
                  value: UiDensityPreference.compact,
                  groupValue: value.uiDensity,
                  onChanged: (next) => _setDensity(ref, next),
                ),
                const Divider(height: 1),
                RadioListTile<UiDensityPreference>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('标准'),
                  subtitle: const Text('当前默认显示比例'),
                  value: UiDensityPreference.standard,
                  groupValue: value.uiDensity,
                  onChanged: (next) => _setDensity(ref, next),
                ),
                const Divider(height: 1),
                RadioListTile<UiDensityPreference>(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('舒适'),
                  subtitle: const Text('适当放大文字和控件内容'),
                  value: UiDensityPreference.comfortable,
                  groupValue: value.uiDensity,
                  onChanged: (next) => _setDensity(ref, next),
                ),
              ],
            ),
          ),
          panel(
            const Text(
              '当前生产 UI 仍使用固定明亮设计基线。深色主题需要先完成 Design Token 动态化，避免出现局部白底/深色文字冲突。',
              style: TextStyle(fontSize: 8.8, color: C.muted, height: 1.4),
            ),
            padding: const EdgeInsets.all(10),
          ),
        ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
      ),
    );
  }

  Future<void> _setDensity(
    WidgetRef ref,
    UiDensityPreference? value,
  ) async {
    if (value == null) return;
    await ref.read(appPreferencesCommandsProvider).setUiDensity(value);
  }
}

class GeneralSettings extends ConsumerWidget {
  const GeneralSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);

    return DetailFrame(
      titleText: '通用',
      child: preferences.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => page([panel(Text('设置读取失败：$error'))]),
        data: (value) => page([
          h('日历'),
          panel(
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('周一作为每周第一天'),
              subtitle: Text(
                value.weekStartsMonday
                    ? '日历按 周一 → 周日 排列'
                    : '日历按 周日 → 周六 排列',
              ),
              value: value.weekStartsMonday,
              onChanged: (enabled) => ref
                  .read(appPreferencesCommandsProvider)
                  .setWeekStartsMonday(enabled),
            ),
          ),
          panel(
            const Text(
              '通用设置保存在本机，不进入 Cloud Sync；切换后日历会立即按新的周起始日重新排列。',
              style: TextStyle(fontSize: 8.8, color: C.muted, height: 1.4),
            ),
            padding: const EdgeInsets.all(10),
          ),
        ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
      ),
    );
  }
}

class AboutLifeTrace extends ConsumerWidget {
  const AboutLifeTrace({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final package = ref.watch(packageInfoProvider);

    return DetailFrame(
      titleText: '关于',
      child: page([
        Row(children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: C.ps,
            child: Icon(Icons.bolt_rounded, color: C.p, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title('LifeTrace Execute'),
                sub('Local-first execution center'),
              ],
            ),
          ),
        ]),
        h('应用信息'),
        package.when(
          loading: () => panel(
            const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => panel(Text('版本读取失败：$error')),
          data: (info) => panel(
            Column(children: [
              _InfoRow('版本', info.version),
              const Divider(height: 1),
              _InfoRow('构建号', info.buildNumber),
              const Divider(height: 1),
              _InfoRow('包名', info.packageName),
            ]),
          ),
        ),
        h('架构'),
        panel(
          const Column(children: [
            _InfoRow('客户端', 'Flutter / Dart'),
            Divider(height: 1),
            _InfoRow('本地数据', 'Drift / SQLite · Local-first'),
            Divider(height: 1),
            _InfoRow('同步', 'LifeTrace Cloud · Sync v1'),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'LifeTrace Execute',
            ),
            icon: const Icon(Icons.description_outlined, size: 17),
            label: const Text('开源许可'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => push(context, const DataManagement()),
            icon: const Icon(Icons.privacy_tip_outlined, size: 17),
            label: const Text('数据与隐私'),
          ),
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }
}
