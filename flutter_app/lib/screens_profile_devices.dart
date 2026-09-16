part of 'main.dart';

class DeviceManagement extends ConsumerWidget {
  const DeviceManagement({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider).valueOrNull;
    final devicesState = ref.watch(cloudDevicesProvider);
    final sessionsState = ref.watch(cloudSessionsProvider);

    return DetailFrame(
      titleText: '设备管理',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: session == null
              ? null
              : () {
                  ref.invalidate(cloudDevicesProvider);
                  ref.invalidate(cloudSessionsProvider);
                },
          icon: const Icon(Icons.refresh_rounded, size: 18),
        ),
      ],
      child: page([
        if (session == null)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '尚未连接 LifeTrace Cloud',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  '设备与会话由 LifeTrace Cloud 统一管理，连接后才能查看。',
                  style: TextStyle(fontSize: 9, color: C.muted),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () => push(context, const CloudConnection()),
                  child: const Text('连接 Cloud'),
                ),
              ],
            ),
          )
        else ...[
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title('已登录设备'),
                  sub('Cloud 真实 installation · 可重命名或撤销其他设备'),
                ],
              ),
            ),
            chip(
              devicesState.valueOrNull?.length.toString() ?? '…',
              bg: C.ps,
              fg: C.p,
            ),
          ]),
          const SizedBox(height: 12),
          devicesState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => panel(
              Text(
                '设备读取失败：$error',
                style: const TextStyle(fontSize: 9.2, color: C.red),
              ),
            ),
            data: (devices) => devices.isEmpty
                ? panel(
                    const Text(
                      'Cloud 没有返回设备记录。',
                      style: TextStyle(fontSize: 9.2, color: C.muted),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < devices.length; i++) ...[
                        _CloudDeviceCard(
                          device: devices[i],
                          onRename: () =>
                              _renameCloudDevice(context, ref, devices[i]),
                          onRevoke: devices[i].current
                              ? null
                              : () => _revokeCloudDevice(
                                    context,
                                    ref,
                                    devices[i],
                                  ),
                        ),
                        if (i != devices.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
          h('登录会话'),
          sessionsState.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => panel(
              Text(
                '会话读取失败：$error',
                style: const TextStyle(fontSize: 9.2, color: C.red),
              ),
            ),
            data: (sessions) => sessions.isEmpty
                ? panel(
                    const Text(
                      '没有活跃会话。',
                      style: TextStyle(fontSize: 9.2, color: C.muted),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < sessions.length; i++) ...[
                        _CloudSessionCard(
                          session: sessions[i],
                          devices: devicesState.valueOrNull ??
                              const <CloudDeviceInstallation>[],
                          onRevoke: sessions[i].current
                              ? null
                              : () => _revokeCloudSession(
                                    context,
                                    ref,
                                    sessions[i],
                                  ),
                        ),
                        if (i != sessions.length - 1)
                          const SizedBox(height: 8),
                      ],
                    ],
                  ),
          ),
        ],
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }
}

class _CloudDeviceCard extends StatelessWidget {
  const _CloudDeviceCard({
    required this.device,
    required this.onRename,
    required this.onRevoke,
  });

  final CloudDeviceInstallation device;
  final VoidCallback onRename;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final revoked = device.revokedAt != null || device.status == 'revoked';
    final accent = device.current
        ? C.green
        : revoked
            ? C.muted
            : C.p;
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: accent.withValues(alpha: .10),
              child: Icon(_deviceIcon(device.platform), size: 18, color: accent),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(
                        device.deviceName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (device.current) ...[
                      const SizedBox(width: 6),
                      chip('当前设备', bg: C.greenSoft, fg: C.green),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    '${device.platform} · ${device.appId}'
                    '${device.clientVersion == null ? '' : ' · ${device.clientVersion}'}',
                    style: const TextStyle(fontSize: 8.4, color: C.muted),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              chip(
                revoked ? '已撤销' : device.status,
                bg: revoked ? C.soft : C.ps,
                fg: revoked ? C.muted : C.p,
              ),
              chip(
                '最近在线 ${_profileTime(device.lastSeenAt)}',
                bg: C.soft,
                fg: C.muted,
              ),
              if (device.lastSyncAt != null)
                chip(
                  '同步 ${_profileTime(device.lastSyncAt!)}',
                  bg: C.soft,
                  fg: C.muted,
                ),
            ],
          ),
          if (!revoked) ...[
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRename,
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('重命名'),
                ),
              ),
              if (onRevoke != null) ...[
                const SizedBox(width: 7),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRevoke,
                    icon: const Icon(Icons.block_rounded, size: 14),
                    label: const Text('撤销设备'),
                  ),
                ),
              ],
            ]),
          ],
        ],
      ),
      padding: const EdgeInsets.all(11),
    );
  }
}

class _CloudSessionCard extends StatelessWidget {
  const _CloudSessionCard({
    required this.session,
    required this.devices,
    required this.onRevoke,
  });

  final CloudAuthSessionInfo session;
  final List<CloudDeviceInstallation> devices;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    CloudDeviceInstallation? device;
    for (final candidate in devices) {
      if (candidate.id == session.deviceId) {
        device = candidate;
        break;
      }
    }
    return panel(
      Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: session.current ? C.greenSoft : C.soft,
          child: Icon(
            Icons.key_rounded,
            size: 15,
            color: session.current ? C.green : C.muted,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device?.deviceName ?? session.appId,
                style: const TextStyle(
                  fontSize: 10.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${session.sessionType} · 最近活动 ${_profileTime(session.lastSeenAt)}',
                style: const TextStyle(fontSize: 8.4, color: C.muted),
              ),
            ],
          ),
        ),
        if (session.current)
          chip('当前会话', bg: C.greenSoft, fg: C.green)
        else
          TextButton(onPressed: onRevoke, child: const Text('撤销')),
      ]),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    );
  }
}

Future<void> _renameCloudDevice(
  BuildContext context,
  WidgetRef ref,
  CloudDeviceInstallation device,
) async {
  final controller = TextEditingController(text: device.deviceName);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('重命名设备'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: '设备名称'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            try {
              await ref
                  .read(cloudDeviceCommandsProvider)
                  .renameDevice(device, controller.text);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            } catch (error) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('$error')),
                );
              }
            }
          },
          child: const Text('保存'),
        ),
      ],
    ),
  );
  controller.dispose();
}

Future<void> _revokeCloudDevice(
  BuildContext context,
  WidgetRef ref,
  CloudDeviceInstallation device,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('撤销设备'),
      content: Text('撤销「${device.deviceName}」后，该设备上的会话将失效。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('确认撤销'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(cloudDeviceCommandsProvider).revokeDevice(device);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

Future<void> _revokeCloudSession(
  BuildContext context,
  WidgetRef ref,
  CloudAuthSessionInfo session,
) async {
  try {
    await ref.read(cloudDeviceCommandsProvider).revokeSession(session);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

IconData _deviceIcon(String platform) {
  final value = platform.toLowerCase();
  if (value.contains('android')) return Icons.android_rounded;
  if (value.contains('ios')) return Icons.phone_iphone_rounded;
  if (value.contains('web')) return Icons.language_rounded;
  if (value.contains('desktop')) return Icons.computer_rounded;
  return Icons.devices_other_rounded;
}

String _profileTime(String raw) {
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return raw;
  final now = DateTime.now();
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '今天 $hh:$mm';
  }
  return '${value.month}月${value.day}日';
}
