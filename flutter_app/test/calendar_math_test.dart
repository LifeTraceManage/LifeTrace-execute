import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/features/calendar/calendar_math.dart';

void main() {
  test('month grid uses real month length and Monday offset', () {
    final september = calendarMonthGrid(DateTime(2026, 9));
    expect(september.length, 35);
    expect(september.first, isNull);
    expect(september[1], DateTime(2026, 9, 1));

    final february = calendarMonthGrid(DateTime(2028, 2));
    expect(february.whereType<DateTime>(), hasLength(29));
  });

  test('month navigation crosses year boundaries', () {
    expect(previousCalendarMonth(DateTime(2026, 1)), DateTime(2025, 12));
    expect(nextCalendarMonth(DateTime(2026, 12)), DateTime(2027, 1));
  });

  test('event overlap includes multi-day event dates', () {
    expect(
      eventTouchesLocalDate(
        startAt: '2026-09-10T12:00:00+08:00',
        endAt: '2026-09-12T12:00:00+08:00',
        date: DateTime(2026, 9, 11),
      ),
      isTrue,
    );
  });
}
