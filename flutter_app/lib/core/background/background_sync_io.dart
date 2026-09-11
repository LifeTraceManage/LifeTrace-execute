import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import 'background_sync_runner.dart';

const _initialWork = 'lifetrace-sync-after-cloud-login';
const _localChangeWork = 'lifetrace-sync-after-local-change';
const _periodicWork = 'lifetrace-sync-periodic';
const _backgroundTask = 'lifetrace.background.sync';

@pragma('vm:entry-point')
void lifeTraceBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (task != _backgroundTask) return true;

    final outcome = await runProductionBackgroundSync();
    return switch (outcome) {
      BackgroundSyncOutcome.success => true,
      BackgroundSyncOutcome.retry => false,
      BackgroundSyncOutcome.failure =>
        throw StateError('LifeTrace background sync failed permanently'),
    };
  });
}

class BackgroundSyncScheduler {
  const BackgroundSyncScheduler._();

  static const _network = Constraints(networkType: NetworkType.connected);

  static Future<void> initialize() async {
    await Workmanager().initialize(lifeTraceBackgroundDispatcher);
    await schedulePeriodic();
  }

  static Future<void> schedulePeriodic() {
    return Workmanager().registerPeriodicTask(
      _periodicWork,
      _backgroundTask,
      frequency: const Duration(hours: 6),
      constraints: _network,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

  static Future<void> enqueueInitialSync() {
    return Workmanager().registerOneOffTask(
      _initialWork,
      _backgroundTask,
      constraints: _network,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }

  static Future<void> cancelForLogout() async {
    await Workmanager().cancelByUniqueName(_initialWork);
    await Workmanager().cancelByUniqueName(_localChangeWork);
    await Workmanager().cancelByUniqueName(_periodicWork);
  }

  static Future<void> enqueueAfterLocalChange() {
    return Workmanager().registerOneOffTask(
      _localChangeWork,
      _backgroundTask,
      initialDelay: const Duration(seconds: 3),
      constraints: _network,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(seconds: 30),
    );
  }
}
