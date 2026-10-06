import 'asset_models.dart';

class AssetAnalyticsSnapshot {
  const AssetAnalyticsSnapshot({
    required this.assetCount,
    required this.totalPurchase,
    required this.totalValue,
    required this.totalMaintenance,
    required this.totalRecovered,
    required this.retentionPercent,
    required this.categoryValues,
    required this.statusCounts,
    required this.dailyCostRanking,
    required this.addedThisMonth,
    required this.soldThisMonth,
    required this.maintenanceThisMonth,
  });

  final int assetCount;
  final double totalPurchase;
  final double totalValue;
  final double totalMaintenance;
  final double totalRecovered;
  final double retentionPercent;
  final Map<AssetCategory, double> categoryValues;
  final Map<AssetStatus, int> statusCounts;
  final List<AssetItem> dailyCostRanking;
  final int addedThisMonth;
  final int soldThisMonth;
  final int maintenanceThisMonth;

  int countForStatus(AssetStatus status) => statusCounts[status] ?? 0;

  double categoryRatio(AssetCategory category) {
    if (totalValue <= 0) return 0;
    return (categoryValues[category] ?? 0) / totalValue;
  }
}

AssetAnalyticsSnapshot buildAssetAnalytics({
  required Iterable<AssetItem> assets,
  required Iterable<AssetEvent> events,
  required DateTime now,
}) {
  final assetList = assets.where((asset) => !asset.isDeleted).toList(growable: false);
  final validAssetIds = assetList.map((asset) => asset.id).toSet();
  final eventList = events
      .where(
        (event) =>
            !event.isDeleted && validAssetIds.contains(event.assetId),
      )
      .toList(growable: false);

  var totalPurchase = 0.0;
  var totalValue = 0.0;
  var totalMaintenance = 0.0;
  var totalRecovered = 0.0;
  final categoryValues = <AssetCategory, double>{};
  final statusCounts = <AssetStatus, int>{};

  for (final asset in assetList) {
    totalPurchase += asset.purchasePrice;
    totalValue += asset.currentValue;
    totalMaintenance += asset.maintenanceCost;
    totalRecovered += asset.recoveredAmount;
    categoryValues.update(
      asset.category,
      (value) => value + asset.currentValue,
      ifAbsent: () => asset.currentValue,
    );
    statusCounts.update(
      asset.status,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }

  bool isCurrentMonth(DateTime value) =>
      value.year == now.year && value.month == now.month;

  final ranking = [...assetList]
    ..sort((a, b) {
      final byCost = b.dailyCost.compareTo(a.dailyCost);
      if (byCost != 0) return byCost;
      return a.id.compareTo(b.id);
    });

  final maintenanceTypes = {
    AssetEventType.maintenance,
    AssetEventType.repair,
    AssetEventType.replacement,
  };

  return AssetAnalyticsSnapshot(
    assetCount: assetList.length,
    totalPurchase: totalPurchase,
    totalValue: totalValue,
    totalMaintenance: totalMaintenance,
    totalRecovered: totalRecovered,
    retentionPercent:
        totalPurchase <= 0 ? 0 : totalValue / totalPurchase * 100,
    categoryValues: Map.unmodifiable(categoryValues),
    statusCounts: Map.unmodifiable(statusCounts),
    dailyCostRanking: List.unmodifiable(ranking),
    addedThisMonth:
        assetList.where((asset) => isCurrentMonth(asset.createdAt)).length,
    soldThisMonth: eventList
        .where(
          (event) =>
              event.type == AssetEventType.sell && isCurrentMonth(event.date),
        )
        .length,
    maintenanceThisMonth: eventList
        .where(
          (event) =>
              maintenanceTypes.contains(event.type) &&
              isCurrentMonth(event.date),
        )
        .length,
  );
}
