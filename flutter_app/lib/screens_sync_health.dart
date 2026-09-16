part of 'main.dart';

class SyncHealthCenter extends ConsumerStatefulWidget {
  const SyncHealthCenter({super.key});

  @override
  ConsumerState<SyncHealthCenter> createState() => _SyncHealthCenterState();
}

class _SyncHealthCenterState extends ConsumerState<SyncHealthCenter> {
  bool rebuilding = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final conflictsState = ref.watch(syncConflictCenterProvider);
    final pending = ref.watch(taskPendingSyncCountProvider).valueOrNull ?? 0;
    final blocked = ref.watch(taskBlockedSyncCountProvider).valueOrNull ?? 0;
    final syncState = ref.watch(taskSyncControllerProvider);
    final conflicts =
        conflictsState.valueOrNull ?? const <SyncConflictCenterItem>[];

    return DetailFrame(
      titleText: '同步健康',
      actions: [
        IconButton(
          tooltip: '立即同步',
          onPressed: syncState.isLoading ? null : _syncNow,
          icon: const Icon(Icons.sync_rounded, size: 18),
        ),
      ],
      child: page([
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title('Sync v1 状态'),
                sub('Outbox · 阻塞 · 冲突 · Snapshot 基线'),
              ],
            ),
          ),
          chip(
            conflicts.isEmpty ? '正常' : '需处理',
            bg: conflicts.isEmpty ? C.greenSoft : C.redSoft,
            fg: conflicts.isEmpty ? C.green : C.red,
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _MiniMetric(
              Icons.outbox_outlined,
              pending.toString(),
              '待上传',
              C.p,
              C.ps,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _MiniMetric(
              Icons.block_rounded,
              blocked.toString(),
              '阻塞',
              C.orange,
              C.orangeSoft,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: _MiniMetric(
              Icons.compare_arrows_rounded,
              conflicts.length.toString(),
              '冲突',
              C.red,
              C.redSoft,
            ),
          ),
        ]),
        if (syncState.hasError) ...[
          const SizedBox(height: 10),
          Text(
            '最近同步失败：${syncState.error}',
            style: const TextStyle(fontSize: 9, color: C.red),
          ),
        ],
        h(
          '冲突中心',
          tail: conflictsState.isLoading
              ? const Text(
                  '读取中',
                  style: TextStyle(fontSize: 9, color: C.muted),
                )
              : Text(
                  '${conflicts.length} 项',
                  style: const TextStyle(fontSize: 9, color: C.muted),
                ),
        ),
        conflictsState.when(
          loading: () => panel(
            const Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => panel(
            Text(
              '冲突读取失败：$error',
              style: const TextStyle(fontSize: 9.2, color: C.red),
            ),
          ),
          data: (items) => items.isEmpty
              ? panel(
                  const Row(children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 17,
                      color: C.green,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前没有未解决的 Sync v1 冲突。',
                        style: TextStyle(fontSize: 9.2, color: C.muted),
                      ),
                    ),
                  ]),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                )
              : Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _SyncConflictCard(item: items[i]),
                      if (i != items.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ),
        ),
        h('同步维护'),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '重建同步基线',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                '清除当前 Sync cursor 后重新请求全实体 Snapshot。不会删除本地业务实体、Outbox 或未解决冲突；有本地待上传变更的实体不会被 Snapshot 覆盖。',
                style: TextStyle(
                  fontSize: 8.8,
                  color: C.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: rebuilding ? null : _confirmRebuild,
                  icon: rebuilding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore_page_rounded, size: 17),
                  label: Text(rebuilding ? '正在重建' : '重建 Snapshot 基线'),
                ),
              ),
            ],
          ),
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

  Future<void> _syncNow() async {
    setState(() => error = null);
    try {
      final summary = await ref.read(syncHealthCommandsProvider).syncNow();
      if (!mounted || summary == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '同步完成：Push ${summary.pushed} · Pull ${summary.pulled} · '
            '冲突 ${summary.conflicts}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = '同步失败：$e');
    }
  }

  Future<void> _confirmRebuild() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('重建同步基线'),
        content: const Text(
          '将清除当前同步游标并重新拉取全实体 Snapshot。本地未上传修改会保留。是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('开始重建'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      rebuilding = true;
      error = null;
    });
    try {
      final summary =
          await ref.read(syncHealthCommandsProvider).rebuildSnapshotBaseline();
      if (!mounted || summary == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Snapshot 重建完成：${summary.snapshotItems} 项 · '
            'Pull ${summary.pulled} 项',
          ),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = '重建失败：$e');
    } finally {
      if (mounted) setState(() => rebuilding = false);
    }
  }
}

class _SyncConflictCard extends ConsumerStatefulWidget {
  const _SyncConflictCard({required this.item});

  final SyncConflictCenterItem item;

  @override
  ConsumerState<_SyncConflictCard> createState() => _SyncConflictCardState();
}

class _SyncConflictCardState extends ConsumerState<_SyncConflictCard> {
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final local = item.localTitle?.trim();
    final server = item.serverTitle?.trim();

    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const CircleAvatar(
              radius: 17,
              backgroundColor: C.redSoft,
              child: const Icon(
                Icons.compare_arrows_rounded,
                size: 16,
                color: C.red,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    syncEntityLabel(item.entityType),
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.entityId,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 8.2, color: C.muted),
                  ),
                ],
              ),
            ),
            if (item.serverDeleted)
              chip('云端已删除', bg: C.redSoft, fg: C.red),
          ]),
          const SizedBox(height: 8),
          if (local != null && local.isNotEmpty)
            _InfoRow('本地', local),
          if (server != null && server.isNotEmpty) ...[
            const Divider(height: 1),
            _InfoRow('云端', server),
          ],
          const Divider(height: 1),
          _InfoRow(
            '原因',
            item.reason.trim().isEmpty ? '版本冲突' : item.reason,
          ),
          if (error != null) ...[
            const SizedBox(height: 7),
            Text(
              error!,
              style: const TextStyle(fontSize: 8.6, color: C.red),
            ),
          ],
          const SizedBox(height: 9),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => _resolve(false),
                child: const Text('保留云端'),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : () => _resolve(true),
                child: const Text('保留本地'),
              ),
            ),
          ]),
        ],
      ),
      padding: const EdgeInsets.all(11),
    );
  }

  Future<void> _resolve(bool keepLocal) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(syncHealthCommandsProvider).resolve(
            widget.item,
            keepLocal: keepLocal,
          );
    } catch (e) {
      if (mounted) setState(() => error = '处理失败：$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
