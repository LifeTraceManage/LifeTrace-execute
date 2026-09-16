import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/cloud/cloud_contract.dart';
import 'package:lifetrace_execute/features/profile/conflict_center_providers.dart';

void main() {
  test('conflict center covers every required Sync v1 entity type', () {
    expect(
      CloudContract.requiredSyncEntityTypes
          .difference(conflictCenterSupportedEntityTypes),
      isEmpty,
    );
  });

  test('conflict center exposes readable labels for required entities', () {
    for (final entityType in CloudContract.requiredSyncEntityTypes) {
      expect(
        conflictEntityLabel(entityType),
        isNot(equals(entityType)),
        reason: 'missing readable label for $entityType',
      );
    }
  });
}
