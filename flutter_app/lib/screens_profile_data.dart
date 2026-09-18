part of 'main.dart';

class DataManagement extends ConsumerStatefulWidget {
  const DataManagement({super.key});

  @override
  ConsumerState<DataManagement> createState() => _DataManagementState();
}

class _DataManagementState extends ConsumerState<DataManagement> {
  bool exporting = false;
  bool deleting = false;
  String? exportPath;
  String? actionError;

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(currentSessionProvider);
    final session = sessionState.valueOrNull;
    final policyState = ref.watch(privacyPolicyProvider);

    return DetailFrame(
      titleText: '数据与隐私',
      child: page([
        if (sessionState.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (session == null)
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
                  '隐私导出和账号删除需要通过 Cloud 返回真实结果。',
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
            const CircleAvatar(
              radius: 20,
              backgroundColor: C.purpleSoft,
              child: Icon(Icons.shield_outlined, color: C.purple, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title('你的数据由你控制'),
                  const SizedBox(height: 2),
                  sub(session.email),
                ],
              ),
            ),
          ]),
          h('隐私策略'),
          policyState.when(
            loading: () => panel(
              const Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => panel(
              Text(
                '策略读取失败：$error',
                style: const TextStyle(fontSize: 9, color: C.red),
              ),
            ),
            data: (policy) => panel(
              Column(
                children: [
                  _InfoRow(
                    '策略版本',
                    policy?['policyVersion']?.toString() ?? '未知',
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    '环境',
                    policy?['environment']?.toString() ?? '未知',
                  ),
                  const Divider(height: 1),
                  _InfoRow(
                    '备份删除',
                    _privacyPolicyText(policy, 'backupDeletion'),
                  ),
                ],
              ),
            ),
          ),
          h('隐私导出'),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '导出当前 Cloud 会话有权限访问的 LifeTrace 数据',
                  style: TextStyle(
                    fontSize: 10.4,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '服务端生成 lifetrace-privacy-export-v1 JSON，本机会写入应用文档目录，不会把 token 或密码写入导出文件。',
                  style: TextStyle(fontSize: 8.8, color: C.muted, height: 1.4),
                ),
                if (exportPath != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    '已导出：$exportPath',
                    style: const TextStyle(fontSize: 8.6, color: C.green),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: exporting ? null : _export,
                    icon: exporting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.download_rounded, size: 17),
                    label: Text(exporting ? '正在导出' : '导出 Cloud 数据'),
                  ),
                ),
              ],
            ),
          ),
          h('账号删除'),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '永久删除 LifeTrace Cloud 账号',
                  style: TextStyle(
                    fontSize: 10.4,
                    fontWeight: FontWeight.w900,
                    color: C.red,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '该操作会由 Cloud 撤销会话并删除账号及其服务器数据。本机 Local-first 数据不会被此按钮自动擦除。',
                  style: TextStyle(fontSize: 8.8, color: C.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: deleting ? null : () => _confirmDelete(session.email),
                    icon: const Icon(Icons.delete_forever_outlined, size: 17),
                    label: Text(deleting ? '正在删除账号' : '删除 Cloud 账号'),
                  ),
                ),
              ],
            ),
          ),
          if (actionError != null) ...[
            const SizedBox(height: 10),
            Text(
              actionError!,
              style: const TextStyle(fontSize: 9, color: C.red),
            ),
          ],
        ],
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }

  Future<void> _export() async {
    setState(() {
      exporting = true;
      actionError = null;
    });
    try {
      final path =
          await ref.read(profileDataCommandsProvider).exportPrivacyData();
      if (!mounted) return;
      setState(() => exportPath = path);
    } catch (error) {
      if (mounted) setState(() => actionError = '导出失败：$error');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _confirmDelete(String email) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('永久删除 Cloud 账号'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请输入当前邮箱 $email 以确认。'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '确认邮箱'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim() == email,
            ),
            child: const Text('永久删除'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (confirmed != true) return;

    setState(() {
      deleting = true;
      actionError = null;
    });
    try {
      await ref.read(profileDataCommandsProvider).deleteCloudAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cloud 账号已删除，本机会话已清除')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => actionError = '账号删除失败：$error');
    } finally {
      if (mounted) setState(() => deleting = false);
    }
  }
}

String _privacyPolicyText(Map<String, dynamic>? policy, String key) {
  final value = policy?[key]?.toString().trim();
  return value == null || value.isEmpty ? '未声明' : value;
}
