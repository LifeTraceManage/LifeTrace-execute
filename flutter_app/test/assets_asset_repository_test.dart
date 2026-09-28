import 'dart:io';

import 'package:sembast/sembast_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/workspaces/assets/src/data/asset_repository.dart';
import 'package:lifetrace_execute/workspaces/assets/src/domain/asset_models.dart';

AssetItem makeAsset({
  String id = 'asset-1',
  double purchasePrice = 1000,
  double currentValue = 800,
}) {
  final now = DateTime(2026, 9, 11, 12);
  return AssetItem(
    id: id,
    name: 'Test Asset',
    brand: 'LifeTrace',
    model: 'V1',
    category: AssetCategory.other,
    status: AssetStatus.active,
    purchasePrice: purchasePrice,
    currentValue: currentValue,
    purchaseDate: DateTime(2026, 1, 1),
    warrantyUntil: DateTime(2027, 1, 1),
    spec: 'test',
    serialNumber: 'SN-1',
    location: 'desk',
    targetDailyCost: 5,
    createdAt: now,
    updatedAt: now,
  );
}

AssetEntityLink makeLink({
  String id = 'link-1',
  String sourceAssetId = 'asset-1',
  String targetEntityType = 'execution.project',
  String targetEntityId = 'project-1',
  String targetLabel = 'Project Alpha',
}) {
  final now = DateTime(2026, 9, 11, 12);
  return AssetEntityLink(
    id: id,
    userId: 'user-1',
    sourceAssetId: sourceAssetId,
    targetEntityType: targetEntityType,
    targetEntityId: targetEntityId,
    relationType: 'references',
    targetLabel: targetLabel,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('AssetRepository', () {
    late AssetRepository repository;

    setUp(() async {
      repository = await AssetRepository.inMemory('asset_repository_test.db');
      await repository.clearAll();
    });

    tearDown(() async {
      await repository.close();
    });

    test('reopens a file database without losing persisted entities', () async {
      final directory =
          await Directory.systemTemp.createTemp('lifetrace-assets-reopen-');
      final path = '${directory.path}/assets.db';

      var persistent = AssetRepository.fromDatabase(
        await databaseFactoryIo.openDatabase(path),
      );
      await persistent.clearAll();
      await persistent.upsertAsset(makeAsset());
      await persistent.close();

      persistent = AssetRepository.fromDatabase(
        await databaseFactoryIo.openDatabase(path),
      );
      final assets = await persistent.listAssets();
      final outbox = await persistent.listOutbox();

      expect(assets, hasLength(1));
      expect(assets.single.id, 'asset-1');
      expect(outbox, hasLength(1));

      await persistent.close();
      await directory.delete(recursive: true);
    });

    test('persists asset and queues sync mutation', () async {
      final saved = await repository.upsertAsset(makeAsset());

      final assets = await repository.listAssets();
      final outbox = await repository.listOutbox();

      expect(assets, hasLength(1));
      expect(assets.single.id, saved.id);
      expect(outbox, hasLength(1));
      expect(outbox.single['entityType'], 'asset.asset');
      expect(outbox.single['operation'], 'upsert');
    });

    test('lifecycle maintenance and sale update derived asset totals', () async {
      await repository.upsertAsset(makeAsset());
      final now = DateTime(2026, 9, 11, 13);

      await repository.upsertEvent(
        AssetEvent(
          id: 'event-maintenance',
          assetId: 'asset-1',
          type: AssetEventType.maintenance,
          date: now,
          title: 'Maintenance',
          detail: 'battery',
          amount: 100,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await repository.upsertEvent(
        AssetEvent(
          id: 'event-sale',
          assetId: 'asset-1',
          type: AssetEventType.sell,
          date: now.add(const Duration(hours: 1)),
          title: 'Sold',
          detail: 'marketplace',
          amount: 300,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final asset = (await repository.listAssets()).single;
      expect(asset.maintenanceCost, 100);
      expect(asset.recoveredAmount, 300);
      expect(asset.status, AssetStatus.sold);
      expect(asset.effectiveCost, 800);
      expect(await repository.pendingOutboxCount(), 5);
    });

    test('deleting asset hides asset and its events but retains tombstones', () async {
      await repository.upsertAsset(makeAsset());
      final now = DateTime(2026, 9, 11, 13);
      await repository.upsertEvent(
        AssetEvent(
          id: 'event-1',
          assetId: 'asset-1',
          type: AssetEventType.note,
          date: now,
          title: 'Note',
          detail: 'detail',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repository.deleteAsset('asset-1');

      expect(await repository.listAssets(), isEmpty);
      expect(await repository.listEvents(), isEmpty);
      final allAssets = await repository.listAssets(includeDeleted: true);
      final allEvents = await repository.listEvents(includeDeleted: true);
      expect(allAssets.single.isDeleted, isTrue);
      expect(allEvents.single.isDeleted, isTrue);
      expect((await repository.listOutbox()).where((item) => item['operation'] == 'delete'), hasLength(2));
    });

    test('persists EntityLink with Cloud wire payload and queues sync', () async {
      await repository.upsertAsset(makeAsset());
      await repository.upsertLink(makeLink());

      final links = await repository.listLinks(sourceAssetId: 'asset-1');
      expect(links, hasLength(1));
      expect(links.single.targetEntityType, 'execution.project');
      expect(links.single.targetEntityId, 'project-1');

      final outbox = await repository.listOutbox();
      final linkChange =
          outbox.singleWhere((item) => item['entityType'] == 'entity.link');
      final payload =
          Map<String, Object?>.from(linkChange['payload'] as Map);
      final meta = Map<String, Object?>.from(payload['meta'] as Map);
      final source = Map<String, Object?>.from(payload['source'] as Map);
      final target = Map<String, Object?>.from(payload['target'] as Map);
      expect(meta['id'], 'link-1');
      expect(meta['userId'], 'user-1');
      expect(meta['serverVersion'], isNull);
      expect(source['entityType'], 'asset.asset');
      expect(source['entityId'], 'asset-1');
      expect(target['entityType'], 'execution.project');
      expect(target['entityId'], 'project-1');
    });

    test('deleting asset also tombstones and queues deletion for source links',
        () async {
      await repository.upsertAsset(makeAsset());
      await repository.upsertLink(makeLink());

      await repository.deleteAsset('asset-1');

      expect(await repository.listLinks(), isEmpty);
      final allLinks = await repository.listLinks(includeDeleted: true);
      expect(allLinks, hasLength(1));
      expect(allLinks.single.isDeleted, isTrue);

      final deletes = (await repository.listOutbox())
          .where((item) => item['operation'] == 'delete')
          .toList();
      expect(
        deletes.any((item) => item['entityType'] == 'entity.link'),
        isTrue,
      );
    });

    test('accepted EntityLink mutation rebases nested meta serverVersion',
        () async {
      await repository.upsertAsset(makeAsset());
      await repository.upsertLink(makeLink());
      await repository.upsertLink(
        makeLink(targetLabel: 'Renamed Project'),
      );

      final linkOutbox = (await repository.listOutbox())
          .where((item) => item['entityType'] == 'entity.link')
          .toList();
      expect(linkOutbox, hasLength(2));

      await repository.acknowledgeChange(
        changeId: linkOutbox.first['id'].toString(),
        entityType: 'entity.link',
        entityId: 'link-1',
        serverVersion: '12',
      );

      final link = (await repository.listLinks()).single;
      expect(link.serverVersion, '12');

      final remaining = (await repository.listOutbox())
          .singleWhere((item) => item['entityType'] == 'entity.link');
      expect(remaining['baseServerVersion'], '12');
      final payload = Map<String, Object?>.from(remaining['payload'] as Map);
      final meta = Map<String, Object?>.from(payload['meta'] as Map);
      expect(meta['serverVersion'], '12');
      expect(payload.containsKey('serverVersion'), isFalse);
    });

    test('blocked head prevents later mutations for the same entity from leapfrogging', () async {
      await repository.upsertAsset(makeAsset());
      await repository.upsertAsset(
        makeAsset().copyWith(currentValue: 700),
      );
      final outbox = await repository.listOutbox();
      expect(outbox, hasLength(2));

      await repository.markOutboxRejected(
        outbox.first['id'].toString(),
        code: 'INVALID_PAYLOAD',
        message: 'invalid',
      );

      expect(await repository.listPushableOutboxHeads(), isEmpty);
      final all = await repository.listOutbox();
      expect(all.first['blocked'], isTrue);
      expect(all.last['blocked'], isFalse);
      final issues = await repository.listSyncIssues();
      expect(issues, hasLength(1));
      expect(issues.single.errorCode, 'INVALID_PAYLOAD');
    });

    test('accepted mutation rebases the next change for the same entity', () async {
      await repository.upsertAsset(makeAsset());
      await repository.upsertAsset(
        makeAsset().copyWith(currentValue: 750),
      );

      final before = await repository.listOutbox();
      expect(before, hasLength(2));

      await repository.acknowledgeChange(
        changeId: before.first['id'].toString(),
        entityType: 'asset.asset',
        entityId: 'asset-1',
        serverVersion: '7',
      );

      final asset = (await repository.listAssets()).single;
      final remaining = await repository.listOutbox();
      expect(asset.serverVersion, '7');
      expect(remaining, hasLength(1));
      expect(remaining.single['baseServerVersion'], '7');
      expect(
        (remaining.single['payload'] as Map)['serverVersion'],
        '7',
      );
    });

    test('conflict can preserve local intent and rebase it explicitly', () async {
      await repository.upsertAsset(makeAsset());
      final pending = (await repository.listOutbox()).single;

      await repository.persistConflict(
        AssetSyncConflict(
          id: 'conflict-1',
          entityType: 'asset.asset',
          entityId: 'asset-1',
          changeId: pending['id'].toString(),
          currentServerVersion: '9',
          serverDeleted: false,
          reason: 'version_mismatch',
          createdAt: DateTime(2026, 9, 11, 14),
          localPayload: Map<String, Object?>.from(pending['payload'] as Map),
          serverPayload: makeAsset()
              .copyWith(currentValue: 700, serverVersion: '9')
              .toJson(),
        ),
      );

      expect(await repository.listConflicts(), hasLength(1));
      expect(
        (await repository.listOutbox()).single['blocked'],
        isTrue,
      );

      await repository.resolveConflictKeepLocal('conflict-1');

      expect(await repository.listConflicts(), isEmpty);
      final rebased = (await repository.listOutbox()).single;
      expect(rebased['blocked'], isFalse);
      expect(rebased['baseServerVersion'], '9');
    });

    test('conflict can accept server state and discard pending local mutation', () async {
      await repository.upsertAsset(makeAsset());
      final pending = (await repository.listOutbox()).single;

      await repository.persistConflict(
        AssetSyncConflict(
          id: 'conflict-server',
          entityType: 'asset.asset',
          entityId: 'asset-1',
          changeId: pending['id'].toString(),
          currentServerVersion: '11',
          serverDeleted: false,
          reason: 'version_mismatch',
          createdAt: DateTime(2026, 9, 11, 14),
          localPayload: Map<String, Object?>.from(pending['payload'] as Map),
          serverPayload: makeAsset()
              .copyWith(currentValue: 640, serverVersion: '11')
              .toJson(),
        ),
      );

      await repository.resolveConflictUseServer('conflict-server');

      expect(await repository.listOutbox(), isEmpty);
      expect(await repository.listConflicts(), isEmpty);
      final asset = (await repository.listAssets()).single;
      expect(asset.currentValue, 640);
      expect(asset.serverVersion, '11');
    });

    test('invalid backup does not partially replace local data', () async {
      await repository.upsertAsset(makeAsset());

      await expectLater(
        repository.importBackupJson(
          '{"format":"lifetrace-assets-backup","version":999,"assets":[],"events":[]}',
        ),
        throwsFormatException,
      );

      final assets = await repository.listAssets();
      expect(assets, hasLength(1));
      expect(assets.single.id, 'asset-1');

      await expectLater(
        repository.importBackupJson('{"format":"lifetrace-assets-backup"'),
        throwsFormatException,
      );

      expect(await repository.listAssets(), hasLength(1));
    });

    test('version 1 backup remains compatible and restores no links', () async {
      const v1 = '''
{
  "format": "lifetrace-assets-backup",
  "version": 1,
  "assets": [
    {
      "id": "asset-v1",
      "name": "Legacy",
      "brand": "",
      "model": "",
      "category": "other",
      "status": "active",
      "purchasePrice": 10,
      "currentValue": 8,
      "purchaseDate": "2026-01-01T00:00:00.000Z",
      "warrantyUntil": null,
      "spec": "",
      "serialNumber": "",
      "location": "",
      "targetDailyCost": 0,
      "purchaseChannel": "",
      "maintenanceCost": 0,
      "recoveredAmount": 0,
      "createdAt": "2026-01-01T00:00:00.000Z",
      "updatedAt": "2026-01-01T00:00:00.000Z",
      "isDeleted": false,
      "serverVersion": "3"
    }
  ],
  "events": []
}
''';

      await repository.importBackupJson(v1);

      expect(await repository.listAssets(), hasLength(1));
      expect(await repository.listLinks(), isEmpty);
      expect((await repository.listAssets()).single.serverVersion, '0');
      expect(await repository.pendingOutboxCount(), 1);
    });

    test('version 2 backup restores links at server version zero', () async {
      await repository.upsertAsset(makeAsset());
      await repository.upsertLink(
        makeLink().copyWith(serverVersion: '8'),
      );

      final backup = await repository.exportBackupJson();
      await repository.clearAll();
      await repository.importBackupJson(backup);

      final links = await repository.listLinks();
      expect(links, hasLength(1));
      expect(links.single.serverVersion, '0');
      final linkOutbox = (await repository.listOutbox())
          .where((item) => item['entityType'] == 'entity.link')
          .toList();
      expect(linkOutbox, hasLength(1));
      final payload =
          Map<String, Object?>.from(linkOutbox.single['payload'] as Map);
      final meta = Map<String, Object?>.from(payload['meta'] as Map);
      expect(meta['serverVersion'], isNull);
    });

    test('backup export and restore rebuilds local data and sync outbox', () async {
      await repository.upsertAsset(makeAsset());
      final now = DateTime(2026, 9, 11, 13);
      await repository.upsertEvent(
        AssetEvent(
          id: 'event-backup',
          assetId: 'asset-1',
          type: AssetEventType.note,
          date: now,
          title: 'Backup note',
          detail: 'persist me',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final backup = await repository.exportBackupJson();
      await repository.clearAll();
      expect(await repository.listAssets(), isEmpty);

      await repository.importBackupJson(backup);

      final restoredAssets = await repository.listAssets();
      final restoredEvents = await repository.listEvents();
      expect(restoredAssets, hasLength(1));
      expect(restoredEvents, hasLength(1));
      expect(restoredAssets.single.serverVersion, '0');
      expect(restoredEvents.single.serverVersion, '0');
      expect(await repository.pendingOutboxCount(), 2);
    });

  });

  group('AssetItem calculations', () {
    test('effective cost never becomes negative', () {
      final asset = makeAsset().copyWith(
        maintenanceCost: 50,
        recoveredAmount: 5000,
      );

      expect(asset.effectiveCost, 0);
      expect(asset.dailyCost, 0);
    });

    test('retention is zero for zero purchase price', () {
      final asset = makeAsset(purchasePrice: 0, currentValue: 100);
      expect(asset.retentionRate, 0);
    });
  });
}
