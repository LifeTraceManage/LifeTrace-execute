enum ExecutionMemoKind {
  text('text'),
  idea('idea'),
  link('link'),
  image('image'),
  audio('audio'),
  file('file');

  const ExecutionMemoKind(this.wireValue);
  final String wireValue;

  static ExecutionMemoKind fromWire(String value) =>
      ExecutionMemoKind.values.firstWhere(
        (kind) => kind.wireValue == value,
        orElse: () => ExecutionMemoKind.text,
      );
}

enum ExecutionMemoStatus {
  inbox('inbox'),
  archived('archived');

  const ExecutionMemoStatus(this.wireValue);
  final String wireValue;

  static ExecutionMemoStatus fromWire(String value) =>
      ExecutionMemoStatus.values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => ExecutionMemoStatus.inbox,
      );
}

class ExecutionMemo {
  const ExecutionMemo({
    required this.id,
    required this.userId,
    required this.kind,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.title,
    this.sourceUrl,
    this.important = false,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final ExecutionMemoKind kind;
  final String? title;
  final String content;
  final String? sourceUrl;
  final bool important;
  final ExecutionMemoStatus status;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  bool get isInbox => status == ExecutionMemoStatus.inbox;

  ExecutionMemo copyWith({
    ExecutionMemoKind? kind,
    String? title,
    String? content,
    String? sourceUrl,
    bool? important,
    ExecutionMemoStatus? status,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearTitle = false,
    bool clearSourceUrl = false,
  }) =>
      ExecutionMemo(
        id: id,
        userId: userId,
        kind: kind ?? this.kind,
        title: clearTitle ? null : title ?? this.title,
        content: content ?? this.content,
        sourceUrl: clearSourceUrl ? null : sourceUrl ?? this.sourceUrl,
        important: important ?? this.important,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );
}
