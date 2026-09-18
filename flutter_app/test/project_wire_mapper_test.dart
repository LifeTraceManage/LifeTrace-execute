import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/project_wire_mapper.dart';
import 'package:lifetrace_execute/domain/project/execution_project.dart';

void main() {
  test('project wire mapper round-trips Sync v1 registered JSON payload', () {
    const project = ExecutionProject(
      id: 'project-1',
      userId: 'user-1',
      title: 'LifeTrace',
      description: 'Execute project',
      status: ExecutionProjectStatus.paused,
      startAt: '2026-09-01T00:00:00.000Z',
      dueAt: '2026-10-01T00:00:00.000Z',
      createdAt: '2026-08-01T00:00:00.000Z',
      updatedAt: '2026-09-11T00:00:00.000Z',
      localVersion: 3,
      serverVersion: '7',
      modifiedByDevice: 'device-1',
    );

    final payload = ProjectWireMapper.toPayload(project);
    expect(payload['status'], 'paused');
    expect((payload['meta'] as Map<String, dynamic>)['id'], 'project-1');

    final decoded = ProjectWireMapper.fromPayload(
      payload,
      serverVersion: '8',
    );
    expect(decoded.id, project.id);
    expect(decoded.title, project.title);
    expect(decoded.status, ExecutionProjectStatus.paused);
    expect(decoded.startAt, project.startAt);
    expect(decoded.dueAt, project.dueAt);
    expect(decoded.serverVersion, '8');
  });
}
