import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/domain/important_date/execution_important_date.dart';
import 'package:lifetrace_execute/domain/important_date/important_date_occurrence.dart';

void main() {
  test('lunar conversion matches known golden vectors', () {
    final classic = lunarDateToSolar(1986, 4, 21, leapMonth: false);
    expect(classic, DateTime(1986, 5, 29));

    final chineseNewYear = lunarDateToSolar(2024, 1, 1, leapMonth: false);
    expect(chineseNewYear, DateTime(2024, 2, 10));

    final leapSecondMonth = lunarDateToSolar(2023, 2, 1, leapMonth: true);
    expect(leapSecondMonth, DateTime(2023, 3, 22));

    expect(lunarDateToSolar(2024, 2, 1, leapMonth: true), isNull);
  });

  test('yearly lunar date derives the occurrence in requested solar year', () {
    const item = ExecutionImportantDate(
      id: 'mid-autumn',
      userId: 'user-1',
      title: '中秋',
      date: '2024-09-17',
      repeat: ImportantDateRepeat.yearly,
      kind: ImportantDateKind.other,
      calendar: ImportantDateCalendar.lunar,
      lunarMonth: 8,
      lunarDay: 15,
      lunarLeapMonth: false,
      enabled: true,
      createdAt: '2024-01-01T00:00:00Z',
      updatedAt: '2024-01-01T00:00:00Z',
      localVersion: 1,
    );

    expect(
      importantDateOccurrenceForSolarYear(item, 2024),
      DateTime(2024, 9, 17),
    );
  });

  test('yearly solar leap day only exists in leap years', () {
    const item = ExecutionImportantDate(
      id: 'leap-day',
      userId: 'user-1',
      title: '闰日',
      date: '2024-02-29',
      repeat: ImportantDateRepeat.yearly,
      kind: ImportantDateKind.anniversary,
      calendar: ImportantDateCalendar.solar,
      lunarLeapMonth: false,
      enabled: true,
      createdAt: '2024-01-01T00:00:00Z',
      updatedAt: '2024-01-01T00:00:00Z',
      localVersion: 1,
    );

    expect(importantDateOccurrenceForSolarYear(item, 2025), isNull);
    expect(
      importantDateOccurrenceForSolarYear(item, 2028),
      DateTime(2028, 2, 29),
    );
  });
}
