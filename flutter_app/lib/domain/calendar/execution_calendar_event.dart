class ExecutionCalendarEvent {
  const ExecutionCalendarEvent({
    required this.id,
    required this.userId,
    required this.title,
    required this.startAt,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.description,
    this.location,
    this.allDay = false,
    this.endAt,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? location;
  final bool allDay;
  final String startAt;
  final String? endAt;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  ExecutionCalendarEvent copyWith({
    String? title,
    String? description,
    String? location,
    bool? allDay,
    String? startAt,
    String? endAt,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearDescription = false,
    bool clearLocation = false,
    bool clearEndAt = false,
  }) {
    return ExecutionCalendarEvent(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: clearDescription ? null : description ?? this.description,
      location: clearLocation ? null : location ?? this.location,
      allDay: allDay ?? this.allDay,
      startAt: startAt ?? this.startAt,
      endAt: clearEndAt ? null : endAt ?? this.endAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localVersion: localVersion ?? this.localVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
    );
  }
}
