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
  });

  Future<void> initialize() async {}
  Future<bool> requestPermission() async => true;
  Future<void> schedule(ExecutionReminder reminder) async {}
  Future<void> cancel(String reminderId) async {}
  Future<void> reconcileFocus(FocusTimerState? state) async {}
  Future<void> cancelFocus(String userId) async {}
  Future<void> reconcile(List<ExecutionReminder> reminders) async {}
}
