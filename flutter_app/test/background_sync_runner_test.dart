import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/background/background_sync_runner.dart';
import 'package:lifetrace_execute/core/cloud/cloud_contract.dart';
import 'package:lifetrace_execute/data/sync/media_upload_coordinator.dart';

void main() {
  test('background sync uploads media then syncs generated metadata', () async {
    var syncCalls = 0;
    final runner = BackgroundSyncRunner(
      sync: () async => syncCalls++,
      uploadMedia: () async =>
          const MediaUploadSummary(completed: 2, failed: 0),
    );

    final outcome = await runner.run();

    expect(outcome, BackgroundSyncOutcome.success);
    expect(syncCalls, 2);
  });

  test('failed media upload asks WorkManager to retry', () async {
    final runner = BackgroundSyncRunner(
      sync: () async {},
      uploadMedia: () async =>
          const MediaUploadSummary(completed: 0, failed: 1),
    );

    expect(await runner.run(), BackgroundSyncOutcome.retry);
  });

  test('retryable Cloud errors ask WorkManager to retry', () async {
    final runner = BackgroundSyncRunner(
      sync: () async => throw const CloudApiException(
        statusCode: 503,
        code: 'TEMPORARY',
        retryable: true,
        message: 'temporary outage',
      ),
      uploadMedia: () async =>
          const MediaUploadSummary(completed: 0, failed: 0),
    );

    expect(await runner.run(), BackgroundSyncOutcome.retry);
  });

  test('authentication errors fail without retry loop', () async {
    final runner = BackgroundSyncRunner(
      sync: () async => throw const CloudApiException(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        retryable: false,
        message: 'expired session',
      ),
      uploadMedia: () async =>
          const MediaUploadSummary(completed: 0, failed: 0),
    );

    expect(await runner.run(), BackgroundSyncOutcome.failure);
  });
}
