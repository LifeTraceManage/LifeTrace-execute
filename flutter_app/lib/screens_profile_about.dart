part of 'main.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoState = ref.watch(appAboutInfoProvider);
    final session = ref.watch(currentSessionProvider).valueOrNull;

    return DetailFrame(
      titleText: '关于',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: () => ref.invalidate(appAboutInfoProvider),
          icon: const Icon(Icons.refresh_rounded, size: 18),
        ),
      ],
      child: page([
        const CircleAvatar(
          radius: 34,
          backgroundColor: C.ps,
          child: Icon(Icons.route_rounded, size: 34, color: C.p),
        ),
        const SizedBox(height: 10),
        title('LifeTrace Execute'),
        const SizedBox(height: 3),
        sub('Local-first execution client'),
        h('应用信息'),
        infoState.when(
          loading: () => panel(
            const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => panel(
            Text(
              '应用信息读取失败：$error',
              style: const TextStyle(fontSize: 9.2, color: C.red),
            ),
          ),
          data: (info) => panel(
            Column(children: [
              _InfoRow('应用名', info.appName),
              const Divider(height: 1),
              _InfoRow('版本', info.version),
              const Divider(height: 1),
              _InfoRow('Build', info.buildNumber),
              const Divider(height: 1),
              _InfoRow('Package', info.packageName),
              const Divider(height: 1),
              _InfoRow('平台', info.platform),
            ]),
          ),
        ),
        h('Cloud / Sync'),
        panel(
          Column(children: [
            const _InfoRow('AppId', CloudContract.appId),
            const Divider(height: 1),
            const _InfoRow(
              '协议',
              'Sync v${CloudContract.protocolVersion} · '
              'Schema ${CloudContract.schemaVersion}',
            ),
            const Divider(height: 1),
            _InfoRow(
              '连接',
              session == null
                  ? '未连接'
                  : '${session.baseUrl} · ${session.email}',
            ),
            const Divider(height: 1),
            _InfoRow(
              '实体类型',
              '${CloudContract.requiredSyncEntityTypes.length} 个',
            ),
          ]),
        ),
        h('运行原则'),
        panel(
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• Local-first：核心业务先写本地数据库和 Outbox。',
                style: TextStyle(fontSize: 8.9, color: C.muted, height: 1.5),
              ),
              Text(
                '• Sync v1：Snapshot / Push / Pull / Conflict / Tombstone。',
                style: TextStyle(fontSize: 8.9, color: C.muted, height: 1.5),
              ),
              Text(
                '• Flutter 是正式客户端；旧 Compose 仅保留作迁移参考。',
                style: TextStyle(fontSize: 8.9, color: C.muted, height: 1.5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(11),
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }
}
