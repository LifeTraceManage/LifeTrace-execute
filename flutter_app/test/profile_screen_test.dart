import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/cloud/cloud_device_contract.dart';
import 'package:lifetrace_execute/features/profile/profile_providers.dart';
import 'package:lifetrace_execute/features/profile/settings_providers.dart';
import 'package:lifetrace_execute/features/tasks/task_providers.dart';
import 'package:lifetrace_execute/main.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  testWidgets(
    'profile uses the shared LifeTrace settings information architecture',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentSessionProvider.overrideWith((ref) async => null),
            cloudDevicesProvider.overrideWith(
              (ref) async => const <CloudDeviceInstallation>[],
            ),
            taskPendingSyncCountProvider.overrideWith(
              (ref) => Stream<int>.value(0),
            ),
            taskBlockedSyncCountProvider.overrideWith(
              (ref) => Stream<int>.value(0),
            ),
            syncUnresolvedConflictCountProvider.overrideWith(
              (ref) => Stream<int>.value(0),
            ),
            packageInfoProvider.overrideWith(
              (ref) async => PackageInfo(
                appName: 'LifeTrace Execute',
                packageName: 'com.lifetrace.execute',
                version: '0.3.0',
                buildNumber: '3',
              ),
            ),
          ],
          child: MaterialApp(
            theme: buildTheme(),
            home: const Profile(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('我的'), findsOneWidget);
      expect(find.text('数据与同步'), findsOneWidget);
      expect(find.text('云端同步'), findsOneWidget);
      expect(find.text('本地数据'), findsWidgets);
      expect(find.text('设备管理'), findsOneWidget);

      final list = find.byType(ListView);
      expect(list, findsOneWidget);

      await tester.drag(list, const Offset(0, -520));
      await tester.pumpAndSettle();

      expect(find.text('应用'), findsOneWidget);
      expect(find.text('通知与提醒'), findsOneWidget);
      expect(find.text('外观'), findsOneWidget);
      expect(find.text('应用设置'), findsOneWidget);

      await tester.drag(list, const Offset(0, -520));
      await tester.pumpAndSettle();

      expect(find.text('账户与安全'), findsOneWidget);
      expect(find.text('LifeTrace Cloud'), findsOneWidget);
      expect(find.text('其他'), findsOneWidget);
      expect(find.text('关于 LifeTrace'), findsOneWidget);

      await tester.drag(list, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('LifeTrace Execute · v0.3.0'), findsOneWidget);
    },
  );
}
