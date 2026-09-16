part of 'main.dart';

class ConflictCenter extends ConsumerStatefulWidget {
  const ConflictCenter({super.key});

  @override
  ConsumerState<ConflictCenter> createState() => _ConflictCenterState();
}

class _ConflictCenterState extends ConsumerState<ConflictCenter> {
  final Set<String> busy = <String>{};
  String? actionError;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider).valueOrNull;
    final state = ref.watch(syncConflictCenterProvider);
    final conflicts = state.valueOrNull ?? const <ProfileConflictItem>[];

    return DetailFrame(
      titleText: '冲突中心',
      actions: [
        IconButton(
          tooltip: '立即同步',
          onPressed: session == null
              ? null
              : () => ref
                  .read(taskSyncControllerProvider.notifier)
                  .syncNow(),
          icon: const Icon(Icons.sync_rounded, size: 18),
        ),
      ],
      child: page([
        Row(children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: C.orangeSoft,
            child: Icon(
              Icons.call_split_rounded,
              color: C.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title('Sync v1 冲突'),
                const SizedBox(height: 2),
                sub('统一处理 Task / Project / Goal / Habit / Review 等实体'),
              ],
            ),
          ),
          chip(
            state.isLoading ? '…' : '${conflicts.length}',
            bg: conflicts.isEmpty ? C.greenSoft : C.orangeSoft,
            fg: conflicts.isEmpty ? C.green : C.orange,
          ),
        ]),
        const SizedBox(height: 12),
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
                  '冲突来自跨设备 Sync v1，连接 Cloud 后才能同步和处理。',
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
        else if (state.isLoading && conflicts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.hasError)
          panel(
            Text(
              '冲突读取失败：${state.error}',
              style: const TextStyle(fontSize: 9.2, color: C.red),
            ),
          )
        else if (conflicts.isEmpty)
          panel(
            const Row(children: [
              Icon(Icons.check_circle_rounded, color: C.green, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '当前没有未解决的同步冲突。',
                  style: TextStyle(fontSize: 9.5, color: C.muted),
                ),
              ),
            ]),
          )
        else
          for (final conflict in conflicts) ...[
            _ProfileConflictCard(
              conflict: conflict,
              busy: busy.contains(conflict.id),
              onKeepServer: () => _resolve(conflict, keepLocal: false),
              onKeepLocal: () => _resolve(conflict, keepLocal: true),
            ),
            const SizedBox(height: 8),
          ],
        if (actionError != null) ...[
          const SizedBox(height: 8),
          Text(
            actionError!,
            style: const TextStyle(fontSize: 9, color: C.red),
          ),
        ],
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }

  Future<void> _resolve(
    ProfileConflictItem conflict, {
    required bool keepLocal,
  }) async {
    setState(() {
      busy.add(conflict.id);
      actionError = null;
    });
    try {
      final commands = ref.read(profileConflictCommandsProvider);
      if (keepLocal) {
        await commands.keepLocal(conflict);
      } else {
        await commands.keepServer(conflict);
      }
    } catch (error) {
      if (mounted) setState(() => actionError = '冲突处理失败：$error');
    } finally {
      if (mounted) {
        setState(() => busy.remove(conflict.id));
      }
    }
  }
}

class _ProfileConflictCard extends StatelessWidget {
  const _ProfileConflictCard({
    required this.conflict,
    required this.busy,
    required this.onKeepServer,
    required this.onKeepLocal,
  });

  final ProfileConflictItem conflict;
  final bool busy;
  final VoidCallback onKeepServer;
  final VoidCallback onKeepLocal;

  @override
  Widget build(BuildContext context) => panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                  conflictEntityLabel(conflict.entityType),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (conflict.serverDeleted)
                chip('云端已删除', bg: C.redSoft, fg: C.red)
              else
                chip(
                  'v${conflict.serverVersion ?? '?'}',
                  bg: C.orangeSoft,
                  fg: C.orange,
                ),
            ]),
            const SizedBox(height: 4),
            Text(
              conflict.reason,
              style: const TextStyle(fontSize: 8.8, color: C.muted),
            ),
            const SizedBox(height: 7),
            _ConflictValue(
              label: '本地',
              value: conflict.localSummary ?? conflict.entityId,
            ),
            const SizedBox(height: 5),
            _ConflictValue(
              label: '云端',
              value: conflict.serverDeleted
                  ? '已删除'
                  : conflict.serverSummary ?? conflict.entityId,
            ),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onKeepServer,
                  child: const Text('保留云端'),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onKeepLocal,
                  child: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('保留本地'),
                ),
              ),
            ]),
          ],
        ),
        padding: const EdgeInsets.all(11),
      );
}

class _ConflictValue extends StatelessWidget {
  const _ConflictValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 8.4,
                color: C.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8.8, color: C.ink),
            ),
          ),
        ],
      );
}
