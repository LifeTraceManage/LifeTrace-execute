import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/focus/focus_timer_state.dart';
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

class FocusNotificationTarget {
  const FocusNotificationTarget({
    required this.userId,
    required this.phase,
  });

  final String userId;
  final FocusPhase phase;
}

typedef FocusNotificationTap = void Function(FocusNotificationTarget target);

class ReminderNotificationService {
  ReminderNotificationService({
    ReminderNotificationTap? onTap,
    FocusNotificationTap? onFocusTap,
  })  : _onTap = onTap,
        _onFocusTap = onFocusTap;

  static const _channelId = 'lifetrace_reminders';
  static const _channelName = 'LifeTrace 提醒';
  static const _channelDescription = '任务与日历提醒';
  static const _payloadKind = 'execution.reminder';
  static const _focusPayloadKind = 'focus.timer';
  static const _focusChannelId = 'lifetrace_focus';
  static const _focusChannelName = 'LifeTrace 专注';
  static const _focusChannelDescription = '番茄钟专注与休息阶段提醒';

  final ReminderNotificationTap? _onTap;
  final FocusNotificationTap? _onFocusTap;
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
        final reminder = _decodePayload(response.payload);
        if (reminder != null) {
          _onTap?.call(reminder);
          return;
        }
        final focus = _decodeFocusPayload(response.payload);
        if (focus != null) _onFocusTap?.call(focus);
      },
    );
    _initialized = true;

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      final payload = launch?.notificationResponse?.payload;
      final reminder = _decodePayload(payload);
      if (reminder != null) {
        _onTap?.call(reminder);
      } else {
        final focus = _decodeFocusPayload(payload);
        if (focus != null) _onFocusTap?.call(focus);
      }
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

  Future<void> reconcileFocus(FocusTimerState? state) async {
    await initialize();
    if (state == null || !state.isRunning) {
      if (state != null) await cancelFocus(state.userId);
      return;
    }

    await cancelFocus(state.userId);
    final end = DateTime.tryParse(state.expectedEndAt ?? '')?.toUtc();
    if (end == null || !end.isAfter(DateTime.now().toUtc())) return;

    if (state.isFocus) {
      await _scheduleFocusPhase(
        userId: state.userId,
        phase: FocusPhase.focus,
        instant: end,
        title: '专注完成',
        body: '本轮专注已完成，休息 ${state.breakSeconds ~/ 60} 分钟',
      );
      final breakEnd = end.add(Duration(seconds: state.breakSeconds));
      if (breakEnd.isAfter(DateTime.now().toUtc())) {
        await _scheduleFocusPhase(
          userId: state.userId,
          phase: FocusPhase.breakTime,
          instant: breakEnd,
          title: '休息结束',
          body: '可以开始下一轮专注了',
        );
      }
    } else {
      await _scheduleFocusPhase(
        userId: state.userId,
        phase: FocusPhase.breakTime,
        instant: end,
        title: '休息结束',
        body: '可以开始下一轮专注了',
      );
    }
  }

  Future<void> cancelFocus(String userId) async {
    await initialize();
    await _plugin.cancel(id: _focusNotificationId(userId, FocusPhase.focus));
    await _plugin.cancel(
      id: _focusNotificationId(userId, FocusPhase.breakTime),
    );
  }

  Future<void> _scheduleFocusPhase({
    required String userId,
    required FocusPhase phase,
    required DateTime instant,
    required String title,
    required String body,
  }) async {
    await _plugin.zonedSchedule(
      id: _focusNotificationId(userId, phase),
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(instant, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _focusChannelId,
          _focusChannelName,
          channelDescription: _focusChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: jsonEncode({
        'kind': _focusPayloadKind,
        'userId': userId,
        'phase': phase.wireValue,
      }),
    );
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

  FocusNotificationTarget? _decodeFocusPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final value = jsonDecode(payload);
      if (value is! Map) return null;
      final json = Map<String, dynamic>.from(value);
      if (json['kind'] != _focusPayloadKind) return null;
      final userId = json['userId']?.toString();
      final phase = json['phase']?.toString();
      if (userId == null ||
          userId.isEmpty ||
          phase == null ||
          phase.isEmpty) {
        return null;
      }
      return FocusNotificationTarget(
        userId: userId,
        phase: FocusPhase.fromWire(phase),
      );
    } catch (_) {
      return null;
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

  static int _focusNotificationId(String userId, FocusPhase phase) =>
      _stableId('focus:$userId:${phase.wireValue}');

  static int _notificationId(String reminderId) =>
      _stableId('reminder:$reminderId');

  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  static int _legacyNotificationId(String reminderId) =>
      _stableId('reminder:$reminderId');
}
