import 'asset_models.dart';

enum AssetReminderType {
  warranty,
  idle,
  repair,
}

class AssetReminder {
  const AssetReminder({
    required this.assetId,
    required this.type,
    required this.title,
    required this.body,
  });

  final String assetId;
  final AssetReminderType type;
  final String title;
  final String body;
}

List<AssetReminder> buildAssetReminders(
  Iterable<AssetItem> assets, {
  required DateTime now,
  int warrantyWindowDays = 90,
}) {
  final reminders = <AssetReminder>[];

  for (final asset in assets) {
    final warranty = asset.warrantyUntil;
    if (warranty != null) {
      final days = warranty.difference(now).inDays;
      if (days >= 0 && days <= warrantyWindowDays) {
        reminders.add(
          AssetReminder(
            assetId: asset.id,
            type: AssetReminderType.warranty,
            title: '${asset.name} 即将过保',
            body: '剩余 $days 天 · ${_date(warranty)}',
          ),
        );
      }
    }

    if (asset.status == AssetStatus.idle) {
      reminders.add(
        AssetReminder(
          assetId: asset.id,
          type: AssetReminderType.idle,
          title: '${asset.name} 当前闲置',
          body: '可以评估继续使用、借出、出售或退役',
        ),
      );
    }

    if (asset.status == AssetStatus.repair) {
      reminders.add(
        AssetReminder(
          assetId: asset.id,
          type: AssetReminderType.repair,
          title: '${asset.name} 正在维修',
          body: '建议补充维修结果、费用和状态变化记录',
        ),
      );
    }
  }

  return reminders;
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
