import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/reminder/execution_reminder.dart';

class ReminderNotificationTarget {
  const ReminderNotificationTarget({
    required this.reminderId,
    required this.subjectType,
    required this.subjectId,
  });

  final String reminderId;
  final String subjectType;
  final String subjectId;
}

typedef ReminderNotificationTap = void Function(ReminderNotificationTarget target);

class ReminderNotificationService {
  ReminderNotificationService({ReminderNotificationTap? onTap}) : _onTap = onTap;

  static const _channelId = 'lifetrace_reminders';
  static const _channelName = 'LifeTrace 提醒';
  static const _channelDescription = '任务与日历提醒';
  static const _payloadKind = 'execution.reminder';

  final ReminderNotificationTap? _onTap;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    try {
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (response) {
        final target = _decodePayload(response.payload);
        if (target != null) _onTap?.call(target);
      },
    );
    _initialized = true;

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final target = _decodePayload(launch?.notificationResponse?.payload);
      if (target != null) _onTap?.call(target);
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.requestNotificationsPermission() ?? true;
  }

  Future<void> schedule(ExecutionReminder reminder) async {
    await initialize();
    if (!reminder.isScheduled) {
      await cancel(reminder.id);
      return;
    }

    final instant = DateTime.tryParse(reminder.effectiveTriggerAt)?.toUtc();
    if (instant == null || !instant.isAfter(DateTime.now().toUtc())) {
      await cancel(reminder.id);
      return;
    }

    await _plugin.zonedSchedule(
      id: _notificationId(reminder.id),
      title: reminder.title ?? 'LifeTrace 提醒',
      body: reminder.body ?? '你有一项计划需要处理',
      scheduledDate: tz.TZDateTime.from(instant, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({
        'kind': _payloadKind,
        'reminderId': reminder.id,
        'subjectType': reminder.subjectType,
        'subjectId': reminder.subjectId,
      }),
    );
  }

  Future<void> cancel(String reminderId) async {
    await initialize();
    await _plugin.cancel(id: _notificationId(reminderId));
  }

  Future<void> reconcile(List<ExecutionReminder> reminders) async {
    await initialize();
    final now = DateTime.now().toUtc();
    final desired = <String, ExecutionReminder>{
      for (final reminder in reminders)
        if (reminder.isScheduled &&
            (DateTime.tryParse(reminder.effectiveTriggerAt)?.toUtc().isAfter(now) ??
                false))
          reminder.id: reminder,
    };

    final pending = await _plugin.pendingNotificationRequests();
    for (final item in pending) {
      final target = _decodePayload(item.payload);
      if (target == null || !desired.containsKey(target.reminderId)) {
        if (target != null) {
          await _plugin.cancel(id: item.id);
        }
      }
    }

    for (final reminder in desired.values) {
      await schedule(reminder);
    }
  }

  ReminderNotificationTarget? _decodePayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final value = jsonDecode(payload);
      if (value is! Map) return null;
      final json = Map<String, dynamic>.from(value);
      if (json['kind'] != _payloadKind) return null;
      final reminderId = json['reminderId']?.toString();
      final subjectType = json['subjectType']?.toString();
      final subjectId = json['subjectId']?.toString();
      if (reminderId == null ||
          reminderId.isEmpty ||
          subjectType == null ||
          subjectType.isEmpty ||
          subjectId == null ||
          subjectId.isEmpty) {
        return null;
      }
      return ReminderNotificationTarget(
        reminderId: reminderId,
        subjectType: subjectType,
        subjectId: subjectId,
      );
    } catch (_) {
      return null;
    }
  }

  static int _notificationId(String reminderId) {
    var hash = 0x811c9dc5;
    for (final unit in reminderId.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
