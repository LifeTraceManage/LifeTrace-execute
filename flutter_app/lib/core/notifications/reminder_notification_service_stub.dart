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
  ReminderNotificationService({ReminderNotificationTap? onTap});

  Future<void> initialize() async {}
  Future<bool> requestPermission() async => true;
  Future<void> schedule(ExecutionReminder reminder) async {}
  Future<void> cancel(String reminderId) async {}
  Future<void> reconcile(List<ExecutionReminder> reminders) async {}
}
