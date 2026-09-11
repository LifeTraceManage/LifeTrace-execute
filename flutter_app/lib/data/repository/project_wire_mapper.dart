import '../../domain/project/execution_project.dart';

abstract final class ProjectWireMapper {
  static Map<String, dynamic> toPayload(ExecutionProject project) => {
        'meta': {
          'id': project.id,
          'userId': project.userId,
          'createdAt': project.createdAt,
          'updatedAt': project.updatedAt,
          'deletedAt': null,
          'localVersion': project.localVersion,
          'serverVersion': project.serverVersion,
          'modifiedByDevice': project.modifiedByDevice,
        },
        'title': project.title,
        'description': project.description,
        'status': project.status.wireValue,
        'startAt': project.startAt,
        'dueAt': project.dueAt,
      };

  static ExecutionProject fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _map(payload['meta']);
    return ExecutionProject(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      title: _requiredString(payload, 'title'),
      description: _nullableString(payload['description']),
      status: ExecutionProjectStatus.fromWire(
        _nullableString(payload['status']) ?? 'active',
      ),
      startAt: _nullableString(payload['startAt']),
      dueAt: _nullableString(payload['dueAt']),
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
    throw const FormatException('Project payload meta must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = _nullableString(json[name]);
    if (value == null) throw FormatException('Project payload is missing $name');
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
