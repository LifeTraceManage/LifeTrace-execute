import '../../domain/calendar/execution_calendar_event.dart';
import '../local/app_database.dart' as db;

abstract final class CalendarEventDatabaseMapper {
  static db.CalendarEvent toRow(ExecutionCalendarEvent event) =>
      db.CalendarEvent(
        id: event.id,
        userId: event.userId,
        title: event.title,
        description: event.description,
        location: event.location,
        allDay: event.allDay,
        startAt: event.startAt,
        endAt: event.endAt,
        createdAt: event.createdAt,
        updatedAt: event.updatedAt,
        localVersion: event.localVersion,
        serverVersion: event.serverVersion,
        modifiedByDevice: event.modifiedByDevice,
      );

  static ExecutionCalendarEvent fromRow(db.CalendarEvent row) =>
      ExecutionCalendarEvent(
        id: row.id,
        userId: row.userId,
        title: row.title,
        description: row.description,
        location: row.location,
        allDay: row.allDay,
        startAt: row.startAt,
        endAt: row.endAt,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}
