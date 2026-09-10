import 'dart:async';
import 'package:flutter/material.dart';
part 'screens_a.dart';
part 'screens_b.dart';
part 'screens_c.dart';

void main() => runApp(const LifeTracePreviewApp());

abstract final class C {
  static const p = Color(0xff2468f2), ps = Color(0xffedf4ff), ink = Color(0xff111827),
      muted = Color(0xff6b7280), bg = Color(0xfffbfcfe), surface = Colors.white,
      soft = Color(0xfff5f7fb), border = Color(0xffe6eaf0), orange = Color(0xffff9f2f),
      green = Color(0xff16a36a), red = Color(0xfff05252), purple = Color(0xff7c3aed), teal = Color(0xff0f9f83);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: C.bg,
  colorScheme: const ColorScheme.light(primary: C.p, surface: C.surface, onSurface: C.ink, outline: C.border, error: C.red),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.12),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
    bodyMedium: TextStyle(fontSize: 12.5, height: 1.35),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true, fillColor: C.soft, isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  ),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
    minimumSize: const Size(0, 42), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
);

class LifeTracePreviewApp extends StatelessWidget {
  const LifeTracePreviewApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'LifeTrace Execute', theme: buildTheme(), home: const Shell());
}

class PhoneStatusBar extends StatelessWidget {
  const PhoneStatusBar({super.key, this.time = '9:43'}); final String time;
  @override Widget build(BuildContext context) => SizedBox(height: 24, child: Stack(children: [
    Positioned(left: 12, top: 6, child: Text(time, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800))),
    const Align(alignment: Alignment.topCenter, child: Padding(padding: EdgeInsets.only(top: 4), child: CircleAvatar(radius: 4.4, backgroundColor: Colors.black))),
    const Positioned(right: 10, top: 5, child: Row(children: [
      Icon(Icons.signal_cellular_4_bar_rounded, size: 11), SizedBox(width: 4), Icon(Icons.wifi_rounded, size: 11), SizedBox(width: 4), Icon(Icons.battery_full_rounded, size: 13),
    ])),
  ]));
}

class Shell extends StatefulWidget { const Shell({super.key}); @override State<Shell> createState() => _ShellState(); }
class _ShellState extends State<Shell> {
  int i = 0;
  @override Widget build(BuildContext context) {
    final pages = [const Today(), const Tasks(), const Projects(), const Calendar(), const Collection()];
    return Scaffold(body: Column(children: [
      const PhoneStatusBar(),
      Expanded(child: IndexedStack(index: i, children: pages)),
      _BottomNav(index: i, onChanged: (v) => setState(() => i = v)),
      const SizedBox(height: 5),
    ]));
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged}); final int index; final ValueChanged<int> onChanged;
  static const items = [
    (Icons.home_outlined, Icons.home_rounded, '今天'), (Icons.check_box_outlined, Icons.check_box_rounded, '任务'),
    (Icons.folder_outlined, Icons.folder_rounded, '项目'), (Icons.calendar_today_outlined, Icons.calendar_month_rounded, '日历'),
    (Icons.inbox_outlined, Icons.inbox_rounded, '收集'),
  ];
  @override Widget build(BuildContext context) => Container(
    height: 57, decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.border))),
    child: Row(children: List.generate(items.length, (j) { final x = items[j]; final s = j == index; return Expanded(child: InkWell(
      onTap: () => onChanged(j), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(s ? x.$2 : x.$1, size: 18, color: s ? C.p : C.muted), const SizedBox(height: 3),
        Text(x.$3, style: TextStyle(fontSize: 9.5, fontWeight: s ? FontWeight.w800 : FontWeight.w600, color: s ? C.p : C.muted)),
      ]))); })),
  );
}

Widget page(List<Widget> children, {EdgeInsets padding = const EdgeInsets.fromLTRB(14, 8, 14, 18)}) =>
  ListView(padding: padding, physics: const BouncingScrollPhysics(), children: children);
Widget title(String s) => Text(s, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900));
Widget sub(String s) => Text(s, style: const TextStyle(fontSize: 10.5, color: C.muted));
Widget h(String s, {Widget? tail}) => Padding(padding: const EdgeInsets.only(top: 15, bottom: 8), child: Row(children: [
  Expanded(child: Text(s, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900))), if (tail != null) tail]));
Widget panel(Widget child, {Color color = Colors.white, EdgeInsets padding = const EdgeInsets.all(12), VoidCallback? onTap}) {
  final box = Container(padding: padding, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(11), border: Border.all(color: C.border)), child: child);
  return onTap == null ? box : InkWell(borderRadius: BorderRadius.circular(11), onTap: onTap, child: box);
}
Widget chip(String s, {Color bg = C.soft, Color fg = C.muted}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
  child: Text(s, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg)));
