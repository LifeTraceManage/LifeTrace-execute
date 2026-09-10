import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'app_database.g.dart';

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get status => text()();
  TextColumn get priority => text()();
  TextColumn get dueAt => text().nullable()();
  TextColumn get scheduledAt => text().nullable()();
  TextColumn get completedAt => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  IntColumn get localVersion => integer()();
  TextColumn get serverVersion => text().nullable()();
  TextColumn get modifiedByDevice => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncOutbox extends Table {
  TextColumn get changeId => text()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get operation => text()();
  TextColumn get baseServerVersion => text()();
  IntColumn get entitySchemaVersion => integer().withDefault(const Constant(1))();
  TextColumn get clientModifiedAt => text()();
  TextColumn get payloadJson => text().nullable()();
  TextColumn get atomicGroupId => text().nullable()();
  TextColumn get dependenciesJson => text().withDefault(const Constant('[]'))();
  TextColumn get createdAt => text()();
  BoolColumn get blocked => boolean().withDefault(const Constant(false))();
  TextColumn get errorCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {changeId};
}

class SyncState extends Table {
  TextColumn get scope => text()();
  TextColumn get userId => text()();
  TextColumn get cursor => text().nullable()();
  TextColumn get updatedAt => text()();

  @override
  Set<Column<Object>> get primaryKey => {scope, userId};
}

class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get localPayloadJson => text().nullable()();
  TextColumn get serverPayloadJson => text().nullable()();
  TextColumn get serverVersion => text().nullable()();
  TextColumn get createdAt => text()();
  BoolColumn get resolved => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Tasks, SyncOutbox, SyncState, SyncConflicts])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);
  AppDatabase.production() : super(openProductionConnection());

  @override
  int get schemaVersion => 1;
}
