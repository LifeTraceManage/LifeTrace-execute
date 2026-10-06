import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/workspaces/assets/src/domain/asset_analytics.dart';
import 'package:lifetrace_execute/workspaces/assets/src/domain/asset_models.dart';

AssetItem _asset({
  required String id,
  required double purchase,
  required double value,
  AssetCategory category = AssetCategory.other,
  AssetStatus status = AssetStatus.active,
  double maintenance = 0,
  double recovered = 0,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime(2026, 9, 11);
  return AssetItem(
    id: id,
    name: id,
    brand: 'LifeTrace',
    model: 'V1',
    category: category,
    status: status,
    purchasePrice: purchase,
    currentValue: value,
    purchaseDate: DateTime(2026, 1, 1),
    warrantyUntil: null,
    spec: '',
    serialNumber: '',
    location: '',
    targetDailyCost: 0,
    maintenanceCost: maintenance,
    recoveredAmount: recovered,
    createdAt: now,
    updatedAt: now,
  );
}

AssetEvent _event({
  required String id,
  required String assetId,
  required AssetEventType type,
  required DateTime date,
  double? amount,
}) {
  return AssetEvent(
    id: id,
    assetId: assetId,
    type: type,
    date: date,
    title: id,
    detail: '',
    amount: amount,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  test('empty analytics are safe zero values', () {
    final analytics = buildAssetAnalytics(
      assets: const [],
      events: const [],
      now: DateTime(2026, 9, 11),
    );

    expect(analytics.assetCount, 0);
    expect(analytics.totalPurchase, 0);
    expect(analytics.totalValue, 0);
    expect(analytics.retentionPercent, 0);
    expect(analytics.categoryValues, isEmpty);
    expect(analytics.dailyCostRanking, isEmpty);
    expect(analytics.addedThisMonth, 0);
    expect(analytics.soldThisMonth, 0);
    expect(analytics.maintenanceThisMonth, 0);
  });

  test('valuation and status metrics are derived from current assets', () {
    final analytics = buildAssetAnalytics(
      assets: [
        _asset(
          id: 'phone',
          purchase: 1000,
          value: 700,
          category: AssetCategory.phone,
          status: AssetStatus.active,
          maintenance: 100,
        ),
        _asset(
          id: 'camera',
          purchase: 2000,
          value: 1000,
          category: AssetCategory.camera,
          status: AssetStatus.idle,
          recovered: 200,
        ),
      ],
      events: const [],
      now: DateTime(2026, 9, 11),
    );

    expect(analytics.totalPurchase, 3000);
    expect(analytics.totalValue, 1700);
    expect(analytics.totalMaintenance, 100);
    expect(analytics.totalRecovered, 200);
    expect(analytics.retentionPercent, closeTo(56.6666, 0.001));
    expect(analytics.countForStatus(AssetStatus.active), 1);
    expect(analytics.countForStatus(AssetStatus.idle), 1);
    expect(analytics.categoryValues[AssetCategory.phone], 700);
    expect(analytics.categoryRatio(AssetCategory.camera), closeTo(1000 / 1700, 0.0001));
  });

  test('monthly activity only counts current month and valid active assets', () {
    final now = DateTime(2026, 9, 11);
    final assets = [
      _asset(
        id: 'current',
        purchase: 1000,
        value: 800,
        createdAt: DateTime(2026, 9, 3),
      ),
      _asset(
        id: 'old',
        purchase: 1000,
        value: 800,
        createdAt: DateTime(2026, 8, 30),
      ),
    ];
    final analytics = buildAssetAnalytics(
      assets: assets,
      events: [
        _event(
          id: 'sale-current',
          assetId: 'current',
          type: AssetEventType.sell,
          date: DateTime(2026, 9, 5),
        ),
        _event(
          id: 'repair-current',
          assetId: 'current',
          type: AssetEventType.repair,
          date: DateTime(2026, 9, 6),
        ),
        _event(
          id: 'repair-old',
          assetId: 'current',
          type: AssetEventType.repair,
          date: DateTime(2026, 8, 31),
        ),
        _event(
          id: 'orphan',
          assetId: 'missing',
          type: AssetEventType.sell,
          date: DateTime(2026, 9, 7),
        ),
      ],
      now: now,
    );

    expect(analytics.addedThisMonth, 1);
    expect(analytics.soldThisMonth, 1);
    expect(analytics.maintenanceThisMonth, 1);
  });

  test('daily-cost ranking is deterministic on equal values', () {
    final analytics = buildAssetAnalytics(
      assets: [
        _asset(id: 'b', purchase: 1000, value: 800),
        _asset(id: 'a', purchase: 1000, value: 800),
      ],
      events: const [],
      now: DateTime(2026, 9, 11),
    );

    expect(
      analytics.dailyCostRanking.map((asset) => asset.id).toList(),
      ['a', 'b'],
    );
  });
}
