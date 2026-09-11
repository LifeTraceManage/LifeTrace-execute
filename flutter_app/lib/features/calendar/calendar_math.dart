DateTime calendarMonthStart(DateTime value) =>
    DateTime(value.year, value.month);

DateTime previousCalendarMonth(DateTime value) =>
    DateTime(value.year, value.month - 1);

DateTime nextCalendarMonth(DateTime value) =>
    DateTime(value.year, value.month + 1);

int calendarDaysInMonth(DateTime month) =>
    DateTime(month.year, month.month + 1, 0).day;

int calendarMondayOffset(DateTime month) =>
    DateTime(month.year, month.month, 1).weekday - DateTime.monday;

List<DateTime?> calendarMonthGrid(DateTime month) {
  final first = calendarMonthStart(month);
  final offset = calendarMondayOffset(first);
  final days = calendarDaysInMonth(first);
  final cellCount = offset + days <= 35 ? 35 : 42;
  return List<DateTime?>.generate(cellCount, (index) {
    final day = index - offset + 1;
    if (day < 1 || day > days) return null;
    return DateTime(first.year, first.month, day);
  });
}

bool sameCalendarDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool instantFallsOnLocalDate(String? raw, DateTime date) {
  if (raw == null) return false;
  final value = DateTime.tryParse(raw)?.toLocal();
  return value != null && sameCalendarDate(value, date);
}

bool eventTouchesLocalDate({
  required String startAt,
  String? endAt,
  required DateTime date,
}) {
  final start = DateTime.tryParse(startAt)?.toLocal();
  if (start == null) return false;
  final end = DateTime.tryParse(endAt ?? '')?.toLocal() ?? start;
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  return start.isBefore(dayEnd) && !end.isBefore(dayStart);
}
