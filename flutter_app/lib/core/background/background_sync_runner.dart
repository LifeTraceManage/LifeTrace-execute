import '../../core/cloud/cloud_contract.dart';
import '../../core/cloud/cloud_session_manager.dart';
import '../../core/identity/device_identity_store.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../../data/local/app_database.dart';
import '../../data/repository/reminder_repository.dart';
import '../../data/sync/media_upload_coordinator.dart';
import '../../data/sync/task_sync_coordinator.dart';

enum BackgroundSyncOutcome { success, retry, failure }

typedef BackgroundSyncAction = Future<void> Function();
typedef BackgroundMediaAction = Future<MediaUploadSummary> Function();

class BackgroundSyncRunner {
  const BackgroundSyncRunner({
    required this.sync,
    required this.uploadMedia,
  });

  final BackgroundSyncAction sync;
  final BackgroundMediaAction uploadMedia;

  Future<BackgroundSyncOutcome> run() async {
    try {
      await sync();
      final media = await uploadMedia();
      if (media.completed > 0) {
        await sync();
      }
      return media.failed > 0
          ? BackgroundSyncOutcome.retry
          : BackgroundSyncOutcome.success;
    } on CloudApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return BackgroundSyncOutcome.failure;
      }
      if (error.retryable ||
          error.statusCode == 0 ||
          error.statusCode == 429 ||
          error.statusCode >= 500) {
        return BackgroundSyncOutcome.retry;
      }
      return BackgroundSyncOutcome.failure;
    } on StateError catch (error) {
      final message = error.message.toString();
      if (message.contains('Refresh Token') ||
          message.contains('尚未连接 LifeTrace Cloud')) {
        return BackgroundSyncOutcome.failure;
      }
      return BackgroundSyncOutcome.failure;
    }
  }
}

Future<BackgroundSyncOutcome> runProductionBackgroundSync() async {
  final sessionManager = CloudSessionManager();
  final session = await sessionManager.currentSession();
  if (session == null) {
    return BackgroundSyncOutcome.success;
  }

  final database = AppDatabase.production();
  try {
    final identityStore = DeviceIdentityStore();
    final runner = BackgroundSyncRunner(
      sync: () => TaskSyncCoordinator(
        database: database,
        sessionManager: sessionManager,
        deviceIdLoader: identityStore.getOrCreate,
      ).syncNow(),
      uploadMedia: () => MediaUploadCoordinator(
        database: database,
        sessionManager: sessionManager,
        deviceIdLoader: identityStore.getOrCreate,
      ).processPending(),
    );
    final outcome = await runner.run();

    try {
      final reminders =
          await DriftReminderRepository(database).listReminders(session.userId);
      final notifications = ReminderNotificationService();
      await notifications.initialize();
      await notifications.reconcile(reminders);
    } catch (_) {
      // Notification reconciliation is best effort and must not poison Sync v1.
    }

    return outcome;
  } finally {
    await database.close();
  }
}
