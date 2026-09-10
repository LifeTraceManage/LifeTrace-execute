import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/task_wire_mapper.dart';
import 'package:lifetrace_execute/domain/task/execution_task.dart';

void main() {
  test('task wire mapper preserves Compose Sync v1 payload shape', () {
    const task = ExecutionTask(
      id: 'task-1',
      userId: 'user-1',
      title: 'Write tests',
      description: 'sync parity',
      projectId: 'project-1',
      status: ExecutionTaskStatus.inProgress,
      priority: ExecutionTaskPriority.high,
      dueAt: '2026-09-11T12:00:00.000Z',
      scheduledAt: '2026-09-11T10:00:00.000Z',
      createdAt: '2026-09-10T10:00:00.000Z',
      updatedAt: '2026-09-10T11:00:00.000Z',
      localVersion: 4,
      serverVersion: '12',
      modifiedByDevice: 'device-1',
    );

    final payload = TaskWireMapper.toPayload(task);
    final meta = payload['meta'] as Map<String, dynamic>;

    expect(meta['id'], 'task-1');
    expect(meta['userId'], 'user-1');
    expect(meta['deletedAt'], isNull);
    expect(meta['localVersion'], 4);
    expect(meta['serverVersion'], '12');
    expect(payload['status'], 'in_progress');
    expect(payload['priority'], 'high');
    expect(payload['projectId'], 'project-1');

    final restored = TaskWireMapper.fromPayload(payload, serverVersion: '13');
    expect(restored.id, task.id);
    expect(restored.title, task.title);
    expect(restored.status, task.status);
    expect(restored.priority, task.priority);
    expect(restored.localVersion, task.localVersion);
    expect(restored.serverVersion, '13');
  });
}
