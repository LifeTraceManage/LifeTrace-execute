import '../../domain/task/execution_task.dart';

abstract final class TaskWireMapper {
  static Map<String, dynamic> toPayload(ExecutionTask task) => {
        'meta': {
          'id': task.id,
          'userId': task.userId,
          'createdAt': task.createdAt,
          'updatedAt': task.updatedAt,
          'deletedAt': null,
          'localVersion': task.localVersion,
          'serverVersion': task.serverVersion,
          'modifiedByDevice': task.modifiedByDevice,
        },
        'title': task.title,
        'description': task.description,
        'projectId': task.projectId,
        'status': task.status.wireValue,
        'priority': task.priority.wireValue,
        'dueAt': task.dueAt,
        'scheduledAt': task.scheduledAt,
        'completedAt': task.completedAt,
      };

  static ExecutionTask fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _map(payload['meta']);
    return ExecutionTask(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      title: _requiredString(payload, 'title'),
      description: _nullableString(payload['description']),
      projectId: _nullableString(payload['projectId']),
      status: ExecutionTaskStatus.fromWire(
        _nullableString(payload['status']) ?? 'todo',
      ),
      priority: ExecutionTaskPriority.fromWire(
        _nullableString(payload['priority']) ?? 'normal',
      ),
      dueAt: _nullableString(payload['dueAt']),
      scheduledAt: _nullableString(payload['scheduledAt']),
      completedAt: _nullableString(payload['completedAt']),
      createdAt: _requiredString(meta, 'createdAt'),
      updatedAt: _requiredString(meta, 'updatedAt'),
      localVersion: _int(meta['localVersion']) ?? 1,
      serverVersion: serverVersion,
      modifiedByDevice: _nullableString(meta['modifiedByDevice']),
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Task payload meta must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = _nullableString(json[name]);
    if (value == null) throw FormatException('Task payload is missing $name');
    return value;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
