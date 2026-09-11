import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/background/background_sync.dart';
import 'domain/calendar/execution_calendar_event.dart';
import 'domain/collection/entity_link.dart';
import 'domain/collection/execution_file_metadata.dart';
import 'domain/collection/execution_memo.dart';
import 'domain/project/execution_project.dart';
import 'domain/reminder/execution_reminder.dart';
import 'domain/review/daily_review.dart';
import 'domain/task/execution_task.dart';
import 'features/calendar/calendar_math.dart';
import 'features/calendar/calendar_providers.dart';
import 'features/collection/collection_providers.dart';
import 'features/collection/media_providers.dart';
import 'features/projects/project_providers.dart';
import 'features/reminders/reminder_providers.dart';
import 'features/review/review_providers.dart';
import 'features/review/review_stats.dart';
import 'features/tasks/task_providers.dart';

part 'screens_a.dart';
part 'screens_b.dart';
part 'screens_c.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(
    BackgroundSyncScheduler.initialize().catchError((_) {
      // Background scheduling must never prevent foreground startup.
    }),
  );
  runApp(const ProviderScope(child: LifeTraceExecuteApp()));
}

abstract final class C {
  static const p = Color(0xff2468f2),
      ps = Color(0xffeaf2ff),
      ink = Color(0xff172033),
      muted = Color(0xff697386),
      bg = Color(0xfff7f8fc),
      surface = Colors.white,
      soft = Color(0xfff1f4f9),
      border = Color(0xffe2e7f0),
      orange = Color(0xffff9a3d),
      orangeSoft = Color(0xfffff1e3),
      green = Color(0xff16a36a),
      greenSoft = Color(0xffe8f8ef),
      red = Color(0xffef5350),
      redSoft = Color(0xffffeceb),
      purple = Color(0xff7657e8),
      purpleSoft = Color(0xfff0ecff),
      teal = Color(0xff0f9f83),
      tealSoft = Color(0xffe7f8f4),
      pink = Color(0xffd9568b),
      pinkSoft = Color(0xffffedf5),
      amber = Color(0xffd98b00),
      amberSoft = Color(0xfffff5dc),
      sky = Color(0xff2786c7),
      skySoft = Color(0xffe9f6ff);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: C.bg,
      colorScheme: const ColorScheme.light(
        primary: C.p,
        secondary: C.purple,
        tertiary: C.teal,
        surface: C.surface,
        onSurface: C.ink,
        outline: C.border,
        error: C.red,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          height: 1.12,
        ),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        bodyMedium: TextStyle(fontSize: 12.5, height: 1.35),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: C.soft,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );

class LifeTraceExecuteApp extends StatelessWidget {
  const LifeTraceExecuteApp({super.key, this.simulateSystemChrome = false});

  final bool simulateSystemChrome;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LifeTrace Execute',
        theme: buildTheme(),
        home: Shell(simulateSystemChrome: simulateSystemChrome),
      );
}

class PhoneStatusBar extends StatelessWidget {
  const PhoneStatusBar({super.key, this.time = '9:43'});

  final String time;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 24,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 6,
              child: Text(
                time,
                style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: CircleAvatar(radius: 4.4, backgroundColor: Colors.black),
              ),
            ),
            const Positioned(
              right: 10,
              top: 5,
              child: Row(
                children: [
                  Icon(Icons.signal_cellular_4_bar_rounded, size: 11),
                  SizedBox(width: 4),
                  Icon(Icons.wifi_rounded, size: 11),
                  SizedBox(width: 4),
                  Icon(Icons.battery_full_rounded, size: 13),
                ],
              ),
            ),
          ],
        ),
      );
}

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key, this.simulateSystemChrome = false});

  final bool simulateSystemChrome;

  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> with WidgetsBindingObserver {
  int i = 0;

  bool get _runsOnProductionAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_runsOnProductionAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await ref
            .read(reminderNotificationBridgeProvider)
            .service
            .initialize();
        _syncSilently();
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_runsOnProductionAndroid && state == AppLifecycleState.resumed) {
      _syncSilently();
    }
  }

  void _syncSilently() {
    unawaited(_syncAndReconcile());
  }

  Future<void> _syncAndReconcile() async {
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
    await ref
        .read(mediaUploadControllerProvider.notifier)
        .processPending(silent: true);
    await ref.read(reminderCommandsProvider).reconcile();
  }

  void _openReminderTarget(ReminderNotificationTarget target) {
    switch (target.subjectType) {
      case ReminderSubjectTypes.task:
        setState(() => i = 1);
        final task = ref
            .read(taskListProvider)
            .valueOrNull
            ?.where((item) => item.id == target.subjectId)
            .firstOrNull;
        if (task != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) push(context, TaskDetail(task: task));
          });
        }
      case ReminderSubjectTypes.calendarEvent:
        setState(() => i = 3);
        final event = ref
            .read(calendarEventListProvider)
            .valueOrNull
            ?.where((item) => item.id == target.subjectId)
            .firstOrNull;
        if (event != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _editCalendarEvent(
              context,
              ref,
              initialDate: DateTime.parse(event.startAt).toLocal(),
              event: event,
            );
          });
        }
      default:
        setState(() => i = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<ReminderNotificationTarget>>(
      reminderNotificationTapProvider,
      (_, next) => next.whenData(_openReminderTarget),
    );

    final pages = [
      const Today(),
      const Tasks(),
      const Projects(),
      const Calendar(),
      const Collection(),
    ];

    final content = Column(
      children: [
        if (widget.simulateSystemChrome) const PhoneStatusBar(),
        Expanded(child: IndexedStack(index: i, children: pages)),
        _BottomNav(index: i, onChanged: (v) => setState(() => i = v)),
        if (widget.simulateSystemChrome) const SizedBox(height: 5),
      ],
    );

    return Scaffold(
      body: widget.simulateSystemChrome ? content : SafeArea(child: content),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const items = [
    (Icons.home_outlined, Icons.home_rounded, '今天', C.p, C.ps),
    (Icons.check_box_outlined, Icons.check_box_rounded, '任务', C.sky, C.skySoft),
    (Icons.folder_outlined, Icons.folder_rounded, '项目', C.purple, C.purpleSoft),
    (Icons.calendar_today_outlined, Icons.calendar_month_rounded, '日历', C.orange, C.orangeSoft),
    (Icons.inbox_outlined, Icons.inbox_rounded, '收集', C.teal, C.tealSoft),
  ];

  @override
  Widget build(BuildContext context) => Container(
        height: 57,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: C.border)),
        ),
        child: Row(
          children: List.generate(items.length, (j) {
            final item = items[j];
            final selected = j == index;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(j),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 34,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? item.$5 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        selected ? item.$2 : item.$1,
                        size: 18,
                        color: selected ? item.$4 : C.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 9.2,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? item.$4 : C.muted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      );
}

Widget page(
  List<Widget> children, {
  EdgeInsets padding = const EdgeInsets.fromLTRB(14, 8, 14, 18),
}) =>
    ListView(
      padding: padding,
      physics: const BouncingScrollPhysics(),
      children: children,
    );

Widget title(String s) =>
    Text(s, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900));

Widget sub(String s) =>
    Text(s, style: const TextStyle(fontSize: 10.5, color: C.muted));

Widget h(String s, {Widget? tail}) => Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              s,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
            ),
          ),
          if (tail != null) tail,
        ],
      ),
    );

Widget panel(
  Widget child, {
  Color color = Colors.white,
  EdgeInsets padding = const EdgeInsets.all(12),
  VoidCallback? onTap,
}) {
  final box = Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(11),
      border: Border.all(color: C.border),
    ),
    child: child,
  );
  return onTap == null
      ? box
      : InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: box,
        );
}

Widget chip(String s, {Color bg = C.soft, Color fg = C.muted}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        s,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg),
      ),
    );
