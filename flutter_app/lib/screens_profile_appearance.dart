part of 'main.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appPreferencesProvider);

    return DetailFrame(
      titleText: '外观',
      child: page([
        Row(children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: C.purpleSoft,
            child: Icon(Icons.palette_outlined, color: C.purple, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title('界面偏好'),
                const SizedBox(height: 2),
                sub('当前设备本地设置 · 修改后立即作用于全 App'),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => panel(
            Text(
              '外观设置读取失败：$error',
              style: const TextStyle(fontSize: 9.2, color: C.red),
            ),
          ),
          data: (preferences) => Column(children: [
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '文字大小',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '通过 Flutter TextScaler 统一调整应用文字比例。',
                    style: TextStyle(fontSize: 8.6, color: C.muted),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<FontScalePreference>(
                      segments: const [
                        ButtonSegment(
                          value: FontScalePreference.small,
                          label: Text('小'),
                        ),
                        ButtonSegment(
                          value: FontScalePreference.normal,
                          label: Text('标准'),
                        ),
                        ButtonSegment(
                          value: FontScalePreference.large,
                          label: Text('大'),
                        ),
                      ],
                      selected: {preferences.fontScale},
                      onSelectionChanged: (values) {
                        ref
                            .read(appPreferencesCommandsProvider)
                            .setFontScale(values.single);
                      },
                    ),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(11),
            ),
            const SizedBox(height: 9),
            panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '界面密度',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    '控制 Material 控件的视觉密度，紧凑模式更适合信息密集场景。',
                    style: TextStyle(fontSize: 8.6, color: C.muted),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<DensityPreference>(
                      segments: const [
                        ButtonSegment(
                          value: DensityPreference.comfortable,
                          label: Text('舒适'),
                        ),
                        ButtonSegment(
                          value: DensityPreference.compact,
                          label: Text('紧凑'),
                        ),
                      ],
                      selected: {preferences.density},
                      onSelectionChanged: (values) {
                        ref
                            .read(appPreferencesCommandsProvider)
                            .setDensity(values.single);
                      },
                    ),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(11),
            ),
            const SizedBox(height: 9),
            panel(
              Row(children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: C.soft,
                  child: Icon(
                    Icons.motion_photos_off_outlined,
                    size: 16,
                    color: C.muted,
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '减少动画',
                        style: TextStyle(
                          fontSize: 10.3,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '向 Flutter 组件树声明 disableAnimations，减少非必要过渡与动态效果。',
                        style: TextStyle(
                          fontSize: 8.4,
                          color: C.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: preferences.reduceMotion,
                  onChanged: (value) {
                    ref
                        .read(appPreferencesCommandsProvider)
                        .setReduceMotion(value);
                  },
                ),
              ]),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ]),
        ),
      ], padding: const EdgeInsets.fromLTRB(14, 4, 14, 22)),
    );
  }
}
