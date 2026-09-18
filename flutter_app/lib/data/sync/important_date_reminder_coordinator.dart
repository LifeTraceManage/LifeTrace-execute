import '../../domain/important_date/execution_important_date.dart';
import '../../domain/important_date/important_date_occurrence.dart';
import '../../domain/reminder/execution_reminder.dart';
import '../repository/important_date_repository.dart';
import '../repository/reminder_repository.dart';

class ImportantDateReminderCoordinator {
  const ImportantDateReminderCoordinator({
    required this.importantDates,
    required this.reminders,
  });

  final ImportantDateRepository importantDates;
  final ReminderRepository reminders;

  Future<int> reconcileYearlyFired({
    required String userId,
    required String deviceId,
  }) async {
    final dates = await importantDates.listImportantDates(userId);
    var changed = 0;

    for (final item in dates) {
      if (!item.enabled || item.repeat != ImportantDateRepeat.yearly) continue;

      final subjectReminders = await reminders.listForSubject(
        userId: userId,
        subjectType: ReminderSubjectTypes.importantDate,
        subjectId: item.id,
      );
      if (subjectReminders.any((candidate) => candidate.isScheduled)) continue;
      if (subjectReminders.isEmpty) continue;

      final ordered = List<ExecutionReminder>.from(subjectReminders)
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      final latest = ordered.first;
      if (latest.status != ExecutionReminderStatus.fired) continue;

      final trigger = _nextTrigger(item, latest);
      if (trigger == null) continue;

      await reminders.reschedule(
        reminder: latest,
        deviceId: deviceId,
        triggerAt: trigger.toUtc().toIso8601String(),
      );
      changed++;
    }

    return changed;
  }

  static DateTime? _nextTrigger(
    ExecutionImportantDate item,
    ExecutionReminder fired,
  ) {
    final now = DateTime.now();
    final previous =
        DateTime.tryParse(fired.triggerAt)?.toLocal() ?? now;
    var occurrence = nextImportantDateOccurrence(item, from: now);

    DateTime candidateFor(DateTime date) => DateTime(
          date.year,
          date.month,
          date.day,
          previous.hour,
          previous.minute,
          previous.second,
        );

    if (occurrence != null) {
      final candidate = candidateFor(occurrence);
      if (candidate.isAfter(now)) return candidate;
    }

    final tomorrow = DateTime(now.year, now.month, now.day)
        .add(const Duration(days: 1));
    occurrence = nextImportantDateOccurrence(item, from: tomorrow);
    return occurrence == null ? null : candidateFor(occurrence);
  }
}
