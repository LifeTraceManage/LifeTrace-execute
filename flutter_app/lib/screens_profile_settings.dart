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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<UiDensityPreference>(
                    segments: const [
                      ButtonSegment(
                        value: UiDensityPreference.compact,
                        label: Text('紧凑'),
                      ),
                      ButtonSegment(
                        value: UiDensityPreference.standard,
                        label: Text('标准'),
                      ),
                      ButtonSegment(
                        value: UiDensityPreference.comfortable,
                        label: Text('舒适'),
                      ),
                    ],
                    selected: {value.uiDensity},
                    onSelectionChanged: (selected) =>
                        _setDensity(ref, selected.first),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  switch (value.uiDensity) {
                    UiDensityPreference.compact =>
                      '提高信息密度，适合小屏和高频操作。',
                    UiDensityPreference.standard =>
                      '使用当前默认显示比例。',
                    UiDensityPreference.comfortable =>
                      '适当放大文字和控件内容。',
                  },
                  style: const TextStyle(
                    fontSize: 8.8,
                    color: C.muted,
                    height: 1.4,
                  ),
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

class AboutLifeTrace extends ConsumerStatefulWidget {
  const AboutLifeTrace({super.key});

  @override
  ConsumerState<AboutLifeTrace> createState() => _AboutLifeTraceState();
}

class _AboutLifeTraceState extends ConsumerState<AboutLifeTrace> {
  bool _checkingUpdate = false;
  bool _downloadingUpdate = false;
  double _downloadProgress = 0;

  bool get _supportsInAppUpdate =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final package = ref.watch(packageInfoProvider);
    final busy = _checkingUpdate || _downloadingUpdate;

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
        h('应用更新'),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '仅在你主动点击时检查 GitHub Release，不会在启动、后台或回到前台时自动检查。',
                style: TextStyle(fontSize: 9, color: C.muted, height: 1.45),
              ),
              if (_downloadingUpdate) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(value: _downloadProgress),
                const SizedBox(height: 5),
                Text(
                  '正在下载更新 · ${(_downloadProgress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 8.8,
                    color: C.p,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _supportsInAppUpdate && !busy
                      ? _checkForUpdate
                      : null,
                  icon: _checkingUpdate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_rounded, size: 17),
                  label: Text(
                    _checkingUpdate
                        ? '正在检查…'
                        : _downloadingUpdate
                            ? '正在下载…'
                            : _supportsInAppUpdate
                                ? '检查更新'
                                : '检查更新（仅 Android）',
                  ),
                ),
              ),
            ],
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

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate || _downloadingUpdate) return;

    setState(() => _checkingUpdate = true);
    AppUpdateCheckResult? result;
    try {
      final package = await ref.read(packageInfoProvider.future);
      result = await ref
          .read(appUpdateServiceProvider)
          .checkForUpdate(package);
    } on AppUpdateException catch (error) {
      if (mounted) {
        await _showUpdateMessage(
          title: '检查更新失败',
          message: error.message,
        );
      }
      return;
    } catch (error) {
      if (mounted) {
        await _showUpdateMessage(
          title: '检查更新失败',
          message: error.toString(),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _checkingUpdate = false);
      }
    }

    if (!mounted || result == null) return;
    if (!result.updateAvailable) {
      await _showUpdateMessage(
        title: '已是最新版本',
        message: '当前版本 ${result.current.label}，GitHub Release 最新版本为 '
            '${result.latest.version.label}。',
      );
      return;
    }

    final release = result.latest;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('发现新版本 ${release.version.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前版本：${result!.current.label}'),
            const SizedBox(height: 4),
            Text('安装包：${_formatBytes(release.apkSize)}'),
            if (release.body.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _releaseNotes(release.body),
                style: const TextStyle(fontSize: 11, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              '确认后才会开始下载；下载完成后仍由 Android 系统安装器确认安装。',
              style: TextStyle(fontSize: 10, color: C.muted, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('下载并安装'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _downloadAndInstall(release);
    }
  }

  Future<void> _downloadAndInstall(AppUpdateRelease release) async {
    setState(() {
      _downloadingUpdate = true;
      _downloadProgress = 0;
    });

    try {
      final service = ref.read(appUpdateServiceProvider);
      final apk = await service.downloadRelease(
        release,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => _downloadProgress = progress.clamp(0.0, 1.0).toDouble());
        },
      );

      final result = await service.install(apk);
      if (!mounted) return;
      switch (result) {
        case ApkInstallResult.launched:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已打开 Android 系统安装器')),
          );
        case ApkInstallResult.permissionRequired:
          await _showUpdateMessage(
            title: '需要安装权限',
            message:
                '系统已打开“安装未知应用”设置。允许 LifeTrace Execute 安装应用后，返回这里再次点击“检查更新”；已下载且校验通过的 APK 会直接复用。',
          );
        case ApkInstallResult.signatureMismatch:
          await _showUpdateMessage(
            title: '无法覆盖安装',
            message:
                '新 APK 与当前安装版本的签名不一致，Android 不允许直接覆盖。需要后续发布版本使用同一套稳定签名，才能实现原地升级。',
          );
      }
    } on AppUpdateException catch (error) {
      if (mounted) {
        await _showUpdateMessage(
          title: '更新失败',
          message: error.message,
        );
      }
    } catch (error) {
      if (mounted) {
        await _showUpdateMessage(
          title: '更新失败',
          message: error.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingUpdate = false;
          _downloadProgress = 0;
        });
      }
    }
  }

  Future<void> _showUpdateMessage({
    required String title,
    required String message,
  }) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '未知大小';
    final megabytes = bytes / (1024 * 1024);
    return '${megabytes.toStringAsFixed(1)} MB';
  }

  String _releaseNotes(String value) {
    final normalized = value.trim();
    if (normalized.length <= 600) return normalized;
    return '${normalized.substring(0, 600)}…';
  }
}
