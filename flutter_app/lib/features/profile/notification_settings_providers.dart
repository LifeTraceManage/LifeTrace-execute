import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_preferences.dart';
import '../focus/focus_providers.dart';
import '../reminders/reminder_providers.dart';
import '../tasks/task_providers.dart';

final notificationSettingsCommandsProvider =
    Provider<NotificationSettingsCommands>(NotificationSettingsCommands.new);

class NotificationSettingsCommands {
  NotificationSettingsCommands(this.ref);

  final Ref ref;

  Future<void> setRemindersEnabled(bool enabled) async {
    final current = await ref.read(notificationPreferencesProvider.future);
    if (current.remindersEnabled == enabled) return;

    if (enabled && !kIsWeb) {
      final allowed = await ref
          .read(reminderNotificationBridgeProvider)
          .service
          .requestPermission();
      if (!allowed) {
        throw StateError('系统通知权限未开启');
      }
    }

    final next = current.copyWith(remindersEnabled: enabled);
    await ref.read(notificationPreferencesStoreProvider).save(next);
    ref.invalidate(notificationPreferencesProvider);

    if (kIsWeb) return;
    if (enabled) {
      await ref.read(reminderCommandsProvider).reconcile();
    } else {
      await ref
          .read(reminderNotificationBridgeProvider)
          .service
          .cancelAllReminders();
    }
  }

  Future<void> setFocusEnabled(bool enabled) async {
    final current = await ref.read(notificationPreferencesProvider.future);
    if (current.focusEnabled == enabled) return;

    if (enabled && !kIsWeb) {
      final allowed = await ref
          .read(reminderNotificationBridgeProvider)
          .service
          .requestPermission();
      if (!allowed) {
        throw StateError('系统通知权限未开启');
      }
    }

    final next = current.copyWith(focusEnabled: enabled);
    await ref.read(notificationPreferencesStoreProvider).save(next);
    ref.invalidate(notificationPreferencesProvider);

    if (kIsWeb) return;
    final service = ref.read(reminderNotificationBridgeProvider).service;
    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null) return;
    if (!enabled) {
      await service.cancelFocus(userId);
      return;
    }
    final state = await ref.read(focusTimerStateProvider.future);
    await service.reconcileFocus(state);
  }
}
