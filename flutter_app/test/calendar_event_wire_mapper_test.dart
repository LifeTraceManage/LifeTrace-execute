import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/calendar_event_wire_mapper.dart';
import 'package:lifetrace_execute/domain/calendar/execution_calendar_event.dart';

void main() {
  test('calendar wire mapper round-trips Sync v1 payload', () {
    const event = ExecutionCalendarEvent(
      id: 'event-1',
      userId: 'user-1',
      title: 'Meeting',
      description: 'Discuss project',
      location: 'Room A',
      allDay: false,
      startAt: '2026-09-11T06:30:00.000Z',
      endAt: '2026-09-11T07:30:00.000Z',
      createdAt: '2026-09-10T00:00:00.000Z',
      updatedAt: '2026-09-11T00:00:00.000Z',
      localVersion: 2,
      serverVersion: '4',
      modifiedByDevice: 'device-1',
    );

    final payload = CalendarEventWireMapper.toPayload(event);
    expect(payload['allDay'], isFalse);
    expect(payload['startAt'], event.startAt);

    final decoded = CalendarEventWireMapper.fromPayload(
      payload,
      serverVersion: '5',
    );
    expect(decoded.id, event.id);
    expect(decoded.location, 'Room A');
    expect(decoded.endAt, event.endAt);
    expect(decoded.serverVersion, '5');
  });
}
