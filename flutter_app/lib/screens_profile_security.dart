part of 'main.dart';

class ProfileDetails extends ConsumerWidget {
  const ProfileDetails({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(currentSessionProvider).valueOrNull;
    final profileState = ref.watch(cloudProfileProvider);

    return DetailFrame(
      titleText: '个人资料',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: session == null
              ? null
              : () => ref.invalidate(cloudProfileProvider),
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
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => push(context, const CloudConnection()),
                  child: const Text('连接 Cloud'),
                ),
              ],
            ),
          )
        else
          profileState.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => panel(
              Text(
                '资料读取失败：$error',
                style: const TextStyle(fontSize: 9.2, color: C.red),
              ),
            ),
            data: (profile) => profile == null
                ? panel(
                    const Text(
                      'Cloud 没有返回用户资料。',
                      style: TextStyle(fontSize: 9.2, color: C.muted),
                    ),
                  )
                : Column(
                    children: [
                      const CircleAvatar(
                        radius: 34,
                        backgroundColor: C.purpleSoft,
                        child: Icon(
                          Icons.person_rounded,
                          size: 34,
                          color: C.purple,
                        ),
                      ),
                      const SizedBox(height: 10),
                      title(
                        profile.displayName?.trim().isNotEmpty == true
                            ? profile.displayName!
                            : profile.email.split('@').first,
                      ),
                      const SizedBox(height: 3),
                      sub(profile.email),
                      h('Cloud 资料'),
                      panel(
                        Column(children: [
                          _InfoRow('用户 ID', profile.id),
                          const Divider(height: 1),
                          _InfoRow('邮箱', profile.email),
                          const Divider(height: 1),
                          _InfoRow(
                            '显示名称',
                            profile.displayName?.trim().isNotEmpty == true
                                ? profile.displayName!
                                : '未设置',
                          ),
                          const Divider(height: 1),
                          _InfoRow(
                            '会话权限',
                            session.scopes.join(', '),
                          ),
                        ]),
                      ),
                      panel(
                        const Text(
                          '当前 Cloud Auth v1 只提供资料读取，没有用户资料更新 endpoint；本页只展示服务端真实值，不提供伪编辑入口。',
                          style: TextStyle(
                            fontSize: 8.8,
                            color: C.muted,
                            height: 1.4,
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                      ),
                    ],
                  ),
          ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }
}

class AccountSecurity extends ConsumerStatefulWidget {
  const AccountSecurity({super.key});

  @override
  ConsumerState<AccountSecurity> createState() => _AccountSecurityState();
}

class _AccountSecurityState extends ConsumerState<AccountSecurity> {
  final currentPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmPassword = TextEditingController();
  bool changing = false;
  bool loggingOutAll = false;
  String? error;

  @override
  void dispose() {
    currentPassword.dispose();
    newPassword.dispose();
    confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(currentSessionProvider).valueOrNull;

    return DetailFrame(
      titleText: '账户与安全',
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
                const SizedBox(height: 8),
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
              backgroundColor: C.greenSoft,
              child: Icon(Icons.lock_rounded, color: C.green, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title('账户安全'),
                  const SizedBox(height: 2),
                  sub(session.email),
                ],
              ),
            ),
          ]),
          h('修改密码'),
          panel(
            Column(children: [
              TextField(
                controller: currentPassword,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: '当前密码'),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: newPassword,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: '新密码'),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: confirmPassword,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(labelText: '确认新密码'),
              ),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Cloud 修改密码成功后会撤销所有登录会话，本机也需要重新登录。',
                  style: TextStyle(fontSize: 8.6, color: C.muted),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: changing ? null : _changePassword,
                  icon: changing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.password_rounded, size: 17),
                  label: Text(changing ? '正在修改密码' : '修改密码'),
                ),
              ),
            ]),
          ),
          h('会话安全'),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '退出所有设备',
                  style: TextStyle(fontSize: 10.4, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  '撤销当前账号的所有 Cloud session、access token 和 refresh token。',
                  style: TextStyle(fontSize: 8.8, color: C.muted, height: 1.4),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: loggingOutAll ? null : _logoutAll,
                    icon: const Icon(Icons.logout_rounded, size: 17),
                    label: Text(
                      loggingOutAll ? '正在退出所有设备' : '退出所有设备',
                    ),
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
        ],
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }

  Future<void> _changePassword() async {
    if (newPassword.text != confirmPassword.text) {
      setState(() => error = '两次输入的新密码不一致');
      return;
    }
    setState(() {
      changing = true;
      error = null;
    });
    try {
      await ref.read(profileSecurityCommandsProvider).changePassword(
            currentPassword: currentPassword.text,
            newPassword: newPassword.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密码已修改，所有会话已退出，请重新登录')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '修改密码失败：$e');
    } finally {
      if (mounted) setState(() => changing = false);
    }
  }

  Future<void> _logoutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出所有设备'),
        content: const Text('这会立即撤销包括当前设备在内的所有 Cloud 会话。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('全部退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      loggingOutAll = true;
      error = null;
    });
    try {
      await ref.read(profileSecurityCommandsProvider).logoutAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所有 Cloud 会话已撤销')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = '退出所有设备失败：$e');
    } finally {
      if (mounted) setState(() => loggingOutAll = false);
    }
  }
}
