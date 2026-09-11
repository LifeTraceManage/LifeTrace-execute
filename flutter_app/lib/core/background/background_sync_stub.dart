class BackgroundSyncScheduler {
  const BackgroundSyncScheduler._();

  static Future<void> initialize() async {}
  static Future<void> schedulePeriodic() async {}
  static Future<void> enqueueInitialSync() async {}
  static Future<void> enqueueAfterLocalChange() async {}
  static Future<void> cancelForLogout() async {}
}
