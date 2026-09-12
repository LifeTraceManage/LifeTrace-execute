// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

part of 'main.dart';

class Focus extends StatefulWidget { const Focus({super.key}); @override State<Focus> createState()=>_FocusState(); }
class _FocusState extends State<Focus>{ static const total=1500; int left=total; Timer? t; bool run=true; @override void dispose(){t?.cancel();super.dispose();} void toggle(){if(run){t?.cancel();setState(()=>run=false);}else{t=Timer.periodic(const Duration(seconds:1),(_){if(left>0)setState(()=>left--);});setState(()=>run=true);}} String get ts=>'${(left~/60).toString().padLeft(2,'0')}:${(left%60).toString().padLeft(2,'0')}'; @override Widget build(BuildContext c)=>DetailFrame(titleText:'专注中',leading:Icons.close,actions:const [Icon(Icons.more_vert_rounded,size:19)],child:page([
  const SizedBox(height:12),Center(child:SizedBox(width:208,height:208,child:Stack(fit:StackFit.expand,children:[const CircularProgressIndicator(value:.86,strokeWidth:8,color:C.purple,backgroundColor:C.purpleSoft,strokeCap:StrokeCap.round),Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(ts,style:const TextStyle(fontSize:37,fontWeight:FontWeight.w900,letterSpacing:-1)),const SizedBox(height:4),const Text('🌿 专注工作',style:TextStyle(fontSize:10,color:C.muted))]))]))),
  const SizedBox(height:15),panel(const Row(children:[Icon(Icons.favorite_rounded,color:C.red,size:14),SizedBox(width:7),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('完成论文实验设计',style:TextStyle(fontSize:11.5,fontWeight:FontWeight.w800)),Text('Academic Research · P1',style:TextStyle(fontSize:9,color:C.muted))]))]),color:C.purpleSoft,padding:const EdgeInsets.all(10)),
  const SizedBox(height:18),Row(mainAxisAlignment:MainAxisAlignment.center,children:[_RoundAction(Icons.replay_rounded,'放弃',()=>setState(()=>left=total)),const SizedBox(width:24),InkWell(onTap:toggle,child:CircleAvatar(radius:29,backgroundColor:C.purple,child:Icon(run?Icons.pause_rounded:Icons.play_arrow_rounded,color:Colors.white,size:30))),const SizedBox(width:24),_RoundAction(Icons.skip_next_rounded,'跳过',()=>Navigator.pop(c))]),
  const SizedBox(height:20),const Row(children:[Expanded(child:_StatBox('今日专注','2h 15m')),SizedBox(width:7),Expanded(child:_StatBox('番茄次数','4')),SizedBox(width:7),Expanded(child:_StatBox('连续天数','7'))]),
  const SizedBox(height:12),Row(children:[Expanded(child:panel(const Column(children:[Icon(Icons.music_note_outlined,size:16,color:C.muted),SizedBox(height:4),Text('白噪音',style:TextStyle(fontSize:9)),Text('放松',style:TextStyle(fontSize:8,color:C.p))]),padding:const EdgeInsets.symmetric(vertical:9))),const SizedBox(width:7),Expanded(child:panel(const Column(children:[Icon(Icons.center_focus_strong_outlined,size:16,color:C.muted),SizedBox(height:4),Text('专注模式',style:TextStyle(fontSize:9)),Text('开启',style:TextStyle(fontSize:8,color:C.p))]),padding:const EdgeInsets.symmetric(vertical:9))),const SizedBox(width:7),Expanded(child:panel(const Column(children:[Icon(Icons.notifications_none_rounded,size:16,color:C.muted),SizedBox(height:4),Text('提醒',style:TextStyle(fontSize:9)),Text('关闭',style:TextStyle(fontSize:8,color:C.muted))]),padding:const EdgeInsets.symmetric(vertical:9)))])
],padding:const EdgeInsets.fromLTRB(16,0,16,15)));
}
class _RoundAction extends StatelessWidget{const _RoundAction(this.icon,this.label,this.tap);final IconData icon;final String label;final VoidCallback tap;@override Widget build(BuildContext c)=>Column(children:[InkWell(onTap:tap,child:CircleAvatar(radius:20,backgroundColor:C.soft,child:Icon(icon,size:19,color:C.ink))),const SizedBox(height:5),Text(label,style:const TextStyle(fontSize:8.5,color:C.muted))]);}
class _StatBox extends StatelessWidget{const _StatBox(this.label,this.value);final String label,value;@override Widget build(BuildContext c)=>panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:const TextStyle(fontSize:8.5,color:C.muted)),const SizedBox(height:3),Text(value,style:const TextStyle(fontSize:15,fontWeight:FontWeight.w900))]),padding:const EdgeInsets.all(9));}

class Projects extends ConsumerStatefulWidget {
  const Projects({super.key});

  @override
  ConsumerState<Projects> createState() => _ProjectsState();
}

class _ProjectsState extends ConsumerState<Projects> {
  int filter = 0;

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectListProvider);
    final tasks = ref.watch(taskListProvider).valueOrNull ?? const <ExecutionTask>[];
    return page([
      Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title('项目'), sub('真实任务进度 · Local-first')],
          ),
        ),
        IconButton(
          tooltip: '新建项目',
          onPressed: () => _editProject(context, ref),
          icon: const Icon(Icons.add, size: 19),
        ),
      ]),
      const SizedBox(height: 9),
      _Tabs(
        labels: const ['全部', '进行中', '已暂停', '已完成', '已归档'],
        selected: filter,
        onTap: (value) => setState(() => filter = value),
      ),
      const SizedBox(height: 12),
      projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => panel(
          Text('项目加载失败：$error',
              style: const TextStyle(fontSize: 9.5, color: C.red)),
          padding: const EdgeInsets.all(12),
        ),
        data: (items) {
          final visible = items
              .where((item) => _projectMatchesFilter(item, filter))
              .toList(growable: false);
          if (visible.isEmpty) {
            return panel(
              Column(children: [
                const Icon(Icons.folder_open_rounded, color: C.muted),
                const SizedBox(height: 7),
                Text(
                  items.isEmpty ? '还没有项目' : '当前筛选没有项目',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  '项目进度直接由真实任务完成状态推导。',
                  style: TextStyle(fontSize: 8.8, color: C.muted),
                ),
              ]),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            );
          }
          return Column(children: [
            for (var i = 0; i < visible.length; i++) ...[
              _ProjectCard(
                project: visible[i],
                tasks: tasks
                    .where((task) => task.projectId == visible[i].id)
                    .toList(growable: false),
                onTap: () => push(
                  context,
                  ProjectDetail(projectId: visible[i].id),
                ),
              ),
              if (i != visible.length - 1) const SizedBox(height: 9),
            ],
          ]);
        },
      ),
    ]);
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.tasks,
    required this.onTap,
  });

  final ExecutionProject project;
  final List<ExecutionTask> tasks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _projectColor(project);
    final done = tasks.where((task) => task.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: .16)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.folder_rounded, size: 21, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    project.description ?? _projectStatusText(project.status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9, color: C.muted),
                  ),
                ],
              ),
            ),
            chip(
              _projectStatusText(project.status),
              bg: color.withValues(alpha: .10),
              fg: color,
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: .10),
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.checklist_rounded, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              '${tasks.length} 个任务 · $done 已完成 · ${(progress * 100).round()}%',
              style: const TextStyle(fontSize: 8.7, color: C.muted),
            ),
            const Spacer(),
            const Icon(Icons.flag_outlined, size: 11, color: C.muted),
            const SizedBox(width: 3),
            Text(
              _projectDate(project.dueAt),
              style: const TextStyle(fontSize: 8.7, color: C.muted),
            ),
          ]),
        ]),
      ),
    );
  }
}

class ProjectDetail extends ConsumerWidget {
  const ProjectDetail({required this.projectId, super.key});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectListProvider);
    final tasksState = ref.watch(taskListProvider);
    final project = _findProject(projects.valueOrNull, projectId);

    if (project == null) {
      return DetailFrame(
        titleText: '项目详情',
        child: projects.isLoading
            ? const Center(child: CircularProgressIndicator())
            : page([
                panel(
                  const Text(
                    '项目不存在或已删除。',
                    style: TextStyle(fontSize: 10, color: C.muted),
                  ),
                  padding: const EdgeInsets.all(16),
                ),
              ]),
      );
    }

    final tasks = (tasksState.valueOrNull ?? const <ExecutionTask>[])
        .where((task) => task.projectId == project.id)
        .toList(growable: false);
    final done = tasks.where((task) => task.isDone).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    final color = _projectColor(project);
    final conflicts = (ref.watch(projectConflictsProvider).valueOrNull ??
            const <ProjectConflictUi>[])
        .where((item) => item.projectId == project.id)
        .toList(growable: false);

    return DetailFrame(
      titleText: '项目详情',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, size: 19),
          onSelected: (value) async {
            if (value == 'edit') {
              await _editProject(context, ref, project: project);
            } else if (value == 'delete') {
              await _deleteProject(context, ref, project);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑项目')),
            PopupMenuItem(value: 'delete', child: Text('删除项目')),
          ],
        ),
      ],
      child: page([
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            color: color.withValues(alpha: .08),
            border: Border.all(color: color.withValues(alpha: .14)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    project.description ?? '暂无项目描述',
                    style: const TextStyle(fontSize: 9, color: C.muted),
                  ),
                  const SizedBox(height: 9),
                  Wrap(spacing: 6, children: [
                    chip(
                      _projectStatusText(project.status),
                      bg: Colors.white,
                      fg: color,
                    ),
                    chip(
                      '截止 ${_projectDate(project.dueAt)}',
                      bg: Colors.white,
                      fg: C.muted,
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 68,
              height: 68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    color: color,
                    backgroundColor: Colors.white,
                  ),
                  Center(
                    child: Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ),
        if (conflicts.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ProjectConflictCard(conflict: conflicts.first),
        ],
        h('进度'),
        Row(children: [
          Expanded(child: _ProjectStat('$done', '已完成', C.green)),
          const SizedBox(width: 7),
          Expanded(child: _ProjectStat('${tasks.length - done}', '待完成', C.orange)),
          const SizedBox(width: 7),
          Expanded(child: _ProjectStat('${tasks.length}', '任务总数', color)),
        ]),
        h('操作'),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _createProjectTask(context, ref, project),
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: const Text('新增任务'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _editProject(context, ref, project: project),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('编辑项目'),
            ),
          ),
        ]),
        h('项目任务'),
        if (tasksState.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (tasks.isEmpty)
          panel(
            const Text(
              '暂无归属到该项目的任务。',
              style: TextStyle(fontSize: 9.5, color: C.muted),
            ),
            padding: const EdgeInsets.all(12),
          )
        else
          for (final task in tasks)
            InkWell(
              onTap: () => push(context, TaskDetail(task: task)),
              child: panel(
                Row(children: [
                  Icon(
                    task.isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: task.isDone ? C.green : color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _taskMeta(task),
                          style: const TextStyle(
                            fontSize: 8.5,
                            color: C.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: C.muted,
                  ),
                ]),
                padding: const EdgeInsets.all(10),
              ),
            ),
        h('项目信息'),
        panel(
          Column(children: [
            _ProjectInfo('状态', _projectStatusText(project.status)),
            const Divider(height: 1),
            _ProjectInfo('开始', _projectDate(project.startAt)),
            const Divider(height: 1),
            _ProjectInfo('截止', _projectDate(project.dueAt)),
          ]),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }
}

class _ProjectStat extends StatelessWidget {
  const _ProjectStat(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 8.2, color: C.muted)),
          ],
        ),
      );
}

class _ProjectInfo extends StatelessWidget {
  const _ProjectInfo(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          Text(label, style: const TextStyle(fontSize: 9, color: C.muted)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
          ),
        ]),
      );
}

class _ProjectConflictCard extends ConsumerWidget {
  const _ProjectConflictCard({required this.conflict});
  final ProjectConflictUi conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: C.orangeSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            '项目存在同步冲突',
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
                    .read(projectCommandsProvider)
                    .keepServer(conflict.conflictId),
                child: const Text('保留云端'),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: FilledButton(
                onPressed: () => ref
                    .read(projectCommandsProvider)
                    .keepLocal(conflict.conflictId),
                child: const Text('保留本地'),
              ),
            ),
          ]),
        ]),
      );
}

Future<void> _editProject(
  BuildContext context,
  WidgetRef ref, {
  ExecutionProject? project,
}) async {
  final titleController = TextEditingController(text: project?.title ?? '');
  final descriptionController =
      TextEditingController(text: project?.description ?? '');
  var status = project?.status ?? ExecutionProjectStatus.active;
  DateTime? startAt = DateTime.tryParse(project?.startAt ?? '')?.toLocal();
  DateTime? dueAt = DateTime.tryParse(project?.dueAt ?? '')?.toLocal();

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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleController,
              autofocus: project == null,
              decoration: const InputDecoration(labelText: '项目标题'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '描述'),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<ExecutionProjectStatus>(
              initialValue: status,
              decoration: const InputDecoration(labelText: '状态'),
              items: ExecutionProjectStatus.values
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(_projectStatusText(item)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setSheetState(() => status = value);
              },
            ),
            const SizedBox(height: 10),
            _DateField(
              label: '开始时间',
              value: startAt,
              onPick: () async {
                final value = await _pickDateTime(sheetContext, startAt);
                if (value != null) setSheetState(() => startAt = value);
              },
              onClear: startAt == null
                  ? null
                  : () => setSheetState(() => startAt = null),
            ),
            const SizedBox(height: 8),
            _DateField(
              label: '截止时间',
              value: dueAt,
              onPick: () async {
                final value = await _pickDateTime(sheetContext, dueAt);
                if (value != null) setSheetState(() => dueAt = value);
              },
              onClear: dueAt == null
                  ? null
                  : () => setSheetState(() => dueAt = null),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  try {
                    final commands = ref.read(projectCommandsProvider);
                    if (project == null) {
                      await commands.create(
                        title: titleController.text,
                        description: descriptionController.text,
                        status: status,
                        startAt: startAt?.toUtc().toIso8601String(),
                        dueAt: dueAt?.toUtc().toIso8601String(),
                      );
                    } else {
                      await commands.update(
                        project: project,
                        title: titleController.text,
                        description: descriptionController.text,
                        status: status,
                        startAt: startAt?.toUtc().toIso8601String(),
                        dueAt: dueAt?.toUtc().toIso8601String(),
                        clearDescription:
                            descriptionController.text.trim().isEmpty,
                        clearStartAt:
                            startAt == null && project.startAt != null,
                        clearDueAt: dueAt == null && project.dueAt != null,
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
                child: Text(project == null ? '创建项目' : '保存项目'),
              ),
            ),
          ]),
        ),
      ),
    ),
  );
  titleController.dispose();
  descriptionController.dispose();
}

Future<void> _createProjectTask(
  BuildContext context,
  WidgetRef ref,
  ExecutionProject project,
) async {
  final titleController = TextEditingController();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        20 + MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(labelText: '新增到 ${project.title}'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              try {
                await ref.read(taskCommandsProvider).create(
                      title: titleController.text,
                      projectId: project.id,
                    );
                if (sheetContext.mounted) Navigator.pop(sheetContext);
              } catch (error) {
                if (sheetContext.mounted) {
                  ScaffoldMessenger.of(sheetContext).showSnackBar(
                    SnackBar(content: Text('$error')),
                  );
                }
              }
            },
            child: const Text('创建任务'),
          ),
        ),
      ]),
    ),
  );
  titleController.dispose();
}

Future<void> _deleteProject(
  BuildContext context,
  WidgetRef ref,
  ExecutionProject project,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('删除项目'),
      content: const Text('项目会删除，已归属任务会自动移出项目并进入同步 Outbox。'),
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
  try {
    await ref.read(projectCommandsProvider).delete(project);
    if (context.mounted) Navigator.maybePop(context);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }
}

ExecutionProject? _findProject(
  List<ExecutionProject>? projects,
  String projectId,
) {
  if (projects == null) return null;
  for (final project in projects) {
    if (project.id == projectId) return project;
  }
  return null;
}

bool _projectMatchesFilter(ExecutionProject project, int filter) =>
    switch (filter) {
      1 => project.status == ExecutionProjectStatus.active,
      2 => project.status == ExecutionProjectStatus.paused,
      3 => project.status == ExecutionProjectStatus.completed,
      4 => project.status == ExecutionProjectStatus.archived,
      _ => true,
    };

String _projectStatusText(ExecutionProjectStatus status) => switch (status) {
      ExecutionProjectStatus.active => '进行中',
      ExecutionProjectStatus.paused => '已暂停',
      ExecutionProjectStatus.completed => '已完成',
      ExecutionProjectStatus.archived => '已归档',
    };

Color _projectColor(ExecutionProject project) {
  const colors = [C.orange, C.p, C.teal, C.purple, C.sky];
  final score = project.id.codeUnits.fold<int>(0, (sum, value) => sum + value);
  return colors[score % colors.length];
}

String _projectDate(String? raw) {
  if (raw == null || raw.isEmpty) return '未设置';
  final value = DateTime.tryParse(raw)?.toLocal();
  if (value == null) return raw;
  return '${value.month}月${value.day}日';
}

class Calendar extends ConsumerStatefulWidget {
  const Calendar({super.key});

  @override
  ConsumerState<Calendar> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<Calendar> {
  late DateTime visibleMonth;
  late DateTime selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    visibleMonth = calendarMonthStart(now);
    selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final eventsState = ref.watch(calendarEventListProvider);
    final events = eventsState.valueOrNull ?? const <ExecutionCalendarEvent>[];
    final tasks =
        ref.watch(taskListProvider).valueOrNull ?? const <ExecutionTask>[];
    final importantDateState = ref.watch(importantDateListProvider);
    final importantDates =
        importantDateState.valueOrNull ?? const <ExecutionImportantDate>[];
    final conflicts = ref.watch(calendarConflictsProvider).valueOrNull ??
        const <CalendarConflictUi>[];
    final reminderConflicts =
        ref.watch(reminderConflictsProvider).valueOrNull ??
            const <ReminderConflictUi>[];
    final importantDateConflicts =
        ref.watch(importantDateConflictsProvider).valueOrNull ??
            const <ImportantDateConflictUi>[];
    final grid = calendarMonthGrid(visibleMonth);
    final agenda =
        _calendarAgendaFor(selectedDate, events, tasks, importantDates);

    bool hasContent(DateTime date) =>
        events.any(
          (event) => eventTouchesLocalDate(
            startAt: event.startAt,
            endAt: event.endAt,
            date: date,
          ),
        ) ||
        tasks.any(
          (task) =>
              instantFallsOnLocalDate(task.scheduledAt, date) ||
              instantFallsOnLocalDate(task.dueAt, date),
        ) ||
        importantDates.any((item) {
          final occurrence =
              importantDateOccurrenceForSolarYear(item, date.year);
          return occurrence != null && sameCalendarDate(occurrence, date);
        });

    return Scaffold(
      backgroundColor: C.bg,
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: C.orange,
        foregroundColor: Colors.white,
        onPressed: () => _editCalendarEvent(
          context,
          ref,
          initialDate: selectedDate,
        ),
        child: const Icon(Icons.add),
      ),
      body: page([
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title('日历'), sub('日程与任务时间统一视图')],
            ),
          ),
          TextButton.icon(
            onPressed: () => _manageImportantDates(context, ref),
            icon: const Icon(Icons.cake_outlined, size: 15),
            label: const Text('重要日期'),
          ),
          TextButton(
            onPressed: () {
              final now = DateTime.now();
              setState(() {
                visibleMonth = calendarMonthStart(now);
                selectedDate = DateTime(now.year, now.month, now.day);
              });
            },
            child: const Text('今天'),
          ),
        ]),
        if (conflicts.isNotEmpty) ...[
          const SizedBox(height: 8),
          _CalendarConflictCard(conflict: conflicts.first),
        ],
        if (reminderConflicts.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ReminderConflictBanner(conflict: reminderConflicts.first),
        ],
        if (importantDateConflicts.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ImportantDateConflictCard(conflict: importantDateConflicts.first),
        ],
        const SizedBox(height: 8),
        Row(children: [
          IconButton(
            tooltip: '上个月',
            onPressed: () => setState(() {
              visibleMonth = previousCalendarMonth(visibleMonth);
              selectedDate = DateTime(
                visibleMonth.year,
                visibleMonth.month,
                1,
              );
            }),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                '${visibleMonth.year}年 ${visibleMonth.month}月',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '下个月',
            onPressed: () => setState(() {
              visibleMonth = nextCalendarMonth(visibleMonth);
              selectedDate = DateTime(
                visibleMonth.year,
                visibleMonth.month,
                1,
              );
            }),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
        Row(
          children: const ['一', '二', '三', '四', '五', '六', '日']
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 8, color: C.muted),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.border),
          ),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 40,
            ),
            itemCount: grid.length,
            itemBuilder: (_, index) {
              final date = grid[index];
              if (date == null) return const SizedBox.shrink();
              final selected = sameCalendarDate(date, selectedDate);
              final marked = hasContent(date);
              final today = sameCalendarDate(date, DateTime.now());
              return InkWell(
                onTap: () => setState(() => selectedDate = date),
                child: Center(
                  child: Container(
                    width: 31,
                    height: 35,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? C.orange : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: today && !selected
                          ? Border.all(color: C.orangeSoft, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight:
                                selected ? FontWeight.w900 : FontWeight.w600,
                            color: selected ? Colors.white : C.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: marked
                                ? (selected ? Colors.white : C.orange)
                                : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        h(_calendarDateHeader(selectedDate)),
        if (eventsState.isLoading || importantDateState.isLoading)
          const Center(child: CircularProgressIndicator())
        else if (agenda.isEmpty)
          panel(
            const Text(
              '当天没有日程、任务或重要日期。',
              style: TextStyle(fontSize: 9.5, color: C.muted),
            ),
            padding: const EdgeInsets.all(14),
          )
        else
          for (final item in agenda)
            _CalendarAgendaTile(
              item: item,
              onTap: () {
                final event = item.event;
                if (event != null) {
                  _editCalendarEvent(
                    context,
                    ref,
                    initialDate: selectedDate,
                    event: event,
                  );
                } else if (item.task != null) {
                  push(context, TaskDetail(task: item.task));
                } else if (item.importantDate != null) {
                  _editImportantDate(
                    context,
                    ref,
                    item: item.importantDate,
                  );
                }
              },
            ),
      ]),
    );
  }
}

class _CalendarAgendaItem {
  const _CalendarAgendaItem({
    required this.sortAt,
    required this.time,
    required this.title,
    required this.meta,
    required this.color,
    this.event,
    this.task,
    this.importantDate,
  });

  final DateTime sortAt;
  final String time;
  final String title;
  final String meta;
  final Color color;
  final ExecutionCalendarEvent? event;
  final ExecutionTask? task;
  final ExecutionImportantDate? importantDate;
}

List<_CalendarAgendaItem> _calendarAgendaFor(
  DateTime date,
  List<ExecutionCalendarEvent> events,
  List<ExecutionTask> tasks,
  List<ExecutionImportantDate> importantDates,
) {
  final items = <_CalendarAgendaItem>[];

  for (final event in events) {
    if (!eventTouchesLocalDate(
      startAt: event.startAt,
      endAt: event.endAt,
      date: date,
    )) {
      continue;
    }
    final start = DateTime.parse(event.startAt).toLocal();
    items.add(
      _CalendarAgendaItem(
        sortAt: event.allDay
            ? DateTime(date.year, date.month, date.day)
            : start,
        time: event.allDay ? '全天' : _calendarTime(start),
        title: event.title,
        meta: [
          '日程',
          if (event.location != null) event.location!,
        ].join(' · '),
        color: C.orange,
        event: event,
      ),
    );
  }

  for (final importantDate in importantDates) {
    final occurrence =
        importantDateOccurrenceForSolarYear(importantDate, date.year);
    if (occurrence == null || !sameCalendarDate(occurrence, date)) continue;
    items.add(
      _CalendarAgendaItem(
        sortAt: DateTime(date.year, date.month, date.day),
        time: '重要',
        title: importantDate.title,
        meta:
            '重要日期 · ${_importantDateKindText(importantDate.kind)} · ${_importantDateCalendarText(importantDate)}',
        color: C.pink,
        importantDate: importantDate,
      ),
    );
  }

  for (final task in tasks) {
    final scheduled = DateTime.tryParse(task.scheduledAt ?? '')?.toLocal();
    if (scheduled != null && sameCalendarDate(scheduled, date)) {
      items.add(
        _CalendarAgendaItem(
          sortAt: scheduled,
          time: _calendarTime(scheduled),
          title: task.title,
          meta: '任务 · 已安排',
          color: C.p,
          task: task,
        ),
      );
    }

    final due = DateTime.tryParse(task.dueAt ?? '')?.toLocal();
    if (due != null && sameCalendarDate(due, date)) {
      items.add(
        _CalendarAgendaItem(
          sortAt: due,
          time: _calendarTime(due),
          title: task.title,
          meta: '任务 · 截止',
          color: C.red,
          task: task,
        ),
      );
    }
  }

  items.sort((a, b) => a.sortAt.compareTo(b.sortAt));
  return items;
}

class _CalendarAgendaTile extends StatelessWidget {
  const _CalendarAgendaTile({
    required this.item,
    required this.onTap,
  });

  final _CalendarAgendaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Container(
              width: 4,
              height: 34,
              decoration: BoxDecoration(
                color: item.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 9),
            SizedBox(
              width: 42,
              child: Text(
                item.time,
                style: TextStyle(
                  fontSize: 9.2,
                  fontWeight: FontWeight.w900,
                  color: item.color,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    item.meta,
                    style: const TextStyle(fontSize: 8.7, color: C.muted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: C.muted,
            ),
          ]),
        ),
      );
}

class _CalendarConflictCard extends ConsumerWidget {
  const _CalendarConflictCard({required this.conflict});

  final CalendarConflictUi conflict;

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
              '日程存在同步冲突',
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
                      .read(calendarCommandsProvider)
                      .keepServer(conflict.conflictId),
                  child: const Text('保留云端'),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: FilledButton(
                  onPressed: () => ref
                      .read(calendarCommandsProvider)
                      .keepLocal(conflict.conflictId),
                  child: const Text('保留本地'),
                ),
              ),
            ]),
          ],
        ),
      );
}

Future<void> _editCalendarEvent(
  BuildContext context,
  WidgetRef ref, {
  required DateTime initialDate,
  ExecutionCalendarEvent? event,
}) async {
  final existingReminders = event == null
      ? const <ExecutionReminder>[]
      : await ref.read(
          remindersForSubjectProvider(
            ReminderSubjectKey(
              subjectType: ReminderSubjectTypes.calendarEvent,
              subjectId: event.id,
            ),
          ).future,
        );
  final existingReminder = _activeReminder(existingReminders);
  if (!context.mounted) return;

  final titleController = TextEditingController(text: event?.title ?? '');
  final descriptionController =
      TextEditingController(text: event?.description ?? '');
  final locationController =
      TextEditingController(text: event?.location ?? '');

  final defaultStart = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
    9,
  );
  DateTime start =
      DateTime.tryParse(event?.startAt ?? '')?.toLocal() ?? defaultStart;
  DateTime? end = DateTime.tryParse(event?.endAt ?? '')?.toLocal() ??
      start.add(const Duration(hours: 1));
  var allDay = event?.allDay ?? false;
  var reminderEnabled = existingReminder != null;
  DateTime? reminderAt = existingReminder == null
      ? null
      : DateTime.parse(existingReminder.effectiveTriggerAt).toLocal();

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
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleController,
              autofocus: event == null,
              decoration: const InputDecoration(labelText: '日程标题'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: '描述'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: '地点'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('全天事件'),
              value: allDay,
              onChanged: (value) => setSheetState(() => allDay = value),
            ),
            _DateField(
              label: allDay ? '开始日期' : '开始时间',
              value: start,
              onPick: () async {
                final value = await _pickDateTime(sheetContext, start);
                if (value != null) setSheetState(() => start = value);
              },
              onClear: null,
            ),
            const SizedBox(height: 8),
            _DateField(
              label: allDay ? '结束日期' : '结束时间',
              value: end,
              onPick: () async {
                final value = await _pickDateTime(sheetContext, end);
                if (value != null) setSheetState(() => end = value);
              },
              onClear: end == null
                  ? null
                  : () => setSheetState(() => end = null),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('日程提醒'),
              subtitle: Text(
                reminderEnabled
                    ? '在指定时间发送系统通知'
                    : '关闭后会同步取消已有提醒',
                style: const TextStyle(fontSize: 8.5, color: C.muted),
              ),
              value: reminderEnabled,
              onChanged: (value) => setSheetState(() {
                reminderEnabled = value;
                if (value && reminderAt == null) {
                  reminderAt = _suggestCalendarReminder(start);
                }
              }),
            ),
            if (reminderEnabled) ...[
              _DateField(
                label: '提醒时间',
                value: reminderAt,
                onPick: () async {
                  final value =
                      await _pickDateTime(sheetContext, reminderAt ?? start);
                  if (value != null) {
                    setSheetState(() => reminderAt = value);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            Row(children: [
              if (event != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref.read(reminderCommandsProvider).cancelForSubject(
                            subjectType: ReminderSubjectTypes.calendarEvent,
                            subjectId: event.id,
                          );
                      await ref.read(calendarCommandsProvider).delete(event);
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('删除'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: () async {
                    try {
                      var saveStart = start;
                      DateTime? saveEnd = end;
                      if (allDay) {
                        saveStart = DateTime(
                          start.year,
                          start.month,
                          start.day,
                        );
                        final endDate = end ?? start;
                        saveEnd = DateTime(
                          endDate.year,
                          endDate.month,
                          endDate.day,
                          23,
                          59,
                          59,
                          999,
                        );
                      }

                      final commands = ref.read(calendarCommandsProvider);
                      late final ExecutionCalendarEvent savedEvent;
                      if (event == null) {
                        savedEvent = await commands.create(
                          title: titleController.text,
                          description: descriptionController.text,
                          location: locationController.text,
                          allDay: allDay,
                          startAt: saveStart.toUtc().toIso8601String(),
                          endAt: saveEnd?.toUtc().toIso8601String(),
                        );
                      } else {
                        savedEvent = await commands.update(
                          event: event,
                          title: titleController.text,
                          description: descriptionController.text,
                          location: locationController.text,
                          allDay: allDay,
                          startAt: saveStart.toUtc().toIso8601String(),
                          endAt: saveEnd?.toUtc().toIso8601String(),
                          clearDescription:
                              descriptionController.text.trim().isEmpty,
                          clearLocation:
                              locationController.text.trim().isEmpty,
                          clearEndAt: saveEnd == null,
                        );
                      }

                      if (reminderEnabled) {
                        final trigger =
                            reminderAt ?? _suggestCalendarReminder(saveStart);
                        await ref.read(reminderCommandsProvider).schedule(
                              subjectType:
                                  ReminderSubjectTypes.calendarEvent,
                              subjectId: savedEvent.id,
                              triggerAt: trigger,
                              title: savedEvent.title,
                              body: savedEvent.location ??
                                  savedEvent.description ??
                                  'LifeTrace 日程提醒',
                            );
                      } else {
                        await ref.read(reminderCommandsProvider).cancelForSubject(
                              subjectType:
                                  ReminderSubjectTypes.calendarEvent,
                              subjectId: savedEvent.id,
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
                  child: Text(event == null ? '创建日程' : '保存日程'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    ),
  );

  titleController.dispose();
  descriptionController.dispose();
  locationController.dispose();
}

DateTime _suggestCalendarReminder(DateTime start) {
  final now = DateTime.now();
  final candidate = start.subtract(const Duration(minutes: 10));
  return candidate.isAfter(now)
      ? candidate
      : now.add(const Duration(hours: 1));
}

String _calendarTime(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}

String _calendarDateHeader(DateTime date) {
  final today = DateTime.now();
  final suffix = sameCalendarDate(date, today) ? ' · 今天' : '';
  return '${date.month}月${date.day}日$suffix';
}
