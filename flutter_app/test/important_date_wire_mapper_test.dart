import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/important_date_repository.dart';
import 'package:lifetrace_execute/domain/important_date/execution_important_date.dart';

void main() {
  test('important date mapper matches Cloud typed contract', () {
    const item = ExecutionImportantDate(
      id: 'important-1',
      userId: 'user-1',
      title: '农历生日',
      date: '2026-09-02',
      repeat: ImportantDateRepeat.once,
      kind: ImportantDateKind.birthday,
      calendar: ImportantDateCalendar.lunar,
      lunarYear: 2026,
      lunarMonth: 7,
      lunarDay: 21,
      lunarLeapMonth: false,
      enabled: true,
      createdAt: '2026-09-01T00:00:00Z',
      updatedAt: '2026-09-01T00:00:00Z',
      localVersion: 2,
      serverVersion: '7',
      modifiedByDevice: 'device-1',
    );

    final payload = ImportantDateWireMapper.toPayload(item);
    expect(payload['id'], 'important-1');
    expect(payload['userId'], 'user-1');
    expect(payload['calendar'], 'lunar');
    expect(payload['lunarYear'], 2026);
    expect(payload['lunarMonth'], 7);
    expect(payload['lunarDay'], 21);
    expect(payload['enabled'], isTrue);
    expect(payload.containsKey('serverVersion'), isFalse);
    expect(payload.containsKey('localVersion'), isFalse);

    final parsed = ImportantDateWireMapper.fromPayload(
      payload,
      serverVersion: '8',
      serverModifiedAt: '2026-09-02T00:00:00Z',
    );
    expect(parsed.id, item.id);
    expect(parsed.serverVersion, '8');
    expect(parsed.calendar, ImportantDateCalendar.lunar);
  });

  test('legacy yearly lunar payload without lunarYear remains readable', () {
    final parsed = ImportantDateWireMapper.fromPayload(
      {
        'id': 'legacy',
        'userId': 'user-1',
        'title': '每年农历纪念日',
        'date': '2026-09-25',
        'repeat': 'yearly',
        'kind': 'anniversary',
        'calendar': 'lunar',
        'lunarMonth': 8,
        'lunarDay': 15,
        'lunarLeapMonth': false,
      },
      serverVersion: '1',
      serverModifiedAt: '2026-01-01T00:00:00Z',
    );

    expect(parsed.lunarYear, isNull);
    expect(parsed.enabled, isTrue);
  });
}
