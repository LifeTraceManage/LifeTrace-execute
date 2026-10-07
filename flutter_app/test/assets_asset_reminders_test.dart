import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/workspaces/assets/src/domain/asset_models.dart';
import 'package:lifetrace_execute/workspaces/assets/src/domain/asset_reminders.dart';

AssetItem _asset({
  required String id,
  required AssetStatus status,
  DateTime? warrantyUntil,
}) {
  final now = DateTime(2026, 9, 11);
  return AssetItem(
    id: id,
    name: id,
    brand: 'LifeTrace',
    model: 'V1',
    category: AssetCategory.other,
    status: status,
    purchasePrice: 1000,
    currentValue: 800,
    purchaseDate: DateTime(2026, 1, 1),
    warrantyUntil: warrantyUntil,
    spec: '',
    serialNumber: '',
    location: '',
    targetDailyCost: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('creates warranty reminder only inside the configured window', () {
    final now = DateTime(2026, 9, 11);
    final reminders = buildAssetReminders(
      [
        _asset(
          id: 'inside',
          status: AssetStatus.active,
          warrantyUntil: now.add(const Duration(days: 30)),
        ),
        _asset(
          id: 'outside',
          status: AssetStatus.active,
          warrantyUntil: now.add(const Duration(days: 120)),
        ),
        _asset(
          id: 'expired',
          status: AssetStatus.active,
          warrantyUntil: now.subtract(const Duration(days: 1)),
        ),
      ],
      now: now,
    );

    expect(reminders, hasLength(1));
    expect(reminders.single.assetId, 'inside');
    expect(reminders.single.type, AssetReminderType.warranty);
  });

  test('creates idle and repair reminders from current status', () {
    final now = DateTime(2026, 9, 11);
    final reminders = buildAssetReminders(
      [
        _asset(id: 'idle', status: AssetStatus.idle),
        _asset(id: 'repair', status: AssetStatus.repair),
        _asset(id: 'active', status: AssetStatus.active),
      ],
      now: now,
    );

    expect(
      reminders.map((reminder) => reminder.type),
      containsAll([AssetReminderType.idle, AssetReminderType.repair]),
    );
    expect(reminders.where((r) => r.assetId == 'active'), isEmpty);
  });

  test('one asset may produce both warranty and state reminders', () {
    final now = DateTime(2026, 9, 11);
    final reminders = buildAssetReminders(
      [
        _asset(
          id: 'idle-soon',
          status: AssetStatus.idle,
          warrantyUntil: now.add(const Duration(days: 7)),
        ),
      ],
      now: now,
    );

    expect(reminders, hasLength(2));
    expect(
      reminders.map((reminder) => reminder.type).toSet(),
      {AssetReminderType.warranty, AssetReminderType.idle},
    );
  });
}
