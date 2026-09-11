import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/entity_link_repository.dart';
import 'package:lifetrace_execute/domain/collection/entity_link.dart';

void main() {
  test('entity link wire mapper matches Cloud EntityLink schema', () {
    const link = ExecutionEntityLink(
      id: 'link-1',
      userId: 'user-1',
      sourceType: 'execution.task',
      sourceId: 'task-1',
      targetType: 'execution.memo',
      targetId: 'memo-1',
      relationType: 'created_from',
      metadata: {'workflow': 'collection.convert_to_task'},
      createdAt: '2026-09-11T00:00:00.000Z',
      updatedAt: '2026-09-11T00:00:00.000Z',
      localVersion: 1,
      serverVersion: '3',
      modifiedByDevice: 'device-1',
    );

    final payload = EntityLinkWireMapper.toPayload(link);
    expect(payload['source'], {
      'entityType': 'execution.task',
      'entityId': 'task-1',
    });
    expect(payload['target'], {
      'entityType': 'execution.memo',
      'entityId': 'memo-1',
    });
    expect(payload['relationType'], 'created_from');

    final decoded = EntityLinkWireMapper.fromPayload(
      payload,
      serverVersion: '4',
    );
    expect(decoded.id, link.id);
    expect(decoded.sourceId, 'task-1');
    expect(decoded.targetId, 'memo-1');
    expect(decoded.metadata?['workflow'], 'collection.convert_to_task');
    expect(decoded.serverVersion, '4');
  });
}
