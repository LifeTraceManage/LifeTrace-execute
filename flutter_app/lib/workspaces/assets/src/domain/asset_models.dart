import 'dart:math' as math;

enum AssetCategory {
  phone('手机'),
  tablet('平板'),
  computer('电脑'),
  wearable('穿戴'),
  audio('音频'),
  camera('影像'),
  home('家电'),
  other('其他');

  const AssetCategory(this.label);
  final String label;
}

enum AssetStatus {
  active('使用中'),
  idle('闲置'),
  lent('借出'),
  repair('维修中'),
  sold('已出售'),
  retired('已退役');

  const AssetStatus(this.label);
  final String label;
}

enum AssetEventType {
  purchase('购入'),
  useStart('开始使用'),
  maintenance('保养'),
  repair('维修'),
  replacement('更换配件'),
  lend('借出'),
  returnItem('归还'),
  idle('闲置'),
  valuation('估值变化'),
  sell('出售'),
  retire('退役'),
  note('备注');

  const AssetEventType(this.label);
  final String label;
}

String newEntityId(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final random = math.Random.secure().nextInt(0x7fffffff).toRadixString(36);
  return '$prefix-$now-$random';
}

DateTime _dateTime(Object? value, {DateTime? fallback}) {
  if (value is String) {
    return DateTime.tryParse(value)?.toLocal() ?? fallback ?? DateTime.now();
  }
  return fallback ?? DateTime.now();
}

double _double(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  final raw = name?.toString();
  return values.where((value) => value.name == raw).firstOrNull ?? fallback;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}

class AssetItem {
  const AssetItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.model,
    required this.category,
    required this.status,
    required this.purchasePrice,
    required this.currentValue,
    required this.purchaseDate,
    required this.warrantyUntil,
    required this.spec,
    required this.serialNumber,
    required this.location,
    required this.targetDailyCost,
    this.purchaseChannel = '',
    this.maintenanceCost = 0,
    this.recoveredAmount = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.serverVersion = '0',
  });

  final String id;
  final String name;
  final String brand;
  final String model;
  final AssetCategory category;
  final AssetStatus status;
  final double purchasePrice;
  final double currentValue;
  final DateTime purchaseDate;
  final DateTime? warrantyUntil;
  final String spec;
  final String serialNumber;
  final String location;
  final double targetDailyCost;
  final String purchaseChannel;
  final double maintenanceCost;
  final double recoveredAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String serverVersion;

  int get heldDays => math.max(1, DateTime.now().difference(purchaseDate).inDays);
  double get effectiveCost => math.max(0, purchasePrice + maintenanceCost - recoveredAmount);
  double get dailyCost => effectiveCost / heldDays;
  double get retentionRate => purchasePrice <= 0 ? 0 : currentValue / purchasePrice;
  double get serviceProgress => (heldDays / 1095).clamp(0.0, 1.0);

  AssetItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? model,
    AssetCategory? category,
    AssetStatus? status,
    double? purchasePrice,
    double? currentValue,
    DateTime? purchaseDate,
    DateTime? warrantyUntil,
    bool clearWarrantyUntil = false,
    String? spec,
    String? serialNumber,
    String? location,
    double? targetDailyCost,
    String? purchaseChannel,
    double? maintenanceCost,
    double? recoveredAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? serverVersion,
  }) {
    return AssetItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      category: category ?? this.category,
      status: status ?? this.status,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      currentValue: currentValue ?? this.currentValue,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyUntil: clearWarrantyUntil ? null : warrantyUntil ?? this.warrantyUntil,
      spec: spec ?? this.spec,
      serialNumber: serialNumber ?? this.serialNumber,
      location: location ?? this.location,
      targetDailyCost: targetDailyCost ?? this.targetDailyCost,
      purchaseChannel: purchaseChannel ?? this.purchaseChannel,
      maintenanceCost: maintenanceCost ?? this.maintenanceCost,
      recoveredAmount: recoveredAmount ?? this.recoveredAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'brand': brand,
        'model': model,
        'category': category.name,
        'status': status.name,
        'purchasePrice': purchasePrice,
        'currentValue': currentValue,
        'purchaseDate': purchaseDate.toUtc().toIso8601String(),
        'warrantyUntil': warrantyUntil?.toUtc().toIso8601String(),
        'spec': spec,
        'serialNumber': serialNumber,
        'location': location,
        'targetDailyCost': targetDailyCost,
        'purchaseChannel': purchaseChannel,
        'maintenanceCost': maintenanceCost,
        'recoveredAmount': recoveredAmount,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'isDeleted': isDeleted,
        'serverVersion': serverVersion,
      };

  factory AssetItem.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return AssetItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString() ?? '',
      model: json['model']?.toString() ?? '',
      category: _enumByName(AssetCategory.values, json['category'], AssetCategory.other),
      status: _enumByName(AssetStatus.values, json['status'], AssetStatus.active),
      purchasePrice: _double(json['purchasePrice']),
      currentValue: _double(json['currentValue']),
      purchaseDate: _dateTime(json['purchaseDate'], fallback: now),
      warrantyUntil: json['warrantyUntil'] == null
          ? null
          : DateTime.tryParse(json['warrantyUntil'].toString())?.toLocal(),
      spec: json['spec']?.toString() ?? '',
      serialNumber: json['serialNumber']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      targetDailyCost: _double(json['targetDailyCost']),
      purchaseChannel: json['purchaseChannel']?.toString() ?? '',
      maintenanceCost: _double(json['maintenanceCost']),
      recoveredAmount: _double(json['recoveredAmount']),
      createdAt: _dateTime(json['createdAt'], fallback: now),
      updatedAt: _dateTime(json['updatedAt'], fallback: now),
      isDeleted: json['isDeleted'] == true,
      serverVersion: json['serverVersion']?.toString() ?? '0',
    );
  }
}

class AssetEvent {
  const AssetEvent({
    required this.id,
    required this.assetId,
    required this.type,
    required this.date,
    required this.title,
    required this.detail,
    required this.createdAt,
    required this.updatedAt,
    this.amount,
    this.isDeleted = false,
    this.serverVersion = '0',
  });

  final String id;
  final String assetId;
  final AssetEventType type;
  final DateTime date;
  final String title;
  final String detail;
  final double? amount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String serverVersion;

  AssetEvent copyWith({
    String? id,
    String? assetId,
    AssetEventType? type,
    DateTime? date,
    String? title,
    String? detail,
    double? amount,
    bool clearAmount = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? serverVersion,
  }) {
    return AssetEvent(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      type: type ?? this.type,
      date: date ?? this.date,
      title: title ?? this.title,
      detail: detail ?? this.detail,
      amount: clearAmount ? null : amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'assetId': assetId,
        'type': type.name,
        'date': date.toUtc().toIso8601String(),
        'title': title,
        'detail': detail,
        'amount': amount,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'isDeleted': isDeleted,
        'serverVersion': serverVersion,
      };

  factory AssetEvent.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return AssetEvent(
      id: json['id']?.toString() ?? '',
      assetId: json['assetId']?.toString() ?? '',
      type: _enumByName(AssetEventType.values, json['type'], AssetEventType.note),
      date: _dateTime(json['date'], fallback: now),
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      amount: json['amount'] == null ? null : _double(json['amount']),
      createdAt: _dateTime(json['createdAt'], fallback: now),
      updatedAt: _dateTime(json['updatedAt'], fallback: now),
      isDeleted: json['isDeleted'] == true,
      serverVersion: json['serverVersion']?.toString() ?? '0',
    );
  }
}

class AssetEntityLink {
  const AssetEntityLink({
    required this.id,
    required this.userId,
    required this.sourceAssetId,
    required this.targetEntityType,
    required this.targetEntityId,
    required this.relationType,
    required this.targetLabel,
    required this.createdAt,
    required this.updatedAt,
    this.localVersion = 1,
    this.isDeleted = false,
    this.serverVersion = '0',
  });

  final String id;
  final String userId;
  final String sourceAssetId;
  final String targetEntityType;
  final String targetEntityId;
  final String relationType;
  final String targetLabel;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int localVersion;
  final bool isDeleted;
  final String serverVersion;

  AssetEntityLink copyWith({
    String? id,
    String? userId,
    String? sourceAssetId,
    String? targetEntityType,
    String? targetEntityId,
    String? relationType,
    String? targetLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? localVersion,
    bool? isDeleted,
    String? serverVersion,
  }) {
    return AssetEntityLink(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sourceAssetId: sourceAssetId ?? this.sourceAssetId,
      targetEntityType: targetEntityType ?? this.targetEntityType,
      targetEntityId: targetEntityId ?? this.targetEntityId,
      relationType: relationType ?? this.relationType,
      targetLabel: targetLabel ?? this.targetLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localVersion: localVersion ?? this.localVersion,
      isDeleted: isDeleted ?? this.isDeleted,
      serverVersion: serverVersion ?? this.serverVersion,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'userId': userId,
        'sourceAssetId': sourceAssetId,
        'targetEntityType': targetEntityType,
        'targetEntityId': targetEntityId,
        'relationType': relationType,
        'targetLabel': targetLabel,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'localVersion': localVersion,
        'isDeleted': isDeleted,
        'serverVersion': serverVersion,
      };

  Map<String, Object?> toCloudJson() => {
        'meta': {
          'id': id,
          'userId': userId,
          'createdAt': createdAt.toUtc().toIso8601String(),
          'updatedAt': updatedAt.toUtc().toIso8601String(),
          'deletedAt':
              isDeleted ? updatedAt.toUtc().toIso8601String() : null,
          'localVersion': localVersion,
          'serverVersion': serverVersion == '0' ? null : serverVersion,
          'modifiedByDevice': null,
        },
        'source': {
          'entityType': 'asset.asset',
          'entityId': sourceAssetId,
        },
        'target': {
          'entityType': targetEntityType,
          'entityId': targetEntityId,
        },
        'relationType': relationType,
        'metadata': targetLabel.isEmpty ? null : {'label': targetLabel},
      };

  factory AssetEntityLink.fromJson(Map<String, Object?> json) {
    final now = DateTime.now();
    return AssetEntityLink(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      sourceAssetId: json['sourceAssetId']?.toString() ?? '',
      targetEntityType: json['targetEntityType']?.toString() ?? '',
      targetEntityId: json['targetEntityId']?.toString() ?? '',
      relationType: json['relationType']?.toString() ?? 'references',
      targetLabel: json['targetLabel']?.toString() ?? '',
      createdAt: _dateTime(json['createdAt'], fallback: now),
      updatedAt: _dateTime(json['updatedAt'], fallback: now),
      localVersion: (json['localVersion'] as num?)?.toInt() ?? 1,
      isDeleted: json['isDeleted'] == true,
      serverVersion: json['serverVersion']?.toString() ?? '0',
    );
  }

  static AssetEntityLink? tryFromCloudJson(
    Map<String, Object?> json, {
    required String serverVersion,
  }) {
    final metaRaw = json['meta'];
    final sourceRaw = json['source'];
    final targetRaw = json['target'];
    if (metaRaw is! Map || sourceRaw is! Map || targetRaw is! Map) {
      throw const FormatException('entity.link payload is missing meta/source/target');
    }
    final meta = Map<String, Object?>.from(metaRaw);
    final source = Map<String, Object?>.from(sourceRaw);
    final target = Map<String, Object?>.from(targetRaw);
    if (source['entityType']?.toString() != 'asset.asset') {
      return null;
    }

    final id = meta['id']?.toString() ?? '';
    final userId = meta['userId']?.toString() ?? '';
    final sourceAssetId = source['entityId']?.toString() ?? '';
    final targetEntityType = target['entityType']?.toString() ?? '';
    final targetEntityId = target['entityId']?.toString() ?? '';
    final relationType = json['relationType']?.toString() ?? '';
    if (id.isEmpty ||
        userId.isEmpty ||
        sourceAssetId.isEmpty ||
        targetEntityType.isEmpty ||
        targetEntityId.isEmpty ||
        relationType.isEmpty) {
      throw const FormatException('entity.link payload contains empty identifiers');
    }

    final metadataRaw = json['metadata'];
    final metadata = metadataRaw is Map
        ? Map<String, Object?>.from(metadataRaw)
        : const <String, Object?>{};
    final now = DateTime.now();
    return AssetEntityLink(
      id: id,
      userId: userId,
      sourceAssetId: sourceAssetId,
      targetEntityType: targetEntityType,
      targetEntityId: targetEntityId,
      relationType: relationType,
      targetLabel: metadata['label']?.toString() ?? '',
      createdAt: _dateTime(meta['createdAt'], fallback: now),
      updatedAt: _dateTime(meta['updatedAt'], fallback: now),
      localVersion: (meta['localVersion'] as num?)?.toInt() ?? 1,
      isDeleted: meta['deletedAt'] != null,
      serverVersion: serverVersion,
    );
  }
}

class AssetSyncConflict {
  const AssetSyncConflict({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.changeId,
    required this.currentServerVersion,
    required this.serverDeleted,
    required this.reason,
    required this.createdAt,
    this.localPayload,
    this.serverPayload,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String changeId;
  final String currentServerVersion;
  final bool serverDeleted;
  final String reason;
  final DateTime createdAt;
  final Map<String, Object?>? localPayload;
  final Map<String, Object?>? serverPayload;

  Map<String, Object?> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityId': entityId,
        'changeId': changeId,
        'currentServerVersion': currentServerVersion,
        'serverDeleted': serverDeleted,
        'reason': reason,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'localPayload': localPayload,
        'serverPayload': serverPayload,
      };

  factory AssetSyncConflict.fromJson(Map<String, Object?> json) =>
      AssetSyncConflict(
        id: json['id']?.toString() ?? '',
        entityType: json['entityType']?.toString() ?? '',
        entityId: json['entityId']?.toString() ?? '',
        changeId: json['changeId']?.toString() ?? '',
        currentServerVersion:
            json['currentServerVersion']?.toString() ?? '0',
        serverDeleted: json['serverDeleted'] == true,
        reason: json['reason']?.toString() ?? '',
        createdAt: _dateTime(json['createdAt']),
        localPayload: json['localPayload'] is Map
            ? Map<String, Object?>.from(json['localPayload'] as Map)
            : null,
        serverPayload: json['serverPayload'] is Map
            ? Map<String, Object?>.from(json['serverPayload'] as Map)
            : null,
      );
}

class AssetSyncIssue {
  const AssetSyncIssue({
    required this.changeId,
    required this.entityType,
    required this.entityId,
    required this.errorCode,
    required this.message,
  });

  final String changeId;
  final String entityType;
  final String entityId;
  final String errorCode;
  final String message;
}

class SyncOutboxItem {
  const SyncOutboxItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.baseServerVersion,
    required this.clientModifiedAt,
    this.attempts = 0,
    this.lastError,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final Map<String, Object?>? payload;
  final String baseServerVersion;
  final DateTime clientModifiedAt;
  final int attempts;
  final String? lastError;

  Map<String, Object?> toJson() => {
        'id': id,
        'entityType': entityType,
        'entityId': entityId,
        'operation': operation,
        'payload': payload,
        'baseServerVersion': baseServerVersion,
        'clientModifiedAt': clientModifiedAt.toUtc().toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
      };
}
