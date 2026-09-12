import 'package:lunar/lunar.dart';

import '../../domain/important_date/execution_important_date.dart';

class ImportantDateOccurrence {
  const ImportantDateOccurrence({
    required this.source,
    required this.localDate,
  });

  final ExecutionImportantDate source;
  final DateTime localDate;
}

DateTime? importantDateOccurrenceForSolarYear(
  ExecutionImportantDate item,
  int solarYear,
) {
  if (!item.enabled) return null;

  if (item.calendar == ImportantDateCalendar.solar) {
    final source = _parseLocalDate(item.date);
    if (source == null) return null;
    if (item.repeat == ImportantDateRepeat.once) {
      return source.year == solarYear ? source : null;
    }
    return _validDate(solarYear, source.month, source.day);
  }

  final month = item.lunarMonth;
  final day = item.lunarDay;
  if (month == null || day == null) return null;

  if (item.repeat == ImportantDateRepeat.once) {
    final lunarYear = item.lunarYear;
    if (lunarYear == null) return null;
    final solar = lunarDateToSolar(
      lunarYear,
      month,
      day,
      leapMonth: item.lunarLeapMonth,
    );
    return solar?.year == solarYear ? solar : null;
  }

  // A lunar year can end in Jan/Feb of the following solar year. Check both
  // candidate lunar years and select the occurrence in the requested solar year.
  for (final lunarYear in [solarYear - 1, solarYear]) {
    final solar = lunarDateToSolar(
      lunarYear,
      month,
      day,
      leapMonth: item.lunarLeapMonth,
    );
    if (solar?.year == solarYear) return solar;
  }
  return null;
}

DateTime? nextImportantDateOccurrence(
  ExecutionImportantDate item, {
  DateTime? from,
}) {
  if (!item.enabled) return null;
  final start = (from ?? DateTime.now()).toLocal();
  final startDate = DateTime(start.year, start.month, start.day);

  if (item.repeat == ImportantDateRepeat.once) {
    final occurrence = item.calendar == ImportantDateCalendar.solar
        ? _parseLocalDate(item.date)
        : lunarDateToSolar(
            item.lunarYear ?? -1,
            item.lunarMonth ?? -1,
            item.lunarDay ?? -1,
            leapMonth: item.lunarLeapMonth,
          );
    if (occurrence == null || occurrence.isBefore(startDate)) return null;
    return occurrence;
  }

  // Leap lunar months can be absent for many consecutive years, so search a
  // complete 60-year calendrical cycle rather than assuming next year exists.
  for (var year = start.year; year <= start.year + 60; year++) {
    final occurrence = importantDateOccurrenceForSolarYear(item, year);
    if (occurrence != null && !occurrence.isBefore(startDate)) {
      return occurrence;
    }
  }
  return null;
}

List<ImportantDateOccurrence> importantDatesForRange(
  Iterable<ExecutionImportantDate> items, {
  required DateTime start,
  required DateTime end,
}) {
  final from = DateTime(start.year, start.month, start.day);
  final until = DateTime(end.year, end.month, end.day);
  final result = <ImportantDateOccurrence>[];

  for (final item in items) {
    if (!item.enabled) continue;
    for (var year = from.year; year <= until.year; year++) {
      final date = importantDateOccurrenceForSolarYear(item, year);
      if (date == null || date.isBefore(from) || date.isAfter(until)) continue;
      result.add(ImportantDateOccurrence(source: item, localDate: date));
    }
  }

  result.sort((a, b) => a.localDate.compareTo(b.localDate));
  return result;
}

DateTime? lunarDateToSolar(
  int year,
  int month,
  int day, {
  required bool leapMonth,
}) {
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 30) return null;
  try {
    final lunar = Lunar.fromYmd(year, leapMonth ? -month : month, day);
    final solar = lunar.getSolar();
    return _validDate(solar.getYear(), solar.getMonth(), solar.getDay());
  } catch (_) {
    return null;
  }
}

DateTime? _parseLocalDate(String raw) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (match == null) return null;
  return _validDate(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

DateTime? _validDate(int year, int month, int day) {
  if (year < 1 || month < 1 || month > 12 || day < 1 || day > 31) return null;
  final value = DateTime(year, month, day);
  if (value.year != year || value.month != month || value.day != day) {
    return null;
  }
  return value;
}
