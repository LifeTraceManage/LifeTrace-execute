import '../../domain/calendar/execution_calendar_event.dart';

abstract final class CalendarEventWireMapper {
  static Map<String, dynamic> toPayload(ExecutionCalendarEvent event) => {
        'meta': {
          'id': event.id,
          'userId': event.userId,
          'createdAt': event.createdAt,
          'updatedAt': event.updatedAt,
          'deletedAt': null,
          'localVersion': event.localVersion,
          'serverVersion': event.serverVersion,
          'modifiedByDevice': event.modifiedByDevice,
        },
        'title': event.title,
        'description': event.description,
        'location': event.location,
        'allDay': event.allDay,
        'startAt': event.startAt,
        'endAt': event.endAt,
      };

  static ExecutionCalendarEvent fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _map(payload['meta']);
    return ExecutionCalendarEvent(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      title: _requiredString(payload, 'title'),
      description: _nullableString(payload['description']),
      location: _nullableString(payload['location']),
      allDay: _bool(payload['allDay']) ?? false,
      startAt: _requiredString(payload, 'startAt'),
      endAt: _nullableString(payload['endAt']),
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
    throw const FormatException('Calendar payload meta must be a JSON object');
  }

  static String _requiredString(Map<String, dynamic> json, String name) {
    final value = _nullableString(json[name]);
    if (value == null) {
      throw FormatException('Calendar payload is missing $name');
    }
    return value;
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool? _bool(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    return null;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
