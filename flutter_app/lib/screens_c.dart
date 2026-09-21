// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

part of 'main.dart';

class Collection extends ConsumerStatefulWidget {
  const Collection({super.key});

  @override
  ConsumerState<Collection> createState() => _CollectionState();
}

class _CollectionState extends ConsumerState<Collection> {
  int inboxFilter = 0;

  @override
  Widget build(BuildContext context) {
    final inboxState = ref.watch(inboxMemoListProvider);
    final conflicts =
        ref.watch(collectionConflictsProvider).valueOrNull ??
            const <CollectionConflictUi>[];
    final inbox = inboxState.valueOrNull ?? const <ExecutionMemo>[];
    final visible = _filterInbox(inbox, inboxFilter);

    return page([
      Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title('收集'),
              sub('先记下来，再决定它属于哪里'),
            ],
          ),
        ),
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: C.tealSoft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.inbox_rounded, color: C.teal, size: 19),
        ),
      ]),
      if (conflicts.isNotEmpty) ...[
        const SizedBox(height: 10),
        _CollectionConflictCard(conflict: conflicts.first),
      ],
      const SizedBox(height: 12),
      _CaptureComposer(
        onSubmit: (text) => ref.read(collectionCommandsProvider).create(
              kind: ExecutionMemoKind.text,
              content: text,
            ),
      ),
      h('快速收集'),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _Quick(
          Icons.edit_note_rounded,
          '文本',
          C.p,
          C.ps,
          () => _showMemoEditor(context, ref, kind: ExecutionMemoKind.text),
        ),
        _Quick(
          Icons.lightbulb_outline_rounded,
          '想法',
          C.amber,
          C.amberSoft,
          () => _showMemoEditor(context, ref, kind: ExecutionMemoKind.idea),
        ),
        _Quick(
          Icons.link_rounded,
          '链接',
          C.teal,
          C.tealSoft,
          () => _showMemoEditor(context, ref, kind: ExecutionMemoKind.link),
        ),
        _Quick(
          Icons.mic_none_rounded,
          '语音',
          C.purple,
          C.purpleSoft,
          () => _pickMediaForInbox(
            context,
            ref,
            ExecutionMemoKind.audio,
          ),
        ),
        _Quick(
          Icons.image_outlined,
          '图片',
          C.pink,
          C.pinkSoft,
          () => _pickMediaForInbox(
            context,
            ref,
            ExecutionMemoKind.image,
          ),
        ),
        _Quick(
          Icons.insert_drive_file_outlined,
          '文件',
          C.orange,
          C.orangeSoft,
          () => _pickMediaForInbox(
            context,
            ref,
            ExecutionMemoKind.file,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      _InboxOverview(items: inbox),
      const SizedBox(height: 12),
      Row(children: [
        const Expanded(
          child: Text(
            'Inbox',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          '${visible.length} 条待整理',
          style: const TextStyle(fontSize: 8.8, color: C.muted),
        ),
      ]),
      const SizedBox(height: 8),
      _InboxFilters(
        selected: inboxFilter,
        onChanged: (value) => setState(() => inboxFilter = value),
      ),
      const SizedBox(height: 10),
      if (inboxState.isLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (inboxState.hasError)
        panel(
          Text(
            '读取 Inbox 失败：${inboxState.error}',
            style: const TextStyle(fontSize: 9.5, color: C.red),
          ),
        )
      else if (visible.isEmpty)
        panel(
          const Column(
            children: [
              Icon(Icons.inbox_outlined, color: C.muted),
              SizedBox(height: 6),
              Text(
                '当前筛选下没有待整理内容',
                style: TextStyle(fontSize: 9.5, color: C.muted),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
        )
      else
        for (final memo in visible)
          _InboxCard(
            memo: memo,
            onTap: () => push(context, InboxDetail(memoId: memo.id)),
          ),
    ]);
  }
}

List<ExecutionMemo> _filterInbox(List<ExecutionMemo> items, int filter) {
  return switch (filter) {
    1 => items.where((memo) => memo.important).toList(growable: false),
    2 => items
        .where((memo) => memo.kind == ExecutionMemoKind.text)
        .toList(growable: false),
    3 => items
        .where((memo) => memo.kind == ExecutionMemoKind.idea)
        .toList(growable: false),
    4 => items
        .where((memo) => memo.kind == ExecutionMemoKind.link)
        .toList(growable: false),
    5 => items
        .where(
          (memo) =>
              memo.kind == ExecutionMemoKind.image ||
              memo.kind == ExecutionMemoKind.audio ||
              memo.kind == ExecutionMemoKind.file,
        )
        .toList(growable: false),
    _ => items,
  };
}

class _CaptureComposer extends StatefulWidget {
  const _CaptureComposer({required this.onSubmit});

  final Future<ExecutionMemo> Function(String text) onSubmit;

  @override
  State<_CaptureComposer> createState() => _CaptureComposerState();
}

class _CaptureComposerState extends State<_CaptureComposer> {
  final controller = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final value = controller.text.trim();
    if (value.isEmpty || saving) return;
    setState(() => saving = true);
    try {
      await widget.onSubmit(value);
      controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已保存到 Inbox')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [C.tealSoft, Colors.white],
          ),
          border: Border.all(color: C.teal.withValues(alpha: .12)),
        ),
        child: Column(children: [
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '输入想法、任务、备忘...',
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 9),
          Row(children: [
            const Text(
              '默认保存为文本 Memo',
              style: TextStyle(fontSize: 8.3, color: C.muted),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: saving ? null : submit,
              icon: saving
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 14),
              label: const Text('收集'),
            ),
          ]),
        ]),
      );
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.color, this.background, this.tap);

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback tap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 96,
          height: 68,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.3,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
}

class _InboxOverview extends StatelessWidget {
  const _InboxOverview({required this.items});

  final List<ExecutionMemo> items;

  @override
  Widget build(BuildContext context) {
    final important = items.where((memo) => memo.important).length;
    final links =
        items.where((memo) => memo.kind == ExecutionMemoKind.link).length;
    final ideas =
        items.where((memo) => memo.kind == ExecutionMemoKind.idea).length;
    final progress = items.isEmpty ? 1.0 : important / items.length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.ink,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 6,
                color: C.teal,
                backgroundColor: const Color(0xff313b4f),
              ),
              Center(
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                items.isEmpty ? 'Inbox 已清空' : '收集箱需要整理',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                items.isEmpty
                    ? '新的内容会先进入这里'
                    : '还有 ${items.length} 条真实内容等待归类',
                style: const TextStyle(fontSize: 8.8, color: Colors.white60),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 5, children: [
                _InboxStatDot(color: C.amber, label: '$important 重点'),
                _InboxStatDot(color: C.teal, label: '$links 链接'),
                _InboxStatDot(color: C.purple, label: '$ideas 想法'),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _InboxStatDot extends StatelessWidget {
  const _InboxStatDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 8, color: Colors.white70),
          ),
        ],
      );
}

class _InboxFilters extends StatelessWidget {
  const _InboxFilters({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['全部', '重点', '文本', '想法', '链接', '媒体'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = selected == index;
          return Padding(
            padding: EdgeInsets.only(
              right: index == labels.length - 1 ? 0 : 6,
            ),
            child: ChoiceChip(
              selected: active,
              label: Text(labels[index]),
              onSelected: (_) => onChanged(index),
              selectedColor: C.tealSoft,
              labelStyle: TextStyle(
                fontSize: 8.8,
                fontWeight: FontWeight.w800,
                color: active ? C.teal : C.muted,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.memo, required this.onTap});

  final ExecutionMemo memo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _memoVisual(memo.kind);
    final displayTitle = _memoTitle(memo);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: visual.color.withValues(alpha: .12)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: visual.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(visual.icon, size: 18, color: visual.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (memo.important)
                      const Icon(Icons.star_rounded, size: 13, color: C.amber),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    memo.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.7,
                      color: C.muted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(children: [
                    chip(
                      visual.label,
                      bg: visual.background,
                      fg: visual.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _memoUpdatedLabel(memo.updatedAt),
                      style: const TextStyle(fontSize: 8, color: C.muted),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: visual.color.withValues(alpha: .72),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InboxDetail extends ConsumerWidget {
  const InboxDetail({super.key, required this.memoId});

  final String memoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memos = ref.watch(memoListProvider).valueOrNull ??
        const <ExecutionMemo>[];
    ExecutionMemo? memo;
    for (final item in memos) {
      if (item.id == memoId) {
        memo = item;
        break;
      }
    }
    if (memo == null) {
      return DetailFrame(
        titleText: 'Inbox',
        child: page([
          panel(
            const Text(
              '这条内容已被整理或删除。',
              style: TextStyle(fontSize: 10, color: C.muted),
            ),
          ),
        ]),
      );
    }

    final current = memo;
    final visual = _memoVisual(current.kind);
    final projects =
        ref.watch(projectListProvider).valueOrNull ?? const <ExecutionProject>[];
    final uploads =
        ref.watch(mediaUploadListProvider).valueOrNull ??
            const <PendingMediaUpload>[];
    PendingMediaUpload? upload;
    for (final item in uploads) {
      if (item.memoId == current.id) {
        upload = item;
        break;
      }
    }
    final attachmentLinks =
        ref.watch(memoAttachmentLinksProvider(current.id)).valueOrNull ??
            const <ExecutionEntityLink>[];
    final files =
        ref.watch(fileMetadataListProvider).valueOrNull ??
            const <ExecutionFileMetadata>[];
    ExecutionFileMetadata? syncedFile;
    for (final link in attachmentLinks) {
      if (link.relationType != 'attachment' ||
          link.targetType != 'file.metadata') {
        continue;
      }
      for (final file in files) {
        if (file.id == link.targetId) {
          syncedFile = file;
          break;
        }
      }
      if (syncedFile != null) break;
    }

    return DetailFrame(
      titleText: 'Inbox',
      actions: [
        IconButton(
          tooltip: current.important ? '取消重点' : '标记重点',
          onPressed: () =>
              ref.read(collectionCommandsProvider).toggleImportant(current),
          icon: Icon(
            current.important ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 19,
            color: current.important ? C.amber : C.muted,
          ),
        ),
        IconButton(
          tooltip: '编辑',
          onPressed: () =>
              _showMemoEditor(context, ref, kind: current.kind, memo: current),
          icon: const Icon(Icons.edit_outlined, size: 18),
        ),
      ],
      child: page([
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: visual.background,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(visual.icon, size: 21, color: visual.color),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _memoTitle(current),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(spacing: 6, runSpacing: 5, children: [
                      chip(visual.label, bg: Colors.white, fg: visual.color),
                      chip(
                        _memoUpdatedLabel(current.updatedAt),
                        bg: Colors.white,
                        fg: C.muted,
                      ),
                      if (current.status == ExecutionMemoStatus.archived)
                        chip('已归档', bg: Colors.white, fg: C.muted),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
        h('内容'),
        panel(
          SelectableText(
            current.content,
            style: const TextStyle(fontSize: 10.3, color: C.muted, height: 1.5),
          ),
        ),
        if (current.sourceUrl != null) ...[
          h('链接'),
          panel(
            SelectableText(
              current.sourceUrl!,
              style: const TextStyle(fontSize: 9.5, color: C.teal),
            ),
          ),
        ],
        if ({
          ExecutionMemoKind.image,
          ExecutionMemoKind.audio,
          ExecutionMemoKind.file,
        }.contains(current.kind)) ...[
          h('附件'),
          _MediaAttachmentCard(
            upload: upload,
            file: syncedFile,
            onRetry: upload == null
                ? null
                : () => ref
                    .read(mediaUploadControllerProvider.notifier)
                    .retryOne(upload!.id),
          ),
        ],
        if (current.isInbox) ...[
          h('整理'),
          Row(children: [
            Expanded(
              child: _InboxDestination(
                Icons.check_box_outlined,
                '转任务',
                C.p,
                C.ps,
                onTap: () async {
                  try {
                    final task = await ref
                        .read(collectionCommandsProvider)
                        .convertToTask(current);
                    if (context.mounted) {
                      Navigator.pop(context);
                      push(context, TaskDetail(task: task));
                    }
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$error')),
                      );
                    }
                  }
                },
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _InboxDestination(
                Icons.folder_outlined,
                '到项目',
                C.purple,
                C.purpleSoft,
                onTap: projects.isEmpty
                    ? null
                    : () => _chooseProjectForMemo(
                          context,
                          ref,
                          current,
                          projects,
                        ),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _InboxDestination(
                Icons.archive_outlined,
                '归档',
                C.muted,
                C.soft,
                onTap: () async {
                  await ref.read(collectionCommandsProvider).archive(current);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmDeleteMemo(context, ref, current),
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: const Text('删除'),
            ),
          ),
        ],
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }
}

class _InboxDestination extends StatelessWidget {
  const _InboxDestination(
    this.icon,
    this.label,
    this.color,
    this.background, {
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Opacity(
          opacity: onTap == null ? .45 : 1,
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 8.7,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _CollectionConflictCard extends ConsumerWidget {
  const _CollectionConflictCard({required this.conflict});

  final CollectionConflictUi conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: C.orangeSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '收集数据存在同步冲突',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              conflict.reason,
              style: const TextStyle(fontSize: 8.7, color: C.muted),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ref
                      .read(collectionCommandsProvider)
                      .keepServer(conflict.conflictId),
                  child: const Text('保留云端'),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: FilledButton(
                  onPressed: () => ref
                      .read(collectionCommandsProvider)
                      .keepLocal(conflict.conflictId),
                  child: const Text('保留本地'),
                ),
              ),
            ]),
          ],
        ),
      );
}

Future<void> _showMemoEditor(
  BuildContext context,
  WidgetRef ref, {
  required ExecutionMemoKind kind,
  ExecutionMemo? memo,
}) async {
  final titleController = TextEditingController(text: memo?.title ?? '');
  final contentController = TextEditingController(text: memo?.content ?? '');
  final urlController = TextEditingController(text: memo?.sourceUrl ?? '');
  var important = memo?.important ?? false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          20 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                memo == null
                    ? '新建${_memoVisual(kind).label}'
                    : '编辑${_memoVisual(kind).label}',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题（可选）',
                ),
              ),
              const SizedBox(height: 10),
              if (kind == ExecutionMemoKind.link) ...[
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: '链接',
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: contentController,
                autofocus: memo == null,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '内容',
                  hintText: '记录内容',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('标记为重点'),
                value: important,
                onChanged: (value) =>
                    setSheetState(() => important = value),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      if (memo == null) {
                        await ref.read(collectionCommandsProvider).create(
                              kind: kind,
                              title: titleController.text,
                              content: contentController.text,
                              sourceUrl: kind == ExecutionMemoKind.link
                                  ? urlController.text
                                  : null,
                              important: important,
                            );
                      } else {
                        await ref.read(collectionCommandsProvider).update(
                              memo: memo,
                              title: titleController.text,
                              content: contentController.text,
                              sourceUrl: kind == ExecutionMemoKind.link
                                  ? urlController.text
                                  : null,
                              important: important,
                              clearTitle:
                                  titleController.text.trim().isEmpty,
                              clearSourceUrl: kind == ExecutionMemoKind.link &&
                                  urlController.text.trim().isEmpty,
                            );
                      }
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    } catch (error) {
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text('$error')),
                        );
                      }
                    }
                  },
                  child: Text(memo == null ? '保存到 Inbox' : '保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  titleController.dispose();
  contentController.dispose();
  urlController.dispose();
}

Future<void> _chooseProjectForMemo(
  BuildContext context,
  WidgetRef ref,
  ExecutionMemo memo,
  List<ExecutionProject> projects,
) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        children: [
          const ListTile(
            title: Text(
              '整理到项目',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          for (final project in projects)
            ListTile(
              leading: const Icon(Icons.folder_outlined, color: C.purple),
              title: Text(project.title),
              subtitle: Text(project.status.wireValue),
              onTap: () async {
                try {
                  await ref
                      .read(collectionCommandsProvider)
                      .organizeToProject(memo, project.id);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) Navigator.pop(context);
                } catch (error) {
                  if (sheetContext.mounted) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      SnackBar(content: Text('$error')),
                    );
                  }
                }
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> _confirmDeleteMemo(
  BuildContext context,
  WidgetRef ref,
  ExecutionMemo memo,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除这条收集内容？'),
      content: const Text('删除会通过 Sync v1 同步为 tombstone。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(collectionCommandsProvider).delete(memo);
  if (context.mounted) Navigator.pop(context);
}

Future<void> _pickMediaForInbox(
  BuildContext context,
  WidgetRef ref,
  ExecutionMemoKind kind,
) async {
  try {
    final memo = await ref.read(mediaCommandsProvider).pickAndQueue(kind);
    if (memo != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('附件已保存到本地并加入上传队列')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

class _MediaAttachmentCard extends StatelessWidget {
  const _MediaAttachmentCard({
    required this.upload,
    required this.file,
    required this.onRetry,
  });

  final PendingMediaUpload? upload;
  final ExecutionFileMetadata? file;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final local = upload;
    final remote = file;
    final status = remote != null
        ? '已存云端'
        : switch (local?.status) {
            MediaUploadStatus.localOnly => '等待上传',
            MediaUploadStatus.pendingUpload => '等待对象存储',
            MediaUploadStatus.uploading => '上传中',
            MediaUploadStatus.failed => '上传失败',
            MediaUploadStatus.serverStored => '已存云端',
            null => '等待附件同步',
          };
    final color = remote != null || local?.status == MediaUploadStatus.serverStored
        ? C.green
        : local?.status == MediaUploadStatus.failed
            ? C.red
            : C.orange;
    final name = remote?.originalName ?? local?.originalName ?? '附件';
    final size = remote?.sizeBytes ?? local?.sizeBytes;
    final error = local?.errorMessage;

    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.attach_file_rounded, size: 17, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            chip(status, bg: color.withValues(alpha: .1), fg: color),
          ]),
          if (size != null) ...[
            const SizedBox(height: 5),
            Text(
              _fileSizeLabel(size),
              style: const TextStyle(fontSize: 8.5, color: C.muted),
            ),
          ],
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              error,
              style: const TextStyle(fontSize: 8.5, color: C.red),
            ),
          ],
          if (local?.status == MediaUploadStatus.failed && onRetry != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: const Text('重试上传'),
            ),
          ],
        ],
      ),
    );
  }
}

String _fileSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(1)} MB';
}

({IconData icon, String label, Color color, Color background}) _memoVisual(
  ExecutionMemoKind kind,
) {
  return switch (kind) {
    ExecutionMemoKind.text => (
        icon: Icons.notes_rounded,
        label: '文本',
        color: C.p,
        background: C.ps,
      ),
    ExecutionMemoKind.idea => (
        icon: Icons.lightbulb_outline_rounded,
        label: '想法',
        color: C.amber,
        background: C.amberSoft,
      ),
    ExecutionMemoKind.link => (
        icon: Icons.link_rounded,
        label: '链接',
        color: C.teal,
        background: C.tealSoft,
      ),
    ExecutionMemoKind.image => (
        icon: Icons.image_outlined,
        label: '图片',
        color: C.pink,
        background: C.pinkSoft,
      ),
    ExecutionMemoKind.audio => (
        icon: Icons.mic_none_rounded,
        label: '语音',
        color: C.purple,
        background: C.purpleSoft,
      ),
    ExecutionMemoKind.file => (
        icon: Icons.insert_drive_file_outlined,
        label: '文件',
        color: C.orange,
        background: C.orangeSoft,
      ),
  };
}

String _memoTitle(ExecutionMemo memo) {
  final title = memo.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final oneLine = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length <= 36 ? oneLine : '${oneLine.substring(0, 36)}…';
}

String _memoUpdatedLabel(String raw) {
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return raw;
  final now = DateTime.now();
  final diff = now.difference(value);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
  if (diff.inHours < 24) return '${diff.inHours}小时前';
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day - 1) {
    return '昨天';
  }
  return '${value.month}月${value.day}日';
}

class Review extends ConsumerStatefulWidget {
  const Review({super.key, this.reviewDate});

  final String? reviewDate;

  @override
  ConsumerState<Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<Review> {
  final bestThing = TextEditingController();
  final problem = TextEditingController();
  final tomorrowPriority = TextEditingController();
  final note = TextEditingController();

  int mood = 4;
  int energy = 3;
  bool saving = false;
  String? _hydratedToken;

  @override
  void dispose() {
    bestThing.dispose();
    problem.dispose();
    tomorrowPriority.dispose();
    note.dispose();
    super.dispose();
  }

  void _hydrate(DailyReview? review, String reviewDate) {
    final token = review == null
        ? 'empty:$reviewDate'
        : '${review.id}:${review.updatedAt}';
    if (_hydratedToken == token) return;
    _hydratedToken = token;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        mood = review?.mood ?? 4;
        energy = review?.energy ?? 3;
        bestThing.text = review?.bestThing ?? '';
        problem.text = review?.problem ?? '';
        tomorrowPriority.text = review?.tomorrowPriority ?? '';
        note.text = review?.note ?? '';
      });
    });
  }

  @override
  Widget build(BuildContext c) {
    final todayReviewDate = ref.watch(todayReviewDateProvider);
    final reviewDate = widget.reviewDate ?? todayReviewDate;
    final isToday = reviewDate == todayReviewDate;
    final reviewState = ref.watch(dailyReviewForDateProvider(reviewDate));
    final review = reviewState.valueOrNull;
    _hydrate(review, reviewDate);

    final taskState = ref.watch(taskListProvider);
    final tasks = taskState.valueOrNull ?? const <ExecutionTask>[];
    final focusState = ref.watch(focusSessionListProvider);
    final focusSessions =
        focusState.valueOrNull ?? const <ExecutionFocusSession>[];
    final liveStats = calculateReviewTaskStats(tasks, reviewDate);
    final liveFocusSeconds =
        calculateDailyFocusSeconds(focusSessions, reviewDate);
    final useLiveStats = isToday && taskState.hasValue;
    final useLiveFocus = isToday && focusState.hasValue;
    final completed = useLiveStats
        ? liveStats.completed
        : review?.completedTaskCount ?? 0;
    final total =
        useLiveStats ? liveStats.total : review?.totalTaskCount ?? 0;
    final score = useLiveStats
        ? liveStats.completionScore
        : review?.completionScore;
    final focusSeconds =
        useLiveFocus ? liveFocusSeconds : review?.focusSeconds ?? 0;
    final conflicts = ref.watch(dailyReviewConflictsProvider).valueOrNull ??
        const <DailyReviewConflictUi>[];

    return DetailFrame(
      titleText: _reviewDateLabel(reviewDate),
      child: page([
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title(isToday ? '今日复盘' : '历史复盘'),
                const SizedBox(height: 2),
                sub(
                  review == null
                      ? (isToday ? '今天过得怎么样？' : '这一天还没有保存复盘')
                      : '已保存，可继续查看或更新这一天的复盘',
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => push(c, const WeeklyReviewScreen()),
            icon: const Icon(Icons.date_range_outlined, size: 15),
            label: const Text('周复盘'),
          ),
          TextButton.icon(
            onPressed: () => push(c, const DailyReviewHistory()),
            icon: const Icon(Icons.history_rounded, size: 15),
            label: const Text('历史'),
          ),
          if (review != null)
            chip('已保存', bg: C.greenSoft, fg: C.green),
        ]),
        if (reviewState.hasError) ...[
          const SizedBox(height: 10),
          Text(
            '复盘数据读取失败：${reviewState.error}',
            style: const TextStyle(fontSize: 9.5, color: C.red),
          ),
        ],
        if (conflicts.isNotEmpty) ...[
          h('同步冲突'),
          for (final conflict in conflicts)
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${conflict.reviewDate ?? '未知日期'} 的复盘存在版本冲突',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conflict.serverDeleted
                        ? '云端版本已删除'
                        : conflict.reason,
                    style: const TextStyle(fontSize: 8.8, color: C.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => ref
                            .read(dailyReviewCommandsProvider)
                            .keepServer(conflict.conflictId),
                        child: const Text('保留云端'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => ref
                            .read(dailyReviewCommandsProvider)
                            .keepLocal(conflict.conflictId),
                        child: const Text('保留本地'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
        ],
        h('心情'),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(5, (i) {
            final value = i + 1;
            return InkWell(
              onTap: () => setState(() => mood = value),
              borderRadius: BorderRadius.circular(30),
              child: CircleAvatar(
                radius: 19,
                backgroundColor: value == mood ? C.pinkSoft : C.soft,
                child: Text(
                  ['☹', '🙁', '😐', '🙂', '😊'][i],
                  style: TextStyle(fontSize: value == mood ? 18 : 15),
                ),
              ),
            );
          }),
        ),
        h('精力'),
        Row(
          children: List.generate(5, (i) {
            final value = i + 1;
            final selected = value == energy;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i == 4 ? 0 : 6),
                child: InkWell(
                  onTap: () => setState(() => energy = value),
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? C.orangeSoft : C.soft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 13,
                          color: selected ? C.orange : C.muted,
                        ),
                        Text(
                          '$value',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: selected ? C.orange : C.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        h('今日完成'),
        Row(children: [
          Text(
            '$completed / $total Tasks',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          if (score != null)
            Text(
              '${(score * 100).round()}%',
              style: const TextStyle(
                fontSize: 10,
                color: C.green,
                fontWeight: FontWeight.w900,
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.timer_outlined, size: 14, color: C.purple),
          const SizedBox(width: 5),
          Text(
            '专注 ${_focusDuration(focusSeconds)}',
            style: const TextStyle(
              fontSize: 9.2,
              color: C.purple,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (focusState.isLoading && isToday) ...[
            const SizedBox(width: 6),
            const Text(
              '读取中…',
              style: TextStyle(fontSize: 8.2, color: C.muted),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(5)),
          child: LinearProgressIndicator(
            value: score ?? 0,
            minHeight: 6,
            backgroundColor: C.soft,
            color: C.green,
          ),
        ),
        if (taskState.isLoading) ...[
          const SizedBox(height: 5),
          const Text(
            '正在读取今日任务…',
            style: TextStyle(fontSize: 8.5, color: C.muted),
          ),
        ],
        h('今天做得好的事情'),
        TextField(
          controller: bestThing,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '记录今天值得保留的做法'),
        ),
        h('今天可以改进什么？'),
        TextField(
          controller: problem,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '记录阻碍、偏差或需要调整的地方'),
        ),
        h('明天最重要的一件事'),
        TextField(
          controller: tomorrowPriority,
          decoration: InputDecoration(
            hintText: isToday
                ? liveStats.tomorrowSuggestion ?? '写下明天唯一最重要的事'
                : review?.tomorrowPriority ?? '记录下一天的重点',
            prefixIcon: const Icon(Icons.flag_outlined, size: 17),
          ),
        ),
        h('补充记录'),
        TextField(
          controller: note,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '可选：其他想记住的事情'),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: saving
                ? null
                : () => _save(
                      c,
                      reviewDate: reviewDate,
                      completed: completed,
                      total: total,
                      score: score,
                      focusSeconds: focusSeconds,
                      tomorrowSuggestion:
                          isToday ? liveStats.tomorrowSuggestion : null,
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
                : Text(
                    review == null
                        ? (isToday ? '完成今日复盘' : '保存这天复盘')
                        : '更新复盘',
                  ),
          ),
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
    );
  }

  Future<void> _save(
    BuildContext context, {
    required String reviewDate,
    required int completed,
    required int total,
    required double? score,
    required int focusSeconds,
    required String? tomorrowSuggestion,
  }) async {
    setState(() => saving = true);
    try {
      final priority = tomorrowPriority.text.trim().isEmpty
          ? tomorrowSuggestion
          : tomorrowPriority.text.trim();
      await ref.read(dailyReviewCommandsProvider).save(
            reviewDate: reviewDate,
            mood: mood,
            energy: energy,
            completedTaskCount: completed,
            totalTaskCount: total,
            completionScore: score,
            focusSeconds: focusSeconds,
            bestThing: bestThing.text,
            problem: problem.text,
            tomorrowPriority: priority,
            note: note.text,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('今日复盘已保存并加入同步队列')),
        );
        Navigator.pop(context);
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

class DailyReviewHistory extends ConsumerWidget {
  const DailyReviewHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailyReviewListProvider);
    return DetailFrame(
      titleText: '复盘历史',
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
                    '每日复盘记录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '历史统计使用保存时快照，不会被后续任务修改覆盖',
                    style: TextStyle(fontSize: 8.8, color: C.muted),
                  ),
                ],
              ),
            ),
            chip('${reviews.length} 天', bg: C.purpleSoft, fg: C.purple),
          ]),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            panel(
              const Column(children: [
                Icon(Icons.history_toggle_off_rounded, color: C.muted),
                SizedBox(height: 6),
                Text(
                  '还没有历史复盘',
                  style: TextStyle(fontSize: 9.5, color: C.muted),
                ),
              ]),
              padding: const EdgeInsets.all(18),
            )
          else
            for (final review in reviews)
              _DailyReviewHistoryTile(
                review: review,
                onTap: () => push(
                  context,
                  DailyReviewHistoryDetail(review: review),
                ),
              ),
        ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
      ),
    );
  }
}

class _DailyReviewHistoryTile extends StatelessWidget {
  const _DailyReviewHistoryTile({
    required this.review,
    required this.onTap,
  });

  final DailyReview review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = review.completionScore;
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
          CircleAvatar(
            radius: 18,
            backgroundColor: C.pinkSoft,
            child: Text(
              _reviewMoodEmoji(review.mood),
              style: const TextStyle(fontSize: 16),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _reviewDateLabel(review.reviewDate),
                  style: const TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${review.completedTaskCount ?? 0} / ${review.totalTaskCount ?? 0} Tasks'
                  '${score == null ? '' : ' · ${(score * 100).round()}%'}'
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

class DailyReviewHistoryDetail extends StatelessWidget {
  const DailyReviewHistoryDetail({super.key, required this.review});

  final DailyReview review;

  @override
  Widget build(BuildContext context) => DetailFrame(
        titleText: _reviewDateLabel(review.reviewDate),
        child: page([
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: C.pinkSoft,
              child: Text(
                _reviewMoodEmoji(review.mood),
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '每日复盘',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '精力 ${review.energy ?? '-'} / 5 · 心情 ${review.mood ?? '-'} / 5',
                    style: const TextStyle(fontSize: 8.8, color: C.muted),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => push(
                context,
                Review(reviewDate: review.reviewDate),
              ),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('编辑'),
            ),
          ]),
          h('完成情况'),
          panel(
            Column(children: [
              Row(children: [
                Text(
                  '${review.completedTaskCount ?? 0} / ${review.totalTaskCount ?? 0} Tasks',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (review.completionScore != null)
                  Text(
                    '${(review.completionScore! * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: C.green,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.timer_outlined, size: 14, color: C.purple),
                const SizedBox(width: 5),
                Text(
                  '专注 ${_focusDuration(review.focusSeconds ?? 0)}',
                  style: const TextStyle(
                    fontSize: 9,
                    color: C.purple,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ]),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: review.completionScore ?? 0,
                  minHeight: 6,
                  backgroundColor: C.soft,
                  color: C.green,
                ),
              ),
            ]),
          ),
          if ((review.bestThing ?? '').isNotEmpty) ...[
            h('做得好的事情'),
            panel(Text(review.bestThing!)),
          ],
          if ((review.problem ?? '').isNotEmpty) ...[
            h('问题与改进'),
            panel(Text(review.problem!)),
          ],
          if ((review.tomorrowPriority ?? '').isNotEmpty) ...[
            h('下一天重点'),
            panel(
              Row(children: [
                const Icon(Icons.flag_outlined, size: 16, color: C.purple),
                const SizedBox(width: 8),
                Expanded(child: Text(review.tomorrowPriority!)),
              ]),
              color: C.purpleSoft,
            ),
          ],
          if ((review.note ?? '').isNotEmpty) ...[
            h('补充记录'),
            panel(Text(review.note!)),
          ],
        ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
      );
}

String _reviewMoodEmoji(int? mood) => switch (mood) {
      1 => '☹',
      2 => '🙁',
      3 => '😐',
      4 => '🙂',
      5 => '😊',
      _ => '·',
    };
String _reviewDateLabel(String value) {
  final date = DateTime.tryParse('${value}T00:00:00');
  if (date == null) return value;
  const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  return '${date.month}月${date.day}日 · 星期${weekdays[date.weekday - 1]}';
}

const _profileYellow = Color(0xffffc928);
const _profileYellowSoft = Color(0xfffff4bf);
const _profileInk = Color(0xff111111);
const _profileMuted = Color(0xff747474);
const _profileDivider = Color(0xffececec);

class Profile extends ConsumerWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider).valueOrNull;
    final devices = ref.watch(cloudDevicesProvider).valueOrNull ??
        const <CloudDeviceInstallation>[];
    final pending = ref.watch(taskPendingSyncCountProvider).valueOrNull ?? 0;
    final blocked = ref.watch(taskBlockedSyncCountProvider).valueOrNull ?? 0;
    final conflicts =
        ref.watch(syncUnresolvedConflictCountProvider).valueOrNull ?? 0;
    final package = ref.watch(packageInfoProvider).valueOrNull;

    final connected = session != null;
    final name = session?.displayName?.trim().isNotEmpty == true
        ? session!.displayName!
        : session?.email.split('@').first ?? 'LifeTrace';
    final accountLabel =
        connected ? session.email : '本地模式 · 未连接 LifeTrace Cloud';

    CloudDeviceInstallation? currentDevice;
    for (final device in devices) {
      if (device.current) {
        currentDevice = device;
        break;
      }
    }
    final deviceLabel = kIsWeb
        ? 'Web Preview'
        : currentDevice?.deviceName ?? '本机设备';

    final syncSummary = !connected
        ? '未连接 Cloud · 数据继续保存在本机'
        : blocked > 0
            ? '$blocked 项同步被阻塞'
            : conflicts > 0
                ? '$conflicts 项冲突待处理'
                : pending > 0
                    ? '$pending 项变更待同步'
                    : 'Cloud 已连接 · 当前无待同步变更';

    final deviceSummary = !connected
        ? '连接 Cloud 后管理登录设备与会话'
        : devices.isEmpty
            ? 'Cloud 设备列表暂未返回'
            : '${devices.length} 台 Cloud 设备 · 当前 $deviceLabel';

    return DetailFrame(
      titleText: '我的',
      backgroundColor: Colors.white,
      child: page(
        [
          _ProfileHero(
            name: name,
            accountLabel: accountLabel,
            connected: connected,
            deviceLabel: deviceLabel,
            onTap: () => push(context, const ProfileDetails()),
          ),
          const SizedBox(height: 22),
          _ProfileSection(
            title: '数据与同步',
            children: [
              _ProfileRow(
                icon: Icons.cloud_sync_outlined,
                title: '云端同步',
                subtitle: syncSummary,
                trailing: connected ? '已连接' : '未连接',
                onTap: () => push(context, const CloudConnection()),
              ),
              const Divider(height: 1, color: _profileDivider),
              const _ProfileRow(
                icon: Icons.storage_rounded,
                title: '本地数据',
                subtitle: 'Drift / SQLite · Local-first，核心数据优先写入本机',
                trailing: '本机优先',
              ),
              const Divider(height: 1, color: _profileDivider),
              _ProfileRow(
                icon: Icons.devices_outlined,
                title: '设备管理',
                subtitle: deviceSummary,
                onTap: () => push(context, const DeviceManagement()),
              ),
              const Divider(height: 1, color: _profileDivider),
              _ProfileRow(
                icon: Icons.privacy_tip_outlined,
                title: '数据导出与隐私',
                subtitle: '隐私策略 · Cloud 数据导出 · 账号删除',
                onTap: () => push(context, const DataManagement()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ProfileSection(
            title: '应用',
            children: [
              _ProfileRow(
                icon: Icons.notifications_none_rounded,
                title: '通知与提醒',
                subtitle: '任务、日历与专注通知',
                onTap: () => push(context, const NotificationSettings()),
              ),
              const Divider(height: 1, color: _profileDivider),
              _ProfileRow(
                icon: Icons.palette_outlined,
                title: '外观',
                subtitle: '界面密度与显示偏好',
                onTap: () => push(context, const AppearanceSettings()),
              ),
              const Divider(height: 1, color: _profileDivider),
              _ProfileRow(
                icon: Icons.tune_rounded,
                title: '应用设置',
                subtitle: '日历与本机通用偏好',
                onTap: () => push(context, const GeneralSettings()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ProfileSection(
            title: 'LifeTrace',
            children: [
              _ProfileRow(
                icon: Icons.person_outline_rounded,
                title: '个人资料',
                subtitle:
                    connected ? accountLabel : '连接 Cloud 后查看 LifeTrace Account',
                onTap: () => push(context, const ProfileDetails()),
              ),
              const Divider(height: 1, color: _profileDivider),
              _ProfileRow(
                icon: Icons.lock_outline_rounded,
                title: '账户与安全',
                subtitle: '密码、会话与全部设备退出',
                onTap: () => push(context, const AccountSecurity()),
              ),
              const Divider(height: 1, color: _profileDivider),
              _ProfileRow(
                icon: Icons.cloud_outlined,
                title: 'LifeTrace Cloud',
                subtitle:
                    connected ? '查看连接与同步协议状态' : '连接你的 LifeTrace Cloud',
                onTap: () => push(context, const CloudConnection()),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _ProfileSection(
            title: '其他',
            children: [
              _ProfileRow(
                icon: Icons.info_outline_rounded,
                title: '关于 LifeTrace',
                subtitle: '版本、架构与开源许可',
                onTap: () => push(context, const AboutLifeTrace()),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              package == null
                  ? 'LifeTrace Execute'
                  : 'LifeTrace Execute · v${package.version}',
              style: const TextStyle(
                fontSize: 9,
                color: _profileMuted,
                fontWeight: FontWeight.w600,
                letterSpacing: .2,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Local-first · LifeTrace Cloud',
              style: TextStyle(fontSize: 8.5, color: Color(0xffa0a0a0)),
            ),
          ),
        ],
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.accountLabel,
    required this.connected,
    required this.deviceLabel,
    required this.onTap,
  });

  final String name;
  final String accountLabel;
  final bool connected;
  final String deviceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: _profileInk,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _profileYellow,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 27,
                        color: _profileInk,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            accountLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: Color(0xffbdbdbd),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xff8f8f8f),
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  color: const Color(0xff303030),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    const _ProfileHeroStatus(
                      icon: Icons.check_circle_rounded,
                      label: '本地数据正常',
                      active: true,
                    ),
                    const SizedBox(width: 14),
                    _ProfileHeroStatus(
                      icon: connected
                          ? Icons.cloud_done_rounded
                          : Icons.cloud_off_outlined,
                      label: connected ? 'Cloud 已连接' : 'Cloud 未连接',
                      active: connected,
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        deviceLabel,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 8.8,
                          color: Color(0xffa8a8a8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

}

class _ProfileHeroStatus extends StatelessWidget {
  const _ProfileHeroStatus({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: active ? _profileYellow : const Color(0xff777777),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.6,
              color: active ? Colors.white : const Color(0xff9a9a9a),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: _profileInk,
                fontWeight: FontWeight.w900,
                letterSpacing: .1,
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: _profileDivider),
                bottom: BorderSide(color: _profileDivider),
              ),
            ),
            child: Column(children: children),
          ),
        ],
      );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: _profileYellowSoft,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: _profileInk),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.8,
                    color: _profileInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8.7,
                    color: _profileMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: 8.5,
                color: _profileMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: Color(0xffa5a5a5),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class CloudConnection extends ConsumerStatefulWidget {
  const CloudConnection({super.key});

  @override
  ConsumerState<CloudConnection> createState() => _CloudConnectionState();
}

class _CloudConnectionState extends ConsumerState<CloudConnection> {
  final baseUrl = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final deviceName = TextEditingController(text: 'Android Device');
  bool busy = false;
  String? error;

  @override
  void dispose() {
    baseUrl.dispose();
    email.dispose();
    password.dispose();
    deviceName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final sessionState = ref.watch(currentSessionProvider);
    final session = sessionState.valueOrNull;
    return DetailFrame(
      titleText: 'LifeTrace Cloud',
      child: page([
        if (sessionState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (session != null)
          ..._connected(c, session)
        else
          ..._disconnected(c),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 18)),
    );
  }

  List<Widget> _connected(BuildContext c, dynamic session) {
    final syncState = ref.watch(taskSyncControllerProvider);
    final pending = ref.watch(taskPendingSyncCountProvider).valueOrNull ?? 0;
    final blocked = ref.watch(taskBlockedSyncCountProvider).valueOrNull ?? 0;
    final conflicts =
        ref.watch(syncUnresolvedConflictCountProvider).valueOrNull ?? 0;
    return [
      Row(children: [
        const CircleAvatar(
          radius: 19,
          backgroundColor: C.greenSoft,
          child: Icon(Icons.cloud_done_rounded, color: C.green, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Cloud 已连接',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
            Text(
              session.email as String,
              style: const TextStyle(fontSize: 9.5, color: C.muted),
            ),
          ]),
        ),
      ]),
      h('连接'),
      panel(
        Column(children: [
          _InfoRow('服务地址', session.baseUrl as String),
          const Divider(height: 1),
          _InfoRow('会话', session.sessionId as String),
          const Divider(height: 1),
          _InfoRow('协议', 'Sync v${session.protocolVersion} · Schema ${session.schemaVersion}'),
        ]),
      ),
      h('执行数据同步'),
      Row(children: [
        chip('待上传 $pending', bg: pending > 0 ? C.ps : C.soft, fg: pending > 0 ? C.p : C.muted),
        const SizedBox(width: 6),
        chip('阻塞 $blocked', bg: blocked > 0 ? const Color(0xffffe9e9) : C.soft, fg: blocked > 0 ? C.red : C.muted),
        const SizedBox(width: 6),
        chip('冲突 $conflicts', bg: conflicts > 0 ? const Color(0xfffff3df) : C.soft, fg: conflicts > 0 ? C.orange : C.muted),
      ]),
      if (syncState.hasError) ...[
        const SizedBox(height: 9),
        Text(
          '同步失败：${syncState.error}。本地任务仍保存在设备中。',
          style: const TextStyle(fontSize: 9.5, color: C.red),
        ),
      ],
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: syncState.isLoading
              ? null
              : () => ref.read(taskSyncControllerProvider.notifier).syncNow(),
          icon: syncState.isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.sync_rounded, size: 17),
          label: Text(syncState.isLoading ? '正在同步' : '立即同步'),
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: busy ? null : _logout,
          child: const Text('断开连接'),
        ),
      ),
    ];
  }

  List<Widget> _disconnected(BuildContext c) => [
        const Text(
          '连接你的 LifeTrace Cloud',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        const Text(
          '执行数据采用 Local-first；登录后会执行 Snapshot → Push → Pull，并处理版本冲突。',
          style: TextStyle(fontSize: 10, color: C.muted, height: 1.4),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: baseUrl,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Cloud 地址',
            hintText: 'https://your-cloud.example.com',
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '邮箱'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: password,
          obscureText: true,
          enableSuggestions: false,
          autocorrect: false,
          decoration: const InputDecoration(labelText: '密码'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: deviceName,
          decoration: const InputDecoration(labelText: '设备名称'),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!, style: const TextStyle(fontSize: 9.5, color: C.red)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: busy ? null : _login,
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('连接 Cloud'),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '仅接受 HTTPS 服务 origin，不要填写 /api/v1/... 路径。凭据使用平台安全存储保存。',
          style: TextStyle(fontSize: 8.8, color: C.muted),
        ),
      ];

  Future<void> _login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(cloudCommandsProvider).login(
            baseUrl: baseUrl.text,
            email: email.text,
            password: password.text,
            deviceName: deviceName.text.trim().isEmpty ? 'Android Device' : deviceName.text.trim(),
          );
      await ref.read(taskSyncControllerProvider.notifier).syncNow();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(cloudCommandsProvider).logout();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          SizedBox(
            width: 56,
            child: Text(label, style: const TextStyle(fontSize: 9.5, color: C.muted)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      );
}

class DetailFrame extends StatelessWidget {
  const DetailFrame({
    required this.child,
    this.titleText = '',
    this.leading = Icons.arrow_back,
    this.actions = const [],
    this.backgroundColor = C.bg,
    super.key,
  });

  final Widget child;
  final String titleText;
  final IconData leading;
  final List<Widget> actions;
  final Color backgroundColor;

  @override
  Widget build(BuildContext c) => Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(children: [
            SizedBox(
              height: 42,
              child: Row(children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(c),
                  icon: Icon(leading, size: 18),
                ),
                Expanded(
                  child: Text(
                    titleText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ),
                const SizedBox(width: 4),
              ]),
            ),
            Expanded(child: child),
            const SizedBox(height: 5),
          ]),
        ),
      );
}

void push(BuildContext c, Widget w) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => w));
