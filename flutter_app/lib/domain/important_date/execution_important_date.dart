enum ImportantDateRepeat {
  once('once'),
  yearly('yearly');

  const ImportantDateRepeat(this.wireValue);
  final String wireValue;

  static ImportantDateRepeat fromWire(String value) =>
      ImportantDateRepeat.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => ImportantDateRepeat.once,
      );
}

enum ImportantDateKind {
  birthday('birthday'),
  anniversary('anniversary'),
  milestone('milestone'),
  other('other');

  const ImportantDateKind(this.wireValue);
  final String wireValue;

  static ImportantDateKind fromWire(String value) =>
      ImportantDateKind.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => ImportantDateKind.other,
      );
}

enum ImportantDateCalendar {
  solar('solar'),
  lunar('lunar');

  const ImportantDateCalendar(this.wireValue);
  final String wireValue;

  static ImportantDateCalendar fromWire(String value) =>
      ImportantDateCalendar.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => ImportantDateCalendar.solar,
      );
}

class ExecutionImportantDate {
  const ExecutionImportantDate({
    required this.id,
    required this.userId,
    required this.title,
    required this.date,
    required this.repeat,
    required this.kind,
    required this.calendar,
    required this.lunarLeapMonth,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.lunarYear,
    this.lunarMonth,
    this.lunarDay,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String title;

  /// Solar source date. For lunar records this is only a compatibility anchor;
  /// lunarYear/lunarMonth/lunarDay/lunarLeapMonth are the source of truth.
  final String date;
  final ImportantDateRepeat repeat;
  final ImportantDateKind kind;
  final ImportantDateCalendar calendar;
  final int? lunarYear;
  final int? lunarMonth;
  final int? lunarDay;
  final bool lunarLeapMonth;
  final bool enabled;

  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  bool get isLunar => calendar == ImportantDateCalendar.lunar;
  bool get isYearly => repeat == ImportantDateRepeat.yearly;

  ExecutionImportantDate copyWith({
    String? title,
    String? date,
    ImportantDateRepeat? repeat,
    ImportantDateKind? kind,
    ImportantDateCalendar? calendar,
    int? lunarYear,
    int? lunarMonth,
    int? lunarDay,
    bool? lunarLeapMonth,
    bool? enabled,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearLunarYear = false,
    bool clearLunarMonth = false,
    bool clearLunarDay = false,
  }) =>
      ExecutionImportantDate(
        id: id,
        userId: userId,
        title: title ?? this.title,
        date: date ?? this.date,
        repeat: repeat ?? this.repeat,
        kind: kind ?? this.kind,
        calendar: calendar ?? this.calendar,
        lunarYear: clearLunarYear ? null : lunarYear ?? this.lunarYear,
        lunarMonth: clearLunarMonth ? null : lunarMonth ?? this.lunarMonth,
        lunarDay: clearLunarDay ? null : lunarDay ?? this.lunarDay,
        lunarLeapMonth: lunarLeapMonth ?? this.lunarLeapMonth,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );
}
